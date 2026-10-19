import {safeFileName, storagePathFor} from "./files";
import type {VoteAction} from "./types";

// `now` é o valor de serverTimestamp(), injetado para os construtores ficarem
// puros. Cada construtor produz exatamente os campos que as regras aceitam.

export function newFolderPayload(
  i: {uid: string; name: string; parentId: string | null},
  now: unknown
) {
  return {
    type: "folder",
    name: i.name.trim(),
    parentId: i.parentId,
    authorId: i.uid,
    updatedBy: i.uid,
    status: "active",
    version: 1,
    createdAt: now,
    updatedAt: now,
  };
}

export function newFilePayload(
  i: {
    uid: string;
    itemId: string;
    name: string;
    parentId: string | null;
    fileName: string;
    contentType: string;
    size: number;
  },
  now: unknown
) {
  return {
    type: "file",
    name: i.name.trim(),
    parentId: i.parentId,
    authorId: i.uid,
    updatedBy: i.uid,
    status: "in_review",
    version: 1,
    fileName: safeFileName(i.fileName),
    contentType: i.contentType,
    size: i.size,
    storagePath: storagePathFor(i.itemId, 1, i.fileName),
    createdAt: now,
    updatedAt: now,
  };
}

export function newLinkPayload(
  i: {
    uid: string;
    name: string;
    parentId: string | null;
    url: string;
    description?: string;
  },
  now: unknown
) {
  const description = i.description?.trim();
  return {
    type: "link",
    name: i.name.trim(),
    parentId: i.parentId,
    authorId: i.uid,
    updatedBy: i.uid,
    status: "in_review",
    version: 1,
    url: i.url.trim(),
    ...(description ? {description} : {}),
    createdAt: now,
    updatedAt: now,
  };
}

export function renamePayload(i: {uid: string; name: string}, now: unknown) {
  return {name: i.name.trim(), updatedBy: i.uid, updatedAt: now};
}

export function movePayload(
  i: {uid: string; parentId: string | null},
  now: unknown
) {
  return {parentId: i.parentId, updatedBy: i.uid, updatedAt: now};
}

export function deleteRequestPayload(
  i: {uid: string; requestId: string; reason?: string},
  now: unknown
) {
  const reason = i.reason?.trim();
  return {
    deleteRequested: true,
    deleteRequest: {
      id: i.requestId,
      requestedBy: i.uid,
      requestedAt: now,
      ...(reason ? {reason} : {}),
    },
    updatedBy: i.uid,
    updatedAt: now,
  };
}

export function cancelDeletePayload(i: {uid: string}, now: unknown) {
  return {
    deleteRequested: false,
    deleteRequest: null,
    updatedBy: i.uid,
    updatedAt: now,
  };
}

export function resubmitFilePayload(
  i: {
    uid: string;
    itemId: string;
    currentVersion: number;
    fileName: string;
    contentType: string;
    size: number;
    name?: string;
  },
  now: unknown
) {
  const version = i.currentVersion + 1;
  const name = i.name?.trim();
  return {
    status: "in_review",
    version,
    ...(name ? {name} : {}),
    fileName: safeFileName(i.fileName),
    contentType: i.contentType,
    size: i.size,
    storagePath: storagePathFor(i.itemId, version, i.fileName),
    updatedBy: i.uid,
    updatedAt: now,
  };
}

export function resubmitLinkPayload(
  i: {
    uid: string;
    currentVersion: number;
    url: string;
    name?: string;
    description?: string;
  },
  now: unknown
) {
  const name = i.name?.trim();
  const description = i.description?.trim();
  return {
    status: "in_review",
    version: i.currentVersion + 1,
    ...(name ? {name} : {}),
    url: i.url.trim(),
    ...(description ? {description} : {}),
    updatedBy: i.uid,
    updatedAt: now,
  };
}

const DELETION_ACTIONS: VoteAction[] = ["delete_approve", "delete_refuse"];

export function voteCommentError(
  action: VoteAction,
  comment: string | undefined
): string | null {
  if (action === "approve" || action === "delete_approve") return null;
  const text = comment?.trim() ?? "";
  if (text.length === 0) return "Escreva um comentário.";
  if (text.length > 1000) return "O comentário pode ter no máximo 1000 caracteres.";
  return null;
}

export function votePayload(
  i: {
    uid: string;
    action: VoteAction;
    version?: number;
    requestId?: string;
    comment?: string;
  },
  now: unknown
) {
  const comment = i.comment?.trim();
  const isDeletion = DELETION_ACTIONS.includes(i.action);
  return {
    voterId: i.uid,
    action: i.action,
    ...(isDeletion ?
      {requestId: i.requestId} :
      {version: i.version}),
    ...(comment ? {comment} : {}),
    createdAt: now,
  };
}
