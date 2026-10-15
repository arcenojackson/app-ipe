import {describe, expect, it} from "vitest";
import {tallyRound} from "../src/elections/tally";

const ana = {id: "ana", name: "Ana"};
const bia = {id: "bia", name: "Bia"};

describe("tallyRound — rodada normal", () => {
  it("vence quem tem mais votos", () => {
    const r = tallyRound("normal", [ana, bia], ["ana", "ana", "bia", "blank"], 4);
    expect(r.counts).toEqual({ana: 2, bia: 1, blank: 1});
    expect(r.winnerId).toBe("ana");
    expect(r.tie).toEqual([]);
    expect(r.total).toBe(4);
    expect(r.divergence).toBe(false);
  });

  it("empate no topo devolve os empatados e nenhum vencedor", () => {
    const r = tallyRound("normal", [ana, bia], ["ana", "bia"], 2);
    expect(r.winnerId).toBeNull();
    expect(r.tie).toEqual(["ana", "bia"]);
  });

  it("só votos em branco: sem vencedor e sem empate", () => {
    const r = tallyRound("normal", [ana, bia], ["blank", "blank"], 2);
    expect(r.winnerId).toBeNull();
    expect(r.tie).toEqual([]);
  });

  it("nenhum voto: sem vencedor e sem empate", () => {
    const r = tallyRound("normal", [ana, bia], [], 0);
    expect(r.winnerId).toBeNull();
    expect(r.tie).toEqual([]);
    expect(r.total).toBe(0);
  });

  it("branco não vence mesmo sendo maioria", () => {
    const r = tallyRound("normal", [ana, bia], ["blank", "blank", "ana"], 3);
    expect(r.winnerId).toBe("ana");
  });

  it("voto inválido (inclusive chave herdada de Object) marca divergência", () => {
    const r = tallyRound("normal", [ana], ["ana", "constructor"], 2);
    expect(r.divergence).toBe(true);
    expect(r.winnerId).toBe("ana");
  });

  it("divergência quando ballots e voted não batem", () => {
    const r = tallyRound("normal", [ana, bia], ["ana"], 2);
    expect(r.divergence).toBe(true);
    expect(r.votedCount).toBe(2);
  });
});

describe("tallyRound — candidato único", () => {
  it("vence com mais Sim que Não", () => {
    const r = tallyRound("single", [ana], ["yes", "yes", "no", "blank"], 4);
    expect(r.counts).toEqual({yes: 2, no: 1, blank: 1});
    expect(r.winnerId).toBe("ana");
  });

  it("empate Sim x Não não elege", () => {
    const r = tallyRound("single", [ana], ["yes", "no"], 2);
    expect(r.winnerId).toBeNull();
    expect(r.tie).toEqual([]);
  });

  it("só Branco não elege", () => {
    const r = tallyRound("single", [ana], ["blank"], 1);
    expect(r.winnerId).toBeNull();
  });
});
