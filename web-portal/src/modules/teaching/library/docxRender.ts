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

// Conteúdo ativo nunca fica na pré-visualização: um DOCX malicioso poderia
// trazer um iframe (altChunk) com script no mesmo domínio do portal.
const ACTIVE_SELECTOR = "iframe, frame, frameset, object, embed, script";

export function stripActiveContent(container: HTMLElement): void {
  for (const element of container.querySelectorAll(ACTIVE_SELECTOR)) element.remove();
}

// Desenha o DOCX no próprio navegador (sem enviar o arquivo a nenhum serviço).
// Devolve a função de limpeza.
export async function renderDocx(container: HTMLElement, bytes: ArrayBuffer): Promise<() => void> {
  const {renderAsync} = await import("docx-preview");
  container.replaceChildren();
  // renderAltChunks: false — a opção padrão gera <iframe srcdoc> com o HTML do arquivo.
  await renderAsync(bytes, container, undefined, {inWrapper: true, breakPages: false, renderAltChunks: false});
  stripActiveContent(container);
  sanitizeDocxLinks(container);
  return () => container.replaceChildren();
}
