# Biblioteca e Curadoria — Plano A (base: regras e Functions) — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar a base testada da biblioteca de ensino: regras novas do Firestore e do Storage e as Cloud Functions que decidem publicação, devolução, rejeição e exclusão exigindo 2 curadores, além de notificações e registro de ações.

**Architecture:** Coleções novas `teaching_items` (árvore por `parentId`), `votes` (subcoleção), `teaching_notifications` e `teaching_log`. O cliente nunca escreve `status` nem apaga nada; três gatilhos de Cloud Functions chamam funções de domínio puras e testáveis (`decide*`, `processVote`, `processItemChange`) por meio de portas injetáveis (banco, Storage, papéis no Auth, notificador, auditoria). As regras novas valem só para coleções novas.

**Tech Stack:** Firebase Functions v1 (Node 22, TypeScript), firebase-admin 12, Vitest, `@firebase/rules-unit-testing` com emuladores do Firebase (firebase-tools 14 local, Java 17).

**Spec:** `docs/superpowers/specs/2026-10-15-teaching-library-curation-design.md` (e, por herança, `docs/superpowers/specs/2026-10-12-teaching-portal-design.md`).

**Nota de ambiente:** nesta máquina o hook do `rtk` bloqueia `git` simples e construções de shell complexas dentro da worktree. Use `/usr/bin/git`, um comando simples por vez, com caminhos literais. A worktree nova não tem `node_modules`: rode `npm --prefix functions install` e `npm --prefix rules-tests install` antes de começar. Os testes de regras usam o `firebase-tools` 14 local de `rules-tests/` (o global exige Java 21; um aviso de Java é esperado). Todos os caminhos são relativos à raiz da worktree (`.claude/worktrees/teaching-library`).

## Decisões deste plano em relação à spec

1. **Sem índices compostos.** A spec cita `firestore.indexes.json`, mas as consultas da biblioteca usam só igualdades (`parentId`, `status`, `authorId`, `deleteRequested`) e a ordenação por nome é feita no cliente; o Firestore resolve igualdades com índices simples. Não criamos `firestore.indexes.json`.
2. **Campo `updatedBy`.** Todo `create`/`update` do cliente grava `updatedBy == uid`, para a Function saber quem moveu/pediu e notificar (gatilhos do Firestore v1 não trazem o usuário).
3. **Storage guarda só o objeto atual.** As regras não validam o número da versão no caminho. O cliente grava `storagePath` em `teaching/materials/{itemId}/...` e, no reenvio, a Function apaga todos os objetos do item **exceto** o `storagePath` atual.
4. **Notificações e auditoria são "melhor esforço"**, com ids determinísticos (não duplicam em retentativa). As transições de estado e a limpeza do Storage são críticas e idempotentes: em falha a Function lança erro e é reexecutada.
5. **Consultas do professor:** as regras de leitura exigem filtro; o professor usa 3 consultas de igualdade por pasta (`status == published`, `status == active`, `authorId == uid`). O portal (Plano B) segue isso.

## Global Constraints

- Só a IPE. Papéis vêm das custom claims `teaching_role` (`teacher` | `curator`) e `admin`; **nenhuma regra existente é alterada** (`firestore.rules` só ganha blocos novos; o bloco `users` e todos os demais ficam idênticos).
- **Todo envio é revisado**; nenhum item nasce publicado. Publicar exige **2 aprovações de curadores distintos entre si e diferentes do autor**; só vale o **último voto** de cada curador na **versão atual**.
- **Devolver com comentário:** 1 curador basta; zera as aprovações. **Rejeitar um envio novo:** 2 curadores. **Apagar documento publicado ou pasta com documentos:** pedido de um curador + aprovação de **2 outros curadores**; **qualquer curador pode Recusar** e encerra o pedido; quem pediu pode cancelar. **Pasta sem nenhum documento/link em qualquer nível:** 1 curador, direto.
- **Só curador (`teaching_role == curator`) vota ou gerencia pastas**; admin sem esse papel lê tudo, mas não vota, não apaga e não gerencia pastas.
- **Ninguém apaga pelo cliente:** regras de Firestore e Storage negam qualquer exclusão do cliente; toda exclusão é feita por Function (Admin SDK).
- Papel do votante relido no **Auth** na hora de contar (curador rebaixado não conta).
- Storage: `teaching/materials/{itemId}/{fileName}`, objetos novos apenas (sem sobrescrever), até 100 MB, PDF, Office (doc/docx/ppt/pptx/xls/xlsx e OpenDocument) e imagens.
- Profundidade máxima da árvore: 8 níveis; nome de item de 1 a 120 caracteres; link só `http` ou `https`.
- Notificações em pt-BR; push respeita `users/{uid}.disabled_notifications` (chave `teaching_review`) e usa `users/{uid}.fcmToken`.
- Node 22; Functions v1 com `runWith({failurePolicy: true})`; ESLint do Google (sem espaços em `{}`, 80 colunas, aspas duplas, vírgula final).
- Não modificar `lib/` (Flutter) nem `web-portal/` neste plano.

## Review Focus

Entradas e falhas que a spec implica e que as tarefas cobrem com testes:

1. **Voto do autor, de não-curador ou de admin sem papel Curador** nunca conta (regras negam a criação; `decide*` ignora). (Tasks 2 e 3)
2. **Curador rebaixado antes da contagem:** voto descartado. (Task 4)
3. **Eventos repetidos ou atrasados:** reprocessar um voto depois da publicação, voto de versão antiga ou de `requestId` antigo não faz nada nem duplica notificação. (Task 4)
4. **Falha parcial:** se o Storage falhar ao rejeitar/excluir, o item e os votos continuam e a retentativa conclui; a exclusão de pasta remove todos os níveis e a pasta raiz por último. (Tasks 4 e 5)
5. **Movimentos inválidos:** mover pasta para dentro de si mesma ou de um descendente, para um item que não é pasta, ou além de 8 níveis é desfeito e o autor do movimento é avisado. (Task 5)
6. **Vazamento por Storage ou consulta:** professor não baixa arquivo em revisão de outro autor, nem lista itens sem filtro; ninguém sobrescreve ou apaga objetos pelo cliente. (Tasks 1 e 2)

---

## File Structure

```
firestore.rules                                  (modificar: blocos novos no fim)
storage.rules                                    (modificar: leitura por status via Firestore)
rules-tests/library.firestore.rules.test.ts      (criar)
rules-tests/storage.rules.test.ts                (reescrever)
functions/.eslintrc.js                           (modificar: override p/ library)
functions/package.json                           (modificar: scripts de teste)
functions/vitest.config.ts                       (criar)
functions/vitest.emulator.config.ts              (criar)
functions/src/index.ts                           (modificar: exports dos gatilhos)
functions/src/teaching/library/
  constants.ts      nomes de coleções, limites, URL do portal
  types.ts          ItemDoc, VoteDoc, portas (LibraryDb, Storage, Roles, Notifier, Audit)
  util.ts           chunks, unique, safely
  decide.ts         decisões puras (publicação e exclusão)
  messages.ts       textos pt-BR das notificações
  subtree.ts        collectSubtree, hasDocuments, deleteSubtree
  moves.ts          moveIsValid (ciclo, pai, profundidade)
  processVote.ts    processa um voto novo
  processItemChange.ts  criação, reenvio, movimento, pedido de exclusão
  convert.ts        toItem / toVote (Firestore -> domínio)
  adapterDb.ts      LibraryDb sobre firebase-admin
  adapterStorage.ts LibraryStorage sobre o bucket
  adapterRoles.ts   RolesPort sobre o Auth
  adapterNotifier.ts Notifier (doc + push) e AuditLog
  buildDeps.ts      composição das dependências reais
  triggers.ts       os 3 gatilhos exportados
functions/test/library/
  fakes.ts          portas em memória e fábricas
  decide.test.ts  messages.test.ts  processVote.test.ts
  processItemChange.test.ts  adapterRoles.test.ts  adapterStorage.test.ts
functions/test-emulator/
  adapterDb.test.ts  adapterNotifier.test.ts   (rodam no emulador do Firestore)
```

---

### Task 1: Regras do Storage lendo o status do item no Firestore

**Files:**
- Modify: `storage.rules`
- Rewrite: `rules-tests/storage.rules.test.ts`

**Interfaces:**
- Consumes: documento `teaching_items/{itemId}` com `status` (`in_review | returned | published | active`) e `authorId`.
- Produces (usado por todo o plano e pelo Plano B): leitura de `teaching/materials/{itemId}/{fileName}` permitida a professor/curador/admin **apenas** se o item existe e (`status == published` ou autor ou curador/admin); criação só de objeto novo; **nenhum update/delete do cliente**.

- [ ] **Step 1: Preparar o ambiente**

Run (um comando por vez): `npm --prefix rules-tests install` e `npm --prefix functions install`.
Expected: dependências instaladas; `rules-tests/node_modules/.bin/firebase` existe (versão 14.x).

- [ ] **Step 2: Escrever os testes (que vão falhar) — inclui o teste que prova a leitura cruzada Storage → Firestore**

Substituir `rules-tests/storage.rules.test.ts` por:

```ts
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
```

- [ ] **Step 3: Rodar para ver falhar**

Run: `npm --prefix rules-tests test`
Expected: FAIL — em especial "item em revisão: ... outro professor não" e "ninguém sobrescreve/apaga" (as regras atuais deixam o curador sobrescrever e apagar, e qualquer professor ler). Se o erro for de infraestrutura (emulador não sobe, `firestore.get` indisponível no emulador de Storage), **pare e reporte BLOCKED**: a decisão de arquitetura depende de a leitura cruzada funcionar.

- [ ] **Step 4: Implementar as regras**

Substituir o conteúdo de `storage.rules` por:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // Professor, curador ou administrador
    function hasTeachingAccess() {
      return request.auth != null && (
        request.auth.token.get('admin', false) == true ||
        request.auth.token.get('teaching_role', '') in ['teacher', 'curator']
      );
    }

    // Curador ou administrador (leitura de tudo)
    function isCuratorOrAdmin() {
      return request.auth != null && (
        request.auth.token.get('admin', false) == true ||
        request.auth.token.get('teaching_role', '') == 'curator'
      );
    }

    function allowedContentType() {
      return request.resource.contentType == 'application/pdf' ||
        request.resource.contentType.matches('image/.*') ||
        request.resource.contentType in [
          'application/msword',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'application/vnd.ms-powerpoint',
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          'application/vnd.ms-excel',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'application/vnd.oasis.opendocument.text',
          'application/vnd.oasis.opendocument.presentation',
          'application/vnd.oasis.opendocument.spreadsheet'
        ];
    }

    function itemPath(id) {
      return /databases/(default)/documents/teaching_items/$(id);
    }

    match /teaching/materials/{itemId}/{fileName} {
      // Só se o item existe e: publicado, ou do próprio autor, ou curador/admin.
      allow read: if hasTeachingAccess() &&
        firestore.exists(itemPath(itemId)) && (
          isCuratorOrAdmin() ||
          firestore.get(itemPath(itemId)).data.status == 'published' ||
          firestore.get(itemPath(itemId)).data.authorId == request.auth.uid
        );

      // Só objetos novos, até 100 MB. O envio sobre objeto existente (avaliado
      // como create com `resource` preenchido no emulador, como update em
      // produção) é negado. Apagar/trocar é feito pela Cloud Function.
      allow create: if hasTeachingAccess() &&
        resource == null &&
        request.resource.size <= 100 * 1024 * 1024 &&
        allowedContentType();

      // Sem update nem delete pelo cliente.
    }
  }
}
```

- [ ] **Step 5: Rodar para ver passar**

Run: `npm --prefix rules-tests test`
Expected: todos os testes de Storage e de `users` PASS (o `users.rules.test.ts` existente segue verde).

- [ ] **Step 6: Commit**

```bash
/usr/bin/git add storage.rules rules-tests/storage.rules.test.ts
/usr/bin/git commit -m "feat(rules): leitura do Storage pelo status do item e sem escrita destrutiva

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Regras do Firestore para itens, votos e notificações

**Files:**
- Modify: `firestore.rules` (acrescentar blocos novos antes do fecho final de `match /databases/{database}/documents`; **não alterar nenhuma linha existente**)
- Create: `rules-tests/library.firestore.rules.test.ts`

**Interfaces:**
- Consumes: claims `admin`, `teaching_role`.
- Produces (contrato para Functions e Plano B):
  - `teaching_items/{itemId}` com campos: `type` (`folder|file|link`), `name`, `parentId` (string|null), `authorId`, `status`, `version`, `updatedBy`, `createdAt`, `updatedAt`; arquivo: `fileName`, `contentType`, `size`, `storagePath`; link: `url`, `description?`; opcionais gravados por Functions: `returnComment`, `returnedBy`; pedido de exclusão: `deleteRequest {id, requestedBy, requestedAt, reason?}` + `deleteRequested` (boolean).
  - Criar: professor/curador/admin com acesso; pasta só curador (`status: active`); arquivo/link `status: in_review`, `version: 1`, `authorId == updatedBy == uid`, `createdAt == updatedAt == request.time`.
  - Atualizar (cliente): curador renomeia/move; curador abre/cancela pedido de exclusão; autor reenvia item `returned` (`status: in_review`, `version + 1`).
  - Votos em `teaching_items/{itemId}/votes/{voteId}` imutáveis: `voterId`, `action`, `version` (publicação) ou `requestId` (exclusão), `comment`, `createdAt`.
  - Notificações: dono lê e só pode atualizar `readAt`.
  - `teaching_log`: sem acesso do cliente. **Nenhuma exclusão pelo cliente.**

- [ ] **Step 1: Escrever os testes (que vão falhar)**

Criar `rules-tests/library.firestore.rules.test.ts`:

```ts
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
      ...base, type: "file", authorId: "t1", status: "published",
      fileName: "a.pdf", contentType: "application/pdf", size: 10, storagePath: "teaching/materials/pub/v1-a.pdf",
    });
    await setDoc(doc(db, "teaching_items/rev"), {
      ...base, type: "file", authorId: "t1", status: "in_review",
      fileName: "a.pdf", contentType: "application/pdf", size: 10, storagePath: "teaching/materials/rev/v1-a.pdf",
    });
    await setDoc(doc(db, "teaching_items/ret"), {
      ...base, type: "file", authorId: "t1", status: "returned",
      fileName: "a.pdf", contentType: "application/pdf", size: 10, storagePath: "teaching/materials/ret/v1-a.pdf",
    });
    await setDoc(doc(db, "teaching_items/lnk"), {
      ...base, type: "link", authorId: "t1", status: "returned", url: "https://exemplo.org",
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
    size: 1000, storagePath: `teaching/materials/${id}/v1-a.pdf`,
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
      status: "in_review", version: 1, url, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
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

  it("negado: tipo de arquivo ou tamanho inválidos", async () => {
    await assertFails(setDoc(doc(teacher(), "teaching_items/j"), fileData("t1", "j", {contentType: "application/x-msdownload"})));
    await assertFails(setDoc(doc(teacher(), "teaching_items/k"), fileData("t1", "k", {size: 104857601})));
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
```

