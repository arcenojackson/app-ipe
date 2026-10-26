import {afterAll, beforeAll, beforeEach, describe, it} from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";
import {createEnv} from "./env";

let env: RulesTestEnvironment;

const teacher = () => env.authenticatedContext("t1", {teaching_role: "teacher"}).firestore();
const teacher2 = () => env.authenticatedContext("t2", {teaching_role: "teacher"}).firestore();
const curator1 = () => env.authenticatedContext("c1", {teaching_role: "curator"}).firestore();
const curator2 = () => env.authenticatedContext("c2", {teaching_role: "curator"}).firestore();
const adminOnly = () => env.authenticatedContext("a1", {admin: true}).firestore();
const plain = () => env.authenticatedContext("p1").firestore();

const base = {parentId: "f1", version: 1, name: "Item"};
const tags = {
  typeTags: ["tipo-artigos"], subjectTags: ["assunto-trindade"], ageTags: ["faixa-ump"],
  searchTokens: ["it", "ite", "item"],
};

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
    await setDoc(doc(db, "teaching_items/f1"), {
      type: "folder", name: "Pasta", parentId: null, authorId: "c1", status: "active", version: 1,
    });
    await setDoc(doc(db, "teaching_items/pub"), {
      ...base, ...tags, type: "file", authorId: "t1", status: "published",
      fileName: "a.pdf", contentType: "application/pdf", size: 10, storagePath: "teaching/materials/pub/v1-a.pdf",
    });
    await setDoc(doc(db, "teaching_items/rev"), {
      ...base, type: "file", authorId: "t1", status: "in_review",
      fileName: "a.pdf", contentType: "application/pdf", size: 10, storagePath: "teaching/materials/rev/v1-a.pdf",
    });
    await setDoc(doc(db, "teaching_items/ret"), {
      ...base, ...tags, type: "file", authorId: "t1", status: "returned",
      fileName: "a.pdf", contentType: "application/pdf", size: 10, storagePath: "teaching/materials/ret/v1-a.pdf",
    });
    await setDoc(doc(db, "teaching_items/lnk"), {
      ...base, ...tags, type: "link", authorId: "t1", status: "returned", url: "https://exemplo.org",
    });
    await setDoc(doc(db, "teaching_items/del"), {
      ...base, type: "file", authorId: "t1", status: "published",
      fileName: "a.pdf", contentType: "application/pdf", size: 10, storagePath: "teaching/materials/del/v1-a.pdf",
      deleteRequested: true,
      deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: new Date(0)},
    });
    await setDoc(doc(db, "teaching_notifications/n1"), {
      toUid: "t1", type: "published", itemId: "pub", title: "T", body: "B", readAt: null,
    });
  });
});

function fileData(uid: string, id: string, extra: Record<string, unknown> = {}) {
  return {
    type: "file", name: "Aula 1", parentId: "f1", authorId: uid, updatedBy: uid,
    status: "in_review", version: 1, fileName: "a.pdf", contentType: "application/pdf",
    size: 1000, storagePath: `teaching/materials/${id}/v1-a.pdf`, ...tags,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...extra,
  };
}

describe("leitura de itens", () => {
  it("professor lê pasta, publicado e o próprio envio; não lê envio de outro em revisão", async () => {
    await assertSucceeds(getDoc(doc(teacher2(), "teaching_items/f1")));
    await assertSucceeds(getDoc(doc(teacher2(), "teaching_items/pub")));
    await assertSucceeds(getDoc(doc(teacher(), "teaching_items/rev")));
    await assertFails(getDoc(doc(teacher2(), "teaching_items/rev")));
    await assertFails(getDoc(doc(teacher2(), "teaching_items/ret")));
  });

  it("curador e admin leem tudo; sem papel não lê nada", async () => {
    await assertSucceeds(getDoc(doc(curator2(), "teaching_items/rev")));
    await assertSucceeds(getDoc(doc(adminOnly(), "teaching_items/rev")));
    await assertFails(getDoc(doc(plain(), "teaching_items/pub")));
  });

  it("consultas do professor com filtro são aceitas; sem filtro é negada", async () => {
    const items = (db: ReturnType<typeof teacher>) => collection(db, "teaching_items");
    await assertSucceeds(getDocs(query(items(teacher2()), where("parentId", "==", "f1"), where("status", "==", "published"))));
    await assertSucceeds(getDocs(query(items(teacher2()), where("parentId", "==", "f1"), where("status", "==", "active"))));
    await assertSucceeds(getDocs(query(items(teacher()), where("parentId", "==", "f1"), where("authorId", "==", "t1"))));
    await assertFails(getDocs(query(items(teacher2()), where("parentId", "==", "f1"))));
    await assertSucceeds(getDocs(query(items(curator1()), where("parentId", "==", "f1"))));
  });
});

