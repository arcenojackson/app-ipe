import {act, cleanup, fireEvent, render, screen, waitFor} from "@testing-library/react";
import type {User} from "firebase/auth";
import {afterEach, beforeEach, describe, expect, it, vi} from "vitest";
import BibliotecaRedirect from "@/app/(portal)/ensino/biblioteca/page";
import {AuthContext, type AuthState} from "@/core/auth/AuthContext";
import {nav, RedirectSignal} from "@/test/fakeNavigation";
import TopicPage from "./forum/ui/TopicPage";
import LibraryPage from "./library/ui/LibraryPage";
import NotificationsPage from "./library/ui/NotificationsPage";
import ReviewQueuePage from "./library/ui/ReviewQueuePage";
import type {LibraryItem} from "./library/types";

// Integração das janelas (item/aula) com um roteador simulado que tem histórico:
// a rota de fundo nunca muda, a URL ganha ?item=/?aula=, e fechar (✕/Esc/fora),
// voltar do navegador e recarregar se comportam como no Next.
vi.mock("next/navigation", async () => await import("@/test/fakeNavigation"));

const libRepo = vi.hoisted(() => ({
  subscribeReviewQueue: vi.fn(),
  loadVotes: vi.fn(),
  countCurators: vi.fn(),
  loadUserNames: vi.fn(),
  subscribeItem: vi.fn(),
}));
vi.mock("./library/repository", () => libRepo);
vi.mock("./library/mutations", () => ({createLink: vi.fn(), uploadFile: vi.fn()}));
const notifications = vi.hoisted(() => ({subscribeNotifications: vi.fn(), markRead: vi.fn(), markAllRead: vi.fn()}));
vi.mock("./library/notifications", () => notifications);
const libraryPage = vi.hoisted(() => ({useLibraryPage: vi.fn()}));
vi.mock("./library/useLibraryPage", () => libraryPage);
vi.mock("./library/useTags", () => ({
  useTags: () => ({tags: [], error: null, byId: new Map(), active: () => []}),
}));
vi.mock("./library/ui/ItemDetail", () => ({
  ItemDetail: ({itemId, onClose}: {itemId: string; onClose: () => void}) => (
    <div data-testid="item-detail">{itemId}<button type="button" onClick={onClose}>Fechar</button></div>
  ),
}));
const forumRepo = vi.hoisted(() => ({
  loadTopic: vi.fn(), loadComments: vi.fn(), loadMyVotes: vi.fn(), loadSubjectTags: vi.fn(),
  createComment: vi.fn(), editComment: vi.fn(), removeComment: vi.fn(), setTopicFlags: vi.fn(), setVote: vi.fn(),
}));
vi.mock("./forum/repository", () => forumRepo);
const planRepo = vi.hoisted(() => ({loadPlanRow: vi.fn()}));
vi.mock("./plan/repository", () => planRepo);

const state = (role: "teacher" | "curator"): AuthState => ({
  status: "signedIn",
  user: {uid: role === "curator" ? "c1" : "t1", displayName: "Eu", email: "e@x.com"} as User,
  claims: {admin: false, teachingRole: role},
});
const withAuth = (ui: React.ReactElement, role: "teacher" | "curator" = "curator") => (
  <AuthContext.Provider value={{state: state(role), refreshAccess: vi.fn(), signOut: vi.fn()}}>{ui}</AuthContext.Provider>
);

const published = (id: string, extra: Partial<LibraryItem> = {}): LibraryItem => ({
  id, name: `Doc ${id}`, type: "file", parentId: null, authorId: "u1", status: "published", version: 1,
  typeTags: [], subjectTags: [], ageTags: [], publishedAt: 1_700_000_000_000, createdAt: 1, ...extra,
});

beforeEach(() => {
  localStorage.clear();
  libRepo.loadUserNames.mockReset().mockResolvedValue({});
  libRepo.loadVotes.mockReset().mockResolvedValue([]);
  libRepo.countCurators.mockReset().mockResolvedValue(3);
  libRepo.subscribeItem.mockReset().mockImplementation((_id: string, onData: (i: LibraryItem) => void) => {
    onData(published("i1"));
    return vi.fn();
  });
  libRepo.subscribeReviewQueue.mockReset().mockImplementation((_viewer: unknown, onData: (q: unknown) => void) => {
    onData({mine: [], toReview: [published("i1", {status: "in_review", name: "Em revisão 1"})], returned: [], deleteRequests: []});
    return vi.fn();
  });
  notifications.subscribeNotifications.mockReset().mockImplementation((_uid: string, onData: (l: unknown[]) => void) => {
    onData([{id: "n1", toUid: "c1", type: "published", itemId: "i1", title: "Material publicado", body: "ok", createdAt: 5, readAt: 4}]);
    return vi.fn();
  });
  notifications.markRead.mockReset().mockResolvedValue(undefined);
  libraryPage.useLibraryPage.mockReset().mockReturnValue({
    items: [published("i1")], loading: false, error: null, done: true, loadMore: vi.fn(), reload: vi.fn(),
  });
});

