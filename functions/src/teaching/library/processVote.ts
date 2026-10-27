import {
  decideDeletion,
  decidePublication,
  DELETION_ACTIONS,
  latestPerVoter,
  PUBLICATION_ACTIONS,
} from "./decide";
import type {DeletionDecision, PublicationDecision} from "./decide";
import * as msg from "./messages";
import {deleteSubtree} from "./subtree";
import type {ItemDoc, LibraryDeps, VoteDoc} from "./types";
import {safely, unique} from "./util";

export type VoteOutcome =
  | "skipped"
  | "none"
  | "returned"
  | "published"
  | "rejected"
  | "delete_refused"
  | "deleted";

type TxResult =
  | {kind: "skip"}
  | {kind: "publication"; item: ItemDoc; decision: PublicationDecision}
  | {kind: "deletion"; item: ItemDoc; decision: DeletionDecision}
  | {
      kind: "resume";
      item: ItemDoc;
      mode: "reject" | "execute";
      votes: VoteDoc[];
    };

// Processa um voto recém-criado. Transições de estado acontecem na transação;
// remoções (Storage e documentos) são idempotentes e reexecutáveis;
// notificações e auditoria são de melhor esforço.
export async function processVote(
  deps: LibraryDeps,
  itemId: string,
  voteId: string
): Promise<VoteOutcome> {
  const result = await deps.db.transact<TxResult>(async (tx) => {
    const item = await tx.getItem(itemId);
    if (!item) return {kind: "skip"};
    const votes = await tx.listVotes(itemId);
    // Remoção já decidida: não decide de novo, só conclui (idempotente).
    if (item.deleting) {
      return {kind: "resume", item, mode: item.deleting, votes};
    }
    const current = votes.find((v) => v.id === voteId);
    if (!current) return {kind: "skip"};
    const voterIds = unique(votes.map((v) => v.voterId));

    if (PUBLICATION_ACTIONS.includes(current.action)) {
      if (item.status !== "in_review") return {kind: "skip"};
      if (current.version !== item.version) return {kind: "skip"};
      const valid = await deps.roles.currentCuratorIds(voterIds);
      const decision = decidePublication(item, votes, valid);
      if (decision.type === "return") {
        tx.updateItem(item.id, {
          status: "returned",
          returnComment: decision.comment,
          returnedBy: decision.by,
        });
      } else if (decision.type === "publish") {
        tx.updateItem(item.id, {
          status: "published",
          publishedAt: true,
          approvedBy: decision.by,
          returnComment: null,
          returnedBy: null,
        });
      } else if (decision.type === "reject") {
        tx.updateItem(item.id, {deleting: "reject"});
      }
      return {kind: "publication", item, decision};
    }

    if (DELETION_ACTIONS.includes(current.action)) {
      const request = item.deleteRequest;
      if (!request || current.requestId !== request.id) {
        return {kind: "skip"};
      }
      const valid = await deps.roles.currentCuratorIds(voterIds);
      const decision = decideDeletion(item, votes, valid);
      if (decision.type === "refuse") {
        tx.updateItem(item.id, {deleteRequest: null, deleteRequested: false});
      } else if (decision.type === "execute") {
        tx.updateItem(item.id, {deleting: "execute"});
      }
      return {kind: "deletion", item, decision};
    }
    return {kind: "skip"};
  });

  if (result.kind === "skip") return "skipped";
  if (result.kind === "resume") {
    const {item, votes} = result;
    if (result.mode === "reject") {
      const rejects = latestPerVoter(
        votes.filter(
          (v) =>
            PUBLICATION_ACTIONS.includes(v.action) &&
            v.version === item.version
        )
      ).filter((v) => v.action === "reject");
      return finishReject(
        deps,
        item,
        rejects.map((v) => v.voterId),
        rejects.map((v) => v.comment ?? "")
      );
    }
    const request = item.deleteRequest;
    const approvers = request ?
      latestPerVoter(
        votes.filter(
          (v) =>
            DELETION_ACTIONS.includes(v.action) &&
            v.requestId === request.id &&
            v.voterId !== request.requestedBy
        )
      )
        .filter((v) => v.action === "delete_approve")
        .map((v) => v.voterId) :
      [];
    return finishDelete(deps, item, approvers);
  }
  if (result.kind === "publication") {
    return applyPublication(deps, result.item, result.decision);
  }
  return applyDeletion(deps, result.item, result.decision);
}

