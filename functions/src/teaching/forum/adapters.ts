import * as admin from "firebase-admin";
import {
  COMMENTS_SUBCOLLECTION,
  NOTIFICATION_PREFERENCE,
  NOTIFICATION_TYPE,
  NOTIFICATIONS_COLLECTION,
  PORTAL_URL,
  TOPICS_COLLECTION,
  VOTES_SUBCOLLECTION,
} from "./constants";
import type {ForumDb, ForumNotification, ForumNotifier} from "./types";

type Firestore = admin.firestore.Firestore;

export interface MessagingLike {
  send(message: admin.messaging.Message): Promise<string>;
}

const ALREADY_EXISTS = 6;

export const createForumDb = (firestore: Firestore): ForumDb => {
  const topic = (id: string) =>
    firestore.collection(TOPICS_COLLECTION).doc(id);
  const comments = (topicId: string) =>
    topic(topicId).collection(COMMENTS_SUBCOLLECTION);
  return {
    async getTopic(topicId) {
      const data = (await topic(topicId).get()).data();
      if (!data) return null;
      return {
        authorUid: String(data.authorUid ?? ""),
        title: String(data.title ?? ""),
        deleted: data.deleted === true,
      };
    },
    async getComment(topicId, commentId) {
      const data = (await comments(topicId).doc(commentId).get()).data();
      if (!data) return null;
      const createdAt = data.createdAt as admin.firestore.Timestamp | undefined;
      return {
        authorUid: String(data.authorUid ?? ""),
        authorName: String(data.authorName ?? ""),
        parentId: typeof data.parentId === "string" ? data.parentId : null,
        body: String(data.body ?? ""),
        deleted: data.deleted === true,
        createdAt: createdAt ? createdAt.toDate() : new Date(),
      };
    },
    async countActiveComments(topicId) {
      const snapshot = await comments(topicId)
        .where("deleted", "==", false).count().get();
      return snapshot.data().count;
    },
    async sumVotes(topicId, commentId) {
      const snapshot = await comments(topicId).doc(commentId)
        .collection(VOTES_SUBCOLLECTION)
        .aggregate({total: admin.firestore.AggregateField.sum("value")})
        .get();
      return snapshot.data().total ?? 0;
    },
    async setTopicStats(topicId, stats) {
      const patch: Record<string, unknown> = {commentCount: stats.commentCount};
      if (stats.lastActivityAt) {
        // Nunca volta no tempo (retentativa tardia de comentário antigo).
        const current = (await topic(topicId).get())
          .get("lastActivityAt") as admin.firestore.Timestamp | undefined;
        if (!current || current.toDate() < stats.lastActivityAt) {
          patch.lastActivityAt =
            admin.firestore.Timestamp.fromDate(stats.lastActivityAt);
        }
      }
      await topic(topicId).update(patch);
    },
    async setCommentScore(topicId, commentId, score) {
      await comments(topicId).doc(commentId).update({score});
    },
  };
};

const push = async (
  firestore: Firestore,
  messaging: MessagingLike,
  n: ForumNotification
): Promise<void> => {
  try {
    const data = (await firestore.collection("users").doc(n.toUid).get())
      .data();
    const token = data?.fcmToken;
    const disabled: string[] = data?.disabled_notifications ?? [];
    if (!token || disabled.includes(NOTIFICATION_PREFERENCE)) return;
    await messaging.send({
      token,
      notification: {title: n.title, body: n.body},
      data: {
        type: NOTIFICATION_PREFERENCE,
        topicId: n.topicId,
        url: `${PORTAL_URL}/ensino/forum/${n.topicId}`,
      },
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default", badge: 1}}},
    });
  } catch (error) {
    console.error("Falha ao enviar push do fórum:", error);
  }
};

// Cria o documento só se ainda não existe; o push só sai na primeira criação.
export const createForumNotifier = (
  firestore: Firestore,
  messaging: MessagingLike
): ForumNotifier => ({
  async notify(n) {
    const ref = firestore.collection(NOTIFICATIONS_COLLECTION).doc(n.id);
    try {
      await ref.create({
        toUid: n.toUid,
        type: NOTIFICATION_TYPE,
        itemId: "",
        topicId: n.topicId,
        commentId: n.commentId,
        title: n.title,
        body: n.body,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        readAt: null,
      });
    } catch (error) {
      if ((error as {code?: number}).code === ALREADY_EXISTS) return;
      throw error;
    }
    await push(firestore, messaging, n);
  },
});
