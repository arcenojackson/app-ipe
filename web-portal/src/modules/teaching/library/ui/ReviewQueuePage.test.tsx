import {fireEvent, render, screen} from "@testing-library/react";
import type {User} from "firebase/auth";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {AuthContext, type AuthState} from "@/core/auth/AuthContext";
import type {LibraryItem, LibraryVote} from "../types";
import ReviewQueuePage from "./ReviewQueuePage";

const repo = vi.hoisted(() => ({loadReviewQueue: vi.fn(), loadVotes: vi.fn(), loadAllVisible: vi.fn(), countCurators: vi.fn()}));
vi.mock("../repository", () => repo);
const nav = vi.hoisted(() => ({push: vi.fn()}));
vi.mock("next/navigation", () => ({useRouter: () => ({push: nav.push})}));

const item = (id: string, name: string, extra: Partial<LibraryItem> = {}): LibraryItem => ({
  id, name, type: "file", parentId: "f1", authorId: "t1", status: "in_review", version: 1, ...extra,
});
const folder: LibraryItem = {id: "f1", name: "Crianças", type: "folder", parentId: null, authorId: "c9", status: "active", version: 1};

function renderAs(uid: string, claims = {admin: false, teachingRole: "curator" as const}) {
  const state: AuthState = {status: "signedIn", user: {uid} as User, claims};
  return render(
    <AuthContext.Provider value={{state, refreshAccess: vi.fn(), signOut: vi.fn()}}>
      <ReviewQueuePage />
    </AuthContext.Provider>
  );
}

beforeEach(() => {
  nav.push.mockReset();
  repo.countCurators.mockReset().mockResolvedValue(3);
  repo.loadAllVisible.mockReset().mockResolvedValue([folder]);
  repo.loadVotes.mockReset().mockImplementation(async (id: string): Promise<LibraryVote[]> =>
    id === "i1" ? [{id: "v1", voterId: "c3", action: "approve", version: 1, createdAt: 1}] : []);
  repo.loadReviewQueue.mockReset().mockResolvedValue({
    inReview: [item("i1", "Aula 1"), item("i2", "Meu envio", {authorId: "c1"}), item("i3", "Já votei")],
    deleteRequests: [item("d1", "Livro antigo", {status: "published", deleteRequest: {id: "r1", requestedBy: "c9", requestedAt: 1, reason: "Obsoleto"}})],
  });
});

describe("ReviewQueuePage", () => {
  it("lista os envios que o curador ainda pode votar, com o andamento, e os pedidos de exclusão", async () => {
    renderAs("c1");
    expect(await screen.findByText("Aula 1")).toBeInTheDocument();
    expect(screen.getByText("1/2 aprovações")).toBeInTheDocument();
    expect(screen.getByText("Livro antigo")).toBeInTheDocument();
    expect(screen.getByText(/Obsoleto/)).toBeInTheDocument();
    expect(screen.queryByText("Meu envio")).not.toBeInTheDocument();
  });

  it("quem já votou na versão atual não vê o item pendente", async () => {
    repo.loadVotes.mockImplementation(async (id: string) =>
      id === "i3" ? [{id: "v9", voterId: "c1", action: "approve", version: 1, createdAt: 1}] : []);
    renderAs("c1");
    await screen.findByText("Aula 1");
    expect(screen.queryByText("Já votei")).not.toBeInTheDocument();
  });

  it("o interruptor mostra também os itens que não precisam do meu voto", async () => {
    renderAs("c1");
    await screen.findByText("Aula 1");
    fireEvent.click(screen.getByLabelText("Mostrar todos os envios em revisão"));
    expect(await screen.findByText("Meu envio")).toBeInTheDocument();
  });

  it("abrir um item navega para a biblioteca naquele item", async () => {
    renderAs("c1");
    fireEvent.click(await screen.findByRole("button", {name: "Abrir Aula 1"}));
    expect(nav.push).toHaveBeenCalledWith("/ensino/biblioteca?item=i1");
  });

  it("fila vazia mostra mensagem", async () => {
    repo.loadReviewQueue.mockResolvedValue({inReview: [], deleteRequests: []});
    renderAs("c1");
    expect(await screen.findByText("Nada aguardando a sua revisão.")).toBeInTheDocument();
  });

  it("erro ao carregar mostra alerta", async () => {
    repo.loadReviewQueue.mockRejectedValue(new Error("x"));
    renderAs("c1");
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível carregar a fila de revisão.");
  });

  it("aviso quando há menos de 3 curadores", async () => {
    repo.countCurators.mockResolvedValue(1);
    renderAs("c1");
    expect(await screen.findByText(/Há apenas 1 curador/)).toBeInTheDocument();
  });
});
