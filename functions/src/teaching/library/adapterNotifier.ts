import * as admin from "firebase-admin";
import {
  AUDIT_COLLECTION,
  NOTIFICATION_PREFERENCE,
  NOTIFICATIONS_COLLECTION,
  PORTAL_URL,
} from "./constants";
import type {AuditLog, NotificationInput, Notifier} from "./types";

type Firestore = admin.firestore.Firestore;

export interface MessagingLike {
  send(message: admin.messaging.Message): Promise<string>;
}

const ALREADY_EXISTS = 6;

async function push(
  firestore: Firestore,
  messaging: MessagingLike,
  n: NotificationInput
): Promise<void> {
  try {
    const user = await firestore.collection("users").doc(n.toUid).get();
    const data = user.data();
    const token = data?.fcmToken;
    const disabled: string[] = data?.disabled_notifications ?? [];
    if (!token || disabled.includes(NOTIFICATION_PREFERENCE)) return;
    await messaging.send({
      token,
      notification: {title: n.title, body: n.body},
      data: {
        type: NOTIFICATION_PREFERENCE,
        itemId: n.itemId,
        url: `${PORTAL_URL}/ensino/biblioteca?item=${n.itemId}`,
      },
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default", badge: 1}}},
    });
  } catch (error) {
    console.error("Falha ao enviar push da biblioteca:", error);
  }
}

// Cria o documento só se ainda não existe; o push só sai na primeira criação.
export function createFirestoreNotifier(
  firestore: Firestore,
  messaging: MessagingLike
): Notifier {
  return {
    async notify(n) {
      const ref = firestore.collection(NOTIFICATIONS_COLLECTION).doc(n.id);
      try {
        await ref.create({
          toUid: n.toUid,
          type: n.type,
          itemId: n.itemId,
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
  };
}

export function createFirestoreAudit(firestore: Firestore): AuditLog {
  return {
    async record(entry) {
      await firestore.collection(AUDIT_COLLECTION).doc(entry.id).set({
        action: entry.action,
        itemId: entry.itemId,
        itemName: entry.itemName,
        actors: entry.actors,
        at: admin.firestore.FieldValue.serverTimestamp(),
      });
    },
  };
}
