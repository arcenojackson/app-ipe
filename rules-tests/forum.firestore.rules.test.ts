import {afterAll, beforeAll, beforeEach, describe, it} from "vitest";
import {assertFails, assertSucceeds, type RulesTestEnvironment} from "@firebase/rules-unit-testing";
import {collection, deleteDoc, doc, getDoc, getDocs, serverTimestamp, setDoc, updateDoc} from "firebase/firestore";
import {createEnv} from "./env";

let env: RulesTestEnvironment;

const teacher = () => env.authenticatedContext("t1", {teaching_role: "teacher"}).firestore();
const teacher2 = () => env.authenticatedContext("t2", {teaching_role: "teacher"}).firestore();
const curator = () => env.authenticatedContext("c1", {teaching_role: "curator"}).firestore();
const adminOnly = () => env.authenticatedContext("a1", {admin: true}).firestore();
const plain = () => env.authenticatedContext("p1").firestore();
const anon = () => env.unauthenticatedContext().firestore();

beforeAll(async () => {
  env = await createEnv();
});

afterAll(async () => {
  await env.cleanup();
});

const baseTopic = (extra: Record<string, unknown> = {}) => ({
  title: "Dúvida sobre a aula 3", body: "Como vocês explicam isso?",
  authorUid: "t1", authorName: "Teresa", tagIds: [], refs: [], searchTokens: ["du", "duv"],
  pinned: false, locked: false, deleted: false, commentCount: 0,
  createdAt: new Date(0), updatedAt: new Date(0), lastActivityAt: new Date(0), ...extra,
});

const baseComment = (extra: Record<string, unknown> = {}) => ({
  body: "Eu explico assim", authorUid: "t2", authorName: "Tiago", parentId: null, depth: 1,
  refs: [], score: 0, deleted: false, createdAt: new Date(0), ...extra,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "forum_topics/top1"), baseTopic());
    await setDoc(doc(db, "forum_topics/locked"), baseTopic({locked: true}));
    await setDoc(doc(db, "forum_topics/gone"), baseTopic({deleted: true}));
    await setDoc(doc(db, "forum_topics/top1/comments/c1"), baseComment());
    await setDoc(doc(db, "forum_topics/top1/comments/c2"), baseComment({parentId: "c1", depth: 2, authorUid: "t1"}));
    await setDoc(doc(db, "forum_topics/top1/comments/c3"), baseComment({parentId: "c2", depth: 3}));
    await setDoc(doc(db, "forum_topics/top1/comments/dead"), baseComment({deleted: true}));
    await setDoc(doc(db, "forum_topics/locked/comments/lc"), baseComment());
    await setDoc(doc(db, "forum_topics/gone/comments/gc"), baseComment());
  });
});

const newTopic = (extra: Record<string, unknown> = {}) => ({
  ...baseTopic(), createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  lastActivityAt: serverTimestamp(), ...extra,
});

const newComment = (uid: string, extra: Record<string, unknown> = {}) => ({
  ...baseComment({authorUid: uid}), createdAt: serverTimestamp(), ...extra,
});

describe("forum — leitura", () => {
  it("professor, curador e admin leem; sem papel e anônimo não", async () => {
    await assertSucceeds(getDoc(doc(teacher(), "forum_topics/top1")));
    await assertSucceeds(getDocs(collection(curator(), "forum_topics")));
    await assertSucceeds(getDoc(doc(adminOnly(), "forum_topics/top1/comments/c1")));
    await assertFails(getDoc(doc(plain(), "forum_topics/top1")));
    await assertFails(getDoc(doc(anon(), "forum_topics/top1/comments/c1")));
  });
});

