import {
  GoogleAuthProvider,
  signInAnonymously,
  signInWithEmailAndPassword,
  signInWithPopup,
} from "firebase/auth";
import {
  collection,
  doc,
  limit,
  onSnapshot,
  query,
  where,
  type Unsubscribe,
} from "firebase/firestore";
import {httpsCallable} from "firebase/functions";
import {auth, db, functions} from "@/core/firebase/client";
import type {Election, Round, Voter} from "../types";

type OnError = (message: string) => void;

export function watchElection(
  id: string,
  onData: (election: Election | null) => void,
  onError: OnError
): Unsubscribe {
  return onSnapshot(
    doc(db, "elections", id),
    (snap) =>
      onData(snap.exists() ? ({id: snap.id, ...snap.data()} as Election) : null),
    (e) => onError(e.message)
  );
}

export function watchVoter(
  electionId: string,
  uid: string,
  onData: (voter: Voter | null) => void,
  onError: OnError
): Unsubscribe {
  return onSnapshot(
    doc(db, "elections", electionId, "voters", uid),
    (snap) => onData(snap.exists() ? (snap.data() as Voter) : null),
    (e) => onError(e.message)
  );
}

export function watchOpenRound(
  electionId: string,
  onData: (round: Round | null) => void,
  onError: OnError
): Unsubscribe {
  const q = query(
    collection(db, "elections", electionId, "rounds"),
    where("status", "==", "open"),
    limit(1)
  );
  return onSnapshot(
    q,
    (snap) =>
      onData(
        snap.empty ?
          null :
          ({id: snap.docs[0].id, ...snap.docs[0].data()} as Round)
      ),
    (e) => onError(e.message)
  );
}

export function watchHasVoted(
  electionId: string,
  roundId: string,
  uid: string,
  onData: (hasVoted: boolean) => void,
  onError: OnError
): Unsubscribe {
  return onSnapshot(
    doc(db, "elections", electionId, "rounds", roundId, "voted", uid),
    (snap) => onData(snap.exists()),
    (e) => onError(e.message)
  );
}

export async function checkIn(
  electionId: string,
  guest?: {name: string; email: string}
): Promise<void> {
  const call = httpsCallable(functions, "electionCheckIn");
  await call({electionId, ...guest});
}

export async function castVote(
  electionId: string,
  roundId: string,
  choice: string
): Promise<string> {
  const call = httpsCallable<
    {electionId: string; roundId: string; choice: string},
    {receipt: string}
  >(functions, "electionCastVote");
  const res = await call({electionId, roundId, choice});
  return res.data.receipt;
}

export const signInGuest = () => signInAnonymously(auth);

export const signInWithPassword = (email: string, password: string) =>
  signInWithEmailAndPassword(auth, email.trim(), password);

export const signInWithGoogle = () =>
  signInWithPopup(auth, new GoogleAuthProvider());

export function errorMessage(e: unknown): string {
  return e instanceof Error && e.message ? e.message : "Algo deu errado.";
}
