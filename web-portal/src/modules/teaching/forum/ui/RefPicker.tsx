"use client";

import {useState} from "react";
import {Button} from "@/core/ui/Button";
import {Icon} from "@/core/ui/icons";
import {Dialog} from "../../library/ui/Dialog";
import {loadPlanLessons, loadPublishedDocs} from "../repository";
import {LIMITS, type Ref} from "../types";
import {RefBadge} from "./RefCard";

type Tab = "library" | "plan";

const same = (a: Ref, b: Ref) => a.kind === b.kind && a.id === b.id;
const LOAD_ERROR = "Não foi possível carregar as opções.";

// Seletor de citações: botão que abre um diálogo com duas abas (documentos
// PUBLICADOS da Biblioteca, com busca, e aulas do Plano pedagógico). O item
// escolhido vira um cartão removível no formulário.
export default function RefPicker({
  value,
  onChange,
  max = LIMITS.refs,
}: {
  value: Ref[];
  onChange: (refs: Ref[]) => void;
  max?: number;
}) {
  const [open, setOpen] = useState(false);
  const [tab, setTab] = useState<Tab>("library");
  const [search, setSearch] = useState("");
  const [options, setOptions] = useState<Ref[]>([]);
  const [error, setError] = useState<string | null>(null);

  async function load(next: Tab, text: string) {
    setError(null);
    try {
      setOptions(next === "library" ? await loadPublishedDocs(text) : await loadPlanLessons());
    } catch {
      setOptions([]);
      setError(LOAD_ERROR);
    }
  }

  function choose(next: Tab) {
    setTab(next);
    setOptions([]);
    void load(next, search);
  }

  const full = value.length >= max;
  const tabClass = (active: boolean) =>
    `rounded-full border px-4 py-1.5 text-sm hover:brightness-125 ${
      active ? "border-secondary bg-secondary/40" : "border-white/10"
    }`;

  return (
    <div className="space-y-3">
      <div className="flex flex-wrap items-center gap-3">
        <button
          type="button"
          disabled={full}
          onClick={() => {
            setOpen(true);
            void load(tab, search);
          }}
          className="inline-flex items-center gap-2 rounded-full border border-dashed border-white/20 px-4 py-2 text-sm hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-50"
        >
          <Icon name="paperclip" className="h-4 w-4" />
          Citar documento ou aula
        </button>
        <span className="text-xs text-white/60">{value.length} de {max}</span>
      </div>
      {value.length > 0 && (
        <ul className="space-y-2">
          {value.map((ref) => (
            <li key={`${ref.kind}-${ref.id}`} className="flex max-w-md items-center gap-3 rounded-input bg-surface-elevated px-3 py-2">
              <RefBadge item={ref} />
              <span className="min-w-0 flex-1 truncate text-sm">{ref.label}</span>
              <button
                type="button"
                aria-label={`Remover citação ${ref.label}`}
                onClick={() => onChange(value.filter((r) => !same(r, ref)))}
                className="rounded-full px-2 text-white/60 hover:bg-white/10 hover:text-white"
              >
                ✕
              </button>
            </li>
          ))}
        </ul>
      )}
      {open && (
        <Dialog title="Citar no tópico" onClose={() => setOpen(false)}>
          <div className="space-y-3">
            <div className="flex gap-2">
              <button type="button" aria-pressed={tab === "library"} className={tabClass(tab === "library")} onClick={() => choose("library")}>
                Biblioteca
              </button>
              <button type="button" aria-pressed={tab === "plan"} className={tabClass(tab === "plan")} onClick={() => choose("plan")}>
                Plano pedagógico
              </button>
            </div>
            {tab === "library" && (
              <form
                className="flex items-center gap-2"
                onSubmit={(event) => {
                  event.preventDefault();
                  void load("library", search);
                }}
              >
                <input
                  type="search"
                  aria-label="Buscar documento publicado"
                  placeholder="Buscar documento publicado…"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  className="min-w-0 flex-1 rounded-full bg-surface-elevated px-4 py-2 text-sm outline-none"
                />
                <button type="submit" className="rounded-full bg-secondary px-4 py-2 text-sm font-semibold text-white hover:brightness-125">
                  Buscar
                </button>
              </form>
            )}
            {error && <p role="alert" className="text-sm text-error">{error}</p>}
            {!error && options.length === 0 && <p className="text-sm text-white/60">Nenhum resultado.</p>}
            <ul className="max-h-72 space-y-1 overflow-y-auto">
              {options.map((ref) => {
                const added = value.some((r) => same(r, ref));
                return (
                  <li key={`${ref.kind}-${ref.id}`}>
                    <button
                      type="button"
                      disabled={added || full}
                      aria-label={ref.label}
                      onClick={() => {
                        onChange([...value, ref]);
                        setOpen(false);
                      }}
                      className="flex w-full items-center gap-3 rounded-input px-3 py-2 text-left text-sm hover:bg-white/10 disabled:opacity-50"
                    >
                      <RefBadge item={ref} />
                      <span className="min-w-0 flex-1 truncate">{ref.label}</span>
                      {added && <span className="text-xs text-white/60">já citado</span>}
                    </button>
                  </li>
                );
              })}
            </ul>
            <div className="flex justify-end">
              <Button type="button" variant="text" onClick={() => setOpen(false)}>Fechar</Button>
            </div>
          </div>
        </Dialog>
      )}
    </div>
  );
}
