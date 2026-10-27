"use client";

import {useEffect, useRef, useState, type ReactNode} from "react";
import {TAG_KIND_STYLE} from "../../library/tagKindStyle";

const SEARCHABLE_FROM = 8;
const SUBJECT = TAG_KIND_STYLE.subject;

export interface Subject {
  id: string;
  name: string;
}

export function Avatar({name, small = false}: {name: string; small?: boolean}) {
  const initials = name.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]?.toUpperCase()).join("");
  return (
    <span
      aria-hidden
      className={`grid shrink-0 place-items-center rounded-full bg-surface-elevated font-bold ${
        small ? "h-7 w-7 text-[11px]" : "h-9 w-9 text-[13px]"
      }`}
    >
      {initials || "?"}
    </span>
  );
}

// Selo pequeno (assunto, fixado, trancado).
export function Pill({children, tone = "plain"}: {children: ReactNode; tone?: "plain" | "pinned" | "subject"}) {
  const tones = {
    plain: "bg-white/10",
    pinned: "bg-secondary/30 text-[#d6ecaa]",
    subject: `border ${SUBJECT.chip}`,
  };
  return <span className={`whitespace-nowrap rounded-full px-2.5 py-0.5 text-[11px] ${tones[tone]}`}>{children}</span>;
}

// Menu de assuntos: um chip que abre uma lista com busca (a partir de 8
// opções). `max` > 1 permite várias caixas; com max 1 a escolha é única e o
// menu fecha. Os escolhidos aparecem como chips removíveis ao lado.
export function SubjectMenu({
  subjects,
  value,
  onChange,
  max = 1,
  label = "Assunto",
}: {
  subjects: Subject[];
  value: string[];
  onChange: (ids: string[]) => void;
  max?: number;
  label?: string;
}) {
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const box = useRef<HTMLDivElement>(null);
  const single = max === 1;

  useEffect(() => {
    if (!open) return;
    const onPointer = (event: MouseEvent) => {
      if (!box.current?.contains(event.target as Node)) setOpen(false);
    };
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };
    document.addEventListener("mousedown", onPointer);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onPointer);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  const nameOf = (id: string) => subjects.find((s) => s.id === id)?.name ?? id;
  const shown = subjects.filter((s) => s.name.toLowerCase().includes(query.trim().toLowerCase()));
  const full = value.length >= max;

  function pick(id: string) {
    if (single) {
      onChange(value[0] === id ? [] : [id]);
      setOpen(false);
      return;
    }
    if (value.includes(id)) onChange(value.filter((v) => v !== id));
    else if (!full) onChange([...value, id]);
  }

  return (
    <div className="flex flex-wrap items-center gap-2">
      <div ref={box} className="relative">
        <button
          type="button"
          aria-expanded={open}
          onClick={() => {
            setQuery("");
            setOpen(!open);
          }}
          className={`flex items-center gap-2 rounded-full border px-4 py-1.5 text-sm hover:brightness-125 ${
            value.length > 0 && single ? SUBJECT.solid : "border-white/10"
          }`}
        >
          {label}{!single && value.length > 0 ? ` · ${value.length}` : ""} ▾
        </button>
        {open && (
          <div className="absolute z-10 mt-2 w-64 rounded-card bg-surface-elevated p-3 shadow-xl ring-1 ring-white/10">
            {subjects.length >= SEARCHABLE_FROM && (
              <input
                type="search"
                aria-label="Filtrar assuntos"
                placeholder="Filtrar…"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                className="mb-2 w-full rounded-full bg-background/60 px-4 py-1.5 text-sm outline-none"
              />
            )}
            <div className="max-h-64 overflow-y-auto">
              {shown.map((s) =>
                single ? (
                  <button
                    key={s.id}
                    type="button"
                    onClick={() => pick(s.id)}
                    className={`block w-full rounded-lg px-2 py-1.5 text-left text-sm hover:bg-white/5 ${
                      value[0] === s.id ? "bg-white/10 font-semibold" : ""
                    }`}
                  >
                    {s.name}
                  </button>
                ) : (
                  <label key={s.id} className={`flex items-center gap-2 rounded-lg px-2 py-1.5 text-sm hover:bg-white/5 ${
                    !value.includes(s.id) && full ? "cursor-not-allowed opacity-50" : "cursor-pointer"
                  }`}>
                    <input
                      type="checkbox"
                      checked={value.includes(s.id)}
                      disabled={!value.includes(s.id) && full}
                      onChange={() => pick(s.id)}
                      className="accent-secondary"
                    />
                    {s.name}
                  </label>
                )
              )}
              {shown.length === 0 && <p className="px-2 py-1.5 text-sm text-white/60">Nenhum assunto encontrado.</p>}
            </div>
          </div>
        )}
      </div>
      {value.map((id) => (
        <button
          key={id}
          type="button"
          aria-label={`Remover ${nameOf(id)}`}
          onClick={() => onChange(value.filter((v) => v !== id))}
          className={`rounded-full border px-3 py-1 text-sm hover:brightness-125 ${SUBJECT.chip}`}
        >
          {nameOf(id)} ✕
        </button>
      ))}
    </div>
  );
}
