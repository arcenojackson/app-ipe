import type {PlanField} from "./types";

const LESSON_ERROR = "A aula deve ser um número de 1 a 999.";

// Mesmos limites das regras do Firestore (validPlanRow).
export function validatePlanField(field: PlanField, value: string): string | null {
  const trimmed = value.trim();
  switch (field) {
    case "lesson": {
      const lesson = Number(trimmed);
      return /^\d+$/.test(trimmed) && lesson >= 1 && lesson <= 999 ? null : LESSON_ERROR;
    }
    case "theme":
      if (trimmed.length === 0) return "O tema não pode ficar vazio.";
      return trimmed.length > 200 ? "O tema pode ter no máximo 200 caracteres." : null;
    case "leader":
      return trimmed.length > 120 ? "O orientador pode ter no máximo 120 caracteres." : null;
    default:
      return trimmed.length > 2000 ? "O texto pode ter no máximo 2000 caracteres." : null;
  }
}

// `now` é o valor de serverTimestamp(), injetado para o construtor ficar puro.
export function planFieldPatch(
  i: {uid: string; field: PlanField; value: string},
  now: unknown
) {
  const value = i.value.trim();
  return {
    [i.field]: i.field === "lesson" ? Number(value) : value,
    updatedBy: i.uid,
    updatedAt: now,
  };
}

export function newPlanRowPayload(
  i: {uid: string; lesson: number; theme: string},
  now: unknown
) {
  return {lesson: i.lesson, theme: i.theme.trim(), updatedBy: i.uid, updatedAt: now};
}
