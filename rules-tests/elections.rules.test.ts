import {afterAll, beforeAll, beforeEach, describe, it} from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  addDoc, collection, deleteDoc, doc, getDoc, getDocs, setDoc, updateDoc,
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
    await setDoc(doc(db, "users/user1"), {is_admin: false});
    await setDoc(doc(db, "elections/draft1"), {status: "draft", title: "t"});
    await setDoc(doc(db, "elections/open1"), {status: "open", title: "t"});
    await setDoc(doc(db, "elections/draft1/rounds/pend"), {status: "pending", position: "vice", candidates: [], type: "normal"});
    await setDoc(doc(db, "elections/open1/rounds/live"), {status: "open", position: "vice", candidates: [], type: "normal"});
    await setDoc(doc(db, "elections/open1/voters/user1"), {status: "approved"});
    await setDoc(doc(db, "elections/open1/voters/other"), {status: "approved"});
    await setDoc(doc(db, "elections/open1/rounds/live/voted/user1"), {});
    await setDoc(doc(db, "elections/open1/rounds/live/voted/other"), {});
    await setDoc(doc(db, "elections/open1/rounds/live/ballots/b1"), {choice: "x"});
    await setDoc(doc(db, "elections/open1/events/ev1"), {type: "checkin"});
  });
});

const admin = () => env.authenticatedContext("admin1").firestore();
const user = () => env.authenticatedContext("user1").firestore();
const anon = () => env.authenticatedContext("anon9", {firebase: {sign_in_provider: "anonymous"}}).firestore();
const noAuth = () => env.unauthenticatedContext().firestore();

describe("elections", () => {
  it("get do documento é público; list só para admin", async () => {
    await assertSucceeds(getDoc(doc(noAuth(), "elections/open1")));
    await assertFails(getDocs(collection(noAuth(), "elections")));
    await assertFails(getDocs(collection(anon(), "elections")));
    await assertFails(getDocs(collection(user(), "elections")));
    await assertSucceeds(getDocs(collection(admin(), "elections")));
  });

  it("admin cria rascunho; outros e status diferente de draft, não", async () => {
    await assertSucceeds(setDoc(doc(admin(), "elections/new1"), {status: "draft", title: "n"}));
    await assertFails(setDoc(doc(user(), "elections/new2"), {status: "draft", title: "n"}));
    await assertFails(setDoc(doc(admin(), "elections/new3"), {status: "open", title: "n"}));
  });

  it("admin edita só rascunho e não muda o status pelo cliente", async () => {
    await assertSucceeds(updateDoc(doc(admin(), "elections/draft1"), {title: "novo"}));
    await assertFails(updateDoc(doc(admin(), "elections/draft1"), {status: "open"}));
    await assertFails(updateDoc(doc(admin(), "elections/open1"), {title: "novo"}));
    await assertFails(updateDoc(doc(user(), "elections/draft1"), {title: "novo"}));
  });

  it("só admin exclui, e só rascunho", async () => {
    await assertSucceeds(deleteDoc(doc(admin(), "elections/draft1")));
    await assertFails(deleteDoc(doc(admin(), "elections/open1")));
    await assertFails(deleteDoc(doc(user(), "elections/draft1")));
  });
});

describe("elections/rounds", () => {
  it("leitura exige login (anônimo do Firebase vale)", async () => {
    await assertSucceeds(getDoc(doc(anon(), "elections/open1/rounds/live")));
    await assertFails(getDoc(doc(noAuth(), "elections/open1/rounds/live")));
  });

  it("admin cria rodada pendente em eleição draft/open; nunca com outro status", async () => {
    const data = {status: "pending", position: "presidente", candidates: [], type: "normal"};
    await assertSucceeds(setDoc(doc(admin(), "elections/draft1/rounds/n1"), data));
    await assertSucceeds(setDoc(doc(admin(), "elections/open1/rounds/n2"), data));
    await assertFails(setDoc(doc(admin(), "elections/open1/rounds/n3"), {...data, status: "open"}));
    await assertFails(setDoc(doc(user(), "elections/open1/rounds/n4"), data));
  });

  it("admin edita candidatos só de rodada pendente e não muda status/resultado", async () => {
    const pend = doc(admin(), "elections/draft1/rounds/pend");
    await assertSucceeds(updateDoc(pend, {candidates: [{id: "a", name: "A"}]}));
    await assertFails(updateDoc(pend, {status: "open"}));
    await assertFails(updateDoc(pend, {result: {winnerId: "a"}}));
    await assertFails(updateDoc(doc(admin(), "elections/open1/rounds/live"), {candidates: []}));
    await assertFails(updateDoc(doc(user(), "elections/draft1/rounds/pend"), {candidates: []}));
  });

  it("exclui só rodada pendente, só admin", async () => {
    await assertSucceeds(deleteDoc(doc(admin(), "elections/draft1/rounds/pend")));
    await assertFails(deleteDoc(doc(admin(), "elections/open1/rounds/live")));
  });
});

describe("voters, voted, ballots, events", () => {
  it("eleitor lê só o próprio documento; admin lê todos; ninguém escreve", async () => {
    await assertSucceeds(getDoc(doc(user(), "elections/open1/voters/user1")));
    await assertFails(getDoc(doc(user(), "elections/open1/voters/other")));
    await assertSucceeds(getDoc(doc(admin(), "elections/open1/voters/other")));
    await assertFails(setDoc(doc(user(), "elections/open1/voters/user1"), {status: "approved"}));
    await assertFails(updateDoc(doc(admin(), "elections/open1/voters/other"), {status: "rejected"}));
  });

  it("eleitor pode ler o próprio voted (e não o dos outros); ninguém escreve", async () => {
    await assertSucceeds(getDoc(doc(user(), "elections/open1/rounds/live/voted/user1")));
    await assertFails(getDoc(doc(user(), "elections/open1/rounds/live/voted/other")));
    await assertFails(setDoc(doc(user(), "elections/open1/rounds/live/voted/new"), {}));
    await assertFails(setDoc(doc(admin(), "elections/open1/rounds/live/voted/new"), {}));
  });

  it("ballots: nenhuma leitura nem escrita, nem para o admin", async () => {
    await assertFails(getDoc(doc(admin(), "elections/open1/rounds/live/ballots/b1")));
    await assertFails(getDocs(collection(admin(), "elections/open1/rounds/live/ballots")));
    await assertFails(addDoc(collection(admin(), "elections/open1/rounds/live/ballots"), {choice: "x"}));
    await assertFails(getDoc(doc(user(), "elections/open1/rounds/live/ballots/b1")));
  });

  it("events: só admin lê; ninguém escreve", async () => {
    await assertSucceeds(getDoc(doc(admin(), "elections/open1/events/ev1")));
    await assertFails(getDoc(doc(user(), "elections/open1/events/ev1")));
    await assertFails(addDoc(collection(admin(), "elections/open1/events"), {type: "x"}));
  });
});