describe("criação de itens", () => {
  it("professor cria arquivo em revisão", async () => {
    await assertSucceeds(setDoc(doc(teacher(), "teaching_items/novo"), fileData("t1", "novo")));
  });

  it("curador cria arquivo em revisão e pasta ativa; professor não cria pasta", async () => {
    await assertSucceeds(setDoc(doc(curator1(), "teaching_items/novo"), fileData("c1", "novo")));
    const folder = (uid: string) => ({
      type: "folder", name: "Nova", parentId: null, authorId: uid, updatedBy: uid,
      status: "active", version: 1, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    await assertSucceeds(setDoc(doc(curator1(), "teaching_items/pasta"), folder("c1")));
    await assertFails(setDoc(doc(teacher(), "teaching_items/pasta"), folder("t1")));
  });

  it("professor cria link http(s); link com outro esquema é negado", async () => {
    const link = (url: string) => ({
      type: "link", name: "Livro", parentId: "f1", authorId: "t1", updatedBy: "t1",
      status: "in_review", version: 1, url, ...tags, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    await assertSucceeds(setDoc(doc(teacher(), "teaching_items/l1"), link("https://exemplo.org/livro")));
    await assertFails(setDoc(doc(teacher(), "teaching_items/l2"), link("javascript:alert(1)")));
  });

  it("negado: já publicado, autor de outro, versão 2, caminho errado, campo extra", async () => {
    await assertFails(setDoc(doc(teacher(), "teaching_items/a"), fileData("t1", "a", {status: "published"})));
    await assertFails(setDoc(doc(teacher(), "teaching_items/b"), fileData("t1", "b", {authorId: "t2"})));
    await assertFails(setDoc(doc(teacher(), "teaching_items/c"), fileData("t1", "c", {version: 2})));
    await assertFails(setDoc(doc(teacher(), "teaching_items/d"), fileData("t1", "d", {storagePath: "teaching/materials/outro/v1-a.pdf"})));
    await assertFails(setDoc(doc(teacher(), "teaching_items/e"), fileData("t1", "e", {deleteRequested: true})));
  });

  it("negado: pai inexistente, pai que não é pasta, nome vazio, sem papel", async () => {
    await assertFails(setDoc(doc(teacher(), "teaching_items/f"), fileData("t1", "f", {parentId: "nao-existe"})));
    await assertFails(setDoc(doc(teacher(), "teaching_items/g"), fileData("t1", "g", {parentId: "pub"})));
    await assertFails(setDoc(doc(teacher(), "teaching_items/h"), fileData("t1", "h", {name: ""})));
    await assertFails(setDoc(doc(plain(), "teaching_items/i"), fileData("p1", "i")));
  });

  it("negado: content type vazio ou tamanho inválido", async () => {
    await assertFails(setDoc(doc(teacher(), "teaching_items/j"), fileData("t1", "j", {contentType: ""})));
    await assertFails(setDoc(doc(teacher(), "teaching_items/k"), fileData("t1", "k", {size: 104857601})));
  });
});

describe("tags e qualquer tipo de arquivo", () => {
  it("professor cria arquivo com uma tag de cada tipo", async () => {
    await assertSucceeds(setDoc(doc(teacher(), "teaching_items/t1"), fileData("t1", "t1", {parentId: null})));
  });

  it("nega criar arquivo sem tag de tipo, assunto ou faixa", async () => {
    await assertFails(setDoc(doc(teacher(), "teaching_items/s1"), fileData("t1", "s1", {typeTags: []})));
    await assertFails(setDoc(doc(teacher(), "teaching_items/s2"), fileData("t1", "s2", {subjectTags: []})));
    await assertFails(setDoc(doc(teacher(), "teaching_items/s3"), fileData("t1", "s3", {ageTags: []})));
  });

  it("nega mais de 10 tags num tipo e mais de 200 searchTokens", async () => {
    const many = Array.from({length: 11}, (_, i) => `assunto-${i}`);
    await assertFails(setDoc(doc(teacher(), "teaching_items/s4"), fileData("t1", "s4", {subjectTags: many})));
    const tokens = Array.from({length: 201}, (_, i) => `t${i}`);
    await assertFails(setDoc(doc(teacher(), "teaching_items/s5"), fileData("t1", "s5", {searchTokens: tokens})));
  });

  it("link sem tags é negado", async () => {
    const link = {
      type: "link", name: "Livro", parentId: null, authorId: "t1", updatedBy: "t1",
      status: "in_review", version: 1, url: "https://exemplo.org", typeTags: [], subjectTags: [], ageTags: [],
      searchTokens: [], createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    };
    await assertFails(setDoc(doc(teacher(), "teaching_items/l3"), link));
  });

  it("aceita qualquer content type não vazio", async () => {
    await assertSucceeds(setDoc(doc(teacher(), "teaching_items/z1"), fileData("t1", "z1", {contentType: "application/zip"})));
  });

  it("curador edita só as tags de item publicado", async () => {
    const edit = (extra: Record<string, unknown> = {}) => ({
      typeTags: ["tipo-aulas"], subjectTags: ["assunto-trindade", "assunto-igreja"], ageTags: ["faixa-upa"],
      updatedBy: "c1", updatedAt: serverTimestamp(), ...extra,
    });
    await assertSucceeds(updateDoc(doc(curator1(), "teaching_items/pub"), edit()));
    await assertFails(updateDoc(doc(curator1(), "teaching_items/pub"), edit({status: "in_review"})));
    await assertFails(updateDoc(doc(curator1(), "teaching_items/pub"), edit({typeTags: []})));
  });

  it("professor e admin sem papel curador não editam tags", async () => {
    const edit = (uid: string) => ({typeTags: ["tipo-aulas"], updatedBy: uid, updatedAt: serverTimestamp()});
    await assertFails(updateDoc(doc(teacher(), "teaching_items/pub"), edit("t1")));
    await assertFails(updateDoc(doc(adminOnly(), "teaching_items/pub"), edit("a1")));
  });

  it("curador renomeia atualizando searchTokens", async () => {
    await assertSucceeds(updateDoc(doc(curator1(), "teaching_items/pub"), {
      name: "Novo nome", searchTokens: ["no", "nov", "novo"], updatedBy: "c1", updatedAt: serverTimestamp(),
    }));
  });

  it("autor reenvia item devolvido trocando as tags; tipo vazio é negado", async () => {
    const resubmit = (extra: Record<string, unknown> = {}) => ({
      status: "in_review", version: 2, storagePath: "teaching/materials/ret/v2-b.pdf", fileName: "b.pdf",
      updatedBy: "t1", updatedAt: serverTimestamp(), ...extra,
    });
    await assertSucceeds(updateDoc(doc(teacher(), "teaching_items/ret"), resubmit({subjectTags: ["assunto-cristo"]})));
    await assertFails(updateDoc(doc(teacher(), "teaching_items/ret"), resubmit({ageTags: []})));
  });
});

describe("coleção de tags", () => {
  it("professor lê tags e ninguém grava", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "teaching_tags/tipo-artigos"), {kind: "type", name: "Artigos", order: 1, active: true});
    });
    await assertSucceeds(getDoc(doc(teacher(), "teaching_tags/tipo-artigos")));
    await assertSucceeds(getDocs(collection(teacher(), "teaching_tags")));
    await assertFails(getDoc(doc(plain(), "teaching_tags/tipo-artigos")));
    for (const db of [teacher(), curator1(), adminOnly()]) {
      await assertFails(setDoc(doc(db, "teaching_tags/novo"), {kind: "type", name: "X", order: 9, active: true}));
      await assertFails(updateDoc(doc(db, "teaching_tags/tipo-artigos"), {name: "Y"}));
    }
  });
});

