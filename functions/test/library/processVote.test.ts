import {describe, expect, it} from "vitest";
import {processVote} from "../../src/teaching/library/processVote";
import {makeDeps, makeItem, vote} from "./fakes";

const approve = (id: string, voterId: string, createdAt = 1) =>
  vote({id, voterId, action: "approve", version: 1, createdAt});

describe("processVote — publicação", () => {
  it("1ª aprovação não muda nada; a 2ª publica e avisa o autor", async () => {
    const t = makeDeps({
      items: [makeItem({id: "i1"})],
      curators: ["c1", "c2", "c3"],
      votes: {i1: [approve("v1", "c1", 1)]},
    });
    expect(await processVote(t.deps, "i1", "v1")).toBe("none");
    expect((await t.db.getItem("i1"))?.status).toBe("in_review");

    t.db.votes.set("i1", [approve("v1", "c1", 1), approve("v2", "c2", 2)]);
    expect(await processVote(t.deps, "i1", "v2")).toBe("published");
    expect((await t.db.getItem("i1"))?.status).toBe("published");
    expect(t.notifier.sent.map((n) => [n.toUid, n.type, n.id])).toEqual([
      ["author", "published", "published_i1_v1_author"],
    ]);
    expect(t.audit.entries.map((e) => e.action)).toEqual(["published"]);
  });

  it("ao publicar, grava publishedAt; devolver não grava", async () => {
    const t = makeDeps({
      items: [makeItem({id: "i1"})],
      curators: ["c1", "c2", "c3"],
      votes: {i1: [approve("v1", "c1", 1), approve("v2", "c2", 2)]},
    });
    expect(await processVote(t.deps, "i1", "v2")).toBe("published");
    const published = (await t.db.getItem("i1")) as unknown as Record<string, unknown>;
    expect(published.publishedAt).toBe(true);

    const returned = makeDeps({
      items: [makeItem({id: "i2"})],
      curators: ["c1", "c2"],
      votes: {i2: [vote({id: "v1", voterId: "c1", action: "return", version: 1, comment: "Falta fonte"})]},
    });
    expect(await processVote(returned.deps, "i2", "v1")).toBe("returned");
    const after = (await returned.db.getItem("i2")) as unknown as Record<string, unknown>;
    expect(after.publishedAt).toBeUndefined();
  });

  it("reprocessar o voto depois de publicar não faz nada", async () => {
    const t = makeDeps({
      items: [makeItem({id: "i1", status: "published"})],
      curators: ["c1", "c2"],
      votes: {i1: [approve("v1", "c1", 1), approve("v2", "c2", 2)]},
    });
    expect(await processVote(t.deps, "i1", "v2")).toBe("skipped");
    expect(t.notifier.sent).toEqual([]);
  });

  it("voto de versão antiga é ignorado", async () => {
    const t = makeDeps({
      items: [makeItem({id: "i1", version: 2})],
      curators: ["c1", "c2"],
      votes: {i1: [approve("v1", "c1")]},
    });
    expect(await processVote(t.deps, "i1", "v1")).toBe("skipped");
  });

  it("curador rebaixado não conta; autor curador não conta", async () => {
    const demoted = makeDeps({
      items: [makeItem({id: "i1"})],
      curators: ["c2"],
      votes: {i1: [approve("v1", "c1", 1), approve("v2", "c2", 2)]},
    });
    expect(await processVote(demoted.deps, "i1", "v2")).toBe("none");

    const authorCurator = makeDeps({
      items: [makeItem({id: "i2", authorId: "c1"})],
      curators: ["c1", "c2", "c3"],
      votes: {i2: [approve("v1", "c1", 1), approve("v2", "c2", 2)]},
    });
    expect(await processVote(authorCurator.deps, "i2", "v2")).toBe("none");
    authorCurator.db.votes.get("i2")!.push(approve("v3", "c3", 3));
    expect(await processVote(authorCurator.deps, "i2", "v3")).toBe("published");
  });

  it("1 curador devolve: status returned, comentário guardado e autor avisado", async () => {
    const t = makeDeps({
      items: [makeItem({id: "i1", name: "Aula 3"})],
      curators: ["c1", "c2"],
      votes: {
        i1: [
          approve("v1", "c1", 1),
          vote({id: "v2", voterId: "c2", action: "return", version: 1, comment: "Falta a referência", createdAt: 2}),
        ],
      },
    });
    expect(await processVote(t.deps, "i1", "v2")).toBe("returned");
    const item = await t.db.getItem("i1");
    expect(item).toMatchObject({status: "returned", returnComment: "Falta a referência", returnedBy: "c2"});
    expect(t.notifier.sent).toHaveLength(1);
    expect(t.notifier.sent[0]).toMatchObject({toUid: "author", type: "returned"});
    expect(t.notifier.sent[0].body).toContain("Falta a referência");
  });

  it("2 rejeições apagam arquivos e item, e avisam o autor", async () => {
    const reject = (id: string, voterId: string, createdAt: number) =>
      vote({id, voterId, action: "reject", version: 1, comment: "Fora do escopo", createdAt});
    const t = makeDeps({
      items: [makeItem({id: "i1"})],
      curators: ["c1", "c2"],
      votes: {i1: [reject("v1", "c1", 1), reject("v2", "c2", 2)]},
    });
    expect(await processVote(t.deps, "i1", "v2")).toBe("rejected");
    expect(await t.db.getItem("i1")).toBeUndefined();
    expect(t.storage.deleted).toEqual([{itemId: "i1", keepPath: undefined}]);
    expect(t.notifier.sent.map((n) => [n.toUid, n.type])).toEqual([["author", "rejected"]]);
    expect(t.audit.entries[0]).toMatchObject({action: "rejected", itemId: "i1", actors: ["c1", "c2"]});
  });

  it("falha do Storage ao rejeitar: item continua e a retentativa conclui", async () => {
    const reject = (id: string, voterId: string, createdAt: number) =>
      vote({id, voterId, action: "reject", version: 1, comment: "Não", createdAt});
    const t = makeDeps({
      items: [makeItem({id: "i1"})],
      curators: ["c1", "c2"],
      votes: {i1: [reject("v1", "c1", 1), reject("v2", "c2", 2)]},
    });
    t.storage.failNext = 1;
    await expect(processVote(t.deps, "i1", "v2")).rejects.toThrow("storage fora do ar");
    expect(await t.db.getItem("i1")).toBeDefined();
    expect(await processVote(t.deps, "i1", "v2")).toBe("rejected");
    expect(await t.db.getItem("i1")).toBeUndefined();
  });

  it("votos de item inexistente ou voto inexistente são ignorados", async () => {
    const t = makeDeps({items: [makeItem({id: "i1"})], curators: ["c1"]});
    expect(await processVote(t.deps, "nao-existe", "v1")).toBe("skipped");
    expect(await processVote(t.deps, "i1", "v-nao-existe")).toBe("skipped");
  });
});

