import type {Firestore} from "firebase-admin/firestore";
import {fail, logEvent, requireString} from "./common";
import {assertElectionDirector} from "./directors";
import type {CandidateVotes} from "./types";

const cargoRefOf = (db: Firestore, electionId: string, position: string) =>
  db.doc(`elections/${electionId}/cargos/${position}`);

// Tira um candidato que declinou. Vale só para este cargo: a pessoa continua
// liberada para votar e volta a ser opção quando outro cargo começar.
export const removeCandidate = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<void> => {
  const electionId = requireString(data, "electionId");
  const position = requireString(data, "position");
  const candidateId = requireString(data, "candidateId");
  await assertElectionDirector(db, uid, electionId);

  const ref = cargoRefOf(db, electionId, position);
  const removed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw fail("not-found", "Cargo não encontrado.");
    if (snap.get("stage") !== "confirming") {
      throw fail(
        "failed-precondition",
        "Só é possível remover candidatos na confirmação."
      );
    }
    const candidates = snap.get("candidates") as CandidateVotes[];
    const target = candidates.find((c) => c.id === candidateId);
    if (!target) {
      throw fail("failed-precondition", "Esta pessoa não é candidata.");
    }
    tx.update(ref, {
      candidates: candidates.filter((c) => c.id !== candidateId),
    });
    return target;
  });
  await logEvent(db, electionId, {
    type: "candidate_removed",
    actorId: uid,
    position,
    candidateId,
    candidateName: removed.name,
  });
};

// Recomeça o cargo do 1º escrutínio: só quando não sobrou candidato na
// confirmação (ou o cargo já está parado).
export const restartCargo = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<void> => {
  const electionId = requireString(data, "electionId");
  const position = requireString(data, "position");
  await assertElectionDirector(db, uid, electionId);

  const ref = cargoRefOf(db, electionId, position);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw fail("not-found", "Cargo não encontrado.");
    const stage = snap.get("stage");
    const empty = (snap.get("candidates") as unknown[]).length === 0;
    if (!(stage === "idle" || (stage === "confirming" && empty))) {
      throw fail(
        "failed-precondition", "Este cargo não pode ser reiniciado agora."
      );
    }
    tx.update(ref, {
      stage: "idle",
      cycle: Number(snap.get("cycle") ?? 1) + 1,
      candidates: [],
      tiedIds: [],
      winnerId: null,
    });
  });
  await logEvent(db, electionId, {
    type: "cargo_restarted", actorId: uid, position,
  });
};

// Empate no topo do 3º escrutínio: o diretor escolhe o mais velho.
export const pickOldest = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<void> => {
  const electionId = requireString(data, "electionId");
  const position = requireString(data, "position");
  const candidateId = requireString(data, "candidateId");
  await assertElectionDirector(db, uid, electionId);

  const ref = cargoRefOf(db, electionId, position);
  const picked = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw fail("not-found", "Cargo não encontrado.");
    if (snap.get("stage") !== "tiebreak") {
      throw fail("failed-precondition", "Este cargo não está em desempate.");
    }
    if (!(snap.get("tiedIds") as string[]).includes(candidateId)) {
      throw fail("invalid-argument", "Escolha uma das pessoas empatadas.");
    }
    tx.update(ref, {stage: "decided", winnerId: candidateId, tiedIds: []});
    const candidates = snap.get("candidates") as CandidateVotes[];
    return candidates.find((c) => c.id === candidateId)?.name ?? "";
  });
  await logEvent(db, electionId, {
    type: "oldest_picked",
    actorId: uid,
    position,
    candidateId,
    candidateName: picked,
  });
};
