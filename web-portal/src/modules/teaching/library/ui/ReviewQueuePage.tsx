"use client";

import {useRouter} from "next/navigation";
import {useMemo, useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {Button} from "@/core/ui/Button";
import {REQUIRED_APPROVALS} from "../files";
import {createLink} from "../mutations";
import {iVoted} from "../reviewQueue";
import {countApprovals, countDeleteApprovals, statusBadge} from "../status";
import type {LibraryItem, LibraryVote} from "../types";
import {viewerFrom} from "../types";
import {libraryUrl} from "../url";
import {useReviewQueue} from "../useReviewQueue";
import {useTags} from "../useTags";
import {CuratorWarning} from "./CuratorWarning";
import {LinkDialog} from "./Dialogs";
import {QueueRow} from "./QueueRow";
import {UploadPanel} from "./UploadPanel";

export default function ReviewQueuePage() {
  const {state} = useAuth();
  const router = useRouter();
  const viewer = useMemo(
    () => (state.status === "signedIn" ? viewerFrom(state.user.uid, state.claims) : null),
    [state]
  );
  const {queue, votes, error} = useReviewQueue(viewer);
  const {byId: tagById} = useTags();
  const [showVoted, setShowVoted] = useState(false);
  const [linkOpen, setLinkOpen] = useState(false);

  if (!viewer) return null;
  const privileged = viewer.isCurator || viewer.isAdmin;
  const open = (item: LibraryItem) => router.push(libraryUrl({item: item.id}));
  const votesOf = (item: LibraryItem): LibraryVote[] => votes[item.id] ?? [];
  const pending = (item: LibraryItem) => showVoted || !iVoted(item, votesOf(item), viewer.uid);

  const row = (item: LibraryItem, kind: "mine" | "review" | "delete") => {
    const itemVotes = votesOf(item);
    const deletion = kind === "delete";
    const approvals = deletion ? countDeleteApprovals(item, itemVotes) : countApprovals(item, itemVotes);
    const reason = item.deleteRequest?.reason;
    const note =
      kind === "mine" && item.status === "returned" && item.returnComment ?
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

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Fila de revisão</h1>
      {privileged && <CuratorWarning />}

      <section aria-label="Enviar material" className="space-y-3">
        <h2 className="font-semibold">Enviar material</h2>
        <UploadPanel uid={viewer.uid} onUploaded={() => undefined} />
        <Button type="button" variant="text" onClick={() => setLinkOpen(true)}>Adicionar link</Button>
      </section>
      {linkOpen && (
        <LinkDialog
          withTags
          submitLabel="Adicionar"
          onSubmit={async (value) => {
            if (!value.tags) return;
            await createLink(viewer.uid, {...value, tags: value.tags});
          }}
          onClose={() => setLinkOpen(false)}
        />
      )}

      {error && <p role="alert" className="text-sm text-error">{error}</p>}
      {!queue && !error && <p className="text-white/70">Carregando…</p>}

      {queue && (
        <>
          <section aria-label="Meus envios" className="space-y-2">
            <h2 className="font-semibold">Meus envios</h2>
            {queue.mine.length === 0 ?
              <p className="text-sm text-white/70">Você ainda não enviou nada.</p> :
              queue.mine.map((item) => row(item, "mine"))}
          </section>

          {privileged && (
            <>
              <label className="flex items-center gap-2 text-sm text-white/70">
                <input type="checkbox" checked={showVoted} onChange={(e) => setShowVoted(e.target.checked)}
                  aria-label="Mostrar também o que já votei" />
                Mostrar também o que já votei
              </label>
              <section aria-label="Para revisar" className="space-y-2">
                <h2 className="font-semibold">Para revisar</h2>
                {toReview.length === 0 ?
                  <p className="text-sm text-white/70">Nada aguardando a sua revisão.</p> :
                  toReview.map((item) => row(item, "review"))}
              </section>
              <section aria-label="Pedidos de exclusão" className="space-y-2">
                <h2 className="font-semibold">Pedidos de exclusão</h2>
                {deleteRequests.length === 0 ?
                  <p className="text-sm text-white/70">Nenhum pedido de exclusão.</p> :
                  deleteRequests.map((item) => row(item, "delete"))}
              </section>
            </>
          )}
        </>
      )}
    </div>
  );
}
