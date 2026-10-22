import {describe, expect, it} from "vitest";
import {toItem, toNotification, toVote} from "./convert";

const ts = (ms: number) => ({toMillis: () => ms});

describe("toItem", () => {
  it("converte campos, timestamps e padrões", () => {
    expect(toItem("i1", {
      type: "file", name: "Aula", parentId: "f1", authorId: "t1", status: "in_review", version: 2,
      fileName: "a.pdf", contentType: "application/pdf", size: 10, storagePath: "p",
      createdAt: ts(500),
      deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: ts(700), reason: "x"},
    })).toEqual({
      id: "i1", type: "file", name: "Aula", parentId: "f1", authorId: "t1", status: "in_review", version: 2,
      updatedBy: undefined, fileName: "a.pdf", contentType: "application/pdf", size: 10, storagePath: "p",
      url: undefined, description: undefined, returnComment: null, returnedBy: null,
      deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: 700, reason: "x"},
      deleting: null, createdAt: 500,
    });
  });

  it("parentId ausente vira null e versão ausente vira 1", () => {
    const item = toItem("f", {type: "folder", name: "P", authorId: "c1", status: "active"});
    expect(item).toMatchObject({parentId: null, version: 1, deleteRequest: null, deleting: null});
  });

  it("tipo ou status desconhecidos devolvem null", () => {
    expect(toItem("x", {type: "banana", name: "x", authorId: "a", status: "active"})).toBeNull();
    expect(toItem("x", {type: "file", name: "x", authorId: "a", status: "?"})).toBeNull();
    expect(toItem("x", {})).toBeNull();
  });

  it("deleting só aceita os dois valores conhecidos", () => {
    expect(toItem("x", {type: "file", name: "x", authorId: "a", status: "published", deleting: "execute"})?.deleting).toBe("execute");
    expect(toItem("x", {type: "file", name: "x", authorId: "a", status: "published", deleting: "qualquer"})?.deleting).toBeNull();
  });
});

describe("toVote", () => {
  it("converte e descarta ação desconhecida", () => {
    expect(toVote("v1", {voterId: "c1", action: "approve", version: 1, createdAt: ts(10)})).toEqual({
      id: "v1", voterId: "c1", action: "approve", version: 1, requestId: undefined, comment: undefined, createdAt: 10,
    });
    expect(toVote("v2", {voterId: "c1", action: "x", createdAt: ts(1)})).toBeNull();
    expect(toVote("v3", {action: "approve"})).toBeNull();
  });
});

describe("toNotification", () => {
  it("converte e trata readAt nulo", () => {
    expect(toNotification("n1", {toUid: "t1", type: "published", itemId: "i1", title: "T", body: "B", createdAt: ts(9), readAt: null})).toEqual({
      id: "n1", toUid: "t1", type: "published", itemId: "i1", title: "T", body: "B", createdAt: 9, readAt: null,
    });
    expect(toNotification("n2", {toUid: "t1", type: "x", itemId: "i", title: "T", body: "B", createdAt: ts(1), readAt: ts(5)})?.readAt).toBe(5);
    expect(toNotification("n3", {type: "x"})).toBeNull();
  });
});
