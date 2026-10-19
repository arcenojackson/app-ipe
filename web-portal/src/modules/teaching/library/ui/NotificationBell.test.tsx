import {render, screen} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {LibraryNotification} from "../types";
import {NotificationBell} from "./NotificationBell";

const notifications = vi.hoisted(() => ({subscribeNotifications: vi.fn()}));
vi.mock("../notifications", () => notifications);

const n = (id: string, readAt: number | null): LibraryNotification => ({id, toUid: "t1", type: "x", itemId: "i", title: "T", body: "B", createdAt: 1, readAt});

// Chaves: retornar o mock faria o vitest chamá-lo como limpeza do teste.
beforeEach(() => {
  notifications.subscribeNotifications.mockReset();
});

describe("NotificationBell", () => {
  it("mostra o contador de não lidas no link", () => {
    notifications.subscribeNotifications.mockImplementation((_uid, onData) => {
      onData([n("1", null), n("2", null), n("3", 5)]);
      return vi.fn();
    });
    render(<NotificationBell uid="t1" />);
    const link = screen.getByRole("link", {name: "Notificações (2 não lidas)"});
    expect(link).toHaveAttribute("href", "/ensino/notificacoes");
  });

  it("sem não lidas não mostra contador", () => {
    notifications.subscribeNotifications.mockImplementation((_uid, onData) => {
      onData([n("1", 5)]);
      return vi.fn();
    });
    render(<NotificationBell uid="t1" />);
    expect(screen.getByRole("link", {name: "Notificações"})).toBeInTheDocument();
  });

  it("cancela a escuta ao desmontar", () => {
    const stop = vi.fn();
    notifications.subscribeNotifications.mockReturnValue(stop);
    const {unmount} = render(<NotificationBell uid="t1" />);
    unmount();
    expect(stop).toHaveBeenCalled();
  });
});
