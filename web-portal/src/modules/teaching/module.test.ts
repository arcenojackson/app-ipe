import {describe, expect, it} from "vitest";
import {teachingModule} from "./module";

describe("teachingModule", () => {
  it("a Fila de revisão está disponível para professores", () => {
    const item = teachingModule.navItems.find((i) => i.href === "/ensino/revisao");
    expect(item?.access).toBe("teacher");
  });

  it("Biblioteca e Notificações são de professores; o grupo é do admin", () => {
    const access = (href: string) => teachingModule.navItems.find((i) => i.href === href)?.access;
    expect(access("/ensino/biblioteca")).toBe("teacher");
    expect(access("/ensino/notificacoes")).toBe("teacher");
    expect(access("/ensino/admin")).toBe("admin");
  });
});
