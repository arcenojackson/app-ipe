import * as admin from "firebase-admin";
import {ITEMS_COLLECTION, VOTES_SUBCOLLECTION} from "./constants";
import {toItem, toVote} from "./convert";
import type {ItemPatch, LibraryDb, Tx} from "./types";

type Firestore = admin.firestore.Firestore;

// Remove undefined (o Firestore rejeita) e converte o pedido de exclusão.
function toWrite(patch: ItemPatch): Record<string, unknown> {
  const data: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(patch)) {
    if (value === undefined) continue;
    if (key === "deleteRequest" && value !== null) {
      const req = value as {requestedAt: number};
      data[key] = {
        ...req,
        requestedAt: admin.firestore.Timestamp.fromMillis(req.requestedAt),
      };
    } else if (key === "publishedAt") {
      data[key] = admin.firestore.FieldValue.serverTimestamp();
    } else {
      data[key] = value;
    }
  }
  data.updatedAt = admin.firestore.FieldValue.serverTimestamp();
  return data;
}

export function createAdminLibraryDb(firestore: Firestore): LibraryDb {
  const ref = (id: string) => firestore.collection(ITEMS_COLLECTION).doc(id);

  return {
    async getItem(id) {
      const snap = await ref(id).get();
      return snap.exists ? toItem(snap) : undefined;
    },

    async listChildren(parentId) {
      const snap = await firestore
        .collection(ITEMS_COLLECTION)
        .where("parentId", "==", parentId)
        .get();
      return snap.docs.map((doc) => toItem(doc));
    },

    async updateItem(id, patch) {
      await ref(id).update(toWrite(patch));
    },

    async deleteItem(id) {
      await firestore.recursiveDelete(ref(id));
    },

    async transact(fn) {
      return firestore.runTransaction(async (t) => {
        const writes: Array<[string, ItemPatch]> = [];
        const tx: Tx = {
          async getItem(id) {
            const snap = await t.get(ref(id));
            return snap.exists ? toItem(snap) : undefined;
          },
          async listVotes(itemId) {
            const snap = await t.get(
              ref(itemId).collection(VOTES_SUBCOLLECTION)
            );
            return snap.docs.map((doc) => toVote(doc));
          },
          updateItem(id, patch) {
            writes.push([id, patch]);
          },
        };
        const result = await fn(tx);
        for (const [id, patch] of writes) t.update(ref(id), toWrite(patch));
        return result;
      });
    },
  };
}
