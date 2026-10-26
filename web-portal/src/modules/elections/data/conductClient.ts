import {collection, doc, onSnapshot, type Unsubscribe} from "firebase/firestore";
import {httpsCallable} from "firebase/functions";
import {db, functions} from "@/core/firebase/client";
import type {
  Cargo, ConductElection, ConductRound, ConductVoter, RoundResult,
} from "../types";

export {errorMessage} from "./electionClient";

type OnError = (message: string) => void;

export function watchElection(
  id: string,
  onData: (election: ConductElection | null) => void,
  onError: OnError
): Unsubscribe {
  return onSnapshot(
    doc(db, "elections", id),
    (snap) => {
      if (!snap.exists()) return onData(null);
      const data: Record<string, unknown> = snap.data();
      onData({directorIds: [], positions: [], ...data, id: snap.id} as unknown as ConductElection);
    },
    (e) => onError(e.message)
  );
}

export function watchCargos(
  id: string,
  onData: (cargos: Cargo[]) => void,
  onError: OnError
): Unsubscribe {
  return onSnapshot(
    collection(db, "elections", id, "cargos"),
    (snap) => onData(snap.docs.map((d) => ({position: d.id, ...d.data()}) as Cargo)),
    (e) => onError(e.message)
  );
}

export function watchRounds(
  id: string,
  onData: (rounds: ConductRound[]) => void,
  onError: OnError
): Unsubscribe {
  return onSnapshot(
    collection(db, "elections", id, "rounds"),
    (snap) => onData(snap.docs.map((d) => ({id: d.id, ...d.data()}) as ConductRound)),
    (e) => onError(e.message)
  );
}

export function watchVoters(
  id: string,
  onData: (voters: ConductVoter[]) => void,
  onError: OnError
): Unsubscribe {
  return onSnapshot(
    collection(db, "elections", id, "voters"),
    (snap) => onData(snap.docs.map((d) => ({id: d.id, ...d.data()}) as ConductVoter)),
    (e) => onError(e.message)
  );
}

/** Ids de quem já votou neste escrutínio (nunca em quem votou). */
export function watchVoted(
  id: string,
  roundId: string,
  onData: (uids: string[]) => void,
  onError: OnError
): Unsubscribe {
  return onSnapshot(
    collection(db, "elections", id, "rounds", roundId, "voted"),
    (snap) => onData(snap.docs.map((d) => d.id)),
    (e) => onError(e.message)
  );
}

async function call<T>(name: string, data: Record<string, unknown>): Promise<T> {
  const res = await httpsCallable<Record<string, unknown>, T>(functions, name)(data);
  return res.data;
}

export const setStatus = (electionId: string, status: "open" | "closed") =>
  call<void>("electionSetStatus", {electionId, status});

export const reviewVoter = (
  electionId: string,
  voterId: string,
  decision: "approved" | "rejected"
) => call<void>("electionReviewVoter", {electionId, voterId, decision});

export const startScrutiny = (electionId: string, position: string) =>
  call<{roundId: string; number: number}>("electionStartScrutiny", {electionId, position});

export const closeScrutiny = (electionId: string, position: string) =>
  call<{stage: string; result: RoundResult}>("electionCloseScrutiny", {electionId, position});

export const removeCandidate = (
  electionId: string,
  position: string,
  candidateId: string
) => call<void>("electionRemoveCandidate", {electionId, position, candidateId});

export const restartCargo = (electionId: string, position: string) =>
  call<void>("electionRestartCargo", {electionId, position});

export const pickOldest = (
  electionId: string,
  position: string,
  candidateId: string
) => call<void>("electionPickOldest", {electionId, position, candidateId});

export const applyBoard = (electionId: string) =>
  call<{winners: Record<string, string>; missingRequired: string[]}>(
    "electionApplyBoard",
    {electionId}
  );
