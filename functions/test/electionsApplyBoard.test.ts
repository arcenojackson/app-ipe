import {describe, expect, it} from "vitest";
import {assertCanApplyBoard} from "../src/elections/lifecycle";

describe("assertCanApplyBoard", () => {
  it("eleição em andamento pode ter a diretoria aplicada", () => {
    expect(() => assertCanApplyBoard("open")).not.toThrow();
  });

  it("eleição já concluída aceita repetir (idempotente até a posse)", () => {
    expect(() => assertCanApplyBoard("completed")).not.toThrow();
  });

  it("eleição encerrada não vale mais: não aplica", () => {
    expect(() => assertCanApplyBoard("closed")).toThrowError(
      expect.objectContaining({
        code: "failed-precondition",
        message: "Uma eleição encerrada não pode ter a diretoria aplicada.",
      })
    );
  });

  it("rascunho não aplica", () => {
    expect(() => assertCanApplyBoard("draft")).toThrowError(
      expect.objectContaining({code: "failed-precondition"})
    );
  });
});