async function applyPublication(
  deps: LibraryDeps,
  item: ItemDoc,
  decision: PublicationDecision
): Promise<VoteOutcome> {
  const stamp = `${item.id}_v${item.version}`;
  if (decision.type === "return") {
    const m = msg.returnedMessage(item, decision.comment);
    await safely("notificar devolução", () =>
      deps.notifier.notify({
        id: `returned_${stamp}_${item.authorId}`,
        toUid: item.authorId,
        type: "returned",
        itemId: item.id,
        ...m,
      })
    );
    await safely("auditar devolução", () =>
      deps.audit.record({
        id: `returned_${stamp}`,
        action: "returned",
        itemId: item.id,
        itemName: item.name,
        actors: [decision.by],
      })
    );
    return "returned";
  }
  if (decision.type === "publish") {
    const m = msg.publishedMessage(item);
    await safely("notificar publicação", () =>
      deps.notifier.notify({
        id: `published_${stamp}_${item.authorId}`,
        toUid: item.authorId,
        type: "published",
        itemId: item.id,
        ...m,
      })
    );
    await safely("auditar publicação", () =>
      deps.audit.record({
        id: `published_${stamp}`,
        action: "published",
        itemId: item.id,
        itemName: item.name,
        actors: [],
      })
    );
    return "published";
  }
  if (decision.type === "reject") {
    return finishReject(deps, item, decision.by, decision.comments);
  }
  return "none";
}

// Passo destrutivo da rejeição; idempotente, reexecutado pelo marcador.
async function finishReject(
  deps: LibraryDeps,
  item: ItemDoc,
  by: string[],
  comments: string[]
): Promise<VoteOutcome> {
  const stamp = `${item.id}_v${item.version}`;
  await safely("auditar rejeição", () =>
    deps.audit.record({
      id: `rejected_${stamp}`,
      action: "rejected",
      itemId: item.id,
      itemName: item.name,
      actors: by,
    })
  );
  await deps.storage.deleteItemFiles(item.id);
  await deps.db.deleteItem(item.id);
  const m = msg.rejectedMessage(item, comments);
  await safely("notificar rejeição", () =>
    deps.notifier.notify({
      id: `rejected_${stamp}_${item.authorId}`,
      toUid: item.authorId,
      type: "rejected",
      itemId: item.id,
      ...m,
    })
  );
  return "rejected";
}

// Passo destrutivo da exclusão; idempotente, reexecutado pelo marcador.
async function finishDelete(
  deps: LibraryDeps,
  item: ItemDoc,
  approvers: string[]
): Promise<VoteOutcome> {
  const request = item.deleteRequest;
  const stamp = request ? `${item.id}_${request.id}` : item.id;
  await safely("auditar exclusão", () =>
    deps.audit.record({
      id: `deleted_${stamp}`,
      action: "deleted",
      itemId: item.id,
      itemName: item.name,
      actors: request ? [request.requestedBy, ...approvers] : approvers,
    })
  );
  await deleteSubtree(deps, item);
  if (request) {
    const m = msg.deleteExecutedMessage(item);
    await safely("notificar exclusão", () =>
      deps.notifier.notify({
        id: `deleted_${stamp}_${request.requestedBy}`,
        toUid: request.requestedBy,
        type: "deleted",
        itemId: item.id,
        ...m,
      })
    );
  }
  return "deleted";
}

async function applyDeletion(
  deps: LibraryDeps,
  item: ItemDoc,
  decision: DeletionDecision
): Promise<VoteOutcome> {
  const request = item.deleteRequest;
  if (!request) return "none";
  const stamp = `${item.id}_${request.id}`;
  if (decision.type === "refuse") {
    const m = msg.deleteRefusedMessage(item, decision.comment);
    await safely("notificar recusa", () =>
      deps.notifier.notify({
        id: `delete_refused_${stamp}_${request.requestedBy}`,
        toUid: request.requestedBy,
        type: "delete_refused",
        itemId: item.id,
        ...m,
      })
    );
    await safely("auditar recusa", () =>
      deps.audit.record({
        id: `delete_refused_${stamp}`,
        action: "delete_refused",
        itemId: item.id,
        itemName: item.name,
        actors: [request.requestedBy, decision.by],
      })
    );
    return "delete_refused";
  }
  if (decision.type === "execute") {
    return finishDelete(deps, item, decision.by);
  }
  return "none";
}
