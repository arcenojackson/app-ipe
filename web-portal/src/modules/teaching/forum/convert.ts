import type {Comment, CommentDepth, Ref, Topic} from "./types";

type Data = Record<string, unknown>;

function millis(value: unknown): number {
  const maybe = value as {toMillis?: () => number} | null | undefined;
  if (maybe && typeof maybe.toMillis === "function") return maybe.toMillis();
  return typeof value === "number" ? value : 0;
}

const optionalMillis = (value: unknown): number | undefined =>
  value ? millis(value) : undefined;

const strings = (value: unknown): string[] =>
  Array.isArray(value) ? value.filter((v): v is string => typeof v === "string") : [];

const refs = (value: unknown): Ref[] =>
  Array.isArray(value) ?
    value.filter(
      (r): r is Ref =>
        !!r &&
        (r.kind === "library" || r.kind === "plan") &&
        typeof r.id === "string" &&
        typeof r.label === "string"
    ).map((r) => ({kind: r.kind, id: r.id, label: r.label})) :
    [];

export function toTopic(id: string, data: Data): Topic | null {
  if (typeof data.title !== "string" || typeof data.body !== "string") return null;
  if (typeof data.authorUid !== "string") return null;
  return {
    id,
    title: data.title,
    body: data.body,
    authorUid: data.authorUid,
    authorName: typeof data.authorName === "string" ? data.authorName : "",
    tagIds: strings(data.tagIds),
    refs: refs(data.refs),
    pinned: data.pinned === true,
    locked: data.locked === true,
    deleted: data.deleted === true,
    createdAt: millis(data.createdAt),
    updatedAt: millis(data.updatedAt),
    editedAt: optionalMillis(data.editedAt),
    lastActivityAt: millis(data.lastActivityAt),
    commentCount: typeof data.commentCount === "number" ? data.commentCount : 0,
  };
}

export function toComment(topicId: string, id: string, data: Data): Comment | null {
  const depth = data.depth;
  if (typeof data.body !== "string" || typeof data.authorUid !== "string") return null;
  if (depth !== 1 && depth !== 2 && depth !== 3) return null;
  return {
    id,
    topicId,
    body: data.body,
    authorUid: data.authorUid,
    authorName: typeof data.authorName === "string" ? data.authorName : "",
    parentId: typeof data.parentId === "string" ? data.parentId : null,
    depth: depth as CommentDepth,
    refs: refs(data.refs),
    score: typeof data.score === "number" ? data.score : 0,
    deleted: data.deleted === true,
    createdAt: millis(data.createdAt),
    editedAt: optionalMillis(data.editedAt),
  };
}
