import {
  REQUIRED_APPROVALS,
  REQUIRED_DELETE_APPROVALS,
  REQUIRED_REJECTIONS,
} from "./constants";
import type {ItemDoc, VoteAction, VoteDoc} from "./types";

export const PUBLICATION_ACTIONS: VoteAction[] = [
  "approve",
  "reject",
  "return",
];
export const DELETION_ACTIONS: VoteAction[] = [
  "delete_approve",
  "delete_refuse",
];

export type PublicationDecision =
  | {type: "none"}
  | {type: "publish"; by: string[]}
  | {type: "return"; by: string; comment: string}
  | {type: "reject"; comments: string[]; by: string[]};

export type DeletionDecision =
  | {type: "none"}
  | {type: "refuse"; by: string; comment: string}
  | {type: "execute"; by: string[]};

// Mantém só o último voto de cada votante (createdAt e, no empate, id).
export function latestPerVoter(votes: VoteDoc[]): VoteDoc[] {
  const sorted = [...votes].sort(
    (a, b) => a.createdAt - b.createdAt || a.id.localeCompare(b.id)
  );
  const byVoter = new Map<string, VoteDoc>();
  for (const v of sorted) byVoter.set(v.voterId, v);
  return [...byVoter.values()];
}

// Votos de publicação: versão atual, não-autor, curador hoje, último de cada.
export function decidePublication(
  item: ItemDoc,
  votes: VoteDoc[],
  validCurators: Set<string>
): PublicationDecision {
  const eligible = votes.filter(
    (v) =>
      PUBLICATION_ACTIONS.includes(v.action) &&
      v.version === item.version &&
      v.voterId !== item.authorId &&
      validCurators.has(v.voterId)
  );
  const latest = latestPerVoter(eligible);

  const returns = latest
    .filter((v) => v.action === "return")
    .sort((a, b) => b.createdAt - a.createdAt);
  if (returns.length > 0) {
    const first = returns[0];
    return {type: "return", by: first.voterId, comment: first.comment ?? ""};
  }

  const approvals = latest.filter((v) => v.action === "approve");
  if (approvals.length >= REQUIRED_APPROVALS) {
    return {type: "publish", by: approvals.map((v) => v.voterId)};
  }

  const rejects = latest.filter((v) => v.action === "reject");
  if (rejects.length >= REQUIRED_REJECTIONS) {
    return {
      type: "reject",
      comments: rejects.map((v) => v.comment ?? ""),
      by: rejects.map((v) => v.voterId),
    };
  }
  return {type: "none"};
}

// Votos de exclusão: pedido atual, não-solicitante, curador hoje.
export function decideDeletion(
  item: ItemDoc,
  votes: VoteDoc[],
  validCurators: Set<string>
): DeletionDecision {
  const request = item.deleteRequest;
  if (!request) return {type: "none"};
  const eligible = votes.filter(
    (v) =>
      DELETION_ACTIONS.includes(v.action) &&
      v.requestId === request.id &&
      v.voterId !== request.requestedBy &&
      validCurators.has(v.voterId)
  );
  const latest = latestPerVoter(eligible);

  const refusals = latest
    .filter((v) => v.action === "delete_refuse")
    .sort((a, b) => b.createdAt - a.createdAt);
  if (refusals.length > 0) {
    const first = refusals[0];
    return {type: "refuse", by: first.voterId, comment: first.comment ?? ""};
  }

  const approvals = latest.filter((v) => v.action === "delete_approve");
  if (approvals.length >= REQUIRED_DELETE_APPROVALS) {
    return {type: "execute", by: approvals.map((v) => v.voterId)};
  }
  return {type: "none"};
}
