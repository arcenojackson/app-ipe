import {describe, expect, it} from "vitest";
import {TAG_SEED} from "../src/teaching/tagSeed";

const names = (kind: string) =>
  TAG_SEED.filter((t) => t.kind === kind).map((t) => t.name);

describe("TAG_SEED", () => {
  it("tem 6 tipos, 25 assuntos e 7 faixas", () => {
    expect(names("type")).toHaveLength(6);
    expect(names("subject")).toHaveLength(25);
    expect(names("age")).toHaveLength(7);
    expect(TAG_SEED).toHaveLength(38);
  });

  it("faixas e tipos têm os nomes exatos da spec, na ordem", () => {
    expect(names("age")).toEqual(["UCP", "UPA", "UMP", "ADULTOS", "CASAIS", "SAF", "HOMENS"]);
    expect(names("type")).toEqual([
      "Sermões", "Recursos pedagógicos", "Fichamentos e resumos", "Bibliografia", "Aulas", "Artigos",
    ]);
    expect(names("subject")[0]).toBe("Identidade cristã e evangelho");
    expect(names("subject")[24]).toBe("Escatologia e vida futura");
  });

  it("ids únicos, com prefixo do tipo e só [a-z0-9-]", () => {
    const ids = TAG_SEED.map((t) => t.id);
    expect(new Set(ids).size).toBe(ids.length);
    const prefix = {type: "tipo", subject: "assunto", age: "faixa"} as const;
    for (const tag of TAG_SEED) {
      expect(tag.id).toMatch(new RegExp(`^${prefix[tag.kind]}-[a-z0-9-]+$`));
      expect(tag.id).not.toMatch(/--|-$/);
    }
    expect(TAG_SEED.find((t) => t.name === "Sermões")?.id).toBe("tipo-sermoes");
    expect(TAG_SEED.find((t) => t.name === "UMP")?.id).toBe("faixa-ump");
  });

  it("order de cada tipo é 1..n sem buracos e todas ativas", () => {
    for (const kind of ["type", "subject", "age"]) {
      const orders = TAG_SEED.filter((t) => t.kind === kind).map((t) => t.order);
      expect(orders).toEqual(orders.map((_, i) => i + 1));
    }
    expect(TAG_SEED.every((t) => t.active)).toBe(true);
  });
});
