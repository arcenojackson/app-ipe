"use client";

import {Button} from "@/core/ui/Button";
import {cargoView, type ConductActionKind} from "../conduct/cargoView";
import {
  positionLabel,
  type Cargo,
  type ConductRound,
  type ConductVoter,
} from "../types";

interface Props {
  cargo: Cargo;
  /** Escrutínio aberto deste cargo, se houver. */
  openRound: ConductRound | null;
  /** Último escrutínio encerrado deste cargo, se houver. */
  lastClosed: ConductRound | null;
  approved: ConductVoter[];
  votedIds: string[];
  busy: boolean;
  onAction: (kind: ConductActionKind, targetId?: string) => void;
}

export function CargoCard({
  cargo, openRound, lastClosed, approved, votedIds, busy, onAction,
}: Props) {
  const winnerName = cargo.candidates.find((c) => c.id === cargo.winnerId)?.name;
  const view = cargoView({
    stage: cargo.stage,
    candidates: cargo.candidates,
    tiedIds: cargo.tiedIds,
    winnerName,
  });
  const result = lastClosed?.result;
  const missing = approved.filter((v) => !votedIds.includes(v.id));
  const removeFor = (id: string) =>
    view.actions.find((a) => a.kind === "removeCandidate" && a.targetId === id);
  const footerActions = view.actions.filter((a) => a.kind !== "removeCandidate");

  return (
    <article className="space-y-3 rounded-card bg-white/5 p-4">
      <header>
        <h3 className="text-base font-semibold">{positionLabel(cargo.position)}</h3>
        <p className="text-sm text-white/70">{view.title}</p>
      </header>

      {openRound && (
        <div className="space-y-1 text-sm">
          <p>{`${votedIds.length} de ${approved.length} votaram`}</p>
          {missing.length > 0 && (
            <>
              <p className="text-white/70">Faltam votar:</p>
              <ul className="list-disc pl-5">
                {missing.map((v) => <li key={v.id}>{v.name}</li>)}
              </ul>
            </>
          )}
        </div>
      )}

      {cargo.stage === "confirming" && cargo.candidates.length > 0 && (
        <ul className="space-y-2">
          {cargo.candidates.map((c) => (
            <li key={c.id} className="flex flex-wrap items-center justify-between gap-2">
              <span>{`${c.name} — ${c.votes} ${c.votes === 1 ? "voto" : "votos"} no 1º escrutínio`}</span>
              {removeFor(c.id) && (
                <Button type="button" variant="text" disabled={busy} onClick={() => onAction("removeCandidate", c.id)}>
                  Remover como candidato
                </Button>
              )}
            </li>
          ))}
        </ul>
      )}

      {!openRound && result && (
        <div className="space-y-1 text-sm">
          <p className="text-white/70">{`Resultado do ${lastClosed.number}º escrutínio`}</p>
          <ul>
            {lastClosed.options.map((o) => (
              <li key={o.id}>{`${o.name}: ${result.counts[o.id] ?? 0}`}</li>
            ))}
            <li>{`Branco: ${result.blank}`}</li>
          </ul>
          {lastClosed.number > 1 && (
            <p>{`${result.threshold} de ${result.presentCount} necessários`}</p>
          )}
          {result.divergence && (
            <p role="alert" className="text-error">
              Atenção: a contagem diverge do número de votantes.
            </p>
          )}
        </div>
      )}

      {footerActions.length > 0 && (
        <div className="flex flex-wrap gap-2">
          {footerActions.map((a) => (
            <Button key={`${a.kind}-${a.targetId ?? ""}`} type="button" disabled={busy} onClick={() => onAction(a.kind, a.targetId)}>
              {a.label}
            </Button>
          ))}
        </div>
      )}
    </article>
  );
}
