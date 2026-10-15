import {
  BLANK,
  NO,
  YES,
  type Candidate,
  type RoundResult,
  type RoundType,
} from "./types";

const has = (obj: object, key: string): boolean =>
  Object.prototype.hasOwnProperty.call(obj, key);

// Conta os votos de uma rodada. `votedCount` é o número de documentos em
// `voted`; se não bater com o número de ballots (ou houver escolha
// inválida), o resultado sai marcado com `divergence`.
export const tallyRound = (
  type: RoundType,
  candidates: Candidate[],
  choices: string[],
  votedCount: number
): RoundResult => {
  const keys = type === "single" ?
    [YES, NO, BLANK] :
    [...candidates.map((c) => c.id), BLANK];
  const counts: Record<string, number> = {};
  for (const key of keys) counts[key] = 0;

  let invalid = 0;
  for (const choice of choices) {
    if (has(counts, choice)) counts[choice] += 1;
    else invalid += 1;
  }

  const base = {
    counts,
    total: choices.length,
    votedCount,
    divergence: invalid > 0 || choices.length !== votedCount,
  };

  if (type === "single") {
    const winnerId = candidates.length > 0 && counts[YES] > counts[NO] ?
      candidates[0].id :
      null;
    return {...base, winnerId, tie: []};
  }

  const top = Math.max(0, ...candidates.map((c) => counts[c.id]));
  if (top === 0) return {...base, winnerId: null, tie: []};
  const leaders = candidates
    .filter((c) => counts[c.id] === top)
    .map((c) => c.id);
  return leaders.length === 1 ?
    {...base, winnerId: leaders[0], tie: []} :
    {...base, winnerId: null, tie: leaders};
};