- [ ] **Step 2: Rodar para ver falhar**

Run: `npm --prefix rules-tests test`
Expected: os testes novos FALHAM (as coleções são negadas por padrão). Os testes existentes de `users` e de Storage continuam passando.

- [ ] **Step 3: Implementar as regras**

Em `firestore.rules`, dentro de `match /databases/{database}/documents { ... }`, **depois do último bloco existente (`match /musics/{musicId}`) e antes do fecho do `match /databases`**, acrescentar exatamente:

```
    // ===== Biblioteca de ensino (etapas 2 e 3) =====
    // Papéis vêm das custom claims geradas por syncTeachingClaimsOnUserWrite.
    // Nenhuma regra acima foi alterada.

    function hasAdminClaim() {
      return request.auth != null &&
        request.auth.token.get('admin', false) == true;
    }

    function isCurator() {
      return request.auth != null &&
        request.auth.token.get('teaching_role', '') == 'curator';
    }

    function canUseTeaching() {
      return request.auth != null && (hasAdminClaim() ||
        request.auth.token.get('teaching_role', '') in ['teacher', 'curator']);
    }

    function itemPath(id) {
      return /databases/$(database)/documents/teaching_items/$(id);
    }

    function validContentType(ct) {
      return ct == 'application/pdf' ||
        ct.matches('image/.*') ||
        ct in [
          'application/msword',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'application/vnd.ms-powerpoint',
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          'application/vnd.ms-excel',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'application/vnd.oasis.opendocument.text',
          'application/vnd.oasis.opendocument.presentation',
          'application/vnd.oasis.opendocument.spreadsheet'
        ];
    }

    function validItemName(data) {
      return data.name is string && data.name.size() >= 1 &&
        data.name.size() <= 120;
    }

    function validParent(data) {
      return data.parentId == null || (
        data.parentId is string &&
        exists(itemPath(data.parentId)) &&
        get(itemPath(data.parentId)).data.type == 'folder');
    }

    function validNewFolder(data) {
      return data.keys().hasOnly(['type', 'name', 'parentId', 'authorId',
        'status', 'version', 'updatedBy', 'createdAt', 'updatedAt']) &&
        data.status == 'active';
    }

    function validNewFile(itemId, data) {
      return data.keys().hasOnly(['type', 'name', 'parentId', 'authorId',
        'status', 'version', 'updatedBy', 'createdAt', 'updatedAt',
        'fileName', 'contentType', 'size', 'storagePath']) &&
        data.keys().hasAll(['fileName', 'contentType', 'size', 'storagePath']) &&
        data.status == 'in_review' &&
        data.fileName is string && data.fileName.size() >= 1 &&
        data.fileName.size() <= 200 && !data.fileName.matches('.*/.*') &&
        data.size is int && data.size > 0 && data.size <= 104857600 &&
        validContentType(data.contentType) &&
        data.storagePath.matches('teaching/materials/' + itemId + '/.+');
    }

    function validNewLink(data) {
      return data.keys().hasOnly(['type', 'name', 'parentId', 'authorId',
        'status', 'version', 'updatedBy', 'createdAt', 'updatedAt',
        'url', 'description']) &&
        data.keys().hasAll(['url']) &&
        data.status == 'in_review' &&
        data.url is string && data.url.size() <= 2000 &&
        data.url.matches('https?://.+') &&
        (!('description' in data) ||
          (data.description is string && data.description.size() <= 1000));
    }

    function changedKeys() {
      return request.resource.data.diff(resource.data).affectedKeys();
    }

    function curatorOrganizes() {
      return isCurator() &&
        changedKeys().hasOnly(['name', 'parentId', 'updatedBy', 'updatedAt']) &&
        validItemName(request.resource.data) &&
        validParent(request.resource.data);
    }

    function curatorRequestsDelete() {
      return isCurator() &&
        changedKeys().hasOnly(['deleteRequest', 'deleteRequested',
          'updatedBy', 'updatedAt']) &&
        resource.data.get('deleteRequest', null) == null &&
        resource.data.status in ['active', 'published'] &&
        request.resource.data.deleteRequested == true &&
        request.resource.data.deleteRequest.keys().hasOnly(
          ['id', 'requestedBy', 'requestedAt', 'reason']) &&
        request.resource.data.deleteRequest.keys().hasAll(
          ['id', 'requestedBy', 'requestedAt']) &&
        request.resource.data.deleteRequest.id is string &&
        request.resource.data.deleteRequest.id.size() > 0 &&
        request.resource.data.deleteRequest.requestedBy == request.auth.uid &&
        request.resource.data.deleteRequest.requestedAt == request.time;
    }

    function requesterCancelsDelete() {
      return isCurator() &&
        resource.data.get('deleteRequest', null) != null &&
        resource.data.deleteRequest.requestedBy == request.auth.uid &&
        changedKeys().hasOnly(['deleteRequest', 'deleteRequested',
          'updatedBy', 'updatedAt']) &&
        request.resource.data.get('deleteRequest', null) == null &&
        request.resource.data.deleteRequested == false;
    }

    function authorResubmits(itemId) {
      return resource.data.authorId == request.auth.uid &&
        resource.data.status == 'returned' &&
        request.resource.data.status == 'in_review' &&
        request.resource.data.version == resource.data.version + 1 &&
        changedKeys().hasOnly(['status', 'version', 'name', 'fileName',
          'contentType', 'size', 'storagePath', 'url', 'description',
          'updatedBy', 'updatedAt']) &&
        validItemName(request.resource.data) &&
        (resource.data.type != 'file' || (
          request.resource.data.storagePath.matches(
            'teaching/materials/' + itemId + '/.+') &&
          request.resource.data.storagePath != resource.data.storagePath &&
          request.resource.data.fileName is string &&
          request.resource.data.size is int &&
          request.resource.data.size > 0 &&
          request.resource.data.size <= 104857600 &&
          validContentType(request.resource.data.contentType))) &&
        (resource.data.type != 'link' ||
          request.resource.data.url.matches('https?://.+'));
    }

    match /teaching_items/{itemId} {
      // Curador e admin leem tudo. Professor lê pastas, itens publicados e
      // os próprios envios. Consultas precisam trazer o filtro correspondente.
      allow read: if canUseTeaching() && (
        isCurator() || hasAdminClaim() ||
        resource.data.status in ['active', 'published'] ||
        resource.data.authorId == request.auth.uid);

      allow create: if canUseTeaching() &&
        request.resource.data.authorId == request.auth.uid &&
        request.resource.data.updatedBy == request.auth.uid &&
        request.resource.data.version == 1 &&
        request.resource.data.createdAt == request.time &&
        request.resource.data.updatedAt == request.time &&
        validItemName(request.resource.data) &&
        validParent(request.resource.data) && (
          (request.resource.data.type == 'folder' && isCurator() &&
            validNewFolder(request.resource.data)) ||
          (request.resource.data.type == 'file' &&
            validNewFile(itemId, request.resource.data)) ||
          (request.resource.data.type == 'link' &&
            validNewLink(request.resource.data)));

      allow update: if canUseTeaching() &&
        request.resource.data.updatedBy == request.auth.uid &&
        request.resource.data.updatedAt == request.time && (
          curatorOrganizes() || curatorRequestsDelete() ||
          requesterCancelsDelete() || authorResubmits(itemId));

      // Sem delete pelo cliente: exclusões são feitas por Cloud Function.

      match /votes/{voteId} {
        function commentOk() {
          return request.resource.data.action in ['approve', 'delete_approve'] ||
            (request.resource.data.comment is string &&
              request.resource.data.comment.size() >= 1 &&
              request.resource.data.comment.size() <= 1000);
        }

        function publicationVoteOk() {
          let item = get(itemPath(itemId)).data;
          return item.status == 'in_review' &&
            item.authorId != request.auth.uid &&
            request.resource.data.version == item.version &&
            commentOk();
        }

        function deletionVoteOk() {
          let item = get(itemPath(itemId)).data;
          return item.get('deleteRequest', null) != null &&
            item.deleteRequest.requestedBy != request.auth.uid &&
            request.resource.data.requestId == item.deleteRequest.id &&
            commentOk();
        }

        allow read: if canUseTeaching() && (
          isCurator() || hasAdminClaim() ||
          get(itemPath(itemId)).data.authorId == request.auth.uid);

        allow create: if isCurator() &&
          request.resource.data.voterId == request.auth.uid &&
          request.resource.data.createdAt == request.time &&
          request.resource.data.keys().hasOnly(['voterId', 'action',
            'version', 'requestId', 'comment', 'createdAt']) && (
            (request.resource.data.action in ['approve', 'reject', 'return'] &&
              publicationVoteOk()) ||
            (request.resource.data.action in
              ['delete_approve', 'delete_refuse'] && deletionVoteOk()));

        allow update, delete: if false;
      }
    }

    match /teaching_notifications/{notificationId} {
      allow read: if request.auth != null &&
        resource.data.toUid == request.auth.uid;
      allow update: if request.auth != null &&
        resource.data.toUid == request.auth.uid &&
        request.resource.data.diff(resource.data).affectedKeys()
          .hasOnly(['readAt']);
      // create/delete: só Cloud Functions.
    }

    // teaching_log: sem acesso do cliente (negado por padrão).
```

Se alguma expressão não compilar ou se comportar diferente no emulador (por exemplo, `let` dentro de função, função declarada dentro de `match`, ou `.get()` em mapa), corrija a regra **mantendo a semântica descrita** e registre o ajuste no relatório.

- [ ] **Step 4: Rodar a suíte completa das regras**

Run: `npm --prefix rules-tests test`
Expected: PASS em `library.firestore.rules.test.ts`, `storage.rules.test.ts` e `users.rules.test.ts`. Confirme também que o bloco `users` e todos os blocos anteriores de `firestore.rules` continuam idênticos: `/usr/bin/git diff -U0 -- firestore.rules` deve mostrar **apenas linhas adicionadas**.

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add firestore.rules rules-tests/library.firestore.rules.test.ts
/usr/bin/git commit -m "feat(rules): regras do Firestore para itens, votos e notificações da biblioteca

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Domínio das Functions — tipos, decisões puras, mensagens e fakes

**Files:**
- Modify: `functions/.eslintrc.js`, `functions/package.json`
- Create: `functions/vitest.config.ts`, `functions/src/teaching/library/constants.ts`, `types.ts`, `util.ts`, `decide.ts`, `messages.ts`
- Create (testes): `functions/test/library/fakes.ts`, `decide.test.ts`, `messages.test.ts`

**Interfaces:**
- Consumes: contrato de dados da Task 2.
- Produces (usados nas Tasks 4 a 7): todos os tipos e portas abaixo, `decidePublication`, `decideDeletion`, `latestPerVoter`, `PUBLICATION_ACTIONS`, `DELETION_ACTIONS`, as funções de mensagem, `chunks`, `unique`, `safely` e as fábricas de teste (`makeItem`, `vote`, `makeDeps`).

- [ ] **Step 1: Configuração (lint e Vitest)**

Em `functions/.eslintrc.js`, acrescentar ao objeto exportado, logo depois de `rules: {...}`:

```js
  overrides: [
    {
      // Código novo da biblioteca: comentários curtos em vez de JSDoc completo.
      files: ["src/teaching/library/**/*.ts"],
      rules: {
        "require-jsdoc": "off",
        "valid-jsdoc": "off",
      },
    },
  ],
```

Criar `functions/vitest.config.ts`:

```ts
import {defineConfig} from "vitest/config";

export default defineConfig({
  test: {include: ["test/**/*.test.ts"]},
});
```

Run: `npm --prefix functions test`
Expected: os testes existentes (claims, syncClaims, backfillAudit) continuam PASS.

- [ ] **Step 2: Escrever os testes (que vão falhar)**

Criar `functions/test/library/fakes.ts` (portas em memória usadas por todas as tarefas seguintes):

```ts
import type {
  AuditEntry,
  ItemDoc,
  ItemPatch,
  LibraryDb,
  LibraryDeps,
  NotificationInput,
  Tx,
  VoteDoc,
} from "../../src/teaching/library/types";

export function makeItem(
  overrides: Partial<ItemDoc> & {id: string}
): ItemDoc {
  return {
    type: "file",
    name: overrides.id,
    parentId: null,
    authorId: "author",
    status: "in_review",
    version: 1,
    deleteRequest: null,
    ...overrides,
  };
}

export function vote(
  overrides: Partial<VoteDoc> & Pick<VoteDoc, "id" | "voterId" | "action">
): VoteDoc {
  return {createdAt: 1, ...overrides};
}

export class FakeDb implements LibraryDb {
  items = new Map<string, ItemDoc>();
  votes = new Map<string, VoteDoc[]>();

  constructor(items: ItemDoc[] = [], votes: Record<string, VoteDoc[]> = {}) {
    for (const item of items) this.items.set(item.id, item);
    for (const [id, list] of Object.entries(votes)) this.votes.set(id, list);
  }

  async getItem(id: string): Promise<ItemDoc | undefined> {
    const item = this.items.get(id);
    return item ? structuredClone(item) : undefined;
  }

  async listChildren(parentId: string): Promise<ItemDoc[]> {
    return [...this.items.values()]
      .filter((item) => item.parentId === parentId)
      .map((item) => structuredClone(item));
  }

  async updateItem(id: string, patch: ItemPatch): Promise<void> {
    const current = this.items.get(id);
    if (!current) throw new Error(`item ${id} não existe`);
    const clean = Object.fromEntries(
      Object.entries(patch).filter(([, value]) => value !== undefined)
    );
    this.items.set(id, {...current, ...clean});
  }

  async deleteItem(id: string): Promise<void> {
    this.items.delete(id);
    this.votes.delete(id);
  }

  async transact<T>(fn: (tx: Tx) => Promise<T>): Promise<T> {
    const writes: Array<[string, ItemPatch]> = [];
    const tx: Tx = {
      getItem: (id) => this.getItem(id),
      listVotes: async (id) => structuredClone(this.votes.get(id) ?? []),
      updateItem: (id, patch) => {
        writes.push([id, patch]);
      },
    };
    const result = await fn(tx);
    for (const [id, patch] of writes) await this.updateItem(id, patch);
    return result;
  }
}

export class FakeStorage {
  deleted: Array<{itemId: string; keepPath?: string}> = [];
  failNext = 0;

  async deleteItemFiles(itemId: string, keepPath?: string): Promise<void> {
    if (this.failNext > 0) {
      this.failNext--;
      throw new Error("storage fora do ar");
    }
    this.deleted.push({itemId, keepPath});
  }
}

export class FakeRoles {
  constructor(public curators: string[]) {}

  async currentCuratorIds(uids: string[]): Promise<Set<string>> {
    return new Set(uids.filter((uid) => this.curators.includes(uid)));
  }

  async allCuratorIds(): Promise<string[]> {
    return [...this.curators];
  }
}

export class FakeNotifier {
  sent: NotificationInput[] = [];

  async notify(n: NotificationInput): Promise<void> {
    this.sent.push(n);
  }
}

export class FakeAudit {
  entries: AuditEntry[] = [];

  async record(entry: AuditEntry): Promise<void> {
    this.entries.push(entry);
  }
}

export function makeDeps(options: {
  items?: ItemDoc[];
  votes?: Record<string, VoteDoc[]>;
  curators?: string[];
}) {
  const db = new FakeDb(options.items, options.votes);
  const storage = new FakeStorage();
  const roles = new FakeRoles(options.curators ?? []);
  const notifier = new FakeNotifier();
  const audit = new FakeAudit();
  const deps: LibraryDeps = {db, storage, roles, notifier, audit};
  return {deps, db, storage, roles, notifier, audit};
}
```

