import {describe, expect, it} from "vitest";
import {libraryUrl, readParams} from "./url";

describe("libraryUrl", () => {
  it("sem item é a raiz da biblioteca; com item leva ?item=", () => {
    expect(libraryUrl({})).toBe("/ensino/biblioteca");
    expect(libraryUrl({item: null})).toBe("/ensino/biblioteca");
    expect(libraryUrl({item: "i1"})).toBe("/ensino/biblioteca?item=i1");
  });

  it("codifica ids com caracteres especiais", () => {
    expect(libraryUrl({item: "a b&c"})).toBe("/ensino/biblioteca?item=a%20b%26c");
  });
});

describe("readParams", () => {
  it("lê o item; vazio vira null e pasta é ignorada", () => {
    expect(readParams(new URLSearchParams("item=i1&pasta=f1"))).toEqual({item: "i1"});
    expect(readParams(new URLSearchParams("item="))).toEqual({item: null});
    expect(readParams(new URLSearchParams(""))).toEqual({item: null});
  });
});
