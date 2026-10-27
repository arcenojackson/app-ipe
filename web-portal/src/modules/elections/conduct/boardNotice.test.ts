import {describe, expect, it} from "vitest";
import {boardNotice} from "./boardNotice";

// 00:00 de 01/01/2027 em São Paulo.
const effectiveAtMs = Date.UTC(2027, 0, 1, 3, 0);

describe("boardNotice", () => {
  it("diz que a diretoria assume na data de vigência, no fuso de São Paulo", () => {
    expect(boardNotice({missingRequired: [], effectiveAtMs}))
      .toBe("Diretoria registrada. Assume em 01/01/2027.");
  });

  it("acrescenta os cargos obrigatórios que faltam", () => {
    expect(boardNotice({missingRequired: ["vice"], effectiveAtMs}))
      .toBe("Diretoria registrada. Assume em 01/01/2027. Faltam cargos obrigatórios: Vice");
  });
});
