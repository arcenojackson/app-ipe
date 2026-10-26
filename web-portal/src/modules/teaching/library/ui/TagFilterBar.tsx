"use client";

import {useEffect, useRef, useState} from "react";
import {Icon} from "@/core/ui/icons";
import {TAG_KIND_STYLE} from "../tagKindStyle";
import {TAGS_LOAD_HINT, TAG_FIELD, TAG_KINDS, TAG_KIND_LABEL, tagName, type ItemTags, type Tag, type TagKind} from "../tags";

const SEARCHABLE_FROM = 8;

// Filtros da biblioteca: busca, um chip por tipo de tag (Tipo/Assunto/Faixa)
// com seleção múltipla e chips dos filtros ativos.
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
  const [open, setOpen] = useState<TagKind | null>(null);
  const [query, setQuery] = useState("");
  const byId = new Map(tags.map((t) => [t.id, t]));
  const menus = useRef<HTMLDivElement>(null);

  // Fecha o menu aberto ao clicar fora dele ou ao apertar Esc.
  useEffect(() => {
    if (!open) return;
    const onPointer = (event: MouseEvent) => {
      if (!menus.current?.contains(event.target as Node)) setOpen(null);
    };
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(null);
    };
    document.addEventListener("mousedown", onPointer);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onPointer);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  const toggle = (field: keyof ItemTags, id: string) => {
    const current = value[field];
    onChange({...value, [field]: current.includes(id) ? current.filter((x) => x !== id) : [...current, id]});
  };

  const selected = TAG_KINDS.flatMap((kind) =>
    value[TAG_FIELD[kind]].map((id) => ({kind, id}))
  );

  const toggleMenu = (kind: TagKind) => {
    setQuery("");
    setOpen(open === kind ? null : kind);
  };

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
      <div ref={menus} className="flex flex-wrap items-center gap-2">
        {TAG_KINDS.map((kind) => {
          const count = value[TAG_FIELD[kind]].length;
          const options = tags.filter((t) => t.kind === kind && t.active);
          const shown = options.filter((t) => t.name.toLowerCase().includes(query.trim().toLowerCase()));
          return (
            <div key={kind} className="relative">
              <button
                type="button"
                aria-expanded={open === kind}
                onClick={() => toggleMenu(kind)}
                className={`flex items-center gap-2 rounded-full border px-4 py-1.5 text-sm hover:brightness-125 ${
                  count > 0 ? TAG_KIND_STYLE[kind].solid : `${TAG_KIND_STYLE[kind].chip} text-white/90`
                }`}
              >
                {TAG_KIND_LABEL[kind]}
                {count > 0 ? ` · ${count}` : ""} ▾
              </button>
              {open === kind && (
                <div className="absolute z-10 mt-2 w-64 rounded-card bg-surface-elevated p-3 shadow-xl ring-1 ring-white/10">
                  {options.length >= SEARCHABLE_FROM && (
                    <input
                      type="search"
                      aria-label={`Filtrar ${TAG_KIND_LABEL[kind].toLowerCase()}`}
                      placeholder="Filtrar…"
                      value={query}
                      onChange={(e) => setQuery(e.target.value)}
                      className="mb-2 w-full rounded-full bg-background/60 px-4 py-1.5 text-sm outline-none"
                    />
                  )}
                  <div className="max-h-64 overflow-y-auto">
                    {shown.map((t) => (
                      <label key={t.id} className="flex cursor-pointer items-center gap-2 rounded-lg px-2 py-1.5 text-sm hover:bg-white/5">
                        <input
                          type="checkbox"
                          checked={value[TAG_FIELD[kind]].includes(t.id)}
                          onChange={() => toggle(TAG_FIELD[kind], t.id)}
                          className="accent-secondary"
                        />
                        {t.name}
                      </label>
                    ))}
                    {shown.length === 0 && <p className="px-2 py-1.5 text-sm text-white/60">Nenhuma tag encontrada.</p>}
                  </div>
                </div>
              )}
            </div>
          );
        })}
        {selected.length > 0 && (
          <button
            type="button"
            onClick={() => onChange({typeTags: [], subjectTags: [], ageTags: []})}
            className="ml-auto rounded-full px-3 py-1.5 text-sm text-white/70 hover:bg-white/10"
          >
            Limpar filtros
          </button>
        )}
      </div>
      {selected.length > 0 && (
        <div className="flex flex-wrap items-center gap-x-5 gap-y-2">
          {TAG_KINDS.filter((kind) => value[TAG_FIELD[kind]].length > 0).map((kind) => (
            <ul key={kind} aria-label={`${TAG_KIND_LABEL[kind]} selecionados`} className="flex flex-wrap items-center gap-2">
              <li aria-hidden className={`h-2.5 w-2.5 rounded-full ${TAG_KIND_STYLE[kind].dot}`} />
              {value[TAG_FIELD[kind]].map((id) => (
                <li key={id}>
                  <button
                    type="button"
                    aria-label={`Remover ${tagName(byId, id)}`}
                    onClick={() => toggle(TAG_FIELD[kind], id)}
                    className={`rounded-full border px-3 py-1 text-sm hover:brightness-125 ${TAG_KIND_STYLE[kind].chip}`}
                  >
                    {tagName(byId, id)} ✕
                  </button>
                </li>
              ))}
            </ul>
          ))}
        </div>
      )}
    </div>
  );
}
