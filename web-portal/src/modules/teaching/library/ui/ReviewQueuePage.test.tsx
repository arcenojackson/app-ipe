import {fireEvent, render, screen, within} from "@testing-library/react";
import type {User} from "firebase/auth";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {AuthContext, type AuthState} from "@/core/auth/AuthContext";
import type {ReviewQueue} from "../reviewQueue";
import type {Tag} from "../tags";
import type {LibraryItem, LibraryVote} from "../types";
import ReviewQueuePage from "./ReviewQueuePage";

const repo = vi.hoisted(() => ({subscribeReviewQueue: vi.fn(), loadVotes: vi.fn(), countCurators: vi.fn()}));
vi.mock("../repository", () => repo);
const nav = vi.hoisted(() => ({push: vi.fn()}));
vi.mock("next/navigation", () => ({useRouter: () => ({push: nav.push})}));
vi.mock("./UploadPanel", () => ({UploadPanel: () => <div data-testid="upload-panel" />}));
vi.mock("./Dialogs", () => ({LinkDialog: () => <div data-testid="link-dialog" />}));
const mutations = vi.hoisted(() => ({createLink: vi.fn()}));
vi.mock("../mutations", () => mutations);
vi.mock("../notifications", () => ({subscribeNotifications: vi.fn(() => () => undefined)}));

const tagList: Tag[] = [
  {id: "tipo-artigos", kind: "type", name: "Artigos", order: 1, active: true},
  {id: "faixa-ump", kind: "age", name: "UMP", order: 1, active: true},
];
vi.mock("../useTags", () => ({
  useTags: () => ({tags: tagList, error: null, byId: new Map(tagList.map((t) => [t.id, t])), active: () => tagList}),
}));

const item = (id: string, name: string, extra: Partial<LibraryItem> = {}): LibraryItem => ({
  id, name, type: "file", parentId: null, authorId: "t1", status: "in_review", version: 1,
  typeTags: ["tipo-artigos"], subjectTags: [], ageTags: ["faixa-ump"], ...extra,
});

let queue: ReviewQueue;

function renderAs(uid: string, claims = {admin: false, teachingRole: "curator" as "curator" | "teacher"}) {
  const state: AuthState = {status: "signedIn", user: {uid} as User, claims};
  return render(
    <AuthContext.Provider value={{state, refreshAccess: vi.fn(), signOut: vi.fn()}}>
      <ReviewQueuePage />
    </AuthContext.Provider>
  );
}
const asTeacher = () => renderAs("t1", {admin: false, teachingRole: "teacher"});

beforeEach(() => {
  nav.push.mockReset();
  repo.countCurators.mockReset().mockResolvedValue(3);
  repo.loadVotes.mockReset().mockImplementation(async (id: string): Promise<LibraryVote[]> =>
    id === "i1" ? [{id: "v1", voterId: "c3", action: "approve", version: 1, createdAt: 1}] : []);
  queue = {
    mine: [
      item("m1", "Meu envio", {authorId: "c1"}),
      item("m2", "Meu devolvido", {authorId: "c1", status: "returned", returnComment: "Falta a fonte"}),
    ],
    toReview: [item("i1", "Aula 1"), item("i3", "Já votei")],
    returned: [item("r1", "Parado no autor", {authorId: "t2", status: "returned", returnComment: "Sem resposta do autor"})],
    deleteRequests: [item("d1", "Livro antigo", {status: "published", deleteRequest: {id: "r1", requestedBy: "c9", requestedAt: 1, reason: "Obsoleto"}})],
  };
  repo.subscribeReviewQueue.mockReset().mockImplementation((_viewer, onData) => {
    onData(queue);
    return vi.fn();
  });
});

const section = (name: string) => within(screen.getByRole("region", {name}));

describe("ReviewQueuePage — professor", () => {
  it("vê o envio de material e só os próprios envios", async () => {
    queue = {mine: [item("m1", "Meu envio")], toReview: [], returned: [], deleteRequests: []};
    asTeacher();
    expect(await screen.findByTestId("upload-panel")).toBeInTheDocument();
    expect(section("Meus envios").getByText("Meu envio")).toBeInTheDocument();
    expect(screen.queryByRole("region", {name: "Para revisar"})).not.toBeInTheDocument();
    expect(screen.queryByRole("region", {name: "Devolvidos aguardando o autor"})).not.toBeInTheDocument();
    expect(screen.queryByRole("region", {name: "Pedidos de exclusão"})).not.toBeInTheDocument();
  });

  it("sem envios mostra a mensagem da seção", async () => {
    queue = {mine: [], toReview: [], returned: [], deleteRequests: []};
    asTeacher();
    expect(await screen.findByText("Você ainda não enviou nada.")).toBeInTheDocument();
  });
});

