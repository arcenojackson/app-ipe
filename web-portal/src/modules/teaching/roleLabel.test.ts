import {describe, expect, it} from "vitest";
import {teachingRoleLabel} from "./roleLabel";

describe("teachingRoleLabel", () => {
  it("admin + curator -> Curador", () => {
    expect(teachingRoleLabel({admin: true, teachingRole: "curator"})).toBe("Curador");
  });
  it("admin + teacher -> Professor", () => {
    expect(teachingRoleLabel({admin: true, teachingRole: "teacher"})).toBe("Professor");
  });
  it("somente admin -> Administrador", () => {
    expect(teachingRoleLabel({admin: true, teachingRole: null})).toBe("Administrador");
  });
  it("somente curator -> Curador", () => {
    expect(teachingRoleLabel({admin: false, teachingRole: "curator"})).toBe("Curador");
  });
  it("somente teacher -> Professor", () => {
    expect(teachingRoleLabel({admin: false, teachingRole: "teacher"})).toBe("Professor");
  });
  it("nenhum -> Sem papel no grupo", () => {
    expect(teachingRoleLabel({admin: false, teachingRole: null})).toBe("Sem papel no grupo");
  });
});
