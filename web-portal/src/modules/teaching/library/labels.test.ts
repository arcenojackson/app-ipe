import {describe, expect, it} from "vitest";
import {approverLabel, formatBytes, formatDate, formatDateTime, voteLabel} from "./labels";

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

describe("formatDate", () => {
  it("só a data em pt-BR, e traço para tempo zero ou ausente", () => {
    expect(formatDate(Date.UTC(2026, 9, 19, 15))).toMatch(/^19\/10\/2026$/);
    expect(formatDate(0)).toBe("—");
    expect(formatDate(undefined)).toBe("—");
  });
});

describe("formatBytes", () => {
  it("KB, MB e bytes pequenos", () => {
    expect(formatBytes(512)).toBe("512 B");
    expect(formatBytes(250 * 1024)).toBe("250 KB");
    expect(formatBytes(6 * 1024)).toBe("6 KB");
    expect(formatBytes(1.5 * 1024 * 1024)).toBe("1,5 MB");
    expect(formatBytes(100 * 1024 * 1024)).toBe("100 MB");
  });
});

describe("approverLabel", () => {
  const names = {a: "Ana Curadora", b: "Bia Souza", c: "Caio Lima"};
  it("sem aprovadores mostra traço; até 2 mostra primeiros nomes; mais vira +N", () => {
    expect(approverLabel(undefined, names)).toEqual({text: "—", title: ""});
    expect(approverLabel([], names).text).toBe("—");
    expect(approverLabel(["a", "b"], names).text).toBe("Ana, Bia");
    expect(approverLabel(["a", "b", "c"], names)).toEqual({text: "Ana, Bia +1", title: "Ana Curadora, Bia Souza, Caio Lima"});
    expect(approverLabel(["x"], names).text).toBe("Curador");
  });
});
