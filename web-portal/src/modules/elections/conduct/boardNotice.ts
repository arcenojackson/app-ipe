import {positionLabel} from "../types";

/** Aviso depois de registrar a diretoria eleita: ela só assume na data de
 *  vigência (01/01), e a falta de cargo obrigatório é um aviso, não um erro. */
export function boardNotice(res: {
  missingRequired: string[];
  effectiveAtMs: number;
}): string {
  const date = new Date(res.effectiveAtMs).toLocaleDateString("pt-BR", {
    timeZone: "America/Sao_Paulo",
  });
  const base = `Diretoria registrada. Assume em ${date}.`;
  return res.missingRequired.length > 0 ?
    `${base} Faltam cargos obrigatórios: ${res.missingRequired.map(positionLabel).join(", ")}` :
    base;
}
