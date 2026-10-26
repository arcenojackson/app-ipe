import type {Comment} from "./types";

export interface CommentNodeData {
  comment: Comment;
  children: CommentNodeData[];
}

// Árvore por parentId, do mais antigo ao mais novo. Comentário cujo pai não
// veio na lista sobe para a raiz (não some).
export function buildTree(comments: Comment[]): CommentNodeData[] {
  const sorted = [...comments].sort((a, b) => a.createdAt - b.createdAt);
  const nodes = new Map<string, CommentNodeData>(
    sorted.map((comment) => [comment.id, {comment, children: []}])
  );
  const roots: CommentNodeData[] = [];
  for (const comment of sorted) {
    const node = nodes.get(comment.id)!;
    const parent = comment.parentId ? nodes.get(comment.parentId) : undefined;
    (parent ? parent.children : roots).push(node);
  }
  return roots;
}
