import {
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  onSnapshot,
  orderBy,
  query,
  startAfter,
  where,
  type DocumentData,
  type Query,
  type QueryConstraint,
  type QueryDocumentSnapshot,
  type QuerySnapshot,
} from "firebase/firestore";
import {db} from "@/core/firebase/client";
import {toItem, toVote} from "./convert";
import {collectPage, planQuery, type Batch, type LibraryFilters} from "./libraryQuery";
import {buildReviewQueue, type ReviewQueue} from "./reviewQueue";
import type {LibraryItem, LibraryVote, Viewer} from "./types";

const items = () => collection(db, "teaching_items");

function itemsFrom(snapshot: QuerySnapshot<DocumentData>): LibraryItem[] {
  return snapshot.docs
    .map((d) => toItem(d.id, d.data()))
    .filter((item): item is LibraryItem => item !== null);
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

export async function loadVotes(itemId: string): Promise<LibraryVote[]> {
  const snapshot = await getDocs(collection(db, "teaching_items", itemId, "votes"));
  return snapshot.docs
    .map((d) => toVote(d.id, d.data()))
    .filter((vote): vote is LibraryVote => vote !== null);
}

// Curadores = usuários com teaching_role == "curator" (users é legível por
// quem está logado). A Function confere o papel no Auth ao contar votos.
export async function countCurators(): Promise<number> {
  const snapshot = await getDocs(
    query(collection(db, "users"), where("teaching_role", "==", "curator"))
  );
  return snapshot.size;
}

// Fila de revisão ao vivo. Todos veem os próprios envios em revisão/devolvidos;
// curador e admin também veem o que aguarda revisão e os pedidos de exclusão.
// O primeiro erro é terminal (o Firestore já encerrou aquela escuta).
export function subscribeReviewQueue(
  viewer: Viewer,
  onData: (queue: ReviewQueue) => void,
  onError: (error: Error) => void
): () => void {
  const privileged = viewer.isCurator || viewer.isAdmin;
  const sources: Array<{key: "mine" | "inReview" | "deleteRequested"; q: Query<DocumentData>}> = [
    {key: "mine", q: query(items(), where("authorId", "==", viewer.uid), where("status", "in", ["in_review", "returned"]))},
  ];
  if (privileged) {
    sources.push(
      {key: "inReview", q: query(items(), where("status", "==", "in_review"))},
      {key: "deleteRequested", q: query(items(), where("deleteRequested", "==", true))}
    );
  }
  const latest: Partial<Record<"mine" | "inReview" | "deleteRequested", LibraryItem[]>> = {};
  let active = true;
  const stops = sources.map(({key, q}) =>
    onSnapshot(
      q,
      (snapshot) => {
        if (!active) return;
        latest[key] = itemsFrom(snapshot);
        if (sources.every((s) => latest[s.key] !== undefined)) {
          onData(
            buildReviewQueue(viewer, {
              mine: latest.mine ?? [],
              inReview: latest.inReview ?? [],
              deleteRequested: latest.deleteRequested ?? [],
            })
          );
        }
      },
      (error) => active && onError(error)
    )
  );
  return () => {
    active = false;
    stops.forEach((stop) => stop());
  };
}

export type LibraryCursor = QueryDocumentSnapshot<DocumentData>;

// Biblioteca: só itens publicados, do mais novo ao mais antigo. Um filtro de
// servidor (ver planQuery) mais o filtro completo no cliente, com paginação
// por cursor. Índices em firestore.indexes.json.
export async function loadLibraryPage(
  filters: LibraryFilters,
  after: LibraryCursor | null,
  pageSize = 20
): Promise<{items: LibraryItem[]; cursor: LibraryCursor | null; done: boolean}> {
  const plan = planQuery(filters);
  const fetchBatch = async (cursor: LibraryCursor | null, size: number): Promise<Batch<LibraryCursor>> => {
    const constraints: QueryConstraint[] = [where("status", "==", "published")];
    if (plan.server) {
      const {field, op, values} = plan.server;
      constraints.push(where(field, op, op === "array-contains" ? values[0] : values));
    }
    constraints.push(orderBy("publishedAt", "desc"));
    if (cursor) constraints.push(startAfter(cursor));
    constraints.push(limit(size));
    const snapshot = await getDocs(query(items(), ...constraints));
    const entries = snapshot.docs.flatMap((d) => {
      const item = toItem(d.id, d.data());
      return item ? [{item, cursor: d}] : [];
    });
    return {items: entries, exhausted: snapshot.docs.length < size};
  };
  return collectPage(fetchBatch, plan.matches, after, pageSize);
}
