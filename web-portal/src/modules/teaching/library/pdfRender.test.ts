import {beforeEach, describe, expect, it, vi} from "vitest";
import {MAX_PDF_PAGES, renderPdf} from "./pdfRender";

const pdfjs = vi.hoisted(() => ({
  GlobalWorkerOptions: {workerSrc: ""},
  getDocument: vi.fn(),
}));
vi.mock("pdfjs-dist", () => pdfjs);

function fakeDocument(numPages: number) {
  const getPage = vi.fn(async () => ({
    getViewport: ({scale}: {scale: number}) => ({width: 100 * scale, height: 140 * scale}),
    render: () => ({promise: Promise.resolve()}),
  }));
  const destroy = vi.fn(async () => undefined);
  pdfjs.getDocument.mockReturnValue({promise: Promise.resolve({numPages, getPage}), destroy});
  return {getPage, destroy};
}

beforeEach(() => {
  pdfjs.getDocument.mockReset();
  HTMLCanvasElement.prototype.getContext = vi.fn(() => ({})) as never;
});

describe("renderPdf", () => {
  it("entrega ao pdf.js uma cópia dos bytes, sem desanexar o buffer original", async () => {
    fakeDocument(1);
    const bytes = new Uint8Array([1, 2, 3, 4]).buffer;
    await renderPdf(document.createElement("div"), bytes);
    const {data} = pdfjs.getDocument.mock.calls[0][0] as {data: Uint8Array};
    expect(data.buffer).not.toBe(bytes);
    expect(Array.from(data)).toEqual([1, 2, 3, 4]);
  });

  it("desenha só as primeiras MAX_PDF_PAGES páginas e avisa que há mais", async () => {
    const doc = fakeDocument(MAX_PDF_PAGES + 15);
    const container = document.createElement("div");
    await renderPdf(container, new ArrayBuffer(4));
    await vi.waitFor(() => expect(container.querySelectorAll("canvas")).toHaveLength(MAX_PDF_PAGES));
    expect(doc.getPage).toHaveBeenCalledTimes(MAX_PDF_PAGES);
    expect(container.textContent).toContain(`Mostrando as primeiras ${MAX_PDF_PAGES} páginas de ${MAX_PDF_PAGES + 15}`);
  });

  it("documento curto não mostra aviso; a limpeza destrói a tarefa", async () => {
    const doc = fakeDocument(2);
    const container = document.createElement("div");
    const stop = await renderPdf(container, new ArrayBuffer(4));
    await vi.waitFor(() => expect(container.querySelectorAll("canvas")).toHaveLength(2));
    expect(container.textContent).not.toContain("Mostrando as primeiras");
    stop();
    expect(doc.destroy).toHaveBeenCalled();
  });

  it("falha na primeira página libera o worker e propaga o erro", async () => {
    const destroy = vi.fn(async () => undefined);
    pdfjs.getDocument.mockReturnValue({promise: Promise.reject(new Error("senha")), destroy});
    await expect(renderPdf(document.createElement("div"), new ArrayBuffer(4))).rejects.toThrow("senha");
    expect(destroy).toHaveBeenCalled();
  });
});
