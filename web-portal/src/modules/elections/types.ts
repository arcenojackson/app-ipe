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

/** Escrutínio aberto: as opções já vêm montadas pelo servidor. */
export interface Round {
  id: string;
  position: string;
  number: 1 | 2 | 3;
  options: Candidate[];
}

export type VoterStatus = "pending" | "approved" | "rejected";

export interface Voter {
  status: VoterStatus;
  kind: "member" | "guest";
  name: string;
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

/** `result` gravado pelo servidor ao encerrar o escrutínio. */
export interface RoundResult {
  counts: Record<string, number>;
  blank: number;
  total: number;
  presentCount: number;
  threshold: number;
  winnerId: string | null;
  tie: string[];
  divergence: boolean;
}

/** Eleição como a tela de condução a lê. */
export interface ConductElection extends Election {
  positions: string[];
  directorIds: string[];
}

export interface Cargo {
  position: string;
  stage: CargoStage;
  cycle: number;
  candidates: CandidateVotes[];
  tiedIds: string[];
  winnerId: string | null;
}

export interface ConductRound {
  id: string;
  position: string;
  number: 1 | 2 | 3;
  cycle: number;
  status: "open" | "closed";
  options: Candidate[];
  votedCount: number;
  result?: RoundResult;
}

export interface ConductVoter {
  id: string;
  name: string;
  email: string;
  kind: "member" | "guest";
  status: VoterStatus;
}

const POSITION_LABELS: Record<string, string> = {
  presidente: "Presidente",
  vice: "Vice",
  secretario: "1º Secretário(a)",
  secretario2: "2º Secretário(a)",
  tesoureiro: "Tesoureiro(a)",
};

export const positionLabel = (position: string): string =>
  POSITION_LABELS[position] ?? position;
