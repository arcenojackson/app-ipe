"use client";

import {useState} from "react";
import {Button} from "@/core/ui/Button";
import {REQUIRED_APPROVALS, validateName} from "../files";
import {formatDateTime, voteLabel} from "../labels";
import {cancelDelete, castVote, editTags, renameItem, requestDelete, resubmitFile, resubmitLink} from "../mutations";
import {itemPermissions} from "../permissions";
import {countApprovals, countDeleteApprovals, statusBadge} from "../status";
import type {Viewer, VoteAction} from "../types";
import {UploadError} from "../uploadFlow";
import {useItemDetail} from "../useItemDetail";
import {useTags} from "../useTags";
import {LinkDialog, ReasonDialog, TagEditDialog, TextPromptDialog} from "./Dialogs";
import {FileInfo} from "./FileInfo";
import {PreviewPane} from "./PreviewPane";
import {ResubmitCard} from "./ResubmitCard";
import {StatusBadge} from "./StatusBadge";
import {TagChips} from "./TagChips";

type Modal =
  | "return" | "reject" | "refuse" | "delete" | "rename" | "tags" | "resubmit-link" | null;

const isWebUrl = (url: string) => /^https?:\/\/.+/.test(url);

export function ItemDetail({
  itemId, viewer, onClose, onChanged,
}: {
  itemId: string;
  viewer: Viewer;
  onClose: () => void;
  onChanged: () => void;
}) {
  const {item, error, votes, votesLoaded, votesError, names, authorName} = useItemDetail(itemId, viewer);
  const {byId: tagById} = useTags();
  const [modal, setModal] = useState<Modal>(null);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [progress, setProgress] = useState<number | null>(null);

  if (item === undefined && !error) return <p className="text-white/70">Carregando…</p>;
  if (!item) {
    return (
      <div className="space-y-3 rounded-card bg-surface-elevated p-6">
        <p>{error ?? "Item não encontrado ou excluído."}</p>
        <Button type="button" variant="text" onClick={() => onClose()}>Fechar</Button>
      </div>
    );
  }

  const permissions = itemPermissions(item, viewer);
  const approvals = countApprovals(item, votes);
  const deleteApprovals = countDeleteApprovals(item, votes);
  const request = item.deleteRequest ?? null;
  const myVote = viewer.isCurator ?
    [...votes]
      .filter((v) => v.voterId === viewer.uid && v.version === item.version &&
        (v.action === "approve" || v.action === "reject" || v.action === "return"))
      .sort((a, b) => a.createdAt - b.createdAt || a.id.localeCompare(b.id))
      .pop() :
    undefined;

  // Mostra o resultado na página e repassa a falha (os diálogos exibem o erro e
  // permanecem abertos; os botões a ignoram).
  async function act(success: string, failureMessage: string | ((cause: unknown) => string), action: () => Promise<void>) {
    setBusy(true);
    setNotice(null);
    setFailure(null);
    try {
      await action();
      setNotice(success);
      onChanged();
    } catch (cause) {
      setFailure(typeof failureMessage === "function" ? failureMessage(cause) : failureMessage);
      throw cause;
    } finally {
      setBusy(false);
    }
  }
  // Tipo, tamanho ou nome inválidos não se resolvem tentando de novo: mostra o motivo.
  const reason = (cause: unknown) =>
    cause instanceof UploadError ? cause.message : "Não foi possível reenviar o arquivo. Tente novamente.";
  const resubmitCard = permissions.canResubmit && item.type === "file";
  // O autor nunca vê o arquivo do próprio item em revisão/devolvido (mesmo sendo curador).
  const hideFile = item.authorId === viewer.uid && item.status !== "published";
  const quiet = (promise: Promise<void>) => void promise.catch(() => undefined);

  const vote = (action: VoteAction, comment?: string) =>
    act("Voto registrado.", "Não foi possível registrar o voto. Tente novamente.", () => castVote(viewer.uid, item, action, comment));

  return (
    <article className="space-y-4 rounded-card bg-surface-elevated p-5">
      <header className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <h2 className="text-xl font-semibold">{item.name}</h2>
          <StatusBadge badge={statusBadge(item, votesLoaded ? approvals : null)} />
        </div>
        <Button type="button" variant="text" onClick={() => onClose()}>Fechar</Button>
      </header>

      <div className="space-y-1">
        {authorName && <p className="text-sm text-white/70">Enviado por {authorName}</p>}
        <TagChips
          ids={[...(item.typeTags ?? []), ...(item.subjectTags ?? []), ...(item.ageTags ?? [])]}
          byId={tagById}
        />
      </div>

      {item.deleting && <p className="text-error">Este item está sendo excluído.</p>}
      {request && !item.deleting && (
        <p className="rounded-card bg-error/10 p-3 text-sm">
          Pedido de exclusão aberto{request.reason ? `: ${request.reason}` : ""}.{votesLoaded && ` Aprovações: ${deleteApprovals}/${REQUIRED_APPROVALS}`}
        </p>
      )}
      {item.status === "returned" && item.returnComment && !resubmitCard && (
        <p className="rounded-card bg-white/10 p-3 text-sm">Devolvido pelos curadores: {item.returnComment}</p>
      )}
      {item.status === "in_review" && !request && votesLoaded && (
        <p className="text-sm text-white/70">Aprovações: {approvals}/{REQUIRED_APPROVALS}</p>
      )}
      {myVote && <p className="text-sm text-white/70">Seu voto: {voteLabel(myVote.action)}</p>}
      {votesError && <p className="text-sm text-error">Não foi possível carregar o histórico de revisão.</p>}

      {item.type === "file" && (hideFile ? <FileInfo item={item} download={false} /> : <PreviewPane item={item} />)}
      {item.type === "link" && item.url && (
        <section aria-label="Link" className="space-y-1">
          {isWebUrl(item.url) ? (
            <a href={item.url} target="_blank" rel="noopener noreferrer" className="break-all text-secondary underline">{item.url}</a>
          ) : (
            <span className="break-all">{item.url}</span>
          )}
          {item.description && <p className="text-sm text-white/70">{item.description}</p>}
        </section>
      )}

      {notice && <p role="status" className="text-sm text-secondary">{notice}</p>}
      {failure && <p role="alert" className="text-sm text-error">{failure}</p>}
      {progress !== null && !resubmitCard && <progress className="w-full" value={progress} max={1} />}

      {resubmitCard && (
        <ResubmitCard
          returnComment={item.returnComment ?? undefined}
          busy={busy}
          progress={progress}
          onResubmit={(file) =>
            act("Arquivo reenviado para revisão.", reason, async () => {
              try {
                await resubmitFile(viewer.uid, item, file, setProgress);
              } finally {
                setProgress(null);
              }
            })}
        />
      )}

      <div className="flex flex-wrap gap-2">
        {permissions.canVote && (
          <>
            <Button type="button" disabled={busy} onClick={() => quiet(vote("approve"))}>Aprovar</Button>
            <Button type="button" variant="text" disabled={busy} onClick={() => setModal("return")}>Devolver</Button>
            <Button type="button" variant="text" disabled={busy} onClick={() => setModal("reject")}>Rejeitar</Button>
          </>
        )}
        {permissions.canVoteDelete && (
          <>
            <Button type="button" disabled={busy} onClick={() => quiet(vote("delete_approve"))}>Aprovar exclusão</Button>
            <Button type="button" variant="text" disabled={busy} onClick={() => setModal("refuse")}>Recusar exclusão</Button>
          </>
        )}
        {permissions.canCancelDelete && (
          <Button type="button" variant="text" disabled={busy}
            onClick={() => quiet(act("Pedido cancelado.", "Não foi possível cancelar o pedido.", () => cancelDelete(viewer.uid, item.id)))}>
            Cancelar pedido de exclusão
          </Button>
        )}
        {permissions.canRename && <Button type="button" variant="text" disabled={busy} onClick={() => setModal("rename")}>Renomear</Button>}
        {permissions.canEditTags && <Button type="button" variant="text" disabled={busy} onClick={() => setModal("tags")}>Editar tags</Button>}
        {permissions.canRequestDelete && <Button type="button" variant="text" disabled={busy} onClick={() => setModal("delete")}>Pedir exclusão</Button>}
        {permissions.canResubmit && item.type === "link" && (
          <Button type="button" disabled={busy} onClick={() => setModal("resubmit-link")}>Reenviar link</Button>
        )}
      </div>

      {votes.length > 0 && (
        <section aria-label="Histórico de revisão" className="space-y-1">
          <h3 className="text-sm font-semibold">Histórico de revisão</h3>
          <ul className="space-y-1 text-sm">
            {[...votes].sort((a, b) => a.createdAt - b.createdAt).map((v) => (
              <li key={v.id} className="rounded-card bg-white/5 p-2">
                <span>{names[v.voterId] ?? "Curador"} — {voteLabel(v.action)}</span>
                <span className="text-white/50"> · {formatDateTime(v.createdAt)}</span>
                {v.comment && <p className="mt-1 text-white/80">{v.comment}</p>}
              </li>
            ))}
          </ul>
        </section>
      )}

      {modal === "return" && (
        <ReasonDialog title="Devolver para o autor" label="Comentário para o autor" required submitLabel="Devolver para o autor"
          onSubmit={(text) => vote("return", text.trim())} onClose={() => setModal(null)} />
      )}
      {modal === "reject" && (
        <ReasonDialog title="Rejeitar envio" label="Motivo da rejeição" required submitLabel="Rejeitar envio"
          onSubmit={(text) => vote("reject", text.trim())} onClose={() => setModal(null)} />
      )}
      {modal === "refuse" && (
        <ReasonDialog title="Recusar exclusão" label="Motivo da recusa" required submitLabel="Recusar pedido"
          onSubmit={(text) => vote("delete_refuse", text.trim())} onClose={() => setModal(null)} />
      )}
      {modal === "delete" && (
        <ReasonDialog title="Pedir exclusão" label="Motivo (opcional)" submitLabel="Enviar pedido"
          onSubmit={(text) => act("Pedido de exclusão enviado.", "Não foi possível enviar o pedido.", () => requestDelete(viewer.uid, item.id, text.trim() || undefined))}
          onClose={() => setModal(null)} />
      )}
      {modal === "rename" && (
        <TextPromptDialog title="Renomear" label="Novo nome" initial={item.name} submitLabel="Salvar" validate={validateName}
          onSubmit={async (name) => { await renameItem(viewer.uid, item.id, name.trim()); onChanged(); }}
          onClose={() => setModal(null)} />
      )}
      {modal === "tags" && (
        <TagEditDialog
          initial={{typeTags: item.typeTags ?? [], subjectTags: item.subjectTags ?? [], ageTags: item.ageTags ?? []}}
          onSubmit={async (tags) => { await editTags(viewer.uid, item.id, tags); onChanged(); }}
          onClose={() => setModal(null)} />
      )}
      {modal === "resubmit-link" && (
        <LinkDialog title="Reenviar link" submitLabel="Reenviar"
          initial={{name: item.name, url: item.url ?? "", description: item.description ?? ""}}
          onSubmit={async (value) => {
            await resubmitLink(viewer.uid, item, {url: value.url.trim(), name: value.name.trim(), description: value.description});
            onChanged();
          }}
          onClose={() => setModal(null)} />
      )}
    </article>
  );
}
