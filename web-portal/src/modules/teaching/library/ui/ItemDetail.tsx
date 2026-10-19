"use client";

import {useState} from "react";
import {Button} from "@/core/ui/Button";
import {REQUIRED_APPROVALS, validateName} from "../files";
import {formatDateTime, voteLabel} from "../labels";
import {cancelDelete, castVote, moveItem, renameItem, requestDelete, resubmitFile, resubmitLink} from "../mutations";
import {itemPermissions} from "../permissions";
import {previewKind} from "../preview";
import {countApprovals, countDeleteApprovals, statusBadge} from "../status";
import type {LibraryItem, Viewer, VoteAction} from "../types";
import {useItemDetail} from "../useItemDetail";
import {LinkDialog, MoveDialog, ReasonDialog, TextPromptDialog} from "./Dialogs";
import {StatusBadge} from "./StatusBadge";

type Modal =
  | "return" | "reject" | "refuse" | "delete" | "rename" | "move" | "resubmit-link" | null;

const isWebUrl = (url: string) => /^https?:\/\/.+/.test(url);

export function ItemDetail({
  itemId, viewer, folders, byId, onClose, onChanged,
}: {
  itemId: string;
  viewer: Viewer;
  folders: LibraryItem[];
  byId: Map<string, LibraryItem>;
  onClose: (parentId: string | null) => void;
  onChanged: () => void;
}) {
  const {item, error, votes, names, fileUrl, fileUrlError} = useItemDetail(itemId, viewer);
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
        <Button type="button" variant="text" onClick={() => onClose(null)}>Fechar</Button>
      </div>
    );
  }

  const permissions = itemPermissions(item, viewer);
  const approvals = countApprovals(item, votes);
  const deleteApprovals = countDeleteApprovals(item, votes);
  const request = item.deleteRequest ?? null;
  const preview = item.type === "file" ? previewKind(item.contentType) : "other";

  // Mostra o resultado na página e repassa a falha (os diálogos exibem o erro e
  // permanecem abertos; os botões a ignoram).
  async function act(success: string, failureMessage: string, action: () => Promise<void>) {
    setBusy(true);
    setNotice(null);
    setFailure(null);
    try {
      await action();
      setNotice(success);
      onChanged();
    } catch (cause) {
      setFailure(failureMessage);
      throw cause;
    } finally {
      setBusy(false);
    }
  }
  const quiet = (promise: Promise<void>) => void promise.catch(() => undefined);

  const vote = (action: VoteAction, comment?: string) =>
    act("Voto registrado.", "Não foi possível registrar o voto. Tente novamente.", () => castVote(viewer.uid, item, action, comment));

  return (
    <article className="space-y-4 rounded-card bg-surface-elevated p-5">
      <header className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <h2 className="text-xl font-semibold">{item.name}</h2>
          <StatusBadge badge={statusBadge(item, approvals)} />
        </div>
        <Button type="button" variant="text" onClick={() => onClose(item.parentId)}>Fechar</Button>
      </header>

      {item.deleting && <p className="text-error">Este item está sendo excluído.</p>}
      {request && !item.deleting && (
        <p className="rounded-card bg-error/10 p-3 text-sm">
          Pedido de exclusão aberto{request.reason ? `: ${request.reason}` : ""}. Aprovações: {deleteApprovals}/{REQUIRED_APPROVALS}
        </p>
      )}
      {item.status === "returned" && item.returnComment && (
        <p className="rounded-card bg-white/10 p-3 text-sm">Devolvido pelos curadores: {item.returnComment}</p>
      )}
      {item.status === "in_review" && !request && <p className="text-sm text-white/70">Aprovações: {approvals}/{REQUIRED_APPROVALS}</p>}

      {item.type === "file" && (
        <section aria-label="Arquivo" className="space-y-2">
          {fileUrlError && <p role="alert" className="text-sm text-error">Não foi possível abrir o arquivo.</p>}
          {fileUrl && preview === "pdf" && <iframe title={`Visualização de ${item.name}`} src={fileUrl} className="h-[60vh] w-full rounded-card bg-white" />}
          {/* eslint-disable-next-line @next/next/no-img-element -- URL assinada do Storage, fora do otimizador do Next */}
          {fileUrl && preview === "image" && <img alt={item.name} src={fileUrl} className="max-h-[60vh] rounded-card" />}
          {fileUrl && preview === "other" && <p className="text-sm text-white/70">Este tipo de arquivo não tem visualização. Baixe para abrir.</p>}
          {fileUrl && <a href={fileUrl} target="_blank" rel="noopener noreferrer" download={item.fileName} className="text-secondary underline">Baixar</a>}
        </section>
      )}
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
      {progress !== null && <progress className="w-full" value={progress} max={1} />}

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
        {permissions.canMove && <Button type="button" variant="text" disabled={busy} onClick={() => setModal("move")}>Mover</Button>}
        {permissions.canRequestDelete && <Button type="button" variant="text" disabled={busy} onClick={() => setModal("delete")}>Pedir exclusão</Button>}
        {permissions.canResubmit && item.type === "link" && (
          <Button type="button" disabled={busy} onClick={() => setModal("resubmit-link")}>Reenviar link</Button>
        )}
      </div>

      {permissions.canResubmit && item.type === "file" && (
        <label className="block text-sm text-white/70">
          Reenviar arquivo corrigido
          <input
            type="file"
            aria-label="Escolher novo arquivo"
            disabled={busy}
            className="mt-1 block"
            onChange={(event) => {
              const chosen = event.target.files?.[0];
              event.target.value = "";
              if (!chosen) return;
              quiet(act("Arquivo reenviado para revisão.", "Não foi possível reenviar o arquivo. Tente novamente.", async () => {
                try {
                  await resubmitFile(viewer.uid, item, chosen, setProgress);
                } finally {
                  setProgress(null);
                }
              }));
            }}
          />
        </label>
      )}

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
      {modal === "move" && (
        <MoveDialog item={item} folders={folders} byId={byId}
          onPick={async (parentId) => { await moveItem(viewer.uid, item.id, parentId); onChanged(); }}
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
