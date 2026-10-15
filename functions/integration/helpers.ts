import * as admin from "firebase-admin";
import {expect} from "vitest";

const PROJECT = "demo-ipe-elections";
if (!admin.apps.length) admin.initializeApp({projectId: PROJECT});

export const db = admin.firestore();

export const ADMIN = "admin1";
export const MEMBER = "m1";
export const MEMBER2 = "m2";
export const MEMBER3 = "m3";
export const OUTSIDER = "out1";
export const SOCIETY = "s1";
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
  await db.doc(`societies/${SOCIETY}`).set({
    name: "UMP",
    members: [MEMBER, MEMBER2, MEMBER3],
    board: {presidente: ["old"], vice: ["v1"]},
  });
  await db.doc(`elections/${ELECTION}`).set({
    societyId: SOCIETY,
    societyName: "UMP",
    title: "Eleição 2026",
    status,
    positions: ["presidente", "vice", "secretario", "tesoureiro"],
  });
};

export const expectCode = async (
  promise: Promise<unknown>,
  code: string
): Promise<void> => {
  await expect(promise).rejects.toMatchObject({code});
};
