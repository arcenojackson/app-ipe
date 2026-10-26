import * as functions from "firebase-functions/v1";
import {FieldValue, type Firestore} from "firebase-admin/firestore";
import type {ElectionStatus} from "./types";

type ErrorCode = ConstructorParameters<typeof functions.https.HttpsError>[0];

export const fail = (code: ErrorCode, message: string) =>
  new functions.https.HttpsError(code, message);

export interface ElectionDoc {
  status: ElectionStatus;
  societyId: string;
  directorIds?: string[];
  positions?: string[];
  [key: string]: unknown;
}

// Sessão anônima (convidado da página de voto) nunca opera como admin, mesmo
// que exista um `users/{uid}` com is_admin gravado para esse uid.
export const assertNotAnonymous = (isAnonymous: boolean): void => {
  if (isAnonymous) {
    throw fail(
      "permission-denied", "Entre com uma conta do app para fazer isso."
    );
  }
};

export const requireString = (data: unknown, key: string): string => {
  const value = (data as Record<string, unknown> | null)?.[key];
  if (typeof value !== "string" || value.trim() === "") {
    throw fail("invalid-argument", `Campo obrigatório: ${key}.`);
  }
  return value.trim();
};

export const getElection = async (
  db: Firestore,
  electionId: string
): Promise<ElectionDoc> => {
  const snap = await db.doc(`elections/${electionId}`).get();
  if (!snap.exists) throw fail("not-found", "Eleição não encontrada.");
  return snap.data() as ElectionDoc;
};

// Log de auditoria só de escrita. Nunca registre quem votou em quê.
export const logEvent = async (
  db: Firestore,
  electionId: string,
  event: Record<string, unknown>
): Promise<void> => {
  await db.collection(`elections/${electionId}/events`).add({
    ...event,
    at: FieldValue.serverTimestamp(),
  });
};
