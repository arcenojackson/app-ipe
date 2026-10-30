import * as admin from "firebase-admin";
import {computeTeachingClaims} from "../src/teaching/claims";
import {PLAN_SEED} from "../src/teaching/planSeed";
import {TAG_SEED} from "../src/teaching/tagSeed";
import {LOCAL_PROJECT_ID} from "./lib/target";

// Popula os EMULADORES (Auth + Firestore) com dados fictícios para
// desenvolvimento local. Idempotente: pode rodar quantas vezes quiser.
// Recusa rodar se os emuladores não estiverem configurados, para nunca
// escrever em produção. Uso: `npm run seed:local` (com os emuladores no ar).

export const LOCAL_PASSWORD = "senha123";

interface SeedUser {
  uid: string;
  name: string;
  email: string;
  isAdmin?: boolean;
  isPending?: boolean;
  teachingRole?: "teacher" | "curator";
}

const USERS: SeedUser[] = [
  {uid: "u-admin", name: "Ana Admin", email: "admin@ipe.test",
    isAdmin: true, teachingRole: "curator"},
  {uid: "u-curador", name: "Carlos Curador", email: "curador@ipe.test",
    teachingRole: "curator"},
  {uid: "u-professor", name: "Paula Professora", email: "professor@ipe.test",
    teachingRole: "teacher"},
  {uid: "u-membro", name: "Marcos Membro", email: "membro@ipe.test"},
  {uid: "u-louvor", name: "Lívia Louvor", email: "louvor@ipe.test"},
  {uid: "u-pendente", name: "Pedro Pendente", email: "pendente@ipe.test",
    isPending: true},
];

const SOCIETIES = [
  {
    id: "soc-uph", name: "UPH", description: "União Presbiterial de Homens",
    color: 0xff1565c0, userId: "u-admin",
    members: ["u-admin", "u-membro"],
    board: {presidente: ["u-admin"], vice: ["u-membro"]},
    vocais: [], ministros: [],
  },
  {
    id: "soc-elo", name: "ELO", description: "Equipe de louvor",
    color: 0xff2e7d32, userId: "u-admin",
    members: ["u-louvor", "u-membro"],
    board: {presidente: ["u-louvor"]},
    vocais: ["u-louvor"], ministros: ["u-membro"],
  },
];

const MUSICS = [
  ["m-1", "Castelo Forte", "Martinho Lutero", "D"],
  ["m-2", "Grandioso És Tu", "Hino 8", "G"],
  ["m-3", "Em Espírito e em Verdade", "Livres para Adorar", "E"],
  ["m-4", "Rocha Eterna", "Hinário Novo Cântico", "A"],
].map(([id, title, artist, tone]) => ({
  id, title, artist, tone, cipher: "", category: "", minorTone: false,
  status: "avaliar", selected_times: [],
}));

/**
 * Próximo dia da semana (0 = domingo) às `hour` horas, em ISO local.
 * @param {number} weekday - dia da semana desejado
 * @param {number} hour - hora do dia
 * @param {number} weeksAhead - semanas adicionais
 * @return {string} data em ISO 8601
 */
function nextWeekday(weekday: number, hour: number, weeksAhead = 0): string {
  const d = new Date();
  d.setHours(hour, 0, 0, 0);
  d.setDate(d.getDate() + ((weekday + 7 - d.getDay()) % 7) + weeksAhead * 7);
  return d.toISOString();
}

const SERVICES = [0, 1, 2].map((week) => ({
  id: `svc-${week + 1}`,
  name: "Culto de Domingo",
  date: nextWeekday(0, 18, week),
  start: "18:00",
  steps: [
    {title: "Oração inicial", description: null, duration: 5, type: "step",
      musicId: null, musicTone: null},
    {title: "Louvor", description: null, duration: 4, type: "music",
      musicId: `m-${(week % 4) + 1}`, musicTone: "D"},
    {title: "Sermão", description: null, duration: 40, type: "step",
      musicId: null, musicTone: null},
  ],
  people: {
    elo: ["u-louvor"], preacher: ["u-admin"], lead: ["u-membro"],
    soundImage: [], diaconia: [], eloWithInstruments: {},
  },
  teams: {liturgia: "soc-uph", lanche: "soc-elo"},
  templateId: null,
}));

/**
 * Cria ou atualiza o usuário no Auth e no Firestore, com as claims.
 * @param {SeedUser} u - usuário fictício
 * @return {Promise<void>} conclusão
 */
async function seedUser(u: SeedUser): Promise<void> {
  const auth = admin.auth();
  const profile = {
    email: u.email, password: LOCAL_PASSWORD, displayName: u.name,
    emailVerified: true,
  };
  try {
    await auth.updateUser(u.uid, profile);
  } catch (e) {
    if ((e as {code?: string}).code !== "auth/user-not-found") throw e;
    await auth.createUser({uid: u.uid, ...profile});
  }
  const doc = {
    id: u.uid, name: u.name, email: u.email,
    is_admin: u.isAdmin === true, is_pending: u.isPending === true,
    ...(u.teachingRole ? {teaching_role: u.teachingRole} : {}),
  };
  await admin.firestore().collection("users").doc(u.uid).set(doc);
  // A Function syncTeachingClaimsOnUserWrite faria o mesmo, mas gravamos aqui
  // para o seed funcionar mesmo sem o emulador de Functions no ar.
  await auth.setCustomUserClaims(u.uid, computeTeachingClaims(doc));
}

/**
 * Grava vários documentos de uma coleção (sobrescreve por id).
 * @param {string} collection - nome da coleção
 * @param {Array<{id: string}>} docs - documentos com `id`
 * @return {Promise<void>} conclusão
 */
async function seedCollection(
  collection: string,
  docs: Array<{id: string} & Record<string, unknown>>
): Promise<void> {
  const firestore = admin.firestore();
  const batch = firestore.batch();
  for (const {id, ...data} of docs) {
    batch.set(firestore.collection(collection).doc(id), data);
  }
  await batch.commit();
  console.log(`  ${collection}: ${docs.length}`);
}

async function main(): Promise<void> {
  if (!process.env.FIRESTORE_EMULATOR_HOST ||
      !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    console.error(
      "Abortado: este script só roda contra os emuladores. Defina " +
      "FIRESTORE_EMULATOR_HOST e FIREBASE_AUTH_EMULATOR_HOST (o comando " +
      "`npm run seed`, na raiz do repo, já faz isso)."
    );
    process.exit(1);
  }
  const projectId = process.env.GCLOUD_PROJECT ?? LOCAL_PROJECT_ID;
  if (!projectId.startsWith("demo-")) {
    console.error(`Abortado: projeto "${projectId}" não é um projeto demo-*.`);
    process.exit(1);
  }
  admin.initializeApp({projectId});
  console.log(`Populando emuladores (${projectId})...`);

  for (const u of USERS) await seedUser(u);
  console.log(`  auth + users: ${USERS.length}`);
  await seedCollection("societies", SOCIETIES);
  await seedCollection("musics", MUSICS);
  await seedCollection("services", SERVICES);
  await seedCollection("teaching_tags", TAG_SEED.map((t) => ({...t})));
  await seedCollection("teaching_plan", PLAN_SEED.map((p) => ({
    ...p, updatedBy: "seed",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  })));

  console.log("\nPronto. Contas de teste (senha: " + LOCAL_PASSWORD + "):");
  for (const u of USERS) console.log(`  ${u.email}  — ${u.name}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
