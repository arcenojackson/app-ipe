import {BLANK, type Candidate, type ScrutinyOutcome} from "./types";

const has = (obj: object, key: string): boolean =>
  Object.prototype.hasOwnProperty.call(obj, key);

// 50% + 1 dos presentes liberados.
export const requiredVotes = (presentCount: number): number =>
  Math.floor(presentCount / 2) + 1;

// Conta os ballots de um escrutínio. `votedCount` é o número de documentos em
// `voted`; se não bater com os ballots (ou houver escolha inválida), marca
// `divergence`.
export const countBallots = (
  options: Candidate[],
  choices: string[],
  votedCount: number
): {
  counts: Record<string, number>;
  blank: number;
  total: number;
  divergence: boolean;
} => {
  const counts: Record<string, number> = {};
  for (const option of options) counts[option.id] = 0;
  let blank = 0;
  let invalid = 0;
  for (const choice of choices) {
    if (choice === BLANK) blank += 1;
    else if (has(counts, choice)) counts[choice] += 1;
    else invalid += 1;
  }
  return {
    counts,
    blank,
    total: choices.length,
    divergence: invalid > 0 || choices.length !== votedCount,
  };
};

// Decide a próxima fase do cargo (regras do rito, seção 3 do spec).
export const decideScrutiny = (input: {
  number: 1 | 2 | 3;
  options: Candidate[];
  counts: Record<string, number>;
  presentCount: number;
}): ScrutinyOutcome => {
  const {number, options, counts, presentCount} = input;
  const votesOf = (id: string): number => counts[id] ?? 0;

  if (number === 1) {
    const candidates = options
      .map((o) => ({id: o.id, name: o.name, votes: votesOf(o.id)}))
      .filter((c) => c.votes > 0)
      .sort((a, b) => b.votes - a.votes || a.name.localeCompare(b.name));
    return {stage: "confirming", candidates};
  }

  const top = Math.max(0, ...options.map((o) => votesOf(o.id)));
  const leaders = options.filter((o) => votesOf(o.id) === top);

  if (number === 2) {
    if (top >= requiredVotes(presentCount) && leaders.length === 1) {
      return {stage: "decided", winnerId: leaders[0].id};
    }
    return {stage: "awaiting3"};
  }

  if (top === 0) return {stage: "idle"};
  if (leaders.length === 1) return {stage: "decided", winnerId: leaders[0].id};
  return {stage: "tiebreak", tiedIds: leaders.map((o) => o.id)};
};
