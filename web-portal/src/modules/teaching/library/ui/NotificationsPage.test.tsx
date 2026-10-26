import {fireEvent, render, screen, waitFor} from "@testing-library/react";
import type {User} from "firebase/auth";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {AuthContext, type AuthState} from "@/core/auth/AuthContext";
import type {LibraryNotification} from "../types";
import NotificationsPage from "./NotificationsPage";

const notifications = vi.hoisted(() => ({subscribeNotifications: vi.fn(), markRead: vi.fn(), markAllRead: vi.fn()}));
vi.mock("../notifications", () => notifications);
const nav = vi.hoisted(() => ({push: vi.fn()}));
vi.mock("next/navigation", () => ({useRouter: () => ({push: nav.push})}));

const list: LibraryNotification[] = [
  {id: "n1", toUid: "t1", type: "published", itemId: "i1", title: "Material publicado", body: "\"Aula\" foi aprovado.", createdAt: 5, readAt: null},
  {id: "n2", toUid: "t1", type: "returned", itemId: "i2", title: "Material devolvido", body: "\"Livro\": Link quebrado", createdAt: 3, readAt: 4},
];

function renderPage() {
  const state: AuthState = {status: "signedIn", user: {uid: "t1"} as User, claims: {admin: false, teachingRole: "teacher"}};
  render(
    <AuthContext.Provider value={{state, refreshAccess: vi.fn(), signOut: vi.fn()}}>
      <NotificationsPage />
    </AuthContext.Provider>
  );
}

beforeEach(() => {
  nav.push.mockReset();
  notifications.markRead.mockReset().mockResolvedValue(undefined);
  notifications.markAllRead.mockReset().mockResolvedValue(undefined);
  notifications.subscribeNotifications.mockReset().mockImplementation((_uid, onData) => {
    onData(list);
    return vi.fn();
  });
});

describe("NotificationsPage", () => {
  it("lista com não lidas destacadas", async () => {
    renderPage();
    expect(await screen.findByText("Material publicado")).toBeInTheDocument();
    expect(screen.getByText("Material devolvido")).toBeInTheDocument();
    expect(screen.getAllByLabelText("Não lida")).toHaveLength(1);
  });

  it("abrir marca como lida e navega para o item", async () => {
    renderPage();
    fireEvent.click(await screen.findByRole("button", {name: /Material publicado/}));
    await waitFor(() => expect(notifications.markRead).toHaveBeenCalledWith("n1"));
    expect(nav.push).toHaveBeenCalledWith("/ensino?item=i1");
  });

  it("resposta do Fórum abre o tópico", async () => {
    notifications.subscribeNotifications.mockImplementation((_uid, onData) => {
      onData([{id: "f1", toUid: "t1", type: "forum_reply", itemId: "", topicId: "top1", title: "Nova resposta no Fórum", body: "Ana: oi", createdAt: 9, readAt: null}]);
      return vi.fn();
    });
    renderPage();
    fireEvent.click(await screen.findByRole("button", {name: /Nova resposta no Fórum/}));
    await waitFor(() => expect(notifications.markRead).toHaveBeenCalledWith("f1"));
    expect(nav.push).toHaveBeenCalledWith("/ensino/forum/top1");
  });

  it("não remarca uma notificação já lida", async () => {
    renderPage();
    fireEvent.click(await screen.findByRole("button", {name: /Material devolvido/}));
    expect(notifications.markRead).not.toHaveBeenCalled();
    expect(nav.push).toHaveBeenCalledWith("/ensino?item=i2");
  });

  it("marcar todas como lidas só envia as não lidas", async () => {
    renderPage();
    fireEvent.click(await screen.findByRole("button", {name: "Marcar todas como lidas"}));
    await waitFor(() => expect(notifications.markAllRead).toHaveBeenCalledWith(["n1"]));
  });

  it("falha ao marcar todas como lidas mostra alerta", async () => {
    notifications.markAllRead.mockRejectedValue(new Error("x"));
    renderPage();
    fireEvent.click(await screen.findByRole("button", {name: "Marcar todas como lidas"}));
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível marcar as notificações como lidas.");
  });

  it("sem notificações mostra mensagem", async () => {
    notifications.subscribeNotifications.mockImplementation((_uid, onData) => {
      onData([]);
      return vi.fn();
    });
    renderPage();
    expect(await screen.findByText("Você não tem notificações.")).toBeInTheDocument();
  });

  it("erro na escuta mostra alerta", async () => {
    notifications.subscribeNotifications.mockImplementation((_uid, _onData, onError) => {
      onError(new Error("x"));
      return vi.fn();
    });
    renderPage();
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível carregar as notificações.");
  });
});
