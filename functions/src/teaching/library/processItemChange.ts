import * as msg from "./messages";
import {moveIsValid} from "./moves";
import {collectSubtree, deleteSubtree, hasDocuments} from "./subtree";
import type {ItemDoc, LibraryDeps} from "./types";
import {safely} from "./util";

export type ChangeOutcome =
  | "none"
  | "resubmitted"
  | "moved"
  | "move_reverted"
  | "move_invalid"
  | "delete_requested"
  | "deleted_empty_folder";

async function notifyCurators(
  deps: LibraryDeps,
  item: ItemDoc,
  except: string,
  type: string,
  idStamp: string,
  message: msg.Message
): Promise<void> {
  const curators = await deps.roles.allCuratorIds();
  for (const uid of curators.filter((id) => id !== except)) {
    await safely(`notificar ${type}`, () =>
      deps.notifier.notify({
        id: `${type}_${idStamp}_${uid}`,
        toUid: uid,
        type,
        itemId: item.id,
        ...message,
      })
    );
  }
}

// Novo documento ou link em revisão: avisa os curadores (menos o autor).
export async function processItemCreated(
  deps: LibraryDeps,
  item: ItemDoc
): Promise<void> {
  // Item em destruição não gera avisos.
  if (item.deleting) return;
  if (item.type === "folder" || item.status !== "in_review") return;
  await notifyCurators(
    deps,
    item,
    item.authorId,
    "review_requested",
    `${item.id}_v${item.version}`,
    msg.reviewRequestedMessage(item, false)
  );
  await safely("auditar envio", () =>
    deps.audit.record({
      id: `submitted_${item.id}_v${item.version}`,
      action: "submitted",
      itemId: item.id,
      itemName: item.name,
      actors: [item.authorId],
    })
  );
}

export async function processItemChange(
  deps: LibraryDeps,
  before: ItemDoc,
  after: ItemDoc
): Promise<ChangeOutcome> {
  // Item em destruição: sem avisos, reversões nem limpeza de reenvio.
  if (after.deleting) return "none";

  // 1) Movimento
  if (before.parentId !== after.parentId) {
    if (await moveIsValid(deps.db, after)) return "moved";
    // Só desfaz se o destino do revert for válido; senão o desfazer
    // reacionaria este handler em ciclo infinito.
    const revertTarget = {...after, parentId: before.parentId};
    if (!(await moveIsValid(deps.db, revertTarget))) {
      console.error(
        `Movimento inválido e pai anterior também inválido: item ${after.id}` +
        ` (pai anterior ${before.parentId}, pai atual ${after.parentId});` +
        " nada foi revertido."
      );
      return "move_invalid";
    }
    await deps.db.updateItem(after.id, {parentId: before.parentId});
    const mover = after.updatedBy;
    if (mover) {
      const m = msg.moveRevertedMessage(after);
      await safely("notificar movimento desfeito", () =>
        deps.notifier.notify({
          id: `move_reverted_${after.id}_${mover}_${after.parentId}`,
          toUid: mover,
          type: "move_reverted",
          itemId: after.id,
          ...m,
        })
      );
    }
    return "move_reverted";
  }

  // 2) Reenvio após devolução
  const resubmitted =
    before.status === "returned" &&
    after.status === "in_review" &&
    after.version === before.version + 1;
  if (resubmitted) {
    // O evento pode ser reentregue ou atrasado: confere o item vivo antes de
    // apagar qualquer coisa e usa o storagePath vivo como keepPath.
    const live = await deps.db.getItem(after.id);
    if (
      !live ||
      live.status !== "in_review" ||
      live.version !== after.version
    ) {
      console.error(
        `Reenvio ignorado: item ${after.id} mudou desde o evento ` +
        `(versão do evento ${after.version}).`
      );
      return "none";
    }
    if (live.type === "file" && !live.storagePath) {
      // Sem keepPath a limpeza apagaria também o arquivo atual.
      console.error(
        `Reenvio de arquivo sem storagePath: item ${after.id}; ` +
        "limpeza do Storage ignorada."
      );
    } else {
      await deps.storage.deleteItemFiles(after.id, live.storagePath);
    }
    // Campos só das Functions: o cliente não consegue limpá-los.
    await deps.db.updateItem(after.id, {
      returnComment: null,
      returnedBy: null,
    });
    await notifyCurators(
      deps,
      after,
      after.authorId,
      "review_requested",
      `${after.id}_v${after.version}`,
      msg.reviewRequestedMessage(after, true)
    );
    await safely("auditar reenvio", () =>
      deps.audit.record({
        id: `resubmitted_${after.id}_v${after.version}`,
        action: "resubmitted",
        itemId: after.id,
        itemName: after.name,
        actors: [after.authorId],
      })
    );
    return "resubmitted";
  }

  // 3) Pedido de exclusão aberto
  const opened = !before.deleteRequest && !!after.deleteRequest;
  if (opened && after.deleteRequest) {
    const request = after.deleteRequest;
    if (after.type === "folder") {
      const subtree = await collectSubtree(deps.db, after);
      if (!hasDocuments(subtree)) {
        const valid = await deps.roles.currentCuratorIds([
          request.requestedBy,
        ]);
        if (!valid.has(request.requestedBy)) {
          console.error(
            `Pedido de exclusão de ${after.id} ignorado: ` +
            `${request.requestedBy} não é mais curador.`
          );
          await deps.db.updateItem(after.id, {
            deleteRequest: null,
            deleteRequested: false,
          });
          return "none";
        }
        await safely("auditar exclusão de pasta vazia", () =>
          deps.audit.record({
            id: `deleted_empty_folder_${after.id}_${request.id}`,
            action: "deleted_empty_folder",
            itemId: after.id,
            itemName: after.name,
            actors: [request.requestedBy],
          })
        );
        await deleteSubtree(deps, after);
        return "deleted_empty_folder";
      }
    }
    await notifyCurators(
      deps,
      after,
      request.requestedBy,
      "delete_requested",
      `${after.id}_${request.id}`,
      msg.deleteRequestedMessage(after)
    );
    await safely("auditar pedido de exclusão", () =>
      deps.audit.record({
        id: `delete_requested_${after.id}_${request.id}`,
        action: "delete_requested",
        itemId: after.id,
        itemName: after.name,
        actors: [request.requestedBy],
      })
    );
    return "delete_requested";
  }

  return "none";
}
