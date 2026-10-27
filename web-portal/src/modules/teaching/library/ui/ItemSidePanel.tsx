"use client";

import {Button} from "@/core/ui/Button";
import {formatBytes, formatDate} from "../labels";
import type {Tag} from "../tags";
import type {LibraryItem} from "../types";
import {FileTypeIcon} from "./FileTypeIcon";
import {TagChips} from "./TagChips";

// Painel lateral da lista: mini resumo do item selecionado. A visualização
// completa e as ações de curadoria ficam na janela do item.
export function ItemSidePanel({
  item,
  byTagId,
  authorName,
  approverNames = [],
  onOpen,
  onClose,
}: {
  item: LibraryItem;
  byTagId: Map<string, Tag>;
  authorName?: string;
  approverNames?: string[];
  onOpen: () => void;
  onClose: () => void;
}) {
  return (
    <aside aria-label="Resumo do item" className="space-y-4 rounded-card bg-surface p-5 lg:sticky lg:top-6">
      <div className="flex items-start justify-between gap-3">
        <h2 className="font-semibold">{item.name}</h2>
        <button type="button" aria-label="Fechar resumo" onClick={onClose} className="rounded-button px-2 text-white/60 hover:bg-white/10">
          ✕
        </button>
      </div>
      <div className="grid h-40 place-items-center rounded-card bg-surface-elevated">
        <FileTypeIcon item={item} large />
      </div>
      <dl className="grid grid-cols-[6rem_1fr] gap-x-3 gap-y-2 text-sm">
        <dt className="text-white/60">Enviado por</dt>
        <dd>{authorName ?? "—"}</dd>
        <dt className="text-white/60">Enviado em</dt>
        <dd>{formatDate(item.createdAt)}</dd>
        <dt className="text-white/60">Publicado</dt>
        <dd>{formatDate(item.publishedAt)}</dd>
        <dt className="text-white/60">Aprovado por</dt>
        <dd>{approverNames.length > 0 ? approverNames.join(", ") : "—"}</dd>
        {item.type === "file" && item.size ? (
          <>
            <dt className="text-white/60">Tamanho</dt>
            <dd>{formatBytes(item.size)}</dd>
          </>
        ) : null}
      </dl>
      <TagChips
        ids={[...(item.typeTags ?? []), ...(item.subjectTags ?? []), ...(item.ageTags ?? [])]}
        byId={byTagId}
      />
      <Button type="button" className="w-full py-3" onClick={onOpen}>
        Visualizar
      </Button>
    </aside>
  );
}
