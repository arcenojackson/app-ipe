import type {LibraryItem, LibraryVote, Viewer} from "./types";

export interface ReviewQueue {
  // Histórico de envios do próprio usuário (qualquer status): devolvidos no
  // topo (pedem ação do autor), depois do mais novo ao mais antigo.
  mine: LibraryItem[];
  // Envios de outros aguardando revisão (só curador/admin).
  toReview: LibraryItem[];
  // Devolvidos de outros autores, parados à espera de reenvio (só curador/admin):
  // o curador pode pedir a exclusão de quem nunca reenvia.
  returned: LibraryItem[];
  // Pedidos de exclusão em aberto (só curador/admin).
  deleteRequests: LibraryItem[];
}

const newestFirst = (a: LibraryItem, b: LibraryItem) =>
  (b.createdAt ?? 0) - (a.createdAt ?? 0) || a.name.localeCompare(b.name, "pt-BR");

export function buildReviewQueue(
  viewer: Viewer,
  input: {
    mine: LibraryItem[];
    inReview: LibraryItem[];
    returned: LibraryItem[];
    deleteRequested: LibraryItem[];
  }
): ReviewQueue {
  const privileged = viewer.isCurator || viewer.isAdmin;
  return {
    mine: [...input.mine].sort(
      (a, b) => Number(b.status === "returned") - Number(a.status === "returned") || newestFirst(a, b)
    ),
    toReview: privileged ?
      input.inReview.filter((i) => i.authorId !== viewer.uid).sort(newestFirst) :
      [],
    returned: privileged ?
      input.returned.filter((i) => i.authorId !== viewer.uid).sort(newestFirst) :
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