Criar `functions/test/library/decide.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {
  decideDeletion,
  decidePublication,
  latestPerVoter,
} from "../../src/teaching/library/decide";
import {makeItem, vote} from "./fakes";

const item = makeItem({id: "i1", authorId: "author", version: 1});
const curators = new Set(["c1", "c2", "c3"]);
const approve = (id: string, voterId: string, createdAt = 1) =>
  vote({id, voterId, action: "approve", version: 1, createdAt});

describe("latestPerVoter", () => {
  it("mantém só o último voto de cada votante", () => {
    const result = latestPerVoter([
      vote({id: "a", voterId: "c1", action: "approve", createdAt: 1}),
      vote({id: "b", voterId: "c1", action: "reject", createdAt: 2}),
      vote({id: "c", voterId: "c2", action: "approve", createdAt: 1}),
    ]);
    expect(result.map((v) => [v.voterId, v.action]).sort()).toEqual([
      ["c1", "reject"],
      ["c2", "approve"],
    ]);
  });
});

describe("decidePublication", () => {
  it("2 aprovações de curadores distintos publicam", () => {
    const d = decidePublication(item, [approve("a", "c1"), approve("b", "c2")], curators);
    expect(d).toEqual({type: "publish"});
  });

  it("1 aprovação não publica", () => {
    expect(decidePublication(item, [approve("a", "c1")], curators)).toEqual({type: "none"});
  });

  it("o mesmo curador aprovando duas vezes conta uma vez", () => {
    const d = decidePublication(item, [approve("a", "c1", 1), approve("b", "c1", 2)], curators);
    expect(d).toEqual({type: "none"});
  });

  it("voto do autor, de não-curador e de versão antiga não conta", () => {
    const votes = [
      approve("a", "author"),
      approve("b", "alguem-sem-papel"),
      vote({id: "c", voterId: "c1", action: "approve", version: 0}),
      approve("d", "c2"),
    ];
    const withAuthorCurator = new Set([...curators, "author"]);
    expect(decidePublication(item, votes, withAuthorCurator)).toEqual({type: "none"});
  });

  it("o último voto do curador vale (aprovou e depois rejeitou)", () => {
    const votes = [
      approve("a", "c1", 1),
      vote({id: "b", voterId: "c1", action: "reject", version: 1, createdAt: 2, comment: "Não"}),
      approve("c", "c2", 3),
    ];
    expect(decidePublication(item, votes, curators)).toEqual({type: "none"});
  });

  it("1 curador devolvendo basta e tem prioridade", () => {
    const votes = [
      approve("a", "c1"),
      approve("b", "c2"),
      vote({id: "c", voterId: "c3", action: "return", version: 1, comment: "Falta a referência", createdAt: 5}),
    ];
    expect(decidePublication(item, votes, curators)).toEqual({
      type: "return", by: "c3", comment: "Falta a referência",
    });
  });

  it("2 rejeições distintas rejeitam; 1 não", () => {
    const reject = (id: string, voterId: string, comment: string) =>
      vote({id, voterId, action: "reject", version: 1, comment});
    expect(decidePublication(item, [reject("a", "c1", "Fora do escopo")], curators)).toEqual({type: "none"});
    expect(decidePublication(item, [reject("a", "c1", "Fora do escopo"), reject("b", "c2", "Duplicado")], curators)).toEqual({
      type: "reject", comments: ["Fora do escopo", "Duplicado"], by: ["c1", "c2"],
    });
  });
});

describe("decideDeletion", () => {
  const withRequest = makeItem({
    id: "d1", status: "published",
    deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: 1},
  });
  const approveDel = (id: string, voterId: string, requestId = "r1") =>
    vote({id, voterId, action: "delete_approve", requestId});

  it("sem pedido aberto não há decisão", () => {
    expect(decideDeletion(makeItem({id: "x"}), [approveDel("a", "c2")], curators)).toEqual({type: "none"});
  });

  it("2 aprovações de outros curadores executam", () => {
    const d = decideDeletion(withRequest, [approveDel("a", "c2"), approveDel("b", "c3")], curators);
    expect(d).toEqual({type: "execute", by: ["c2", "c3"]});
  });

  it("aprovação de quem pediu e votos de outro pedido não contam", () => {
    const votes = [approveDel("a", "c1"), approveDel("b", "c2"), approveDel("c", "c3", "velho")];
    expect(decideDeletion(withRequest, votes, curators)).toEqual({type: "none"});
  });

  it("1 recusa encerra o pedido", () => {
    const votes = [
      approveDel("a", "c2"),
      vote({id: "b", voterId: "c3", action: "delete_refuse", requestId: "r1", comment: "Ainda é usado", createdAt: 3}),
    ];
    expect(decideDeletion(withRequest, votes, curators)).toEqual({
      type: "refuse", by: "c3", comment: "Ainda é usado",
    });
  });

  it("quem recusou e depois aprovou conta como aprovação (último voto)", () => {
    const votes = [
      vote({id: "a", voterId: "c2", action: "delete_refuse", requestId: "r1", comment: "Não", createdAt: 1}),
      vote({id: "b", voterId: "c2", action: "delete_approve", requestId: "r1", createdAt: 2}),
      approveDel("c", "c3"),
    ];
    expect(decideDeletion(withRequest, votes, curators)).toEqual({type: "execute", by: ["c2", "c3"]});
  });
});
```

Criar `functions/test/library/messages.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {
  deleteExecutedMessage,
  deleteRefusedMessage,
  deleteRequestedMessage,
  moveRevertedMessage,
  publishedMessage,
  rejectedMessage,
  returnedMessage,
  reviewRequestedMessage,
} from "../../src/teaching/library/messages";
import {makeItem} from "./fakes";

const item = makeItem({id: "i1", name: "Aula 1"});

describe("mensagens (pt-BR)", () => {
  it("novo envio e reenvio", () => {
    expect(reviewRequestedMessage(item, false)).toEqual({
      title: "Novo material para revisar",
      body: "\"Aula 1\" aguarda a sua revisão.",
    });
    expect(reviewRequestedMessage(item, true).title).toBe("Material reenviado para revisão");
  });

  it("publicado, devolvido e rejeitado", () => {
    expect(publishedMessage(item).title).toBe("Material publicado");
    expect(returnedMessage(item, "Falta a referência").body).toBe("\"Aula 1\": Falta a referência");
    expect(rejectedMessage(item, ["Fora do escopo", "Duplicado"]).body).toBe(
      "\"Aula 1\" foi rejeitado pelos curadores. Motivo: Fora do escopo | Duplicado"
    );
    expect(rejectedMessage(item, []).body).toBe("\"Aula 1\" foi rejeitado pelos curadores.");
  });

  it("pedido de exclusão, recusa, execução e movimento desfeito", () => {
    expect(deleteRequestedMessage(item).title).toBe("Pedido de exclusão");
    expect(deleteRefusedMessage(item, "Ainda é usado").body).toBe("A exclusão de \"Aula 1\" foi recusada: Ainda é usado");
    expect(deleteExecutedMessage(item).title).toBe("Exclusão concluída");
    expect(moveRevertedMessage(item).title).toBe("Movimento desfeito");
  });

  it("textos longos são cortados em 200 caracteres", () => {
    const long = makeItem({id: "i2", name: "x".repeat(300)});
    expect(publishedMessage(long).body.length).toBeLessThanOrEqual(200);
  });
});
```

- [ ] **Step 3: Rodar para ver falhar**

Run: `npm --prefix functions test`
Expected: FAIL — módulos `decide`, `messages` e `types` não existem.

- [ ] **Step 4: Implementar o domínio**

Criar `functions/src/teaching/library/constants.ts`:

```ts
export const ITEMS_COLLECTION = "teaching_items";
export const VOTES_SUBCOLLECTION = "votes";
export const NOTIFICATIONS_COLLECTION = "teaching_notifications";
export const AUDIT_COLLECTION = "teaching_log";
export const STORAGE_PREFIX = "teaching/materials";
export const DEFAULT_BUCKET = "app-ipe.firebasestorage.app";
export const PORTAL_URL = "https://ipe-ensino.vercel.app";
export const NOTIFICATION_PREFERENCE = "teaching_review";

export const REQUIRED_APPROVALS = 2;
export const REQUIRED_REJECTIONS = 2;
export const REQUIRED_DELETE_APPROVALS = 2;
export const MAX_DEPTH = 8;
export const BATCH_SIZE = 25;
```

Criar `functions/src/teaching/library/types.ts`:

```ts
export type ItemType = "folder" | "file" | "link";
export type ItemStatus = "active" | "in_review" | "returned" | "published";
export type VoteAction =
  | "approve"
  | "reject"
  | "return"
  | "delete_approve"
  | "delete_refuse";

export interface DeleteRequest {
  id: string;
  requestedBy: string;
  requestedAt: number;
  reason?: string;
}

// Visão de domínio de teaching_items/{id}; tempos em milissegundos.
export interface ItemDoc {
  id: string;
  type: ItemType;
  name: string;
  parentId: string | null;
  authorId: string;
  status: ItemStatus;
  version: number;
  updatedBy?: string;
  storagePath?: string;
  deleteRequest?: DeleteRequest | null;
  returnComment?: string | null;
  returnedBy?: string | null;
}

// Visão de domínio de teaching_items/{id}/votes/{voteId}.
export interface VoteDoc {
  id: string;
  voterId: string;
  action: VoteAction;
  version?: number;
  requestId?: string;
  comment?: string;
  createdAt: number;
}

// Campos que as Functions podem gravar no item.
export interface ItemPatch {
  status?: ItemStatus;
  returnComment?: string | null;
  returnedBy?: string | null;
  parentId?: string | null;
  deleteRequest?: DeleteRequest | null;
  deleteRequested?: boolean;
}

export interface Tx {
  getItem(id: string): Promise<ItemDoc | undefined>;
  listVotes(itemId: string): Promise<VoteDoc[]>;
  // Escritas são aplicadas ao final da transação.
  updateItem(id: string, patch: ItemPatch): void;
}

export interface LibraryDb {
  transact<T>(fn: (tx: Tx) => Promise<T>): Promise<T>;
  getItem(id: string): Promise<ItemDoc | undefined>;
  listChildren(parentId: string): Promise<ItemDoc[]>;
  updateItem(id: string, patch: ItemPatch): Promise<void>;
  // Apaga o documento e a subcoleção de votos.
  deleteItem(id: string): Promise<void>;
}

export interface LibraryStorage {
  // Apaga os objetos do item, exceto `keepPath` (caminho completo), se dado.
  deleteItemFiles(itemId: string, keepPath?: string): Promise<void>;
}

export interface RolesPort {
  // Dos uids dados, quem hoje tem teaching_role == curator no Auth.
  currentCuratorIds(uids: string[]): Promise<Set<string>>;
  allCuratorIds(): Promise<string[]>;
}

export interface NotificationInput {
  id: string; // determinístico: reprocessar não duplica
  toUid: string;
  type: string;
  itemId: string;
  title: string;
  body: string;
}

export interface Notifier {
  notify(n: NotificationInput): Promise<void>;
}

export interface AuditEntry {
  id: string; // determinístico
  action: string;
  itemId: string;
  itemName: string;
  actors: string[];
}

export interface AuditLog {
  record(entry: AuditEntry): Promise<void>;
}

export interface LibraryDeps {
  db: LibraryDb;
  storage: LibraryStorage;
  roles: RolesPort;
  notifier: Notifier;
  audit: AuditLog;
}
```

Criar `functions/src/teaching/library/util.ts`:

```ts
export function chunks<T>(list: T[], size: number): T[][] {
  const result: T[][] = [];
  for (let i = 0; i < list.length; i += size) {
    result.push(list.slice(i, i + size));
  }
  return result;
}

export function unique<T>(list: T[]): T[] {
  return [...new Set(list)];
}

// Efeitos de melhor esforço (notificação, auditoria): falha só é registrada.
export async function safely(
  label: string,
  fn: () => Promise<unknown>
): Promise<void> {
  try {
    await fn();
  } catch (error) {
    console.error(`Falha em ${label}:`, error);
  }
}
```

Criar `functions/src/teaching/library/decide.ts`:

