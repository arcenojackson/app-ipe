import {fail} from "./common";

// Cargos de uma eleição, na ordem canônica.
export const POSITIONS = [
  "presidente",
  "vice",
  "secretario",
  "secretario2",
  "tesoureiro",
] as const;

export const REQUIRED_POSITIONS = ["presidente", "vice"] as const;

// Valida a lista de cargos escolhida ao criar a eleição: só cargos conhecidos,
// sem repetição, na ordem canônica, sempre com presidente e vice.
export const normalizePositions = (input: unknown): string[] => {
  if (!Array.isArray(input)) {
    throw fail("invalid-argument", "Informe a lista de cargos.");
  }
  const known: readonly string[] = POSITIONS;
  for (const item of input) {
    if (typeof item !== "string" || !known.includes(item)) {
      throw fail("invalid-argument", `Cargo desconhecido: ${String(item)}.`);
    }
  }
  const chosen = new Set(input as string[]);
  for (const required of REQUIRED_POSITIONS) {
    if (!chosen.has(required)) {
      throw fail("invalid-argument", `O cargo ${required} é obrigatório.`);
    }
  }
  return POSITIONS.filter((p) => chosen.has(p));
};
