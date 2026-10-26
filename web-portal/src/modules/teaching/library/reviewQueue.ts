import type {LibraryItem, LibraryVote, Viewer} from "./types";

export interface ReviewQueue {
  // Envios do próprio usuário (em revisão ou devolvidos).
  mine: LibraryItem[];
  // Envios de outros aguardando revisão (só curador/admin).
  toReview: LibraryItem[];
  // Pedidos de exclusão em aberto (só curador/admin).
  deleteRequests: LibraryItem[];
}

const newestFirst = (a: LibraryItem, b: LibraryItem) =>
  (b.createdAt ?? 0) - (a.createdAt ?? 0) || a.name.localeCompare(b.name, "pt-BR");

export function buildReviewQueue(
  viewer: Viewer,
  input: {mine: LibraryItem[]; inReview: LibraryItem[]; deleteRequested: LibraryItem[]}
): ReviewQueue {
  const privileged = viewer.isCurator || viewer.isAdmin;
  return {
    mine: [...input.mine].sort(newestFirst),
    toReview: privileged ?
      input.inReview.filter((i) => i.authorId !== viewer.uid).sort(newestFirst) :
      [],
    deleteRequests: privileged ? [...input.deleteRequested].sort(newestFirst) : [],
  };
}

// Já votei na versão atual (publicação) ou no pedido atual (exclusão)?
export function iVoted(item: LibraryItem, votes: LibraryVote[], uid: string): boolean {
  return votes.some((v) =>
    v.voterId === uid &&
    (item.deleteRequest ? v.requestId === item.deleteRequest.id : v.version === item.version));
}
