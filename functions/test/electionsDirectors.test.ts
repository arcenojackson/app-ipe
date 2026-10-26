import {describe, expect, it} from "vitest";
import {directorIdsOf} from "../src/elections/directors";

describe("directorIdsOf", () => {
  it("junta todos os cargos de um mapa", () => {
    expect(directorIdsOf({presidente: ["a"], vice: ["b", "c"]}).sort())
      .toEqual(["a", "b", "c"]);
  });

  it("aceita valor string em um cargo", () => {
    expect(directorIdsOf({presidente: "a"})).toEqual(["a"]);
  });

  it("aceita a lista antiga de ids", () => {
    expect(directorIdsOf(["a", "b"])).toEqual(["a", "b"]);
  });

  it("remove repetidos", () => {
    expect(directorIdsOf({presidente: ["a"], vice: ["a"]})).toEqual(["a"]);
  });

  it("formatos inesperados viram lista vazia", () => {
    expect(directorIdsOf(undefined)).toEqual([]);
    expect(directorIdsOf(null)).toEqual([]);
    expect(directorIdsOf(7)).toEqual([]);
    expect(directorIdsOf({})).toEqual([]);
    expect(directorIdsOf([])).toEqual([]);
  });
});
