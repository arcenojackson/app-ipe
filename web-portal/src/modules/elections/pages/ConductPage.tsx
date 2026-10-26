"use client";

import {useEffect, useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {Button} from "@/core/ui/Button";
import {GlassCard} from "@/core/ui/GlassCard";
import type {ConductActionKind} from "../conduct/cargoView";
import {CargoCard} from "../components/CargoCard";
import {PresentesPanel} from "../components/PresentesPanel";
import {QrPanel} from "../components/QrPanel";
import {
  applyBoard,
  closeScrutiny,
  errorMessage,
  pickOldest,
  removeCandidate,
  restartCargo,
  reviewVoter,
  setStatus,
  startScrutiny,
  watchCargos,
  watchElection,
  watchRounds,
  watchVoted,
  watchVoters,
} from "../data/conductClient";
import {
  positionLabel,
  type Cargo,
  type ConductElection,
  type ConductRound,
  type ConductVoter,
} from "../types";

const idleCargo = (position: string): Cargo => ({
  position, stage: "idle", cycle: 1, candidates: [], tiedIds: [], winnerId: null,
});

/** Último escrutínio encerrado do cargo: maior ciclo e, nele, maior número. */
const lastClosedOf = (rounds: ConductRound[], position: string) =>
  rounds
    .filter((r) => r.position === position && r.status === "closed")
    .sort((a, b) => b.cycle - a.cycle || b.number - a.number)[0] ?? null;

export function ConductPage({electionId}: {electionId: string}) {
  const {state} = useAuth();
  const uid = state.status === "signedIn" ? state.user.uid : null;

  const [election, setElection] = useState<ConductElection | null | undefined>(undefined);
  const [cargos, setCargos] = useState<Cargo[]>([]);
  const [rounds, setRounds] = useState<ConductRound[]>([]);
  const [voters, setVoters] = useState<ConductVoter[]>([]);
  const [votedIds, setVotedIds] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const isDirector = !!uid && !!election && election.directorIds.includes(uid);

  useEffect(() => watchElection(electionId, setElection, setError), [electionId]);
  useEffect(() => {
    if (!isDirector) return;
    const stops = [
      watchCargos(electionId, setCargos, setError),
      watchRounds(electionId, setRounds, setError),
      watchVoters(electionId, setVoters, setError),
    ];
    return () => stops.forEach((stop) => stop());
  }, [electionId, isDirector]);

  const openRound = rounds.find((r) => r.status === "open") ?? null;
  const openRoundId = openRound?.id;
  useEffect(() => {
    if (!isDirector || !openRoundId) return;
    return watchVoted(electionId, openRoundId, setVotedIds, setError);
  }, [electionId, isDirector, openRoundId]);

  async function run(action: () => Promise<unknown>) {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      await action();
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  if (election === undefined) return <p className="p-6 text-white/70">Carregando…</p>;
  if (election === null) return <p className="p-6">Eleição não encontrada.</p>;
  if (!isDirector) {
    return (
      <p className="p-6">Acesso restrito aos diretores desta sociedade.</p>
    );
  }

  const approved = voters.filter((v) => v.status === "approved");
  const anyDecided = cargos.some((c) => c.stage === "decided");

  function onAction(position: string, kind: ConductActionKind, targetId?: string) {
    void run(async () => {
      if (kind === "start") await startScrutiny(electionId, position);
      else if (kind === "close") await closeScrutiny(electionId, position);
      else if (kind === "restart") await restartCargo(electionId, position);
      else if (targetId && kind === "removeCandidate") await removeCandidate(electionId, position, targetId);
      else if (targetId && kind === "pickOldest") await pickOldest(electionId, position, targetId);
    });
  }

  return (
    <main className="mx-auto max-w-3xl space-y-6 p-6">
      <GlassCard className="space-y-4">
        <header className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-2xl font-semibold">{election.title}</h1>
            <p className="text-sm text-white/70">{election.societyName}</p>
          </div>
          {election.status === "draft" && (
            <Button type="button" disabled={busy} onClick={() => void run(() => setStatus(electionId, "open"))}>
              Abrir eleição
            </Button>
          )}
          {election.status === "open" && (
            <Button type="button" variant="text" disabled={busy} onClick={() => void run(() => setStatus(electionId, "closed"))}>
              Encerrar eleição
            </Button>
          )}
          {election.status === "closed" && <span className="text-sm text-white/70">Encerrada</span>}
        </header>
        {election.status !== "closed" && <QrPanel electionId={electionId} />}
      </GlassCard>

      {error && <p role="alert" className="text-sm text-error">{error}</p>}
      {notice && <p className="text-sm text-white/80">{notice}</p>}

      <GlassCard>
        <PresentesPanel
          voters={voters}
          busy={busy}
          onReview={(voterId, decision) => void run(() => reviewVoter(electionId, voterId, decision))}
        />
      </GlassCard>

      <section className="space-y-3">
        {election.positions.map((position) => {
          const cargo = cargos.find((c) => c.position === position) ?? idleCargo(position);
          return (
            <CargoCard
              key={position}
              cargo={cargo}
              openRound={openRound?.position === position ? openRound : null}
              lastClosed={lastClosedOf(rounds, position)}
              approved={approved}
              votedIds={openRound?.position === position ? votedIds : []}
              busy={busy}
              onAction={(kind, targetId) => onAction(position, kind, targetId)}
            />
          );
        })}
      </section>

      <GlassCard className="space-y-2">
        <Button
          type="button"
          disabled={busy || !anyDecided}
          onClick={() => void run(async () => {
            const res = await applyBoard(electionId);
            setNotice(
              res.missingRequired.length > 0 ?
                `Faltam cargos obrigatórios: ${res.missingRequired.map(positionLabel).join(", ")}` :
                "Diretoria aplicada."
            );
          })}
        >
          Aplicar diretoria
        </Button>
      </GlassCard>
    </main>
  );
}
