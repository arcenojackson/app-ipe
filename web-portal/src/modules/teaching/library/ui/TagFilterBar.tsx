"use client";

import {useState} from "react";
import {TextField} from "@/core/ui/TextField";
import {TAG_FIELD, TAG_KINDS, TAG_KIND_LABEL, tagName, type ItemTags, type Tag, type TagKind} from "../tags";

// Filtros da biblioteca: menus de Tipo/Assunto/Faixa, chips dos filtros ativos
// e busca por texto.
export function TagFilterBar({
  tags,
  value,
  onChange,
  text,
  onTextChange,
}: {
  tags: Tag[];
  value: ItemTags;
  onChange: (next: ItemTags) => void;
  text: string;
  onTextChange: (text: string) => void;
}) {
  const [open, setOpen] = useState<TagKind | null>(null);
  const byId = new Map(tags.map((t) => [t.id, t]));

  const toggle = (field: keyof ItemTags, id: string) => {
    const current = value[field];
    onChange({...value, [field]: current.includes(id) ? current.filter((x) => x !== id) : [...current, id]});
  };

  const selected = TAG_KINDS.flatMap((kind) =>
    value[TAG_FIELD[kind]].map((id) => ({kind, id}))
  );

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-end gap-3">
        {TAG_KINDS.map((kind) => (
          <div key={kind} className="relative">
            <button
              type="button"
              aria-expanded={open === kind}
              onClick={() => setOpen(open === kind ? null : kind)}
              className="rounded-button border border-white/20 px-4 py-2 text-sm hover:bg-white/10"
            >
              {TAG_KIND_LABEL[kind]} ▾
            </button>
            {open === kind && (
              <div className="absolute z-10 mt-1 max-h-72 min-w-56 overflow-y-auto rounded-card bg-surface-elevated p-3 shadow-lg">
                {tags
                  .filter((t) => t.kind === kind && t.active)
                  .map((t) => (
                    <label key={t.id} className="flex items-center gap-2 py-1 text-sm">
                      <input
                        type="checkbox"
                        checked={value[TAG_FIELD[kind]].includes(t.id)}
                        onChange={() => toggle(TAG_FIELD[kind], t.id)}
                      />
                      {t.name}
                    </label>
                  ))}
              </div>
            )}
          </div>
        ))}
        <div className="min-w-[14rem] flex-1">
          <TextField id="library-search" label="Buscar na biblioteca" value={text} onChange={(e) => onTextChange(e.target.value)} />
        </div>
      </div>
      {selected.length > 0 && (
        <ul className="flex flex-wrap gap-2">
          {selected.map(({kind, id}) => (
            <li key={`${kind}-${id}`}>
              <button
                type="button"
                aria-label={`Remover ${tagName(byId, id)}`}
                onClick={() => toggle(TAG_FIELD[kind], id)}
                className="rounded-full bg-white/10 px-3 py-1 text-xs hover:bg-white/20"
              >
                {tagName(byId, id)} ✕
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
