import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {
  claimsEqual,
  computeTeachingClaims,
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

/**
 * Copia teaching_role e is_admin de users/{uid} para as custom claims do
 * usuário, só quando algo que afeta o acesso mudou.
 * @param {ClaimsAuth} auth - cliente do Firebase Auth (injetável em testes)
 * @param {string} uid - id do usuário
 * @param {UserData | undefined} before - documento antes da escrita
 * @param {UserData | undefined} after - documento depois da escrita
 * @return {Promise<string>} "updated" quando gravou, "skipped" caso contrário
 */
export async function syncTeachingClaims(
  auth: ClaimsAuth,
  uid: string,
  before: UserData | undefined,
  after: UserData | undefined
): Promise<"updated" | "skipped"> {
  const beforeClaims = computeTeachingClaims(before);
  const afterClaims = computeTeachingClaims(after);
  if (claimsEqual(beforeClaims, afterClaims)) return "skipped";

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

  await auth.setCustomUserClaims(
    uid,
    mergeTeachingClaims(existing, afterClaims)
  );
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
        change.before.exists ? change.before.data() : undefined,
        change.after.exists ? change.after.data() : undefined
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
