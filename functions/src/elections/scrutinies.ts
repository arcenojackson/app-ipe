import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {fail, logEvent, requireString} from "./common";
import {assertElectionDirector} from "./directors";
import {countBallots, decideScrutiny, requiredVotes} from "./scrutiny";
import {
  BLANK,
  type Candidate,
  type CandidateVotes,
  type CargoStage,
  type ScrutinyResult,
} from "./types";

interface CargoDoc {
  stage: CargoStage;
  cycle: number;
  candidates: CandidateVotes[];
}

type Number123 = 1 | 2 | 3;

// Membros da sociedade com o nome do cadastro, em ordem alfabética.
const loadMemberOptions = async (
  db: Firestore,
  societyId: string
): Promise<Candidate[]> => {
  const society = await db.doc(`societies/${societyId}`).get();
  const ids: string[] = (society.get("members") ?? []).map(String);
  if (ids.length === 0) return [];
  const users = await db.getAll(...ids.map((id) => db.doc(`users/${id}`)));
  return users
    .filter((u) => u.exists)
    .map((u) => ({id: u.id, name: String(u.get("name") ?? "")}))
    .sort((a, b) => a.name.localeCompare(b.name));
};

// Número do próximo escrutínio conforme a fase do cargo.
const nextNumber = (cargo: CargoDoc): Number123 => {
  if (cargo.stage === "idle") return 1;
  if (cargo.stage === "confirming") {
    if (cargo.candidates.length === 0) {
      throw fail(
        "failed-precondition",
        "Não há candidatos. Reinicie o cargo para um novo 1º escrutínio."
      );
    }
    return 2;
  }
  if (cargo.stage === "awaiting3") return 3;
  throw fail(
    "failed-precondition", "O cargo não está pronto para iniciar um escrutínio."
  );
};

// Inicia o 1º, 2º ou 3º escrutínio do cargo. Só um escrutínio fica aberto por
// vez na eleição; tudo roda numa transação para não haver duas aberturas.
export const startScrutiny = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<{roundId: string; number: Number123}> => {
  const electionId = requireString(data, "electionId");
  const position = requireString(data, "position");
  const election = await assertElectionDirector(db, uid, electionId);
  if (election.status !== "open") {
    throw fail(
      "failed-precondition", "Abra a eleição antes de iniciar um escrutínio."
    );
  }
  if (!(election.positions ?? []).includes(position)) {
    throw fail("invalid-argument", "Este cargo não faz parte da eleição.");
  }

  const members = await loadMemberOptions(db, election.societyId);
  const electionRef = db.doc(`elections/${electionId}`);
  const cargosRef = electionRef.collection("cargos");
  const roundsRef = electionRef.collection("rounds");

  const started = await db.runTransaction(async (tx) => {
    const cargos = await tx.get(cargosRef);
    const open = await tx.get(roundsRef.where("status", "==", "open").limit(1));
    const cargoSnap = cargos.docs.find((d) => d.id === position);
    if (!cargoSnap) throw fail("not-found", "Cargo não encontrado.");
    if (!open.empty) {
      throw fail("failed-precondition", "Já existe um escrutínio aberto.");
    }
    const cargo = cargoSnap.data() as CargoDoc;
    const number = nextNumber(cargo);

    // Quem já foi eleito em outro cargo não pode ser eleito de novo.
    const elected = new Set(
      cargos.docs
        .filter((d) => d.id !== position)
        .filter((d) => d.get("stage") === "decided" && d.get("winnerId"))
        .map((d) => String(d.get("winnerId")))
    );
    const pool: Candidate[] = number === 1 ?
      members :
      cargo.candidates.map((c) => ({id: c.id, name: c.name}));
    const options = pool.filter((o) => !elected.has(o.id));
    if (options.length === 0) {
      throw fail(
        "failed-precondition",
        number === 1 ?
          "Não há opções para este escrutínio." :
          "Todos os candidatos já foram eleitos em outro cargo. " +
            "Reinicie o cargo."
      );
    }

    const roundRef = roundsRef.doc();
    tx.set(roundRef, {
      position,
      cycle: cargo.cycle,
      number,
      status: "open",
      options,
      votedCount: 0,
      openedAt: FieldValue.serverTimestamp(),
    });
    tx.update(cargoSnap.ref, {stage: `scrutiny${number}`});
    return {roundId: roundRef.id, number};
  });

  await logEvent(db, electionId, {
    type: "scrutiny_started",
    actorId: uid,
    position,
    number: started.number,
  });
  return started;
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
      throw fail("failed-precondition", "Este escrutínio não está aberto.");
    }
    if (voted.exists) {
      throw fail("already-exists", "Você já votou neste escrutínio.");
    }
    const allowed = [
      ...(round.get("options") as Candidate[]).map((o) => o.id),
      BLANK,
    ];
    if (!allowed.includes(choice)) {
      throw fail("invalid-argument", "Opção de voto inválida.");
    }
    tx.create(votedRef, {});
    tx.create(ballotRef, {choice});
  });
  return {receipt: ballotRef.id};
};

