import {
  collection,
  doc,
  onSnapshot,
  query,
  serverTimestamp,
  updateDoc,
  where,
} from "firebase/firestore";
import {db} from "@/core/firebase/client";
import {toNotification} from "./convert";
import type {LibraryNotification} from "./types";

const MAX_NOTIFICATIONS = 100;

// Sem orderBy (evita índice composto): ordena e limita no cliente.
export function subscribeNotifications(
  uid: string,
  onData: (list: LibraryNotification[]) => void,
  onError: (error: Error) => void
): () => void {
  return onSnapshot(
    query(collection(db, "teaching_notifications"), where("toUid", "==", uid)),
    (snapshot) => {
      const list = snapshot.docs
        .map((d) => toNotification(d.id, d.data()))
        .filter((n): n is LibraryNotification => n !== null)
        .sort((a, b) => b.createdAt - a.createdAt)
        .slice(0, MAX_NOTIFICATIONS);
      onData(list);
    },
    onError
  );
}

export async function markRead(id: string): Promise<void> {
  await updateDoc(doc(db, "teaching_notifications", id), {readAt: serverTimestamp()});
}

export async function markAllRead(ids: string[]): Promise<void> {
  await Promise.all(ids.map((id) => markRead(id)));
}
