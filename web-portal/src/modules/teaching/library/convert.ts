import type {
  ItemStatus,
  ItemType,
  LibraryItem,
  LibraryNotification,
  LibraryVote,
  VoteAction,
} from "./types";

type Data = Record<string, unknown>;

const TYPES: ItemType[] = ["folder", "file", "link"];
const STATUSES: ItemStatus[] = ["active", "in_review", "returned", "published"];
const ACTIONS: VoteAction[] = [
  "approve",
  "reject",
  "return",
  "delete_approve",
  "delete_refuse",
];

function millis(value: unknown): number {
  const maybe = value as {toMillis?: () => number} | null | undefined;
  if (maybe && typeof maybe.toMillis === "function") return maybe.toMillis();
  return typeof value === "number" ? value : 0;
}

const str = (value: unknown): string | undefined =>
  typeof value === "string" ? value : undefined;

const strings = (value: unknown): string[] =>
  Array.isArray(value) ? value.filter((v): v is string => typeof v === "string") : [];

export function toItem(id: string, data: Data): LibraryItem | null {
  const type = data.type as ItemType;
  const status = data.status as ItemStatus;
  if (!TYPES.includes(type) || !STATUSES.includes(status)) return null;

  const raw = data.deleteRequest as Data | null | undefined;
  const request = raw ?
    {
      id: String(raw.id),
      requestedBy: String(raw.requestedBy),
      requestedAt: millis(raw.requestedAt),
      reason: str(raw.reason),
    } :
    null;
  const deleting = data.deleting;
  return {
    id,
    type,
    name: str(data.name) ?? "",
    parentId: typeof data.parentId === "string" ? data.parentId : null,
    authorId: str(data.authorId) ?? "",
    status,
    version: typeof data.version === "number" ? data.version : 1,
    updatedBy: str(data.updatedBy),
    fileName: str(data.fileName),
    contentType: str(data.contentType),
    size: typeof data.size === "number" ? data.size : undefined,
    storagePath: str(data.storagePath),
    url: str(data.url),
    description: str(data.description),
    typeTags: strings(data.typeTags),
    subjectTags: strings(data.subjectTags),
    ageTags: strings(data.ageTags),
    searchTokens: Array.isArray(data.searchTokens) ? strings(data.searchTokens) : undefined,
    publishedAt: data.publishedAt ? millis(data.publishedAt) : undefined,
    returnComment: str(data.returnComment) ?? null,
    returnedBy: str(data.returnedBy) ?? null,
    deleteRequest: request,
    deleting: deleting === "reject" || deleting === "execute" ? deleting : null,
    createdAt: data.createdAt === undefined ? undefined : millis(data.createdAt),
  };
}

export function toVote(id: string, data: Data): LibraryVote | null {
  const action = data.action as VoteAction;
  const voterId = str(data.voterId);
  if (!voterId || !ACTIONS.includes(action)) return null;
  return {
    id,
    voterId,
    action,
    version: typeof data.version === "number" ? data.version : undefined,
    requestId: str(data.requestId),
    comment: str(data.comment),
    createdAt: millis(data.createdAt),
  };
}

export function toNotification(id: string, data: Data): LibraryNotification | null {
  const toUid = str(data.toUid);
  const itemId = str(data.itemId) ?? "";
  const topicId = str(data.topicId);
  // Biblioteca traz itemId; resposta do Fórum (forum_reply) traz topicId.
  if (!toUid || (!itemId && !topicId)) return null;
  return {
    id,
    toUid,
    type: str(data.type) ?? "",
    itemId,
    ...(topicId ? {topicId} : {}),
    title: str(data.title) ?? "",
    body: str(data.body) ?? "",
    createdAt: millis(data.createdAt),
    readAt: data.readAt ? millis(data.readAt) : null,
  };
}
