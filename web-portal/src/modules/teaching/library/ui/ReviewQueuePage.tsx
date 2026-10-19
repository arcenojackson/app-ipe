"use client";

import {useRouter} from "next/navigation";
import {useEffect, useMemo, useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {REQUIRED_APPROVALS} from "../files";
import {itemPermissions} from "../permissions";
import {loadReviewQueue, loadVotes} from "../repository";
import {countApprovals, countDeleteApprovals, statusBadge} from "../status";
import {buildBreadcrumbs, indexById, sortItems} from "../tree";
import type {LibraryItem, LibraryVote} from "../types";
import {viewerFrom} from "../types";
import {libraryUrl} from "../url";
import {NO_VIEWER, useCatalog} from "../useLibrary";
import {CuratorWarning} from "./CuratorWarning";
import {ItemRow} from "./ItemRow";

interface Entry {
  item: LibraryItem;
  votes: LibraryVote[];
}

// Já votei na versão atual (publicação) ou no pedido atual (exclusão)?
function iVoted(item: LibraryItem, votes: LibraryVote[], uid: string): boolean {
  return votes.some((v) =>
    v.voterId === uid &&
    (item.deleteRequest ? v.requestId === item.deleteRequest.id : v.version === item.version));
}

export default function ReviewQueuePage() {
  const {state} = useAuth();
  const router = useRouter();
  const viewer = useMemo(
    () => (state.status === "signedIn" ? viewerFrom(state.user.uid, state.claims) : null),
    [state]
  );
  const catalog = useCatalog(viewer ?? NO_VIEWER);
  const [reviews, setReviews] = useState<Entry[] | null>(null);
  const [deletions, setDeletions] = useState<Entry[] | null>(null);
  const [showAll, setShowAll] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const queue = await loadReviewQueue();
        const withVotes = async (items: LibraryItem[]): Promise<Entry[]> =>
          Promise.all(items.map(async (item) => ({item, votes: await loadVotes(item.id).catch(() => [])})));
        const [r, d] = await Promise.all([withVotes(queue.inReview), withVotes(queue.deleteRequests)]);
        if (!active) return;
        setReviews(r);
        setDeletions(d);
      } catch {
        if (active) setError("Não foi possível carregar a fila de revisão.");
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  if (!viewer) return null;
  const byId = indexById(catalog.items ?? []);
  const pathOf = (item: LibraryItem) => {
    const names = buildBreadcrumbs(byId, item.parentId).map((f) => f.name);
    return names.length > 0 ? names.join(" / ") : "Biblioteca";
  };
  const open = (item: LibraryItem) => router.push(libraryUrl({pasta: item.parentId, item: item.id}));

  const visibleReviews = (reviews ?? []).filter(({item, votes}) =>
    showAll || (itemPermissions(item, viewer).canVote && !iVoted(item, votes, viewer.uid)));
  const visibleDeletions = (deletions ?? []).filter(({item, votes}) =>
    showAll || (itemPermissions(item, viewer).canVoteDelete && !iVoted(item, votes, viewer.uid)));
  const empty = reviews !== null && visibleReviews.length === 0 && visibleDeletions.length === 0;

  const rows = (entries: Entry[], deletion: boolean) => {
    const votesOf = new Map(entries.map((e) => [e.item.id, e.votes]));
    return sortItems(entries.map((e) => e.item)).map((item) => {
      const votes = votesOf.get(item.id) ?? [];
      const approvals = deletion ? countDeleteApprovals(item, votes) : countApprovals(item, votes);
      const reason = deletion && item.deleteRequest?.reason ? `: ${item.deleteRequest.reason}` : "";
      const subtitle = deletion ? `${pathOf(item)} · Pedido de exclusão${reason}` : pathOf(item);
      return (
        <div key={item.id} className="space-y-1">
          <ItemRow item={item} badge={statusBadge(item, countApprovals(item, votes))} view="list" subtitle={subtitle} onOpen={() => open(item)} />
          <p className="px-4 text-xs text-white/60">{`${approvals}/${REQUIRED_APPROVALS} aprovações`}</p>
        </div>
      );
    });
  };

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Fila de revisão</h1>
      <CuratorWarning />
      <label className="flex items-center gap-2 text-sm text-white/70">
        <input type="checkbox" checked={showAll} onChange={(e) => setShowAll(e.target.checked)} aria-label="Mostrar todos os envios em revisão" />
        Mostrar também o que não precisa do meu voto
      </label>
      {error && <p role="alert" className="text-sm text-error">{error}</p>}
      {reviews === null && !error && <p className="text-white/70">Carregando…</p>}
      {empty && <p className="rounded-card bg-surface-elevated p-6 text-center text-white/70">Nada aguardando a sua revisão.</p>}
      {visibleReviews.length > 0 && (
        <section aria-label="Envios em revisão" className="space-y-2">
          <h2 className="font-semibold">Envios em revisão</h2>
          {rows(visibleReviews, false)}
        </section>
      )}
      {visibleDeletions.length > 0 && (
        <section aria-label="Pedidos de exclusão" className="space-y-2">
          <h2 className="font-semibold">Pedidos de exclusão</h2>
          {rows(visibleDeletions, true)}
        </section>
      )}
    </div>
  );
}
