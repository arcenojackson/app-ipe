import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {
  assertAdmin, fail, getElection, logEvent, requireString,
} from "./common";
import type {VoterKind, VoterStatus} from "./types";

export interface Caller {
  uid: string;
  isAnonymous: boolean;
  email?: string;
}

const str = (value: unknown): string =>
  typeof value === "string" ? value.trim() : "";

// Entrada do eleitor. Membro logado da sociedade entra aprovado; os demais
// ficam pendentes. Idempotente: repetir não altera o estado já gravado.
export const checkIn = async (
  db: Firestore,
  caller: Caller,
  data: unknown
): Promise<{status: VoterStatus; kind: VoterKind}> => {
  const electionId = requireString(data, "electionId");
  const election = await getElection(db, electionId);
  if (election.status !== "open") {
    throw fail(
      "failed-precondition", "A eleição não está aberta para entrada."
    );
  }

  const voterRef = db.doc(`elections/${electionId}/voters/${caller.uid}`);
  const existing = await voterRef.get();
  if (existing.exists) {
    return {status: existing.get("status"), kind: existing.get("kind")};
  }

  const society = await db.doc(`societies/${election.societyId}`).get();
  const members: string[] = (society.get("members") ?? []).map(String);
  const isMember = !caller.isAnonymous && members.includes(caller.uid);
  const userDoc = caller.isAnonymous ?
    undefined :
    (await db.doc(`users/${caller.uid}`).get()).data();

  const input = data as {name?: unknown; email?: unknown};
  const registered = str(userDoc?.name);
  const name = isMember ? registered : (str(input.name) || registered);
  if (!name) throw fail("invalid-argument", "Informe seu nome.");
  const email = caller.email ?? str(input.email);

  const kind: VoterKind = isMember ? "member" : "guest";
  const status: VoterStatus = isMember ? "approved" : "pending";

  try {
    await voterRef.create({
      name, email, kind, status, createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    // 6 = ALREADY_EXISTS: outra chamada simultânea criou primeiro.
    if ((error as {code?: number}).code === 6) {
      const again = await voterRef.get();
      return {status: again.get("status"), kind: again.get("kind")};
    }
    throw error;
  }
  await logEvent(db, electionId, {type: "checkin", voterId: caller.uid, kind});
  return {status, kind};
};

export const reviewVoter = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<void> => {
  await assertAdmin(db, uid);
  const electionId = requireString(data, "electionId");
  const voterId = requireString(data, "voterId");
  const decision = requireString(data, "decision");
  if (decision !== "approved" && decision !== "rejected") {
    throw fail("invalid-argument", "Decisão inválida.");
  }
  await getElection(db, electionId);
  const voterRef = db.doc(`elections/${electionId}/voters/${voterId}`);
  if (!(await voterRef.get()).exists) {
    throw fail("not-found", "Eleitor não encontrado.");
  }
  await voterRef.update({
    status: decision,
    reviewedBy: uid,
    reviewedAt: FieldValue.serverTimestamp(),
  });
  await logEvent(db, electionId, {
    type: "voter_reviewed", actorId: uid, voterId, decision,
  });
};
