/** Caminho de login que lembra para onde a pessoa queria ir. */
export function loginPathFor(pathname: string): string {
  if (pathname === "/" || pathname === "/login") return "/login";
  return `/login?next=${encodeURIComponent(pathname)}`;
}

/**
 * Destino pós-login vindo da URL. Só aceita caminho interno: qualquer outra
 * coisa (URL externa, `//host`, `/\host`) vira "/" para não virar open redirect.
 */
export function safeNextPath(raw: string | null): string {
  if (!raw || !raw.startsWith("/")) return "/";
  if (raw.startsWith("//") || raw.startsWith("/\\")) return "/";
  if (raw === "/login" || raw.startsWith("/login?")) return "/";
  return raw;
}
