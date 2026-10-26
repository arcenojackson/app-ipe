import {afterAll, beforeAll, beforeEach, describe, expect, it} from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  addDoc, collection, collectionGroup, deleteDoc, doc, getDoc, getDocs, query,
  setDoc, updateDoc, where,
} from "firebase/firestore";
import {createEnv} from "./env";

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await createEnv();
});
afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users/admin1"), {is_admin: true});
    await setDoc(doc(db, "elections/e1"), {status: "open", title: "t", directorIds: ["dir1", "dir2"]});
    await setDoc(doc(db, "elections/e2"), {status: "open", title: "outra", directorIds: ["dirX"]});
    await setDoc(doc(db, "elections/e1/cargos/presidente"), {stage: "idle", cycle: 1});
    await setDoc(doc(db, "elections/e1/rounds/r1"), {position: "presidente", status: "open", options: []});
    await setDoc(doc(db, "elections/e1/voters/user1"), {status: "approved"});
    await setDoc(doc(db, "elections/e1/voters/other"), {status: "approved"});
    await setDoc(doc(db, "elections/e1/rounds/r1/voted/user1"), {});
    await setDoc(doc(db, "elections/e1/rounds/r1/voted/other"), {});
    await setDoc(doc(db, "elections/e1/rounds/r1/ballots/b1"), {choice: "x"});
    await setDoc(doc(db, "elections/e1/events/ev1"), {type: "checkin"});
  });
});

const dir = () => env.authenticatedContext("dir1").firestore();
const otherDir = () => env.authenticatedContext("dirX").firestore();
const admin = () => env.authenticatedContext("admin1").firestore();
const user = () => env.authenticatedContext("user1").firestore();
const anon = () => env.authenticatedContext("anon9", {firebase: {sign_in_provider: "anonymous"}}).firestore();
const noAuth = () => env.unauthenticatedContext().firestore();

const mine = (db: ReturnType<typeof dir>, uid: string) =>
  query(collection(db, "elections"), where("directorIds", "array-contains", uid));

describe("elections (documento)", () => {
  it("get é público", async () => {
    await assertSucceeds(getDoc(doc(noAuth(), "elections/e1")));
    await assertSucceeds(getDoc(doc(anon(), "elections/e1")));
  });

  it("list pela consulta do próprio uid: o diretor vê só as suas; quem não é diretor vê nada", async () => {
    const mineSnap = await assertSucceeds(getDocs(mine(dir(), "dir1")));
    expect(mineSnap.docs.map((d) => d.id)).toEqual(["e1"]);
    const noneSnap = await assertSucceeds(getDocs(mine(user(), "user1")));
    expect(noneSnap.empty).toBe(true);
  });

  it("não lista eleições alheias: consulta com o uid de outro diretor ou sem filtro falha", async () => {
    await assertFails(getDocs(mine(otherDir(), "dir1")));
    await assertFails(getDocs(collection(dir(), "elections")));
    await assertFails(getDocs(collection(admin(), "elections")));
    await assertFails(getDocs(collection(noAuth(), "elections")));
  });

  it("ninguém escreve: nem diretor, nem admin global", async () => {
    for (const db of [dir(), admin(), user(), anon()]) {
      await assertFails(setDoc(doc(db, "elections/novo"), {status: "draft", directorIds: ["dir1"]}));
      await assertFails(updateDoc(doc(db, "elections/e1"), {title: "x"}));
      await assertFails(deleteDoc(doc(db, "elections/e1")));
    }
  });
});

describe("rounds, cargos, voters, voted, events, ballots", () => {
  it("rounds: leitura para qualquer autenticado (inclusive anônimo do Firebase), nunca sem login", async () => {
    await assertSucceeds(getDoc(doc(user(), "elections/e1/rounds/r1")));
    await assertSucceeds(getDoc(doc(anon(), "elections/e1/rounds/r1")));
    await assertFails(getDoc(doc(noAuth(), "elections/e1/rounds/r1")));
  });

  it("cargos: só os diretores da eleição leem", async () => {
    await assertSucceeds(getDoc(doc(dir(), "elections/e1/cargos/presidente")));
    await assertFails(getDoc(doc(user(), "elections/e1/cargos/presidente")));
    await assertFails(getDoc(doc(otherDir(), "elections/e1/cargos/presidente")));
    await assertFails(getDoc(doc(admin(), "elections/e1/cargos/presidente")));
  });

  it("voters: o eleitor lê o próprio; o diretor lê todos; outros não", async () => {
    await assertSucceeds(getDoc(doc(user(), "elections/e1/voters/user1")));
    await assertFails(getDoc(doc(user(), "elections/e1/voters/other")));
    await assertSucceeds(getDoc(doc(dir(), "elections/e1/voters/other")));
    await assertSucceeds(getDocs(collection(dir(), "elections/e1/voters")));
    await assertFails(getDoc(doc(otherDir(), "elections/e1/voters/other")));
    await assertFails(getDoc(doc(admin(), "elections/e1/voters/other")));
    await assertFails(getDocs(collection(user(), "elections/e1/voters")));
  });

  it("voted: o eleitor lê o próprio; o diretor lê a lista (quem votou); outros não", async () => {
    await assertSucceeds(getDoc(doc(user(), "elections/e1/rounds/r1/voted/user1")));
    await assertFails(getDoc(doc(user(), "elections/e1/rounds/r1/voted/other")));
    await assertSucceeds(getDocs(collection(dir(), "elections/e1/rounds/r1/voted")));
    await assertFails(getDocs(collection(otherDir(), "elections/e1/rounds/r1/voted")));
    await assertFails(getDocs(collection(admin(), "elections/e1/rounds/r1/voted")));
  });

  it("events: só os diretores leem", async () => {
    await assertSucceeds(getDoc(doc(dir(), "elections/e1/events/ev1")));
    await assertSucceeds(getDocs(collection(dir(), "elections/e1/events")));
    await assertFails(getDoc(doc(user(), "elections/e1/events/ev1")));
    await assertFails(getDoc(doc(admin(), "elections/e1/events/ev1")));
  });

  it("ballots: ninguém lê, nem o diretor, nem em consulta de grupo", async () => {
    await assertFails(getDoc(doc(dir(), "elections/e1/rounds/r1/ballots/b1")));
    await assertFails(getDocs(collection(dir(), "elections/e1/rounds/r1/ballots")));
    await assertFails(getDocs(collectionGroup(dir(), "ballots")));
    await assertFails(getDoc(doc(user(), "elections/e1/rounds/r1/ballots/b1")));
  });

  it("nenhuma escrita em nenhuma subcoleção, nem pelo diretor nem pelo admin", async () => {
    const paths = [
      "elections/e1/cargos/presidente",
      "elections/e1/rounds/r1",
      "elections/e1/voters/user1",
      "elections/e1/rounds/r1/voted/user1",
      "elections/e1/events/ev1",
      "elections/e1/rounds/r1/ballots/b1",
    ];
    for (const db of [dir(), admin(), user()]) {
      for (const path of paths) {
        await assertFails(setDoc(doc(db, path), {x: 1}));
        await assertFails(updateDoc(doc(db, path), {x: 1}));
        await assertFails(deleteDoc(doc(db, path)));
      }
      await assertFails(addDoc(collection(db, "elections/e1/rounds"), {x: 1}));
      await assertFails(addDoc(collection(db, "elections/e1/events"), {x: 1}));
    }
  });
});
