import type * as admin from "firebase-admin";
import type {ItemDoc, VoteAction, VoteDoc} from "./types";

type Snap = admin.firestore.DocumentSnapshot;

function millis(value: unknown): number {
  const maybe = value as {toMillis?: () => number} | null | undefined;
  if (maybe && typeof maybe.toMillis === "function") return maybe.toMillis();
  return typeof value === "number" ? value : 0;
}

export function toItem(snap: Snap): ItemDoc {
  const d = snap.data() ?? {};
  const raw = d.deleteRequest;
  const request = raw ?
    {
      id: String(raw.id),
      requestedBy: String(raw.requestedBy),
      requestedAt: millis(raw.requestedAt),
      reason: raw.reason as string | undefined,
    } :
    null;
  return {
    id: snap.id,
    type: d.type,
    name: d.name,
    parentId: d.parentId ?? null,
    authorId: d.authorId,
    status: d.status,
    version: d.version ?? 1,
    updatedBy: d.updatedBy,
    storagePath: d.storagePath,
    typeTags: Array.isArray(d.typeTags) ? d.typeTags : [],
    subjectTags: Array.isArray(d.subjectTags) ? d.subjectTags : [],
    ageTags: Array.isArray(d.ageTags) ? d.ageTags : [],
    deleteRequest: request,
    returnComment: d.returnComment ?? null,
    returnedBy: d.returnedBy ?? null,
    deleting: d.deleting ?? null,
  };
}

export function toVote(snap: Snap): VoteDoc {
  const d = snap.data() ?? {};
  return {
    id: snap.id,
    voterId: d.voterId,
    action: d.action as VoteAction,
    version: d.version,
    requestId: d.requestId,
    comment: d.comment,
    createdAt: millis(d.createdAt),
  };
}
