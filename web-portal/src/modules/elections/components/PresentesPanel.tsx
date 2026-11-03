"use client";

import {useState} from "react";
import {Button} from "@/core/ui/Button";
import {Modal} from "@/core/ui/Modal";
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
  const present = voters.filter((v) => v.status === "approved");
  const approved = present.length;
  const waiting = voters.filter((v) => v.status === "pending");
  const [listOpen, setListOpen] = useState(false);

  return (
    <section className="space-y-3">
      <h2 className="text-lg font-semibold">Presentes</h2>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-sm text-white/70">Liberados: {approved}</p>
        <Button type="button" variant="text" onClick={() => setListOpen(true)}>
          Ver presentes
        </Button>
      </div>
      {listOpen && (
        <Modal title={`Presentes (${approved})`} onClose={() => setListOpen(false)}>
          {approved === 0 ? (
            <p className="text-sm text-white/70">Ninguém entrou na votação ainda.</p>
          ) : (
            <ul className="space-y-1">
              {present.map((v) => (
                <li key={v.id}>{`${v.name} (${v.kind === "member" ? "membro" : "convidado"})`}</li>
              ))}
            </ul>
          )}
        </Modal>
      )}
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
