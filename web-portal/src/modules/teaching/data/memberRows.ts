export type TeachingRoleValue = "none" | "teacher" | "curator";

export interface MemberRow {
  id: string;
  name: string;
  email: string;
  teachingRole: TeachingRoleValue;
  isAdmin: boolean;
  isPending: boolean;
}

export const ROLE_LABELS: Record<TeachingRoleValue, string> = {
  none: "Sem acesso",
  teacher: "Professor",
  curator: "Curador",
};

export function toMemberRow(id: string, data: Record<string, unknown>): MemberRow {
  const role = data.teaching_role;
  return {
    id,
    name: typeof data.name === "string" && data.name ? data.name : "(sem nome)",
    email: typeof data.email === "string" ? data.email : "",
    teachingRole: role === "teacher" || role === "curator" ? role : "none",
    isAdmin: data.is_admin === true,
    isPending: data.is_pending === true,
  };
}

function normalize(text: string): string {
  return text.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase();
}

export function filterMembers(rows: MemberRow[], term: string): MemberRow[] {
  const needle = normalize(term.trim());
  if (!needle) return rows;
  return rows.filter(
    (row) => normalize(row.name).includes(needle) || normalize(row.email).includes(needle)
  );
}
