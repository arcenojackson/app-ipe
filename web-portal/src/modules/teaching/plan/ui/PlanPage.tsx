"use client";

import {useEffect, useMemo, useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {Button} from "@/core/ui/Button";
import {viewerFrom} from "../../library/types";
import {validatePlanField} from "../payloads";
import {addPlanRow, deletePlanRow, savePlanField, subscribePlan} from "../repository";
import {PLAN_COLUMNS, type PlanField, type PlanRow} from "../types";

const LOAD_ERROR = "Não foi possível carregar o plano pedagógico.";
const SAVE_ERROR = "Não foi possível salvar. Tente novamente.";

// Plano pedagógico no formato da planilha original. Professores leem;
// curadores editam cada célula (salva ao sair do campo).
export default function PlanPage() {
  const {state} = useAuth();
  const viewer = useMemo(
    () => (state.status === "signedIn" ? viewerFrom(state.user.uid, state.claims) : null),
    [state]
  );
  const [rows, setRows] = useState<PlanRow[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [failure, setFailure] = useState<string | null>(null);

  useEffect(() => {
    let failed = false;
    return subscribePlan(
      (list) => {
        if (!failed) setRows(list);
      },
      () => {
        failed = true;
        setLoadError(LOAD_ERROR);
      }
    );
  }, []);

  if (!viewer) return null;
  const canEdit = viewer.isCurator;

  async function run(action: () => Promise<void>, success: string | null) {
    setNotice(null);
    setFailure(null);
    try {
      await action();
      setNotice(success);
    } catch {
      setFailure(SAVE_ERROR);
    }
  }

  function save(row: PlanRow, field: PlanField, value: string) {
    if (String(row[field]) === value) return;
    const problem = validatePlanField(field, value);
    if (problem) {
      setNotice(null);
      setFailure(problem);
      return;
    }
    void run(() => savePlanField(viewer!.uid, row.id, field, value), "Salvo.");
  }

  const nextLesson = (rows ?? []).reduce((max, r) => Math.max(max, r.lesson), 0) + 1;

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Plano pedagógico</h1>
      {loadError && <p role="alert" className="text-sm text-error">{loadError}</p>}
      {notice && <p role="status" className="text-sm text-secondary">{notice}</p>}
      {failure && <p role="alert" className="text-sm text-error">{failure}</p>}
      {!rows && !loadError && <p className="text-white/70">Carregando…</p>}
      {rows && rows.length === 0 && (
        <p className="rounded-card bg-surface-elevated p-6">Nenhuma aula no plano ainda.</p>
      )}
      {rows && rows.length > 0 && (
        <div className="overflow-x-auto rounded-card bg-surface-elevated">
          <table className="w-full min-w-[72rem] text-left text-sm">
            <thead className="text-white/60">
              <tr>
                {PLAN_COLUMNS.map((c) => (
                  <th key={c.field} className="px-3 py-3 font-medium">{c.label}</th>
                ))}
                {canEdit && <th className="px-3 py-3"><span className="sr-only">Ações</span></th>}
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.id} className="border-t border-white/10 align-top">
                  {PLAN_COLUMNS.map((c) => (
                    <td key={c.field} className="px-3 py-2">
                      {canEdit ? (
                        <textarea
                          key={`${row.id}-${c.field}-${String(row[c.field])}`}
                          aria-label={c.field === "lesson" ? `Número da aula ${row.lesson}` : `${c.label} da aula ${row.lesson}`}
                          defaultValue={String(row[c.field])}
                          rows={c.long ? 3 : 2}
                          onBlur={(e) => save(row, c.field, e.target.value)}
                          className={`w-full resize-y rounded-input border border-white/5 bg-surface/60 px-2 py-1 ${
                            c.field === "lesson" ? "w-16" : ""
                          }`}
                        />
                      ) : (
                        <span className="whitespace-pre-wrap">{String(row[c.field])}</span>
                      )}
                    </td>
                  ))}
                  {canEdit && (
                    <td className="px-3 py-2">
                      <Button
                        type="button"
                        variant="text"
                        aria-label={`Apagar aula ${row.lesson}`}
                        onClick={() => {
                          if (!window.confirm(`Apagar a aula ${row.lesson} do plano?`)) return;
                          void run(() => deletePlanRow(row.id), "Aula apagada.");
                        }}
                      >
                        Apagar
                      </Button>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {canEdit && (
        <Button type="button" onClick={() => void run(() => addPlanRow(viewer.uid, nextLesson, "Novo tema"), "Aula adicionada.")}>
          Adicionar aula
        </Button>
      )}
    </div>
  );
}
