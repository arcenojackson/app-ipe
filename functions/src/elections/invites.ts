import type {MulticastMessage} from "firebase-admin/messaging";
import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {getElection} from "./common";

export const OPEN_NOTIFICATION_TYPE = "election_open";

// O Firestore limita lotes a 500 escritas; o FCM, a 500 tokens por envio.
const CHUNK = 500;

const chunks = <T>(items: T[], size: number): T[][] => {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
};

// A eleição só "abre" na passagem de rascunho para aberta. Qualquer outra
// atualização do documento (ex.: gravar `openedAt`) não avisa ninguém.
export const isOpening = (
  before: {status?: unknown} | undefined,
  after: {status?: unknown} | undefined
): boolean => before?.status === "draft" && after?.status === "open";

// Caminho do convite de cada membro: é o que o balão da home lê.
export const invitePaths = (electionId: string, uids: string[]): string[] =>
  uids.map((uid) => `users/${uid}/election_invites/${electionId}`);

export const buildOpenMessage = (
  title: string,
  electionId: string,
  tokens: string[]
): MulticastMessage => ({
  notification: {
    title: "Eleição aberta",
    // Autossuficiente: quem está com versão antiga do app recebe o mesmo
    // texto, sem o fluxo de votação.
    body: `${title}. Abra o app para votar; ` +
      "se não abrir a votação, atualize o app.",
  },
  data: {type: OPEN_NOTIFICATION_TYPE, electionId},
  tokens,
  android: {priority: "high"},
  apns: {payload: {aps: {sound: "default"}}},
});

// Ao abrir a eleição: grava um convite no espaço de cada membro (o balão da
// home lê só o próprio) e manda o push a quem tem token e não desativou o
// tipo. Idempotente nos convites; falha de push não desfaz os convites.
export const inviteMembers = async (
  db: Firestore,
  electionId: string,
  send: (message: MulticastMessage) => Promise<unknown>
): Promise<{invited: number; notified: number}> => {
  const election = await getElection(db, electionId);
  const society = await db.doc(`societies/${election.societyId}`).get();
  const members = [
    ...new Set<string>((society.get("members") ?? []).map(String)),
  ];
  if (members.length === 0) return {invited: 0, notified: 0};

  const title = String(election.title ?? "");
  const societyName = String(election.societyName ?? society.get("name") ?? "");

  for (const group of chunks(members, CHUNK)) {
    const batch = db.batch();
    for (const uid of group) {
      batch.set(db.doc(`users/${uid}/election_invites/${electionId}`), {
        electionId, title, societyName,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  const tokens: string[] = [];
  for (const group of chunks(members, CHUNK)) {
    const docs = await db.getAll(...group.map((uid) => db.doc(`users/${uid}`)));
    for (const doc of docs) {
      const token = doc.get("fcmToken");
      const disabled: unknown[] = doc.get("disabled_notifications") ?? [];
      if (typeof token !== "string" || token === "") continue;
      if (disabled.includes(OPEN_NOTIFICATION_TYPE)) continue;
      tokens.push(token);
    }
  }

  let notified = 0;
  for (const group of chunks(tokens, CHUNK)) {
    try {
      await send(buildOpenMessage(title, electionId, group));
      notified += group.length;
    } catch (error) {
      console.error("Falha ao enviar o push de eleição aberta:", error);
    }
  }
  return {invited: members.length, notified};
};