afterEach(() => cleanup());

interface Scenario {
  name: string;
  base: string;
  param?: "item" | "aula";
  id: string;
  dialog: string;
  mount: () => React.ReactElement;
  // Marca da página de fundo, que precisa continuar na tela.
  background: string | RegExp;
  open: () => Promise<unknown> | void;
}

function overlayScenarios(s: Scenario) {
  const param = s.param ?? "item";
  const dialog = () => screen.queryByRole("dialog", {name: s.dialog});
  const opened = async () => {
    await s.open();
    await waitFor(() => expect(dialog()).toBeInTheDocument());
  };

  describe(`janela sobre ${s.name}`, () => {
    beforeEach(() => nav.reset(s.base));

    it("abrir mantém a rota de fundo, a URL ganha o parâmetro e a página continua atrás", async () => {
      render(s.mount());
      await opened();
      expect(nav.pathname).toBe(s.base.split("?")[0]);
      expect(nav.search).toBe(`?${param}=${s.id}`);
      expect(nav.index).toBe(1);
      expect(screen.getAllByText(s.background).length).toBeGreaterThan(0);
    });

    it("fechar pelo ✕ volta à URL da página (uma entrada, sem empilhar)", async () => {
      render(s.mount());
      await opened();
      fireEvent.click(screen.getAllByRole("button", {name: "Fechar"})[0]);
      expect(dialog()).not.toBeInTheDocument();
      expect(nav.url).toBe(s.base);
      expect(nav.index).toBe(0);
    });

    it("fechar com Esc", async () => {
      render(s.mount());
      await opened();
      fireEvent.keyDown(window, {key: "Escape"});
      expect(dialog()).not.toBeInTheDocument();
      expect(nav.url).toBe(s.base);
      expect(nav.index).toBe(0);
    });

    it("fechar clicando fora", async () => {
      render(s.mount());
      await opened();
      fireEvent.mouseDown(dialog()!.parentElement!);
      expect(dialog()).not.toBeInTheDocument();
      expect(nav.url).toBe(s.base);
      expect(nav.index).toBe(0);
    });

    it("botão voltar do navegador fecha a janela e o avançar reabre", async () => {
      render(s.mount());
      await opened();
      act(() => nav.back());
      expect(dialog()).not.toBeInTheDocument();
      expect(nav.url).toBe(s.base);
      act(() => nav.forward());
      expect(dialog()).toBeInTheDocument();
    });

    it("recarregar com o parâmetro na URL abre a janela sobre a página certa; fechar troca a URL", async () => {
      nav.reset(`${s.base.split("?")[0]}?${param}=${s.id}`);
      render(s.mount());
      await waitFor(() => expect(dialog()).toBeInTheDocument());
      expect(nav.pathname).toBe(s.base.split("?")[0]);
      expect(screen.getAllByText(s.background).length).toBeGreaterThan(0);
      fireEvent.keyDown(window, {key: "Escape"});
      expect(dialog()).not.toBeInTheDocument();
      expect(nav.url).toBe(s.base.split("?")[0]);
      expect(nav.length).toBe(1);
    });
  });
}

overlayScenarios({
  name: "a Fila de Revisão",
  base: "/ensino/revisao",
  id: "i1",
  dialog: "Detalhes do item",
  mount: () => withAuth(<ReviewQueuePage />),
  background: "Fila de revisão",
  open: async () => fireEvent.click(await screen.findByRole("button", {name: "Abrir Em revisão 1"})),
});

overlayScenarios({
  name: "as Notificações",
  base: "/ensino/notificacoes",
  id: "i1",
  dialog: "Detalhes do item",
  mount: () => withAuth(<NotificationsPage />),
  background: "Material publicado",
  open: async () => fireEvent.click(await screen.findByRole("button", {name: /Material publicado/})),
});

overlayScenarios({
  name: "a Biblioteca (lista)",
  base: "/ensino",
  id: "i1",
  dialog: "Detalhes do item",
  mount: () => withAuth(<LibraryPage />),
  background: "Biblioteca",
  open: async () => {
    fireEvent.click(await screen.findByRole("button", {name: /Doc i1/}));
    fireEvent.click(await screen.findByRole("button", {name: "Visualizar"}));
  },
});

overlayScenarios({
  name: "a Biblioteca (grade)",
  base: "/ensino",
  id: "i1",
  dialog: "Detalhes do item",
  mount: () => withAuth(<LibraryPage />),
  background: "Biblioteca",
  open: async () => {
    fireEvent.click(await screen.findByRole("button", {name: "Grade"}));
    fireEvent.click(await screen.findByRole("button", {name: /Doc i1/}));
  },
});

