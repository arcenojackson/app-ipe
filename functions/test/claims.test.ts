import {describe, expect, it} from "vitest";
import {
  claimsEqual,
  computeTeachingClaims,
  currentTeachingClaims,
  mergeTeachingClaims,
} from "../src/teaching/claims";

describe("currentTeachingClaims", () => {
  it("claims vazias ou indefinidas não geram nada", () => {
    expect(currentTeachingClaims(undefined)).toEqual({});
    expect(currentTeachingClaims({})).toEqual({});
  });

  it("lê admin e teaching_role válidos", () => {
    expect(currentTeachingClaims({admin: true, teaching_role: "curator"}))
      .toEqual({admin: true, teaching_role: "curator"});
    expect(currentTeachingClaims({teaching_role: "teacher"}))
      .toEqual({teaching_role: "teacher"});
  });

  it("ignora valores inválidos", () => {
    expect(currentTeachingClaims({admin: "true", teaching_role: "god"}))
      .toEqual({});
    expect(currentTeachingClaims({admin: false, teaching_role: 3}))
      .toEqual({});
  });

  it("ignora claims de outros sistemas", () => {
    expect(currentTeachingClaims({foo: 1, is_admin: true})).toEqual({});
  });
});

describe("computeTeachingClaims", () => {
  it("sem documento não há claims", () => {
    expect(computeTeachingClaims(undefined)).toEqual({});
  });

  it("is_admin true vira admin", () => {
    expect(computeTeachingClaims({is_admin: true})).toEqual({admin: true});
  });

  it("teacher e curator viram teaching_role", () => {
    expect(computeTeachingClaims({teaching_role: "teacher"})).toEqual({teaching_role: "teacher"});
    expect(computeTeachingClaims({teaching_role: "curator"})).toEqual({teaching_role: "curator"});
  });

  it("admin e professor juntos", () => {
    expect(computeTeachingClaims({is_admin: true, teaching_role: "curator"})).toEqual({
      admin: true,
      teaching_role: "curator",
    });
  });

  it("none, valor inválido ou tipo errado não geram claim", () => {
    expect(computeTeachingClaims({teaching_role: "none"})).toEqual({});
    expect(computeTeachingClaims({teaching_role: "god"})).toEqual({});
    expect(computeTeachingClaims({teaching_role: 3})).toEqual({});
  });

  it("is_admin só vale como booleano true (alinhado às regras)", () => {
    expect(computeTeachingClaims({is_admin: "true"})).toEqual({});
    expect(computeTeachingClaims({isAdmin: true})).toEqual({});
    expect(computeTeachingClaims({is_admin: false})).toEqual({});
  });
});

describe("claimsEqual", () => {
  it("compara admin e teaching_role", () => {
    expect(claimsEqual({}, {})).toBe(true);
    expect(claimsEqual({admin: true}, {admin: true})).toBe(true);
    expect(claimsEqual({admin: true}, {})).toBe(false);
    expect(claimsEqual({teaching_role: "teacher"}, {teaching_role: "curator"})).toBe(false);
  });
});

describe("mergeTeachingClaims", () => {
  it("preserva claims de outros sistemas e troca as de ensino", () => {
    const merged = mergeTeachingClaims(
      {foo: 1, admin: true, teaching_role: "teacher"},
      {teaching_role: "curator"}
    );
    expect(merged).toEqual({foo: 1, teaching_role: "curator"});
  });

  it("remove claims de ensino quando não se aplicam mais", () => {
    expect(mergeTeachingClaims({admin: true, teaching_role: "teacher"}, {})).toEqual({});
  });

  it("aceita claims existentes indefinidas", () => {
    expect(mergeTeachingClaims(undefined, {admin: true})).toEqual({admin: true});
  });
});
