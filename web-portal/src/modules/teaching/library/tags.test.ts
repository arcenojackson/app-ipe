import {describe, expect, it} from "vitest";
import {EMPTY_TAGS, TAG_FIELD, tagName, validateTags, type Tag} from "./tags";

const tag = (id: string, name: string): Tag => ({id, kind: "type", name, order: 1, active: true});

describe("validateTags", () => {
  it("aponta o primeiro tipo de tag vazio", () => {
    expect(validateTags(EMPTY_TAGS)).toBe("Escolha pelo menos uma tag de tipo.");
    expect(validateTags({...EMPTY_TAGS, typeTags: ["a"]})).toBe("Escolha pelo menos uma tag de assunto.");
    expect(validateTags({typeTags: ["a"], subjectTags: ["b"], ageTags: []})).toBe(
      "Escolha pelo menos uma tag de faixa."
    );
  });

  it("aceita uma tag de cada tipo", () => {
    expect(validateTags({typeTags: ["a"], subjectTags: ["b"], ageTags: ["c"]})).toBeNull();
  });
});

describe("TAG_FIELD", () => {
  it("liga cada tipo ao campo do item", () => {
    expect(TAG_FIELD).toEqual({type: "typeTags", subject: "subjectTags", age: "ageTags"});
  });
});

describe("tagName", () => {
  it("devolve o nome, ou Tag removida quando o id não existe", () => {
    const byId = new Map([["a", tag("a", "Artigos")]]);
    expect(tagName(byId, "a")).toBe("Artigos");
    expect(tagName(byId, "sumiu")).toBe("Tag removida");
  });
});
