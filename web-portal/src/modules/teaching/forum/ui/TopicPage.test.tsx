import {fireEvent, render, screen, waitFor, within} from "@testing-library/react";
import type {User} from "firebase/auth";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {AuthContext, type AuthState} from "@/core/auth/AuthContext";
import type {Comment, Topic} from "../types";
import TopicPage from "./TopicPage";

const repo = vi.hoisted(() => ({
  loadTopic: vi.fn(),
  loadComments: vi.fn(),
  loadMyVotes: vi.fn(),
  loadSubjectTags: vi.fn(),
  createComment: vi.fn(),
  editComment: vi.fn(),
  removeComment: vi.fn(),
  setTopicFlags: vi.fn(),
  setVote: vi.fn(),
  loadPublishedDocs: vi.fn(),
  loadPlanLessons: vi.fn(),
}));
vi.mock("../repository", () => repo);
vi.mock("next/navigation", async () => await import("@/test/fakeNavigation"));
vi.mock("../../library/ui/ItemModal", () => ({ItemModal: () => null}));
vi.mock("../../plan/ui/PlanLessonModal", () => ({default: () => null}));

const topic = (extra: Partial<Topic> = {}): Topic => ({
  id: "t", title: "Dúvida", body: "Veja https://a.com/x e <script>x</script>", authorUid: "u1",
  authorName: "Ana", tagIds: [], refs: [{kind: "library", id: "d1", label: "Catecismo"}],
  pinned: false, locked: false, deleted: false, createdAt: 1, updatedAt: 1, lastActivityAt: 1,
  commentCount: 3, ...extra,
});

const comment = (id: string, extra: Partial<Comment> = {}): Comment => ({
  id, topicId: "t", body: `Corpo ${id}`, authorUid: "u2", authorName: "Bia", parentId: null,
  depth: 1, refs: [], score: 0, deleted: false, createdAt: 1, ...extra,
});

let current: Topic;
let comments: Comment[];

function renderAs(uid: string, role: "teacher" | "curator" = "teacher") {
  const state: AuthState = {
    status: "signedIn",
    user: {uid, displayName: "Eu", email: "e@x.com"} as User,
    claims: {admin: false, teachingRole: role},
  };
  return render(
    <AuthContext.Provider value={{state, refreshAccess: vi.fn(), signOut: vi.fn()}}>
      <TopicPage topicId="t" />
    </AuthContext.Provider>
  );
}

beforeEach(() => {
  current = topic();
  comments = [
    comment("c1"),
    comment("c2", {parentId: "c1", depth: 2, createdAt: 2}),
    comment("c3", {parentId: "c2", depth: 3, createdAt: 3}),
  ];
  repo.loadTopic.mockReset().mockImplementation(async () => current);
  repo.loadComments.mockReset().mockImplementation(async () => comments);
  repo.loadMyVotes.mockReset().mockResolvedValue({});
  repo.loadSubjectTags.mockReset().mockResolvedValue([]);
  repo.createComment.mockReset().mockResolvedValue(undefined);
  repo.editComment.mockReset().mockResolvedValue(undefined);
  repo.removeComment.mockReset().mockResolvedValue(undefined);
  repo.setTopicFlags.mockReset().mockResolvedValue(undefined);
  repo.setVote.mockReset().mockResolvedValue(undefined);
  repo.loadPublishedDocs.mockReset().mockResolvedValue([]);
  repo.loadPlanLessons.mockReset().mockResolvedValue([]);
  vi.spyOn(window, "confirm").mockReturnValue(true);
});

