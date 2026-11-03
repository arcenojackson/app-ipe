import {describe, expect, it} from "vitest";
import {assertDeletable} from "../src/elections/lifecycle";

describe("assertDeletable", () => {
  it("deixa excluir rascunho, em andamento e encerrada", () => {
    for (const status of ["draft", "open", "closed"]) {
      expect(() => assertDeletable(status)).not.toThrow();
    }
  });

  it("eleição concluída (diretoria aplicada) não é excluída", () => {
    expect(() => assertDeletable("completed")).toThrowError(
      expect.objectContaining({
        code: "failed-precondition",
        message: "Uma eleição concluída não pode ser excluída.",
      })
    );
  });
});