describe("forum — criar tópico", () => {
  it("válido passa", async () => {
    await assertSucceeds(setDoc(doc(teacher(), "forum_topics/n1"), newTopic()));
    await assertSucceeds(setDoc(doc(adminOnly(), "forum_topics/n2"), newTopic({authorUid: "a1"})));
  });

  it("limites exatos passam", async () => {
    await assertSucceeds(setDoc(doc(teacher(), "forum_topics/n3"), newTopic({
      title: "x".repeat(120), body: "y".repeat(5000), tagIds: ["a", "b", "c"],
      refs: [{kind: "library", id: "1", label: "A"}, {kind: "plan", id: "2", label: "B"}, {kind: "plan", id: "3", label: "C"}],
    })));
    await assertSucceeds(setDoc(doc(teacher(), "forum_topics/n4"), newTopic({title: "abc"})));
  });

  it("negado: sem papel, campos de moderação, contador, autor de outro, tempo do cliente, limites", async () => {
    await assertFails(setDoc(doc(plain(), "forum_topics/x"), newTopic({authorUid: "p1"})));
    await assertFails(setDoc(doc(teacher(), "forum_topics/x"), newTopic({pinned: true})));
    await assertFails(setDoc(doc(teacher(), "forum_topics/x"), newTopic({locked: true})));
    await assertFails(setDoc(doc(teacher(), "forum_topics/x"), newTopic({deleted: true})));
    await assertFails(setDoc(doc(teacher(), "forum_topics/x"), newTopic({commentCount: 1})));
    await assertFails(setDoc(doc(teacher(), "forum_topics/x"), newTopic({authorUid: "t2"})));
    await assertFails(setDoc(doc(teacher(), "forum_topics/x"), newTopic({createdAt: new Date(0)})));
    await assertFails(setDoc(doc(teacher(), "forum_topics/x"), newTopic({lastActivityAt: new Date(0)})));
    await assertFails(setDoc(doc(teacher(), "forum_topics/x"), newTopic({title: "ab"})));
    await assertFails(setDoc(doc(teacher(), "forum_topics/x"), newTopic({title: "x".repeat(121)})));
    await assertFails(setDoc(doc(teacher(), "forum_topics/x"), newTopic({body: ""})));
    await assertFails(setDoc(doc(teacher(), "forum_topics/x"), newTopic({body: "y".repeat(5001)})));
    await assertFails(setDoc(doc(teacher(), "forum_topics/x"), newTopic({tagIds: ["a", "b", "c", "d"]})));
    await assertFails(setDoc(doc(teacher(), "forum_topics/x"), newTopic({refs: [1, 2, 3, 4]})));
    await assertFails(setDoc(doc(teacher(), "forum_topics/x"), newTopic({extra: 1})));
  });
});

