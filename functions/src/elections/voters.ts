import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {assertElectionDirector} from "./directors";
import {
  assertNotAnonymous,
  fail,
  getElection,
  logEvent,
  requireString,
} from "./common";
import type {VoterKind, VoterStatus} from "./types";

export interface Caller {
  uid: string;
  isAnonymous: boolean;
  email?: string;
  // Nome da conta (ex.: nome do perfil Google), vindo do token.
  name?: string;
}

const str = (value: unknown): string =>
  typeof value === "string" ? value.trim() : "";

const isAlreadyExists = (error: unknown): boolean =>
  (error as {code?: number}).code === 6;

// Entrada do eleitor. Exige conta de verdade (Google ou e-mail/senha do app).
// Membro da sociedade entra aprovado; os demais ficam pendentes e, se ainda
// não têm cadastro, são cadastrados como usuário novo (igual ao login Google
// do app). Idempotente: repetir não altera o estado já gravado.
export const checkIn = async (
  db: Firestore,
  caller: Caller,
  data: unknown
): Promise<{status: VoterStatus; kind: VoterKind}> => {
  assertNotAnonymous(caller.isAnonymous);
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
  const isMember = members.includes(caller.uid);

  const userRef = db.doc(`users/${caller.uid}`);
  const userSnap = await userRef.get();
  const input = data as {name?: unknown};
  const name = str(userSnap.get("name")) ||
    str(caller.name) ||
    str(input.name);
  if (!name) throw fail("invalid-argument", "Informe seu nome.");
  const email = str(caller.email) || str(userSnap.get("email"));

  if (!userSnap.exists) {
    // Conta nova: cadastra como usuário pendente (mesmos campos do app).
    try {
      await userRef.create({
        id: caller.uid, name, email, is_admin: false, is_pending: true,
      });
    } catch (error) {
      if (!isAlreadyExists(error)) throw error;
    }
  }

  const kind: VoterKind = isMember ? "member" : "guest";
  const status: VoterStatus = isMember ? "approved" : "pending";

  try {
    await voterRef.create({
      name, email, kind, status, createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    // Outra chamada simultânea criou primeiro.
    if (isAlreadyExists(error)) {
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
  const electionId = requireString(data, "electionId");
  const voterId = requireString(data, "voterId");
  const decision = requireString(data, "decision");
  await assertElectionDirector(db, uid, electionId);
  if (decision !== "approved" && decision !== "rejected") {
    throw fail("invalid-argument", "Decisão inválida.");
  }
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
