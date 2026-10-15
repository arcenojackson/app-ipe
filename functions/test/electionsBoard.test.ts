import {describe, expect, it} from "vitest";
import {applyWinners, boardKey} from "../src/elections/board";

describe("boardKey", () => {
  it("usa a mesma chave que o app Flutter grava", () => {
    expect(boardKey("presidente")).toBe("presidente");
    expect(boardKey("vice")).toBe("vice");
    expect(boardKey("secretario")).toBe("secretario(a)");
    expect(boardKey("tesoureiro")).toBe("tesoureiro(a)");
  });

  it("recusa cargo desconhecido", () => {
    expect(() => boardKey("pastor")).toThrow();
  });
});

describe("applyWinners", () => {
  it("troca só os cargos eleitos e preserva os demais", () => {
    const next = applyWinners(
      {presidente: ["old"], vice: ["v1"], "tesoureiro(a)": ["t1"]},
      {presidente: "ana"}
    );
    expect(next).toEqual({presidente: ["ana"], vice: ["v1"], "tesoureiro(a)": ["t1"]});
  });

  it("não duplica cargo gravado com outra caixa (Presidente)", () => {
    const next = applyWinners({Presidente: ["old"]}, {presidente: "ana"});
    expect(next).toEqual({presidente: ["ana"]});
  });

  it("board em formato antigo (lista) começa do zero com os eleitos", () => {
    expect(applyWinners(["a", "b"], {vice: "bia"})).toEqual({vice: ["bia"]});
  });

  it("board vazio ou ausente", () => {
    expect(applyWinners(undefined, {secretario: "caio"})).toEqual({"secretario(a)": ["caio"]});
  });

  it("aceita valor string legado em um cargo não eleito", () => {
    expect(applyWinners({vice: "v1"}, {presidente: "ana"})).toEqual({vice: ["v1"], presidente: ["ana"]});
  });
});