```ts
import {
  REQUIRED_APPROVALS,
  REQUIRED_DELETE_APPROVALS,
  REQUIRED_REJECTIONS,
} from "./constants";
import type {ItemDoc, VoteAction, VoteDoc} from "./types";

export const PUBLICATION_ACTIONS: VoteAction[] = [
  "approve",
  "reject",
  "return",
];
export const DELETION_ACTIONS: VoteAction[] = [
  "delete_approve",
  "delete_refuse",
];

export type PublicationDecision =
  | {type: "none"}
  | {type: "publish"}
  | {type: "return"; by: string; comment: string}
  | {type: "reject"; comments: string[]; by: string[]};

export type DeletionDecision =
  | {type: "none"}
  | {type: "refuse"; by: string; comment: string}
  | {type: "execute"; by: string[]};

// Mantém só o último voto de cada votante (createdAt e, no empate, id).
export function latestPerVoter(votes: VoteDoc[]): VoteDoc[] {
  const sorted = [...votes].sort(
    (a, b) => a.createdAt - b.createdAt || a.id.localeCompare(b.id)
  );
  const byVoter = new Map<string, VoteDoc>();
  for (const v of sorted) byVoter.set(v.voterId, v);
  return [...byVoter.values()];
}

// Votos de publicação: versão atual, não-autor, curador hoje, último de cada.
export function decidePublication(
  item: ItemDoc,
  votes: VoteDoc[],
  validCurators: Set<string>
): PublicationDecision {
  const eligible = votes.filter(
    (v) =>
      PUBLICATION_ACTIONS.includes(v.action) &&
      v.version === item.version &&
      v.voterId !== item.authorId &&
      validCurators.has(v.voterId)
  );
  const latest = latestPerVoter(eligible);

  const returns = latest
    .filter((v) => v.action === "return")
    .sort((a, b) => b.createdAt - a.createdAt);
  if (returns.length > 0) {
    const first = returns[0];
    return {type: "return", by: first.voterId, comment: first.comment ?? ""};
  }

  const approvals = latest.filter((v) => v.action === "approve");
  if (approvals.length >= REQUIRED_APPROVALS) return {type: "publish"};

  const rejects = latest.filter((v) => v.action === "reject");
  if (rejects.length >= REQUIRED_REJECTIONS) {
    return {
      type: "reject",
      comments: rejects.map((v) => v.comment ?? ""),
      by: rejects.map((v) => v.voterId),
    };
  }
  return {type: "none"};
}

// Votos de exclusão: pedido atual, não-solicitante, curador hoje.
export function decideDeletion(
  item: ItemDoc,
  votes: VoteDoc[],
  validCurators: Set<string>
): DeletionDecision {
  const request = item.deleteRequest;
  if (!request) return {type: "none"};
  const eligible = votes.filter(
    (v) =>
      DELETION_ACTIONS.includes(v.action) &&
      v.requestId === request.id &&
      v.voterId !== request.requestedBy &&
      validCurators.has(v.voterId)
  );
  const latest = latestPerVoter(eligible);

  const refusals = latest
    .filter((v) => v.action === "delete_refuse")
    .sort((a, b) => b.createdAt - a.createdAt);
  if (refusals.length > 0) {
    const first = refusals[0];
    return {type: "refuse", by: first.voterId, comment: first.comment ?? ""};
  }

  const approvals = latest.filter((v) => v.action === "delete_approve");
  if (approvals.length >= REQUIRED_DELETE_APPROVALS) {
    return {type: "execute", by: approvals.map((v) => v.voterId)};
  }
  return {type: "none"};
}
```

Criar `functions/src/teaching/library/messages.ts`:

```ts
import type {ItemDoc} from "./types";

export interface Message {
  title: string;
  body: string;
}

const MAX_BODY = 200;

function clip(text: string): string {
  return text.length > MAX_BODY ? `${text.slice(0, MAX_BODY - 1)}…` : text;
}

function quoted(item: ItemDoc): string {
  return `"${item.name}"`;
}

export function reviewRequestedMessage(
  item: ItemDoc,
  resubmitted: boolean
): Message {
  return {
    title: resubmitted ?
      "Material reenviado para revisão" :
      "Novo material para revisar",
    body: clip(`${quoted(item)} aguarda a sua revisão.`),
  };
}

export function publishedMessage(item: ItemDoc): Message {
  return {
    title: "Material publicado",
    body: clip(`${quoted(item)} foi aprovado e já está na biblioteca.`),
  };
}

export function returnedMessage(item: ItemDoc, comment: string): Message {
  return {
    title: "Material devolvido",
    body: clip(`${quoted(item)}: ${comment}`),
  };
}

export function rejectedMessage(item: ItemDoc, comments: string[]): Message {
  const reasons = comments.filter((c) => c.length > 0);
  const suffix = reasons.length > 0 ? ` Motivo: ${reasons.join(" | ")}` : "";
  return {
    title: "Material rejeitado",
    body: clip(`${quoted(item)} foi rejeitado pelos curadores.${suffix}`),
  };
}

export function deleteRequestedMessage(item: ItemDoc): Message {
  return {
    title: "Pedido de exclusão",
    body: clip(
      `Foi pedida a exclusão de ${quoted(item)}. Sua aprovação é necessária.`
    ),
  };
}

export function deleteRefusedMessage(item: ItemDoc, comment: string): Message {
  return {
    title: "Exclusão recusada",
    body: clip(`A exclusão de ${quoted(item)} foi recusada: ${comment}`),
  };
}

export function deleteExecutedMessage(item: ItemDoc): Message {
  return {
    title: "Exclusão concluída",
    body: clip(`${quoted(item)} foi excluído da biblioteca.`),
  };
}

export function moveRevertedMessage(item: ItemDoc): Message {
  return {
    title: "Movimento desfeito",
    body: clip(
      `Não foi possível mover ${quoted(item)} para esse local ` +
      "(destino inválido ou profundidade máxima)."
    ),
  };
}
```

- [ ] **Step 5: Rodar testes, lint e build**

Run (um por vez): `npm --prefix functions test`, `npm --prefix functions run lint`, `npm --prefix functions run build`
Expected: testes PASS; lint e build limpos. Se o lint reclamar de formatação nos arquivos de `src/teaching/library/`, ajuste ao estilo (sem espaços em `{}`, 80 colunas, vírgula final, operadores no fim da linha) sem mudar comportamento, e relate.

- [ ] **Step 6: Commit**

```bash
/usr/bin/git add functions/.eslintrc.js functions/vitest.config.ts functions/src/teaching/library functions/test/library
/usr/bin/git commit -m "feat(functions): domínio da biblioteca (tipos, decisões puras, mensagens)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Processamento de votos (publicação, devolução, rejeição e exclusão)

**Files:**
- Create: `functions/src/teaching/library/subtree.ts`, `functions/src/teaching/library/processVote.ts`
- Create (teste): `functions/test/library/processVote.test.ts`

**Interfaces:**
- Consumes: tudo da Task 3 (`LibraryDeps`, `decidePublication`, `decideDeletion`, mensagens, `chunks`, `unique`, `safely`, `makeDeps`).
- Produces (usados nas Tasks 5 a 7):
  - `collectSubtree(db: LibraryDb, root: ItemDoc): Promise<ItemDoc[]>` (raiz primeiro, em largura)
  - `hasDocuments(items: ItemDoc[]): boolean` (algum `file` ou `link`)
  - `deleteSubtree(deps: LibraryDeps, root: ItemDoc): Promise<void>`
  - `type VoteOutcome = "skipped" | "none" | "returned" | "published" | "rejected" | "delete_refused" | "deleted"`
  - `processVote(deps: LibraryDeps, itemId: string, voteId: string): Promise<VoteOutcome>`
  - ids de notificação: `${tipo}_${itemId}_v${versão}_${uid}` para publicação e `${tipo}_${itemId}_${requestId}_${uid}` para exclusão.

- [ ] **Step 1: Escrever os testes (que vão falhar)**

Criar `functions/test/library/processVote.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {processVote} from "../../src/teaching/library/processVote";
import {makeDeps, makeItem, vote} from "./fakes";

const approve = (id: string, voterId: string, createdAt = 1) =>
  vote({id, voterId, action: "approve", version: 1, createdAt});

describe("processVote — publicação", () => {
  it("1ª aprovação não muda nada; a 2ª publica e avisa o autor", async () => {
    const t = makeDeps({
      items: [makeItem({id: "i1"})],
      curators: ["c1", "c2", "c3"],
      votes: {i1: [approve("v1", "c1", 1)]},
    });
    expect(await processVote(t.deps, "i1", "v1")).toBe("none");
    expect((await t.db.getItem("i1"))?.status).toBe("in_review");

    t.db.votes.set("i1", [approve("v1", "c1", 1), approve("v2", "c2", 2)]);
    expect(await processVote(t.deps, "i1", "v2")).toBe("published");
    expect((await t.db.getItem("i1"))?.status).toBe("published");
    expect(t.notifier.sent.map((n) => [n.toUid, n.type, n.id])).toEqual([
      ["author", "published", "published_i1_v1_author"],
    ]);
    expect(t.audit.entries.map((e) => e.action)).toEqual(["published"]);
  });

  it("reprocessar o voto depois de publicar não faz nada", async () => {
    const t = makeDeps({
      items: [makeItem({id: "i1", status: "published"})],
      curators: ["c1", "c2"],
      votes: {i1: [approve("v1", "c1", 1), approve("v2", "c2", 2)]},
    });
    expect(await processVote(t.deps, "i1", "v2")).toBe("skipped");
    expect(t.notifier.sent).toEqual([]);
  });

  it("voto de versão antiga é ignorado", async () => {
    const t = makeDeps({
      items: [makeItem({id: "i1", version: 2})],
      curators: ["c1", "c2"],
      votes: {i1: [approve("v1", "c1")]},
    });
    expect(await processVote(t.deps, "i1", "v1")).toBe("skipped");
  });

  it("curador rebaixado não conta; autor curador não conta", async () => {
    const demoted = makeDeps({
      items: [makeItem({id: "i1"})],
      curators: ["c2"],
      votes: {i1: [approve("v1", "c1", 1), approve("v2", "c2", 2)]},
    });
    expect(await processVote(demoted.deps, "i1", "v2")).toBe("none");

    const authorCurator = makeDeps({
      items: [makeItem({id: "i2", authorId: "c1"})],
      curators: ["c1", "c2", "c3"],
      votes: {i2: [approve("v1", "c1", 1), approve("v2", "c2", 2)]},
    });
    expect(await processVote(authorCurator.deps, "i2", "v2")).toBe("none");
    authorCurator.db.votes.get("i2")!.push(approve("v3", "c3", 3));
    expect(await processVote(authorCurator.deps, "i2", "v3")).toBe("published");
  });

  it("1 curador devolve: status returned, comentário guardado e autor avisado", async () => {
    const t = makeDeps({
      items: [makeItem({id: "i1", name: "Aula 3"})],
      curators: ["c1", "c2"],
      votes: {
        i1: [
          approve("v1", "c1", 1),
          vote({id: "v2", voterId: "c2", action: "return", version: 1, comment: "Falta a referência", createdAt: 2}),
        ],
      },
    });
    expect(await processVote(t.deps, "i1", "v2")).toBe("returned");
    const item = await t.db.getItem("i1");
    expect(item).toMatchObject({status: "returned", returnComment: "Falta a referência", returnedBy: "c2"});
    expect(t.notifier.sent).toHaveLength(1);
    expect(t.notifier.sent[0]).toMatchObject({toUid: "author", type: "returned"});
    expect(t.notifier.sent[0].body).toContain("Falta a referência");
  });

  it("2 rejeições apagam arquivos e item, e avisam o autor", async () => {
    const reject = (id: string, voterId: string, createdAt: number) =>
      vote({id, voterId, action: "reject", version: 1, comment: "Fora do escopo", createdAt});
    const t = makeDeps({
      items: [makeItem({id: "i1"})],
      curators: ["c1", "c2"],
      votes: {i1: [reject("v1", "c1", 1), reject("v2", "c2", 2)]},
    });
    expect(await processVote(t.deps, "i1", "v2")).toBe("rejected");
    expect(await t.db.getItem("i1")).toBeUndefined();
    expect(t.storage.deleted).toEqual([{itemId: "i1", keepPath: undefined}]);
    expect(t.notifier.sent.map((n) => [n.toUid, n.type])).toEqual([["author", "rejected"]]);
    expect(t.audit.entries[0]).toMatchObject({action: "rejected", itemId: "i1", actors: ["c1", "c2"]});
  });

  it("falha do Storage ao rejeitar: item continua e a retentativa conclui", async () => {
    const reject = (id: string, voterId: string, createdAt: number) =>
      vote({id, voterId, action: "reject", version: 1, comment: "Não", createdAt});
    const t = makeDeps({
      items: [makeItem({id: "i1"})],
      curators: ["c1", "c2"],
      votes: {i1: [reject("v1", "c1", 1), reject("v2", "c2", 2)]},
    });
    t.storage.failNext = 1;
    await expect(processVote(t.deps, "i1", "v2")).rejects.toThrow("storage fora do ar");
    expect(await t.db.getItem("i1")).toBeDefined();
    expect(await processVote(t.deps, "i1", "v2")).toBe("rejected");
    expect(await t.db.getItem("i1")).toBeUndefined();
  });

  it("votos de item inexistente ou voto inexistente são ignorados", async () => {
    const t = makeDeps({items: [makeItem({id: "i1"})], curators: ["c1"]});
    expect(await processVote(t.deps, "nao-existe", "v1")).toBe("skipped");
    expect(await processVote(t.deps, "i1", "v-nao-existe")).toBe("skipped");
  });
});