describe("TopicPage — leitura", () => {
  it("mostra o texto sem HTML, links seguros, citação e a árvore de 3 níveis", async () => {
    renderAs("u9");
    expect(await screen.findByRole("heading", {name: "Dúvida"})).toBeInTheDocument();
    const link = screen.getByRole("link", {name: "https://a.com/x"});
    expect(link).toHaveAttribute("rel", "noopener noreferrer");
    expect(screen.getByText(/<script>x<\/script>/)).toBeInTheDocument();
    // A citação abre uma janela sobre o tópico (não é mais um link para outra página).
    expect(screen.getByRole("button", {name: /Catecismo/})).toBeInTheDocument();
    expect(screen.queryByRole("link", {name: /Catecismo/})).not.toBeInTheDocument();
    for (const id of ["c1", "c2", "c3"]) expect(screen.getByText(`Corpo ${id}`)).toBeInTheDocument();
    // nível 3 não tem "Responder": 2 respostas possíveis (c1, c2)
    expect(screen.getAllByRole("button", {name: "Responder"})).toHaveLength(2);
  });

  it("comentário removido vira [removido], sem Responder, e as respostas continuam", async () => {
    comments[0] = comment("c1", {deleted: true});
    renderAs("u9");
    expect(await screen.findByText("[removido]")).toBeInTheDocument();
    expect(screen.queryByText("Corpo c1")).toBeNull();
    expect(screen.getByText("Corpo c2")).toBeInTheDocument();
  });

  it("tópico removido esconde o corpo de quem não é autor nem moderador", async () => {
    current = topic({deleted: true});
    const {unmount} = renderAs("u9");
    expect(await screen.findByText("Tópico removido")).toBeInTheDocument();
    expect(screen.queryByText(/Veja/)).toBeNull();
    unmount();
    renderAs("u9", "curator");
    expect(await screen.findByText(/Veja/)).toBeInTheDocument();
  });

  it("erro de carga mostra aviso", async () => {
    repo.loadTopic.mockRejectedValue(new Error("x"));
    renderAs("u9");
    expect(await screen.findByText("Não foi possível carregar o tópico.")).toBeInTheDocument();
  });
});

describe("TopicPage — votos", () => {
  it("👍 vota, repetir retira, 👎 troca; saldo acompanha", async () => {
    renderAs("u9");
    await screen.findByText("Corpo c1");
    const first = screen.getAllByRole("button", {name: "Curtir"})[0];
    fireEvent.click(first);
    await waitFor(() => expect(repo.setVote).toHaveBeenLastCalledWith("t", "c1", "u9", 1));
    await waitFor(() => expect(screen.getAllByLabelText("Saldo de votos")[0]).toHaveTextContent("1"));
    fireEvent.click(screen.getAllByRole("button", {name: "Curtir"})[0]);
    await waitFor(() => expect(repo.setVote).toHaveBeenLastCalledWith("t", "c1", "u9", 0));
    fireEvent.click(screen.getAllByRole("button", {name: "Não curtir"})[0]);
    await waitFor(() => expect(repo.setVote).toHaveBeenLastCalledWith("t", "c1", "u9", -1));
    await waitFor(() => expect(screen.getAllByLabelText("Saldo de votos")[0]).toHaveTextContent("-1"));
  });

  it("não há botões de voto no próprio comentário", async () => {
    renderAs("u2");
    await screen.findByText("Corpo c1");
    expect(screen.queryAllByRole("button", {name: "Curtir"})).toHaveLength(0);
  });
});