describe("forum — atualizar tópico", () => {
  it("autor edita conteúdo e apaga o próprio", async () => {
    await assertSucceeds(updateDoc(doc(teacher(), "forum_topics/top1"), {
      title: "Novo título", body: "Novo corpo", tagIds: ["a"], refs: [], searchTokens: ["no"],
      updatedAt: serverTimestamp(), editedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(teacher(), "forum_topics/top1"), {deleted: true}));
  });

  it("autor não mexe em moderação, contadores nem desfaz remoção", async () => {
    await assertFails(updateDoc(doc(teacher(), "forum_topics/top1"), {pinned: true}));
    await assertFails(updateDoc(doc(teacher(), "forum_topics/top1"), {locked: true}));
    await assertFails(updateDoc(doc(teacher(), "forum_topics/top1"), {commentCount: 5}));
    await assertFails(updateDoc(doc(teacher(), "forum_topics/top1"), {lastActivityAt: serverTimestamp()}));
    await assertFails(updateDoc(doc(teacher(), "forum_topics/top1"), {authorUid: "t2"}));
    await assertFails(updateDoc(doc(teacher(), "forum_topics/top1"), {title: "x"}));
    await assertFails(updateDoc(doc(teacher(), "forum_topics/gone"), {deleted: false}));
  });

  it("outro professor não edita nem apaga", async () => {
    await assertFails(updateDoc(doc(teacher2(), "forum_topics/top1"), {deleted: true}));
    await assertFails(updateDoc(doc(teacher2(), "forum_topics/top1"), {title: "Roubado"}));
  });

  it("curador e admin fixam, trancam e apagam; não reescrevem nem restauram", async () => {
    await assertSucceeds(updateDoc(doc(curator(), "forum_topics/top1"), {pinned: true}));
    await assertSucceeds(updateDoc(doc(curator(), "forum_topics/top1"), {locked: true, pinned: false}));
    await assertSucceeds(updateDoc(doc(adminOnly(), "forum_topics/top1"), {deleted: true}));
    await assertFails(updateDoc(doc(curator(), "forum_topics/top1"), {title: "Reescrito"}));
    await assertFails(updateDoc(doc(curator(), "forum_topics/gone"), {deleted: false}));
    await assertFails(updateDoc(doc(curator(), "forum_topics/top1"), {commentCount: 9}));
  });

  it("ninguém apaga o documento", async () => {
    await assertFails(deleteDoc(doc(teacher(), "forum_topics/top1")));
    await assertFails(deleteDoc(doc(curator(), "forum_topics/top1")));
    await assertFails(deleteDoc(doc(adminOnly(), "forum_topics/top1")));
  });
});

describe("forum — criar comentário", () => {
  const path = (id: string, topic = "top1") => `forum_topics/${topic}/comments/${id}`;

  it("raiz e respostas válidas passam", async () => {
    await assertSucceeds(setDoc(doc(teacher2(), path("n1")), newComment("t2")));
    await assertSucceeds(setDoc(doc(teacher2(), path("n2")), newComment("t2", {parentId: "c1", depth: 2})));
    await assertSucceeds(setDoc(doc(teacher2(), path("n3")), newComment("t2", {parentId: "c2", depth: 3})));
    await assertSucceeds(setDoc(doc(curator(), path("n4")), newComment("c1")));
    await assertSucceeds(setDoc(doc(adminOnly(), path("n5")), newComment("a1")));
  });

  it("negado: profundidade errada, pai inexistente/removido, nível 4", async () => {
    await assertFails(setDoc(doc(teacher2(), path("x")), newComment("t2", {parentId: "c1", depth: 1})));
    await assertFails(setDoc(doc(teacher2(), path("x")), newComment("t2", {parentId: "c1", depth: 3})));
    await assertFails(setDoc(doc(teacher2(), path("x")), newComment("t2", {parentId: null, depth: 2})));
    await assertFails(setDoc(doc(teacher2(), path("x")), newComment("t2", {parentId: "nao-existe", depth: 2})));
    await assertFails(setDoc(doc(teacher2(), path("x")), newComment("t2", {parentId: "dead", depth: 2})));
    await assertFails(setDoc(doc(teacher2(), path("x")), newComment("t2", {parentId: "c3", depth: 4})));
  });

  it("negado: tópico trancado, removido ou inexistente", async () => {
    await assertFails(setDoc(doc(teacher2(), path("x", "locked")), newComment("t2")));
    await assertFails(setDoc(doc(teacher2(), path("x", "gone")), newComment("t2")));
    await assertFails(setDoc(doc(teacher2(), path("x", "nope")), newComment("t2")));
  });

  it("negado: sem papel, autor de outro, score, removido, corpo e refs inválidos, tempo do cliente", async () => {
    await assertFails(setDoc(doc(plain(), path("x")), newComment("p1")));
    await assertFails(setDoc(doc(teacher2(), path("x")), newComment("t1")));
    await assertFails(setDoc(doc(teacher2(), path("x")), newComment("t2", {score: 1})));
    await assertFails(setDoc(doc(teacher2(), path("x")), newComment("t2", {deleted: true})));
    await assertFails(setDoc(doc(teacher2(), path("x")), newComment("t2", {body: ""})));
    await assertFails(setDoc(doc(teacher2(), path("x")), newComment("t2", {body: "y".repeat(5001)})));
    await assertFails(setDoc(doc(teacher2(), path("x")), newComment("t2", {refs: [1, 2, 3, 4]})));
    await assertFails(setDoc(doc(teacher2(), path("x")), newComment("t2", {createdAt: new Date(0)})));
    await assertFails(setDoc(doc(teacher2(), path("x")), newComment("t2", {extra: 1})));
  });
});

describe("forum — atualizar comentário", () => {
  const p = "forum_topics/top1/comments/c1";

  it("autor edita e apaga o próprio", async () => {
    await assertSucceeds(updateDoc(doc(teacher2(), p), {body: "Editado", refs: [], editedAt: serverTimestamp()}));
    await assertSucceeds(updateDoc(doc(teacher2(), p), {deleted: true}));
  });

  it("curador e admin só apagam", async () => {
    await assertSucceeds(updateDoc(doc(curator(), p), {deleted: true}));
    await assertSucceeds(updateDoc(doc(adminOnly(), p), {deleted: true}));
    await assertFails(updateDoc(doc(curator(), p), {body: "Reescrito"}));
  });

  it("negado: outro professor, score, restaurar, apagar o doc", async () => {
    await assertFails(updateDoc(doc(teacher(), p), {deleted: true}));
    await assertFails(updateDoc(doc(teacher2(), p), {score: 10}));
    await assertFails(updateDoc(doc(teacher2(), p), {body: ""}));
    await assertFails(updateDoc(doc(teacher2(), "forum_topics/top1/comments/dead"), {deleted: false}));
    await assertFails(deleteDoc(doc(teacher2(), p)));
    await assertFails(deleteDoc(doc(curator(), p)));
  });
});

describe("forum — votos", () => {
  const vote = (topic: string, comment: string, uid: string) =>
    `forum_topics/${topic}/comments/${comment}/votes/${uid}`;

  it("vota 👍 e 👎, troca e retira o voto", async () => {
    await assertSucceeds(setDoc(doc(teacher(), vote("top1", "c1", "t1")), {value: 1}));
    await assertSucceeds(setDoc(doc(teacher(), vote("top1", "c1", "t1")), {value: -1}));
    await assertSucceeds(deleteDoc(doc(teacher(), vote("top1", "c1", "t1"))));
    await assertSucceeds(setDoc(doc(curator(), vote("top1", "c1", "c1")), {value: 1}));
  });

  it("negado: valor inválido, doc de outro, campo extra, sem papel", async () => {
    await assertFails(setDoc(doc(teacher(), vote("top1", "c1", "t1")), {value: 0}));
    await assertFails(setDoc(doc(teacher(), vote("top1", "c1", "t1")), {value: 2}));
    await assertFails(setDoc(doc(teacher(), vote("top1", "c1", "t1")), {value: "1"}));
    await assertFails(setDoc(doc(teacher(), vote("top1", "c1", "t2")), {value: 1}));
    await assertFails(setDoc(doc(teacher(), vote("top1", "c1", "t1")), {value: 1, extra: 1}));
    await assertFails(setDoc(doc(plain(), vote("top1", "c1", "p1")), {value: 1}));
  });

  it("negado: no próprio comentário, em tópico trancado/removido e em comentário removido", async () => {
    await assertFails(setDoc(doc(teacher2(), vote("top1", "c1", "t2")), {value: 1}));
    await assertFails(setDoc(doc(teacher(), vote("locked", "lc", "t1")), {value: 1}));
    await assertFails(setDoc(doc(teacher(), vote("gone", "gc", "t1")), {value: 1}));
    await assertFails(setDoc(doc(teacher(), vote("top1", "dead", "t1")), {value: 1}));
  });

  it("lê só o próprio voto", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), vote("top1", "c1", "t1")), {value: 1});
    });
    await assertSucceeds(getDoc(doc(teacher(), vote("top1", "c1", "t1"))));
    await assertFails(getDoc(doc(teacher2(), vote("top1", "c1", "t1"))));
  });
});
