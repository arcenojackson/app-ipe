import {REQUIRED_APPROVALS} from "./files";
import type {LibraryItem, LibraryVote} from "./types";

export type BadgeTone = "neutral" | "info" | "warning" | "success" | "danger";

// Último voto de cada votante (por createdAt e, no empate, id).
function latestPerVoter(votes: LibraryVote[]): LibraryVote[] {
  const sorted = [...votes].sort(
    (a, b) => a.createdAt - b.createdAt || a.id.localeCompare(b.id)
  );
  const byVoter = new Map<string, LibraryVote>();
  for (const vote of sorted) byVoter.set(vote.voterId, vote);
  return [...byVoter.values()];
}

// Aprovações da versão atual, sem o autor. O papel de cada votante não é
// conhecido aqui; a Function confere no Auth ao decidir (a contagem é um
// indicador de andamento).
export function countApprovals(item: LibraryItem, votes: LibraryVote[]): number {
  const eligible = votes.filter(
    (v) =>
      (v.action === "approve" || v.action === "reject" || v.action === "return") &&
      v.version === item.version &&
      v.voterId !== item.authorId
  );
  return latestPerVoter(eligible).filter((v) => v.action === "approve").length;
}

export function countDeleteApprovals(
  item: LibraryItem,
  votes: LibraryVote[]
): number {
  const request = item.deleteRequest;
  if (!request) return 0;
  const eligible = votes.filter(
    (v) =>
      (v.action === "delete_approve" || v.action === "delete_refuse") &&
      v.requestId === request.id &&
      v.voterId !== request.requestedBy
  );
  return latestPerVoter(eligible).filter((v) => v.action === "delete_approve")
    .length;
}

export function statusBadge(
  item: LibraryItem,
  approvals: number | null
): {label: string; tone: BadgeTone} {
  if (item.deleting) return {label: "Excluindo…", tone: "danger"};
  if (item.deleteRequest) return {label: "Exclusão solicitada", tone: "danger"};
  if (item.type === "folder") return {label: "", tone: "neutral"};
  if (item.status === "published") return {label: "Publicado", tone: "success"};
  if (item.status === "returned") return {label: "Devolvido", tone: "warning"};
  if (approvals === null) return {label: "Em revisão", tone: "info"};
  return {
    label: `Em revisão ${Math.min(approvals, REQUIRED_APPROVALS)}/${REQUIRED_APPROVALS}`,
    tone: "info",
  };
}
