import {describe, expect, it} from "vitest";
import {itemPermissions} from "./permissions";
import type {LibraryItem, Viewer} from "./types";

const teacher: Viewer = {uid: "t1", isCurator: false, isAdmin: false};
const other: Viewer = {uid: "t2", isCurator: false, isAdmin: false};
const curator: Viewer = {uid: "c1", isCurator: true, isAdmin: false};
const curator2: Viewer = {uid: "c2", isCurator: true, isAdmin: false};
const adminOnly: Viewer = {uid: "a1", isCurator: false, isAdmin: true};

const base: LibraryItem = {id: "i1", type: "file", name: "Aula", parentId: null, authorId: "t1", status: "in_review", version: 1};
const make = (extra: Partial<LibraryItem>): LibraryItem => ({...base, ...extra});

describe("itemPermissions — editar tags", () => {
  it("curador edita tags de item publicado e em revisão; professor, admin sem papel e item em exclusão não", () => {
    expect(itemPermissions(make({status: "published"}), curator).canEditTags).toBe(true);
    expect(itemPermissions(make({}), curator2).canEditTags).toBe(true);
    expect(itemPermissions(make({}), teacher).canEditTags).toBe(false);
    expect(itemPermissions(make({}), adminOnly).canEditTags).toBe(false);
    expect(itemPermissions(make({deleting: "execute"}), curator).canEditTags).toBe(false);
  });
});

describe("itemPermissions — votar na publicação", () => {
  it("curador que não é o autor vota em item em revisão", () => {
    const p = itemPermissions(make({}), curator2);
    expect(p.canVote).toBe(true);
  });

  it("autor curador, professor, admin sem papel e item fora de revisão não votam", () => {
    expect(itemPermissions(make({authorId: "c1"}), curator).canVote).toBe(false);
    expect(itemPermissions(make({}), teacher).canVote).toBe(false);
    expect(itemPermissions(make({}), adminOnly).canVote).toBe(false);
    expect(itemPermissions(make({status: "published"}), curator2).canVote).toBe(false);
    expect(itemPermissions(make({status: "returned"}), curator2).canVote).toBe(false);
  });

  it("nada é permitido enquanto o item está sendo apagado (deleting)", () => {
    const p = itemPermissions(make({deleting: "reject"}), curator2);
    expect(p).toMatchObject({canVote: false, canRename: false, canRequestDelete: false, canVoteDelete: false, canResubmit: false});
  });
});

describe("itemPermissions — organizar e excluir", () => {
  it("só curador renomeia", () => {
    expect(itemPermissions(make({status: "published"}), curator)).toMatchObject({canRename: true});
    expect(itemPermissions(make({status: "published"}), teacher)).toMatchObject({canRename: false});
    expect(itemPermissions(make({status: "published"}), adminOnly)).toMatchObject({canRename: false});
  });

  it("curador pede exclusão de item publicado ou pasta ativa, uma vez só", () => {
    expect(itemPermissions(make({status: "published"}), curator).canRequestDelete).toBe(true);
    expect(itemPermissions(make({type: "folder", status: "active"}), curator).canRequestDelete).toBe(true);
    expect(itemPermissions(make({status: "in_review"}), curator).canRequestDelete).toBe(false);
    expect(itemPermissions(make({status: "returned"}), curator).canRequestDelete).toBe(false);
    expect(itemPermissions(make({status: "published", deleteRequest: {id: "r", requestedBy: "c1", requestedAt: 1}}), curator).canRequestDelete).toBe(false);
    expect(itemPermissions(make({status: "published"}), teacher).canRequestDelete).toBe(false);
  });

  it("votos de exclusão: outro curador vota; quem pediu cancela", () => {
    const req = {id: "r", requestedBy: "c1", requestedAt: 1};
    const item = make({status: "published", deleteRequest: req});
    expect(itemPermissions(item, curator2)).toMatchObject({canVoteDelete: true, canCancelDelete: false});
    expect(itemPermissions(item, curator)).toMatchObject({canVoteDelete: false, canCancelDelete: true});
    expect(itemPermissions(item, teacher)).toMatchObject({canVoteDelete: false, canCancelDelete: false});
    expect(itemPermissions(item, adminOnly)).toMatchObject({canVoteDelete: false, canCancelDelete: false});
  });
});

describe("itemPermissions — reenviar", () => {
  it("só o autor reenvia item devolvido", () => {
    expect(itemPermissions(make({status: "returned"}), teacher).canResubmit).toBe(true);
    expect(itemPermissions(make({status: "returned"}), other).canResubmit).toBe(false);
    expect(itemPermissions(make({status: "in_review"}), teacher).canResubmit).toBe(false);
  });
});
