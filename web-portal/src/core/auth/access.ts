export type TeachingRole = "teacher" | "curator";

export interface AccessClaims {
  admin: boolean;
  teachingRole: TeachingRole | null;
}

export type AccessRequirement = "authenticated" | "teacher" | "curator" | "admin";

export function parseClaims(
  raw: Record<string, unknown> | null | undefined
): AccessClaims {
  const role = raw?.teaching_role;
  return {
    admin: raw?.admin === true,
    teachingRole: role === "teacher" || role === "curator" ? role : null,
  };
}

/** `claims === null` significa deslogado. Admin é superconjunto de tudo. */
export function hasAccess(
  claims: AccessClaims | null,
  requirement: AccessRequirement
): boolean {
  if (claims === null) return false;
  if (claims.admin) return true;
  switch (requirement) {
    case "authenticated":
      return true;
    case "teacher":
      return claims.teachingRole === "teacher" || claims.teachingRole === "curator";
    case "curator":
      return claims.teachingRole === "curator";
    case "admin":
      return false;
  }
}
