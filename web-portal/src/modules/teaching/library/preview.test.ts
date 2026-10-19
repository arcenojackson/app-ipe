import {describe, expect, it} from "vitest";
import {previewKind} from "./preview";

describe("previewKind", () => {
  it("PDF e imagens têm visualização; o resto não", () => {
    expect(previewKind("application/pdf")).toBe("pdf");
    expect(previewKind("image/png")).toBe("image");
    expect(previewKind("image/jpeg")).toBe("image");
    expect(previewKind("application/vnd.openxmlformats-officedocument.wordprocessingml.document")).toBe("other");
    expect(previewKind(undefined)).toBe("other");
  });
});
