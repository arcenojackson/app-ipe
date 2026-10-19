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
import {contentTypeFor, storagePathFor, validateFile} from "./files";
import {
  cancelDeletePayload,
  deleteRequestPayload,
  movePayload,
  newFolderPayload,
  newLinkPayload,
  renamePayload,
  resubmitFilePayload,
  resubmitLinkPayload,
  voteCommentError,
  votePayload,
} from "./payloads";
import {UploadError, uploadFileItem} from "./uploadFlow";
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

export async function createFolder(
  uid: string,
  name: string,
  parentId: string | null
): Promise<string> {
  const id = doc(collection(db, "teaching_items")).id;
  await setDoc(itemRef(id), newFolderPayload({uid, name, parentId}, serverTimestamp()));
  return id;
}

export async function createLink(
  uid: string,
  input: {name: string; parentId: string | null; url: string; description?: string}
): Promise<string> {
  const id = doc(collection(db, "teaching_items")).id;
  await setDoc(itemRef(id), newLinkPayload({uid, ...input}, serverTimestamp()));
  return id;
}

export function uploadFile(
  uid: string,
  parentId: string | null,
  file: File,
  onProgress?: (fraction: number) => void,
  name?: string
): Promise<string> {
  return uploadFileItem<File>(
    {
      newId: () => doc(collection(db, "teaching_items")).id,
      now: () => serverTimestamp(),
      uploadObject,
      createItem: (id, payload) => setDoc(itemRef(id), payload),
    },
    {uid, parentId, file, name, onProgress}
  );
}

export async function renameItem(uid: string, id: string, name: string): Promise<void> {
  await updateDoc(itemRef(id), renamePayload({uid, name}, serverTimestamp()));
}

export async function moveItem(uid: string, id: string, parentId: string | null): Promise<void> {
  await updateDoc(itemRef(id), movePayload({uid, parentId}, serverTimestamp()));
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

// Reenvio de arquivo devolvido: novo objeto no Storage, depois o documento.
export async function resubmitFile(
  uid: string,
  item: LibraryItem,
  file: File,
  onProgress?: (fraction: number) => void
): Promise<void> {
  const problem = validateFile(file);
  if (problem) throw new UploadError("validate", problem);
  const contentType = contentTypeFor(file);
  const nextVersion = item.version + 1;
  try {
    await uploadObject(storagePathFor(item.id, nextVersion, file.name), file, contentType, onProgress ?? (() => undefined));
  } catch {
    throw new UploadError("upload", "Não foi possível enviar o arquivo. Tente novamente.");
  }
  try {
    await updateDoc(
      itemRef(item.id),
      resubmitFilePayload(
        {uid, itemId: item.id, currentVersion: item.version, fileName: file.name, contentType, size: file.size},
        serverTimestamp()
      )
    );
  } catch {
    throw new UploadError("create", "O arquivo foi enviado, mas não foi possível reenviar o item. Tente novamente.");
  }
}

export async function resubmitLink(
  uid: string,
  item: LibraryItem,
  input: {url: string; name?: string; description?: string}
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
