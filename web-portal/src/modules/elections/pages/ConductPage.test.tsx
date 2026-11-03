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
  electionError: null as string | null,
  cargosPending: false,
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
  watchElection: (_id: string, cb: (v: unknown) => void, onError?: (m: string) => void) => {
    if (api.electionError) onError?.(api.electionError);
    else cb(api.election);
    return () => {};
  },
  watchCargos: (_id: string, cb: (v: unknown) => void) => {
    if (!api.cargosPending) cb(api.cargos);
    return () => {};
  },
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
  api.electionError = null;
  api.cargosPending = false;
  api.cargos = [cargo("presidente"), cargo("vice")];
  api.rounds = [];
  api.voters = [];
  api.voted = [];
  for (const fn of [
    api.setStatus, api.reviewVoter, api.startScrutiny, api.closeScrutiny,
    api.removeCandidate, api.restartCargo, api.pickOldest, api.applyBoard,
  ]) fn.mockReset().mockResolvedValue(undefined);
  api.applyBoard.mockResolvedValue({winners: {}, missingRequired: [], effectiveAtMs: Date.UTC(2027, 0, 1, 3, 0)});
});

describe("ConductPage", () => {
  it("quem não é diretor da eleição vê acesso restrito e nenhum controle", () => {
    auth.uid = "intruso";
    render(<ConductPage electionId="e1" />);
    expect(screen.getByText(/Acesso restrito aos diretores/)).toBeInTheDocument();
    expect(screen.queryByRole("button", {name: "Iniciar 1º escrutínio"})).not.toBeInTheDocument();
    expect(screen.queryByText(/\/votar\/e1/)).not.toBeInTheDocument();
  });

  it("falha ao carregar a eleição mostra o erro, não fica só em Carregando", () => {
    api.electionError = "Missing or insufficient permissions.";
    render(<ConductPage electionId="e1" />);
    expect(screen.getByRole("alert")).toHaveTextContent("Missing or insufficient permissions.");
  });

  it("antes do primeiro snapshot dos cargos não mostra controles de escrutínio", () => {
    api.cargosPending = true;
    render(<ConductPage electionId="e1" />);
    expect(screen.getByText("Carregando cargos…")).toBeInTheDocument();
    expect(screen.queryByRole("button", {name: "Iniciar 1º escrutínio"})).not.toBeInTheDocument();
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

  it("escrutínio encerrado: mostra contagem por opção e branco, sem a meta de votos", () => {
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
    expect(screen.queryByText(/necessários/)).not.toBeInTheDocument();
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
    api.applyBoard.mockResolvedValue({winners: {presidente: "a"}, missingRequired: ["vice"], effectiveAtMs: Date.UTC(2027, 0, 1, 3, 0)});
    render(<ConductPage electionId="e1" />);
    fireEvent.click(screen.getByRole("button", {name: "Aplicar diretoria"}));
    expect(await screen.findByText(/Assume em 01\/01\/2027\. Faltam cargos obrigatórios: Vice/)).toBeInTheDocument();
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

  it("rascunho: Abrir eleição fica abaixo do QR, com a largura dele", () => {
    api.election = election({status: "draft"});
    render(<ConductPage electionId="e1" />);
    const open = screen.getByRole("button", {name: "Abrir eleição"});
    const qrBox = screen.getByTitle("QR da votação").closest("div")!;
    // O QR tem 224px + 16px de padding de cada lado = w-64 (16rem).
    expect(qrBox).toHaveClass("w-64");
    expect(open).toHaveClass("w-64");
    expect(qrBox.parentElement).toContainElement(open);
  });

  it("QR e link somem quando a eleição está encerrada ou concluída", () => {
    for (const status of ["closed", "completed"] as const) {
      api.election = election({status});
      const {unmount} = render(<ConductPage electionId="e1" />);
      expect(screen.queryByTitle("QR da votação")).not.toBeInTheDocument();
      expect(screen.queryByText(/\/votar\/e1/)).not.toBeInTheDocument();
      unmount();
    }
  });

  it("presentes: Ver presentes abre a lista dos liberados com o tipo, sem os pendentes", () => {
    api.voters = [
      voter("u1", "Ana"),
      {...voter("u2", "Visitante"), kind: "guest"},
      voter("u3", "Espera", "pending"),
    ];
    render(<ConductPage electionId="e1" />);
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", {name: "Ver presentes"}));
    const dialog = screen.getByRole("dialog", {name: "Presentes (2)"});
    expect(dialog).toHaveTextContent("Ana (membro)");
    expect(dialog).toHaveTextContent("Visitante (convidado)");
    expect(dialog).not.toHaveTextContent("Espera");

    fireEvent.click(screen.getByRole("button", {name: "Fechar"}));
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });

  it("presentes: Ver presentes continua disponível com a eleição concluída", () => {
    api.election = election({status: "completed"});
    api.voters = [voter("u1", "Ana")];
    render(<ConductPage electionId="e1" />);
    expect(screen.getByRole("button", {name: "Ver presentes"})).toBeEnabled();
  });

  const decidedCargos = () => [
    cargo("presidente", {stage: "decided", winnerId: "a", candidates: [{id: "a", name: "Ana", votes: 6}]}),
    cargo("vice"),
  ];

  it("eleição encerrada (inválida): todos os botões bloqueados, inclusive Aplicar diretoria", () => {
    api.election = election({status: "closed"});
    api.cargos = decidedCargos();
    api.voters = [voter("u2", "Visitante", "pending")];
    render(<ConductPage electionId="e1" />);
    for (const name of ["Iniciar 1º escrutínio", "Aceitar Visitante", "Recusar Visitante", "Aplicar diretoria"]) {
      for (const button of screen.getAllByRole("button", {name})) expect(button).toBeDisabled();
    }
  });

  it("eleição concluída: todos os botões bloqueados, inclusive Aplicar diretoria", () => {
    api.election = election({status: "completed"});
    api.cargos = decidedCargos();
    api.voters = [voter("u2", "Visitante", "pending")];
    render(<ConductPage electionId="e1" />);
    for (const name of ["Iniciar 1º escrutínio", "Aceitar Visitante", "Recusar Visitante", "Aplicar diretoria"]) {
      for (const button of screen.getAllByRole("button", {name})) expect(button).toBeDisabled();
    }
  });

  it("aplicar diretoria com sucesso desabilita o botão na hora", async () => {
    api.election = election({status: "open"});
    api.cargos = decidedCargos();
    render(<ConductPage electionId="e1" />);
    fireEvent.click(screen.getByRole("button", {name: "Aplicar diretoria"}));
    await waitFor(() => expect(api.applyBoard).toHaveBeenCalledWith("e1"));
    await waitFor(() => expect(screen.getByRole("button", {name: "Aplicar diretoria"})).toBeDisabled());
  });
});