describe("processVote — exclusão", () => {
  const request = {id: "r1", requestedBy: "c1", requestedAt: 1};
  const approveDel = (id: string, voterId: string, requestId = "r1", createdAt = 1) =>
    vote({id, voterId, action: "delete_approve", requestId, createdAt});

  it("2 aprovações de outros curadores apagam o documento e arquivos; avisa quem pediu", async () => {
    const t = makeDeps({
      items: [makeItem({id: "d1", status: "published", deleteRequest: request})],
      curators: ["c1", "c2", "c3"],
      votes: {d1: [approveDel("v1", "c2", "r1", 1), approveDel("v2", "c3", "r1", 2)]},
    });
    expect(await processVote(t.deps, "d1", "v2")).toBe("deleted");
    expect(await t.db.getItem("d1")).toBeUndefined();
    expect(t.storage.deleted.map((d) => d.itemId)).toEqual(["d1"]);
    expect(t.notifier.sent.map((n) => [n.toUid, n.type, n.id])).toEqual([
      ["c1", "deleted", "deleted_d1_r1_c1"],
    ]);
  });

  it("aprovação de quem pediu não conta", async () => {
    const t = makeDeps({
      items: [makeItem({id: "d1", status: "published", deleteRequest: request})],
      curators: ["c1", "c2"],
      votes: {d1: [approveDel("v1", "c1", "r1", 1), approveDel("v2", "c2", "r1", 2)]},
    });
    expect(await processVote(t.deps, "d1", "v2")).toBe("none");
    expect(await t.db.getItem("d1")).toBeDefined();
  });

  it("1 recusa encerra o pedido e avisa quem pediu; votos do pedido antigo não valem no novo", async () => {
    const t = makeDeps({
      items: [makeItem({id: "d1", status: "published", deleteRequest: request})],
      curators: ["c1", "c2", "c3"],
      votes: {
        d1: [vote({id: "v1", voterId: "c2", action: "delete_refuse", requestId: "r1", comment: "Ainda é usado", createdAt: 1})],
      },
    });
    expect(await processVote(t.deps, "d1", "v1")).toBe("delete_refused");
    expect((await t.db.getItem("d1"))?.deleteRequest).toBeNull();
    expect(t.notifier.sent[0]).toMatchObject({toUid: "c1", type: "delete_refused"});

    // novo pedido (r2): votos do r1 não contam; vote com requestId velho é ignorado
    await t.db.updateItem("d1", {deleteRequest: {id: "r2", requestedBy: "c1", requestedAt: 5}, deleteRequested: true});
    t.db.votes.get("d1")!.push(approveDel("v9", "c3", "r1", 6));
    expect(await processVote(t.deps, "d1", "v9")).toBe("skipped");
  });

  it("pasta: apagar leva todos os níveis, arquivos e a raiz por último", async () => {
    const t = makeDeps({
      items: [
        makeItem({id: "F", type: "folder", status: "active", deleteRequest: request}),
        makeItem({id: "X", parentId: "F", status: "published"}),
        makeItem({id: "G", type: "folder", status: "active", parentId: "F"}),
        makeItem({id: "Y", parentId: "G", status: "published"}),
        makeItem({id: "Z", status: "published"}),
      ],
      curators: ["c1", "c2", "c3"],
      votes: {F: [approveDel("v1", "c2", "r1", 1), approveDel("v2", "c3", "r1", 2)]},
    });
    expect(await processVote(t.deps, "F", "v2")).toBe("deleted");
    expect([...t.db.items.keys()]).toEqual(["Z"]);
    expect(t.storage.deleted.map((d) => d.itemId).sort()).toEqual(["X", "Y"]);
  });
});
```

- [ ] **Step 2: Rodar para ver falhar**

Run: `npm --prefix functions test`
Expected: FAIL — `processVote` e `subtree` não existem.

- [ ] **Step 3: Implementar a subárvore e o processamento de votos**

Criar `functions/src/teaching/library/subtree.ts`:

```ts
import {BATCH_SIZE} from "./constants";
import type {ItemDoc, LibraryDb, LibraryDeps} from "./types";
import {chunks} from "./util";

// Raiz primeiro, depois filhos em largura.
export async function collectSubtree(
  db: LibraryDb,
  root: ItemDoc
): Promise<ItemDoc[]> {
  const result: ItemDoc[] = [root];
  const queue: ItemDoc[] = [root];
  while (queue.length > 0) {
    const current = queue.shift() as ItemDoc;
    if (current.type !== "folder") continue;
    const children = await db.listChildren(current.id);
    result.push(...children);
    queue.push(...children);
  }
  return result;
}

// Algum documento ou link (qualquer nível)?
export function hasDocuments(items: ItemDoc[]): boolean {
  return items.some((item) => item.type !== "folder");
}

// Arquivos primeiro; documentos de baixo para cima; a raiz por último, para a
// retentativa ainda encontrar a árvore se algo falhar no meio.
export async function deleteSubtree(
  deps: LibraryDeps,
  root: ItemDoc
): Promise<void> {
  const items = await collectSubtree(deps.db, root);
  const files = items.filter((item) => item.type === "file");
  for (const part of chunks(files, BATCH_SIZE)) {
    await Promise.all(part.map((i) => deps.storage.deleteItemFiles(i.id)));
  }
  const children = items.filter((item) => item.id !== root.id).reverse();
  for (const part of chunks(children, BATCH_SIZE)) {
    await Promise.all(part.map((i) => deps.db.deleteItem(i.id)));
  }
  await deps.db.deleteItem(root.id);
}
```

Criar `functions/src/teaching/library/processVote.ts`:

```ts
import {
  decideDeletion,
  decidePublication,
  DELETION_ACTIONS,
  PUBLICATION_ACTIONS,
} from "./decide";
import type {DeletionDecision, PublicationDecision} from "./decide";
import * as msg from "./messages";
import {deleteSubtree} from "./subtree";
import type {ItemDoc, LibraryDeps} from "./types";
import {safely, unique} from "./util";

export type VoteOutcome =
  | "skipped"
  | "none"
  | "returned"
  | "published"
  | "rejected"
  | "delete_refused"
  | "deleted";

type TxResult =
  | {kind: "skip"}
  | {kind: "publication"; item: ItemDoc; decision: PublicationDecision}
  | {kind: "deletion"; item: ItemDoc; decision: DeletionDecision};

// Processa um voto recém-criado. Transições de estado acontecem na transação;
// remoções (Storage e documentos) são idempotentes e reexecutáveis;
// notificações e auditoria são de melhor esforço.
export async function processVote(
  deps: LibraryDeps,
  itemId: string,
  voteId: string
): Promise<VoteOutcome> {
  const result = await deps.db.transact<TxResult>(async (tx) => {
    const item = await tx.getItem(itemId);
    if (!item) return {kind: "skip"};
    const votes = await tx.listVotes(itemId);
    const current = votes.find((v) => v.id === voteId);
    if (!current) return {kind: "skip"};
    const voterIds = unique(votes.map((v) => v.voterId));

    if (PUBLICATION_ACTIONS.includes(current.action)) {
      if (item.status !== "in_review") return {kind: "skip"};
      if (current.version !== item.version) return {kind: "skip"};
      const valid = await deps.roles.currentCuratorIds(voterIds);
      const decision = decidePublication(item, votes, valid);
      if (decision.type === "return") {
        tx.updateItem(item.id, {
          status: "returned",
          returnComment: decision.comment,
          returnedBy: decision.by,
        });
      } else if (decision.type === "publish") {
        tx.updateItem(item.id, {
          status: "published",
          returnComment: null,
          returnedBy: null,
        });
      }
      return {kind: "publication", item, decision};
    }

    if (DELETION_ACTIONS.includes(current.action)) {
      const request = item.deleteRequest;
      if (!request || current.requestId !== request.id) {
        return {kind: "skip"};
      }
      const valid = await deps.roles.currentCuratorIds(voterIds);
      const decision = decideDeletion(item, votes, valid);
      if (decision.type === "refuse") {
        tx.updateItem(item.id, {deleteRequest: null, deleteRequested: false});
      }
      return {kind: "deletion", item, decision};
    }
    return {kind: "skip"};
  });

  if (result.kind === "skip") return "skipped";
  if (result.kind === "publication") {
    return applyPublication(deps, result.item, result.decision);
  }
  return applyDeletion(deps, result.item, result.decision);
}

async function applyPublication(
  deps: LibraryDeps,
  item: ItemDoc,
  decision: PublicationDecision
): Promise<VoteOutcome> {
  const stamp = `${item.id}_v${item.version}`;
  if (decision.type === "return") {
    const m = msg.returnedMessage(item, decision.comment);
    await safely("notificar devolução", () =>
      deps.notifier.notify({
        id: `returned_${stamp}_${item.authorId}`,
        toUid: item.authorId,
        type: "returned",
        itemId: item.id,
        ...m,
      })
    );
    await safely("auditar devolução", () =>
      deps.audit.record({
        id: `returned_${stamp}`,
        action: "returned",
        itemId: item.id,
        itemName: item.name,
        actors: [decision.by],
      })
    );
    return "returned";
  }
  if (decision.type === "publish") {
    const m = msg.publishedMessage(item);
    await safely("notificar publicação", () =>
      deps.notifier.notify({
        id: `published_${stamp}_${item.authorId}`,
        toUid: item.authorId,
        type: "published",
        itemId: item.id,
        ...m,
      })
    );
    await safely("auditar publicação", () =>
      deps.audit.record({
        id: `published_${stamp}`,
        action: "published",
        itemId: item.id,
        itemName: item.name,
        actors: [],
      })
    );
    return "published";
  }
  if (decision.type === "reject") {
    await safely("auditar rejeição", () =>
      deps.audit.record({
        id: `rejected_${stamp}`,
        action: "rejected",
        itemId: item.id,
        itemName: item.name,
        actors: decision.by,
      })
    );
    await deps.storage.deleteItemFiles(item.id);
    await deps.db.deleteItem(item.id);
    const m = msg.rejectedMessage(item, decision.comments);
    await safely("notificar rejeição", () =>
      deps.notifier.notify({
        id: `rejected_${stamp}_${item.authorId}`,
        toUid: item.authorId,
        type: "rejected",
        itemId: item.id,
        ...m,
      })
    );
    return "rejected";
  }
  return "none";
}

async function applyDeletion(
  deps: LibraryDeps,
  item: ItemDoc,
  decision: DeletionDecision
): Promise<VoteOutcome> {
  const request = item.deleteRequest;
  if (!request) return "none";
  const stamp = `${item.id}_${request.id}`;
  if (decision.type === "refuse") {
    const m = msg.deleteRefusedMessage(item, decision.comment);
    await safely("notificar recusa", () =>
      deps.notifier.notify({
        id: `delete_refused_${stamp}_${request.requestedBy}`,
        toUid: request.requestedBy,
        type: "delete_refused",
        itemId: item.id,
        ...m,
      })
    );
    await safely("auditar recusa", () =>
      deps.audit.record({
        id: `delete_refused_${stamp}`,
        action: "delete_refused",
        itemId: item.id,
        itemName: item.name,
        actors: [request.requestedBy, decision.by],
      })
    );
    return "delete_refused";
  }
  if (decision.type === "execute") {
    await safely("auditar exclusão", () =>
      deps.audit.record({
        id: `deleted_${stamp}`,
        action: "deleted",
        itemId: item.id,
        itemName: item.name,
        actors: [request.requestedBy, ...decision.by],
      })
    );
    await deleteSubtree(deps, item);
    const m = msg.deleteExecutedMessage(item);
    await safely("notificar exclusão", () =>
      deps.notifier.notify({
        id: `deleted_${stamp}_${request.requestedBy}`,
        toUid: request.requestedBy,
        type: "deleted",
        itemId: item.id,
        ...m,
      })
    );
    return "deleted";
  }
  return "none";
}
```

- [ ] **Step 4: Rodar testes, lint e build**

Run (um por vez): `npm --prefix functions test`, `npm --prefix functions run lint`, `npm --prefix functions run build`
Expected: PASS; lint e build limpos (ajuste só formatação, se preciso).

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add functions/src/teaching/library functions/test/library
/usr/bin/git commit -m "feat(functions): processamento de votos da biblioteca (publicar, devolver, rejeitar, excluir)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Processamento de mudanças em itens (criação, reenvio, movimento, pedido de exclusão)

**Files:**
- Create: `functions/src/teaching/library/moves.ts`, `functions/src/teaching/library/processItemChange.ts`
- Create (teste): `functions/test/library/processItemChange.test.ts`

**Interfaces:**
- Consumes: Tasks 3 e 4 (`LibraryDeps`, `collectSubtree`, `hasDocuments`, `deleteSubtree`, mensagens, `safely`, `MAX_DEPTH`).
- Produces:
  - `moveIsValid(db: LibraryDb, item: ItemDoc): Promise<boolean>` — `item` já com o novo `parentId`; falso se o pai não existe/não é pasta, se há ciclo ou se nível total > `MAX_DEPTH` (nível = ancestrais + 1 + altura da subárvore).
  - `type ChangeOutcome = "none" | "resubmitted" | "moved" | "move_reverted" | "delete_requested" | "deleted_empty_folder"`
  - `processItemChange(deps: LibraryDeps, before: ItemDoc, after: ItemDoc): Promise<ChangeOutcome>`
  - `processItemCreated(deps: LibraryDeps, item: ItemDoc): Promise<void>` — avisa os curadores (exceto o autor) de documento/link `in_review`.

- [ ] **Step 1: Escrever os testes (que vão falhar)**

Criar `functions/test/library/processItemChange.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {moveIsValid} from "../../src/teaching/library/moves";
import {
  processItemChange,
  processItemCreated,
} from "../../src/teaching/library/processItemChange";
import {makeDeps, makeItem} from "./fakes";

const folder = (id: string, parentId: string | null = null) =>
  makeItem({id, type: "folder", status: "active", parentId, authorId: "c1"});

function chain(n: number) {
  return Array.from({length: n}, (_, i) =>
    folder(`d${i + 1}`, i === 0 ? null : `d${i}`));
}

describe("moveIsValid", () => {
  it("mover para a raiz ou para uma pasta é válido", async () => {
    const t = makeDeps({items: [folder("A"), makeItem({id: "x", parentId: "A"})]});
    expect(await moveIsValid(t.db, makeItem({id: "x", parentId: null}))).toBe(true);
    expect(await moveIsValid(t.db, makeItem({id: "x", parentId: "A"}))).toBe(true);
  });

  it("pasta para dentro de si mesma ou de um descendente cria ciclo", async () => {
    const t = makeDeps({items: [folder("A"), folder("B", "A"), folder("C", "B")]});
    expect(await moveIsValid(t.db, folder("A", "A"))).toBe(false);
    expect(await moveIsValid(t.db, folder("A", "C"))).toBe(false);
  });

  it("pai inexistente ou que não é pasta é inválido", async () => {
    const t = makeDeps({items: [makeItem({id: "arq", status: "published"})]});
    expect(await moveIsValid(t.db, makeItem({id: "x", parentId: "arq"}))).toBe(false);
    expect(await moveIsValid(t.db, makeItem({id: "x", parentId: "fantasma"}))).toBe(false);
  });

  it("limite de 8 níveis considera ancestrais e a altura da subárvore", async () => {
    const t = makeDeps({items: chain(8)});
    // arquivo dentro de d7 fica no nível 8 (ok); dentro de d8 ficaria no 9 (inválido)
    expect(await moveIsValid(t.db, makeItem({id: "x", parentId: "d7"}))).toBe(true);
    expect(await moveIsValid(t.db, makeItem({id: "x", parentId: "d8"}))).toBe(false);

    // pasta com subárvore de 3 níveis (S > S2 > S3) movida para d5: 5 + 1 + 2 = 8 (ok), para d6: 9 (inválido)
    const t2 = makeDeps({items: [...chain(8), folder("S"), folder("S2", "S"), folder("S3", "S2")]});
    expect(await moveIsValid(t2.db, folder("S", "d5"))).toBe(true);
    expect(await moveIsValid(t2.db, folder("S", "d6"))).toBe(false);
  });
});

