import {describe, expect, it} from "vitest";
import {teachingModule} from "./module";

describe("teachingModule", () => {
  it("o módulo não é liberado por ser admin: cada item define seu acesso", () => {
    expect(teachingModule.access).toBe("authenticated");
    for (const item of teachingModule.navItems.filter((i) => i.href !== "/ensino/admin")) {
      expect(item.access).toBe("teacher");
    }
  });

  it("a Fila de revisão está disponível para professores", () => {
    const item = teachingModule.navItems.find((i) => i.href === "/ensino/revisao");
    expect(item?.access).toBe("teacher");
  });

  it("o Plano pedagógico é aberto a professores", () => {
    const item = teachingModule.navItems.find((i) => i.href === "/ensino/plano");
    expect(item?.label).toBe("Plano pedagógico");
    expect(item?.access).toBe("teacher");
  });

  it("o Fórum é aberto a professores, com ícone", () => {
    const item = teachingModule.navItems.find((i) => i.href === "/ensino/forum");
    expect(item).toMatchObject({label: "Fórum", access: "teacher", icon: "forum"});
  });

  it("Biblioteca (a Início) e Notificações são de professores; o grupo é do admin", () => {
    const access = (href: string) => teachingModule.navItems.find((i) => i.href === href)?.access;
    expect(access("/ensino")).toBe("teacher");
    expect(access("/ensino/notificacoes")).toBe("teacher");
    expect(access("/ensino/admin")).toBe("admin");
  });
});
