import {afterEach, describe, expect, it, vi} from "vitest";
import {fileErrorMessage} from "./storageErrors";

afterEach(() => vi.restoreAllMocks());

describe("fileErrorMessage", () => {
  it("traduz permissão negada e arquivo inexistente; o resto usa o texto genérico", () => {
    vi.spyOn(console, "error").mockImplementation(() => undefined);
    expect(fileErrorMessage({code: "storage/unauthorized"}, "x")).toBe("Sem permissão para este arquivo.");
    expect(fileErrorMessage({code: "storage/object-not-found"}, "x")).toBe("Arquivo não encontrado.");
    expect(fileErrorMessage({code: "storage/retry-limit-exceeded"}, "x")).toBe("x");
    expect(fileErrorMessage(new Error("boom"), "x")).toBe("x");
    expect(fileErrorMessage(null, "x")).toBe("x");
  });
});
