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

export const YES = "yes";
export const NO = "no";
export const BLANK = "blank";
