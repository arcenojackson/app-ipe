import {PUBLICATION_ACTIONS, latestPerVoter} from "./decide";
import type {ItemDoc, VoteDoc} from "./types";

/**
 * Curadores que aprovaram a versão atual do item: último voto de cada
 * votante, sem o autor. Mesma regra de decidePublication (o papel de cada
 * um hoje não é conferido: é histórico).
 * @param {ItemDoc} item Item publicado.
 * @param {VoteDoc[]} votes Votos do item.
 * @return {string[]} Uids dos aprovadores.
 */
export function approversOf(item: ItemDoc, votes: VoteDoc[]): string[] {
  const eligible = votes.filter(
    (v) =>
      PUBLICATION_ACTIONS.includes(v.action) &&
      v.version === item.version &&
      v.voterId !== item.authorId
  );
  return latestPerVoter(eligible)
    .filter((v) => v.action === "approve")
    .map((v) => v.voterId);
}

export interface ApprovedByPlan {
  itemId: string;
  approvedBy: string[];
}

/**
 * Plano do backfill: só itens publicados sem approvedBy e com ao menos um
 * aprovador encontrado (idempotente: o que já tem o campo não entra).
 * @param {Array} entries Itens com seus votos e o approvedBy já gravado.
 * @return {ApprovedByPlan[]} Escritas a fazer.
 */
export function planApprovedBy(
  entries: Array<{item: ItemDoc; votes: VoteDoc[]; current?: unknown}>
): ApprovedByPlan[] {
  const plan: ApprovedByPlan[] = [];
  for (const {item, votes, current} of entries) {
    if (item.status !== "published" || Array.isArray(current)) continue;
    const approvedBy = approversOf(item, votes);
    if (approvedBy.length > 0) plan.push({itemId: item.id, approvedBy});
  }
  return plan;
}
