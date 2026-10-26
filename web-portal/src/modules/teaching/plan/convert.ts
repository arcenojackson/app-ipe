import type {PlanRow} from "./types";

const text = (value: unknown): string => (typeof value === "string" ? value : "");

export function toPlanRow(id: string, data: Record<string, unknown>): PlanRow | null {
  if (typeof data.lesson !== "number" || typeof data.theme !== "string") return null;
  return {
    id,
    lesson: data.lesson,
    theme: data.theme,
    leader: text(data.leader),
    knowledge: text(data.knowledge),
    skills: text(data.skills),
    essentials: text(data.essentials),
    notes: text(data.notes),
    references: text(data.references),
  };
}
