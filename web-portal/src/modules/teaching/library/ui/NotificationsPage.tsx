"use client";

import {useRouter} from "next/navigation";
import {useEffect, useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {Button} from "@/core/ui/Button";
import {formatDateTime} from "../labels";
import {markAllRead, markRead, subscribeNotifications} from "../notifications";
import type {LibraryNotification} from "../types";
import {libraryUrl} from "../url";

export default function NotificationsPage() {
  const {state} = useAuth();
  const router = useRouter();
  const uid = state.status === "signedIn" ? state.user.uid : null;
  const [list, setList] = useState<LibraryNotification[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [marking, setMarking] = useState(false);

  useEffect(() => {
    if (!uid) return;
    // O primeiro erro é terminal: a escuta não volta sozinha.
    return subscribeNotifications(
      uid,
      (items) => {
        setList(items);
        setError(null);
      },
      () => setError((prev) => prev ?? "Não foi possível carregar as notificações.")
    );
  }, [uid]);

  async function open(n: LibraryNotification) {
    if (n.readAt === null) {
      try {
        await markRead(n.id);
      } catch {
        // abrir o item continua funcionando mesmo se marcar falhar
      }
    }
    router.push(n.topicId ? `/ensino/forum/${n.topicId}` : libraryUrl({item: n.itemId}));
  }

  const unreadIds = (list ?? []).filter((n) => n.readAt === null).map((n) => n.id);

  async function readAll() {
    setActionError(null);
    setMarking(true);
    try {
      await markAllRead(unreadIds);
    } catch {
      setActionError("Não foi possível marcar as notificações como lidas.");
    } finally {
      setMarking(false);
    }
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-2xl font-semibold">Notificações</h1>
        {unreadIds.length > 0 && (
          <Button type="button" variant="text" disabled={marking} onClick={() => void readAll()}>Marcar todas como lidas</Button>
        )}
      </div>
      {error && <p role="alert" className="text-sm text-error">{error}</p>}
      {actionError && <p role="alert" className="text-sm text-error">{actionError}</p>}
      {list === null && !error && <p className="text-white/70">Carregando…</p>}
      {list?.length === 0 && <p className="rounded-card bg-surface-elevated p-6 text-center text-white/70">Você não tem notificações.</p>}
      <ul className="space-y-2">
        {list?.map((n) => (
          <li key={n.id}>
            <button type="button" onClick={() => void open(n)} className="flex w-full items-start gap-3 rounded-card bg-surface-elevated px-4 py-3 text-left hover:brightness-125">
              {n.readAt === null ? <span aria-label="Não lida" className="mt-2 h-2 w-2 shrink-0 rounded-full bg-secondary" /> : <span className="mt-2 h-2 w-2 shrink-0" />}
              <span className="min-w-0 flex-1">
                <span className="block font-medium">{n.title}</span>
                <span className="block text-sm text-white/70">{n.body}</span>
                <span className="block text-xs text-white/50">{formatDateTime(n.createdAt)}</span>
              </span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