describe("processVote — exclusão", () => {
  const request = {id: "r1", requestedBy: "c1", requestedAt: 1};
  const approveDel = (id: string, voterId: string, requestId = "r1", createdAt = 1) =>
    vote({id, voterId, action: "delete_approve", requestId, createdAt});

  it("2 aprovações de outros curadores apagam o documento e arquivos; avisa quem pediu", async () => {
    const t = makeDeps({
      items: [makeItem({id: "d1", status: "published", deleteRequest: request})],
      curators: ["c1", "c2", "c3"],
      votes: {d1: [approveDel("v1", "c2", "r1", 1), approveDel("v2", "c3", "r1", 2)]},
    });
    expect(await processVote(t.deps, "d1", "v2")).toBe("deleted");
    expect(await t.db.getItem("d1")).toBeUndefined();
    expect(t.storage.deleted.map((d) => d.itemId)).toEqual(["d1"]);
    expect(t.notifier.sent.map((n) => [n.toUid, n.type, n.id])).toEqual([
      ["c1", "deleted", "deleted_d1_r1_c1"],
    ]);
  });

  it("aprovação de quem pediu não conta", async () => {
    const t = makeDeps({
      items: [makeItem({id: "d1", status: "published", deleteRequest: request})],
      curators: ["c1", "c2"],
      votes: {d1: [approveDel("v1", "c1", "r1", 1), approveDel("v2", "c2", "r1", 2)]},
    });
    expect(await processVote(t.deps, "d1", "v2")).toBe("none");
    expect(await t.db.getItem("d1")).toBeDefined();
  });

  it("1 recusa encerra o pedido e avisa quem pediu; votos do pedido antigo não valem no novo", async () => {
    const t = makeDeps({
      items: [makeItem({id: "d1", status: "published", deleteRequest: request})],
      curators: ["c1", "c2", "c3"],
      votes: {
        d1: [vote({id: "v1", voterId: "c2", action: "delete_refuse", requestId: "r1", comment: "Ainda é usado", createdAt: 1})],
      },
    });
    expect(await processVote(t.deps, "d1", "v1")).toBe("delete_refused");
    expect((await t.db.getItem("d1"))?.deleteRequest).toBeNull();
    expect(t.notifier.sent[0]).toMatchObject({toUid: "c1", type: "delete_refused"});

    // novo pedido (r2): votos do r1 não contam; vote com requestId velho é ignorado
    await t.db.updateItem("d1", {deleteRequest: {id: "r2", requestedBy: "c1", requestedAt: 5}, deleteRequested: true});
    t.db.votes.get("d1")!.push(approveDel("v9", "c3", "r1", 6));
    expect(await processVote(t.deps, "d1", "v9")).toBe("skipped");
  });

  it("pasta: apagar leva todos os níveis, arquivos e a raiz por último", async () => {
    const t = makeDeps({
      items: [
        makeItem({id: "F", type: "folder", status: "active", deleteRequest: request}),
        makeItem({id: "X", parentId: "F", status: "published"}),
        makeItem({id: "G", type: "folder", status: "active", parentId: "F"}),
        makeItem({id: "Y", parentId: "G", status: "published"}),
        makeItem({id: "Z", status: "published"}),
      ],
      curators: ["c1", "c2", "c3"],
      votes: {F: [approveDel("v1", "c2", "r1", 1), approveDel("v2", "c3", "r1", 2)]},
    });
    expect(await processVote(t.deps, "F", "v2")).toBe("deleted");
    expect([...t.db.items.keys()]).toEqual(["Z"]);
    expect(t.storage.deleted.map((d) => d.itemId).sort()).toEqual(["X", "Y"]);
  });
});

