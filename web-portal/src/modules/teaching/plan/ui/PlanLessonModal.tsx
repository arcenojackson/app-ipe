"use client";

import {useEffect, useState} from "react";
import {Button} from "@/core/ui/Button";
import {Dialog} from "../../library/ui/Dialog";
import {loadPlanRow} from "../repository";
import {PLAN_COLUMNS, type PlanRow} from "../types";

type State = {id: string; row: PlanRow | undefined | "error"} | null;

// Aula do Plano pedagógico em janela somente leitura (citações do Fórum).
export default function PlanLessonModal({id, onClose}: {id: string; onClose: () => void}) {
  const [state, setState] = useState<State>(null);

  useEffect(() => {
    let active = true;
    loadPlanRow(id)
      .then((row) => active && setState({id, row}))
      .catch(() => active && setState({id, row: "error"}));
    return () => {
      active = false;
    };
  }, [id]);

  const current = state?.id === id ? state.row : null;
  const row = current && current !== "error" ? current : null;

  return (
    <Dialog title="Aula do Plano pedagógico" onClose={onClose} wide hideTitle>
      <div className="space-y-4">
        <div className="flex items-start justify-between gap-3">
          <h2 className="text-xl font-semibold">
            {row ? `Aula ${row.lesson} — ${row.theme}` : "Aula do Plano pedagógico"}
          </h2>
          <Button type="button" variant="text" onClick={onClose}>Fechar</Button>
        </div>
        {state === null || state.id !== id ? <p className="text-white/70">Carregando…</p> : null}
        {current === undefined && state?.id === id && (
          <p role="status" className="text-white/80">Esta aula não existe mais no Plano pedagógico.</p>
        )}
        {current === "error" && (
          <p role="alert" className="text-error">Não foi possível carregar a aula. Tente novamente.</p>
        )}
        {row && (
          <dl className="space-y-3 text-sm">
            {PLAN_COLUMNS.filter((c) => c.field !== "lesson" && c.field !== "theme").map((c) => (
              <div key={c.field}>
                <dt className="text-xs uppercase tracking-wide text-white/50">{c.label}</dt>
                <dd className="whitespace-pre-wrap text-white/90">{String(row[c.field]).trim() || "—"}</dd>
              </div>
            ))}
          </dl>
        )}
      </div>
    </Dialog>
  );
}
