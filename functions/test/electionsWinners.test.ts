import {describe, expect, it} from "vitest";
import {electedElsewhere, pickWinners, type RoundSummary} from "../src/elections/winners";

const r = (over: Partial<RoundSummary>): RoundSummary => ({
  position: "presidente",
  status: "closed",
  closedAtMs: 1,
  winnerId: "ana",
  ...over,
});

describe("pickWinners", () => {
  it("pega o vencedor de cada cargo e ignora rodadas não fechadas", () => {
    const winners = pickWinners([
      r({}),
      r({position: "vice", winnerId: "bia"}),
      r({position: "secretario", status: "open", winnerId: "caio"}),
    ]);
    expect(winners).toEqual({presidente: "ana", vice: "bia"});
  });

  it("a rodada fechada mais recente do cargo vale (desempate)", () => {
    const winners = pickWinners([
      r({winnerId: null, closedAtMs: 1}),
      r({winnerId: "bia", closedAtMs: 2}),
    ]);
    expect(winners).toEqual({presidente: "bia"});
  });

  it("uma rodada mais recente sem vencedor anula a anterior", () => {
    const winners = pickWinners([
      r({winnerId: "ana", closedAtMs: 1}),
      r({winnerId: null, closedAtMs: 2}),
    ]);
    expect(winners).toEqual({});
  });
});

describe("electedElsewhere", () => {
  it("lista quem foi eleito em outros cargos, não no próprio", () => {
    const rounds = [r({}), r({position: "vice", winnerId: "bia"})];
    expect([...electedElsewhere(rounds, "presidente")]).toEqual(["bia"]);
    expect([...electedElsewhere(rounds, "tesoureiro")].sort()).toEqual(["ana", "bia"]);
  });
});