describe("atualização de itens", () => {
  it("curador renomeia e move; não altera status nem autor", async () => {
    await assertSucceeds(updateDoc(doc(curator1(), "teaching_items/pub"), {name: "Novo nome", updatedBy: "c1", updatedAt: serverTimestamp()}));
    await assertSucceeds(updateDoc(doc(curator1(), "teaching_items/pub"), {parentId: null, updatedBy: "c1", updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(doc(curator1(), "teaching_items/pub"), {status: "in_review", updatedBy: "c1", updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(doc(curator1(), "teaching_items/pub"), {authorId: "c1", updatedBy: "c1", updatedAt: serverTimestamp()}));
  });

  it("professor e admin sem papel curador não renomeiam nem movem", async () => {
    await assertFails(updateDoc(doc(teacher(), "teaching_items/pub"), {name: "X", updatedBy: "t1", updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(doc(adminOnly(), "teaching_items/pub"), {name: "X", updatedBy: "a1", updatedAt: serverTimestamp()}));
  });

  it("mover para pai que não é pasta ou inexistente é negado", async () => {
    await assertFails(updateDoc(doc(curator1(), "teaching_items/pub"), {parentId: "rev", updatedBy: "c1", updatedAt: serverTimestamp()}));
    await assertFails(updateDoc(doc(curator1(), "teaching_items/pub"), {parentId: "x", updatedBy: "c1", updatedAt: serverTimestamp()}));
  });

  it("curador pede exclusão de item publicado; não de item em revisão nem em nome de outro", async () => {
    const request = (uid: string, by: string) => ({
      deleteRequested: true,
      deleteRequest: {id: "r9", requestedBy: by, requestedAt: serverTimestamp(), reason: "Obsoleto"},
      updatedBy: uid, updatedAt: serverTimestamp(),
    });
    await assertSucceeds(updateDoc(doc(curator1(), "teaching_items/pub"), request("c1", "c1")));
    await assertFails(updateDoc(doc(curator2(), "teaching_items/rev"), request("c2", "c2")));
    await assertFails(updateDoc(doc(curator2(), "teaching_items/pub"), request("c2", "c1")));
    await assertFails(updateDoc(doc(teacher(), "teaching_items/pub"), request("t1", "t1")));
  });

  it("curador pede exclusão de item devolvido (autor que nunca reenvia); professor não", async () => {
    const request = (uid: string) => ({
      deleteRequested: true,
      deleteRequest: {id: "r8", requestedBy: uid, requestedAt: serverTimestamp(), reason: "Autor não reenviou"},
      updatedBy: uid, updatedAt: serverTimestamp(),
    });
    await assertSucceeds(updateDoc(doc(curator1(), "teaching_items/ret"), request("c1")));
    await assertFails(updateDoc(doc(teacher(), "teaching_items/ret"), request("t1")));
    await assertFails(updateDoc(doc(curator1(), "teaching_items/rev"), request("c1")));
  });

  it("quem pediu cancela o pedido; outro curador não cancela", async () => {
    const cancel = (uid: string) => ({deleteRequested: false, deleteRequest: null, updatedBy: uid, updatedAt: serverTimestamp()});
    await assertFails(updateDoc(doc(curator2(), "teaching_items/del"), cancel("c2")));
    await assertSucceeds(updateDoc(doc(curator1(), "teaching_items/del"), cancel("c1")));
  });

  it("autor reenvia item devolvido (versão + 1); negado em outros casos", async () => {
    const resubmit = (extra: Record<string, unknown> = {}) => ({
      status: "in_review", version: 2, storagePath: "teaching/materials/ret/v2-b.pdf", fileName: "b.pdf",
      updatedBy: "t1", updatedAt: serverTimestamp(), ...extra,
    });
    await assertSucceeds(updateDoc(doc(teacher(), "teaching_items/ret"), resubmit()));
    await assertFails(updateDoc(doc(teacher(), "teaching_items/ret"), resubmit({version: 3})));
    await assertFails(updateDoc(doc(teacher(), "teaching_items/ret"), resubmit({status: "published"})));
    await assertFails(updateDoc(doc(teacher(), "teaching_items/ret"), resubmit({storagePath: "teaching/materials/ret/v1-a.pdf"})));
    await assertFails(updateDoc(doc(teacher(), "teaching_items/ret"), resubmit({storagePath: "teaching/materials/outro/v2-b.pdf"})));
    await assertFails(updateDoc(doc(teacher2(), "teaching_items/ret"), resubmit({updatedBy: "t2"})));
    await assertFails(updateDoc(doc(teacher(), "teaching_items/rev"), resubmit({storagePath: "teaching/materials/rev/v2-b.pdf"})));
  });

  it("autor reenvia link devolvido com nova url http(s)", async () => {
    const data = (url: string) => ({status: "in_review", version: 2, url, updatedBy: "t1", updatedAt: serverTimestamp()});
    await assertSucceeds(updateDoc(doc(teacher(), "teaching_items/lnk"), data("https://novo.org")));
    await assertFails(updateDoc(doc(teacher(), "teaching_items/lnk"), data("ftp://novo.org")));
  });

  it("updatedBy e updatedAt são obrigatórios e verificados", async () => {
    await assertFails(updateDoc(doc(curator1(), "teaching_items/pub"), {name: "X"}));
    await assertFails(updateDoc(doc(curator1(), "teaching_items/pub"), {name: "X", updatedBy: "c2", updatedAt: serverTimestamp()}));
  });
});

describe("exclusão", () => {
  it("ninguém apaga itens pelo cliente", async () => {
    await assertFails(deleteDoc(doc(curator1(), "teaching_items/pub")));
    await assertFails(deleteDoc(doc(adminOnly(), "teaching_items/pub")));
    await assertFails(deleteDoc(doc(teacher(), "teaching_items/rev")));
  });
});

describe("votos", () => {
  const vote = (uid: string, extra: Record<string, unknown>) => ({voterId: uid, createdAt: serverTimestamp(), ...extra});
  const votes = (db: ReturnType<typeof teacher>, item: string) => collection(db, `teaching_items/${item}/votes`);

  it("curador diferente do autor aprova a versão atual", async () => {
    await assertSucceeds(addDoc(votes(curator2(), "rev"), vote("c2", {action: "approve", version: 1})));
  });

  it("negado: autor curador, professor, admin sem papel, outro uid, versão errada, item não está em revisão", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "teaching_items/meu"), {
        ...base, type: "file", authorId: "c1", status: "in_review", fileName: "a.pdf",
        contentType: "application/pdf", size: 1, storagePath: "teaching/materials/meu/a.pdf",
      });
    });
    await assertFails(addDoc(votes(curator1(), "meu"), vote("c1", {action: "approve", version: 1})));
    await assertFails(addDoc(votes(teacher2(), "rev"), vote("t2", {action: "approve", version: 1})));
    await assertFails(addDoc(votes(adminOnly(), "rev"), vote("a1", {action: "approve", version: 1})));
    await assertFails(addDoc(votes(curator2(), "rev"), vote("c1", {action: "approve", version: 1})));
    await assertFails(addDoc(votes(curator2(), "rev"), vote("c2", {action: "approve", version: 2})));
    await assertFails(addDoc(votes(curator2(), "pub"), vote("c2", {action: "approve", version: 1})));
  });

  it("devolver e rejeitar exigem comentário; aprovar não", async () => {
    await assertFails(addDoc(votes(curator2(), "rev"), vote("c2", {action: "return", version: 1})));
    await assertFails(addDoc(votes(curator2(), "rev"), vote("c2", {action: "reject", version: 1, comment: ""})));
    await assertSucceeds(addDoc(votes(curator2(), "rev"), vote("c2", {action: "return", version: 1, comment: "Falta a referência"})));
    await assertSucceeds(addDoc(votes(curator2(), "rev"), vote("c2", {action: "reject", version: 1, comment: "Fora do escopo"})));
  });

  it("votos de exclusão: outro curador com requestId correto; não o solicitante; não requestId errado", async () => {
    await assertSucceeds(addDoc(votes(curator2(), "del"), vote("c2", {action: "delete_approve", requestId: "r1"})));
    await assertFails(addDoc(votes(curator1(), "del"), vote("c1", {action: "delete_approve", requestId: "r1"})));
    await assertFails(addDoc(votes(curator2(), "del"), vote("c2", {action: "delete_approve", requestId: "velho"})));
    await assertFails(addDoc(votes(curator2(), "del"), vote("c2", {action: "delete_refuse", requestId: "r1"})));
    await assertSucceeds(addDoc(votes(curator2(), "del"), vote("c2", {action: "delete_refuse", requestId: "r1", comment: "Ainda é usado"})));
    await assertFails(addDoc(votes(curator2(), "pub"), vote("c2", {action: "delete_approve", requestId: "r1"})));
  });

  it("votos são imutáveis e leitura é de curador, admin e autor do item", async () => {
    let voteId = "";
    await env.withSecurityRulesDisabled(async (ctx) => {
      const created = await addDoc(collection(ctx.firestore(), "teaching_items/rev/votes"), {
        voterId: "c2", action: "approve", version: 1, createdAt: new Date(0),
      });
      voteId = created.id;
    });
    const path = `teaching_items/rev/votes/${voteId}`;
    await assertFails(updateDoc(doc(curator2(), path), {action: "reject"}));
    await assertFails(deleteDoc(doc(curator2(), path)));
    await assertSucceeds(getDoc(doc(curator1(), path)));
    await assertSucceeds(getDoc(doc(adminOnly(), path)));
    await assertSucceeds(getDoc(doc(teacher(), path)));
    await assertFails(getDoc(doc(teacher2(), path)));
  });
});

describe("notificações e log", () => {
  it("dono lê e marca readAt; outros não leem; ninguém cria nem apaga", async () => {
    await assertSucceeds(getDoc(doc(teacher(), "teaching_notifications/n1")));
    await assertFails(getDoc(doc(teacher2(), "teaching_notifications/n1")));
    await assertSucceeds(updateDoc(doc(teacher(), "teaching_notifications/n1"), {readAt: serverTimestamp()}));
    await assertFails(updateDoc(doc(teacher(), "teaching_notifications/n1"), {title: "Outro"}));
    await assertFails(updateDoc(doc(teacher2(), "teaching_notifications/n1"), {readAt: serverTimestamp()}));
    await assertFails(setDoc(doc(teacher(), "teaching_notifications/n2"), {toUid: "t1", title: "x"}));
    await assertFails(deleteDoc(doc(teacher(), "teaching_notifications/n1")));
  });

  it("notificações do próprio usuário podem ser listadas com filtro", async () => {
    await assertSucceeds(getDocs(query(collection(teacher(), "teaching_notifications"), where("toUid", "==", "t1"))));
    await assertFails(getDocs(collection(teacher(), "teaching_notifications")));
  });

  it("teaching_log não é acessível pelo cliente", async () => {
    await assertFails(getDoc(doc(curator1(), "teaching_log/x")));
    await assertFails(setDoc(doc(curator1(), "teaching_log/x"), {a: 1}));
  });
});
