import type {CandidateVotes, CargoStage} from "../types";

export type ConductActionKind =
  | "start"
  | "close"
  | "removeCandidate"
  | "restart"
  | "pickOldest";

export interface ConductAction {
  kind: ConductActionKind;
  label: string;
  targetId?: string;
}

export interface CargoViewInput {
  stage: CargoStage;
  candidates: CandidateVotes[];
  tiedIds: string[];
  winnerName?: string;
}

/** Texto e botões de cada fase do cargo. Pura: a tela só desenha o resultado. */
export function cargoView(
  input: CargoViewInput
): {title: string; actions: ConductAction[]} {
  const {stage, candidates, tiedIds, winnerName} = input;
  switch (stage) {
    case "idle":
      return {
        title: "Não iniciado",
        actions: [{kind: "start", label: "Iniciar 1º escrutínio"}],
      };
    case "scrutiny1":
    case "scrutiny2":
    case "scrutiny3":
      return {
        title: `${stage.slice(-1)}º escrutínio em andamento`,
        actions: [{kind: "close", label: "Encerrar escrutínio"}],
      };
    case "confirming":
      if (candidates.length === 0) {
        return {
          title: "Sem candidatos",
          actions: [{kind: "restart", label: "Reiniciar cargo"}],
        };
      }
      return {
        title: "Confirmação dos candidatos",
        actions: [
          ...candidates.map((c) => ({
            kind: "removeCandidate" as const,
            label: "Remover como candidato",
            targetId: c.id,
          })),
          {kind: "start", label: "Iniciar 2º escrutínio"},
        ],
      };
    case "awaiting3":
      return {
        title: "Ninguém atingiu a maioria",
        actions: [{kind: "start", label: "Iniciar 3º escrutínio"}],
      };
    case "tiebreak":
      return {
        title: "Empate: escolha o mais velho",
        actions: tiedIds.map((id) => ({
          kind: "pickOldest" as const,
          label: `Mais velho: ${candidates.find((c) => c.id === id)?.name ?? id}`,
          targetId: id,
        })),
      };
    case "decided":
      return {title: `Eleito(a): ${winnerName ?? ""}`, actions: []};
  }
}
