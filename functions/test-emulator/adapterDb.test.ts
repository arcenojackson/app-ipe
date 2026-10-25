import * as admin from "firebase-admin";
import {beforeAll, beforeEach, describe, expect, it} from "vitest";
import {createAdminLibraryDb} from "../src/teaching/library/adapterDb";

let firestore: admin.firestore.Firestore;

beforeAll(() => {
  if (admin.apps.length === 0) admin.initializeApp({projectId: "demo-ipe-rules"});
  firestore = admin.firestore();
});

beforeEach(async () => {
  await firestore.recursiveDelete(firestore.collection("teaching_items"));
});

const item = (id: string, extra: Record<string, unknown> = {}) => ({
  type: "file", name: id, parentId: null, authorId: "t1", status: "in_review", version: 1,
  ...extra,
});

describe("createAdminLibraryDb", () => {
  it("getItem converte campos, timestamps e valores ausentes", async () => {
    await firestore.doc("teaching_items/a").set(item("a", {
      deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: admin.firestore.Timestamp.fromMillis(1234), reason: "x"},
      storagePath: "teaching/materials/a/v1-a.pdf",
    }));
    const db = createAdminLibraryDb(firestore);
    expect(await db.getItem("a")).toEqual({
      id: "a", type: "file", name: "a", parentId: null, authorId: "t1", status: "in_review", version: 1,
      updatedBy: undefined, storagePath: "teaching/materials/a/v1-a.pdf",
      typeTags: [], subjectTags: [], ageTags: [],
      deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: 1234, reason: "x"},
      returnComment: null, returnedBy: null, deleting: null,
    });
    expect(await db.getItem("nao-existe")).toBeUndefined();
  });

  it("getItem lê o marcador deleting", async () => {
    await firestore.doc("teaching_items/a").set(item("a", {deleting: "execute"}));
    expect((await createAdminLibraryDb(firestore).getItem("a"))?.deleting).toBe("execute");
  });

  it("listChildren devolve só os filhos diretos", async () => {
    await firestore.doc("teaching_items/f").set(item("f", {type: "folder", status: "active"}));
    await firestore.doc("teaching_items/x").set(item("x", {parentId: "f"}));
    await firestore.doc("teaching_items/y").set(item("y", {parentId: "x"}));
    const db = createAdminLibraryDb(firestore);
    expect((await db.listChildren("f")).map((i) => i.id)).toEqual(["x"]);
  });

  it("updateItem ignora undefined e grava null e updatedAt", async () => {
    await firestore.doc("teaching_items/a").set(item("a", {deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: admin.firestore.Timestamp.now()}, deleteRequested: true}));
    const db = createAdminLibraryDb(firestore);
    await db.updateItem("a", {deleteRequest: null, deleteRequested: false, status: undefined});
    const data = (await firestore.doc("teaching_items/a").get()).data()!;
    expect(data.deleteRequest).toBeNull();
    expect(data.deleteRequested).toBe(false);
    expect(data.status).toBe("in_review");
    expect(data.updatedAt).toBeDefined();
  });

  it("publishedAt vira server timestamp, não o booleano", async () => {
    await firestore.doc("teaching_items/a").set(item("a"));
    const db = createAdminLibraryDb(firestore);
    await db.updateItem("a", {status: "published", publishedAt: true});
    const data = (await firestore.doc("teaching_items/a").get()).data()!;
    expect(data.publishedAt).toBeInstanceOf(admin.firestore.Timestamp);
  });

  it("transact lê antes e aplica as escritas no fim, com votos convertidos", async () => {
    await firestore.doc("teaching_items/a").set(item("a"));
    await firestore.doc("teaching_items/a/votes/v1").set({
      voterId: "c1", action: "approve", version: 1, createdAt: admin.firestore.Timestamp.fromMillis(10),
    });
    const db = createAdminLibraryDb(firestore);
    const seen = await db.transact(async (tx) => {
      const current = await tx.getItem("a");
      const votes = await tx.listVotes("a");
      tx.updateItem("a", {status: "published"});
      return {status: current?.status, votes};
    });
    expect(seen.status).toBe("in_review");
    expect(seen.votes).toEqual([{id: "v1", voterId: "c1", action: "approve", version: 1, requestId: undefined, comment: undefined, createdAt: 10}]);
    expect((await db.getItem("a"))?.status).toBe("published");
  });

  it("transact grava o marcador deleting", async () => {
    await firestore.doc("teaching_items/a").set(item("a"));
    const db = createAdminLibraryDb(firestore);
    await db.transact(async (tx) => {
      tx.updateItem("a", {deleting: "reject"});
    });
    expect((await db.getItem("a"))?.deleting).toBe("reject");
  });

  it("deleteItem apaga o documento e os votos", async () => {
    await firestore.doc("teaching_items/a").set(item("a"));
    await firestore.doc("teaching_items/a/votes/v1").set({voterId: "c1", action: "approve", version: 1, createdAt: admin.firestore.Timestamp.now()});
    await createAdminLibraryDb(firestore).deleteItem("a");
    expect((await firestore.doc("teaching_items/a").get()).exists).toBe(false);
    expect((await firestore.collection("teaching_items/a/votes").get()).size).toBe(0);
  });
});
