import {describe, expect, it} from "vitest";
import {PLAN_SEED} from "../src/teaching/planSeed";

describe("PLAN_SEED (planilha Planejamento_Pedagógico_UPA)", () => {
  it("tem 52 linhas, aulas 1 a 52 em ordem, ids aula-01 a aula-52", () => {
    expect(PLAN_SEED).toHaveLength(52);
    expect(PLAN_SEED.map((r) => r.lesson)).toEqual(Array.from({length: 52}, (_, i) => i + 1));
    expect(PLAN_SEED[0].id).toBe("aula-01");
    expect(PLAN_SEED[51].id).toBe("aula-52");
    expect(new Set(PLAN_SEED.map((r) => r.id)).size).toBe(52);
  });

  it("todas têm tema, objetos de conhecimento, habilidade e aprendizagem", () => {
    for (const row of PLAN_SEED) {
      expect(row.theme.length).toBeGreaterThan(0);
      expect(row.knowledge?.length).toBeGreaterThan(0);
      expect(row.skills?.length).toBeGreaterThan(0);
      expect(row.essentials?.length).toBeGreaterThan(0);
    }
  });

  it("reproduz exatamente algumas linhas da planilha", () => {
    expect(PLAN_SEED[0].theme).toBe("O que é ser cristão?");
    expect(PLAN_SEED[5]).toMatchObject({lesson: 6, theme: "Os cinco Solas", leader: "Yara"});
    expect(PLAN_SEED[1].notes).toContain("Cânon Bíblico");
    expect(PLAN_SEED[51].theme).toBe("Minha vida diante de Deus");
  });

  it("orientadores só onde a planilha tem (6, 12, 25, 30, 34, 44, 45)", () => {
    const withLeader = PLAN_SEED.filter((r) => r.leader).map((r) => [r.lesson, r.leader]);
    expect(withLeader).toEqual([
      [6, "Yara"], [12, "Lyla"], [25, "Karen"], [30, "Felipe"], [34, "Állan"], [44, "Guilherme"], [45, "Guilherme"],
    ]);
  });
});
