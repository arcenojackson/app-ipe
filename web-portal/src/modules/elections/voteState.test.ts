import {describe, expect, it} from "vitest";
import type {Election, Round, Voter} from "./types";
import {deriveView} from "./voteState";

const election = (status: Election["status"]): Election => ({
  id: "e1", title: "Eleição 2026", societyName: "UMP", status,
});
const round: Round = {
  id: "r1", position: "presidente", number: 1,
  options: [{id: "a", name: "Ana"}],
};
const voter = (status: Voter["status"]): Voter => ({status, kind: "guest", name: "Maria"});

const base = {
  election: election("open"),
  voter: undefined as Voter | null | undefined,
  openRound: undefined as Round | null | undefined,
  hasVoted: undefined as boolean | undefined,
  hasUser: false,
};

describe("deriveView", () => {
  it("carregando a eleição", () => {
    expect(deriveView({...base, election: undefined}).kind).toBe("loading");
  });

  it("eleição inexistente, em rascunho ou encerrada (mesmo sem login)", () => {
    expect(deriveView({...base, election: null}).kind).toBe("notFound");
    expect(deriveView({...base, election: election("draft")}).kind).toBe("notOpen");
    expect(deriveView({...base, election: election("closed")}).kind).toBe("closed");
  });

  it("encerrada vale mesmo para quem está na tela de voto", () => {
    const view = deriveView({
      ...base, election: election("closed"), hasUser: true,
      voter: voter("approved"), openRound: round, hasVoted: false,
    });
    expect(view.kind).toBe("closed");
  });

  it("sem usuário pede identificação", () => {
    expect(deriveView(base).kind).toBe("join");
  });

  it("com usuário, aguarda o eleitor carregar; sem check-in volta a join", () => {
    expect(deriveView({...base, hasUser: true, voter: undefined}).kind).toBe("loading");
    expect(deriveView({...base, hasUser: true, voter: null}).kind).toBe("join");
  });

  it("pendente e recusado", () => {
    expect(deriveView({...base, hasUser: true, voter: voter("pending")}).kind).toBe("pending");
    expect(deriveView({...base, hasUser: true, voter: voter("rejected")}).kind).toBe("rejected");
  });

  it("aprovado: carrega rodada, espera rodada, vota, já votou", () => {
    const approved = {...base, hasUser: true, voter: voter("approved")};
    expect(deriveView({...approved, openRound: undefined}).kind).toBe("loading");
    expect(deriveView({...approved, openRound: null}).kind).toBe("waitingRound");
    expect(deriveView({...approved, openRound: round, hasVoted: undefined}).kind).toBe("loading");
    expect(deriveView({...approved, openRound: round, hasVoted: false})).toEqual({kind: "ballot", round});
    expect(deriveView({...approved, openRound: round, hasVoted: true})).toEqual({kind: "voted", round});
  });
});