describe("ReviewQueuePage — curador", () => {
  it("vê Meus envios, Para revisar (com o andamento) e Pedidos de exclusão", async () => {
    renderAs("c1");
    expect(await screen.findByText("Aula 1")).toBeInTheDocument();
    expect(section("Meus envios").getByText("Meu envio")).toBeInTheDocument();
    expect(section("Para revisar").getByText("1/2 aprovações")).toBeInTheDocument();
    expect(section("Pedidos de exclusão").getByText("Livro antigo")).toBeInTheDocument();
    expect(screen.getByText(/Obsoleto/)).toBeInTheDocument();
  });

  it("lista os devolvidos de outros autores, para o curador abrir e pedir a exclusão", async () => {
    renderAs("c1");
    await screen.findByText("Parado no autor");
    expect(section("Devolvidos aguardando o autor").getByText(/Sem resposta do autor/)).toBeInTheDocument();
    fireEvent.click(section("Devolvidos aguardando o autor").getByRole("button", {name: "Abrir Parado no autor"}));
    expect(nav.push).toHaveBeenCalledWith("/ensino?item=r1");
  });

  it("mostra as tags de cada item", async () => {
    renderAs("c1");
    await screen.findByText("Aula 1");
    expect(section("Para revisar").getAllByText("Artigos").length).toBeGreaterThan(0);
    expect(section("Para revisar").getAllByText("UMP").length).toBeGreaterThan(0);
  });

  it("item devolvido mostra o comentário de devolução", async () => {
    renderAs("c1");
    expect(await screen.findByText(/Falta a fonte/)).toBeInTheDocument();
  });

  it("quem já votou na versão atual não vê o item pendente; o interruptor mostra tudo", async () => {
    repo.loadVotes.mockImplementation(async (id: string) =>
      id === "i3" ? [{id: "v9", voterId: "c1", action: "approve", version: 1, createdAt: 1}] : []);
    renderAs("c1");
    await screen.findByText("Aula 1");
    expect(screen.queryByText("Já votei")).not.toBeInTheDocument();
    fireEvent.click(screen.getByLabelText("Mostrar também o que já votei"));
    expect(await screen.findByText("Já votei")).toBeInTheDocument();
  });

  it("clicar numa linha abre ?item=ID", async () => {
    renderAs("c1");
    fireEvent.click(await screen.findByRole("button", {name: "Abrir Aula 1"}));
    expect(nav.push).toHaveBeenCalledWith("/ensino?item=i1");
  });

  it("nada para revisar mostra a mensagem da seção", async () => {
    queue = {mine: [], toReview: [], returned: [], deleteRequests: []};
    renderAs("c1");
    expect(await screen.findByText("Nada aguardando a sua revisão.")).toBeInTheDocument();
    expect(screen.getByText("Nenhum pedido de exclusão.")).toBeInTheDocument();
  });

  it("aviso quando há menos de 3 curadores", async () => {
    repo.countCurators.mockResolvedValue(1);
    renderAs("c1");
    expect(await screen.findByText(/Há apenas 1 curador/)).toBeInTheDocument();
  });

  it("Adicionar link abre o diálogo de link", async () => {
    renderAs("c1");
    fireEvent.click(await screen.findByRole("button", {name: "Adicionar link"}));
    expect(screen.getByTestId("link-dialog")).toBeInTheDocument();
  });
});

describe("ReviewQueuePage — erros", () => {
  it("erro da assinatura vira alerta e só o primeiro conta", async () => {
    repo.subscribeReviewQueue.mockImplementation((_viewer, _onData, onError) => {
      onError(new Error("a"));
      onError(new Error("b"));
      return vi.fn();
    });
    renderAs("c1");
    expect(await screen.findAllByRole("alert")).toHaveLength(1);
    expect(screen.getByRole("alert")).toHaveTextContent("Não foi possível carregar a fila de revisão.");
  });
});
