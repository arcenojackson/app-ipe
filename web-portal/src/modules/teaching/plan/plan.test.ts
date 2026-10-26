import {describe, expect, it} from "vitest";
import {toPlanRow} from "./convert";
import {planFieldPatch, newPlanRowPayload, validatePlanField} from "./payloads";

const NOW = "AGORA";

describe("toPlanRow", () => {
  it("converte o documento e usa texto vazio para campos ausentes", () => {
    expect(toPlanRow("aula-02", {lesson: 2, theme: "A Bíblia", leader: "Yara", knowledge: "Inspiração"})).toEqual({
      id: "aula-02", lesson: 2, theme: "A Bíblia", leader: "Yara", knowledge: "Inspiração",
      skills: "", essentials: "", notes: "", references: "",
    });
  });

  it("ignora documentos sem aula numérica ou sem tema", () => {
    expect(toPlanRow("x", {theme: "Sem aula"})).toBeNull();
    expect(toPlanRow("y", {lesson: 3})).toBeNull();
    expect(toPlanRow("z", {lesson: "3", theme: "T"})).toBeNull();
  });
});

describe("validatePlanField", () => {
  it("tema não pode ficar vazio nem passar de 200 caracteres", () => {
    expect(validatePlanField("theme", "  ")).toBe("O tema não pode ficar vazio.");
    expect(validatePlanField("theme", "x".repeat(201))).toBe("O tema pode ter no máximo 200 caracteres.");
    expect(validatePlanField("theme", "Trindade")).toBeNull();
  });

  it("aula é inteiro de 1 a 999", () => {
    expect(validatePlanField("lesson", "0")).toBe("A aula deve ser um número de 1 a 999.");
    expect(validatePlanField("lesson", "1,5")).toBe("A aula deve ser um número de 1 a 999.");
    expect(validatePlanField("lesson", "abc")).toBe("A aula deve ser um número de 1 a 999.");
    expect(validatePlanField("lesson", "1000")).toBe("A aula deve ser um número de 1 a 999.");
    expect(validatePlanField("lesson", "12")).toBeNull();
  });

  it("orientador até 120 e demais textos até 2000, podendo ficar vazios", () => {
    expect(validatePlanField("leader", "x".repeat(121))).toBe("O orientador pode ter no máximo 120 caracteres.");
    expect(validatePlanField("notes", "x".repeat(2001))).toBe("O texto pode ter no máximo 2000 caracteres.");
    expect(validatePlanField("notes", "")).toBeNull();
  });
});

describe("planFieldPatch", () => {
  it("altera só o campo e quem alterou; aula vira número; texto é aparado", () => {
    expect(planFieldPatch({uid: "c1", field: "theme", value: "  Novo  "}, NOW)).toEqual({
      theme: "Novo", updatedBy: "c1", updatedAt: NOW,
    });
    expect(planFieldPatch({uid: "c1", field: "lesson", value: "7"}, NOW)).toEqual({
      lesson: 7, updatedBy: "c1", updatedAt: NOW,
    });
    expect(planFieldPatch({uid: "c1", field: "notes", value: ""}, NOW)).toEqual({
      notes: "", updatedBy: "c1", updatedAt: NOW,
    });
  });
});

describe("newPlanRowPayload", () => {
  it("só aula, tema e quem criou (os demais campos são opcionais nas regras)", () => {
    expect(newPlanRowPayload({uid: "c1", lesson: 53, theme: "Novo tema"}, NOW)).toEqual({
      lesson: 53, theme: "Novo tema", updatedBy: "c1", updatedAt: NOW,
    });
  });
});
