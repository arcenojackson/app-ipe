import type {Firestore} from "firebase-admin/firestore";
import {fail, getElection, type ElectionDoc} from "./common";

// Ids da diretoria de uma sociedade. Aceita o mapa cargo → ids (valor lista
// ou string) e a lista antiga de ids; qualquer outro formato vira [].
export const directorIdsOf = (board: unknown): string[] => {
  const ids: string[] = [];
  const add = (value: unknown) => {
    if (typeof value === "string" && value !== "") ids.push(value);
  };
  if (Array.isArray(board)) {
    board.forEach(add);
  } else if (board && typeof board === "object") {
    for (const value of Object.values(board)) {
      if (Array.isArray(value)) value.forEach(add);
      else add(value);
    }
  }
  return [...new Set(ids)];
};

// Carrega a eleição e exige que `uid` esteja entre os diretores dela
// (snapshot gravado na criação). Admin global sem cargo na diretoria não passa.
export const assertElectionDirector = async (
  db: Firestore,
  uid: string,
  electionId: string
): Promise<ElectionDoc> => {
  const election = await getElection(db, electionId);
  const directors = Array.isArray(election.directorIds) ?
    election.directorIds :
    [];
  if (!directors.includes(uid)) {
    throw fail(
      "permission-denied",
      "Apenas os diretores desta sociedade podem fazer isso."
    );
  }
  return election;
};
