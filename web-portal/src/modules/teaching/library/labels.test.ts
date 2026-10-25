import {describe, expect, it} from "vitest";
import {formatDateTime, voteLabel} from "./labels";

describe("voteLabel", () => {
  it("rótulos em pt-BR para cada ação", () => {
    expect(voteLabel("approve")).toBe("Aprovou");
    expect(voteLabel("reject")).toBe("Rejeitou");
    expect(voteLabel("return")).toBe("Devolveu");
    expect(voteLabel("delete_approve")).toBe("Aprovou a exclusão");
    expect(voteLabel("delete_refuse")).toBe("Recusou a exclusão");
  });
});

describe("formatDateTime", () => {
  it("devolve um texto não vazio e traço para tempo zero", () => {
    expect(formatDateTime(1_700_000_000_000).length).toBeGreaterThan(5);
    expect(formatDateTime(0)).toBe("—");
  });
});
