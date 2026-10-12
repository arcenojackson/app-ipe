export type TeachingRole = "teacher" | "curator";

export interface TeachingClaims {
  admin?: true;
  teaching_role?: TeachingRole;
}

const CLAIM_KEYS = ["admin", "teaching_role"] as const;

/**
 * Calcula as custom claims de ensino a partir do documento users/{uid}.
 * Só `is_admin === true` vale como admin (igual às regras do Firestore).
 * @param {Record<string, unknown> | undefined} userData - dados do usuário
 * @return {TeachingClaims} claims derivadas do documento
 */
export function computeTeachingClaims(
  userData: Record<string, unknown> | undefined
): TeachingClaims {
  const claims: TeachingClaims = {};
  if (!userData) return claims;
  if (userData.is_admin === true) claims.admin = true;
  const role = userData.teaching_role;
  if (role === "teacher" || role === "curator") claims.teaching_role = role;
  return claims;
}

/**
 * Compara dois conjuntos de claims de ensino.
 * @param {TeachingClaims} a - primeiro conjunto
 * @param {TeachingClaims} b - segundo conjunto
 * @return {boolean} true quando são equivalentes
 */
export function claimsEqual(a: TeachingClaims, b: TeachingClaims): boolean {
  return a.admin === b.admin && a.teaching_role === b.teaching_role;
}

/**
 * Aplica as claims de ensino sobre as claims existentes, preservando
 * qualquer claim que não seja de ensino.
 * @param {Record<string, unknown> | undefined} existing - claims atuais
 * @param {TeachingClaims} next - claims de ensino calculadas
 * @return {Record<string, unknown>} claims finais a gravar
 */
export function mergeTeachingClaims(
  existing: Record<string, unknown> | undefined,
  next: TeachingClaims
): Record<string, unknown> {
  const merged: Record<string, unknown> = {...(existing ?? {})};
  for (const key of CLAIM_KEYS) delete merged[key];
  return {...merged, ...next};
}