describe("processItemChange — movimento", () => {
  it("movimento inválido é desfeito e quem moveu é avisado", async () => {
    const before = folder("A", null);
    const after = {...folder("A", "C"), updatedBy: "c2"};
    const t = makeDeps({items: [after, folder("B", "A"), folder("C", "B")], curators: ["c1", "c2"]});
    expect(await processItemChange(t.deps, before, after)).toBe("move_reverted");
    expect((await t.db.getItem("A"))?.parentId).toBeNull();
    expect(t.notifier.sent.map((n) => [n.toUid, n.type])).toEqual([["c2", "move_reverted"]]);
  });

  it("movimento válido não faz nada", async () => {
    const before = folder("A", null);
    const after = {...folder("A", "B"), updatedBy: "c2"};
    const t = makeDeps({items: [after, folder("B")], curators: ["c1"]});
    expect(await processItemChange(t.deps, before, after)).toBe("moved");
    expect((await t.db.getItem("A"))?.parentId).toBe("B");
    expect(t.notifier.sent).toEqual([]);
  });
});

describe("processItemChange — reenvio", () => {
  it("item devolvido que volta para revisão limpa a versão antiga e avisa os curadores", async () => {
    const before = makeItem({id: "i1", status: "returned", version: 1, authorId: "t1", storagePath: "teaching/materials/i1/v1-a.pdf"});
    const after = makeItem({id: "i1", status: "in_review", version: 2, authorId: "t1", storagePath: "teaching/materials/i1/v2-b.pdf"});
    const t = makeDeps({items: [after], curators: ["c1", "c2", "t1"]});
    expect(await processItemChange(t.deps, before, after)).toBe("resubmitted");
    expect(t.storage.deleted).toEqual([{itemId: "i1", keepPath: "teaching/materials/i1/v2-b.pdf"}]);
    expect(t.notifier.sent.map((n) => [n.toUid, n.type, n.id])).toEqual([
      ["c1", "review_requested", "review_requested_i1_v2_c1"],
      ["c2", "review_requested", "review_requested_i1_v2_c2"],
    ]);
  });

  it("falha do Storage no reenvio lança erro (retentativa)", async () => {
    const before = makeItem({id: "i1", status: "returned", version: 1});
    const after = makeItem({id: "i1", status: "in_review", version: 2, storagePath: "p"});
    const t = makeDeps({items: [after], curators: ["c1"]});
    t.storage.failNext = 1;
    await expect(processItemChange(t.deps, before, after)).rejects.toThrow("storage fora do ar");
  });
});

describe("processItemChange — pedido de exclusão", () => {
  const request = {id: "r1", requestedBy: "c1", requestedAt: 1};

  it("documento: avisa os outros curadores", async () => {
    const before = makeItem({id: "d1", status: "published"});
    const after = makeItem({id: "d1", status: "published", deleteRequest: request});
    const t = makeDeps({items: [after], curators: ["c1", "c2", "c3"]});
    expect(await processItemChange(t.deps, before, after)).toBe("delete_requested");
    expect(t.notifier.sent.map((n) => [n.toUid, n.type, n.id])).toEqual([
      ["c2", "delete_requested", "delete_requested_d1_r1_c2"],
      ["c3", "delete_requested", "delete_requested_d1_r1_c3"],
    ]);
    expect(await t.db.getItem("d1")).toBeDefined();
  });

  it("pasta sem nenhum documento (mesmo com subpastas) é apagada na hora", async () => {
    const before = folder("F");
    const after = {...folder("F"), deleteRequest: request};
    const t = makeDeps({items: [after, folder("G", "F"), folder("H", "G")], curators: ["c1", "c2"]});
    expect(await processItemChange(t.deps, before, after)).toBe("deleted_empty_folder");
    expect([...t.db.items.keys()]).toEqual([]);
    expect(t.audit.entries[0]).toMatchObject({action: "deleted_empty_folder", itemId: "F"});
  });

  it("pasta com documento em qualquer nível exige os 2 curadores", async () => {
    const before = folder("F");
    const after = {...folder("F"), deleteRequest: request};
    const t = makeDeps({
      items: [after, folder("G", "F"), makeItem({id: "Y", parentId: "G", status: "in_review"})],
      curators: ["c1", "c2"],
    });
    expect(await processItemChange(t.deps, before, after)).toBe("delete_requested");
    expect(t.db.items.size).toBe(3);
    expect(t.notifier.sent.map((n) => n.toUid)).toEqual(["c2"]);
  });

  it("cancelar o pedido não faz nada", async () => {
    const before = makeItem({id: "d1", status: "published", deleteRequest: request});
    const after = makeItem({id: "d1", status: "published", deleteRequest: null});
    const t = makeDeps({items: [after], curators: ["c1", "c2"]});
    expect(await processItemChange(t.deps, before, after)).toBe("none");
    expect(t.notifier.sent).toEqual([]);
  });

  it("atualização sem efeito (renomear) não faz nada", async () => {
    const before = makeItem({id: "d1", status: "published", name: "A"});
    const after = makeItem({id: "d1", status: "published", name: "B"});
    const t = makeDeps({items: [after], curators: ["c1"]});
    expect(await processItemChange(t.deps, before, after)).toBe("none");
  });
});

describe("processItemCreated", () => {
  it("documento em revisão avisa os curadores, exceto o autor", async () => {
    const item = makeItem({id: "i1", authorId: "c1"});
    const t = makeDeps({items: [item], curators: ["c1", "c2", "c3"]});
    await processItemCreated(t.deps, item);
    expect(t.notifier.sent.map((n) => [n.toUid, n.id])).toEqual([
      ["c2", "review_requested_i1_v1_c2"],
      ["c3", "review_requested_i1_v1_c3"],
    ]);
  });

  it("pasta não gera aviso", async () => {
    const t = makeDeps({items: [folder("F")], curators: ["c1", "c2"]});
    await processItemCreated(t.deps, folder("F"));
    expect(t.notifier.sent).toEqual([]);
  });
});
```

- [ ] **Step 2: Rodar para ver falhar**

Run: `npm --prefix functions test`
Expected: FAIL — `moves` e `processItemChange` não existem.

- [ ] **Step 3: Implementar**

Criar `functions/src/teaching/library/moves.ts`:

```ts
import {MAX_DEPTH} from "./constants";
import type {ItemDoc, LibraryDb} from "./types";

// Altura da subárvore: níveis abaixo do item (0 para arquivo ou pasta vazia).
async function subtreeHeight(db: LibraryDb, item: ItemDoc): Promise<number> {
  if (item.type !== "folder") return 0;
  const children = await db.listChildren(item.id);
  let height = 0;
  for (const child of children) {
    height = Math.max(height, 1 + (await subtreeHeight(db, child)));
  }
  return height;
}

// `item` já traz o novo parentId (o documento foi gravado). Inválido se o pai
// não existe ou não é pasta, se há ciclo, ou se o nível total passa do limite.
export async function moveIsValid(
  db: LibraryDb,
  item: ItemDoc
): Promise<boolean> {
  let ancestors = 0;
  if (item.parentId !== null) {
    const seen = new Set<string>([item.id]);
    let current = await db.getItem(item.parentId);
    while (current) {
      if (seen.has(current.id)) return false;
      if (current.type !== "folder") return false;
      seen.add(current.id);
      ancestors++;
      if (ancestors > MAX_DEPTH) return false;
      if (current.parentId === null) break;
      current = await db.getItem(current.parentId);
    }
    if (!current) return false;
  }
  const height = await subtreeHeight(db, item);
  return ancestors + 1 + height <= MAX_DEPTH;
}
```

Criar `functions/src/teaching/library/processItemChange.ts`:

```ts
import * as msg from "./messages";
import {moveIsValid} from "./moves";
import {collectSubtree, deleteSubtree, hasDocuments} from "./subtree";
import type {ItemDoc, LibraryDeps} from "./types";
import {safely} from "./util";

export type ChangeOutcome =
  | "none"
  | "resubmitted"
  | "moved"
  | "move_reverted"
  | "delete_requested"
  | "deleted_empty_folder";

async function notifyCurators(
  deps: LibraryDeps,
  item: ItemDoc,
  except: string,
  type: string,
  idStamp: string,
  message: msg.Message
): Promise<void> {
  const curators = await deps.roles.allCuratorIds();
  for (const uid of curators.filter((id) => id !== except)) {
    await safely(`notificar ${type}`, () =>
      deps.notifier.notify({
        id: `${type}_${idStamp}_${uid}`,
        toUid: uid,
        type,
        itemId: item.id,
        ...message,
      })
    );
  }
}

// Novo documento ou link em revisão: avisa os curadores (menos o autor).
export async function processItemCreated(
  deps: LibraryDeps,
  item: ItemDoc
): Promise<void> {
  if (item.type === "folder" || item.status !== "in_review") return;
  await notifyCurators(
    deps,
    item,
    item.authorId,
    "review_requested",
    `${item.id}_v${item.version}`,
    msg.reviewRequestedMessage(item, false)
  );
  await safely("auditar envio", () =>
    deps.audit.record({
      id: `submitted_${item.id}_v${item.version}`,
      action: "submitted",
      itemId: item.id,
      itemName: item.name,
      actors: [item.authorId],
    })
  );
}

export async function processItemChange(
  deps: LibraryDeps,
  before: ItemDoc,
  after: ItemDoc
): Promise<ChangeOutcome> {
  // 1) Movimento
  if (before.parentId !== after.parentId) {
    if (await moveIsValid(deps.db, after)) return "moved";
    await deps.db.updateItem(after.id, {parentId: before.parentId});
    const mover = after.updatedBy;
    if (mover) {
      const m = msg.moveRevertedMessage(after);
      await safely("notificar movimento desfeito", () =>
        deps.notifier.notify({
          id: `move_reverted_${after.id}_${mover}_${after.parentId}`,
          toUid: mover,
          type: "move_reverted",
          itemId: after.id,
          ...m,
        })
      );
    }
    return "move_reverted";
  }

  // 2) Reenvio após devolução
  const resubmitted =
    before.status === "returned" &&
    after.status === "in_review" &&
    after.version === before.version + 1;
  if (resubmitted) {
    await deps.storage.deleteItemFiles(after.id, after.storagePath);
    await notifyCurators(
      deps,
      after,
      after.authorId,
      "review_requested",
      `${after.id}_v${after.version}`,
      msg.reviewRequestedMessage(after, true)
    );
    await safely("auditar reenvio", () =>
      deps.audit.record({
        id: `resubmitted_${after.id}_v${after.version}`,
        action: "resubmitted",
        itemId: after.id,
        itemName: after.name,
        actors: [after.authorId],
      })
    );
    return "resubmitted";
  }

  // 3) Pedido de exclusão aberto
  const opened = !before.deleteRequest && !!after.deleteRequest;
  if (opened && after.deleteRequest) {
    const request = after.deleteRequest;
    if (after.type === "folder") {
      const subtree = await collectSubtree(deps.db, after);
      if (!hasDocuments(subtree)) {
        await safely("auditar exclusão de pasta vazia", () =>
          deps.audit.record({
            id: `deleted_empty_folder_${after.id}_${request.id}`,
            action: "deleted_empty_folder",
            itemId: after.id,
            itemName: after.name,
            actors: [request.requestedBy],
          })
        );
        await deleteSubtree(deps, after);
        return "deleted_empty_folder";
      }
    }
    await notifyCurators(
      deps,
      after,
      request.requestedBy,
      "delete_requested",
      `${after.id}_${request.id}`,
      msg.deleteRequestedMessage(after)
    );
    await safely("auditar pedido de exclusão", () =>
      deps.audit.record({
        id: `delete_requested_${after.id}_${request.id}`,
        action: "delete_requested",
        itemId: after.id,
        itemName: after.name,
        actors: [request.requestedBy],
      })
    );
    return "delete_requested";
  }

  return "none";
}
```

- [ ] **Step 4: Rodar testes, lint e build**

Run (um por vez): `npm --prefix functions test`, `npm --prefix functions run lint`, `npm --prefix functions run build`
Expected: PASS; lint e build limpos.

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add functions/src/teaching/library functions/test/library
/usr/bin/git commit -m "feat(functions): criação, reenvio, movimento e pedidos de exclusão da biblioteca

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Adaptadores reais (Firestore, Storage, Auth, notificações) com testes

**Files:**
- Modify: `functions/package.json` (script `test:emulator`)
- Create: `functions/vitest.emulator.config.ts`
- Create: `functions/src/teaching/library/convert.ts`, `adapterDb.ts`, `adapterStorage.ts`, `adapterRoles.ts`, `adapterNotifier.ts`
- Create (testes): `functions/test/library/adapterRoles.test.ts`, `adapterStorage.test.ts`, `functions/test-emulator/adapterDb.test.ts`, `adapterNotifier.test.ts`

**Interfaces:**
- Consumes: portas e constantes das Tasks 3 e 4.
- Produces (usados na Task 7):
  - `toItem(snap: admin.firestore.DocumentSnapshot): ItemDoc`, `toVote(snap): VoteDoc`
  - `createAdminLibraryDb(firestore: admin.firestore.Firestore): LibraryDb`
  - `createBucketStorage(bucket: Bucket): LibraryStorage` (`type Bucket = ReturnType<admin.storage.Storage["bucket"]>`)
  - `createAuthRoles(auth: AuthLike): RolesPort`, onde `AuthLike` expõe `getUsers(ids)` e `listUsers(max, token?)`
  - `createFirestoreNotifier(firestore, messaging): Notifier` e `createFirestoreAudit(firestore): AuditLog`
  - URL do push: `${PORTAL_URL}/ensino/biblioteca?item=${itemId}`; dado do push `type: "teaching_review"`.

- [ ] **Step 1: Escrever os testes (que vão falhar)**

Criar `functions/vitest.emulator.config.ts`:

```ts
import {defineConfig} from "vitest/config";

export default defineConfig({
  test: {
    include: ["test-emulator/**/*.test.ts"],
    fileParallelism: false,
    testTimeout: 30000,
  },
});
```

Em `functions/package.json`, acrescentar aos `scripts`:

```json
    "test:emulator": "../rules-tests/node_modules/.bin/firebase emulators:exec --only firestore --project demo-ipe-rules \"vitest run --config vitest.emulator.config.ts\"",
