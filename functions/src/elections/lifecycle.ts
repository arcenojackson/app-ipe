import {FieldValue, Timestamp, type Firestore} from "firebase-admin/firestore";
import {fail, logEvent, requireString} from "./common";
import {assertElectionDirector, directorIdsOf} from "./directors";
import {nextTermStart} from "./transitions";
import {normalizePositions, REQUIRED_POSITIONS} from "./positions";

// Cria a eleição em rascunho. Só quem está na diretoria *atual* da sociedade
// cria; a lista de diretores vira o snapshot `directorIds` da eleição.
export const createElection = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<{electionId: string}> => {
  const societyId = requireString(data, "societyId");
  const title = requireString(data, "title");
  const scheduledAtMs = (data as {scheduledAtMs?: unknown}).scheduledAtMs;
  if (typeof scheduledAtMs !== "number" || !Number.isFinite(scheduledAtMs)) {
    throw fail("invalid-argument", "Informe a data e a hora da eleição.");
  }
  const positions = normalizePositions(
    (data as {positions?: unknown}).positions
  );

  const society = await db.doc(`societies/${societyId}`).get();
  if (!society.exists) throw fail("not-found", "Sociedade não encontrada.");
  const directorIds = directorIdsOf(society.get("board"));
  if (directorIds.length === 0) {
    throw fail(
      "failed-precondition",
      "A sociedade não tem diretoria cadastrada. " +
        "Cadastre a diretoria em Sociedades antes de criar a eleição."
    );
  }
  if (!directorIds.includes(uid)) {
    throw fail(
      "permission-denied",
      "Apenas os diretores desta sociedade podem criar a eleição."
    );
  }

  const electionRef = db.collection("elections").doc();
  const batch = db.batch();
  batch.set(electionRef, {
    societyId,
    societyName: String(society.get("name") ?? ""),
    title,
    scheduledAt: Timestamp.fromMillis(scheduledAtMs),
    status: "draft",
    positions,
    directorIds,
    createdBy: uid,
    createdAt: FieldValue.serverTimestamp(),
  });
  for (const position of positions) {
    batch.set(electionRef.collection("cargos").doc(position), {
      stage: "idle",
      cycle: 1,
      candidates: [],
      tiedIds: [],
      winnerId: null,
    });
  }
  await batch.commit();
  await logEvent(db, electionRef.id, {type: "election_created", actorId: uid});
  return {electionId: electionRef.id};
};

// Registra os eleitos (cargos `decided`) como diretoria em espera em
// `boardTransitions/{electionId}`. Quem assume é a rotina de 01/01
// (`applyDueBoards`); aqui a diretoria atual não muda. Pode ser repetido até
// a diretoria assumir: o registro é substituído.
export const applyBoard = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<{
  winners: Record<string, string>;
  missingRequired: string[];
  effectiveAtMs: number;
}> => {
  const electionId = requireString(data, "electionId");
  const election = await assertElectionDirector(db, uid, electionId);

  const cargos = await db.collection(`elections/${electionId}/cargos`).get();
  const winners: Record<string, string> = {};
  for (const cargo of cargos.docs) {
    if (cargo.get("stage") === "decided" && cargo.get("winnerId")) {
      winners[cargo.id] = String(cargo.get("winnerId"));
    }
  }
  if (Object.keys(winners).length === 0) {
    throw fail("failed-precondition", "Nenhum cargo foi decidido ainda.");
  }

  const societyRef = db.doc(`societies/${election.societyId}`);
  const transitionRef = db.doc(`boardTransitions/${electionId}`);
  const electionRef = db.doc(`elections/${electionId}`);
  const effectiveAt = nextTermStart(new Date());
  await db.runTransaction(async (tx) => {
    const society = await tx.get(societyRef);
    if (!society.exists) throw fail("not-found", "Sociedade não encontrada.");
    const current = society.get("board");
    if (Array.isArray(current) && current.length > 0) {
      throw fail(
        "failed-precondition",
        "A diretoria desta sociedade está no formato antigo (sem cargos). " +
          "Defina os cargos em Sociedades antes de registrar a eleição."
      );
    }
    const existing = await tx.get(transitionRef);
    if (existing.exists && existing.get("status") === "applied") {
      throw fail(
        "failed-precondition", "Esta diretoria já assumiu na sociedade."
      );
    }
    tx.set(transitionRef, {
      electionId,
      societyId: election.societyId,
      societyName: String(society.get("name") ?? ""),
      winners,
      effectiveAt: Timestamp.fromDate(effectiveAt),
      status: "pending",
      createdBy: uid,
      createdAt: existing.exists ?
        existing.get("createdAt") :
        FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.update(electionRef, {boardAppliedAt: FieldValue.serverTimestamp()});
  });
  await logEvent(db, electionId, {
    type: "board_scheduled",
    actorId: uid,
    winners,
    effectiveAtMs: effectiveAt.getTime(),
  });
  return {
    winners,
    missingRequired: REQUIRED_POSITIONS.filter((p) => !(p in winners)),
    effectiveAtMs: effectiveAt.getTime(),
  };
};

export const setElectionStatus = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<void> => {
  const electionId = requireString(data, "electionId");
  const target = requireString(data, "status");
  const election = await assertElectionDirector(db, uid, electionId);
  if (target !== "open" && target !== "closed") {
    throw fail("invalid-argument", "Status inválido.");
  }
  const ref = db.doc(`elections/${electionId}`);

  if (target === "open") {
    if (election.status !== "draft") {
      throw fail(
        "failed-precondition", "Só é possível abrir uma eleição em rascunho."
      );
    }
    await ref.update({status: "open", openedAt: FieldValue.serverTimestamp()});
  } else {
    if (election.status !== "open") {
      throw fail(
        "failed-precondition", "Só é possível encerrar uma eleição aberta."
      );
    }
    const open = await ref.collection("rounds")
      .where("status", "==", "open").limit(1).get();
    if (!open.empty) {
      throw fail(
        "failed-precondition",
        "Encerre a votação em andamento antes de encerrar a eleição."
      );
    }
    await ref.update({
      status: "closed", closedAt: FieldValue.serverTimestamp(),
    });
  }
  await logEvent(db, electionId, {
    type: target === "open" ? "election_opened" : "election_closed",
    actorId: uid,
  });
};
