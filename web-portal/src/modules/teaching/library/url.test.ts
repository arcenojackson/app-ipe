import {describe, expect, it} from "vitest";
import {libraryUrl, readParams} from "./url";

describe("libraryUrl", () => {
  it("raiz, pasta, item e os dois", () => {
    expect(libraryUrl({})).toBe("/ensino/biblioteca");
    expect(libraryUrl({pasta: null})).toBe("/ensino/biblioteca");
    expect(libraryUrl({pasta: "f1"})).toBe("/ensino/biblioteca?pasta=f1");
    expect(libraryUrl({item: "i1"})).toBe("/ensino/biblioteca?item=i1");
    expect(libraryUrl({pasta: "f1", item: "i1"})).toBe("/ensino/biblioteca?pasta=f1&item=i1");
  });

  it("codifica ids com caracteres especiais", () => {
    expect(libraryUrl({pasta: "a b&c"})).toBe("/ensino/biblioteca?pasta=a%20b%26c");
  });
});

describe("readParams", () => {
  it("lê pasta e item; vazios viram null", () => {
    const search = new URLSearchParams("pasta=f1&item=");
    expect(readParams(search)).toEqual({pasta: "f1", item: null});
    expect(readParams(new URLSearchParams(""))).toEqual({pasta: null, item: null});
  });
});