```

Criar `functions/test/library/adapterRoles.test.ts`:

```ts
import {describe, expect, it, vi} from "vitest";
import {createAuthRoles} from "../../src/teaching/library/adapterRoles";

describe("createAuthRoles", () => {
  it("currentCuratorIds filtra quem hoje é curador e consulta em lotes de 100", async () => {
    const uids = Array.from({length: 150}, (_, i) => `u${i}`);
    const getUsers = vi.fn(async (ids: Array<{uid: string}>) => ({
      users: ids.map(({uid}) => ({
        uid,
        customClaims: Number(uid.slice(1)) % 50 === 0 ?
          {teaching_role: "curator"} :
          {teaching_role: "teacher"},
      })),
    }));
    const roles = createAuthRoles({getUsers, listUsers: vi.fn()});
    const result = await roles.currentCuratorIds([...uids, ...uids]);
    expect([...result].sort()).toEqual(["u0", "u100", "u50"]);
    expect(getUsers).toHaveBeenCalledTimes(2);
    expect(getUsers.mock.calls[0][0]).toHaveLength(100);
  });

  it("claims ausentes não contam", async () => {
    const getUsers = vi.fn(async () => ({users: [{uid: "a"}, {uid: "b", customClaims: {admin: true}}]}));
    const roles = createAuthRoles({getUsers, listUsers: vi.fn()});
    expect((await roles.currentCuratorIds(["a", "b"])).size).toBe(0);
  });

  it("allCuratorIds percorre todas as páginas", async () => {
    const listUsers = vi.fn()
      .mockResolvedValueOnce({users: [{uid: "a", customClaims: {teaching_role: "curator"}}, {uid: "b"}], pageToken: "t2"})
      .mockResolvedValueOnce({users: [{uid: "c", customClaims: {teaching_role: "curator"}}]});
    const roles = createAuthRoles({getUsers: vi.fn(), listUsers});
    expect(await roles.allCuratorIds()).toEqual(["a", "c"]);
    expect(listUsers).toHaveBeenNthCalledWith(2, 1000, "t2");
  });
});
```

Criar `functions/test/library/adapterStorage.test.ts`:

```ts
import {describe, expect, it, vi} from "vitest";
import {createBucketStorage} from "../../src/teaching/library/adapterStorage";

type FakeFile = {name: string; delete: ReturnType<typeof vi.fn>};
const file = (name: string): FakeFile => ({name, delete: vi.fn(async () => undefined)});

function fakeBucket(files: FakeFile[]) {
  return {getFiles: vi.fn(async () => [files])};
}

describe("createBucketStorage", () => {
  it("lista pelo prefixo do item e apaga tudo", async () => {
    const files = [file("teaching/materials/i1/v1-a.pdf"), file("teaching/materials/i1/v2-b.pdf")];
    const bucket = fakeBucket(files);
    await createBucketStorage(bucket as never).deleteItemFiles("i1");
    expect(bucket.getFiles).toHaveBeenCalledWith({prefix: "teaching/materials/i1/"});
    expect(files[0].delete).toHaveBeenCalledWith({ignoreNotFound: true});
    expect(files[1].delete).toHaveBeenCalledWith({ignoreNotFound: true});
  });

  it("mantém o objeto atual (keepPath) e apaga os outros", async () => {
    const files = [file("teaching/materials/i1/v1-a.pdf"), file("teaching/materials/i1/v2-b.pdf")];
    await createBucketStorage(fakeBucket(files) as never).deleteItemFiles("i1", "teaching/materials/i1/v2-b.pdf");
    expect(files[0].delete).toHaveBeenCalled();
    expect(files[1].delete).not.toHaveBeenCalled();
  });

  it("item sem objetos não falha", async () => {
    await expect(createBucketStorage(fakeBucket([]) as never).deleteItemFiles("i1")).resolves.toBeUndefined();
  });
});
```

Criar `functions/test-emulator/adapterDb.test.ts`:

```ts
import * as admin from "firebase-admin";
import {beforeAll, beforeEach, describe, expect, it} from "vitest";
import {createAdminLibraryDb} from "../src/teaching/library/adapterDb";

let firestore: admin.firestore.Firestore;

beforeAll(() => {
  admin.initializeApp({projectId: "demo-ipe-rules"});
  firestore = admin.firestore();
});

beforeEach(async () => {
  await firestore.recursiveDelete(firestore.collection("teaching_items"));
});

const item = (id: string, extra: Record<string, unknown> = {}) => ({
  type: "file", name: id, parentId: null, authorId: "t1", status: "in_review", version: 1,
  ...extra,
});

describe("createAdminLibraryDb", () => {
  it("getItem converte campos, timestamps e valores ausentes", async () => {
    await firestore.doc("teaching_items/a").set(item("a", {
      deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: admin.firestore.Timestamp.fromMillis(1234), reason: "x"},
      storagePath: "teaching/materials/a/v1-a.pdf",
    }));
    const db = createAdminLibraryDb(firestore);
    expect(await db.getItem("a")).toEqual({
      id: "a", type: "file", name: "a", parentId: null, authorId: "t1", status: "in_review", version: 1,
      updatedBy: undefined, storagePath: "teaching/materials/a/v1-a.pdf",
      deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: 1234, reason: "x"},
      returnComment: null, returnedBy: null,
    });
    expect(await db.getItem("nao-existe")).toBeUndefined();
  });

  it("listChildren devolve só os filhos diretos", async () => {
    await firestore.doc("teaching_items/f").set(item("f", {type: "folder", status: "active"}));
    await firestore.doc("teaching_items/x").set(item("x", {parentId: "f"}));
    await firestore.doc("teaching_items/y").set(item("y", {parentId: "x"}));
    const db = createAdminLibraryDb(firestore);
    expect((await db.listChildren("f")).map((i) => i.id)).toEqual(["x"]);
  });

  it("updateItem ignora undefined e grava null e updatedAt", async () => {
    await firestore.doc("teaching_items/a").set(item("a", {deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: admin.firestore.Timestamp.now()}, deleteRequested: true}));
    const db = createAdminLibraryDb(firestore);
    await db.updateItem("a", {deleteRequest: null, deleteRequested: false, status: undefined});
    const data = (await firestore.doc("teaching_items/a").get()).data()!;
    expect(data.deleteRequest).toBeNull();
    expect(data.deleteRequested).toBe(false);
    expect(data.status).toBe("in_review");
    expect(data.updatedAt).toBeDefined();
  });

  it("transact lê antes e aplica as escritas no fim, com votos convertidos", async () => {
    await firestore.doc("teaching_items/a").set(item("a"));
    await firestore.doc("teaching_items/a/votes/v1").set({
      voterId: "c1", action: "approve", version: 1, createdAt: admin.firestore.Timestamp.fromMillis(10),
    });
    const db = createAdminLibraryDb(firestore);
    const seen = await db.transact(async (tx) => {
      const current = await tx.getItem("a");
      const votes = await tx.listVotes("a");
      tx.updateItem("a", {status: "published"});
      return {status: current?.status, votes};
    });
    expect(seen.status).toBe("in_review");
    expect(seen.votes).toEqual([{id: "v1", voterId: "c1", action: "approve", version: 1, requestId: undefined, comment: undefined, createdAt: 10}]);
    expect((await db.getItem("a"))?.status).toBe("published");
  });

  it("deleteItem apaga o documento e os votos", async () => {
    await firestore.doc("teaching_items/a").set(item("a"));
    await firestore.doc("teaching_items/a/votes/v1").set({voterId: "c1", action: "approve", version: 1, createdAt: admin.firestore.Timestamp.now()});
    await createAdminLibraryDb(firestore).deleteItem("a");
    expect((await firestore.doc("teaching_items/a").get()).exists).toBe(false);
    expect((await firestore.collection("teaching_items/a/votes").get()).size).toBe(0);
  });
});
```

Criar `functions/test-emulator/adapterNotifier.test.ts`:

```ts
import * as admin from "firebase-admin";
import {beforeAll, beforeEach, describe, expect, it} from "vitest";
import {
  createFirestoreAudit,
  createFirestoreNotifier,
} from "../src/teaching/library/adapterNotifier";

let firestore: admin.firestore.Firestore;

beforeAll(() => {
  if (admin.apps.length === 0) admin.initializeApp({projectId: "demo-ipe-rules"});
  firestore = admin.firestore();
});

beforeEach(async () => {
  await firestore.recursiveDelete(firestore.collection("teaching_notifications"));
  await firestore.recursiveDelete(firestore.collection("users"));
  await firestore.recursiveDelete(firestore.collection("teaching_log"));
});

const notification = {
  id: "published_i1_v1_t1", toUid: "t1", type: "published", itemId: "i1",
  title: "Material publicado", body: "\"Aula\" foi aprovado.",
};

function fakeMessaging() {
  const sent: admin.messaging.Message[] = [];
  return {sent, send: async (message: admin.messaging.Message) => {
    sent.push(message);
    return "id";
  }};
}

describe("createFirestoreNotifier", () => {
  it("grava a notificação e envia push com a URL do item", async () => {
    await firestore.doc("users/t1").set({fcmToken: "tok-1"});
    const messaging = fakeMessaging();
    await createFirestoreNotifier(firestore, messaging).notify(notification);
    const saved = (await firestore.doc("teaching_notifications/published_i1_v1_t1").get()).data()!;
    expect(saved).toMatchObject({toUid: "t1", type: "published", itemId: "i1", title: "Material publicado", readAt: null});
    expect(messaging.sent).toHaveLength(1);
    expect(messaging.sent[0]).toMatchObject({
      token: "tok-1",
      notification: {title: "Material publicado", body: "\"Aula\" foi aprovado."},
      data: {type: "teaching_review", itemId: "i1", url: "https://ipe-ensino.vercel.app/ensino/biblioteca?item=i1"},
    });
  });

  it("repetir o mesmo id não duplica documento nem push", async () => {
    await firestore.doc("users/t1").set({fcmToken: "tok-1"});
    const messaging = fakeMessaging();
    const notifier = createFirestoreNotifier(firestore, messaging);
    await notifier.notify(notification);
    await notifier.notify(notification);
    expect(messaging.sent).toHaveLength(1);
    expect((await firestore.collection("teaching_notifications").get()).size).toBe(1);
  });

  it("preferência desligada ou sem token: grava o documento e não envia push", async () => {
    await firestore.doc("users/t1").set({fcmToken: "tok-1", disabled_notifications: ["teaching_review"]});
    const messaging = fakeMessaging();
    await createFirestoreNotifier(firestore, messaging).notify(notification);
    await createFirestoreNotifier(firestore, messaging).notify({...notification, id: "x2", toUid: "sem-usuario"});
    expect(messaging.sent).toEqual([]);
    expect((await firestore.collection("teaching_notifications").get()).size).toBe(2);
  });

  it("erro no push não faz a notificação falhar", async () => {
    await firestore.doc("users/t1").set({fcmToken: "tok-1"});
    const notifier = createFirestoreNotifier(firestore, {send: async () => {
      throw new Error("token inválido");
    }});
    await expect(notifier.notify(notification)).resolves.toBeUndefined();
  });
});

describe("createFirestoreAudit", () => {
  it("grava a entrada com id determinístico e é idempotente", async () => {
    const audit = createFirestoreAudit(firestore);
    const entry = {id: "published_i1_v1", action: "published", itemId: "i1", itemName: "Aula", actors: ["c1", "c2"]};
    await audit.record(entry);
    await audit.record(entry);
    const snap = await firestore.collection("teaching_log").get();
    expect(snap.size).toBe(1);
    expect(snap.docs[0].data()).toMatchObject({action: "published", itemId: "i1", itemName: "Aula", actors: ["c1", "c2"]});
    expect(snap.docs[0].data().at).toBeDefined();
  });
});
```

- [ ] **Step 2: Rodar para ver falhar**

Run: `npm --prefix functions test` e `npm --prefix functions run test:emulator`
Expected: FAIL — os adaptadores não existem.

- [ ] **Step 3: Implementar os adaptadores**

Criar `functions/src/teaching/library/convert.ts`:

```ts
import type * as admin from "firebase-admin";
import type {ItemDoc, VoteAction, VoteDoc} from "./types";

type Snap = admin.firestore.DocumentSnapshot;

function millis(value: unknown): number {
  const maybe = value as {toMillis?: () => number} | null | undefined;
  if (maybe && typeof maybe.toMillis === "function") return maybe.toMillis();
  return typeof value === "number" ? value : 0;
}

export function toItem(snap: Snap): ItemDoc {
  const d = snap.data() ?? {};
  const raw = d.deleteRequest;
  const request = raw ?
    {
      id: String(raw.id),
      requestedBy: String(raw.requestedBy),
      requestedAt: millis(raw.requestedAt),
      reason: raw.reason as string | undefined,
    } :
    null;
  return {
    id: snap.id,
    type: d.type,
    name: d.name,
    parentId: d.parentId ?? null,
    authorId: d.authorId,
    status: d.status,
    version: d.version ?? 1,
    updatedBy: d.updatedBy,
    storagePath: d.storagePath,
    deleteRequest: request,
    returnComment: d.returnComment ?? null,
    returnedBy: d.returnedBy ?? null,
  };
}

export function toVote(snap: Snap): VoteDoc {
  const d = snap.data() ?? {};
  return {
    id: snap.id,
    voterId: d.voterId,
    action: d.action as VoteAction,
    version: d.version,
    requestId: d.requestId,
    comment: d.comment,
    createdAt: millis(d.createdAt),
  };
}
```

Criar `functions/src/teaching/library/adapterDb.ts`:

```ts
import * as admin from "firebase-admin";
import {ITEMS_COLLECTION, VOTES_SUBCOLLECTION} from "./constants";
import {toItem, toVote} from "./convert";
import type {ItemPatch, LibraryDb, Tx} from "./types";

type Firestore = admin.firestore.Firestore;

// Remove undefined (o Firestore rejeita) e converte o pedido de exclusão.
function toWrite(patch: ItemPatch): Record<string, unknown> {
  const data: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(patch)) {
    if (value === undefined) continue;
    if (key === "deleteRequest" && value !== null) {
      const req = value as {requestedAt: number};
      data[key] = {
        ...req,
        requestedAt: admin.firestore.Timestamp.fromMillis(req.requestedAt),
      };
    } else {
      data[key] = value;
    }
  }
  data.updatedAt = admin.firestore.FieldValue.serverTimestamp();
  return data;
}

