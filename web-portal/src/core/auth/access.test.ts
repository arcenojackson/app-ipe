import {describe, expect, it} from "vitest";
import {hasAccess, parseClaims, type AccessClaims} from "./access";

const none: AccessClaims = {admin: false, teachingRole: null};
const teacher: AccessClaims = {admin: false, teachingRole: "teacher"};
const curator: AccessClaims = {admin: false, teachingRole: "curator"};
const admin: AccessClaims = {admin: true, teachingRole: null};

describe("parseClaims", () => {
  it("sem claims (conta sem papel) não dá acesso", () => {
    expect(parseClaims(undefined)).toEqual(none);
    expect(parseClaims(null)).toEqual(none);
    expect(parseClaims({})).toEqual(none);
  });

  it("lê admin e teaching_role válidos", () => {
    expect(parseClaims({admin: true})).toEqual(admin);
    expect(parseClaims({teaching_role: "teacher"})).toEqual(teacher);
    expect(parseClaims({teaching_role: "curator", admin: true})).toEqual({admin: true, teachingRole: "curator"});
  });

  it("ignora valores inválidos ou de tipo errado", () => {
    expect(parseClaims({teaching_role: "god"})).toEqual(none);
    expect(parseClaims({teaching_role: 1, admin: "true"})).toEqual(none);
  });
});

describe("hasAccess", () => {
  it("sem claims (deslogado) nega tudo", () => {
    for (const req of ["authenticated", "teacher", "curator", "admin", "teachingManager"] as const) {
      expect(hasAccess(null, req)).toBe(false);
    }
  });

  it("logado sem papel só passa em 'authenticated'", () => {
    expect(hasAccess(none, "authenticated")).toBe(true);
    expect(hasAccess(none, "teacher")).toBe(false);
    expect(hasAccess(none, "curator")).toBe(false);
    expect(hasAccess(none, "admin")).toBe(false);
  });

  it("professor passa em teacher, não em curator nem admin", () => {
    expect(hasAccess(teacher, "teacher")).toBe(true);
    expect(hasAccess(teacher, "curator")).toBe(false);
    expect(hasAccess(teacher, "admin")).toBe(false);
  });

  it("curador passa em teacher e curator, não em admin", () => {
    expect(hasAccess(curator, "teacher")).toBe(true);
    expect(hasAccess(curator, "curator")).toBe(true);
    expect(hasAccess(curator, "admin")).toBe(false);
  });

  it("teachingManager: só admin que também é curador", () => {
    expect(hasAccess({admin: true, teachingRole: "curator"}, "teachingManager")).toBe(true);
    expect(hasAccess(admin, "teachingManager")).toBe(false);
    expect(hasAccess({admin: true, teachingRole: "teacher"}, "teachingManager")).toBe(false);
    expect(hasAccess(curator, "teachingManager")).toBe(false);
    expect(hasAccess(teacher, "teachingManager")).toBe(false);
    expect(hasAccess(none, "teachingManager")).toBe(false);
    expect(hasAccess(null, "teachingManager")).toBe(false);
  });

  it("admin sem papel de ensino passa em authenticated e admin, mas não em teacher/curator", () => {
    expect(hasAccess(admin, "authenticated")).toBe(true);
    expect(hasAccess(admin, "admin")).toBe(true);
    expect(hasAccess(admin, "teacher")).toBe(false);
    expect(hasAccess(admin, "curator")).toBe(false);
  });

  it("admin com papel de ensino acessa o que o papel permite", () => {
    const adminTeacher: AccessClaims = {admin: true, teachingRole: "teacher"};
    const adminCurator: AccessClaims = {admin: true, teachingRole: "curator"};
    expect(hasAccess(adminTeacher, "teacher")).toBe(true);
    expect(hasAccess(adminTeacher, "curator")).toBe(false);
    expect(hasAccess(adminTeacher, "admin")).toBe(true);
    expect(hasAccess(adminCurator, "curator")).toBe(true);
  });
});
