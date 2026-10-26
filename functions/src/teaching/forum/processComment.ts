import {NOTIFICATION_TITLE, SNIPPET_LENGTH} from "./constants";
import type {CommentData, ForumDeps} from "./types";

const snippet = (text: string): string =>
  text.length > SNIPPET_LENGTH ? `${text.slice(0, SNIPPET_LENGTH)}…` : text;

// Contadores são recalculados do zero (nunca incrementados): a retentativa do
// gatilho dá o mesmo resultado. A notificação tem id determinístico.
export const processCommentCreated = async (
  deps: ForumDeps,
  topicId: string,
  commentId: string
): Promise<void> => {
  const {db, notifier} = deps;
  const topic = await db.getTopic(topicId);
  if (!topic || topic.deleted) return;
  const comment = await db.getComment(topicId, commentId);
  if (!comment) return;

  await db.setTopicStats(topicId, {
    commentCount: await db.countActiveComments(topicId),
    lastActivityAt: comment.createdAt,
  });
  if (comment.deleted) return;

  const toUid = comment.parentId ?
    (await db.getComment(topicId, comment.parentId))?.authorUid :
    topic.authorUid;
  if (!toUid || toUid === comment.authorUid) return;
  await notifier.notify({
    id: `forum_reply_${commentId}`,
    toUid,
    title: NOTIFICATION_TITLE,
    body: `${comment.authorName}: ${snippet(comment.body)}`,
    topicId,
    commentId,
  });
};

export const processCommentUpdated = async (
  deps: ForumDeps,
  topicId: string,
  before: CommentData,
  after: CommentData
): Promise<void> => {
  if (before.deleted || !after.deleted) return;
  const topic = await deps.db.getTopic(topicId);
  if (!topic) return;
  await deps.db.setTopicStats(topicId, {
    commentCount: await deps.db.countActiveComments(topicId),
  });
};
