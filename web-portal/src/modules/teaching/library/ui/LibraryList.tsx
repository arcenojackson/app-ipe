"use client";

import {approverLabel, formatBytes, formatDate} from "../labels";
import type {Tag} from "../tags";
import type {LibraryItem} from "../types";
import {FileTypeIcon} from "./FileTypeIcon";
import {TagChips} from "./TagChips";

const isWebUrl = (url: string | undefined): url is string => !!url && /^https?:\/\//.test(url);

// Lista densa estilo Drive: nome, tags, autor, data e tamanho. Arquivos são
// selecionados (painel lateral); links abrem em nova aba.
export function LibraryList({
  items,
  byTagId,
  authorNames,
  selectedId,
  onSelect,
}: {
  items: LibraryItem[];
  byTagId: Map<string, Tag>;
  authorNames: Record<string, string>;
  selectedId?: string | null;
  onSelect: (id: string) => void;
}) {
  return (
    <div className="overflow-hidden rounded-card bg-surface">
      <table className="w-full text-left text-sm">
        <thead className="text-xs uppercase tracking-wide text-white/60">
          <tr>
            <th className="px-4 py-3 font-medium">Nome</th>
            <th className="hidden px-4 py-3 font-medium lg:table-cell">Tags</th>
            <th className="hidden px-4 py-3 font-medium md:table-cell">Enviado por</th>
            <th className="hidden px-4 py-3 font-medium lg:table-cell">Aprovado por</th>
            <th className="hidden px-4 py-3 font-medium md:table-cell">Publicado em</th>
            <th className="hidden px-4 py-3 font-medium md:table-cell">Tamanho</th>
          </tr>
        </thead>
        <tbody>
          {items.map((item) => (
            <tr
              key={item.id}
              // Arquivos: a linha inteira seleciona (o teclado usa o botão do nome, que
              // sobe o clique até aqui). Links continuam abrindo só pela âncora.
              onClick={item.type === "link" ? undefined : () => onSelect(item.id)}
              className={`border-t border-white/10 hover:bg-white/5 focus-within:bg-white/5 ${
                item.type === "link" ? "" : "cursor-pointer"
              } ${item.id === selectedId ? "bg-white/5 shadow-[inset_3px_0_var(--ipe-secondary)]" : ""}`}
            >
              <td className="px-4 py-2.5">{nameCell(item, authorNames)}</td>
              <td className="hidden px-4 py-2.5 lg:table-cell">
                <TagChips
                  ids={[...(item.typeTags ?? []), ...(item.subjectTags ?? []), ...(item.ageTags ?? [])]}
                  byId={byTagId}
                />
              </td>
              <td className="hidden px-4 py-2.5 text-white/70 md:table-cell">{authorNames[item.authorId] ?? "—"}</td>
              <td className="hidden max-w-[12rem] truncate px-4 py-2.5 text-white/70 lg:table-cell" title={approverLabel(item.approvedBy, authorNames).title}>
                {approverLabel(item.approvedBy, authorNames).text}
              </td>
              <td className="hidden px-4 py-2.5 text-white/70 md:table-cell">{formatDate(item.publishedAt)}</td>
              <td className="hidden px-4 py-2.5 text-white/70 md:table-cell">
                {item.type === "file" && item.size ? formatBytes(item.size) : "—"}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function nameCell(item: LibraryItem, authorNames: Record<string, string>) {
  const content = (
    <span className="flex items-center gap-3">
      <FileTypeIcon item={item} />
      <span className="min-w-0">
        <span className="block font-medium">{item.name}</span>
        {item.approvedBy && item.approvedBy.length > 0 && (
          <span className="block text-xs text-white/60 lg:hidden" title={approverLabel(item.approvedBy, authorNames).title}>
            Aprovado por {approverLabel(item.approvedBy, authorNames).text}
          </span>
        )}
      </span>
    </span>
  );
  if (item.type === "link") {
    if (!isWebUrl(item.url)) return content;
    return (
      <a href={item.url} target="_blank" rel="noopener noreferrer" className="hover:underline">
        {content}
      </a>
    );
  }
  return (
    <button type="button" className="text-left hover:underline">
      {content}
    </button>
  );
}
