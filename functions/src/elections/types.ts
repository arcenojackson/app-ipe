export type ElectionStatus = "draft" | "open" | "closed";
export type RoundStatus = "pending" | "open" | "closed";
export type RoundType = "normal" | "single" | "runoff";
export type VoterStatus = "pending" | "approved" | "rejected";
export type VoterKind = "member" | "guest";

export interface Candidate {
  id: string;
  name: string;
}

export interface RoundResult {
  counts: Record<string, number>;
  total: number;
  votedCount: number;
  winnerId: string | null;
  tie: string[];
  divergence: boolean;
}

export type CargoStage =
  | "idle"
  | "scrutiny1"
  | "confirming"
  | "scrutiny2"
  | "awaiting3"
  | "scrutiny3"
  | "tiebreak"
  | "decided";

export interface CandidateVotes {
  id: string;
  name: string;
  votes: number;
}

// `result` gravado na rodada ao encerrar o escrutínio.
export interface ScrutinyResult {
  counts: Record<string, number>;
  blank: number;
  total: number;
  presentCount: number;
  threshold: number;
  winnerId: string | null;
  tie: string[];
  divergence: boolean;
}

// Próxima fase do cargo depois de encerrar um escrutínio.
export type ScrutinyOutcome =
  | {stage: "confirming"; candidates: CandidateVotes[]}
  | {stage: "decided"; winnerId: string}
  | {stage: "awaiting3"}
  | {stage: "tiebreak"; tiedIds: string[]}
  | {stage: "idle"};

export const YES = "yes";
export const NO = "no";
export const BLANK = "blank";
