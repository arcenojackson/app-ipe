import {afterAll, beforeAll, describe, it} from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {deleteObject, getBytes, ref, uploadBytes} from "firebase/storage";
import {createEnv} from "./env";

let env: RulesTestEnvironment;
const path = "teaching/materials/m1/aula.pdf";
const pdf = {contentType: "application/pdf"};
const bytes = new Uint8Array([1, 2, 3]);

beforeAll(async () => {
  env = await createEnv();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), path), bytes, pdf);
  });
});

afterAll(async () => {
  await env.cleanup();
});

const teacher = () => env.authenticatedContext("t1", {teaching_role: "teacher"}).storage();
const curator = () => env.authenticatedContext("c1", {teaching_role: "curator"}).storage();
const admin = () => env.authenticatedContext("a1", {admin: true}).storage();
const plain = () => env.authenticatedContext("p1").storage();
const anon = () => env.unauthenticatedContext().storage();

describe("regras do Storage — teaching/materials", () => {
  it("professor, curador e admin leem", async () => {
    await assertSucceeds(getBytes(ref(teacher(), path)));
    await assertSucceeds(getBytes(ref(curator(), path)));
    await assertSucceeds(getBytes(ref(admin(), path)));
  });

  it("usuário sem papel e anônimo NÃO leem", async () => {
    await assertFails(getBytes(ref(plain(), path)));
    await assertFails(getBytes(ref(anon(), path)));
  });

  it("claim com papel inválido NÃO dá acesso", async () => {
    const odd = env.authenticatedContext("x1", {teaching_role: "god"}).storage();
    await assertFails(getBytes(ref(odd, path)));
  });

  it("professor envia PDF, Office e imagem", async () => {
    const base = "teaching/materials/m2";
    await assertSucceeds(uploadBytes(ref(teacher(), `${base}/a.pdf`), bytes, pdf));
    await assertSucceeds(uploadBytes(ref(teacher(), `${base}/b.docx`), bytes, {
      contentType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    }));
    await assertSucceeds(uploadBytes(ref(teacher(), `${base}/c.png`), bytes, {contentType: "image/png"}));
  });

  it("professor NÃO envia tipo fora da lista", async () => {
    await assertFails(uploadBytes(ref(teacher(), "teaching/materials/m3/x.exe"), bytes, {
      contentType: "application/x-msdownload",
    }));
  });

  it("usuário sem papel NÃO envia", async () => {
    await assertFails(uploadBytes(ref(plain(), "teaching/materials/m4/a.pdf"), bytes, pdf));
  });

  it("arquivo acima de 100 MB é negado", async () => {
    const big = new Uint8Array(100 * 1024 * 1024 + 1);
    await assertFails(uploadBytes(ref(teacher(), "teaching/materials/m5/big.pdf"), big, pdf));
  }, 120_000);

  it("só curador e admin apagam; professor não", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), "teaching/materials/m6/a.pdf"), bytes, pdf);
      await uploadBytes(ref(ctx.storage(), "teaching/materials/m7/a.pdf"), bytes, pdf);
      await uploadBytes(ref(ctx.storage(), "teaching/materials/m8/a.pdf"), bytes, pdf);
    });
    await assertFails(deleteObject(ref(teacher(), "teaching/materials/m6/a.pdf")));
    await assertSucceeds(deleteObject(ref(curator(), "teaching/materials/m7/a.pdf")));
    await assertSucceeds(deleteObject(ref(admin(), "teaching/materials/m8/a.pdf")));
  });

  it("professor NÃO sobrescreve arquivo existente", async () => {
    const p = "teaching/materials/m9/a.pdf";
    await env.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), p), bytes, pdf);
    });
    await assertFails(uploadBytes(ref(teacher(), p), new Uint8Array([9]), pdf));
  });

  it("curador sobrescreve arquivo existente", async () => {
    const p = "teaching/materials/m10/a.pdf";
    await env.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), p), bytes, pdf);
    });
    await assertSucceeds(uploadBytes(ref(curator(), p), new Uint8Array([9]), pdf));
  });

  it("admin sobrescreve arquivo existente", async () => {
    const p = "teaching/materials/m11/a.pdf";
    await env.withSecurityRulesDisabled(async (ctx) => {
      await uploadBytes(ref(ctx.storage(), p), bytes, pdf);
    });
    await assertSucceeds(uploadBytes(ref(admin(), p), new Uint8Array([9]), pdf));
  });

  it("curador e admin criam arquivo novo", async () => {
    await assertSucceeds(uploadBytes(ref(curator(), "teaching/materials/m12/a.pdf"), bytes, pdf));
    await assertSucceeds(uploadBytes(ref(admin(), "teaching/materials/m13/a.pdf"), bytes, pdf));
  });

  it("outros caminhos do bucket seguem negados", async () => {
    await assertFails(uploadBytes(ref(teacher(), "outros/a.pdf"), bytes, pdf));
  });
});