describe("TopicPage — comentar e editar", () => {
  it("comenta e recarrega; responde com o pai", async () => {
    renderAs("u9");
    await screen.findByText("Corpo c1");
    fireEvent.change(screen.getByLabelText("Novo comentário"), {target: {value: "Minha opinião"}});
    fireEvent.click(screen.getByRole("button", {name: "Comentar"}));
    await waitFor(() => expect(repo.createComment).toHaveBeenCalledWith(
      "t", {body: "Minha opinião", refs: []}, {uid: "u9", name: "Eu"}, null));
    await waitFor(() => expect(repo.loadComments).toHaveBeenCalledTimes(2));

    fireEvent.click(screen.getAllByRole("button", {name: "Responder"})[0]);
    fireEvent.change(screen.getByLabelText("Sua resposta"), {target: {value: "Concordo"}});
    fireEvent.click(within(screen.getByLabelText("Sua resposta").closest("form")!).getByRole("button", {name: "Responder"}));
    await waitFor(() => expect(repo.createComment).toHaveBeenLastCalledWith(
      "t", {body: "Concordo", refs: []}, {uid: "u9", name: "Eu"}, expect.objectContaining({id: "c1"})));
  });

  it("autor edita e apaga; curador só apaga os alheios", async () => {
    const {unmount} = renderAs("u2");
    await screen.findByText("Corpo c1");
    fireEvent.click(screen.getAllByRole("button", {name: "Mais ações do comentário"})[0]);
    fireEvent.click(screen.getByRole("menuitem", {name: "Editar"}));
    fireEvent.change(screen.getByLabelText("Editar comentário"), {target: {value: "Novo texto"}});
    fireEvent.click(screen.getByRole("button", {name: "Salvar"}));
    await waitFor(() => expect(repo.editComment).toHaveBeenCalledWith("t", "c1", {body: "Novo texto", refs: []}));
    unmount();

    renderAs("u9", "curator");
    await screen.findByText("Corpo c1");
    fireEvent.click(screen.getAllByRole("button", {name: "Mais ações do comentário"})[0]);
    expect(screen.queryByRole("menuitem", {name: "Editar"})).toBeNull();
    fireEvent.click(screen.getByRole("menuitem", {name: "Apagar"}));
    await waitFor(() => expect(repo.removeComment).toHaveBeenCalledWith("t", "c1"));
  });

  it("falha ao comentar mantém o texto e avisa", async () => {
    repo.createComment.mockRejectedValue(new Error("x"));
    renderAs("u9");
    await screen.findByText("Corpo c1");
    fireEvent.change(screen.getByLabelText("Novo comentário"), {target: {value: "Texto"}});
    fireEvent.click(screen.getByRole("button", {name: "Comentar"}));
    expect(await screen.findByText("Não foi possível salvar. Tente novamente.")).toBeInTheDocument();
    expect(screen.getByLabelText("Novo comentário")).toHaveValue("Texto");
  });
});

describe("TopicPage — moderação e tópico trancado", () => {
  it("curador fixa, tranca e apaga o tópico", async () => {
    renderAs("u9", "curator");
    const openMenu = async () => fireEvent.click(await screen.findByRole("button", {name: "Ações do tópico"}));
    await openMenu();
    fireEvent.click(screen.getByRole("menuitem", {name: "Fixar"}));
    await waitFor(() => expect(repo.setTopicFlags).toHaveBeenLastCalledWith("t", {pinned: true}));
    await openMenu();
    fireEvent.click(screen.getByRole("menuitem", {name: "Trancar"}));
    await waitFor(() => expect(repo.setTopicFlags).toHaveBeenLastCalledWith("t", {locked: true}));
    await openMenu();
    fireEvent.click(screen.getByRole("menuitem", {name: "Apagar"}));
    await waitFor(() => expect(repo.setTopicFlags).toHaveBeenLastCalledWith("t", {deleted: true}));
  });

  it("professor comum não vê Fixar/Trancar", async () => {
    renderAs("u9");
    await screen.findByText("Corpo c1");
    expect(screen.queryByRole("button", {name: "Ações do tópico"})).toBeNull();
    expect(screen.queryByRole("menuitem", {name: "Fixar"})).toBeNull();
  });

  it("tópico trancado avisa e esconde formulário, Responder e votos", async () => {
    current = topic({locked: true});
    renderAs("u9");
    expect(await screen.findByText("Tópico trancado.")).toBeInTheDocument();
    expect(screen.queryByLabelText("Novo comentário")).toBeNull();
    expect(screen.queryAllByRole("button", {name: "Responder"})).toHaveLength(0);
    expect(screen.queryAllByRole("button", {name: "Curtir"})).toHaveLength(0);
  });
});
