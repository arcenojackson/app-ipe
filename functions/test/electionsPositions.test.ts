import {describe, expect, it} from "vitest";
import {
  POSITIONS,
  REQUIRED_POSITIONS,
  normalizePositions,
} from "../src/elections/positions";

const code = (fn: () => unknown) => {
  try {
    fn();
  } catch (e) {
    return (e as {code?: string}).code;
  }
  return undefined;
};

describe("normalizePositions", () => {
  it("expõe os cinco cargos na ordem canônica e os obrigatórios", () => {
    expect(POSITIONS).toEqual([
      "presidente", "vice", "secretario", "secretario2", "tesoureiro",
    ]);
    expect(REQUIRED_POSITIONS).toEqual(["presidente", "vice"]);
  });

  it("aceita os cinco", () => {
    expect(normalizePositions([...POSITIONS])).toEqual([...POSITIONS]);
  });

  it("ordena na ordem canônica", () => {
    expect(normalizePositions(["tesoureiro", "vice", "presidente"]))
      .toEqual(["presidente", "vice", "tesoureiro"]);
  });

  it("remove repetidos", () => {
    expect(normalizePositions(["vice", "presidente", "vice"]))
      .toEqual(["presidente", "vice"]);
  });

  it("exige presidente e vice", () => {
    expect(code(() => normalizePositions(["presidente"]))).toBe("invalid-argument");
    expect(code(() => normalizePositions(["vice", "tesoureiro"]))).toBe("invalid-argument");
  });

  it("recusa cargo desconhecido e entrada que não é lista", () => {
    expect(code(() => normalizePositions(["presidente", "vice", "pastor"]))).toBe("invalid-argument");
    expect(code(() => normalizePositions("presidente"))).toBe("invalid-argument");
    expect(code(() => normalizePositions(undefined))).toBe("invalid-argument");
  });
});
