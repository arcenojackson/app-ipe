// Limites de memória: cada página vira uma <canvas> retida (~3 a 8 MB).
export const MAX_PDF_PAGES = 20;
const MAX_PIXEL_RATIO = 1.5;

// Desenha um PDF no próprio navegador: uma <canvas> por página, na largura do
// container. Resolve quando a primeira página está pronta e segue desenhando as
// demais; a função devolvida interrompe e libera o documento.
export async function renderPdf(container: HTMLElement, bytes: ArrayBuffer): Promise<() => void> {
  const pdfjs = await import("pdfjs-dist");
  pdfjs.GlobalWorkerOptions.workerSrc = new URL("pdfjs-dist/build/pdf.worker.min.mjs", import.meta.url).toString();

  // Cópia: o pdf.js transfere o buffer ao worker e o original ficaria vazio.
  const task = pdfjs.getDocument({data: new Uint8Array(bytes.slice(0))});
  let pdf;
  try {
    pdf = await task.promise;
  } catch (error) {
    void task.destroy();
    throw error;
  }
  let cancelled = false;
  container.replaceChildren();

  const drawPage = async (number: number) => {
    const page = await pdf.getPage(number);
    if (cancelled) return;
    const base = page.getViewport({scale: 1});
    const width = container.clientWidth || base.width;
    const viewport = page.getViewport({scale: width / base.width});
    const ratio = Math.min(window.devicePixelRatio || 1, MAX_PIXEL_RATIO);
    const canvas = document.createElement("canvas");
    canvas.width = Math.floor(viewport.width * ratio);
    canvas.height = Math.floor(viewport.height * ratio);
    canvas.style.width = `${Math.floor(viewport.width)}px`;
    canvas.style.height = `${Math.floor(viewport.height)}px`;
    canvas.className = "mb-3 max-w-full bg-white";
    const context = canvas.getContext("2d");
    if (!context) throw new Error("canvas indisponível");
    await page.render({
      canvas,
      canvasContext: context,
      viewport,
      transform: ratio === 1 ? undefined : [ratio, 0, 0, ratio, 0, 0],
    }).promise;
    if (!cancelled) container.appendChild(canvas);
  };

  try {
    await drawPage(1);
  } catch (error) {
    cancelled = true;
    void task.destroy();
    throw error;
  }
  const shown = Math.min(pdf.numPages, MAX_PDF_PAGES);
  void (async () => {
    for (let number = 2; number <= shown && !cancelled; number++) {
      try {
        await drawPage(number);
      } catch {
        break;
      }
    }
    if (!cancelled && pdf.numPages > shown) {
      const note = document.createElement("p");
      note.className = "p-3 text-sm text-black";
      note.textContent = `Mostrando as primeiras ${shown} páginas de ${pdf.numPages}. Baixe para ver o restante.`;
      container.appendChild(note);
    }
  })();

  return () => {
    cancelled = true;
    void task.destroy();
    container.replaceChildren();
  };
}
