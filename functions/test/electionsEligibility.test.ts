import {describe, expect, it} from "vitest";
import {firstRoundPool, parseEligibility} from "../src/elections/eligibility";

const code = (fn: () => unknown) => {
  try {
    fn();
  } catch (e) {
    return (e as {code?: string}).code;
  }
  return undefined;
};

const members = [
  {id: "a", name: "Ana"},
  {id: "b", name: "Bia"},
  {id: "c", name: "Caio"},
];

describe("parseEligibility", () => {
  it("sem valor vale 'all' (apps antigos não enviam o campo)", () => {
    expect(parseEligibility(undefined)).toBe("all");
  });

  it("aceita 'all' e 'present'", () => {
    expect(parseEligibility("all")).toBe("all");
    expect(parseEligibility("present")).toBe("present");
  });

  it("recusa qualquer outro valor", () => {
    expect(code(() => parseEligibility("todos"))).toBe("invalid-argument");
    expect(code(() => parseEligibility(1))).toBe("invalid-argument");
    expect(code(() => parseEligibility(null))).toBe("invalid-argument");
  });
});

describe("firstRoundPool", () => {
  it("'all' lista todos os membros", () => {
    expect(firstRoundPool("all", members, new Set())).toEqual(members);
  });

  it("eleição antiga, sem o campo, lista todos os membros", () => {
    expect(firstRoundPool(undefined, members, new Set())).toEqual(members);
  });

  it("'present' lista só os membros que já entraram, mantendo a ordem", () => {
    expect(firstRoundPool("present", members, new Set(["c", "a"])))
      .toEqual([{id: "a", name: "Ana"}, {id: "c", name: "Caio"}]);
  });

  it("'present' ignora presente que não é membro", () => {
    expect(firstRoundPool("present", members, new Set(["a", "visitante"])))
      .toEqual([{id: "a", name: "Ana"}]);
  });

  it("'present' sem ninguém dentro devolve lista vazia", () => {
    expect(firstRoundPool("present", members, new Set())).toEqual([]);
  });
});
