import {act, fireEvent, render, screen, waitFor} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {
  Cargo, ConductElection, ConductRound, ConductVoter,
} from "../types";
import {ConductPage} from "./ConductPage";

const auth = vi.hoisted(() => ({uid: "dir1"}));
vi.mock("@/core/auth/AuthContext", () => ({
  useAuth: () => ({
    state: {status: "signedIn", user: {uid: auth.uid}, claims: {admin: false, teachingRole: null}},
    refreshAccess: vi.fn(),
    signOut: vi.fn(),
  }),
}));

const api = vi.hoisted(() => ({
  election: undefined as unknown,
  cargos: [] as unknown[],
  rounds: [] as unknown[],
  voters: [] as unknown[],
  voted: [] as string[],
  setStatus: vi.fn(),
  reviewVoter: vi.fn(),
  startScrutiny: vi.fn(),
  closeScrutiny: vi.fn(),
  removeCandidate: vi.fn(),
  restartCargo: vi.fn(),
  pickOldest: vi.fn(),
  applyBoard: vi.fn(),
}));

vi.mock("../data/conductClient", () => ({
  watchElection: (_id: string, cb: (v: unknown) => void) => { cb(api.election); return () => {}; },
  watchCargos: (_id: string, cb: (v: unknown) => void) => { cb(api.cargos); return () => {}; },
  watchRounds: (_id: string, cb: (v: unknown) => void) => { cb(api.rounds); return () => {}; },
  watchVoters: (_id: string, cb: (v: unknown) => void) => { cb(api.voters); return () => {}; },
  watchVoted: (_id: string, _r: string, cb: (v: unknown) => void) => { cb(api.voted); return () => {}; },
  setStatus: api.setStatus,
  reviewVoter: api.reviewVoter,
  startScrutiny: api.startScrutiny,
  closeScrutiny: api.closeScrutiny,
  removeCandidate: api.removeCandidate,
  restartCargo: api.restartCargo,
  pickOldest: api.pickOldest,
  applyBoard: api.applyBoard,
  errorMessage: (e: unknown) => (e instanceof Error ? e.message : "Algo deu errado."),
}));

const election = (over: Partial<ConductElection> = {}): ConductElection => ({
  id: "e1", title: "Eleição UMP 2026", societyName: "UMP", status: "open",
  positions: ["presidente", "vice"], directorIds: ["dir1"], ...over,
});
const cargo = (position: string, over: Partial<Cargo> = {}): Cargo => ({
  position, stage: "idle", cycle: 1, candidates: [], tiedIds: [], winnerId: null, ...over,
});
const voter = (id: string, name: string, status: ConductVoter["status"] = "approved"): ConductVoter => ({
  id, name, email: `${id}@x.org`, kind: "member", status,
});
const round = (over: Partial<ConductRound> = {}): ConductRound => ({
  id: "r1", position: "presidente", number: 1, cycle: 1, status: "open",
  options: [{id: "a", name: "Ana"}, {id: "b", name: "Bia"}], votedCount: 0, ...over,
});

beforeEach(() => {
  auth.uid = "dir1";
  api.election = election();
  api.cargos = [cargo("presidente"), cargo("vice")];
  api.rounds = [];
  api.voters = [];
  api.voted = [];
  for (const fn of [
    api.setStatus, api.reviewVoter, api.startScrutiny, api.closeScrutiny,
    api.removeCandidate, api.restartCargo, api.pickOldest, api.applyBoard,
  ]) fn.mockReset().mockResolvedValue(undefined);
  api.applyBoard.mockResolvedValue({winners: {}, missingRequired: []});
});

