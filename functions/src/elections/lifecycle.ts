import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {
  assertAdmin, fail, getElection, logEvent, requireString,
} from "./common";

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
