import {fireEvent, render, screen, waitFor} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {Topic} from "../types";
import TopicListPage from "./TopicListPage";

const repo = vi.hoisted(() => ({
  loadPinnedTopics: vi.fn(),
  loadTopicsPage: vi.fn(),
  loadSubjectTags: vi.fn(),
}));
vi.mock("../repository", () => repo);

const topic = (id: string, extra: Partial<Topic> = {}): Topic => ({
  id, title: `Tópico ${id}`, body: "", authorUid: "u", authorName: "Ana", tagIds: [],
  refs: [], pinned: false, locked: false, deleted: false, createdAt: 1, updatedAt: 1,
  lastActivityAt: 1, commentCount: 2, ...extra,
});

beforeEach(() => {
  repo.loadSubjectTags.mockReset().mockResolvedValue([{id: "assunto-fe", name: "Fé"}]);
  repo.loadPinnedTopics.mockReset().mockResolvedValue([topic("fix", {pinned: true})]);
  repo.loadTopicsPage.mockReset().mockResolvedValue({topics: [topic("a", {locked: true, tagIds: ["assunto-fe"]})], cursor: null, done: true});
});

describe("TopicListPage", () => {
  it("mostra fixados antes, selos, autor, comentários e assuntos", async () => {
    render(<TopicListPage />);
    const links = await screen.findAllByRole("link", {name: /Tópico/});
    expect(links.map((l) => l.textContent)).toEqual(["Tópico fix", "Tópico a"]);
    expect(links[0]).toHaveAttribute("href", "/ensino/forum/fix");
    expect(screen.getByText("Fixado")).toBeInTheDocument();
    expect(screen.getByText("Trancado")).toBeInTheDocument();
    expect(screen.getAllByText("2 comentários").length).toBe(2);
    await waitFor(() => expect(screen.getByText("Fé", {selector: "span"})).toBeInTheDocument());
  });

  it("botão Novo tópico leva à criação", async () => {
    render(<TopicListPage />);
    expect(await screen.findByRole("link", {name: "Novo tópico"})).toHaveAttribute("href", "/ensino/forum/novo");
  });

  it("lista vazia e erro de carga", async () => {
    repo.loadPinnedTopics.mockResolvedValue([]);
    repo.loadTopicsPage.mockResolvedValue({topics: [], cursor: null, done: true});
    const {unmount} = render(<TopicListPage />);
    expect(await screen.findByText("Nenhum tópico ainda.")).toBeInTheDocument();
    unmount();
    repo.loadTopicsPage.mockRejectedValue(new Error("x"));
    render(<TopicListPage />);
    expect(await screen.findByText("Não foi possível carregar o fórum.")).toBeInTheDocument();
  });

  it("Carregar mais busca a próxima página com o cursor", async () => {
    const cursor = {id: "cur"};
    repo.loadTopicsPage
      .mockResolvedValueOnce({topics: [topic("a")], cursor, done: false})
      .mockResolvedValueOnce({topics: [topic("b")], cursor: null, done: true});
    render(<TopicListPage />);
    fireEvent.click(await screen.findByRole("button", {name: "Carregar mais"}));
    expect(await screen.findByRole("link", {name: "Tópico b"})).toBeInTheDocument();
    expect(repo.loadTopicsPage).toHaveBeenLastCalledWith({tagId: "", search: ""}, cursor);
    expect(screen.queryByRole("button", {name: "Carregar mais"})).toBeNull();
  });

  it("escolher assunto limpa a busca e vice-versa", async () => {
    render(<TopicListPage />);
    await screen.findByRole("link", {name: "Tópico a"});
    fireEvent.change(screen.getByLabelText("Buscar no título"), {target: {value: "graça"}});
    fireEvent.click(screen.getByRole("button", {name: "Buscar"}));
    await waitFor(() => expect(repo.loadTopicsPage).toHaveBeenLastCalledWith({tagId: "", search: "graça"}, null));
    await waitFor(() => expect(screen.getByRole("option", {name: "Fé"})).toBeInTheDocument());
    fireEvent.change(screen.getByLabelText("Assunto"), {target: {value: "assunto-fe"}});
    await waitFor(() => expect(repo.loadTopicsPage).toHaveBeenLastCalledWith({tagId: "assunto-fe", search: ""}, null));
    expect(screen.getByLabelText("Buscar no título")).toHaveValue("");
  });
});
