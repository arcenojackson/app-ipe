"use client";

import {formatBytes, formatDate} from "../labels";
import type {Tag} from "../tags";
import type {LibraryItem} from "../types";
import {TagChips} from "./TagChips";

const isWebUrl = (url: string | undefined): url is string => !!url && /^https?:\/\//.test(url);

// Tabela estilo Drive: nome, tags, autor, data e tamanho. Arquivos abrem a
// janela de visualização; links abrem em nova aba.
export function LibraryTable({
  items,
  byTagId,
  authorNames,
  onOpenFile,
}: {
  items: LibraryItem[];
  byTagId: Map<string, Tag>;
  authorNames: Record<string, string>;
  onOpenFile: (id: string) => void;
}) {
  return (
    <div className="overflow-x-auto rounded-card bg-surface-elevated">
      <table className="w-full text-left text-sm">
        <thead className="text-white/60">
          <tr>
            <th className="px-4 py-3 font-medium">Nome</th>
            <th className="px-4 py-3 font-medium">Tags</th>
            <th className="px-4 py-3 font-medium">Enviado por</th>
            <th className="px-4 py-3 font-medium">Publicado em</th>
            <th className="px-4 py-3 font-medium">Tamanho</th>
          </tr>
        </thead>
        <tbody>
          {items.map((item) => (
            <tr key={item.id} className="border-t border-white/10">
              <td className="px-4 py-3">{nameCell(item, onOpenFile)}</td>
              <td className="px-4 py-3">
                <TagChips
                  ids={[...(item.typeTags ?? []), ...(item.subjectTags ?? []), ...(item.ageTags ?? [])]}
                  byId={byTagId}
                />
              </td>
              <td className="px-4 py-3">{authorNames[item.authorId] ?? "—"}</td>
              <td className="px-4 py-3">{formatDate(item.publishedAt)}</td>
              <td className="px-4 py-3">{item.type === "file" && item.size ? formatBytes(item.size) : "—"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function nameCell(item: LibraryItem, onOpenFile: (id: string) => void) {
  if (item.type === "link") {
    if (!isWebUrl(item.url)) {
      return <span><span aria-hidden>🔗 </span>{item.name}</span>;
    }
    return (
      <a href={item.url} target="_blank" rel="noopener noreferrer" className="font-medium hover:underline">
        <span aria-hidden>🔗 </span>
        {item.name}
      </a>
    );
  }
  return (
    <button type="button" onClick={() => onOpenFile(item.id)} className="text-left font-medium hover:underline">
      <span aria-hidden>📄 </span>
      {item.name}
    </button>
  );
}
