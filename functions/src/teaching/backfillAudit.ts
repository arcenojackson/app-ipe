import {TeachingClaims} from "./claims";

export interface BackfillCounts {
  read: number;
  admins: number;
  teachers: number;
  curators: number;
  wouldChange: number;
  unchanged: number;
  noAuthAccount: number;
  failed: number;
}

/**
 * Indica se o modo dry-run foi pedido na linha de comando.
 * @param {string[]} argv - argumentos (process.argv)
 * @return {boolean} true quando `--dry-run` está presente
 */
export function isDryRun(argv: string[]): boolean {
  return argv.includes("--dry-run");
}

/**
 * Linha de modo exibida no início da execução.
 * @param {boolean} dryRun - se é dry-run
 * @return {string} texto do modo
 */
export function formatMode(dryRun: boolean): string {
  return dryRun ?
    "Modo: DRY-RUN (nada será gravado)" :
    "Modo: GRAVAÇÃO";
}

/**
 * Indica se o documento entra na auditoria (admin ou papel de ensino válido).
 * @param {Record<string, unknown>} data - dados do documento users/{uid}
 * @return {boolean} true quando deve ser listado
 */
export function isAuditedUser(data: Record<string, unknown>): boolean {
  return (
    data.is_admin === true ||
    data.teaching_role === "teacher" ||
    data.teaching_role === "curator"
  );
}

/**
 * Formata claims de ensino de forma legível.
 * @param {TeachingClaims} claims - claims
 * @return {string} texto como `{admin: true, teaching_role: teacher}`
 */
export function formatClaims(claims: TeachingClaims): string {
  const parts: string[] = [];
  if (claims.admin) parts.push("admin: true");
  if (claims.teaching_role) {
    parts.push(`teaching_role: ${claims.teaching_role}`);
  }
  return `{${parts.join(", ")}}`;
}

/**
 * Linha de auditoria de um usuário (valores como gravados no documento).
 * @param {string} uid - id do usuário
 * @param {Record<string, unknown>} data - dados do documento
 * @return {string} linha formatada
 */
export function formatUserLine(
  uid: string,
  data: Record<string, unknown>
): string {
  const show = (v: unknown): string =>
    v === undefined || v === null || v === "" ? "-" : String(v);
  return (
    `  uid=${uid} | nome=${show(data.name)} | email=${show(data.email)} | ` +
    `is_admin=${show(data.is_admin)} | ` +
    `teaching_role=${show(data.teaching_role)}`
  );
}

/**
 * Linha descrevendo a mudança que uma execução real faria.
 * @param {string} uid - id do usuário
 * @param {string | undefined} email - email (do Auth)
 * @param {TeachingClaims} current - claims atuais no Auth
 * @param {TeachingClaims} desired - claims desejadas
 * @return {string} linha formatada
 */
export function formatChangeLine(
  uid: string,
  email: string | undefined,
  current: TeachingClaims,
  desired: TeachingClaims
): string {
  return (
    `  uid=${uid} | email=${email || "-"} | ` +
    `atual=${formatClaims(current)} | desejado=${formatClaims(desired)}`
  );
}

/**
 * Linha de usuário sem conta no Auth.
 * @param {string} uid - id do usuário
 * @param {Record<string, unknown>} data - dados do documento
 * @return {string} linha formatada
 */
export function formatMissingLine(
  uid: string,
  data: Record<string, unknown>
): string {
  const email = data.email ? String(data.email) : "-";
  return `  uid=${uid} | email=${email} | sem conta no Auth`;
}

/**
 * Resumo final do dry-run, terminando com a confirmação de que nada foi
 * gravado.
 * @param {BackfillCounts} c - contadores
 * @return {string[]} linhas do resumo
 */
export function formatDryRunSummary(c: BackfillCounts): string[] {
  return [
    "Resumo (dry-run):",
    `  Usuários lidos: ${c.read}`,
    `  Admins: ${c.admins}`,
    `  Professores: ${c.teachers}`,
    `  Curadores: ${c.curators}`,
    `  Mudariam: ${c.wouldChange}`,
    `  Sem mudança: ${c.unchanged}`,
    `  Sem conta no Auth: ${c.noAuthAccount}`,
    `  Falhas: ${c.failed}`,
    "DRY-RUN: nada foi gravado.",
  ];
}
