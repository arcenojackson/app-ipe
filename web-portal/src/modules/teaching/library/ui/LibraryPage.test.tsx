import {render, screen, waitFor, fireEvent} from "@testing-library/react";
import {useState} from "react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {LibraryItem, Viewer} from "../types";
import {LibraryContent} from "./LibraryPage";

const repo = vi.hoisted(() => ({
  subscribeFolder: vi.fn(),
  loadAllVisible: vi.fn(),
}));
vi.mock("../repository", () => repo);

const item = (id: string, name: string, extra: Partial<LibraryItem> = {}): LibraryItem => ({
  id, name, type: "file", parentId: null, authorId: "a", status: "published", version: 1, ...extra,
});
const folder = (id: string, name: string, parentId: string | null = null) =>
  item(id, name, {type: "folder", status: "active", parentId});

const catalog = [
  folder("f1", "Crianças"),
  folder("f2", "Antigo Testamento", "f1"),
  item("i1", "Catecismo Menor"),
  item("i2", "Aula 2", {parentId: "f1"}),
  item("i3", "Aula 10", {parentId: "f1", status: "in_review"}),
  item("i4", "Livro", {parentId: "f1", type: "link", url: "https://x.org", status: "returned"}),
];

const teacher: Viewer = {uid: "t1", isCurator: false, isAdmin: false};
const folderData = (id: string | null) => catalog.filter((i) => i.parentId === id);

let unsubscribe: ReturnType<typeof vi.fn>;
beforeEach(() => {
  unsubscribe = vi.fn();
  repo.subscribeFolder.mockReset().mockImplementation((id, _viewer, onData) => {
    onData(folderData(id));
    return unsubscribe;
  });
  repo.loadAllVisible.mockReset().mockResolvedValue(catalog);
});

function renderAt(folderId: string | null, navigate = vi.fn(), itemId: string | null = null) {
  render(<LibraryContent viewer={teacher} folderId={folderId} itemId={itemId} navigate={navigate} />);
  return navigate;
}

