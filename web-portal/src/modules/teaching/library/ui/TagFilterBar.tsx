"use client";

import {Icon} from "@/core/ui/icons";
import {TAGS_LOAD_HINT, type ItemTags, type Tag} from "../tags";
import {TagMenus} from "./TagMenus";

// Filtros da biblioteca: busca e seletor de tags com seleção múltipla.
export function TagFilterBar({
  tags,
  value,
  onChange,
  text,
  onTextChange,
  loadError,
}: {
  loadError?: string | null;
  tags: Tag[];
  value: ItemTags;
  onChange: (next: ItemTags) => void;
  text: string;
  onTextChange: (text: string) => void;
}) {
  return (
    <div className="space-y-3">
      {loadError && <p role="alert" className="text-sm text-error">{`${loadError} ${TAGS_LOAD_HINT}`}</p>}
      <div className="flex items-center gap-3 rounded-full bg-surface-elevated px-5 py-3">
        <Icon name="search" className="h-5 w-5 text-white/60" />
        <input
          type="search"
          aria-label="Buscar na biblioteca"
          placeholder="Buscar por nome na biblioteca…"
          value={text}
          onChange={(e) => onTextChange(e.target.value)}
          className="w-full bg-transparent outline-none placeholder:text-white/50"
        />
      </div>
      <TagMenus
        tags={tags}
        value={value}
        onChange={onChange}
        trailing={
          <button
            type="button"
            onClick={() => onChange({typeTags: [], subjectTags: [], ageTags: []})}
            className="rounded-full px-3 py-1.5 text-sm text-white/70 hover:bg-white/10"
          >
            Limpar filtros
          </button>
        }
      />
    </div>
  );
}
