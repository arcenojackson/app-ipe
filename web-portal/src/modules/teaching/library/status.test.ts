import {describe, expect, it} from "vitest";
import {countApprovals, countDeleteApprovals, statusBadge} from "./status";
import type {LibraryItem, LibraryVote} from "./types";

const item = (extra: Partial<LibraryItem> = {}): LibraryItem => ({
  id: "i1", type: "file", name: "Aula", parentId: null, authorId: "t1", status: "in_review", version: 1, ...extra,
});
const vote = (id: string, voterId: string, action: LibraryVote["action"], extra: Partial<LibraryVote> = {}): LibraryVote => ({
  id, voterId, action, createdAt: 1, version: 1, ...extra,
});

describe("countApprovals", () => {
  it("conta curadores distintos que aprovaram a versão atual (último voto de cada um)", () => {
    const votes = [
      vote("a", "c1", "approve", {createdAt: 1}),
      vote("b", "c2", "approve", {createdAt: 1}),
      vote("c", "c2", "return", {createdAt: 2, comment: "x"}),
      vote("d", "c3", "approve", {version: 0}),
      vote("e", "t1", "approve"),
    ];
    expect(countApprovals(item(), votes)).toBe(1);
  });
});

describe("countDeleteApprovals", () => {
  it("conta aprovações do pedido atual, sem a de quem pediu", () => {
    const withRequest = item({status: "published", deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: 1}});
    const votes = [
      vote("a", "c2", "delete_approve", {requestId: "r1", version: undefined}),
      vote("b", "c1", "delete_approve", {requestId: "r1", version: undefined}),
      vote("c", "c3", "delete_approve", {requestId: "velho", version: undefined}),
    ];
    expect(countDeleteApprovals(withRequest, votes)).toBe(1);
    expect(countDeleteApprovals(item(), votes)).toBe(0);
  });
});

describe("statusBadge", () => {
  it("em revisão mostra o andamento das aprovações", () => {
    expect(statusBadge(item(), 1)).toEqual({label: "Em revisão 1/2", tone: "info"});
  });

  it("publicado, devolvido e pasta", () => {
    expect(statusBadge(item({status: "published"}), 0)).toEqual({label: "Publicado", tone: "success"});
    expect(statusBadge(item({status: "returned"}), 0)).toEqual({label: "Devolvido", tone: "warning"});
    expect(statusBadge(item({type: "folder", status: "active"}), 0)).toEqual({label: "", tone: "neutral"});
  });

  it("pedido de exclusão e exclusão em andamento têm prioridade", () => {
    const req = {id: "r", requestedBy: "c1", requestedAt: 1};
    expect(statusBadge(item({status: "published", deleteRequest: req}), 0)).toEqual({label: "Exclusão solicitada", tone: "danger"});
    expect(statusBadge(item({status: "published", deleting: "execute"}), 0)).toEqual({label: "Excluindo…", tone: "danger"});
    expect(statusBadge(item({deleting: "reject"}), 0)).toEqual({label: "Excluindo…", tone: "danger"});
  });
});
