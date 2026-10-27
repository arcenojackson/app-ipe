"use client";

import type {Tag} from "../tags";
import type {LibraryItem} from "../types";
import {FileTypeIcon} from "./FileTypeIcon";
import {TagChips} from "./TagChips";

const isWebUrl = (url: string | undefined): url is string => !!url && /^https?:\/\//.test(url);

// Grade de cartões com selo grande do tipo: título, tags (por extenso) e autor;
// data e aprovadores ficam na janela do item. Arquivos abrem a visualização
// completa; links abrem em nova aba.
export function LibraryGrid({
  items,
  authorNames,
  byTagId,
  onOpenFile,
}: {
  items: LibraryItem[];
  authorNames: Record<string, string>;
  byTagId: Map<string, Tag>;
  onOpenFile: (id: string) => void;
}) {
  return (
    <ul className="grid grid-cols-[repeat(auto-fill,minmax(200px,1fr))] gap-4">
      {items.map((item) => {
        const body = (
          <>
            <span className="grid h-32 w-full place-items-center bg-surface-elevated">
              <FileTypeIcon item={item} large />
            </span>
            <span className="block space-y-1 p-3 text-left">
              <span className="line-clamp-2 block font-medium">{item.name}</span>
              <TagChips
                ids={[...(item.typeTags ?? []), ...(item.subjectTags ?? []), ...(item.ageTags ?? [])]}
                byId={byTagId}
              />
              <span className="block text-xs text-white/60">{authorNames[item.authorId] ?? "—"}</span>
            </span>
          </>
        );
        const cls =
          "block h-full w-full overflow-hidden rounded-card border border-transparent bg-surface transition hover:-translate-y-0.5 hover:border-secondary";
        return (
          <li key={item.id} className="h-full">
            {item.type === "link" ? (
              isWebUrl(item.url) ? (
                <a href={item.url} target="_blank" rel="noopener noreferrer" className={cls}>{body}</a>
              ) : (
                <div className={cls}>{body}</div>
              )
            ) : (
              <button type="button" onClick={() => onOpenFile(item.id)} className={cls}>{body}</button>
            )}
          </li>
        );
      })}
    </ul>
  );
}
