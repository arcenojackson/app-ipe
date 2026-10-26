import * as admin from "firebase-admin";
import {expect} from "vitest";

const PROJECT = "demo-ipe-elections";
if (!admin.apps.length) admin.initializeApp({projectId: PROJECT});

export const db = admin.firestore();

export const ADMIN = "admin1";
export const DIRECTOR = "d1";
export const DIRECTOR2 = "d2";
export const OTHER_DIRECTOR = "od1";
export const MEMBER = "m1";
export const MEMBER2 = "m2";
export const MEMBER3 = "m3";
export const OUTSIDER = "out1";
export const SOCIETY = "s1";
export const OTHER_SOCIETY = "s2";
export const ELECTION = "e1";

export const clearDb = async (): Promise<void> => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(
    `http://${host}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,
    {method: "DELETE"}
  );
};

// Usuários, sociedade s1 (m1, m2, m3) e eleição e1 (aberta por padrão).
export const seedBase = async (status = "open"): Promise<void> => {
  await db.doc(`users/${ADMIN}`).set({name: "Admin", is_admin: true});
  await db.doc(`users/${MEMBER}`).set({name: "Ana", is_admin: false});
  await db.doc(`users/${MEMBER2}`).set({name: "Bia", is_admin: false});
  await db.doc(`users/${MEMBER3}`).set({name: "Caio", is_admin: false});
  await db.doc(`users/${OUTSIDER}`).set({name: "Fora", is_admin: false});
  // Diretores NÃO são is_admin de propósito: o acesso vem da diretoria.
  await db.doc(`users/${DIRECTOR}`).set({name: "Diretora", is_admin: false});
  await db.doc(`users/${DIRECTOR2}`).set({name: "Vice", is_admin: false});
  await db.doc(`users/${OTHER_DIRECTOR}`).set({name: "Outro", is_admin: false});
  await db.doc(`societies/${OTHER_SOCIETY}`).set({
    name: "UPH",
    members: [],
    board: {presidente: [OTHER_DIRECTOR]},
  });
  await db.doc(`societies/${SOCIETY}`).set({
    name: "UMP",
    members: [MEMBER, MEMBER2, MEMBER3],
    board: {presidente: [DIRECTOR], vice: [DIRECTOR2]},
  });
  await db.doc(`elections/${ELECTION}`).set({
    societyId: SOCIETY,
    societyName: "UMP",
    title: "Eleição 2026",
    status,
    positions: ["presidente", "vice", "secretario", "secretario2", "tesoureiro"],
    directorIds: [DIRECTOR, DIRECTOR2],
  });
};

export const expectCode = async (
  promise: Promise<unknown>,
  code: string
): Promise<void> => {
  await expect(promise).rejects.toMatchObject({code});
};
