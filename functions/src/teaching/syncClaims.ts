import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {
  claimsEqual,
  computeTeachingClaims,
  currentTeachingClaims,
  mergeTeachingClaims,
} from "./claims";

type UserData = Record<string, unknown>;

export interface ClaimsAuth {
  getUser(uid: string): Promise<{customClaims?: Record<string, unknown>}>;
  setCustomUserClaims(
    uid: string,
    claims: Record<string, unknown> | null
  ): Promise<void>;
}

export interface DocSnapshotLike {
  exists: boolean;
  data(): UserData | undefined;
}

/**
 * Converte um snapshot de documento nos seus dados (ou undefined).
 * @param {DocSnapshotLike} snapshot - snapshot do documento
 * @return {UserData | undefined} dados do documento, se existir
 */
export function readSnapshotData(
  snapshot: DocSnapshotLike
): UserData | undefined {
  return snapshot.exists ? snapshot.data() : undefined;
}

/**
 * Copia teaching_role e is_admin de users/{uid} para as custom claims do
 * usuário. O evento só serve para decidir se vale a pena sincronizar; a
 * fonte da verdade é o documento atual, relido via readUser, para que
 * eventos atrasados ou repetidos fora de ordem não restaurem claims antigas.
 * @param {ClaimsAuth} auth - cliente do Firebase Auth (injetável em testes)
 * @param {string} uid - id do usuário
 * @param {UserData | undefined} before - documento antes da escrita
 * @param {UserData | undefined} after - documento depois da escrita
 * @param {Function} readUser - lê o documento users/{uid} atual
 * @return {Promise<string>} "updated" quando gravou, "skipped" caso contrário
 */
export async function syncTeachingClaims(
  auth: ClaimsAuth,
  uid: string,
  before: UserData | undefined,
  after: UserData | undefined,
  readUser: (uid: string) => Promise<UserData | undefined>
): Promise<"updated" | "skipped"> {
  if (
    claimsEqual(computeTeachingClaims(before), computeTeachingClaims(after))
  ) {
    return "skipped";
  }

  const desired = computeTeachingClaims(await readUser(uid));

  let existing: Record<string, unknown> | undefined;
  try {
    const user = await auth.getUser(uid);
    existing = user.customClaims;
  } catch (error) {
    if ((error as {code?: string}).code === "auth/user-not-found") {
      return "skipped";
    }
    throw error;
  }

  if (claimsEqual(desired, currentTeachingClaims(existing))) {
    return "skipped";
  }

  await auth.setCustomUserClaims(uid, mergeTeachingClaims(existing, desired));
  return "updated";
}

export const syncTeachingClaimsOnUserWrite = functions
  .runWith({failurePolicy: true})
  .firestore.document("users/{userId}")
  .onWrite(async (change, context) => {
    const {userId} = context.params;
    try {
      await syncTeachingClaims(
        admin.auth(),
        userId,
        readSnapshotData(change.before),
        readSnapshotData(change.after),
        async (uid) =>
          readSnapshotData(await admin.firestore().doc(`users/${uid}`).get())
      );
    } catch (error) {
      console.error("Erro ao sincronizar claims de ensino:", error);
      // A operação é idempotente (recalcula as claims a partir do
      // documento), então repetir o evento é seguro. Relançar permite o
      // retry em falhas transitórias do Auth, para que uma revogação de
      // papel não deixe de ser aplicada.
      throw error;
    }
    return null;
  });
