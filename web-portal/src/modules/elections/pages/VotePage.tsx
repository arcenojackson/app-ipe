"use client";

import {useEffect, useRef, useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {GlassCard} from "@/core/ui/GlassCard";
import {BallotStep} from "../components/BallotStep";
import {JoinStep} from "../components/JoinStep";
import {
  castVote,
  checkIn,
  errorMessage,
  watchElection,
  watchHasVoted,
  watchOpenRound,
  watchVoter,
} from "../data/electionClient";
import type {Election, Round, Voter} from "../types";
import {positionLabel} from "../types";
import {deriveView, type VoteView} from "../voteState";

export function VotePage({electionId}: {electionId: string}) {
  const {state} = useAuth();
  // Só conta de verdade vota. Uma sessão anônima antiga do navegador é
  // tratada como deslogada.
  const rawUser = state.status === "signedIn" ? state.user : null;
  const user = rawUser && !rawUser.isAnonymous ? rawUser : null;
  const uid = user?.uid;

  const [election, setElection] = useState<Election | null | undefined>(undefined);
  const [voter, setVoter] = useState<Voter | null | undefined>(undefined);
  const [openRound, setOpenRound] = useState<Round | null | undefined>(undefined);
  const [hasVoted, setHasVoted] = useState<boolean | undefined>(undefined);
  const [receipts, setReceipts] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const autoCheckIn = useRef(false);

  useEffect(
    () => watchElection(electionId, setElection, setError),
    [electionId]
  );
  useEffect(() => {
    if (!uid) return;
    return watchVoter(electionId, uid, setVoter, setError);
  }, [electionId, uid]);

  const approved = voter?.status === "approved";
  useEffect(() => {
    if (!uid || !approved) return;
    return watchOpenRound(electionId, setOpenRound, setError);
  }, [electionId, uid, approved]);

  const roundId = openRound?.id;
  useEffect(() => {
    if (!uid || !roundId) return;
    return watchHasVoted(electionId, roundId, uid, setHasVoted, setError);
  }, [electionId, uid, roundId]);

  // Quem entrou com a conta do app não digita nada: o servidor decide se é
  // membro (liberado) ou convidado (pendente).
  // Se falhar (ex.: conta sem nome cadastrado), cai no formulário de nome e
  // e-mail em vez de ficar preso em "Verificando...".
  const [autoFailed, setAutoFailed] = useState(false);
  const needsAutoCheckIn =
    !!user && !autoFailed && voter === null && election?.status === "open";
  useEffect(() => {
    if (!needsAutoCheckIn || autoCheckIn.current) return;
    autoCheckIn.current = true;
    checkIn(electionId).catch((e) => {
      autoCheckIn.current = false;
      setAutoFailed(true);
      setError(errorMessage(e));
    });
  }, [needsAutoCheckIn, electionId]);

  // Enquanto a sessão carrega, ainda não se sabe se há usuário: não mostre
  // o formulário de entrada para quem já está logado.
  const view: VoteView =
    state.status === "loading" ?
      {kind: "loading"} :
      deriveView({
        election,
        voter: uid ? voter : undefined,
        openRound: uid && approved ? openRound : undefined,
        hasVoted: uid && roundId ? hasVoted : undefined,
        hasUser: !!user,
      });

  async function submit(round: Round, choice: string) {
    setBusy(true);
    setError(null);
    try {
      const receipt = await castVote(electionId, round.id, choice);
      setReceipts((prev) => ({...prev, [round.id]: receipt}));
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-md items-center justify-center p-6">
      <GlassCard className="w-full">
        {election && (
          <header className="mb-6">
            <h1 className="text-2xl font-semibold">{election.title}</h1>
            <p className="text-sm text-white/70">{election.societyName}</p>
          </header>
        )}
        {view.kind === "loading" && <p className="text-sm text-white/70">Carregando...</p>}
        {view.kind === "notFound" && <p>Eleição não encontrada.</p>}
        {view.kind === "notOpen" && <p>Esta eleição ainda não foi aberta. Aguarde o início.</p>}
        {view.kind === "closed" && <p>Esta eleição foi encerrada.</p>}
        {view.kind === "join" && (
          <JoinStep
            electionId={electionId}
            needsName={!!user && autoFailed}
            verifying={!!user && !autoFailed}
          />
        )}
        {view.kind === "pending" && (
          <p>Aguardando aprovação do administrador. Esta tela atualiza sozinha.</p>
        )}
        {view.kind === "rejected" && (
          <p>Sua participação não foi liberada. Procure o administrador da eleição.</p>
        )}
        {view.kind === "waitingRound" && (
          <p>Aguardando a próxima votação. Esta tela atualiza sozinha.</p>
        )}
        {view.kind === "ballot" && (
          <BallotStep
            key={view.round.id}
            round={view.round}
            busy={busy}
            error={error}
            onSubmit={(choice) => void submit(view.round, choice)}
          />
        )}
        {view.kind === "voted" && (
          <div className="space-y-2">
            <p>
              Seu voto foi registrado para {positionLabel(view.round.position)}.
              Aguarde a próxima votação.
            </p>
            {receipts[view.round.id] && (
              <div>
                <p className="text-sm text-white/70">Código do seu comprovante:</p>
                <p className="font-mono text-lg">{receipts[view.round.id]}</p>
              </div>
            )}
          </div>
        )}
        {error && view.kind !== "ballot" && (
          <p role="alert" className="mt-4 text-sm text-error">{error}</p>
        )}
      </GlassCard>
    </main>
  );
}
