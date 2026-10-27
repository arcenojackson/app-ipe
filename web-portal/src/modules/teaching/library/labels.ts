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

export function formatDate(ms: number | undefined): string {
  if (!ms) return "—";
  return new Date(ms).toLocaleDateString("pt-BR");
}

export function formatBytes(size: number): string {
  if (size < 1024) return `${size} B`;
  if (size < 1024 * 1024) return `${Math.round(size / 1024)} KB`;
  const mb = size / (1024 * 1024);
  const text = Number.isInteger(mb) ? String(mb) : mb.toFixed(1).replace(".", ",");
  return `${text} MB`;
}

// "Ana, Bia +1": primeiros nomes (até `max`) e "+N" para o resto; `title` traz
// os nomes completos. Sem aprovadores gravados mostra "—".
export function approverLabel(
  ids: string[] | undefined,
  names: Record<string, string>,
  max = 2
): {text: string; title: string} {
  if (!ids || ids.length === 0) return {text: "—", title: ""};
  const full = ids.map((id) => names[id] ?? "Curador");
  const first = full.slice(0, max).map((n) => n.split(" ")[0]);
  const rest = full.length - first.length;
  return {text: rest > 0 ? `${first.join(", ")} +${rest}` : first.join(", "), title: full.join(", ")};
}
