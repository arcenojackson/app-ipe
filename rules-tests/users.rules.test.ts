// Guarda de regressão: documenta o comportamento ATUAL das regras de `users`.
// Este é o comportamento de produção, deliberadamente mantido sem alteração por
// decisão de produto (o gerenciamento de papéis fica a cargo do app Flutter).
// Não endurecer estas regras sem alinhar com o app em produção.
import {afterAll, beforeAll, beforeEach, describe, it} from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {doc, getDoc, setDoc, updateDoc} from "firebase/firestore";
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
    await setDoc(doc(db, "users/admin1"), {name: "Admin", is_admin: true});
    await setDoc(doc(db, "users/user1"), {name: "Ana", is_admin: false});
    await setDoc(doc(db, "users/user2"), {name: "Bia", is_admin: false});
  });
});

describe("regras de users (comportamento de produção)", () => {
  it("usuário autenticado lê usuários", async () => {
    await assertSucceeds(getDoc(doc(env.authenticatedContext("user1").firestore(), "users/user2")));
  });

  it("anônimo não lê usuários", async () => {
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), "users/user2")));
  });

  it("usuário atualiza o próprio nome", async () => {
    const db = env.authenticatedContext("user1").firestore();
    await assertSucceeds(updateDoc(doc(db, "users/user1"), {name: "Ana Maria"}));
  });

  it("usuário não atualiza o documento de outro usuário", async () => {
    const db = env.authenticatedContext("user1").firestore();
    await assertFails(updateDoc(doc(db, "users/user2"), {name: "Hack"}));
  });

  it("admin atualiza is_admin de outro usuário", async () => {
    const db = env.authenticatedContext("admin1").firestore();
    await assertSucceeds(updateDoc(doc(db, "users/user1"), {is_admin: true}));
  });
});