describe("processVote — marcador deleting (veto/voto concorrente)", () => {
  const request = {id: "r1", requestedBy: "c1", requestedAt: 1};
  const approveDel = (id: string, voterId: string, createdAt: number) =>
    vote({id, voterId, action: "delete_approve", requestId: "r1", createdAt});
  const reject = (id: string, voterId: string, createdAt: number) =>
    vote({id, voterId, action: "reject", version: 1, comment: "Não", createdAt});

  it("exclusão decidida e Storage falha: marca deleting; recusa posterior não desfaz", async () => {
    const t = makeDeps({
      items: [makeItem({id: "d1", status: "published", deleteRequest: request})],
      curators: ["c1", "c2", "c3", "c4"],
      votes: {d1: [approveDel("v1", "c2", 1), approveDel("v2", "c3", 2)]},
    });
    t.storage.failNext = 1;
    await expect(processVote(t.deps, "d1", "v2")).rejects.toThrow("storage fora do ar");
    expect((await t.db.getItem("d1"))?.deleting).toBe("execute");

    t.db.votes.get("d1")!.push(
      vote({id: "v3", voterId: "c4", action: "delete_refuse", requestId: "r1", createdAt: 3})
    );
    expect(await processVote(t.deps, "d1", "v3")).toBe("deleted");
    expect(await t.db.getItem("d1")).toBeUndefined();
    expect(t.notifier.sent.map((n) => n.id)).toEqual(["deleted_d1_r1_c1"]);
    expect(t.audit.entries[0].actors).toEqual(["c1", "c2", "c3"]);
  });

  it("retentativa do mesmo evento conclui a exclusão", async () => {
    const t = makeDeps({
      items: [makeItem({id: "d1", status: "published", deleteRequest: request})],
      curators: ["c1", "c2", "c3"],
      votes: {d1: [approveDel("v1", "c2", 1), approveDel("v2", "c3", 2)]},
    });
    t.storage.failNext = 1;
    await expect(processVote(t.deps, "d1", "v2")).rejects.toThrow();
    expect(await processVote(t.deps, "d1", "v2")).toBe("deleted");
    expect(await t.db.getItem("d1")).toBeUndefined();
  });

  it("rejeição decidida com falha: voto posterior (return) não ressuscita", async () => {
    const t = makeDeps({
      items: [makeItem({id: "i1"})],
      curators: ["c1", "c2", "c3", "c4"],
      votes: {i1: [reject("v1", "c1", 1), reject("v2", "c2", 2)]},
    });
    t.storage.failNext = 1;
    await expect(processVote(t.deps, "i1", "v2")).rejects.toThrow();
    expect((await t.db.getItem("i1"))?.deleting).toBe("reject");

    t.db.votes.get("i1")!.push(
      vote({id: "v3", voterId: "c3", action: "return", version: 1, comment: "x", createdAt: 3})
    );
    expect(await processVote(t.deps, "i1", "v3")).toBe("rejected");
    expect(await t.db.getItem("i1")).toBeUndefined();
    expect(t.notifier.sent.map((n) => [n.type, n.id])).toEqual([
      ["rejected", "rejected_i1_v1_author"],
    ]);
    expect(t.audit.entries[0].actors).toEqual(["c1", "c2"]);
  });

  it("após sucesso normal não sobra nada e notifica uma vez; reprocessar é skipped", async () => {
    const t = makeDeps({
      items: [makeItem({id: "i1"})],
      curators: ["c1", "c2"],
      votes: {i1: [reject("v1", "c1", 1), reject("v2", "c2", 2)]},
    });
    expect(await processVote(t.deps, "i1", "v2")).toBe("rejected");
    expect(await processVote(t.deps, "i1", "v2")).toBe("skipped");
    expect(t.db.items.size).toBe(0);
    expect(t.notifier.sent).toHaveLength(1);
  });
});