describe("ConductPage", () => {
  it("quem não é diretor da eleição vê acesso restrito e nenhum controle", () => {
    auth.uid = "intruso";
    render(<ConductPage electionId="e1" />);
    expect(screen.getByText(/Acesso restrito aos diretores/)).toBeInTheDocument();
    expect(screen.queryByRole("button", {name: "Iniciar 1º escrutínio"})).not.toBeInTheDocument();
    expect(screen.queryByText(/\/votar\/e1/)).not.toBeInTheDocument();
  });

  it("diretor vê o título, o QR e o link da votação", () => {
    render(<ConductPage electionId="e1" />);
    expect(screen.getByText("Eleição UMP 2026")).toBeInTheDocument();
    expect(screen.getByText(/\/votar\/e1$/)).toBeInTheDocument();
    expect(screen.getByTitle("QR da votação")).toBeInTheDocument();
  });

  it("rascunho: abrir a eleição; aberta: encerrar", async () => {
    api.election = election({status: "draft"});
    const {unmount} = render(<ConductPage electionId="e1" />);
    fireEvent.click(screen.getByRole("button", {name: "Abrir eleição"}));
    await waitFor(() => expect(api.setStatus).toHaveBeenCalledWith("e1", "open"));
    unmount();
    api.election = election({status: "open"});
    render(<ConductPage electionId="e1" />);
    fireEvent.click(screen.getByRole("button", {name: "Encerrar eleição"}));
    await waitFor(() => expect(api.setStatus).toHaveBeenCalledWith("e1", "closed"));
  });

  it("presentes: convidado pendente pode ser aceito ou recusado; mostra o total de liberados", async () => {
    api.voters = [voter("u1", "Ana"), voter("u2", "Visitante", "pending")];
    render(<ConductPage electionId="e1" />);
    expect(screen.getByText("Liberados: 1")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", {name: "Aceitar Visitante"}));
    await waitFor(() => expect(api.reviewVoter).toHaveBeenCalledWith("e1", "u2", "approved"));
    fireEvent.click(screen.getByRole("button", {name: "Recusar Visitante"}));
    await waitFor(() => expect(api.reviewVoter).toHaveBeenCalledWith("e1", "u2", "rejected"));
  });

  it("cargo parado: iniciar o 1º escrutínio chama a função com o cargo", async () => {
    render(<ConductPage electionId="e1" />);
    fireEvent.click(screen.getAllByRole("button", {name: "Iniciar 1º escrutínio"})[0]);
    await waitFor(() => expect(api.startScrutiny).toHaveBeenCalledWith("e1", "presidente"));
  });

  it("escrutínio aberto: mostra quantos votaram e quem ainda falta", async () => {
    api.cargos = [cargo("presidente", {stage: "scrutiny1"}), cargo("vice")];
    api.rounds = [round()];
    api.voters = [
      voter("u1", "Ana"), voter("u2", "Bia"), voter("u3", "Caio"),
      voter("u4", "Duda"), voter("u5", "Edu"), voter("u9", "Visitante", "pending"),
    ];
    api.voted = ["u1", "u2", "u3"];
    render(<ConductPage electionId="e1" />);
    expect(screen.getByText("3 de 5 votaram")).toBeInTheDocument();
    expect(screen.getByText("Faltam votar:")).toBeInTheDocument();
    expect(screen.getByText(/Duda/)).toBeInTheDocument();
    expect(screen.getByText(/Edu/)).toBeInTheDocument();
    expect(screen.queryByText(/Visitante.*falta/)).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", {name: "Encerrar escrutínio"}));
    await waitFor(() => expect(api.closeScrutiny).toHaveBeenCalledWith("e1", "presidente"));
  });

  it("escrutínio encerrado: mostra contagem por opção, branco e a meta de votos", () => {
    api.cargos = [
      cargo("presidente", {stage: "awaiting3", candidates: [{id: "a", name: "Ana", votes: 2}]}),
      cargo("vice"),
    ];
    api.rounds = [round({
      status: "closed", number: 2,
      result: {
        counts: {a: 5, b: 3}, blank: 2, total: 10, presentCount: 10, threshold: 6,
        winnerId: null, tie: [], divergence: false,
      },
    })];
    render(<ConductPage electionId="e1" />);
    expect(screen.getByText("6 de 10 necessários")).toBeInTheDocument();
    expect(screen.getByText("Ana: 5")).toBeInTheDocument();
    expect(screen.getByText("Bia: 3")).toBeInTheDocument();
    expect(screen.getByText("Branco: 2")).toBeInTheDocument();
  });

  it("divergência na contagem aparece como alerta", () => {
    api.cargos = [cargo("presidente", {stage: "awaiting3"}), cargo("vice")];
    api.rounds = [round({
      status: "closed", number: 2,
      result: {
        counts: {a: 1, b: 0}, blank: 0, total: 1, presentCount: 2, threshold: 2,
        winnerId: null, tie: [], divergence: true,
      },
    })];
    render(<ConductPage electionId="e1" />);
    expect(screen.getByText(/contagem diverge/i)).toBeInTheDocument();
  });

  it("confirmação: remover candidato e iniciar o 2º escrutínio", async () => {
    api.cargos = [
      cargo("presidente", {
        stage: "confirming",
        candidates: [{id: "a", name: "Ana", votes: 3}, {id: "b", name: "Bia", votes: 1}],
      }),
      cargo("vice"),
    ];
    render(<ConductPage electionId="e1" />);
    fireEvent.click(screen.getAllByRole("button", {name: "Remover como candidato"})[0]);
    await waitFor(() => expect(api.removeCandidate).toHaveBeenCalledWith("e1", "presidente", "a"));
    fireEvent.click(screen.getByRole("button", {name: "Iniciar 2º escrutínio"}));
    await waitFor(() => expect(api.startScrutiny).toHaveBeenCalledWith("e1", "presidente"));
  });

  it("confirmação sem candidatos: reiniciar o cargo", async () => {
    api.cargos = [cargo("presidente", {stage: "confirming"}), cargo("vice")];
    render(<ConductPage electionId="e1" />);
    fireEvent.click(screen.getByRole("button", {name: "Reiniciar cargo"}));
    await waitFor(() => expect(api.restartCargo).toHaveBeenCalledWith("e1", "presidente"));
  });

  it("empate no 3º escrutínio: o diretor escolhe o mais velho", async () => {
    api.cargos = [
      cargo("presidente", {
        stage: "tiebreak", tiedIds: ["a", "b"],
        candidates: [{id: "a", name: "Ana", votes: 2}, {id: "b", name: "Bia", votes: 2}],
      }),
      cargo("vice"),
    ];
    render(<ConductPage electionId="e1" />);
    fireEvent.click(screen.getByRole("button", {name: "Mais velho: Bia"}));
    await waitFor(() => expect(api.pickOldest).toHaveBeenCalledWith("e1", "presidente", "b"));
  });

  it("cargo decidido mostra o eleito", () => {
    api.cargos = [
      cargo("presidente", {stage: "decided", winnerId: "a", candidates: [{id: "a", name: "Ana", votes: 6}]}),
      cargo("vice"),
    ];
    render(<ConductPage electionId="e1" />);
    expect(screen.getByText("Eleito(a): Ana")).toBeInTheDocument();
  });

  it("aplicar diretoria avisa quando faltam cargos obrigatórios", async () => {
    api.cargos = [
      cargo("presidente", {stage: "decided", winnerId: "a", candidates: [{id: "a", name: "Ana", votes: 6}]}),
      cargo("vice"),
    ];
    api.applyBoard.mockResolvedValue({winners: {presidente: "a"}, missingRequired: ["vice"]});
    render(<ConductPage electionId="e1" />);
    fireEvent.click(screen.getByRole("button", {name: "Aplicar diretoria"}));
    expect(await screen.findByText("Faltam cargos obrigatórios: Vice")).toBeInTheDocument();
  });

  it("aplicar diretoria fica desabilitado enquanto nenhum cargo foi decidido", () => {
    render(<ConductPage electionId="e1" />);
    expect(screen.getByRole("button", {name: "Aplicar diretoria"})).toBeDisabled();
  });

  it("erro do servidor aparece na tela", async () => {
    api.startScrutiny.mockRejectedValue(new Error("Já existe um escrutínio aberto."));
    render(<ConductPage electionId="e1" />);
    await act(async () => {
      fireEvent.click(screen.getAllByRole("button", {name: "Iniciar 1º escrutínio"})[0]);
    });
    expect(await screen.findByRole("alert")).toHaveTextContent("Já existe um escrutínio aberto.");
  });
});