const topic = {
  id: "t", title: "Dúvida", body: "Texto", authorUid: "u1", authorName: "Ana", tagIds: [],
  refs: [
    {kind: "library", id: "i1", label: "Catecismo"},
    {kind: "plan", id: "aula-52", label: "Aula 52 — Minha vida diante de Deus"},
  ],
  pinned: false, locked: false, deleted: false, createdAt: 1, updatedAt: 1, lastActivityAt: 1, commentCount: 0,
};
const mountTopic = () => withAuth(<TopicPage topicId="t" />, "teacher");

describe("Fórum: citações abrem sobre o tópico", () => {
  beforeEach(() => {
    forumRepo.loadTopic.mockReset().mockResolvedValue(topic);
    forumRepo.loadComments.mockReset().mockResolvedValue([]);
    forumRepo.loadMyVotes.mockReset().mockResolvedValue({});
    forumRepo.loadSubjectTags.mockReset().mockResolvedValue([]);
    planRepo.loadPlanRow.mockReset().mockResolvedValue({
      id: "aula-52", lesson: 52, theme: "Minha vida diante de Deus", leader: "Rev. João",
      knowledge: "Santificação", skills: "", essentials: "", notes: "", references: "",
    });
  });
  const base = "/ensino/forum/t";

  overlayScenarios({
    name: "o tópico (documento)",
    base,
    id: "i1",
    dialog: "Detalhes do item",
    mount: mountTopic,
    background: "Dúvida",
    open: async () => fireEvent.click(await screen.findByRole("button", {name: /Catecismo/})),
  });

  overlayScenarios({
    name: "o tópico (aula)",
    base,
    param: "aula",
    id: "aula-52",
    dialog: "Aula do Plano pedagógico",
    mount: mountTopic,
    background: "Dúvida",
    open: async () => fireEvent.click(await screen.findByRole("button", {name: /Aula 52/})),
  });

  it("a aula citada abre direto com os campos, sem trocar de página", async () => {
    nav.reset(base);
    render(mountTopic());
    fireEvent.click(await screen.findByRole("button", {name: /Aula 52/}));
    expect(await screen.findByText("Santificação")).toBeInTheDocument();
    expect(screen.getByRole("heading", {name: "Aula 52 — Minha vida diante de Deus"})).toBeInTheDocument();
    expect(planRepo.loadPlanRow).toHaveBeenCalledWith("aula-52");
    expect(nav.pathname).toBe(base);
  });

  it("aula que não existe mais mostra mensagem clara dentro da janela", async () => {
    planRepo.loadPlanRow.mockResolvedValue(undefined);
    nav.reset(`${base}?aula=sumiu`);
    render(mountTopic());
    expect(await screen.findByText("Esta aula não existe mais no Plano pedagógico.")).toBeInTheDocument();
  });

  it("o comentário em digitação não se perde ao abrir e fechar a janela", async () => {
    nav.reset(base);
    forumRepo.loadTopic.mockResolvedValue({...topic, locked: false});
    render(mountTopic());
    const box = await screen.findByRole("textbox");
    fireEvent.change(box, {target: {value: "rascunho em andamento"}});
    fireEvent.click(await screen.findByRole("button", {name: /Catecismo/}));
    await screen.findByRole("dialog", {name: "Detalhes do item"});
    fireEvent.keyDown(window, {key: "Escape"});
    expect(screen.getByRole("textbox")).toHaveValue("rascunho em andamento");
  });
});

describe("links antigos e vindos de push", () => {
  beforeEach(() => nav.reset("/ensino?item=i1"));

  it("/ensino/biblioteca?item=ID redireciona para /ensino?item=ID, que abre a janela sobre a Biblioteca", async () => {
    let target = "";
    try {
      await BibliotecaRedirect({searchParams: Promise.resolve({item: "i1"})});
    } catch (error) {
      if (error instanceof RedirectSignal) target = error.url;
    }
    expect(target).toBe("/ensino?item=i1");
    nav.reset(target);
    render(withAuth(<LibraryPage />));
    expect(await screen.findByRole("dialog", {name: "Detalhes do item"})).toBeInTheDocument();
    expect(nav.pathname).toBe("/ensino");
  });

  it("item não publicado vindo de push vai para a Fila de Revisão com a janela aberta", async () => {
    libRepo.subscribeItem.mockImplementation((_id: string, onData: (i: LibraryItem) => void) => {
      onData(published("i1", {status: "in_review"}));
      return vi.fn();
    });
    render(withAuth(<LibraryPage />));
    await waitFor(() => expect(nav.url).toBe("/ensino/revisao?item=i1"));
    cleanup();
    render(withAuth(<ReviewQueuePage />));
    expect(await screen.findByRole("dialog", {name: "Detalhes do item"})).toBeInTheDocument();
    expect(screen.getByRole("heading", {name: "Fila de revisão"})).toBeInTheDocument();
  });

  it("item publicado continua na Biblioteca", async () => {
    render(withAuth(<LibraryPage />));
    expect(await screen.findByRole("dialog", {name: "Detalhes do item"})).toBeInTheDocument();
    expect(nav.url).toBe("/ensino?item=i1");
  });
});
