import {afterAll, beforeAll, beforeEach, describe, it} from "vitest";
import {assertFails, assertSucceeds, type RulesTestEnvironment} from "@firebase/rules-unit-testing";
import {collection, deleteDoc, doc, getDoc, getDocs, serverTimestamp, setDoc, updateDoc} from "firebase/firestore";
import {createEnv} from "./env";

let env: RulesTestEnvironment;

const teacher = () => env.authenticatedContext("t1", {teaching_role: "teacher"}).firestore();
const curator = () => env.authenticatedContext("c1", {teaching_role: "curator"}).firestore();
const adminOnly = () => env.authenticatedContext("a1", {admin: true}).firestore();
const plain = () => env.authenticatedContext("p1").firestore();

beforeAll(async () => {
  env = await createEnv();
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "teaching_plan/aula-01"), {
      lesson: 1, theme: "O que é ser cristão?", updatedBy: "c1", updatedAt: new Date(0),
    });
  });
});

const row = (uid: string, extra: Record<string, unknown> = {}) => ({
  lesson: 2, theme: "A Bíblia: Palavra de Deus", leader: "Yara", knowledge: "Inspiração",
  skills: "Ler", essentials: "Reconhecer", notes: "", references: "",
  updatedBy: uid, updatedAt: serverTimestamp(), ...extra,
});

describe("teaching_plan — leitura", () => {
  it("professor, curador e admin leem; sem papel não lê", async () => {
    await assertSucceeds(getDoc(doc(teacher(), "teaching_plan/aula-01")));
    await assertSucceeds(getDocs(collection(curator(), "teaching_plan")));
    await assertSucceeds(getDoc(doc(adminOnly(), "teaching_plan/aula-01")));
    await assertFails(getDoc(doc(plain(), "teaching_plan/aula-01")));
  });
});

describe("teaching_plan — escrita", () => {
  it("curador cria e atualiza linhas válidas", async () => {
    await assertSucceeds(setDoc(doc(curator(), "teaching_plan/aula-02"), row("c1")));
    await assertSucceeds(updateDoc(doc(curator(), "teaching_plan/aula-01"), {
      theme: "Novo tema", updatedBy: "c1", updatedAt: serverTimestamp(),
    }));
  });

  it("professor e admin sem papel de curador não escrevem nem apagam", async () => {
    await assertFails(setDoc(doc(teacher(), "teaching_plan/aula-02"), row("t1")));
    await assertFails(updateDoc(doc(teacher(), "teaching_plan/aula-01"), {theme: "X", updatedBy: "t1", updatedAt: serverTimestamp()}));
    await assertFails(setDoc(doc(adminOnly(), "teaching_plan/aula-02"), row("a1")));
    await assertFails(deleteDoc(doc(teacher(), "teaching_plan/aula-01")));
    await assertFails(deleteDoc(doc(adminOnly(), "teaching_plan/aula-01")));
  });

  it("curador apaga uma linha", async () => {
    await assertSucceeds(deleteDoc(doc(curator(), "teaching_plan/aula-01")));
  });

  it("negado: updatedBy de outro, sem updatedAt do servidor, campo extra, tema vazio, aula inválida, texto longo", async () => {
    await assertFails(setDoc(doc(curator(), "teaching_plan/a"), row("c1", {updatedBy: "c9"})));
    await assertFails(setDoc(doc(curator(), "teaching_plan/b"), row("c1", {updatedAt: new Date(0)})));
    await assertFails(setDoc(doc(curator(), "teaching_plan/c"), row("c1", {status: "x"})));
    await assertFails(setDoc(doc(curator(), "teaching_plan/d"), row("c1", {theme: ""})));
    await assertFails(setDoc(doc(curator(), "teaching_plan/e"), row("c1", {lesson: 0})));
    await assertFails(setDoc(doc(curator(), "teaching_plan/f"), row("c1", {lesson: "2"})));
    await assertFails(setDoc(doc(curator(), "teaching_plan/g"), row("c1", {notes: "x".repeat(2001)})));
    await assertFails(setDoc(doc(curator(), "teaching_plan/h"), row("c1", {leader: "x".repeat(121)})));
  });

  it("campos de texto são opcionais", async () => {
    await assertSucceeds(setDoc(doc(curator(), "teaching_plan/aula-03"), {
      lesson: 3, theme: "Só o tema", updatedBy: "c1", updatedAt: serverTimestamp(),
    }));
  });
});
