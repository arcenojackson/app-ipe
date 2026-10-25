import {describe, expect, it, vi} from "vitest";
import {EMPTY_FILTERS, collectPage, planQuery, type Batch, type LibraryFilters} from "./libraryQuery";
import type {LibraryItem} from "./types";

const filters = (over: Partial<LibraryFilters>): LibraryFilters => ({...EMPTY_FILTERS, ...over});

const item = (over: Partial<LibraryItem> & {id: string}): LibraryItem => ({
  type: "file", name: over.id, parentId: null, authorId: "a", status: "published", version: 1,
  typeTags: [], subjectTags: [], ageTags: [], ...over,
});

describe("planQuery — filtro de servidor", () => {
  it("texto: maior palavra (2+ letras, sem acento), array-contains em searchTokens", () => {
    expect(planQuery(filters({text: "Fé "})).server).toEqual({field: "searchTokens", op: "array-contains", values: ["fe"]});
    expect(planQuery(filters({text: "a santificação"})).server?.values).toEqual(["santificacao"]);
  });

  it("palavra de 1 caractere é ignorada; palavra longa é cortada em 20", () => {
    expect(planQuery(filters({text: "é"})).server).toBeNull();
    expect(planQuery(filters({text: "a".repeat(30)})).server?.values).toEqual(["a".repeat(20)]);
  });

  it("texto tem prioridade; depois assunto, tipo e faixa", () => {
    const all = filters({text: "fé", subjectTags: ["s"], typeTags: ["t"], ageTags: ["g"]});
    expect(planQuery(all).server?.field).toBe("searchTokens");
    expect(planQuery({...all, text: ""}).server).toEqual({field: "subjectTags", op: "array-contains-any", values: ["s"]});
    expect(planQuery({...all, text: "", subjectTags: []}).server?.field).toBe("typeTags");
    expect(planQuery({...all, text: "", subjectTags: [], typeTags: []}).server?.field).toBe("ageTags");
    expect(planQuery(EMPTY_FILTERS).server).toBeNull();
  });
});

describe("planQuery — matches", () => {
  it("dentro de um tipo vale 'ou'; entre tipos vale 'e'", () => {
    const plan = planQuery(filters({typeTags: ["t1", "t2"], ageTags: ["g1"]}));
    expect(plan.matches(item({id: "x", typeTags: ["t2"], ageTags: ["g1"]}))).toBe(true);
    expect(plan.matches(item({id: "x", typeTags: ["t3"], ageTags: ["g1"]}))).toBe(false);
    expect(plan.matches(item({id: "x", typeTags: ["t1"], ageTags: ["g2"]}))).toBe(false);
  });

  it("texto sem acento nem caixa casa por substring de cada palavra", () => {
    const plan = planQuery(filters({text: "santificacao FÉ"}));
    expect(plan.matches(item({id: "x", name: "A Santificação pela fé"}))).toBe(true);
    expect(plan.matches(item({id: "x", name: "A Santificação"}))).toBe(false);
  });

  it("sem filtros, tudo casa", () => {
    expect(planQuery(EMPTY_FILTERS).matches(item({id: "x"}))).toBe(true);
  });
});

// Lote falso: itens 1..total, cursor = posição.
function source(total: number, pass: (n: number) => boolean) {
  const fetch = vi.fn(async (after: number | null, size: number): Promise<Batch<number>> => {
    const start = after ?? 0;
    const entries = [];
    for (let n = start + 1; n <= Math.min(start + size, total); n++) {
      entries.push({item: item({id: `i${n}`, name: pass(n) ? "ok" : "no"}), cursor: n});
    }
    return {items: entries, exhausted: start + size >= total};
  });
  return fetch;
}
const matches = (i: LibraryItem) => i.name === "ok";

describe("collectPage", () => {
  it("enche a página varrendo vários lotes quando o cliente rejeita quase tudo", async () => {
    const fetch = source(1000, (n) => n % 4 === 0);
    const page = await collectPage(fetch, matches, null, 20);
    expect(page.items).toHaveLength(20);
    expect(page.items[0].id).toBe("i4");
    expect(fetch.mock.calls.length).toBeGreaterThan(1);
    expect(page.done).toBe(false);
  });

  it("cursor é o do último item devolvido quando a página foi cortada", async () => {
    const fetch = source(1000, () => true);
    const page = await collectPage(fetch, matches, null, 20);
    expect(page.items.map((i) => i.id).at(-1)).toBe("i20");
    expect(page.cursor).toBe(20);
    const next = await collectPage(fetch, matches, page.cursor, 20);
    expect(next.items[0].id).toBe("i21");
  });

  it("para depois de 10 lotes devolvendo parcial, com cursor adiante e done=false", async () => {
    const fetch = source(100000, (n) => n === 3);
    const page = await collectPage(fetch, matches, null, 20);
    expect(fetch).toHaveBeenCalledTimes(10);
    expect(page.items.map((i) => i.id)).toEqual(["i3"]);
    expect(page.cursor).toBe(500);
    expect(page.done).toBe(false);
  });

  it("done=true quando o servidor esgotou e nada sobrou", async () => {
    const fetch = source(30, (n) => n <= 5);
    const page = await collectPage(fetch, matches, null, 20);
    expect(page.items).toHaveLength(5);
    expect(page.done).toBe(true);
  });

  it("lote vazio e esgotado devolve lista vazia, cursor null e done", async () => {
    const fetch = source(0, () => true);
    expect(await collectPage(fetch, matches, null, 20)).toEqual({items: [], cursor: null, done: true});
  });

  it("não termina como done se sobraram itens casados além da página", async () => {
    const fetch = source(40, () => true);
    const page = await collectPage(fetch, matches, null, 20);
    expect(page.items).toHaveLength(20);
    expect(page.done).toBe(false);
  });
});
