import {describe, expect, it} from "vitest";
import {filterMembers, toMemberRow, type MemberRow} from "./memberRows";

describe("toMemberRow", () => {
  it("mapeia os campos do documento", () => {
    expect(
      toMemberRow("u1", {name: "Ana", email: "ana@ipe.org", is_admin: true, is_pending: false, teaching_role: "curator"})
    ).toEqual({id: "u1", name: "Ana", email: "ana@ipe.org", isAdmin: true, isPending: false, teachingRole: "curator"});
  });

  it("aplica padrões quando faltam campos", () => {
    expect(toMemberRow("u2", {})).toEqual({
      id: "u2", name: "(sem nome)", email: "", isAdmin: false, isPending: false, teachingRole: "none",
    });
  });

  it("papel inválido vira 'none'", () => {
    expect(toMemberRow("u3", {teaching_role: "god"}).teachingRole).toBe("none");
  });
});

describe("filterMembers", () => {
  const rows: MemberRow[] = [
    {id: "1", name: "José Ávila", email: "jose@ipe.org", isAdmin: false, isPending: false, teachingRole: "none"},
    {id: "2", name: "Maria", email: "maria@exemplo.com", isAdmin: false, isPending: false, teachingRole: "teacher"},
  ];

  it("termo vazio devolve todos", () => {
    expect(filterMembers(rows, "  ")).toHaveLength(2);
  });

  it("busca por nome ou e-mail, sem diferenciar maiúsculas nem acentos", () => {
    expect(filterMembers(rows, "jose").map((r) => r.id)).toEqual(["1"]);
    expect(filterMembers(rows, "ÁVILA").map((r) => r.id)).toEqual(["1"]);
    expect(filterMembers(rows, "exemplo.com").map((r) => r.id)).toEqual(["2"]);
  });

  it("sem resultado devolve lista vazia", () => {
    expect(filterMembers(rows, "zzz")).toEqual([]);
  });
});
