import {describe, expect, it} from "vitest";
import {buildBreadcrumbs, filterByName, indexById, sortItems} from "./tree";
import type {LibraryItem} from "./types";

const item = (id: string, name: string, type: LibraryItem["type"] = "file", parentId: string | null = null): LibraryItem => ({
  id, name, type, parentId, authorId: "a", status: type === "folder" ? "active" : "published", version: 1,
});

describe("sortItems", () => {
  it("pastas primeiro, depois por nome sem diferenciar acento e maiúscula, com números naturais", () => {
    const result = sortItems([
      item("1", "Zeca"), item("2", "ábaco"), item("3", "Aula 10"), item("4", "Aula 2"),
      item("5", "Pasta B", "folder"), item("6", "pasta a", "folder"),
    ]);
    expect(result.map((i) => i.name)).toEqual(["pasta a", "Pasta B", "ábaco", "Aula 2", "Aula 10", "Zeca"]);
  });

  it("não altera a lista original", () => {
    const list = [item("1", "B"), item("2", "A")];
    sortItems(list);
    expect(list.map((i) => i.name)).toEqual(["B", "A"]);
  });
});

describe("buildBreadcrumbs", () => {
  const byId = indexById([
    item("f1", "Crianças", "folder"),
    item("f2", "Antigo Testamento", "folder", "f1"),
    item("f3", "Gênesis", "folder", "f2"),
  ]);

  it("raiz não tem migalhas", () => {
    expect(buildBreadcrumbs(byId, null)).toEqual([]);
  });

  it("da raiz até a pasta", () => {
    expect(buildBreadcrumbs(byId, "f3").map((i) => i.name)).toEqual(["Crianças", "Antigo Testamento", "Gênesis"]);
  });

  it("para quando um pai não está disponível (sem laço infinito)", () => {
    expect(buildBreadcrumbs(byId, "inexistente")).toEqual([]);
    const cyclic = indexById([item("a", "A", "folder", "b"), item("b", "B", "folder", "a")]);
    expect(buildBreadcrumbs(cyclic, "a").length).toBeLessThanOrEqual(2);
  });
});

describe("filterByName", () => {
  const list = [item("1", "Catecismo Menor"), item("2", "Confissão de Fé"), item("3", "Jesus e as crianças")];

  it("sem termo devolve tudo", () => {
    expect(filterByName(list, "  ")).toHaveLength(3);
  });

  it("ignora acento e maiúscula e aceita parte do nome", () => {
    expect(filterByName(list, "CONFISSAO").map((i) => i.id)).toEqual(["2"]);
    expect(filterByName(list, "criancas").map((i) => i.id)).toEqual(["3"]);
    expect(filterByName(list, "zzz")).toEqual([]);
  });
});
