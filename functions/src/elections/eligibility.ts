import {fail} from "./common";
import type {Candidate} from "./types";

// Quem pode ser votado no 1º escrutínio de cada cargo: todos os membros da
// sociedade ou só os que já entraram na votação.
export type Eligibility = "all" | "present";

// Apps antigos não enviam o campo: ficam com o comportamento de sempre.
export const parseEligibility = (input: unknown): Eligibility => {
  if (input === undefined) return "all";
  if (input === "all" || input === "present") return input;
  throw fail("invalid-argument", "Opção inválida de quem pode ser votado.");
};

// Opções do 1º escrutínio. Em "present", só entram os membros cujo id está
// em `presentIds` (eleitores aprovados); quem não é membro nunca é candidato.
export const firstRoundPool = (
  eligibility: Eligibility | undefined,
  members: Candidate[],
  presentIds: ReadonlySet<string>
): Candidate[] =>
  eligibility === "present" ?
    members.filter((m) => presentIds.has(m.id)) :
    members;
