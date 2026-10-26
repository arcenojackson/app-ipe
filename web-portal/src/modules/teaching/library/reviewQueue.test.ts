import {describe, expect, it} from "vitest";
import {buildReviewQueue, iVoted} from "./reviewQueue";
import type {LibraryItem, LibraryVote, Viewer} from "./types";

const item = (id: string, over: Partial<LibraryItem> = {}): LibraryItem => ({
  id, type: "file", name: id, parentId: null, authorId: "t1", status: "in_review", version: 1, ...over,
});

const teacher: Viewer = {uid: "t1", isCurator: false, isAdmin: false};
const curator: Viewer = {uid: "c1", isCurator: true, isAdmin: false};
const admin: Viewer = {uid: "a1", isCurator: false, isAdmin: true};

const input = {
  mine: [item("m1", {authorId: "c1", createdAt: 1}), item("m2", {authorId: "c1", status: "returned", createdAt: 2})],
  inReview: [item("m1", {authorId: "c1"}), item("o1", {authorId: "t2"}), item("o2", {authorId: "t3"})],
  deleteRequested: [item("d1", {status: "published"})],
  returned: [item("m2", {authorId: "c1", status: "returned"}), item("r1", {authorId: "t2", status: "returned"})],
};

describe("buildReviewQueue", () => {
  it("professor vê só os próprios envios, mais novos primeiro", () => {
    const queue = buildReviewQueue(teacher, input);
    expect(queue.mine.map((i) => i.id)).toEqual(["m2", "m1"]);
    expect(queue.toReview).toEqual([]);
    expect(queue.deleteRequests).toEqual([]);
    expect(queue.returned).toEqual([]);
  });

  it("curador também vê os envios de outros em revisão (sem os próprios) e os pedidos de exclusão", () => {
    const queue = buildReviewQueue(curator, input);
    expect(queue.mine.map((i) => i.id)).toEqual(["m2", "m1"]);
    expect(queue.toReview.map((i) => i.id)).toEqual(["o1", "o2"]);
    expect(queue.deleteRequests.map((i) => i.id)).toEqual(["d1"]);
  });

  it("curador vê os devolvidos de outros autores (sem os próprios), para poder pedir a exclusão", () => {
    expect(buildReviewQueue(curator, input).returned.map((i) => i.id)).toEqual(["r1"]);
  });

  it("admin sem papel de curador lê a fila como curador", () => {
    expect(buildReviewQueue(admin, input).toReview).toHaveLength(3);
  });
});

describe("iVoted", () => {
  const vote = (over: Partial<LibraryVote>): LibraryVote => ({id: "v", voterId: "c1", action: "approve", createdAt: 1, ...over});

  it("conta o voto na versão atual (publicação) e no pedido atual (exclusão)", () => {
    expect(iVoted(item("a", {version: 2}), [vote({version: 2})], "c1")).toBe(true);
    expect(iVoted(item("a", {version: 2}), [vote({version: 1})], "c1")).toBe(false);
    expect(iVoted(item("a", {version: 2}), [vote({version: 2, voterId: "c2"})], "c1")).toBe(false);
    const withRequest = item("a", {deleteRequest: {id: "r1", requestedBy: "c9", requestedAt: 1}});
    expect(iVoted(withRequest, [vote({action: "delete_approve", requestId: "r1"})], "c1")).toBe(true);
    expect(iVoted(withRequest, [vote({action: "delete_approve", requestId: "velho"})], "c1")).toBe(false);
  });
});
