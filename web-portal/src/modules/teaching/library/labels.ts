import type {VoteAction} from "./types";

const LABELS: Record<VoteAction, string> = {
  approve: "Aprovou",
  reject: "Rejeitou",
  return: "Devolveu",
  delete_approve: "Aprovou a exclusão",
  delete_refuse: "Recusou a exclusão",
};

export function voteLabel(action: VoteAction): string {
  return LABELS[action];
}

export function formatDateTime(ms: number): string {
  if (!ms) return "—";
  return new Date(ms).toLocaleString("pt-BR", {dateStyle: "short", timeStyle: "short"});
}