describe("LibraryContent", () => {
  it("lista a raiz com pastas primeiro e selos de estado", async () => {
    renderAt(null);
    expect(await screen.findByText("Crianças")).toBeInTheDocument();
    const rows = screen.getAllByRole("button", {name: /Abrir /});
    expect(rows.map((r) => r.getAttribute("aria-label"))).toEqual(["Abrir Crianças", "Abrir Catecismo Menor"]);
    expect(screen.getByText("Catecismo Menor")).toBeInTheDocument();
    expect(screen.getByText("Publicado")).toBeInTheDocument();
  });

  it("em uma pasta mostra em revisão e devolvido", async () => {
    renderAt("f1");
    expect(await screen.findByText("Aula 10")).toBeInTheDocument();
    const rows = screen.getAllByRole("button", {name: /Abrir /});
    expect(rows[0]).toHaveAccessibleName("Abrir Antigo Testamento");
    expect(screen.getByText("Em revisão")).toBeInTheDocument();
    expect(screen.getByText("Devolvido")).toBeInTheDocument();
  });

  it("abrir uma pasta navega para ?pasta=; abrir um arquivo mantém a pasta e adiciona ?item=", async () => {
    const navigate = renderAt("f1");
    fireEvent.click(await screen.findByRole("button", {name: "Abrir Antigo Testamento"}));
    expect(navigate).toHaveBeenCalledWith("/ensino/biblioteca?pasta=f2");
    fireEvent.click(screen.getByRole("button", {name: "Abrir Aula 2"}));
    expect(navigate).toHaveBeenCalledWith("/ensino/biblioteca?pasta=f1&item=i2");
  });

  it("migalhas: da biblioteca até a pasta, clicáveis", async () => {
    const navigate = renderAt("f2");
    await screen.findByText("Esta pasta está vazia.");
    const nav = screen.getByRole("navigation", {name: "Caminho"});
    expect(nav).toHaveTextContent("Biblioteca");
    expect(nav).toHaveTextContent("Crianças");
    fireEvent.click(screen.getByRole("button", {name: "Crianças"}));
    expect(navigate).toHaveBeenCalledWith("/ensino/biblioteca?pasta=f1");
    fireEvent.click(screen.getByRole("button", {name: "Biblioteca"}));
    expect(navigate).toHaveBeenCalledWith("/ensino/biblioteca");
  });

  it("a busca filtra todos os itens visíveis pelo nome, sem acento nem maiúscula", async () => {
    renderAt(null);
    await screen.findByText("Crianças");
    fireEvent.change(screen.getByLabelText("Buscar na biblioteca"), {target: {value: "AULA"}});
    expect(await screen.findByText("Aula 2")).toBeInTheDocument();
    expect(screen.getByText("Aula 10")).toBeInTheDocument();
    expect(screen.queryByText("Catecismo Menor")).not.toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Buscar na biblioteca"), {target: {value: "zzz"}});
    expect(await screen.findByText("Nada encontrado.")).toBeInTheDocument();
  });

  it("pasta inexistente ou sem acesso mostra aviso com volta para a raiz", async () => {
    const navigate = renderAt("fantasma");
    expect(await screen.findByText("Pasta não encontrada ou sem acesso.")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", {name: "Voltar para a biblioteca"}));
    expect(navigate).toHaveBeenCalledWith("/ensino/biblioteca");
  });

  it("erro ao carregar a pasta mostra alerta", async () => {
    repo.subscribeFolder.mockImplementation((_id, _viewer, _onData, onError) => {
      onError(new Error("permission-denied"));
      return unsubscribe;
    });
    renderAt(null);
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível carregar esta pasta.");
    expect(screen.queryByText("Esta pasta está vazia.")).not.toBeInTheDocument();
  });

  it("enquanto a pasta nova não responde mostra Carregando e nada da pasta anterior", async () => {
    const { rerender } = render(<LibraryContent viewer={teacher} folderId="f1" itemId={null} navigate={vi.fn()} />);
    await screen.findByText("Aula 2");
    repo.subscribeFolder.mockImplementation(() => unsubscribe);
    rerender(<LibraryContent viewer={teacher} folderId="f2" itemId={null} navigate={vi.fn()} />);
    expect(await screen.findByText("Carregando…")).toBeInTheDocument();
    expect(screen.queryByText("Aula 2")).not.toBeInTheDocument();
    expect(screen.queryByText("Esta pasta está vazia.")).not.toBeInTheDocument();
  });

  it("busca com o catálogo ainda carregando mostra Carregando, não Nada encontrado", async () => {
    repo.loadAllVisible.mockReturnValue(new Promise(() => {}));
    renderAt(null);
    await screen.findByText("Crianças");
    fireEvent.change(screen.getByLabelText("Buscar na biblioteca"), {target: {value: "x"}});
    expect(screen.getByText("Carregando…")).toBeInTheDocument();
    expect(screen.queryByText("Nada encontrado.")).not.toBeInTheDocument();
  });

  it("busca com erro no catálogo mostra só o alerta", async () => {
    repo.loadAllVisible.mockRejectedValue(new Error("x"));
    renderAt(null);
    await screen.findByText("Crianças");
    fireEvent.change(screen.getByLabelText("Buscar na biblioteca"), {target: {value: "x"}});
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível carregar a biblioteca.");
    expect(screen.queryByText("Nada encontrado.")).not.toBeInTheDocument();
    expect(screen.queryByText("Carregando…")).not.toBeInTheDocument();
  });

  function Harness() {
    const [folderId, setFolderId] = useState<string | null>(null);
    return (
      <LibraryContent
        viewer={teacher}
        folderId={folderId}
        itemId={null}
        navigate={(url) => setFolderId(new URL(url, "http://x").searchParams.get("pasta"))}
      />
    );
  }

  it("navegar limpa a busca e mostra o conteúdo da pasta (clique em resultado)", async () => {
    render(<Harness />);
    await screen.findByText("Crianças");
    fireEvent.change(screen.getByLabelText("Buscar na biblioteca"), {target: {value: "crian"}});
    fireEvent.click(await screen.findByRole("button", {name: "Abrir Crianças"}));
    expect(screen.getByLabelText("Buscar na biblioteca")).toHaveValue("");
    expect(await screen.findByText("Aula 2")).toBeInTheDocument();
    expect(screen.queryByText("Catecismo Menor")).not.toBeInTheDocument();
  });

  it("navegar limpa a busca (migalha)", async () => {
    render(<Harness />);
    fireEvent.click(await screen.findByRole("button", {name: "Abrir Crianças"}));
    await screen.findByText("Aula 2");
    fireEvent.change(screen.getByLabelText("Buscar na biblioteca"), {target: {value: "catec"}});
    expect(await screen.findByText("Catecismo Menor")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", {name: "Biblioteca"}));
    expect(screen.getByLabelText("Buscar na biblioteca")).toHaveValue("");
    expect(await screen.findByText("Crianças")).toBeInTheDocument();
  });

  it("resultados da busca mostram o caminho de cada item", async () => {
    renderAt(null);
    await screen.findByText("Crianças");
    fireEvent.change(screen.getByLabelText("Buscar na biblioteca"), {target: {value: "catec"}});
    expect(await screen.findByText("Biblioteca", {selector: "span.block"})).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Buscar na biblioteca"), {target: {value: "aula 2"}});
    expect(await screen.findByText("Crianças", {selector: "span.block.text-xs"})).toBeInTheDocument();
  });

  it("trocar de pasta cancela a escuta anterior e assina a nova", async () => {
    const {rerender} = render(<LibraryContent viewer={teacher} folderId="f1" itemId={null} navigate={vi.fn()} />);
    await screen.findByText("Aula 2");
    rerender(<LibraryContent viewer={teacher} folderId="f2" itemId={null} navigate={vi.fn()} />);
    await waitFor(() => expect(unsubscribe).toHaveBeenCalled());
    expect(repo.subscribeFolder).toHaveBeenLastCalledWith("f2", teacher, expect.any(Function), expect.any(Function));
    expect(await screen.findByText("Esta pasta está vazia.")).toBeInTheDocument();
  });

  it("alterna entre lista e grade", async () => {
    renderAt(null);
    await screen.findByText("Crianças");
    expect(screen.getByRole("button", {name: "Ver em lista"})).toHaveAttribute("aria-pressed", "true");
    fireEvent.click(screen.getByRole("button", {name: "Ver em grade"}));
    expect(screen.getByRole("button", {name: "Ver em grade"})).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByRole("button", {name: "Ver em lista"})).toHaveAttribute("aria-pressed", "false");
    expect(screen.getByTestId("folder-view")).toHaveAttribute("data-view", "grid");
    fireEvent.click(screen.getByRole("button", {name: "Ver em lista"}));
    expect(screen.getByTestId("folder-view")).toHaveAttribute("data-view", "list");
  });
});
