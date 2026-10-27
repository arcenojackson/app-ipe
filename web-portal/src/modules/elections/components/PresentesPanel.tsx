"use client";

import {Button} from "@/core/ui/Button";
import type {ConductVoter} from "../types";

/** Chave da ação "aceitar/recusar" de um presente, para o spinner do botão. */
export const reviewKey = (voterId: string, decision: "approved" | "rejected") =>
  `review:${voterId}:${decision}`;

interface Props {
  voters: ConductVoter[];
  busy: boolean;
  /** Chave da ação em andamento (`reviewKey`), ou null. */
  pending: string | null;
  onReview: (voterId: string, decision: "approved" | "rejected") => void;
}

/** Quem entrou pela página de voto: aceitar ou recusar quem espera liberação. */
export function PresentesPanel({voters, busy, pending, onReview}: Props) {
  const approved = voters.filter((v) => v.status === "approved").length;
  const waiting = voters.filter((v) => v.status === "pending");

  return (
    <section className="space-y-3">
      <h2 className="text-lg font-semibold">Presentes</h2>
      <p className="text-sm text-white/70">Liberados: {approved}</p>
      {waiting.length > 0 && (
        <ul className="space-y-2">
          {waiting.map((v) => (
            <li key={v.id} className="flex flex-wrap items-center justify-between gap-2 rounded-card bg-white/5 px-4 py-3">
              <span>
                {v.name}
                {v.email && <span className="block text-xs text-white/60">{v.email}</span>}
              </span>
              <span className="flex gap-2">
                <Button type="button" variant="text" disabled={busy} loading={pending === reviewKey(v.id, "rejected")} aria-label={`Recusar ${v.name}`} onClick={() => onReview(v.id, "rejected")}>
                  Recusar
                </Button>
                <Button type="button" disabled={busy} loading={pending === reviewKey(v.id, "approved")} aria-label={`Aceitar ${v.name}`} onClick={() => onReview(v.id, "approved")}>
                  Aceitar
                </Button>
              </span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
