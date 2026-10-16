import {describe, expect, it} from "vitest";
import {moveIsValid} from "../../src/teaching/library/moves";
import {
  processItemChange,
  processItemCreated,
} from "../../src/teaching/library/processItemChange";
import {makeDeps, makeItem} from "./fakes";

const folder = (id: string, parentId: string | null = null) =>
  makeItem({id, type: "folder", status: "active", parentId, authorId: "c1"});

function chain(n: number) {
  return Array.from({length: n}, (_, i) =>
    folder(`d${i + 1}`, i === 0 ? null : `d${i}`));
}

describe("moveIsValid", () => {
  it("mover para a raiz ou para uma pasta é válido", async () => {
    const t = makeDeps({items: [folder("A"), makeItem({id: "x", parentId: "A"})]});
    expect(await moveIsValid(t.db, makeItem({id: "x", parentId: null}))).toBe(true);
    expect(await moveIsValid(t.db, makeItem({id: "x", parentId: "A"}))).toBe(true);
  });

  it("pasta para dentro de si mesma ou de um descendente cria ciclo", async () => {
    const t = makeDeps({items: [folder("A"), folder("B", "A"), folder("C", "B")]});
    expect(await moveIsValid(t.db, folder("A", "A"))).toBe(false);
    expect(await moveIsValid(t.db, folder("A", "C"))).toBe(false);
  });

  it("pai inexistente ou que não é pasta é inválido", async () => {
    const t = makeDeps({items: [makeItem({id: "arq", status: "published"})]});
    expect(await moveIsValid(t.db, makeItem({id: "x", parentId: "arq"}))).toBe(false);
    expect(await moveIsValid(t.db, makeItem({id: "x", parentId: "fantasma"}))).toBe(false);
  });

  it("limite de 8 níveis considera ancestrais e a altura da subárvore", async () => {
    const t = makeDeps({items: chain(8)});
    // arquivo dentro de d7 fica no nível 8 (ok); dentro de d8 ficaria no 9 (inválido)
    expect(await moveIsValid(t.db, makeItem({id: "x", parentId: "d7"}))).toBe(true);
    expect(await moveIsValid(t.db, makeItem({id: "x", parentId: "d8"}))).toBe(false);

    // pasta com subárvore de 3 níveis (S > S2 > S3) movida para d5: 5 + 1 + 2 = 8 (ok), para d6: 9 (inválido)
    const t2 = makeDeps({items: [...chain(8), folder("S"), folder("S2", "S"), folder("S3", "S2")]});
    expect(await moveIsValid(t2.db, folder("S", "d5"))).toBe(true);
    expect(await moveIsValid(t2.db, folder("S", "d6"))).toBe(false);
  });
});

describe("processItemChange — movimento", () => {
  it("movimento inválido é desfeito e quem moveu é avisado", async () => {
    const before = folder("A", null);
    const after = {...folder("A", "C"), updatedBy: "c2"};
    const t = makeDeps({items: [after, folder("B", "A"), folder("C", "B")], curators: ["c1", "c2"]});
    expect(await processItemChange(t.deps, before, after)).toBe("move_reverted");
    expect((await t.db.getItem("A"))?.parentId).toBeNull();
    expect(t.notifier.sent.map((n) => [n.toUid, n.type])).toEqual([["c2", "move_reverted"]]);
  });

  it("movimento válido não faz nada", async () => {
    const before = folder("A", null);
    const after = {...folder("A", "B"), updatedBy: "c2"};
    const t = makeDeps({items: [after, folder("B")], curators: ["c1"]});
    expect(await processItemChange(t.deps, before, after)).toBe("moved");
    expect((await t.db.getItem("A"))?.parentId).toBe("B");
    expect(t.notifier.sent).toEqual([]);
  });
});

