import type {Election, Round, Voter} from "./types";

export type VoteView =
  | {kind: "loading"}
  | {kind: "notFound"}
  | {kind: "notOpen"}
  | {kind: "closed"}
  | {kind: "join"}
  | {kind: "pending"}
  | {kind: "rejected"}
  | {kind: "waitingRound"}
  | {kind: "ballot"; round: Round}
  | {kind: "voted"; round: Round};

/** `undefined` = ainda carregando; `null` = carregou e não existe. */
export interface DeriveInput {
  election: Election | null | undefined;
  voter: Voter | null | undefined;
  openRound: Round | null | undefined;
  hasVoted: boolean | undefined;
  hasUser: boolean;
}

export function deriveView(input: DeriveInput): VoteView {
  const {election, voter, openRound, hasVoted, hasUser} = input;
  if (election === undefined) return {kind: "loading"};
  if (election === null) return {kind: "notFound"};
  if (election.status === "draft") return {kind: "notOpen"};
  if (election.status === "closed") return {kind: "closed"};

  if (!hasUser) return {kind: "join"};
  if (voter === undefined) return {kind: "loading"};
  if (voter === null) return {kind: "join"};
  if (voter.status === "pending") return {kind: "pending"};
  if (voter.status === "rejected") return {kind: "rejected"};

  if (openRound === undefined) return {kind: "loading"};
  if (openRound === null) return {kind: "waitingRound"};
  if (hasVoted === undefined) return {kind: "loading"};
  return hasVoted ?
    {kind: "voted", round: openRound} :
    {kind: "ballot", round: openRound};
}