// Encerra e apura numa única transação: leitura de `ballots`, `voted` e dos
// eleitores liberados e a troca de status acontecem juntas, então um voto
// concorrente ou entra na contagem ou é rejeitado (escrutínio fechado).
export const closeScrutiny = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<{stage: CargoStage; result: ScrutinyResult}> => {
  const electionId = requireString(data, "electionId");
  const position = requireString(data, "position");
  await assertElectionDirector(db, uid, electionId);

  const electionRef = db.doc(`elections/${electionId}`);
  const cargoRef = electionRef.collection("cargos").doc(position);

  const closed = await db.runTransaction(async (tx) => {
    const cargoSnap = await tx.get(cargoRef);
    const openRounds = await tx.get(
      electionRef.collection("rounds")
        .where("position", "==", position)
        .where("status", "==", "open")
        .limit(1)
    );
    if (!cargoSnap.exists) throw fail("not-found", "Cargo não encontrado.");
    if (openRounds.empty) {
      throw fail(
        "failed-precondition", "Não há escrutínio aberto para este cargo."
      );
    }
    const roundSnap = openRounds.docs[0];
    const ballots = await tx.get(roundSnap.ref.collection("ballots"));
    const voted = await tx.get(roundSnap.ref.collection("voted"));
    const approved = await tx.get(
      electionRef.collection("voters").where("status", "==", "approved")
    );

    const options = roundSnap.get("options") as Candidate[];
    const number = roundSnap.get("number") as Number123;
    const presentCount = approved.size;
    const tally = countBallots(
      options,
      ballots.docs.map((d) => String(d.get("choice"))),
      voted.size
    );
    const outcome = decideScrutiny({
      number, options, counts: tally.counts, presentCount,
    });
    const result: ScrutinyResult = {
      counts: tally.counts,
      blank: tally.blank,
      total: tally.total,
      presentCount,
      threshold: requiredVotes(presentCount),
      winnerId: outcome.stage === "decided" ? outcome.winnerId : null,
      tie: outcome.stage === "tiebreak" ? outcome.tiedIds : [],
      divergence: tally.divergence,
    };

    tx.update(roundSnap.ref, {
      status: "closed",
      closedAt: FieldValue.serverTimestamp(),
      votedCount: voted.size,
      result,
    });
    const cycle = Number(cargoSnap.get("cycle") ?? 1);
    const patch: Record<string, unknown> =
      outcome.stage === "confirming" ?
        {stage: "confirming", candidates: outcome.candidates} :
        outcome.stage === "decided" ?
          {stage: "decided", winnerId: outcome.winnerId} :
          outcome.stage === "tiebreak" ?
            {stage: "tiebreak", tiedIds: outcome.tiedIds} :
            outcome.stage === "idle" ?
              {
                stage: "idle", cycle: cycle + 1, candidates: [],
                tiedIds: [], winnerId: null,
              } :
              {stage: "awaiting3"};
    tx.update(cargoRef, patch);
    return {stage: outcome.stage, result, number};
  });

  await logEvent(db, electionId, {
    type: "scrutiny_closed",
    actorId: uid,
    position,
    number: closed.number,
    stage: closed.stage,
    winnerId: closed.result.winnerId,
    tie: closed.result.tie,
    total: closed.result.total,
    presentCount: closed.result.presentCount,
    divergence: closed.result.divergence,
  });
  return {stage: closed.stage, result: closed.result};
};

// Contador exibido ao vivo ("X de Y votaram"). Roda num gatilho, fora da
// transação do voto, para que os eleitores não disputem o mesmo documento.
// É só informativo: o encerramento grava o valor exato.
export const bumpVotedCount = async (
  db: Firestore,
  electionId: string,
  roundId: string
): Promise<void> => {
  const ref = db.doc(`elections/${electionId}/rounds/${roundId}`);
  // Só enquanto o escrutínio está aberto: um gatilho atrasado não pode inflar
  // o valor exato que o encerramento gravou.
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists || snap.get("status") !== "open") return;
    tx.update(ref, {votedCount: FieldValue.increment(1)});
  });
};
