import {fireEvent, render, screen, waitFor} from "@testing-library/react";
import type {User} from "firebase/auth";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {AuthContext, type AuthState} from "@/core/auth/AuthContext";
import NewTopicPage from "./NewTopicPage";

const nav = vi.hoisted(() => ({push: vi.fn(), edit: null as string | null}));
vi.mock("next/navigation", () => ({
  useRouter: () => ({push: nav.push}),
  useSearchParams: () => new URLSearchParams(nav.edit ? `editar=${nav.edit}` : ""),
}));

const repo = vi.hoisted(() => ({
  createTopic: vi.fn(),
  editTopic: vi.fn(),
  loadTopic: vi.fn(),
  loadSubjectTags: vi.fn(),
  loadPublishedDocs: vi.fn(),
  loadPlanLessons: vi.fn(),
}));
vi.mock("../repository", () => repo);

function renderPage() {
  const state: AuthState = {
    status: "signedIn",
    user: {uid: "t1", displayName: "Teresa", email: "t@x.com"} as User,
    claims: {admin: false, teachingRole: "teacher"},
  };
  return render(
    <AuthContext.Provider value={{state, refreshAccess: vi.fn(), signOut: vi.fn()}}>
      <NewTopicPage />
    </AuthContext.Provider>
  );
}

const fill = (title: string, body: string) => {
  fireEvent.change(screen.getByLabelText("Título"), {target: {value: title}});
  fireEvent.change(screen.getByLabelText("Mensagem"), {target: {value: body}});
};

beforeEach(() => {
  nav.push.mockReset();
  nav.edit = null;
  repo.createTopic.mockReset().mockResolvedValue("novo-id");
  repo.editTopic.mockReset().mockResolvedValue(undefined);
  repo.loadTopic.mockReset();
  repo.loadSubjectTags.mockReset().mockResolvedValue([
    {id: "a", name: "Fé"}, {id: "b", name: "Graça"}, {id: "c", name: "Oração"}, {id: "d", name: "Missões"},
  ]);
  repo.loadPublishedDocs.mockReset().mockResolvedValue([
    {kind: "library", id: "d1", label: "Catecismo.pdf"},
  ]);
  repo.loadPlanLessons.mockReset().mockResolvedValue([{kind: "plan", id: "aula-01", label: "Aula 1 — Fé"}]);
});

describe("NewTopicPage", () => {
  it("mostra o erro de validação e não grava", async () => {
    renderPage();
    fill("ab", "texto");
    fireEvent.click(screen.getByRole("button", {name: "Publicar"}));
    expect(await screen.findByRole("alert")).toHaveTextContent(/título/);
    expect(repo.createTopic).not.toHaveBeenCalled();
  });

  it("publica com autor, assuntos e citação e navega para o tópico", async () => {
    renderPage();
    fill("Dúvida", "Como explicar?");
    fireEvent.click(await screen.findByLabelText("Fé"));
    fireEvent.click(screen.getByRole("button", {name: "Citar documento ou aula"}));
    fireEvent.click(await screen.findByRole("button", {name: "Catecismo.pdf"}));
    fireEvent.click(screen.getByRole("button", {name: "Publicar"}));
    await waitFor(() => expect(nav.push).toHaveBeenCalledWith("/ensino/forum/novo-id"));
    expect(repo.createTopic).toHaveBeenCalledWith(
      {title: "Dúvida", body: "Como explicar?", tagIds: ["a"], refs: [{kind: "library", id: "d1", label: "Catecismo.pdf"}]},
      {uid: "t1", name: "Teresa"}
    );
  });

  it("recusa o 4º assunto", async () => {
    renderPage();
    for (const name of ["Fé", "Graça", "Oração", "Missões"]) {
      fireEvent.click(await screen.findByLabelText(name));
    }
    expect(screen.getByLabelText("Missões")).not.toBeChecked();
    expect(screen.getByLabelText("Oração")).toBeChecked();
  });

  it("falha ao gravar mantém o texto e avisa", async () => {
    repo.createTopic.mockRejectedValue(new Error("x"));
    renderPage();
    fill("Dúvida", "Texto");
    fireEvent.click(screen.getByRole("button", {name: "Publicar"}));
    expect(await screen.findByText("Não foi possível publicar. Tente novamente.")).toBeInTheDocument();
    expect(screen.getByLabelText("Mensagem")).toHaveValue("Texto");
    expect(nav.push).not.toHaveBeenCalled();
  });

  it("edita o próprio tópico; de outro autor fica bloqueado", async () => {
    nav.edit = "t9";
    repo.loadTopic.mockResolvedValue({
      id: "t9", title: "Antigo", body: "Corpo", authorUid: "t1", authorName: "Teresa", tagIds: [], refs: [],
      pinned: false, locked: false, deleted: false, createdAt: 1, updatedAt: 1, lastActivityAt: 1, commentCount: 0,
    });
    const {unmount} = renderPage();
    await waitFor(() => expect(screen.getByLabelText("Título")).toHaveValue("Antigo"));
    fireEvent.click(screen.getByRole("button", {name: "Salvar"}));
    await waitFor(() => expect(nav.push).toHaveBeenCalledWith("/ensino/forum/t9"));
    expect(repo.editTopic).toHaveBeenCalledWith("t9", expect.objectContaining({title: "Antigo"}));
    unmount();
    repo.loadTopic.mockResolvedValue({
      id: "t9", title: "A", body: "B", authorUid: "outro", authorName: "X", tagIds: [], refs: [],
      pinned: false, locked: false, deleted: false, createdAt: 1, updatedAt: 1, lastActivityAt: 1, commentCount: 0,
    });
    renderPage();
    expect(await screen.findByText("Você não pode editar este tópico.")).toBeInTheDocument();
  });
});
