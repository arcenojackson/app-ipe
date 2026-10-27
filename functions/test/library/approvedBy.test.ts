import {describe, expect, it} from "vitest";
import {approversOf, planApprovedBy} from "../../src/teaching/library/approvedBy";
import type {ItemDoc, VoteDoc} from "../../src/teaching/library/types";

const item = (over: Partial<ItemDoc> = {}): ItemDoc => ({
  id: "i1", type: "file", name: "Aula", parentId: null, authorId: "t1",
  status: "published", version: 2, ...over,
});
const vote = (id: string, voterId: string, action: VoteDoc["action"], version: number, createdAt: number): VoteDoc =>
  ({id, voterId, action, version, createdAt});

describe("approversOf", () => {
  it("versão atual, sem o autor e sem quem mudou de voto", () => {
    const votes = [
      vote("1", "c1", "approve", 2, 1),
      vote("2", "c2", "approve", 2, 2),
      vote("3", "c2", "return", 2, 3),
      vote("4", "c3", "approve", 1, 1),
      vote("5", "t1", "approve", 2, 4),
      vote("6", "c4", "approve", 2, 5),
    ];
    expect(approversOf(item(), votes).sort()).toEqual(["c1", "c4"]);
  });
});

describe("planApprovedBy", () => {
  const votes = [vote("1", "c1", "approve", 2, 1), vote("2", "c2", "approve", 2, 2)];

  it("só publicados sem approvedBy; é idempotente", () => {
    const plan = planApprovedBy([
      {item: item({id: "a"}), votes},
      {item: item({id: "b"}), votes, current: ["c1"]},
      {item: item({id: "c", status: "in_review"}), votes},
      {item: item({id: "d"}), votes: []},
    ]);
    expect(plan).toEqual([{itemId: "a", approvedBy: ["c1", "c2"]}]);
  });
});
