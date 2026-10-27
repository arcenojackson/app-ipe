"use client";

import {useRouter, useSearchParams} from "next/navigation";
import {useMemo, useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {Icon} from "@/core/ui/icons";
import {REQUIRED_APPROVALS} from "../files";
import {iVoted} from "../reviewQueue";
import {countApprovals, countDeleteApprovals, statusBadge} from "../status";
import type {LibraryItem, LibraryVote} from "../types";
import {viewerFrom} from "../types";
import {useItemOverlay} from "../useItemOverlay";
import {useReviewQueue} from "../useReviewQueue";
import {useTags} from "../useTags";
import {CuratorWarning} from "./CuratorWarning";
import {ItemModal} from "./ItemModal";
import {QueueRow} from "./QueueRow";
import {UploadDrawer} from "./UploadDrawer";

type TabId = "review" | "mine" | "returned" | "delete";

export default function ReviewQueuePage() {
  const {state} = useAuth();
  const router = useRouter();
  const params = useSearchParams();
  const viewer = useMemo(
    () => (state.status === "signedIn" ? viewerFrom(state.user.uid, state.claims) : null),
    [state]
  );
  const {queue, votes, error} = useReviewQueue(viewer);
  const {byId: tagById} = useTags();
  const [showVoted, setShowVoted] = useState(false);
  const [drawerOpen, setDrawerOpen] = useState(params.get("novo") === "1");
  const [tab, setTab] = useState<TabId | null>(null);
  const overlay = useItemOverlay("/ensino/revisao");

  if (!viewer) return null;
  const privileged = viewer.isCurator || viewer.isAdmin;
  const open = (item: LibraryItem) => overlay.open(item.id);
  const votesOf = (item: LibraryItem): LibraryVote[] => votes[item.id] ?? [];
  const pending = (item: LibraryItem) => showVoted || !iVoted(item, votesOf(item), viewer.uid);
  const closeDrawer = () => {
    setDrawerOpen(false);
    if (params.get("novo")) router.replace("/ensino/revisao");
  };

  const row = (item: LibraryItem, kind: "mine" | "review" | "returned" | "delete") => {
    const itemVotes = votesOf(item);
    const deletion = kind === "delete";
    const approvals = deletion ? countDeleteApprovals(item, itemVotes) : countApprovals(item, itemVotes);
    const reason = item.deleteRequest?.reason;
    const note =
      (kind === "mine" || kind === "returned") && item.status === "returned" && item.returnComment ?
        `Devolvido: ${item.returnComment}` :
        deletion ? `Pedido de exclusão${reason ? `: ${reason}` : ""}` : undefined;
    const showProgress = deletion || item.status === "in_review";
    return (
      <QueueRow
        key={`${kind}-${item.id}`}
        item={item}
        badge={statusBadge(item, countApprovals(item, itemVotes))}
        byTagId={tagById}
        note={note}
        progress={showProgress ? `${approvals}/${REQUIRED_APPROVALS} aprovações` : undefined}
        onOpen={() => open(item)}
      />
    );
  };

  const toReview = (queue?.toReview ?? []).filter(pending);
  const deleteRequests = (queue?.deleteRequests ?? []).filter(pending);
  const returned = queue?.returned ?? [];
  const mine = queue?.mine ?? [];

  const tabs: Array<{id: TabId; label: string; count: number}> = privileged ?
    [
      {id: "review", label: "Para revisar", count: toReview.length},
      {id: "mine", label: "Meus envios", count: mine.length},
      ...(returned.length > 0 ? [{id: "returned" as const, label: "Devolvidos", count: returned.length}] : []),
      {id: "delete", label: "Pedidos de exclusão", count: deleteRequests.length},
    ] :
    [{id: "mine", label: "Meus envios", count: mine.length}];
  const current = tabs.find((t) => t.id === tab)?.id ?? tabs[0].id;

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-semibold">Fila de revisão</h1>
        <button
          type="button"
          onClick={() => setDrawerOpen(true)}
          className="inline-flex items-center gap-2 rounded-full bg-secondary px-5 py-2.5 text-sm font-semibold hover:brightness-110"
        >
          <Icon name="plus" className="h-4 w-4" />
          Enviar material
        </button>
      </div>
      {privileged && <CuratorWarning />}

      {overlay.itemId && <ItemModal itemId={overlay.itemId} viewer={viewer} onClose={overlay.close} />}
      {drawerOpen && <UploadDrawer uid={viewer.uid} onClose={closeDrawer} />}

      {error && <p role="alert" className="text-sm text-error">{error}</p>}
      {!queue && !error && (
        <div role="status" aria-label="Carregando" className="space-y-2">
          {[0, 1, 2].map((n) => <div key={n} className="h-16 animate-pulse rounded-card bg-surface" />)}
        </div>
      )}

      {queue && (
        <>
          {tabs.length > 1 && (
            <div role="tablist" aria-label="Seções da fila" className="flex flex-wrap gap-2">
              {tabs.map((t) => (
                <button
                  key={t.id}
                  type="button"
                  role="tab"
                  aria-selected={current === t.id}
                  onClick={() => setTab(t.id)}
                  className={`inline-flex items-center gap-2 rounded-full border px-4 py-1.5 text-sm ${
                    current === t.id ? "border-white/40 bg-white/15" : "border-white/15 text-white/70 hover:bg-white/10"
                  }`}
                >
                  {t.label}
                  {t.count > 0 && <span className="rounded-full bg-white/15 px-2 text-xs">{t.count}</span>}
                </button>
              ))}
            </div>
          )}

          {privileged && (current === "review" || current === "delete") && (
            <label className="flex items-center gap-2 text-sm text-white/70">
              <input type="checkbox" checked={showVoted} onChange={(e) => setShowVoted(e.target.checked)}
                aria-label="Mostrar também o que já votei" />
              Mostrar também o que já votei
            </label>
          )}

          {current === "review" && (
            <section aria-label="Para revisar" className="space-y-2">
              {toReview.length === 0 ?
                <p className="text-sm text-white/70">Nada aguardando a sua revisão.</p> :
                toReview.map((item) => row(item, "review"))}
            </section>
          )}
          {current === "mine" && (
            <section aria-label="Meus envios" className="space-y-2">
              {mine.length === 0 ?
                <p className="text-sm text-white/70">Você ainda não enviou nada.</p> :
                mine.map((item) => row(item, "mine"))}
            </section>
          )}
          {current === "returned" && (
            <section aria-label="Devolvidos aguardando o autor" className="space-y-2">
              <p className="text-sm text-white/70">
                Se o autor não for reenviar, abra o item e peça a exclusão.
              </p>
              {returned.map((item) => row(item, "returned"))}
            </section>
          )}
          {current === "delete" && (
            <section aria-label="Pedidos de exclusão" className="space-y-2">
              {deleteRequests.length === 0 ?
                <p className="text-sm text-white/70">Nenhum pedido de exclusão.</p> :
                deleteRequests.map((item) => row(item, "delete"))}
            </section>
          )}
        </>
      )}
    </div>
  );
}