export function createAdminLibraryDb(firestore: Firestore): LibraryDb {
  const ref = (id: string) => firestore.collection(ITEMS_COLLECTION).doc(id);

  return {
    async getItem(id) {
      const snap = await ref(id).get();
      return snap.exists ? toItem(snap) : undefined;
    },

    async listChildren(parentId) {
      const snap = await firestore
        .collection(ITEMS_COLLECTION)
        .where("parentId", "==", parentId)
        .get();
      return snap.docs.map((doc) => toItem(doc));
    },

    async updateItem(id, patch) {
      await ref(id).update(toWrite(patch));
    },

    async deleteItem(id) {
      await firestore.recursiveDelete(ref(id));
    },

    async transact(fn) {
      return firestore.runTransaction(async (t) => {
        const writes: Array<[string, ItemPatch]> = [];
        const tx: Tx = {
          async getItem(id) {
            const snap = await t.get(ref(id));
            return snap.exists ? toItem(snap) : undefined;
          },
          async listVotes(itemId) {
            const snap = await t.get(
              ref(itemId).collection(VOTES_SUBCOLLECTION)
            );
            return snap.docs.map((doc) => toVote(doc));
          },
          updateItem(id, patch) {
            writes.push([id, patch]);
          },
        };
        const result = await fn(tx);
        for (const [id, patch] of writes) t.update(ref(id), toWrite(patch));
        return result;
      });
    },
  };
}
```

Criar `functions/src/teaching/library/adapterStorage.ts`:

```ts
import type * as admin from "firebase-admin";
import {BATCH_SIZE, STORAGE_PREFIX} from "./constants";
import type {LibraryStorage} from "./types";
import {chunks} from "./util";

export type Bucket = ReturnType<admin.storage.Storage["bucket"]>;

export function createBucketStorage(bucket: Bucket): LibraryStorage {
  return {
    async deleteItemFiles(itemId, keepPath) {
      const [files] = await bucket.getFiles({
        prefix: `${STORAGE_PREFIX}/${itemId}/`,
      });
      const doomed = files.filter((file) => file.name !== keepPath);
      for (const part of chunks(doomed, BATCH_SIZE)) {
        await Promise.all(
          part.map((file) => file.delete({ignoreNotFound: true}))
        );
      }
    },
  };
}
```

Criar `functions/src/teaching/library/adapterRoles.ts`:

```ts
import type {RolesPort} from "./types";
import {chunks, unique} from "./util";

interface UserLike {
  uid: string;
  customClaims?: Record<string, unknown>;
}

export interface AuthLike {
  getUsers(ids: Array<{uid: string}>): Promise<{users: UserLike[]}>;
  listUsers(
    maxResults?: number,
    pageToken?: string
  ): Promise<{users: UserLike[]; pageToken?: string}>;
}

const isCurator = (user: UserLike) =>
  user.customClaims?.teaching_role === "curator";

// Papel lido do Auth (claims atuais), não do documento do usuário.
export function createAuthRoles(auth: AuthLike): RolesPort {
  return {
    async currentCuratorIds(uids) {
      const found = new Set<string>();
      for (const part of chunks(unique(uids), 100)) {
        const result = await auth.getUsers(part.map((uid) => ({uid})));
        for (const user of result.users) {
          if (isCurator(user)) found.add(user.uid);
        }
      }
      return found;
    },

    async allCuratorIds() {
      const ids: string[] = [];
      let token: string | undefined;
      do {
        const page = await auth.listUsers(1000, token);
        for (const user of page.users) {
          if (isCurator(user)) ids.push(user.uid);
        }
        token = page.pageToken;
      } while (token);
      return ids;
    },
  };
}
```

Criar `functions/src/teaching/library/adapterNotifier.ts`:

```ts
import * as admin from "firebase-admin";
import {
  AUDIT_COLLECTION,
  NOTIFICATION_PREFERENCE,
  NOTIFICATIONS_COLLECTION,
  PORTAL_URL,
} from "./constants";
import type {AuditLog, NotificationInput, Notifier} from "./types";

type Firestore = admin.firestore.Firestore;

export interface MessagingLike {
  send(message: admin.messaging.Message): Promise<string>;
}

const ALREADY_EXISTS = 6;

async function push(
  firestore: Firestore,
  messaging: MessagingLike,
  n: NotificationInput
): Promise<void> {
  try {
    const user = await firestore.collection("users").doc(n.toUid).get();
    const data = user.data();
    const token = data?.fcmToken;
    const disabled: string[] = data?.disabled_notifications ?? [];
    if (!token || disabled.includes(NOTIFICATION_PREFERENCE)) return;
    await messaging.send({
      token,
      notification: {title: n.title, body: n.body},
      data: {
        type: NOTIFICATION_PREFERENCE,
        itemId: n.itemId,
        url: `${PORTAL_URL}/ensino/biblioteca?item=${n.itemId}`,
      },
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default", badge: 1}}},
    });
  } catch (error) {
    console.error("Falha ao enviar push da biblioteca:", error);
  }
}

// Cria o documento só se ainda não existe; o push só sai na primeira criação.
export function createFirestoreNotifier(
  firestore: Firestore,
  messaging: MessagingLike
): Notifier {
  return {
    async notify(n) {
      const ref = firestore.collection(NOTIFICATIONS_COLLECTION).doc(n.id);
      try {
        await ref.create({
          toUid: n.toUid,
          type: n.type,
          itemId: n.itemId,
          title: n.title,
          body: n.body,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          readAt: null,
        });
      } catch (error) {
        if ((error as {code?: number}).code === ALREADY_EXISTS) return;
        throw error;
      }
      await push(firestore, messaging, n);
    },
  };
}

export function createFirestoreAudit(firestore: Firestore): AuditLog {
  return {
    async record(entry) {
      await firestore.collection(AUDIT_COLLECTION).doc(entry.id).set({
        action: entry.action,
        itemId: entry.itemId,
        itemName: entry.itemName,
        actors: entry.actors,
        at: admin.firestore.FieldValue.serverTimestamp(),
      });
    },
  };
}
```

- [ ] **Step 4: Rodar tudo**

Run (um por vez): `npm --prefix functions test`, `npm --prefix functions run test:emulator`, `npm --prefix functions run lint`, `npm --prefix functions run build`
Expected: testes unitários e de emulador PASS; lint e build limpos. Se o tipo `Bucket` ou a assinatura de `getUsers/listUsers` do `firebase-admin` 12 não casar com as interfaces (`AuthLike`), ajuste **as interfaces locais** para serem compatíveis estruturalmente (sem `any`) e relate.

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add functions/package.json functions/vitest.emulator.config.ts functions/src/teaching/library functions/test/library functions/test-emulator
/usr/bin/git commit -m "feat(functions): adaptadores reais da biblioteca (Firestore, Storage, Auth, notificações)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Gatilhos, composição e exportação

**Files:**
- Create: `functions/src/teaching/library/buildDeps.ts`, `functions/src/teaching/library/triggers.ts`
- Modify: `functions/src/index.ts` (acrescentar o `export` no fim)

**Interfaces:**
- Consumes: `processVote`, `processItemChange`, `processItemCreated`, `toItem`, os adaptadores e `DEFAULT_BUCKET`.
- Produces: Cloud Functions exportadas `onTeachingVoteCreated`, `onTeachingItemCreated`, `onTeachingItemUpdated` (todas com `runWith({failurePolicy: true})`); `buildDeps(): LibraryDeps` (dependências reais, criadas sob demanda).

- [ ] **Step 1: Implementar a composição e os gatilhos**

Criar `functions/src/teaching/library/buildDeps.ts`:

```ts
import * as admin from "firebase-admin";
import {createAdminLibraryDb} from "./adapterDb";
import {
  createFirestoreAudit,
  createFirestoreNotifier,
} from "./adapterNotifier";
import {createAuthRoles} from "./adapterRoles";
import {createBucketStorage} from "./adapterStorage";
import {DEFAULT_BUCKET} from "./constants";
import type {LibraryDeps} from "./types";

// Criado dentro do gatilho: o admin.initializeApp() do index.ts já rodou.
export function buildDeps(): LibraryDeps {
  const firestore = admin.firestore();
  return {
    db: createAdminLibraryDb(firestore),
    storage: createBucketStorage(admin.storage().bucket(DEFAULT_BUCKET)),
    roles: createAuthRoles(admin.auth()),
    notifier: createFirestoreNotifier(firestore, admin.messaging()),
    audit: createFirestoreAudit(firestore),
  };
}
```

Criar `functions/src/teaching/library/triggers.ts`:

```ts
import * as functions from "firebase-functions/v1";
import {buildDeps} from "./buildDeps";
import {toItem} from "./convert";
import {processItemChange, processItemCreated} from "./processItemChange";
import {processVote} from "./processVote";

// Retentativa ligada: as operações são idempotentes (ver processVote.ts).
const base = functions.runWith({failurePolicy: true});

export const onTeachingVoteCreated = base.firestore
  .document("teaching_items/{itemId}/votes/{voteId}")
  .onCreate(async (_snapshot, context) => {
    const {itemId, voteId} = context.params;
    await processVote(buildDeps(), itemId, voteId);
    return null;
  });

export const onTeachingItemCreated = base.firestore
  .document("teaching_items/{itemId}")
  .onCreate(async (snapshot) => {
    await processItemCreated(buildDeps(), toItem(snapshot));
    return null;
  });

export const onTeachingItemUpdated = base.firestore
  .document("teaching_items/{itemId}")
  .onUpdate(async (change) => {
    await processItemChange(
      buildDeps(),
      toItem(change.before),
      toItem(change.after)
    );
    return null;
  });
```

No fim de `functions/src/index.ts`, acrescentar:

```ts
export {
  onTeachingItemCreated,
  onTeachingItemUpdated,
  onTeachingVoteCreated,
} from "./teaching/library/triggers";
```

- [ ] **Step 2: Rodar a verificação completa**

Run (um por vez): `npm --prefix functions test`, `npm --prefix functions run test:emulator`, `npm --prefix functions run lint`, `npm --prefix functions run build`, `npm --prefix rules-tests test`
Expected: tudo PASS, lint e build limpos.

Verificar que os três gatilhos foram carregados no build: `node -e "const f=require('./functions/lib/index.js'); console.log(['onTeachingVoteCreated','onTeachingItemCreated','onTeachingItemUpdated'].map(n=>n+':'+typeof f[n]).join(' '))"` (o `firebase-admin` não é inicializado ao carregar; se o carregamento falhar por falta de `FIREBASE_CONFIG`, defina `FIREBASE_CONFIG='{}'` no comando). Esperado: `function` para os três.

- [ ] **Step 3: Documentar a limitação conhecida**

Acrescentar ao final do comentário de topo de `functions/src/teaching/library/triggers.ts` (3 linhas):

```ts
// Os gatilhos são finos de propósito: a lógica é testada em processVote.ts e
// processItemChange.ts com portas em memória, e os adaptadores no emulador.
// A fiação dos gatilhos só é exercitada em produção (verificação do Plano B).
```

- [ ] **Step 4: Commit**

```bash
/usr/bin/git add functions/src/index.ts functions/src/teaching/library
/usr/bin/git commit -m "feat(functions): gatilhos da biblioteca (voto, criação e atualização de itens)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Entrega em produção (fora das tarefas, com confirmação do usuário)

Estes passos alteram produção e **só rodam com a autorização do usuário**, depois de todas as tarefas aprovadas:

1. `firebase deploy --only firestore:rules --project app-ipe` — só **acrescenta** regras de coleções novas (conferir com `/usr/bin/git diff master -- firestore.rules` que só há linhas adicionadas).
2. `firebase deploy --only storage --project app-ipe` — substitui as regras de `teaching/materials` (ainda não há uso real da biblioteca).
3. `firebase deploy --only functions:onTeachingVoteCreated,functions:onTeachingItemCreated,functions:onTeachingItemUpdated --force --project app-ipe` (o `--force` só confirma a política de retentativa; nenhuma outra função é tocada).
4. A verificação de ponta a ponta (3 curadores reais, envio, 2 aprovações, devolução, exclusão com 2 curadores) acontece no **Plano B**, com as telas.

## Self-Review (feita ao final da escrita)

**Cobertura da spec**
- Seção 2 (regras do produto): votos e contagens (decide, Tasks 3 e 4), pasta vazia direta (Task 5), admin sem papel não vota (regras Task 2; `RolesPort` Task 3/6), exclusão só por Function (regras Tasks 1 e 2; Tasks 4 e 5).
- Seção 4 (modelo): campos e coleções nas regras (Task 2) e nos tipos (Task 3); `updatedBy` adicionado (decisão 2).
- Seção 5 (máquina de estados): `decide*`, `processVote`, `processItemChange`, transações, releitura do papel no Auth, ordem segura de remoção, validações de movimento (Tasks 3 a 5).
- Seção 6 (segurança): regras do Firestore (Task 2) e do Storage (Task 1); risco aceito já registrado na spec.
- Seção 8 (notificações): mensagens (Task 3), ids determinísticos e push (Tasks 4 a 6).
- Seções 7 e 9 (telas e app): fora deste plano (Plano B).
- Seção 10 (casos de borda): voto de curador rebaixado, retentativa, órfãos (limpeza futura, fora de escopo) cobertos onde cabe.
- Índices da seção 4/7: substituídos por decisão (1).

**Placeholders:** nenhum "TBD/TODO"; todos os passos têm código ou comando. As exceções permitidas são instruções de ajuste mínimo quando o emulador discordar de uma expressão de regra (Task 2) e de tipos do SDK (Task 6), sempre com relato.

**Consistência de tipos:** `ItemDoc`, `VoteDoc`, `ItemPatch`, `Tx`, `LibraryDb`, `LibraryStorage` (`deleteItemFiles(itemId, keepPath?)`), `RolesPort`, `Notifier`, `AuditLog`, `LibraryDeps` definidos na Task 3 e usados com as mesmas assinaturas nas Tasks 4 a 7; `decideDeletion`/`decidePublication` incluem `by` e usam o mesmo formato nos testes e em `processVote`; ids de notificação coincidem entre testes (`published_i1_v1_author`, `deleted_d1_r1_c1`, `review_requested_i1_v2_c1`, `delete_requested_d1_r1_c2`).

**Review Focus:** itens 1 e 6 nos testes de regras (Tasks 1 e 2); 2 e 3 em `processVote.test.ts` (curador rebaixado, reprocesso, versão e `requestId` antigos); 4 em `processVote.test.ts` (falha do Storage e cascata) e `processItemChange.test.ts` (falha no reenvio); 5 em `processItemChange.test.ts` (ciclo, pai inválido, profundidade).