describe("processItemChange — movimento (fix round 1)", () => {
  it("se o pai antigo também é inválido, não escreve nem avisa", async () => {
    const before = folder("A", "gone");
    const after = {...folder("A", "C"), updatedBy: "c2"};
    const t = makeDeps({items: [after, folder("B", "A"), folder("C", "B")], curators: ["c1", "c2"]});
    expect(await processItemChange(t.deps, before, after)).toBe("move_invalid");
    expect((await t.db.getItem("A"))?.parentId).toBe("C");
    expect(t.notifier.sent).toEqual([]);
  });

  it("o evento do revert termina: reprocessá-lo devolve moved", async () => {
    const before = folder("A", null);
    const after = {...folder("A", "C"), updatedBy: "c2"};
    const t = makeDeps({items: [after, folder("B", "A"), folder("C", "B")], curators: ["c1", "c2"]});
    expect(await processItemChange(t.deps, before, after)).toBe("move_reverted");
    const reverted = await t.db.getItem("A");
    expect(reverted).toBeDefined();
    if (!reverted) return;
    expect(await processItemChange(t.deps, after, reverted)).toBe("moved");
  });
});

describe("processItemChange — reenvio (fix round 1)", () => {
  it("arquivo sem storagePath não chama deleteItemFiles mas avisa curadores", async () => {
    const before = makeItem({id: "i1", status: "returned", version: 1, authorId: "t1"});
    const after = makeItem({id: "i1", status: "in_review", version: 2, authorId: "t1"});
    const t = makeDeps({items: [after], curators: ["c1", "t1"]});
    expect(await processItemChange(t.deps, before, after)).toBe("resubmitted");
    expect(t.storage.deleted).toEqual([]);
    expect(t.notifier.sent.map((n) => n.toUid)).toEqual(["c1"]);
  });

  it("link reenviado avisa curadores", async () => {
    const before = makeItem({id: "l1", type: "link", status: "returned", version: 1, authorId: "t1"});
    const after = makeItem({id: "l1", type: "link", status: "in_review", version: 2, authorId: "t1"});
    const t = makeDeps({items: [after], curators: ["c1", "t1"]});
    expect(await processItemChange(t.deps, before, after)).toBe("resubmitted");
    expect(t.notifier.sent.map((n) => n.toUid)).toEqual(["c1"]);
  });
});

describe("processItemChange — reenvio", () => {
  it("item devolvido que volta para revisão limpa a versão antiga e avisa os curadores", async () => {
    const before = makeItem({id: "i1", status: "returned", version: 1, authorId: "t1", storagePath: "teaching/materials/i1/v1-a.pdf"});
    const after = makeItem({id: "i1", status: "in_review", version: 2, authorId: "t1", storagePath: "teaching/materials/i1/v2-b.pdf"});
    const t = makeDeps({items: [after], curators: ["c1", "c2", "t1"]});
    expect(await processItemChange(t.deps, before, after)).toBe("resubmitted");
    expect(t.storage.deleted).toEqual([{itemId: "i1", keepPath: "teaching/materials/i1/v2-b.pdf"}]);
    expect(t.notifier.sent.map((n) => [n.toUid, n.type, n.id])).toEqual([
      ["c1", "review_requested", "review_requested_i1_v2_c1"],
      ["c2", "review_requested", "review_requested_i1_v2_c2"],
    ]);
  });

  it("falha do Storage no reenvio lança erro (retentativa)", async () => {
    const before = makeItem({id: "i1", status: "returned", version: 1});
    const after = makeItem({id: "i1", status: "in_review", version: 2, storagePath: "p"});
    const t = makeDeps({items: [after], curators: ["c1"]});
    t.storage.failNext = 1;
    await expect(processItemChange(t.deps, before, after)).rejects.toThrow("storage fora do ar");
  });
});

