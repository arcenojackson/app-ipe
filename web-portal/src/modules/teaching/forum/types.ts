// Fórum de professores: tópicos (forum_topics/{id}), comentários
// (…/comments/{id}) e votos (…/comments/{id}/votes/{uid}).

export interface Ref {
  kind: "library" | "plan";
  id: string;
  label: string;
}

export interface Topic {
  id: string;
  title: string;
  body: string;
  authorUid: string;
  authorName: string;
  tagIds: string[];
  refs: Ref[];
  pinned: boolean;
  locked: boolean;
  deleted: boolean;
  createdAt: number;
  updatedAt: number;
  editedAt?: number;
  lastActivityAt: number;
  commentCount: number;
}

export type CommentDepth = 1 | 2 | 3;

export interface Comment {
  id: string;
  topicId: string;
  body: string;
  authorUid: string;
  authorName: string;
  parentId: string | null;
  depth: CommentDepth;
  refs: Ref[];
  score: number;
  deleted: boolean;
  createdAt: number;
  editedAt?: number;
}

export interface TopicInput {
  title: string;
  body: string;
  tagIds: string[];
  refs: Ref[];
}

export interface CommentInput {
  body: string;
  refs: Ref[];
}

export interface Author {
  uid: string;
  name: string;
}

export const LIMITS = {
  titleMin: 3,
  titleMax: 120,
  bodyMax: 5000,
  tags: 3,
  refs: 3,
  maxDepth: 3,
  maxPinned: 5,
  pageSize: 20,
  maxComments: 500,
} as const;
