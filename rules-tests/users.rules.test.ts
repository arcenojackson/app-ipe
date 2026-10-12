import {afterAll, beforeAll, beforeEach, describe, it} from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {deleteField, doc, getDoc, setDoc, updateDoc} from "firebase/firestore";
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
    await setDoc(doc(db, "users/teacher1"), {
      name: "Téo",
      is_admin: false,
      teaching_role: "teacher",
    });
  });
});

describe("regras de users", () => {
  it("usuário autenticado lê usuários; anônimo não", async () => {
    await assertSucceeds(getDoc(doc(env.authenticatedContext("user1").firestore(), "users/user2")));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), "users/user2")));
  });

  it("usuário atualiza o próprio nome", async () => {
    const db = env.authenticatedContext("user1").firestore();
    await assertSucceeds(updateDoc(doc(db, "users/user1"), {name: "Ana Maria"}));
  });

  it("atualização completa que mantém is_admin igual é permitida", async () => {
    const db = env.authenticatedContext("user1").firestore();
    await assertSucceeds(updateDoc(doc(db, "users/user1"), {name: "Ana", is_admin: false}));
  });

  it("usuário NÃO vira admin editando o próprio documento", async () => {
    const db = env.authenticatedContext("user1").firestore();
    await assertFails(updateDoc(doc(db, "users/user1"), {is_admin: true}));
    await assertFails(updateDoc(doc(db, "users/user1"), {isAdmin: true}));
  });

  it("usuário NÃO se atribui teaching_role", async () => {
    const db = env.authenticatedContext("user1").firestore();
    await assertFails(updateDoc(doc(db, "users/user1"), {teaching_role: "curator"}));
  });

  it("usuário NÃO edita o documento de outro usuário", async () => {
    const db = env.authenticatedContext("user1").firestore();
    await assertFails(updateDoc(doc(db, "users/user2"), {name: "Hack"}));
  });

  it("criação do próprio documento sem privilégios é permitida", async () => {
    const db = env.authenticatedContext("novo").firestore();
    await assertSucceeds(setDoc(doc(db, "users/novo"), {name: "Novo", is_admin: false, is_pending: true}));
  });

  it("criação com is_admin true ou teaching_role é negada", async () => {
    const db = env.authenticatedContext("novo").firestore();
    await assertFails(setDoc(doc(db, "users/novo"), {name: "Novo", is_admin: true}));
    await assertFails(setDoc(doc(db, "users/novo"), {name: "Novo", is_admin: false, teaching_role: "teacher"}));
  });

  it("admin atribui teaching_role válido a outro usuário", async () => {
    const db = env.authenticatedContext("admin1").firestore();
    await assertSucceeds(updateDoc(doc(db, "users/user1"), {teaching_role: "teacher"}));
    await assertSucceeds(updateDoc(doc(db, "users/user1"), {teaching_role: "curator"}));
    await assertSucceeds(updateDoc(doc(db, "users/user1"), {teaching_role: "none"}));
  });

  it("admin NÃO grava teaching_role inválido", async () => {
    const db = env.authenticatedContext("admin1").firestore();
    await assertFails(updateDoc(doc(db, "users/user1"), {teaching_role: "god"}));
  });

  it("admin continua alternando is_admin (comportamento atual do app)", async () => {
    const db = env.authenticatedContext("admin1").firestore();
    await assertSucceeds(updateDoc(doc(db, "users/user1"), {is_admin: true}));
  });

  describe("professor editando o próprio documento", () => {
    it("atualiza campos não protegidos", async () => {
      const db = env.authenticatedContext("teacher1").firestore();
      await assertSucceeds(updateDoc(doc(db, "users/teacher1"), {fcmToken: "tok"}));
      await assertSucceeds(updateDoc(doc(db, "users/teacher1"), {name: "Téo Silva"}));
    });

    it("NÃO muda o próprio teaching_role para curator", async () => {
      const db = env.authenticatedContext("teacher1").firestore();
      await assertFails(updateDoc(doc(db, "users/teacher1"), {teaching_role: "curator"}));
    });

    it("NÃO apaga o campo teaching_role", async () => {
      const db = env.authenticatedContext("teacher1").firestore();
      await assertFails(updateDoc(doc(db, "users/teacher1"), {teaching_role: deleteField()}));
    });
  });
});
