import {describe, expect, it} from "vitest";
import {BATCH_SIZE} from "../../src/teaching/library/constants";
import {
  collectSubtree,
  deleteSubtree,
} from "../../src/teaching/library/subtree";
import {makeDeps, makeItem} from "./fakes";

describe("subtree", () => {
  it("collectSubtree: raiz primeiro, em largura", async () => {
    const t = makeDeps({
      items: [
        makeItem({id: "F", type: "folder"}),
        makeItem({id: "G", type: "folder", parentId: "F"}),
        makeItem({id: "X", parentId: "F"}),
        makeItem({id: "Y", parentId: "G"}),
      ],
    });
    const root = (await t.db.getItem("F"))!;
    const ids = (await collectSubtree(t.db, root)).map((i) => i.id);
    expect(ids).toEqual(["F", "G", "X", "Y"]);
  });

  it("falha num neto: nenhum ancestral some e a retentativa conclui", async () => {
    const t = makeDeps({
      items: [
        makeItem({id: "F", type: "folder"}),
        makeItem({id: "G", type: "folder", parentId: "F"}),
        makeItem({id: "H", parentId: "G"}),
        makeItem({id: "K", parentId: "G"}),
      ],
    });
    const original = t.db.deleteItem.bind(t.db);
    let failed = false;
    t.db.deleteItem = async (id: string) => {
      if (id === "H" && !failed) {
        failed = true;
        throw new Error("firestore fora do ar");
      }
      return original(id);
    };
    const root = (await t.db.getItem("F"))!;
    await expect(deleteSubtree(t.deps, root)).rejects.toThrow("firestore");
    expect(t.db.items.has("F")).toBe(true);
    expect(t.db.items.has("G")).toBe(true);

    await deleteSubtree(t.deps, root);
    expect(t.db.items.size).toBe(0);
  });

  it("nível largo (> BATCH_SIZE irmãos) é apagado por inteiro", async () => {
    const kids = Array.from({length: BATCH_SIZE * 2 + 3}, (_, i) =>
      makeItem({id: `k${i}`, parentId: "F"})
    );
    const t = makeDeps({items: [makeItem({id: "F", type: "folder"}), ...kids]});
    const root = (await t.db.getItem("F"))!;
    await deleteSubtree(t.deps, root);
    expect(t.db.items.size).toBe(0);
    expect(t.storage.deleted).toHaveLength(kids.length);
  });
});
