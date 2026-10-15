import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {
  assertAdmin, fail, getElection, logEvent, requireString, summarizeRound,
} from "./common";
import {removeElected, roundTypeFor} from "./candidates";
import {tallyRound} from "./tally";
import {
  BLANK, NO, YES, type Candidate, type RoundResult, type RoundType,
} from "./types";
import {electedElsewhere} from "./winners";

interface RoundDoc {
  position: string;
  candidates: Candidate[];
  type: RoundType;
  status: string;
}

export const openRound = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<void> => {
  await assertAdmin(db, uid);
  const electionId = requireString(data, "electionId");
  const roundId = requireString(data, "roundId");
  const election = await getElection(db, electionId);
  if (election.status !== "open") {
    throw fail(
      "failed-precondition", "Abra a eleição antes de abrir uma votação."
    );
  }

  const roundsRef = db.collection(`elections/${electionId}/rounds`);
  const all = await roundsRef.get();
  const target = all.docs.find((d) => d.id === roundId);
  if (!target) throw fail("not-found", "Votação não encontrada.");
  const round = target.data() as RoundDoc;
  if (round.status !== "pending") {
    throw fail("failed-precondition", "Esta votação já foi aberta.");
  }
  if (all.docs.some((d) => d.id !== roundId && d.get("status") === "open")) {
    throw fail("failed-precondition", "Já existe uma votação aberta.");
  }

  const elected = electedElsewhere(
    all.docs.map(summarizeRound), round.position
  );
  const eligible = removeElected(round.candidates, elected);
  if (eligible.length === 0) {
    throw fail(
      "failed-precondition", "Nenhum candidato elegível para este cargo."
    );
  }
  const removed = round.candidates
    .filter((c) => elected.has(c.id))
    .map((c) => c.id);

  await target.ref.update({
    candidates: eligible,
    type: roundTypeFor(eligible, round.type),
    status: "open",
    votedCount: 0,
    openedAt: FieldValue.serverTimestamp(),
  });
  await logEvent(db, electionId, {
    type: "round_opened",
    actorId: uid,
    roundId,
    position: round.position,
    removed,
  });
};

// Contador exibido ao vivo ("X de Y votaram"). Roda num gatilho, fora da
// transação do voto, para que os eleitores não disputem o mesmo documento.
// É só informativo: a contagem oficial vem de `voted`/`ballots` no
// encerramento, que também grava o valor exato.
export const bumpVotedCount = async (
  db: Firestore,
  electionId: string,
  roundId: string
): Promise<void> => {
  const ref = db.doc(`elections/${electionId}/rounds/${roundId}`);
  // Só enquanto a rodada está aberta: um gatilho atrasado não pode inflar o
  // valor exato que o encerramento gravou.
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.get("status") !== "open") return;
    tx.update(ref, {votedCount: FieldValue.increment(1)});
  });
};

// Registra o voto. `voted/{uid}` (quem votou) e `ballots/{randomId}` (o que
// foi votado) são gravados na mesma transação e não se referenciam; o
// `ballot` não tem identidade nem timestamp. O recibo é o id do ballot.
// O voto não escreve no documento da rodada (evita disputa entre eleitores).
export const castVote = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<{receipt: string}> => {
  const electionId = requireString(data, "electionId");
  const roundId = requireString(data, "roundId");
  const choice = requireString(data, "choice");

  const electionRef = db.doc(`elections/${electionId}`);
  const voterRef = electionRef.collection("voters").doc(uid);
  const roundRef = electionRef.collection("rounds").doc(roundId);
  const votedRef = roundRef.collection("voted").doc(uid);
  const ballotRef = roundRef.collection("ballots").doc();

  await db.runTransaction(async (tx) => {
    const [election, voter, round, voted] = await Promise.all([
      tx.get(electionRef),
      tx.get(voterRef),
      tx.get(roundRef),
      tx.get(votedRef),
    ]);
    if (!election.exists || election.get("status") !== "open") {
      throw fail("failed-precondition", "A eleição não está aberta.");
    }
    if (!voter.exists || voter.get("status") !== "approved") {
      throw fail(
        "permission-denied", "Você ainda não foi liberado para votar."
      );
    }
    if (!round.exists || round.get("status") !== "open") {
      throw fail("failed-precondition", "Esta votação não está aberta.");
    }
    if (voted.exists) {
      throw fail("already-exists", "Você já votou nesta votação.");
    }
    const allowed = round.get("type") === "single" ?
      [YES, NO, BLANK] :
      [...(round.get("candidates") as Candidate[]).map((c) => c.id), BLANK];
    if (!allowed.includes(choice)) {
      throw fail("invalid-argument", "Opção de voto inválida.");
    }
    tx.create(votedRef, {});
    tx.create(ballotRef, {choice});
  });
  return {receipt: ballotRef.id};
};

// Encerra e apura numa única transação: leitura de `ballots` e `voted` e a
// troca de status acontecem juntas, então um voto concorrente ou entra na
// contagem ou é rejeitado (rodada fechada).
export const closeRound = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<RoundResult> => {
  await assertAdmin(db, uid);
  const electionId = requireString(data, "electionId");
  const roundId = requireString(data, "roundId");
  await getElection(db, electionId);
  const roundRef = db.doc(`elections/${electionId}/rounds/${roundId}`);

  const {result, position} = await db.runTransaction(async (tx) => {
    const roundSnap = await tx.get(roundRef);
    if (!roundSnap.exists) throw fail("not-found", "Votação não encontrada.");
    if (roundSnap.get("status") !== "open") {
      throw fail("failed-precondition", "Esta votação não está aberta.");
    }
    const ballots = await tx.get(roundRef.collection("ballots"));
    const voted = await tx.get(roundRef.collection("voted"));
    const outcome = tallyRound(
      roundSnap.get("type") as RoundType,
      roundSnap.get("candidates") as Candidate[],
      ballots.docs.map((d) => String(d.get("choice"))),
      voted.size
    );
    tx.update(roundRef, {
      status: "closed",
      closedAt: FieldValue.serverTimestamp(),
      votedCount: voted.size,
      result: outcome,
    });
    return {result: outcome, position: String(roundSnap.get("position"))};
  });

  await logEvent(db, electionId, {
    type: "round_closed",
    actorId: uid,
    roundId,
    position,
    winnerId: result.winnerId,
    tie: result.tie,
    total: result.total,
    votedCount: result.votedCount,
    divergence: result.divergence,
  });
  return result;
};
