"use client";

import {useState} from "react";
import {Button} from "@/core/ui/Button";
import {TextField} from "@/core/ui/TextField";
import {loadPlanLessons, loadPublishedDocs} from "../repository";
import {LIMITS, type Ref} from "../types";

type Tab = "library" | "plan";

const same = (a: Ref, b: Ref) => a.kind === b.kind && a.id === b.id;
const LOAD_ERROR = "Não foi possível carregar as opções.";

// Seletor de citações: documentos PUBLICADOS da Biblioteca (com busca) e
// aulas do Plano pedagógico.
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

  return (
    <div className="space-y-2">
      {value.length > 0 && (
        <ul className="flex flex-wrap gap-2">
          {value.map((ref) => (
            <li key={`${ref.kind}-${ref.id}`} className="flex items-center gap-2 rounded-input bg-surface/60 px-3 py-1 text-sm">
              <span>{ref.label}</span>
              <button
                type="button"
                aria-label={`Remover citação ${ref.label}`}
                onClick={() => onChange(value.filter((r) => !same(r, ref)))}
              >
                ×
              </button>
            </li>
          ))}
        </ul>
      )}
      {!open && (
        <Button
          type="button"
          variant="text"
          disabled={full}
          onClick={() => {
            setOpen(true);
            void load(tab, search);
          }}
        >
          Citar documento ou aula
        </Button>
      )}
      {open && (
        <div className="space-y-2 rounded-card bg-surface/40 p-3">
          <div className="flex gap-2">
            <Button type="button" variant="text" aria-pressed={tab === "library"} onClick={() => choose("library")}>
              Documento da Biblioteca
            </Button>
            <Button type="button" variant="text" aria-pressed={tab === "plan"} onClick={() => choose("plan")}>
              Aula do Plano
            </Button>
            <Button type="button" variant="text" onClick={() => setOpen(false)}>
              Fechar
            </Button>
          </div>
          {tab === "library" && (
            <div className="flex items-end gap-2">
              <div className="flex-1">
                <TextField
                  id="ref-search"
                  label="Buscar documento publicado"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                />
              </div>
              <Button type="button" onClick={() => void load("library", search)}>Buscar</Button>
            </div>
          )}
          {error && <p role="alert" className="text-sm text-error">{error}</p>}
          {!error && options.length === 0 && <p className="text-sm text-white/60">Nenhum resultado.</p>}
          <ul className="max-h-56 space-y-1 overflow-y-auto">
            {options.map((ref) => {
              const added = value.some((r) => same(r, ref));
              return (
                <li key={`${ref.kind}-${ref.id}`}>
                  <button
                    type="button"
                    disabled={added || full}
                    onClick={() => onChange([...value, ref])}
                    className="w-full rounded-input px-3 py-2 text-left text-sm hover:bg-white/10 disabled:opacity-50"
                  >
                    {ref.label}
                  </button>
                </li>
              );
            })}
          </ul>
        </div>
      )}
    </div>
  );
}
