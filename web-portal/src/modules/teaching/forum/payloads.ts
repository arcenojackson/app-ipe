import {searchTokens} from "../library/searchTokens";
import {LIMITS} from "./types";
import type {Author, Comment, CommentInput, TopicInput} from "./types";

const BODY_ERROR = `A mensagem deve ter de 1 a ${LIMITS.bodyMax} caracteres.`;

function validateBody(body: string, refCount: number): string | null {
  const size = body.trim().length;
  if (size < 1 || size > LIMITS.bodyMax) return BODY_ERROR;
  if (refCount > LIMITS.refs) return `Cite no máximo ${LIMITS.refs} itens.`;
  return null;
}

export function validateTopicInput(input: TopicInput): string | null {
  const size = input.title.trim().length;
  if (size < LIMITS.titleMin || size > LIMITS.titleMax) {
    return `O título deve ter de ${LIMITS.titleMin} a ${LIMITS.titleMax} caracteres.`;
  }
  if (input.tagIds.length > LIMITS.tags) return `Escolha no máximo ${LIMITS.tags} assuntos.`;
  return validateBody(input.body, input.refs.length);
}

export function validateCommentInput(input: CommentInput): string | null {
  return validateBody(input.body, input.refs.length);
}

// `ts` é o timestamp do servidor: as regras exigem createdAt == request.time.
export function newTopicPayload(
  input: TopicInput,
  author: Author,
  ts: unknown
): Record<string, unknown> {
  return {
    title: input.title.trim(),
    body: input.body.trim(),
    authorUid: author.uid,
    authorName: author.name,
    tagIds: input.tagIds,
    refs: input.refs,
    searchTokens: searchTokens(input.title),
    pinned: false,
    locked: false,
    deleted: false,
    commentCount: 0,
    createdAt: ts,
    updatedAt: ts,
    lastActivityAt: ts,
  };
}

export function newCommentPayload(
  input: CommentInput,
  author: Author,
  parent: Comment | null,
  ts: unknown
): Record<string, unknown> {
  if (parent && parent.depth >= LIMITS.maxDepth) {
    throw new Error("Respostas aceitam no máximo 3 níveis.");
  }
  return {
    body: input.body.trim(),
    authorUid: author.uid,
    authorName: author.name,
    parentId: parent ? parent.id : null,
    depth: parent ? parent.depth + 1 : 1,
    refs: input.refs,
    score: 0,
    deleted: false,
    createdAt: ts,
  };
}

export function topicEditPatch(input: TopicInput, ts: unknown): Record<string, unknown> {
  return {
    title: input.title.trim(),
    body: input.body.trim(),
    tagIds: input.tagIds,
    refs: input.refs,
    searchTokens: searchTokens(input.title),
    updatedAt: ts,
    editedAt: ts,
  };
}

export function commentEditPatch(input: CommentInput, ts: unknown): Record<string, unknown> {
  return {body: input.body.trim(), refs: input.refs, editedAt: ts};
}
