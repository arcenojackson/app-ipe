// Desenha um PDF no próprio navegador: uma <canvas> por página, na largura do
// container. Resolve quando a primeira página está pronta e segue desenhando as
// demais; a função devolvida interrompe e libera o documento.
export async function renderPdf(container: HTMLElement, bytes: ArrayBuffer): Promise<() => void> {
  const pdfjs = await import("pdfjs-dist");
  pdfjs.GlobalWorkerOptions.workerSrc = new URL("pdfjs-dist/build/pdf.worker.min.mjs", import.meta.url).toString();

  const task = pdfjs.getDocument({data: new Uint8Array(bytes)});
  const pdf = await task.promise;
  let cancelled = false;
  container.replaceChildren();

  const drawPage = async (number: number) => {
    const page = await pdf.getPage(number);
    if (cancelled) return;
    const base = page.getViewport({scale: 1});
    const width = container.clientWidth || base.width;
    const viewport = page.getViewport({scale: width / base.width});
    const ratio = window.devicePixelRatio || 1;
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

  await drawPage(1);
  void (async () => {
    for (let number = 2; number <= pdf.numPages && !cancelled; number++) {
      try {
        await drawPage(number);
      } catch {
        return;
      }
    }
  })();

  return () => {
    cancelled = true;
    void task.destroy();
    container.replaceChildren();
  };
}
