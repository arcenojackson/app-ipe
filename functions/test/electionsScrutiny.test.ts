import {describe, expect, it} from "vitest";
import {
  countBallots,
  decideScrutiny,
  requiredVotes,
} from "../src/elections/scrutiny";

const ana = {id: "ana", name: "Ana"};
const bia = {id: "bia", name: "Bia"};
const caio = {id: "caio", name: "Caio"};

describe("requiredVotes (50% + 1 dos presentes)", () => {
  it("pares e ímpares", () => {
    expect(requiredVotes(10)).toBe(6);
    expect(requiredVotes(9)).toBe(5);
    expect(requiredVotes(1)).toBe(1);
    expect(requiredVotes(0)).toBe(1);
  });
});

describe("countBallots", () => {
  it("conta por opção e separa o branco", () => {
    const r = countBallots([ana, bia], ["ana", "ana", "bia", "blank"], 4);
    expect(r.counts).toEqual({ana: 2, bia: 1});
    expect(r.blank).toBe(1);
    expect(r.total).toBe(4);
    expect(r.divergence).toBe(false);
  });

  it("opção sem voto aparece com zero", () => {
    expect(countBallots([ana, bia], ["ana"], 1).counts).toEqual({ana: 1, bia: 0});
  });

  it("escolha fora das opções (inclusive chave herdada de Object) marca divergência", () => {
    expect(countBallots([ana], ["ana", "constructor"], 2).divergence).toBe(true);
    expect(countBallots([ana], ["fulano"], 1).divergence).toBe(true);
  });

  it("ballots diferentes de voted marcam divergência", () => {
    const r = countBallots([ana, bia], ["ana"], 2);
    expect(r.divergence).toBe(true);
    expect(r.total).toBe(1);
  });
});

describe("decideScrutiny — 1º escrutínio", () => {
  it("vira lista de candidatos: só quem teve voto, por votos e depois por nome", () => {
    const out = decideScrutiny({
      number: 1,
      options: [ana, bia, caio],
      counts: {ana: 1, bia: 3, caio: 1},
      presentCount: 10,
    });
    expect(out).toEqual({
      stage: "confirming",
      candidates: [
        {id: "bia", name: "Bia", votes: 3},
        {id: "ana", name: "Ana", votes: 1},
        {id: "caio", name: "Caio", votes: 1},
      ],
    });
  });

  it("nunca elege, mesmo com maioria", () => {
    const out = decideScrutiny({
      number: 1, options: [ana, bia], counts: {ana: 9, bia: 0}, presentCount: 10,
    });
    expect(out.stage).toBe("confirming");
  });

  it("ninguém votou: confirming com lista vazia", () => {
    const out = decideScrutiny({
      number: 1, options: [ana, bia], counts: {ana: 0, bia: 0}, presentCount: 10,
    });
    expect(out).toEqual({stage: "confirming", candidates: []});
  });
});

describe("decideScrutiny — 2º escrutínio", () => {
  const base = {number: 2 as const, options: [ana, bia], presentCount: 10};

  it("elege quem atinge o limiar (6 de 10)", () => {
    expect(decideScrutiny({...base, counts: {ana: 6, bia: 2}}))
      .toEqual({stage: "decided", winnerId: "ana"});
  });

  it("5 de 10 não basta", () => {
    expect(decideScrutiny({...base, counts: {ana: 5, bia: 3}}))
      .toEqual({stage: "awaiting3"});
  });

  it("com vários candidatos, só um atingindo basta", () => {
    expect(decideScrutiny({...base, counts: {ana: 1, bia: 6}}))
      .toEqual({stage: "decided", winnerId: "bia"});
  });

  it("candidato único abaixo do limiar vai ao 3º; no limiar é eleito", () => {
    const single = {...base, options: [ana]};
    expect(decideScrutiny({...single, counts: {ana: 5}}))
      .toEqual({stage: "awaiting3"});
    expect(decideScrutiny({...single, counts: {ana: 6}}))
      .toEqual({stage: "decided", winnerId: "ana"});
  });

  it("limiar com presentes ímpares (9 → 5)", () => {
    expect(decideScrutiny({number: 2, options: [ana], counts: {ana: 5}, presentCount: 9}))
      .toEqual({stage: "decided", winnerId: "ana"});
    expect(decideScrutiny({number: 2, options: [ana], counts: {ana: 4}, presentCount: 9}))
      .toEqual({stage: "awaiting3"});
  });
});

describe("decideScrutiny — 3º escrutínio", () => {
  const base = {number: 3 as const, options: [ana, bia, caio], presentCount: 10};

  it("vence o mais votado, mesmo sem maioria", () => {
    expect(decideScrutiny({...base, counts: {ana: 3, bia: 2, caio: 1}}))
      .toEqual({stage: "decided", winnerId: "ana"});
  });

  it("empate no topo vai ao diretor, com os ids empatados na ordem das opções", () => {
    expect(decideScrutiny({...base, counts: {ana: 3, bia: 3, caio: 1}}))
      .toEqual({stage: "tiebreak", tiedIds: ["ana", "bia"]});
  });

  it("só brancos (todos com zero): reinicia o cargo", () => {
    expect(decideScrutiny({...base, counts: {ana: 0, bia: 0, caio: 0}}))
      .toEqual({stage: "idle"});
  });

  it("candidato único com ao menos um voto é eleito", () => {
    expect(decideScrutiny({...base, options: [ana], counts: {ana: 1}}))
      .toEqual({stage: "decided", winnerId: "ana"});
  });
});
