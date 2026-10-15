import type {Candidate, RoundType} from "./types";

export const removeElected = (
  candidates: Candidate[],
  elected: Set<string>
): Candidate[] => candidates.filter((c) => !elected.has(c.id));

// Um candidato só vira rodada `single`; senão mantém normal/runoff.
export const roundTypeFor = (
  candidates: Candidate[],
  requested: RoundType
): RoundType => {
  if (candidates.length === 1) return "single";
  return requested === "runoff" ? "runoff" : "normal";
};
