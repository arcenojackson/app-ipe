// Gatilhos finos: a lógica é testada em processComment.ts e processVote.ts
// com portas em memória. A fiação só é exercitada em produção.
import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {createForumDb, createForumNotifier} from "./adapters";
import {processCommentCreated, processCommentUpdated} from "./processComment";
import {processVoteWritten} from "./processVote";
import type {CommentData, ForumDeps} from "./types";

// Retentativa ligada: tudo é recalculado do zero, então é idempotente.
const base = functions.runWith({failurePolicy: true});

// Criado dentro do gatilho: o admin.initializeApp() do index.ts já rodou.
const buildDeps = (): ForumDeps => {
  const firestore = admin.firestore();
  return {
    db: createForumDb(firestore),
    notifier: createForumNotifier(firestore, admin.messaging()),
  };
};

const toCommentData = (
  data: FirebaseFirestore.DocumentData
): CommentData => ({
  authorUid: String(data.authorUid ?? ""),
  authorName: String(data.authorName ?? ""),
  parentId: typeof data.parentId === "string" ? data.parentId : null,
  body: String(data.body ?? ""),
  deleted: data.deleted === true,
  createdAt: data.createdAt?.toDate?.() ?? new Date(),
});

export const onForumCommentCreated = base.firestore
  .document("forum_topics/{topicId}/comments/{commentId}")
  .onCreate(async (_snapshot, context) => {
    const {topicId, commentId} = context.params;
    await processCommentCreated(buildDeps(), topicId, commentId);
    return null;
  });

export const onForumCommentUpdated = base.firestore
  .document("forum_topics/{topicId}/comments/{commentId}")
  .onUpdate(async (change, context) => {
    await processCommentUpdated(
      buildDeps(),
      context.params.topicId,
      toCommentData(change.before.data()),
      toCommentData(change.after.data())
    );
    return null;
  });

export const onForumVoteWritten = base.firestore
  .document("forum_topics/{topicId}/comments/{commentId}/votes/{voterId}")
  .onWrite(async (_change, context) => {
    const {topicId, commentId} = context.params;
    await processVoteWritten(buildDeps(), topicId, commentId);
    return null;
  });
