import * as admin from "firebase-admin";
import {beforeAll, beforeEach, describe, expect, it} from "vitest";
import {
  createFirestoreAudit,
  createFirestoreNotifier,
} from "../src/teaching/library/adapterNotifier";

let firestore: admin.firestore.Firestore;

beforeAll(() => {
  if (admin.apps.length === 0) admin.initializeApp({projectId: "demo-ipe-rules"});
  firestore = admin.firestore();
});

beforeEach(async () => {
  await firestore.recursiveDelete(firestore.collection("teaching_notifications"));
  await firestore.recursiveDelete(firestore.collection("users"));
  await firestore.recursiveDelete(firestore.collection("teaching_log"));
});

const notification = {
  id: "published_i1_v1_t1", toUid: "t1", type: "published", itemId: "i1",
  title: "Material publicado", body: "\"Aula\" foi aprovado.",
};

function fakeMessaging() {
  const sent: admin.messaging.Message[] = [];
  return {sent, send: async (message: admin.messaging.Message) => {
    sent.push(message);
    return "id";
  }};
}

describe("createFirestoreNotifier", () => {
  it("grava a notificação e envia push com a URL do item", async () => {
    await firestore.doc("users/t1").set({fcmToken: "tok-1"});
    const messaging = fakeMessaging();
    await createFirestoreNotifier(firestore, messaging).notify(notification);
    const saved = (await firestore.doc("teaching_notifications/published_i1_v1_t1").get()).data()!;
    expect(saved).toMatchObject({toUid: "t1", type: "published", itemId: "i1", title: "Material publicado", readAt: null});
    expect(messaging.sent).toHaveLength(1);
    expect(messaging.sent[0]).toMatchObject({
      token: "tok-1",
      notification: {title: "Material publicado", body: "\"Aula\" foi aprovado."},
      data: {type: "teaching_review", itemId: "i1", url: "https://ipe-ensino.vercel.app/ensino/biblioteca?item=i1"},
    });
  });

  it("repetir o mesmo id não duplica documento nem push", async () => {
    await firestore.doc("users/t1").set({fcmToken: "tok-1"});
    const messaging = fakeMessaging();
    const notifier = createFirestoreNotifier(firestore, messaging);
    await notifier.notify(notification);
    await notifier.notify(notification);
    expect(messaging.sent).toHaveLength(1);
    expect((await firestore.collection("teaching_notifications").get()).size).toBe(1);
  });

  it("preferência desligada ou sem token: grava o documento e não envia push", async () => {
    await firestore.doc("users/t1").set({fcmToken: "tok-1", disabled_notifications: ["teaching_review"]});
    const messaging = fakeMessaging();
    await createFirestoreNotifier(firestore, messaging).notify(notification);
    await createFirestoreNotifier(firestore, messaging).notify({...notification, id: "x2", toUid: "sem-usuario"});
    expect(messaging.sent).toEqual([]);
    expect((await firestore.collection("teaching_notifications").get()).size).toBe(2);
  });

  it("erro no push não faz a notificação falhar", async () => {
    await firestore.doc("users/t1").set({fcmToken: "tok-1"});
    const notifier = createFirestoreNotifier(firestore, {send: async () => {
      throw new Error("token inválido");
    }});
    await expect(notifier.notify(notification)).resolves.toBeUndefined();
  });
});

describe("createFirestoreAudit", () => {
  it("grava a entrada com id determinístico e é idempotente", async () => {
    const audit = createFirestoreAudit(firestore);
    const entry = {id: "published_i1_v1", action: "published", itemId: "i1", itemName: "Aula", actors: ["c1", "c2"]};
    await audit.record(entry);
    await audit.record(entry);
    const snap = await firestore.collection("teaching_log").get();
    expect(snap.size).toBe(1);
    expect(snap.docs[0].data()).toMatchObject({action: "published", itemId: "i1", itemName: "Aula", actors: ["c1", "c2"]});
    expect(snap.docs[0].data().at).toBeDefined();
  });
});
