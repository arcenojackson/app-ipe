import {act, fireEvent, render, screen} from "@testing-library/react";
import {afterEach, beforeEach, describe, expect, it, vi} from "vitest";
import type {Tag} from "../tags";
import type {LibraryItem, Viewer} from "../types";
import {LibraryContent} from "./LibraryPage";

const page = vi.hoisted(() => ({useLibraryPage: vi.fn()}));
vi.mock("../useLibraryPage", () => page);

const tagList: Tag[] = [
  {id: "tipo-artigos", kind: "type", name: "Artigos", order: 1, active: true},
  {id: "assunto-trindade", kind: "subject", name: "Trindade", order: 1, active: true},
  {id: "faixa-ump", kind: "age", name: "UMP", order: 1, active: true},
];
vi.mock("../useTags", () => ({
  useTags: () => ({
    tags: tagList,
    error: null,
    byId: new Map(tagList.map((t) => [t.id, t])),
    active: (kind: string) => tagList.filter((t) => t.kind === kind && t.active),
  }),
}));

const repo = vi.hoisted(() => ({loadUserNames: vi.fn()}));
vi.mock("../repository", () => repo);

const notifications = vi.hoisted(() => ({subscribeNotifications: vi.fn()}));
vi.mock("../notifications", () => notifications);

vi.mock("./ItemModal", () => ({
  ItemModal: ({itemId, onClose}: {itemId: string; onClose: () => void}) => (
    <div data-testid="item-modal">
      {itemId}
      <button type="button" onClick={onClose}>Fechar janela</button>
    </div>
  ),
}));

const item = (id: string, name: string, extra: Partial<LibraryItem> = {}): LibraryItem => ({
  id, name, type: "file", parentId: null, authorId: "u1", status: "published", version: 1,
  typeTags: [], subjectTags: [], ageTags: [], publishedAt: 1_700_000_000_000, ...extra,
});

const teacher: Viewer = {uid: "t1", isCurator: false, isAdmin: false};
const curator: Viewer = {uid: "c1", isCurator: true, isAdmin: false};

let state: {items: LibraryItem[]; loading: boolean; error: string | null; done: boolean; loadMore: ReturnType<typeof vi.fn>};
const lastFilters = () => page.useLibraryPage.mock.calls.at(-1)?.[0];

function renderPage(viewer: Viewer = teacher, itemId: string | null = null, navigate = vi.fn()) {
  render(<LibraryContent viewer={viewer} itemId={itemId} navigate={navigate} />);
  return navigate;
}

beforeEach(() => {
  state = {items: [item("a", "Santidade"), item("b", "Aula 2")], loading: false, error: null, done: true, loadMore: vi.fn()};
  page.useLibraryPage.mockReset().mockImplementation(() => state);
  repo.loadUserNames.mockReset().mockResolvedValue({u1: "Felipe"});
  notifications.subscribeNotifications.mockReset().mockReturnValue(() => undefined);
});

afterEach(() => {
  vi.useRealTimers();
});

describe("LibraryContent", () => {
  it("lista o que o hook devolve, com o autor", async () => {
    renderPage();
    expect(screen.getByRole("button", {name: /Santidade/})).toBeInTheDocument();
    expect(screen.getByRole("button", {name: /Aula 2/})).toBeInTheDocument();
    expect((await screen.findAllByText("Felipe")).length).toBe(2);
    expect(repo.loadUserNames).toHaveBeenCalledWith(["u1"]);
  });

  it("filtro marcado passa os filtros ao hook", () => {
    renderPage();
    fireEvent.click(screen.getByRole("button", {name: /Faixa/}));
    fireEvent.click(screen.getByRole("checkbox", {name: "UMP"}));
    expect(lastFilters()).toEqual({typeTags: [], subjectTags: [], ageTags: ["faixa-ump"], text: ""});
  });

  it("a busca só chega ao hook depois de 300 ms", () => {
    vi.useFakeTimers();
    renderPage();
    fireEvent.change(screen.getByLabelText("Buscar na biblioteca"), {target: {value: "fé"}});
    expect(lastFilters().text).toBe("");
    act(() => {
      vi.advanceTimersByTime(299);
    });
    expect(lastFilters().text).toBe("");
    act(() => {
      vi.advanceTimersByTime(1);
    });
    expect(lastFilters().text).toBe("fé");
  });

  it("mostra Carregar mais enquanto done=false e chama loadMore", () => {
    state.done = false;
    renderPage();
    fireEvent.click(screen.getByRole("button", {name: "Carregar mais"}));
    expect(state.loadMore).toHaveBeenCalled();
  });

  it("não mostra Carregar mais quando done=true", () => {
    renderPage();
    expect(screen.queryByRole("button", {name: "Carregar mais"})).not.toBeInTheDocument();
  });

  it("zero itens e done mostra Nenhum arquivo encontrado.", () => {
    state.items = [];
    renderPage();
    expect(screen.getByText("Nenhum arquivo encontrado.")).toBeInTheDocument();
  });

  it("zero itens com done=false mantém Carregar mais em vez de dizer que não há nada", () => {
    state = {...state, items: [], done: false};
    renderPage();
    expect(screen.queryByText("Nenhum arquivo encontrado.")).not.toBeInTheDocument();
    expect(screen.getByRole("button", {name: "Carregar mais"})).toBeInTheDocument();
  });

  it("carregando sem itens mostra Carregando…", () => {
    state = {...state, items: [], loading: true, done: false};
    renderPage();
    expect(screen.getByText("Carregando…")).toBeInTheDocument();
  });

  it("erro mostra alerta", () => {
    state.error = "Não foi possível carregar a biblioteca.";
    renderPage();
    expect(screen.getByRole("alert")).toHaveTextContent("Não foi possível carregar a biblioteca.");
  });

  it("não há botões de pasta, envio nem breadcrumbs, nem para curador", () => {
    renderPage(curator);
    for (const name of [/Nova pasta/, /Enviar/, /Adicionar link/, /Gerenciar pasta/]) {
      expect(screen.queryByRole("button", {name})).not.toBeInTheDocument();
    }
    expect(screen.queryByRole("navigation", {name: /Caminho/i})).not.toBeInTheDocument();
  });

  it("clicar num arquivo abre ?item=ID", () => {
    const navigate = renderPage();
    fireEvent.click(screen.getByRole("button", {name: /Santidade/}));
    expect(navigate).toHaveBeenCalledWith("/ensino/biblioteca?item=a");
  });

  it("?item=ID renderiza a janela do item e fechar volta à biblioteca", () => {
    const navigate = renderPage(teacher, "a");
    expect(screen.getByTestId("item-modal")).toHaveTextContent("a");
    fireEvent.click(screen.getByRole("button", {name: "Fechar janela"}));
    expect(navigate).toHaveBeenCalledWith("/ensino/biblioteca");
  });
});
