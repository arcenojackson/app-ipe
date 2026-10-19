import {
  collection,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  query,
  where,
  type DocumentData,
  type QuerySnapshot,
} from "firebase/firestore";
import {db} from "@/core/firebase/client";
import {toItem, toVote} from "./convert";
import {mergeById} from "./merge";
import type {LibraryItem, LibraryVote, Viewer} from "./types";

const items = () => collection(db, "teaching_items");

function itemsFrom(snapshot: QuerySnapshot<DocumentData>): LibraryItem[] {
  return snapshot.docs
    .map((d) => toItem(d.id, d.data()))
    .filter((item): item is LibraryItem => item !== null);
}

// Curador e admin leem tudo; professor precisa de filtros que provem a regra:
// publicado, ativo (pastas) e os próprios envios da pasta.
function folderQueries(folderId: string | null, viewer: Viewer) {
  if (viewer.isCurator || viewer.isAdmin) {
    return [query(items(), where("parentId", "==", folderId))];
  }
  return [
    query(items(), where("parentId", "==", folderId), where("status", "==", "published")),
    query(items(), where("parentId", "==", folderId), where("status", "==", "active")),
    query(items(), where("parentId", "==", folderId), where("authorId", "==", viewer.uid)),
  ];
}

export function subscribeFolder(
  folderId: string | null,
  viewer: Viewer,
  onData: (items: LibraryItem[]) => void,
  onError: (error: Error) => void
): () => void {
  const queries = folderQueries(folderId, viewer);
  const latest: Array<LibraryItem[] | undefined> = queries.map(() => undefined);
  let active = true;
  const unsubscribers = queries.map((q, index) =>
    onSnapshot(
      q,
      (snapshot) => {
        if (!active) return;
        latest[index] = itemsFrom(snapshot);
        if (latest.every((list) => list !== undefined)) {
          onData(mergeById(latest as LibraryItem[][]));
        }
      },
      (error) => active && onError(error)
    )
  );
  return () => {
    active = false;
    unsubscribers.forEach((stop) => stop());
  };
}

// Todos os itens que o espectador pode ver (busca por nome e migalhas).
export async function loadAllVisible(viewer: Viewer): Promise<LibraryItem[]> {
  if (viewer.isCurator || viewer.isAdmin) {
    return itemsFrom(await getDocs(items()));
  }
  const snapshots = await Promise.all([
    getDocs(query(items(), where("status", "==", "published"))),
    getDocs(query(items(), where("status", "==", "active"))),
    getDocs(query(items(), where("authorId", "==", viewer.uid))),
  ]);
  return mergeById(snapshots.map(itemsFrom));
}

export function subscribeItem(
  id: string,
  onData: (item: LibraryItem | null) => void,
  onError: (error: Error) => void
): () => void {
  return onSnapshot(
    doc(db, "teaching_items", id),
    (snapshot) => onData(snapshot.exists() ? toItem(snapshot.id, snapshot.data()) : null),
    onError
  );
}

export function canReadVotes(item: LibraryItem, viewer: Viewer): boolean {
  return viewer.isCurator || viewer.isAdmin || item.authorId === viewer.uid;
}

export function subscribeVotes(
  itemId: string,
  onData: (votes: LibraryVote[]) => void,
  onError: (error: Error) => void
): () => void {
  return onSnapshot(
    collection(db, "teaching_items", itemId, "votes"),
    (snapshot) =>
      onData(
        snapshot.docs
          .map((d) => toVote(d.id, d.data()))
          .filter((vote): vote is LibraryVote => vote !== null)
      ),
    onError
  );
}

const nameCache = new Map<string, string>();

// Nome de exibição dos votantes (users/{uid} é legível por quem está logado).
export async function loadUserNames(uids: string[]): Promise<Record<string, string>> {
  const result: Record<string, string> = {};
  await Promise.all(
    [...new Set(uids)].map(async (uid) => {
      if (!nameCache.has(uid)) {
        try {
          const snapshot = await getDoc(doc(db, "users", uid));
          const name = snapshot.data()?.name;
          nameCache.set(uid, typeof name === "string" && name ? name : "Curador");
        } catch {
          nameCache.set(uid, "Curador");
        }
      }
      result[uid] = nameCache.get(uid) as string;
    })
  );
  return result;
}

// Fila de revisão (curador e admin): em revisão e pedidos de exclusão.
export async function loadReviewQueue(): Promise<{
  inReview: LibraryItem[];
  deleteRequests: LibraryItem[];
}> {
  const [review, deletes] = await Promise.all([
    getDocs(query(items(), where("status", "==", "in_review"))),
    getDocs(query(items(), where("deleteRequested", "==", true))),
  ]);
  return {inReview: itemsFrom(review), deleteRequests: itemsFrom(deletes)};
}
