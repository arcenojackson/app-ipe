import {describe, expect, it} from "vitest";
import {approverIds} from "./status";
import type {LibraryItem, LibraryVote} from "./types";

const base = {id: "i", type: "file", parentId: null, name: "x", authorId: "t1", status: "published", version: 2} as LibraryItem;
const vote = (id: string, voterId: string, action: LibraryVote["action"], version: number, createdAt: number): LibraryVote =>
  ({id, voterId, action, version, createdAt});

describe("approverIds", () => {
  it("lista quem aprovou a versão atual, sem o autor e sem quem mudou de ideia", () => {
    const votes = [
      vote("1", "c1", "approve", 2, 1),
      vote("2", "c2", "approve", 2, 2),
      vote("3", "c2", "return", 2, 3),
      vote("4", "c3", "approve", 1, 1),
      vote("5", "t1", "approve", 2, 4),
    ];
    expect(approverIds(base, votes)).toEqual(["c1"]);
  });
});
