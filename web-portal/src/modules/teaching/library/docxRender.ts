const SAFE_SCHEMES = new Set(["http", "https", "mailto"]);

// Links de um DOCX vêm de terceiros: só http(s) e mailto continuam clicáveis, e
// sempre em nova aba. Navegadores ignoram espaços, tabs e quebras de linha
// dentro do esquema ("java\nscript:"), então o esquema é lido sem eles.
export function sanitizeDocxLinks(container: HTMLElement): void {
  for (const anchor of container.querySelectorAll("a")) {
    const href = anchor.getAttribute("href");
    if (href === null) continue;
    // Remove controles e espaços, como o parser de URL.
    const compact = href.replace(/[\u0000- \u007f]/g, "");
    const scheme = /^([a-zA-Z][a-zA-Z0-9+.-]*):/.exec(compact)?.[1]?.toLowerCase();
    if (scheme && !SAFE_SCHEMES.has(scheme)) {
      anchor.removeAttribute("href");
      continue;
    }
    anchor.setAttribute("target", "_blank");
    anchor.setAttribute("rel", "noopener noreferrer");
  }
}

// Desenha o DOCX no próprio navegador (sem enviar o arquivo a nenhum serviço).
// Devolve a função de limpeza.
export async function renderDocx(container: HTMLElement, bytes: ArrayBuffer): Promise<() => void> {
  const {renderAsync} = await import("docx-preview");
  container.replaceChildren();
  await renderAsync(bytes, container, undefined, {inWrapper: true, breakPages: false});
  sanitizeDocxLinks(container);
  return () => container.replaceChildren();
}
