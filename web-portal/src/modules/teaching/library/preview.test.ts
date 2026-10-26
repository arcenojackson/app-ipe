import {describe, expect, it} from "vitest";
import {MAX_INLINE_PREVIEW_BYTES, previewKind} from "./preview";

const DOCX = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";

describe("previewKind", () => {
  it("PDF, imagens e DOCX têm visualização; o resto não", () => {
    expect(previewKind("application/pdf")).toBe("pdf");
    expect(previewKind("image/png")).toBe("image");
    expect(previewKind("image/jpeg")).toBe("image");
    expect(previewKind(DOCX)).toBe("docx");
    expect(previewKind(undefined)).toBe("other");
  });

  it("DOCX também é reconhecido pelo nome, sem diferenciar caixa, mesmo com tipo vazio", () => {
    expect(previewKind("", "RELATORIO.DOCX")).toBe("docx");
    expect(previewKind("application/octet-stream", "aula.docx")).toBe("docx");
  });

  it(".doc, planilhas, apresentações e zip não têm visualização", () => {
    expect(previewKind("application/msword", "a.doc")).toBe("other");
    expect(previewKind("application/vnd.ms-excel", "a.xls")).toBe("other");
    expect(previewKind("application/zip", "a.zip")).toBe("other");
    expect(previewKind("", "docx")).toBe("other");
  });

  it("o limite de visualização embutida é de 50 MB", () => {
    expect(MAX_INLINE_PREVIEW_BYTES).toBe(50 * 1024 * 1024);
  });
});
