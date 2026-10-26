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
  signInWithPassword: api.signInWithPassword,
  signInWithGoogle: api.signInWithGoogle,
  errorMessage: (e: unknown) => (e instanceof Error ? e.message : "Algo deu errado."),
}));

const election = (status: Election["status"] = "open"): Election => ({
  id: "e1", title: "Eleição 2026", societyName: "UMP", status,
});
const round: Round = {
  id: "r1", position: "presidente", number: 1,
  options: [{id: "a", name: "Ana"}, {id: "b", name: "Bia"}],
};
const voter = (status: Voter["status"]): Voter => ({status, kind: "guest", name: "Maria"});
const signedIn = (isAnonymous = false) => ({
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
  api.signInWithPassword.mockReset().mockResolvedValue(undefined);
  api.signInWithGoogle.mockReset().mockResolvedValue(undefined);
});

describe("VotePage", () => {
  it("enquanto a sessão carrega não mostra as opções de entrada", () => {
    auth.state = {status: "loading"};
    render(<VotePage electionId="e1" />);
    expect(screen.getByText("Carregando...")).toBeInTheDocument();
    expect(screen.queryByRole("button", {name: "Entrar com Google"})).not.toBeInTheDocument();
  });

  it("mostra título e pede para entrar com Google ou e-mail; não há voto sem conta", () => {
    render(<VotePage electionId="e1" />);
    expect(screen.getByText("Eleição 2026")).toBeInTheDocument();
    expect(screen.getByRole("button", {name: "Entrar com Google"})).toBeInTheDocument();
    expect(screen.getByRole("button", {name: "Entrar com e-mail e senha"})).toBeInTheDocument();
    expect(screen.queryByRole("button", {name: "Votar sem conta"})).not.toBeInTheDocument();
  });

  it("entrar com Google chama o login do Google", async () => {
    render(<VotePage electionId="e1" />);
    fireEvent.click(screen.getByRole("button", {name: "Entrar com Google"}));
    await waitFor(() => expect(api.signInWithGoogle).toHaveBeenCalled());
  });

  it("entrar com e-mail e senha", async () => {
    render(<VotePage electionId="e1" />);
    fireEvent.click(screen.getByRole("button", {name: "Entrar com e-mail e senha"}));
    fireEvent.change(screen.getByLabelText("E-mail"), {target: {value: "ana@ipe.org"}});
    fireEvent.change(screen.getByLabelText("Senha"), {target: {value: "segredo"}});
    fireEvent.click(screen.getByRole("button", {name: "Entrar"}));
    await waitFor(() => expect(api.signInWithPassword).toHaveBeenCalledWith("ana@ipe.org", "segredo"));
  });

  it("sessão anônima antiga é tratada como deslogada", () => {
    auth.state = signedIn(true);
    api.voter = null;
    render(<VotePage electionId="e1" />);
    expect(screen.getByRole("button", {name: "Entrar com Google"})).toBeInTheDocument();
    expect(api.checkIn).not.toHaveBeenCalled();
  });

  it("logado faz check-in automático, sem formulário", async () => {
    auth.state = signedIn();
    api.voter = null;
    render(<VotePage electionId="e1" />);
    await waitFor(() => expect(api.checkIn).toHaveBeenCalledWith("e1"));
    expect(screen.getByText("Verificando sua presença...")).toBeInTheDocument();
  });

  it("conta sem nome: se o check-in automático falha, pede só o nome", async () => {
    auth.state = signedIn();
    api.voter = null;
    api.checkIn.mockRejectedValueOnce(new Error("Informe seu nome."));
    render(<VotePage electionId="e1" />);
    expect(await screen.findByLabelText("Seu nome")).toBeInTheDocument();
    expect(screen.queryByLabelText("Seu e-mail")).not.toBeInTheDocument();
    expect(screen.queryByText("Verificando sua presença...")).not.toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Seu nome"), {target: {value: "Maria"}});
    fireEvent.click(screen.getByRole("button", {name: "Continuar"}));
    await waitFor(() => expect(api.checkIn).toHaveBeenLastCalledWith("e1", {name: "Maria"}));
  });

  it("pendente e recusado", () => {
    auth.state = signedIn();
    api.voter = voter("pending");
    const {rerender} = render(<VotePage electionId="e1" />);
    expect(screen.getByText(/Aguardando aprovação/)).toBeInTheDocument();
    api.voter = voter("rejected");
    rerender(<VotePage electionId="e1" key="again" />);
    expect(screen.getByText(/não foi liberada/)).toBeInTheDocument();
  });

  it("aprovado sem votação aberta aguarda", () => {
    auth.state = signedIn();
    api.voter = voter("approved");
    api.round = null;
    render(<VotePage electionId="e1" />);
    expect(screen.getByText(/Aguardando a próxima votação/)).toBeInTheDocument();
  });

  it("vota: só habilita com escolha e envia", async () => {
    auth.state = signedIn();
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
    auth.state = signedIn();
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

  it("2º escrutínio mostra só os candidatos, sem busca, e o título traz o número", () => {
    auth.state = signedIn();
    api.voter = voter("approved");
    api.round = {...round, number: 2, options: [round.options[0]]};
    api.hasVoted = false;
    render(<VotePage electionId="e1" />);
    expect(screen.getByText("Votação para Presidente — 2º escrutínio")).toBeInTheDocument();
    expect(screen.queryByLabelText("Buscar por nome")).not.toBeInTheDocument();
    expect(screen.getByLabelText("Ana")).toBeInTheDocument();
    expect(screen.queryByLabelText("Bia")).not.toBeInTheDocument();
    expect(screen.getByLabelText("Branco")).toBeInTheDocument();
  });

  it("erro do servidor ao votar aparece na tela", async () => {
    auth.state = signedIn();
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
    auth.state = signedIn();
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
