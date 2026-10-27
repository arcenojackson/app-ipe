import {describe, expect, it} from "vitest";
import type {AccessClaims} from "@/core/auth/access";
import {defaultLandingPath, isPathAllowed, visibleNavGroups} from "./registry";
import type {PortalModule} from "./types";

const modules: PortalModule[] = [
  {
    id: "teaching",
    label: "Ensino",
    basePath: "/ensino",
    access: "authenticated",
    navItems: [
      {label: "Início", href: "/ensino", access: "teacher"},
      {label: "Grupo", href: "/ensino/admin", access: "admin"},
    ],
  },
  {
    id: "members",
    label: "Membros",
    basePath: "/membros",
    access: "admin",
    navItems: [{label: "Lista", href: "/membros", access: "admin"}],
  },
];

const none: AccessClaims = {admin: false, teachingRole: null};
const teacher: AccessClaims = {admin: false, teachingRole: "teacher"};
const admin: AccessClaims = {admin: true, teachingRole: null};

describe("visibleNavGroups", () => {
  it("sem papel não vê nenhum módulo", () => {
    expect(visibleNavGroups(modules, none)).toEqual([]);
    expect(visibleNavGroups(modules, null)).toEqual([]);
  });

  it("professor vê só o que seu papel permite dentro do módulo", () => {
    const groups = visibleNavGroups(modules, teacher);
    expect(groups.map((g) => g.moduleId)).toEqual(["teaching"]);
    expect(groups[0].items.map((i) => i.href)).toEqual(["/ensino"]);
  });

  it("admin sem papel de ensino vê só o Grupo, além dos módulos de admin", () => {
    const groups = visibleNavGroups(modules, admin);
    expect(groups.map((g) => g.moduleId)).toEqual(["teaching", "members"]);
    expect(groups[0].items.map((i) => i.href)).toEqual(["/ensino/admin"]);
  });

  it("admin com papel de ensino vê o ensino completo", () => {
    const groups = visibleNavGroups(modules, {admin: true, teachingRole: "teacher"});
    expect(groups[0].items.map((i) => i.href)).toEqual(["/ensino", "/ensino/admin"]);
  });
});

describe("isPathAllowed", () => {
  it("rota fora de qualquer módulo exige apenas estar logado", () => {
    expect(isPathAllowed(modules, "/", none)).toBe(true);
    expect(isPathAllowed(modules, "/", null)).toBe(false);
  });

  it("professor acessa /ensino mas não /ensino/admin", () => {
    expect(isPathAllowed(modules, "/ensino", teacher)).toBe(true);
    expect(isPathAllowed(modules, "/ensino/admin", teacher)).toBe(false);
  });

  it("usa o item mais específico e respeita o acesso do módulo", () => {
    expect(isPathAllowed(modules, "/ensino/admin", admin)).toBe(true);
    expect(isPathAllowed(modules, "/ensino", admin)).toBe(false);
    expect(isPathAllowed(modules, "/ensino/forum/x", admin)).toBe(false);
    expect(isPathAllowed(modules, "/ensino/forum/x", {admin: true, teachingRole: "teacher"})).toBe(true);
    expect(isPathAllowed(modules, "/ensino/outra-pagina", teacher)).toBe(true);
    expect(isPathAllowed(modules, "/ensino/outra-pagina", none)).toBe(false);
    expect(isPathAllowed(modules, "/membros", teacher)).toBe(false);
  });

  it("não confunde prefixos parecidos (/ensinoX)", () => {
    expect(isPathAllowed(modules, "/ensinoX", none)).toBe(true);
  });
});

describe("defaultLandingPath", () => {
  it("devolve o primeiro item visível ou null", () => {
    expect(defaultLandingPath(modules, teacher)).toBe("/ensino");
    expect(defaultLandingPath(modules, none)).toBeNull();
    expect(defaultLandingPath(modules, admin)).toBe("/ensino/admin");
  });
});
