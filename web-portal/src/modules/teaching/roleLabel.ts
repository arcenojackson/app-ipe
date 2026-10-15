import type {AccessClaims} from "@/core/auth/access";

/** Rótulo (pt-BR) do papel real no grupo de ensino; o papel atribuído tem prioridade sobre admin. */
export function teachingRoleLabel(claims: AccessClaims): string {
  if (claims.teachingRole === "curator") return "Curador";
  if (claims.teachingRole === "teacher") return "Professor";
  if (claims.admin) return "Administrador";
  return "Sem papel no grupo";
}
