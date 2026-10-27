export type TeachingRole = "teacher" | "curator";

export interface AccessClaims {
  admin: boolean;
  teachingRole: TeachingRole | null;
}

// "teachingManager": quem gerencia papéis de ensino. Exige ser Curador E admin
// (o servidor só deixa admin gravar `teaching_role`); admin sem papel de curador
// e curador sem admin não gerenciam.
export type AccessRequirement =
  | "authenticated"
  | "teacher"
  | "curator"
  | "admin"
  | "teachingManager";

export function parseClaims(
  raw: Record<string, unknown> | null | undefined
): AccessClaims {
  const role = raw?.teaching_role;
  return {
    admin: raw?.admin === true,
    teachingRole: role === "teacher" || role === "curator" ? role : null,
  };
}

/**
 * `claims === null` significa deslogado. Admin NÃO dá acesso ao ensino: só
 * "authenticated" e "admin". Teacher/curator exigem o papel de ensino (também
 * para admin). Restrição só do portal; as regras do Firestore continuam
 * liberando admin.
 */
export function hasAccess(
  claims: AccessClaims | null,
  requirement: AccessRequirement
): boolean {
  if (claims === null) return false;
  switch (requirement) {
    case "authenticated":
      return true;
    case "teacher":
      return claims.teachingRole === "teacher" || claims.teachingRole === "curator";
    case "curator":
      return claims.teachingRole === "curator";
    case "admin":
      return claims.admin;
    case "teachingManager":
      return claims.admin && claims.teachingRole === "curator";
  }
}