describe("processItemChange — pedido de exclusão", () => {
  const request = {id: "r1", requestedBy: "c1", requestedAt: 1};

  it("documento: avisa os outros curadores", async () => {
    const before = makeItem({id: "d1", status: "published"});
    const after = makeItem({id: "d1", status: "published", deleteRequest: request});
    const t = makeDeps({items: [after], curators: ["c1", "c2", "c3"]});
    expect(await processItemChange(t.deps, before, after)).toBe("delete_requested");
    expect(t.notifier.sent.map((n) => [n.toUid, n.type, n.id])).toEqual([
      ["c2", "delete_requested", "delete_requested_d1_r1_c2"],
      ["c3", "delete_requested", "delete_requested_d1_r1_c3"],
    ]);
    expect(await t.db.getItem("d1")).toBeDefined();
  });

  it("pasta sem nenhum documento (mesmo com subpastas) é apagada na hora", async () => {
    const before = folder("F");
    const after = {...folder("F"), deleteRequest: request};
    const t = makeDeps({items: [after, folder("G", "F"), folder("H", "G")], curators: ["c1", "c2"]});
    expect(await processItemChange(t.deps, before, after)).toBe("deleted_empty_folder");
    expect([...t.db.items.keys()]).toEqual([]);
    expect(t.audit.entries[0]).toMatchObject({action: "deleted_empty_folder", itemId: "F"});
  });

  it("pasta com documento em qualquer nível exige os 2 curadores", async () => {
    const before = folder("F");
    const after = {...folder("F"), deleteRequest: request};
    const t = makeDeps({
      items: [after, folder("G", "F"), makeItem({id: "Y", parentId: "G", status: "in_review"})],
      curators: ["c1", "c2"],
    });
    expect(await processItemChange(t.deps, before, after)).toBe("delete_requested");
    expect(t.db.items.size).toBe(3);
    expect(t.notifier.sent.map((n) => n.toUid)).toEqual(["c2"]);
  });

  it("cancelar o pedido não faz nada", async () => {
    const before = makeItem({id: "d1", status: "published", deleteRequest: request});
    const after = makeItem({id: "d1", status: "published", deleteRequest: null});
    const t = makeDeps({items: [after], curators: ["c1", "c2"]});
    expect(await processItemChange(t.deps, before, after)).toBe("none");
    expect(t.notifier.sent).toEqual([]);
  });

  it("atualização sem efeito (renomear) não faz nada", async () => {
    const before = makeItem({id: "d1", status: "published", name: "A"});
    const after = makeItem({id: "d1", status: "published", name: "B"});
    const t = makeDeps({items: [after], curators: ["c1"]});
    expect(await processItemChange(t.deps, before, after)).toBe("none");
  });
});

describe("itens em destruição (deleting)", () => {
  it("processItemChange não faz nada se o item está com deleting", async () => {
    const before = makeItem({id: "i1", status: "returned", version: 1});
    const after = makeItem({id: "i1", status: "in_review", version: 2, storagePath: "p", deleting: "execute"});
    const t = makeDeps({items: [after], curators: ["c1", "c2"]});
    expect(await processItemChange(t.deps, before, after)).toBe("none");
    expect(t.storage.deleted).toEqual([]);
    expect(t.notifier.sent).toEqual([]);
  });

  it("processItemCreated não faz nada se o item está com deleting", async () => {
    const item = makeItem({id: "i1", authorId: "c1", deleting: "reject"});
    const t = makeDeps({items: [item], curators: ["c1", "c2"]});
    await processItemCreated(t.deps, item);
    expect(t.notifier.sent).toEqual([]);
    expect(t.audit.entries).toEqual([]);
  });
});

describe("processItemCreated", () => {
  it("documento em revisão avisa os curadores, exceto o autor", async () => {
    const item = makeItem({id: "i1", authorId: "c1"});
    const t = makeDeps({items: [item], curators: ["c1", "c2", "c3"]});
    await processItemCreated(t.deps, item);
    expect(t.notifier.sent.map((n) => [n.toUid, n.id])).toEqual([
      ["c2", "review_requested_i1_v1_c2"],
      ["c3", "review_requested_i1_v1_c3"],
    ]);
  });

  it("pasta não gera aviso", async () => {
    const t = makeDeps({items: [folder("F")], curators: ["c1", "c2"]});
    await processItemCreated(t.deps, folder("F"));
    expect(t.notifier.sent).toEqual([]);
  });
});
