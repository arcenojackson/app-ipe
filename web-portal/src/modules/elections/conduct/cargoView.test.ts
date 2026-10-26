import {describe, expect, it} from "vitest";
import {cargoView} from "./cargoView";

const candidates = [
  {id: "a", name: "Ana", votes: 3},
  {id: "b", name: "Bia", votes: 1},
];

const base = {candidates: [], tiedIds: []};

describe("cargoView", () => {
  it("idle: iniciar o 1º escrutínio", () => {
    const v = cargoView({...base, stage: "idle"});
    expect(v.title).toBe("Não iniciado");
    expect(v.actions).toEqual([{kind: "start", label: "Iniciar 1º escrutínio"}]);
  });

  it.each([
    ["scrutiny1", "1º escrutínio em andamento"],
    ["scrutiny2", "2º escrutínio em andamento"],
    ["scrutiny3", "3º escrutínio em andamento"],
  ] as const)("%s: encerrar o escrutínio", (stage, title) => {
    const v = cargoView({...base, stage});
    expect(v.title).toBe(title);
    expect(v.actions).toEqual([{kind: "close", label: "Encerrar escrutínio"}]);
  });

  it("confirming com candidatos: remover cada um e iniciar o 2º escrutínio", () => {
    const v = cargoView({stage: "confirming", candidates, tiedIds: []});
    expect(v.title).toBe("Confirmação dos candidatos");
    expect(v.actions).toEqual([
      {kind: "removeCandidate", label: "Remover como candidato", targetId: "a"},
      {kind: "removeCandidate", label: "Remover como candidato", targetId: "b"},
      {kind: "start", label: "Iniciar 2º escrutínio"},
    ]);
  });

  it("confirming sem candidatos: só reiniciar o cargo", () => {
    const v = cargoView({...base, stage: "confirming"});
    expect(v.title).toBe("Sem candidatos");
    expect(v.actions).toEqual([{kind: "restart", label: "Reiniciar cargo"}]);
  });

  it("awaiting3: ninguém atingiu a maioria; iniciar o 3º", () => {
    const v = cargoView({stage: "awaiting3", candidates, tiedIds: []});
    expect(v.title).toBe("Ninguém atingiu a maioria");
    expect(v.actions).toEqual([{kind: "start", label: "Iniciar 3º escrutínio"}]);
  });

  it("tiebreak: uma ação por empatado, com o nome", () => {
    const v = cargoView({stage: "tiebreak", candidates, tiedIds: ["a", "b"]});
    expect(v.title).toBe("Empate: escolha o mais velho");
    expect(v.actions).toEqual([
      {kind: "pickOldest", label: "Mais velho: Ana", targetId: "a"},
      {kind: "pickOldest", label: "Mais velho: Bia", targetId: "b"},
    ]);
  });

  it("decided: mostra o eleito e nenhuma ação", () => {
    const v = cargoView({...base, stage: "decided", winnerName: "Ana"});
    expect(v.title).toBe("Eleito(a): Ana");
    expect(v.actions).toEqual([]);
  });
});
