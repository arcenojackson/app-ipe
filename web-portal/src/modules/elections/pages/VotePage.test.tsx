import {act, fireEvent, render, screen, waitFor} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {Election, Round, Voter} from "../types";
import {VotePage} from "./VotePage";

const auth = vi.hoisted(() => ({state: {status: "signedOut"} as unknown}));
vi.mock("@/core/auth/AuthContext", () => ({
  useAuth: () => ({state: auth.state, refreshAccess: vi.fn(), signOut: vi.fn()}),
}));

const api = vi.hoisted(() => ({
  election: undefined as unknown,
  voter: undefined as unknown,
  round: undefined as unknown,
  hasVoted: undefined as unknown,
  hasVotedCb: undefined as ((v: boolean) => void) | undefined,
  checkIn: vi.fn(),
  castVote: vi.fn(),
  signInGuest: vi.fn(),
  signInWithPassword: vi.fn(),
  signInWithGoogle: vi.fn(),
}));

vi.mock("../data/electionClient", () => ({
  watchElection: (_id: string, cb: (v: unknown) => void) => { cb(api.election); return () => {}; },
  watchVoter: (_e: string, _u: string, cb: (v: unknown) => void) => { cb(api.voter); return () => {}; },
  watchOpenRound: (_e: string, cb: (v: unknown) => void) => { cb(api.round); return () => {}; },
  watchHasVoted: (_e: string, _r: string, _u: string, cb: (v: boolean) => void) => {
    api.hasVotedCb = cb;
    cb(api.hasVoted as boolean);
    return () => {};
  },
  checkIn: api.checkIn,
  castVote: api.castVote,
  signInGuest: api.signInGuest,
  signInWithPassword: api.signInWithPassword,
  signInWithGoogle: api.signInWithGoogle,
  errorMessage: (e: unknown) => (e instanceof Error ? e.message : "Algo deu errado."),
}));

const election = (status: Election["status"] = "open"): Election => ({
  id: "e1", title: "Eleição 2026", societyName: "UMP", status,
});
const round: Round = {
  id: "r1", position: "presidente", type: "normal",
  candidates: [{id: "a", name: "Ana"}, {id: "b", name: "Bia"}],
};
const voter = (status: Voter["status"]): Voter => ({status, kind: "guest", name: "Maria"});
const signedIn = (isAnonymous: boolean) => ({
  status: "signedIn",
  user: {uid: "u1", isAnonymous},
  claims: {admin: false, teachingRole: null},
});

beforeEach(() => {
  auth.state = {status: "signedOut"};
  api.election = election();
  api.voter = undefined;
  api.round = undefined;
  api.hasVoted = undefined;
  api.checkIn.mockReset().mockResolvedValue(undefined);
  api.castVote.mockReset().mockResolvedValue("RECIBO123");
  api.signInGuest.mockReset().mockResolvedValue(undefined);
  api.signInWithPassword.mockReset();
  api.signInWithGoogle.mockReset();
});

