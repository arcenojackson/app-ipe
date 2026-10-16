import {afterAll, beforeAll, describe, it} from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {doc, setDoc} from "firebase/firestore";
import {deleteObject, getBytes, ref, uploadBytes} from "firebase/storage";
import {createEnv} from "./env";

let env: RulesTestEnvironment;
const bytes = new Uint8Array([1, 2, 3]);
const pdf = {contentType: "application/pdf"};
const p = (id: string, name = "aula.pdf") => `teaching/materials/${id}/${name}`;

const teacher = () => env.authenticatedContext("t1", {teaching_role: "teacher"}).storage();
const other = () => env.authenticatedContext("t2", {teaching_role: "teacher"}).storage();
const curator = () => env.authenticatedContext("c1", {teaching_role: "curator"}).storage();
const admin = () => env.authenticatedContext("a1", {admin: true}).storage();
const plain = () => env.authenticatedContext("p1").storage();
const anon = () => env.unauthenticatedContext().storage();

beforeAll(async () => {
  env = await createEnv();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const base = {type: "file", parentId: null, name: "Aula", version: 1};
    await setDoc(doc(db, "teaching_items/pub"), {...base, authorId: "t1", status: "published"});
    await setDoc(doc(db, "teaching_items/rev"), {...base, authorId: "t1", status: "in_review"});
    await setDoc(doc(db, "teaching_items/ret"), {...base, authorId: "t1", status: "returned"});
    for (const id of ["pub", "rev", "ret", "orphan"]) {
      await uploadBytes(ref(ctx.storage(), p(id)), bytes, pdf);
    }
  });
});

afterAll(async () => {
  await env.cleanup();
});

describe("leitura (consulta o item no Firestore)", () => {
  it("item publicado: professor, curador e admin leem; sem papel e anônimo não", async () => {
    await assertSucceeds(getBytes(ref(other(), p("pub"))));
    await assertSucceeds(getBytes(ref(curator(), p("pub"))));
    await assertSucceeds(getBytes(ref(admin(), p("pub"))));
    await assertFails(getBytes(ref(plain(), p("pub"))));
    await assertFails(getBytes(ref(anon(), p("pub"))));
  });

  it("item em revisão: só o autor, curador e admin leem; outro professor não", async () => {
    await assertSucceeds(getBytes(ref(teacher(), p("rev"))));
    await assertSucceeds(getBytes(ref(curator(), p("rev"))));
    await assertSucceeds(getBytes(ref(admin(), p("rev"))));
    await assertFails(getBytes(ref(other(), p("rev"))));
  });

  it("item devolvido: só o autor, curador e admin leem", async () => {
    await assertSucceeds(getBytes(ref(teacher(), p("ret"))));
    await assertSucceeds(getBytes(ref(curator(), p("ret"))));
    await assertFails(getBytes(ref(other(), p("ret"))));
  });

  it("objeto sem item no Firestore não é legível por ninguém", async () => {
    await assertFails(getBytes(ref(teacher(), p("orphan"))));
    await assertFails(getBytes(ref(curator(), p("orphan"))));
    await assertFails(getBytes(ref(admin(), p("orphan"))));
  });
});

describe("criação, sobrescrita e exclusão", () => {
  it("professor envia PDF, Office e imagem como objetos novos", async () => {
    await assertSucceeds(uploadBytes(ref(teacher(), p("n1", "a.pdf")), bytes, pdf));
    await assertSucceeds(uploadBytes(ref(teacher(), p("n1", "b.docx")), bytes, {
      contentType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    }));
    await assertSucceeds(uploadBytes(ref(teacher(), p("n1", "c.png")), bytes, {contentType: "image/png"}));
  });

  it("curador também envia objetos novos", async () => {
    await assertSucceeds(uploadBytes(ref(curator(), p("n2", "a.pdf")), bytes, pdf));
  });

  it("sem papel e anônimo não enviam; tipo fora da lista é negado", async () => {
    await assertFails(uploadBytes(ref(plain(), p("n3", "a.pdf")), bytes, pdf));
    await assertFails(uploadBytes(ref(anon(), p("n3", "a.pdf")), bytes, pdf));
    await assertFails(uploadBytes(ref(teacher(), p("n3", "x.exe")), bytes, {
      contentType: "application/x-msdownload",
    }));
  });

  it("arquivo acima de 100 MB é negado", async () => {
    const big = new Uint8Array(100 * 1024 * 1024 + 1);
    await assertFails(uploadBytes(ref(teacher(), p("n4", "big.pdf")), big, pdf));
  }, 120_000);

  it("ninguém sobrescreve objeto existente pelo cliente (nem curador ou admin)", async () => {
    await assertFails(uploadBytes(ref(teacher(), p("pub")), bytes, pdf));
    await assertFails(uploadBytes(ref(curator(), p("pub")), bytes, pdf));
    await assertFails(uploadBytes(ref(admin(), p("pub")), bytes, pdf));
  });

  it("ninguém apaga pelo cliente (nem curador ou admin)", async () => {
    await assertFails(deleteObject(ref(teacher(), p("pub"))));
    await assertFails(deleteObject(ref(curator(), p("pub"))));
    await assertFails(deleteObject(ref(admin(), p("pub"))));
  });

  it("outros caminhos do bucket seguem negados", async () => {
    await assertFails(uploadBytes(ref(teacher(), "outros/a.pdf"), bytes, pdf));
  });
});
