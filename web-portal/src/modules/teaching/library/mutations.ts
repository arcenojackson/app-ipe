import {
  addDoc,
  collection,
  doc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from "firebase/firestore";
import {ref, uploadBytesResumable} from "firebase/storage";
import {db, storage} from "@/core/firebase/client";
import {
  cancelDeletePayload,
  deleteRequestPayload,
  newLinkPayload,
  editTagsPayload,
  renamePayload,
  resubmitLinkPayload,
  voteCommentError,
  votePayload,
} from "./payloads";
import {resubmitFileItem, uploadFileItem} from "./uploadFlow";
import type {ItemTags} from "./tags";
import type {LibraryItem, VoteAction} from "./types";

const itemRef = (id: string) => doc(db, "teaching_items", id);

function uploadObject(
  path: string,
  file: File,
  contentType: string,
  onProgress: (fraction: number) => void
): Promise<void> {
  return new Promise((resolve, reject) => {
    const task = uploadBytesResumable(ref(storage, path), file, {contentType});
    task.on(
      "state_changed",
      (snapshot) => onProgress(snapshot.totalBytes ? snapshot.bytesTransferred / snapshot.totalBytes : 0),
      reject,
      () => resolve()
    );
  });
}

export async function createLink(
  uid: string,
  input: {name: string; url: string; description?: string; tags: ItemTags}
): Promise<string> {
  const id = doc(collection(db, "teaching_items")).id;
  await setDoc(itemRef(id), newLinkPayload({uid, ...input}, serverTimestamp()));
  return id;
}

export function uploadFile(
  uid: string,
  file: File,
  options: {tags: ItemTags; name?: string; onProgress?: (fraction: number) => void}
): Promise<string> {
  return uploadFileItem<File>(
    {
      newId: () => doc(collection(db, "teaching_items")).id,
      now: () => serverTimestamp(),
      uploadObject,
      createItem: (id, payload) => setDoc(itemRef(id), payload),
    },
    {uid, file, tags: options.tags, name: options.name, onProgress: options.onProgress}
  );
}

export async function renameItem(uid: string, id: string, name: string): Promise<void> {
  await updateDoc(itemRef(id), renamePayload({uid, name}, serverTimestamp()));
}

export async function editTags(uid: string, id: string, tags: ItemTags): Promise<void> {
  await updateDoc(itemRef(id), editTagsPayload({uid, tags}, serverTimestamp()));
}

export async function requestDelete(uid: string, id: string, reason?: string): Promise<void> {
  await updateDoc(
    itemRef(id),
    deleteRequestPayload({uid, requestId: crypto.randomUUID(), reason}, serverTimestamp())
  );
}

export async function cancelDelete(uid: string, id: string): Promise<void> {
  await updateDoc(itemRef(id), cancelDeletePayload({uid}, serverTimestamp()));
}

// Reenvio de arquivo devolvido: novo objeto no Storage (caminho único por tentativa), depois o documento.
export function resubmitFile(
  uid: string,
  item: LibraryItem,
  file: File,
  onProgress?: (fraction: number) => void,
  tags?: ItemTags
): Promise<void> {
  return resubmitFileItem<File>(
    {
      newNonce: () => crypto.randomUUID().slice(0, 8),
      now: () => serverTimestamp(),
      uploadObject,
      updateItem: (id, payload) => updateDoc(itemRef(id), payload),
    },
    {uid, item, file, tags, onProgress}
  );
}

export async function resubmitLink(
  uid: string,
  item: LibraryItem,
  input: {url: string; name?: string; description?: string; tags?: ItemTags}
): Promise<void> {
  await updateDoc(
    itemRef(item.id),
    resubmitLinkPayload({uid, currentVersion: item.version, ...input}, serverTimestamp())
  );
}

export async function castVote(
  uid: string,
  item: LibraryItem,
  action: VoteAction,
  comment?: string
): Promise<void> {
  const problem = voteCommentError(action, comment);
  if (problem) throw new Error(problem);
  const isDeletion = action === "delete_approve" || action === "delete_refuse";
  await addDoc(
    collection(db, "teaching_items", item.id, "votes"),
    votePayload(
      {
        uid,
        action,
        comment,
        version: isDeletion ? undefined : item.version,
        requestId: isDeletion ? item.deleteRequest?.id : undefined,
      },
      serverTimestamp()
    )
  );
}