describe("VotePage", () => {
  it("enquanto a sessão carrega não mostra o formulário de entrada", () => {
    auth.state = {status: "loading"};
    render(<VotePage electionId="e1" />);
    expect(screen.getByText("Carregando...")).toBeInTheDocument();
    expect(screen.queryByRole("button", {name: "Votar sem conta"})).not.toBeInTheDocument();
  });

  it("mostra título e pede identificação a quem não entrou", () => {
    render(<VotePage electionId="e1" />);
    expect(screen.getByText("Eleição 2026")).toBeInTheDocument();
    expect(screen.getByRole("button", {name: "Votar sem conta"})).toBeInTheDocument();
    expect(screen.getByRole("button", {name: "Entrar com a conta do app"})).toBeInTheDocument();
  });

  it("convidado: entra como anônimo e faz check-in com nome e e-mail", async () => {
    render(<VotePage electionId="e1" />);
    fireEvent.click(screen.getByRole("button", {name: "Votar sem conta"}));
    fireEvent.change(screen.getByLabelText("Seu nome"), {target: {value: "Maria"}});
    fireEvent.change(screen.getByLabelText("Seu e-mail"), {target: {value: "maria@x.org"}});
    fireEvent.click(screen.getByRole("button", {name: "Continuar"}));
    await waitFor(() => expect(api.checkIn).toHaveBeenCalledWith("e1", {name: "Maria", email: "maria@x.org"}));
    expect(api.signInGuest).toHaveBeenCalled();
  });

  it("logado com a conta do app faz check-in automático, sem formulário", async () => {
    auth.state = signedIn(false);
    api.voter = null;
    render(<VotePage electionId="e1" />);
    await waitFor(() => expect(api.checkIn).toHaveBeenCalledWith("e1"));
  });

  it("conta sem nome cadastrado: se o check-in automático falha, pede nome e e-mail", async () => {
    auth.state = signedIn(false);
    api.voter = null;
    api.checkIn.mockRejectedValueOnce(new Error("Informe seu nome."));
    render(<VotePage electionId="e1" />);
    expect(await screen.findByLabelText("Seu nome")).toBeInTheDocument();
    expect(screen.queryByText("Verificando sua presença...")).not.toBeInTheDocument();
    // Já há sessão: o formulário não cria outra conta anônima.
    fireEvent.change(screen.getByLabelText("Seu nome"), {target: {value: "Maria"}});
    fireEvent.change(screen.getByLabelText("Seu e-mail"), {target: {value: "maria@x.org"}});
    fireEvent.click(screen.getByRole("button", {name: "Continuar"}));
    await waitFor(() => expect(api.checkIn).toHaveBeenLastCalledWith("e1", {name: "Maria", email: "maria@x.org"}));
    expect(api.signInGuest).not.toHaveBeenCalled();
  });

  it("anônimo sem check-in vê só o formulário de convidado", () => {
    auth.state = signedIn(true);
    api.voter = null;
    render(<VotePage electionId="e1" />);
    expect(screen.getByLabelText("Seu nome")).toBeInTheDocument();
    expect(api.checkIn).not.toHaveBeenCalled();
  });

  it("pendente e recusado", () => {
    auth.state = signedIn(true);
    api.voter = voter("pending");
    const {rerender} = render(<VotePage electionId="e1" />);
    expect(screen.getByText(/Aguardando aprovação/)).toBeInTheDocument();
    api.voter = voter("rejected");
    rerender(<VotePage electionId="e1" key="again" />);
    expect(screen.getByText(/não foi liberada/)).toBeInTheDocument();
  });

  it("aprovado sem votação aberta aguarda", () => {
    auth.state = signedIn(true);
    api.voter = voter("approved");
    api.round = null;
    render(<VotePage electionId="e1" />);
    expect(screen.getByText(/Aguardando a próxima votação/)).toBeInTheDocument();
  });

  it("vota: só habilita com escolha, envia e mostra o recibo", async () => {
    auth.state = signedIn(true);
    api.voter = voter("approved");
    api.round = round;
    api.hasVoted = false;
    render(<VotePage electionId="e1" />);
    const confirm = screen.getByRole("button", {name: "Confirmar voto"});
    expect(confirm).toBeDisabled();
    fireEvent.click(screen.getByLabelText("Bia"));
    expect(confirm).toBeEnabled();
    fireEvent.click(confirm);
    await waitFor(() => expect(api.castVote).toHaveBeenCalledWith("e1", "r1", "b"));
  });

  it("depois de votar mostra o código do comprovante", async () => {
    auth.state = signedIn(true);
    api.voter = voter("approved");
    api.round = round;
    api.hasVoted = false;
    render(<VotePage electionId="e1" />);
    fireEvent.click(screen.getByLabelText("Bia"));
    fireEvent.click(screen.getByRole("button", {name: "Confirmar voto"}));
    await waitFor(() => expect(api.castVote).toHaveBeenCalled());
    // O listener do Firestore passa a informar que o usuário votou.
    act(() => api.hasVotedCb?.(true));
    expect(await screen.findByText("RECIBO123")).toBeInTheDocument();
    expect(screen.getByText(/Seu voto foi registrado/)).toBeInTheDocument();
  });

  it("candidato único: Sim, Não ou Branco", () => {
    auth.state = signedIn(true);
    api.voter = voter("approved");
    api.round = {...round, type: "single", candidates: [round.candidates[0]]};
    api.hasVoted = false;
    render(<VotePage electionId="e1" />);
    expect(screen.getByLabelText("Sim")).toBeInTheDocument();
    expect(screen.getByLabelText("Não")).toBeInTheDocument();
    expect(screen.getByLabelText("Branco")).toBeInTheDocument();
  });

  it("erro do servidor ao votar aparece na tela", async () => {
    auth.state = signedIn(true);
    api.voter = voter("approved");
    api.round = round;
    api.hasVoted = false;
    api.castVote.mockRejectedValue(new Error("Esta votação não está aberta."));
    render(<VotePage electionId="e1" />);
    fireEvent.click(screen.getByLabelText("Branco"));
    fireEvent.click(screen.getByRole("button", {name: "Confirmar voto"}));
    expect(await screen.findByRole("alert")).toHaveTextContent("Esta votação não está aberta.");
  });

  it("já votou", () => {
    auth.state = signedIn(true);
    api.voter = voter("approved");
    api.round = round;
    api.hasVoted = true;
    render(<VotePage electionId="e1" />);
    expect(screen.getByText(/Seu voto foi registrado/)).toBeInTheDocument();
  });

  it("eleição encerrada e inexistente", () => {
    api.election = election("closed");
    const {rerender} = render(<VotePage electionId="e1" />);
    expect(screen.getByText(/foi encerrada/)).toBeInTheDocument();
    api.election = null;
    rerender(<VotePage electionId="e1" key="x" />);
    expect(screen.getByText(/não encontrada/)).toBeInTheDocument();
  });
});
