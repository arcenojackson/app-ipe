import {describe, expect, it} from "vitest";
import {mergeById} from "./merge";
import type {LibraryItem} from "./types";

const item = (id: string, name: string): LibraryItem => ({
  id, name, type: "file", parentId: null, authorId: "a", status: "published", version: 1,
});

describe("mergeById", () => {
  it("junta listas sem repetir ids; a última lista vence", () => {
    const merged = mergeById([[item("1", "velho"), item("2", "B")], [item("1", "novo")], []]);
    expect(merged.map((i) => [i.id, i.name]).sort()).toEqual([["1", "novo"], ["2", "B"]]);
  });

  it("lista vazia devolve vazio", () => {
    expect(mergeById([])).toEqual([]);
  });
});
