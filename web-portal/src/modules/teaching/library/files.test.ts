import {describe, expect, it} from "vitest";
import {
  MAX_FILE_BYTES,
  contentTypeFor,
  safeFileName,
  storagePathFor,
  validateDescription,
  validateFile,
  validateName,
  validateUrl,
} from "./files";

describe("validateName", () => {
  it("aceita de 1 a 120 caracteres e recusa vazio ou só espaços", () => {
    expect(validateName("Aula 1")).toBeNull();
    expect(validateName("a".repeat(120))).toBeNull();
    expect(validateName("")).toBe("Informe um nome.");
    expect(validateName("   ")).toBe("Informe um nome.");
    expect(validateName("a".repeat(121))).toBe("O nome pode ter no máximo 120 caracteres.");
  });
});

describe("validateUrl", () => {
  it("aceita http e https; recusa outros esquemas, vazio e URL muito longa", () => {
    expect(validateUrl("https://exemplo.org/livro")).toBeNull();
    expect(validateUrl("http://exemplo.org")).toBeNull();
    expect(validateUrl("javascript:alert(1)")).toBe("Use um endereço que comece com http:// ou https://.");
    expect(validateUrl("ftp://x.org")).toBe("Use um endereço que comece com http:// ou https://.");
    expect(validateUrl("HTTP://x.org")).toBe("Use um endereço que comece com http:// ou https://.");
    expect(validateUrl("Https://x.org")).toBe("Use um endereço que comece com http:// ou https://.");
    expect(validateUrl("")).toBe("Informe o endereço do link.");
    expect(validateUrl(`https://x.org/${"a".repeat(2000)}`)).toBe("O endereço é muito longo.");
  });
});

describe("contentTypeFor e validateFile", () => {
  it("usa o tipo do navegador quando existe e a extensão quando vem vazio", () => {
    expect(contentTypeFor({name: "a.pdf", type: "application/pdf"})).toBe("application/pdf");
    expect(contentTypeFor({name: "a.DOCX", type: ""})).toBe("application/vnd.openxmlformats-officedocument.wordprocessingml.document");
    expect(contentTypeFor({name: "a.pptx", type: ""})).toBe("application/vnd.openxmlformats-officedocument.presentationml.presentation");
    expect(contentTypeFor({name: "a.odt", type: ""})).toBe("application/vnd.oasis.opendocument.text");
    expect(contentTypeFor({name: "a.xyz", type: ""})).toBe("");
  });

  it("recusa arquivo vazio, grande demais ou de tipo não permitido", () => {
    expect(validateFile({name: "a.pdf", size: 10, type: "application/pdf"})).toBeNull();
    expect(validateFile({name: "a.png", size: 10, type: "image/png"})).toBeNull();
    expect(validateFile({name: "a.pdf", size: 0, type: "application/pdf"})).toBe("O arquivo está vazio.");
    expect(validateFile({name: "a.pdf", size: MAX_FILE_BYTES + 1, type: "application/pdf"})).toBe("O arquivo passa de 100 MB.");
    expect(validateFile({name: "a.exe", size: 10, type: "application/x-msdownload"})).toBe("Tipo de arquivo não permitido. Use PDF, Office ou imagem.");
    expect(validateFile({name: "a".repeat(201) + ".pdf", size: 10, type: "application/pdf"})).toBe("O nome do arquivo é muito longo.");
  });

  it("usa a extensão quando o tipo do navegador é genérico ou não permitido", () => {
    expect(contentTypeFor({name: "a.docx", type: "application/octet-stream"})).toBe("application/vnd.openxmlformats-officedocument.wordprocessingml.document");
    expect(contentTypeFor({name: "a.exe", type: "application/x-msdownload"})).toBe("application/x-msdownload");
    expect(validateFile({name: "a.docx", size: 10, type: "application/octet-stream"})).toBeNull();
  });

  it("aceita imagem com tipo vazio pela extensão", () => {
    expect(contentTypeFor({name: "a.png", type: ""})).toBe("image/png");
    expect(contentTypeFor({name: "a.JPG", type: ""})).toBe("image/jpeg");
    expect(contentTypeFor({name: "a.jpeg", type: ""})).toBe("image/jpeg");
    expect(contentTypeFor({name: "a.gif", type: ""})).toBe("image/gif");
    expect(contentTypeFor({name: "a.webp", type: ""})).toBe("image/webp");
    expect(validateFile({name: "foto.png", size: 10, type: ""})).toBeNull();
  });

  it("não confunde nomes como constructor, toString ou 'pdf' sem ponto com extensões", () => {
    expect(() => contentTypeFor({name: "x.constructor", type: ""})).not.toThrow();
    expect(contentTypeFor({name: "x.constructor", type: ""})).toBe("");
    expect(contentTypeFor({name: "x.toString", type: ""})).toBe("");
    expect(contentTypeFor({name: "__proto__", type: ""})).toBe("");
    expect(contentTypeFor({name: "pdf", type: ""})).toBe("");
    expect(validateFile({name: "pdf", size: 10, type: ""})).toBe("Tipo de arquivo não permitido. Use PDF, Office ou imagem.");
  });

  it("recusa nome que fica vazio depois de limpo", () => {
    expect(validateFile({name: "   ", size: 10, type: "application/pdf"})).toBe("O nome do arquivo é inválido.");
  });
});

describe("validateDescription", () => {
  it("aceita até 1000 caracteres", () => {
    expect(validateDescription("")).toBeNull();
    expect(validateDescription("a".repeat(1000))).toBeNull();
    expect(validateDescription("a".repeat(1001))).toBe("A descrição pode ter no máximo 1000 caracteres.");
  });
});

describe("safeFileName e storagePathFor", () => {
  it("remove barras e mantém o resto", () => {
    expect(safeFileName("a/b\\c.pdf")).toBe("a_b_c.pdf");
    expect(safeFileName("  aula 1.pdf ")).toBe("aula 1.pdf");
  });

  it("monta o caminho no formato que as regras exigem", () => {
    expect(storagePathFor("abc123", 1, "aula 1.pdf")).toBe("teaching/materials/abc123/v1-aula 1.pdf");
    expect(storagePathFor("abc123", 3, "a/b.pdf")).toBe("teaching/materials/abc123/v3-a_b.pdf");
  });
});
