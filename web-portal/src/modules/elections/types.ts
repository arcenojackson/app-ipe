export type ElectionStatus = "draft" | "open" | "closed";

export interface Election {
  id: string;
  title: string;
  societyName: string;
  status: ElectionStatus;
}

export interface Candidate {
  id: string;
  name: string;
}

export type RoundType = "normal" | "single" | "runoff";

export interface Round {
  id: string;
  position: string;
  candidates: Candidate[];
  type: RoundType;
}

export type VoterStatus = "pending" | "approved" | "rejected";

export interface Voter {
  status: VoterStatus;
  kind: "member" | "guest";
  name: string;
}

const POSITION_LABELS: Record<string, string> = {
  presidente: "Presidente",
  vice: "Vice",
  secretario: "Secretário(a)",
  tesoureiro: "Tesoureiro(a)",
};

export const positionLabel = (position: string): string =>
  POSITION_LABELS[position] ?? position;
