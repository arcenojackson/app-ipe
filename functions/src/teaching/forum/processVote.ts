import type {ForumDeps} from "./types";

// Soma a subcoleção de votos em vez de aplicar delta: idempotente.
export const processVoteWritten = async (
  deps: ForumDeps,
  topicId: string,
  commentId: string
): Promise<void> => {
  const comment = await deps.db.getComment(topicId, commentId);
  if (!comment) return;
  await deps.db.setCommentScore(
    topicId,
    commentId,
    await deps.db.sumVotes(topicId, commentId)
  );
};
