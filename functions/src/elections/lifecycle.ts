import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {applyWinners} from "./board";
import {
  assertAdmin, fail, getElection, logEvent, requireString, summarizeRound,
} from "./common";
import {pickWinners} from "./winners";

export const applyBoard = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<{winners: Record<string, string>}> => {
  await assertAdmin(db, uid);
  const electionId = requireString(data, "electionId");
  const election = await getElection(db, electionId);

  const rounds = await db.collection(`elections/${electionId}/rounds`).get();
  const winners = pickWinners(rounds.docs.map(summarizeRound));
  if (Object.keys(winners).length === 0) {
    throw fail("failed-precondition", "Nenhum cargo foi decidido ainda.");
  }

  const societyRef = db.doc(`societies/${election.societyId}`);
  await db.runTransaction(async (tx) => {
    const society = await tx.get(societyRef);
    if (!society.exists) throw fail("not-found", "Sociedade não encontrada.");
    tx.update(societyRef, {
      board: applyWinners(society.get("board"), winners),
    });
    tx.update(db.doc(`elections/${electionId}`), {
      boardAppliedAt: FieldValue.serverTimestamp(),
    });
  });
  await logEvent(db, electionId, {
    type: "board_applied", actorId: uid, winners,
  });
  return {winners};
};

export const setElectionStatus = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<void> => {
  await assertAdmin(db, uid);
  const electionId = requireString(data, "electionId");
  const target = requireString(data, "status");
  if (target !== "open" && target !== "closed") {
    throw fail("invalid-argument", "Status inválido.");
  }
  const election = await getElection(db, electionId);
  const ref = db.doc(`elections/${electionId}`);

  if (target === "open") {
    if (election.status !== "draft") {
      throw fail(
        "failed-precondition", "Só é possível abrir uma eleição em rascunho."
      );
    }
    await ref.update({status: "open", openedAt: FieldValue.serverTimestamp()});
  } else {
    if (election.status !== "open") {
      throw fail(
        "failed-precondition", "Só é possível encerrar uma eleição aberta."
      );
    }
    const open = await ref.collection("rounds")
      .where("status", "==", "open").limit(1).get();
    if (!open.empty) {
      throw fail(
        "failed-precondition",
        "Encerre a votação em andamento antes de encerrar a eleição."
      );
    }
    await ref.update({
      status: "closed", closedAt: FieldValue.serverTimestamp(),
    });
  }
  await logEvent(db, electionId, {
    type: target === "open" ? "election_opened" : "election_closed",
    actorId: uid,
  });
};
