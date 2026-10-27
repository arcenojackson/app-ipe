import {FieldValue, Timestamp, type Firestore} from "firebase-admin/firestore";
import {applyWinners} from "./board";
import {logEvent} from "./common";

// Brasília não tem horário de verão desde 2019: São Paulo é UTC-3 o ano todo.
const SAO_PAULO_OFFSET_HOURS = 3;

// Início (00:00 em São Paulo) do próximo 01/01 depois de `now`. As eleições
// acontecem entre outubro e dezembro, mas a diretoria só assume no ano
// seguinte; a rotina de 01/01 ao meio-dia já encontra essa data vencida.
export const nextTermStart = (now: Date): Date => {
  const saoPauloYear = new Date(
    now.getTime() - SAO_PAULO_OFFSET_HOURS * 3600 * 1000
  ).getUTCFullYear();
  return new Date(Date.UTC(saoPauloYear + 1, 0, 1, SAO_PAULO_OFFSET_HOURS));
};

export const isDue = (effectiveAt: Date, now: Date): boolean =>
  effectiveAt.getTime() <= now.getTime();

export interface ApplyDueResult {
  applied: string[];
  failed: {electionId: string; reason: string}[];
}

const failedReason = (current: unknown): string | null =>
  Array.isArray(current) && current.length > 0 ?
    "Diretoria em formato antigo (sem cargos)." :
    null;

// Aplica, na diretoria de cada sociedade, as eleições pendentes cuja data de
// vigência já chegou. Uma sociedade com problema vira `failed` e não impede
// as outras.
export const applyDueBoards = async (
  db: Firestore,
  now: Date = new Date()
): Promise<ApplyDueResult> => {
  const pending = await db.collection("boardTransitions")
    .where("status", "==", "pending").get();
  const result: ApplyDueResult = {applied: [], failed: []};

  const due = pending.docs
    .filter((d) => isDue((d.get("effectiveAt") as Timestamp).toDate(), now))
    .sort((a, b) =>
      (a.get("createdAt") as Timestamp).toMillis() -
      (b.get("createdAt") as Timestamp).toMillis());

  for (const doc of due) {
    const electionId = doc.id;
    try {
      const winners = await db.runTransaction(async (tx) => {
        const transition = await tx.get(doc.ref);
        if (transition.get("status") !== "pending") return null;
        const societyRef = db.doc(`societies/${transition.get("societyId")}`);
        const society = await tx.get(societyRef);
        if (!society.exists) throw new Error("Sociedade não encontrada.");
        const current = society.get("board");
        const reason = failedReason(current);
        if (reason) throw new Error(reason);
        const w = transition.get("winners") as Record<string, string>;
        tx.update(societyRef, {board: applyWinners(current, w)});
        tx.update(doc.ref, {
          status: "applied",
          appliedAt: FieldValue.serverTimestamp(),
        });
        return w;
      });
      if (winners) {
        result.applied.push(electionId);
        await logEvent(db, electionId, {
          type: "board_applied", actorId: "system", winners,
        });
      }
    } catch (e) {
      const reason = e instanceof Error ? e.message : String(e);
      result.failed.push({electionId, reason});
      await doc.ref.update({status: "failed", failedReason: reason});
      console.error(
        `Diretoria da eleição ${electionId} não aplicada: ${reason}`
      );
    }
  }
  return result;
};
