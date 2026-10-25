# Biblioteca e Curadoria — Plano B (telas do portal e ajuste do app) — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar no portal Next.js a biblioteca estilo Drive com o fluxo de curadoria (enviar, revisar, devolver, rejeitar, pedir e aprovar exclusão), fila de revisão e caixa de notificações, mais o ajuste do app Flutter para abrir o portal ao tocar numa notificação de curadoria.

**Architecture:** Camada de dados tipada em `src/modules/teaching/library/` falando direto com o Firestore/Storage (as regras e as Cloud Functions do Plano A, já em produção, impõem as permissões). Lógica pura (árvore, permissões de ação, validação, formato dos documentos) separada do Firebase e testada sem o SDK; a UI usa essa lógica e repositórios simulados nos testes. A rota usa parâmetros de busca (`?pasta=` e `?item=`) para uma única página estática.

**Tech Stack:** Next.js 16 (App Router, client components), React 19, Tailwind v4 com os tokens do app, Firebase JS SDK 13 (Firestore, Storage), Vitest + Testing Library; Flutter (`url_launcher`) para o ajuste do app.

**Spec:** `docs/superpowers/specs/2026-10-15-teaching-library-curation-design.md` (seções 5 a 9 e 14). **Plano A (base, já publicado):** `docs/superpowers/plans/2026-10-15-teaching-library-backend.md`.

**Nota de ambiente:** nesta máquina o hook do `rtk` bloqueia `git` simples e construções de shell complexas dentro da worktree. Use `/usr/bin/git`, um comando simples por vez, com caminhos literais; use `npm --prefix web-portal ...`. A worktree já tem `web-portal/node_modules` apenas se alguém rodou `npm --prefix web-portal install` (rode se faltar). `web-portal/.env.local` (git-ignorado) deve existir com os valores públicos do Firebase para o `build`; se não existir, crie com os valores de `web-portal/.env.example` e dados fictícios. Todos os caminhos são relativos à raiz da worktree (`.claude/worktrees/teaching-library`).

## Global Constraints

- Identidade visual do app via tokens (`bg-background`, `bg-surface`, `bg-surface-elevated`, `bg-primary`, `text-on-surface`, `rounded-card/button/input/glass/dialog`, `text-error`); utilitários de branco com alpha (`text-white/70`, `border-white/5`) são aceitos. Nenhuma cor ou raio fixo novo.
- Todo texto de interface em pt-BR.
- O cliente **nunca** escreve `status` (exceto o reenvio `returned → in_review`), `deleting`, `returnComment`, `returnedBy`, nem apaga documentos ou arquivos; toda exclusão acontece por Cloud Function depois dos votos.
- Todo `create`/`update` de item grava `updatedBy == uid` e `updatedAt == serverTimestamp()`; criação grava `authorId == uid`, `version: 1`, `createdAt` e `updatedAt` com `serverTimestamp()`.
- Documento/link novo: `status: "in_review"`; pasta nova (só curador): `status: "active"`. Arquivo: `storagePath` em `teaching/materials/{itemId}/...` (convenção `v{versão}-{nome}`), `fileName` de 1 a 200 caracteres sem `/`, `size` inteiro de 1 a 104857600, tipos PDF, Office (doc/docx/ppt/pptx/xls/xlsx e OpenDocument) e imagens. Link: `url` `http` ou `https` com até 2000 caracteres. Nome do item: 1 a 120 caracteres.
- Pedido de exclusão: `deleteRequest.id` é um **uuid** (`crypto.randomUUID()`), `requestedBy == uid`, `requestedAt == serverTimestamp()`, `deleteRequested: true`; só em item `published` ou pasta `active`.
- Votos (subcoleção `votes`): `voterId == uid`, `createdAt == serverTimestamp()`; publicação: `approve | reject | return` com `version` igual à do item (comentário obrigatório em `reject` e `return`); exclusão: `delete_approve | delete_refuse` com `requestId` igual ao do pedido (comentário obrigatório em `delete_refuse`).
- Consultas do professor (regras exigem filtro): por pasta, 3 consultas de igualdade juntadas no cliente: `parentId == X` com `status == "published"`, com `status == "active"` e com `authorId == uid`. Curador e admin: `parentId == X`. Sem índices compostos: ordenação no cliente. Notificações: `where toUid == uid`, ordenar e limitar no cliente.
- Só quem tem `teaching_role == curator` vota ou gerencia pastas (admin sem esse papel só lê; pode enviar documentos/links como qualquer participante); a interface esconde o que o papel não pode, mas as regras são a barreira real.
- O link de notificação é `?item={id}` (abre o detalhe do item) e `?pasta={id}` abre uma pasta.
- Node 22; sem novas dependências npm.

## Review Focus

1. **A interface oferece ação que as regras negam** (ex.: curador autor votando no próprio envio, admin sem papel votando, ação em item com `deleting`): o botão não aparece e o teste prova. (Tasks 1 e 5)
2. **Documento escrito no formato errado** (campo extra, `deleteRequest.id` repetido, `storagePath` fora do prefixo, `fileName` com `/`): os construtores de payload são testados contra o contrato das regras. (Task 3)
3. **Upload que falha no meio** (arquivo enviado mas documento não criado, ou o contrário): a ordem é arquivo primeiro, documento depois; falha do documento avisa e não deixa item fantasma; falha do arquivo não cria documento. (Task 3)
4. **Estados vazios e erros:** pasta vazia, pasta inexistente (`?pasta=` inválido), item inexistente (`?item=`), sem permissão de leitura, lista de curadores insuficiente (menos de 3). Nunca tela em branco. (Tasks 4, 6 e 7)
5. **Concorrência de tela:** votar duas vezes seguidas, trocar de pasta com uma consulta em andamento (resposta velha não sobrescreve a nova), desmontar a tela durante o envio. (Tasks 4, 5 e 6)

---

## File Structure

```
web-portal/src/modules/teaching/
  module.ts                               (modificar: novos itens de menu)
  pages/TeachingHomePage.tsx              (modificar: cartão da biblioteca com link)
  library/
    types.ts            tipos de item, voto, espectador
    text.ts             normalização e comparação de nomes (pt-BR)
    tree.ts             ordenação, migalhas, busca, mapa por id
    permissions.ts      o que cada papel pode fazer em cada item
    status.ts           selo de estado e contagem de aprovações
    files.ts            validação de arquivo, nome e URL; caminho no Storage
    payloads.ts         construtores dos documentos exatamente como as regras exigem
    convert.ts          Firestore -> LibraryItem / LibraryVote / Notificação
    repository.ts       leitura (consultas, escuta em tempo real)
    mutations.ts        escrita (criar, renomear, mover, votar, enviar arquivo)
    notifications.ts    leitura e marcação de notificações
    useLibrary.ts       hooks de dados da tela (pasta atual, busca, item)
    ui/
      LibraryPage.tsx  FolderView.tsx  ItemRow.tsx  Breadcrumbs.tsx
      StatusBadge.tsx  Dialogs.tsx  UploadPanel.tsx  ItemDetail.tsx
      ReviewQueuePage.tsx  NotificationsPage.tsx  NotificationBell.tsx
web-portal/src/app/(portal)/ensino/
  biblioteca/page.tsx   revisao/page.tsx   notificacoes/page.tsx
lib/src/modules/notifications/services/notification_service.dart   (modificar)
lib/src/modules/notifications/services/teaching_notification_url.dart (criar)
test/modules/notifications/teaching_notification_url_test.dart       (criar)
```

---

### Task 1: Lógica pura da biblioteca (tipos, árvore, permissões, selos, validação)

**Files:**
- Create: `web-portal/src/modules/teaching/library/types.ts`, `text.ts`, `tree.ts`, `permissions.ts`, `status.ts`, `files.ts`
- Test: `web-portal/src/modules/teaching/library/tree.test.ts`, `permissions.test.ts`, `status.test.ts`, `files.test.ts`

**Interfaces:**
- Consumes: `AccessClaims` de `@/core/auth/access` (`{admin: boolean; teachingRole: "teacher" | "curator" | null}`).
- Produces (usados nas Tasks 2 a 7):
  - Tipos `ItemType`, `ItemStatus`, `VoteAction`, `DeleteRequest`, `LibraryItem`, `LibraryVote`, `Viewer`; `viewerFrom(uid: string, claims: AccessClaims): Viewer`.
  - `normalizeText(text: string): string`, `compareNames(a: string, b: string): number`.
  - `sortItems(items: LibraryItem[]): LibraryItem[]` (pastas primeiro, depois nome); `indexById(items: LibraryItem[]): Map<string, LibraryItem>`; `buildBreadcrumbs(byId: Map<string, LibraryItem>, folderId: string | null): LibraryItem[]` (da raiz até a pasta; interrompe em pai ausente); `filterByName(items: LibraryItem[], term: string): LibraryItem[]`.
  - `itemPermissions(item: LibraryItem, viewer: Viewer): ItemPermissions` e `libraryPermissions(viewer: Viewer): {canCreateFolder: boolean; canUpload: boolean; canAddLink: boolean}`.
  - `countApprovals(item: LibraryItem, votes: LibraryVote[]): number`, `countDeleteApprovals(item: LibraryItem, votes: LibraryVote[]): number`, `statusBadge(item: LibraryItem, approvals: number): {label: string; tone: BadgeTone}` com `type BadgeTone = "neutral" | "info" | "warning" | "success" | "danger"`.
  - Constantes e funções de `files.ts`: `MAX_FILE_BYTES`, `REQUIRED_APPROVALS = 2`, `validateName(name: string): string | null`, `validateUrl(url: string): string | null`, `validateFile(file: {name: string; size: number; type: string}): string | null`, `contentTypeFor(file: {name: string; type: string}): string`, `storagePathFor(itemId: string, version: number, fileName: string): string`, `safeFileName(name: string): string`.

- [ ] **Step 1: Escrever os testes (que vão falhar)**

Criar `web-portal/src/modules/teaching/library/tree.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {buildBreadcrumbs, filterByName, indexById, sortItems} from "./tree";
import type {LibraryItem} from "./types";

const item = (id: string, name: string, type: LibraryItem["type"] = "file", parentId: string | null = null): LibraryItem => ({
  id, name, type, parentId, authorId: "a", status: type === "folder" ? "active" : "published", version: 1,
});

describe("sortItems", () => {
  it("pastas primeiro, depois por nome sem diferenciar acento e maiúscula, com números naturais", () => {
    const result = sortItems([
      item("1", "Zeca"), item("2", "ábaco"), item("3", "Aula 10"), item("4", "Aula 2"),
      item("5", "Pasta B", "folder"), item("6", "pasta a", "folder"),
    ]);
    expect(result.map((i) => i.name)).toEqual(["pasta a", "Pasta B", "ábaco", "Aula 2", "Aula 10", "Zeca"]);
  });

  it("não altera a lista original", () => {
    const list = [item("1", "B"), item("2", "A")];
    sortItems(list);
    expect(list.map((i) => i.name)).toEqual(["B", "A"]);
  });
});

describe("buildBreadcrumbs", () => {
  const byId = indexById([
    item("f1", "Crianças", "folder"),
    item("f2", "Antigo Testamento", "folder", "f1"),
    item("f3", "Gênesis", "folder", "f2"),
  ]);

  it("raiz não tem migalhas", () => {
    expect(buildBreadcrumbs(byId, null)).toEqual([]);
  });

  it("da raiz até a pasta", () => {
    expect(buildBreadcrumbs(byId, "f3").map((i) => i.name)).toEqual(["Crianças", "Antigo Testamento", "Gênesis"]);
  });

  it("para quando um pai não está disponível (sem laço infinito)", () => {
    expect(buildBreadcrumbs(byId, "inexistente")).toEqual([]);
    const cyclic = indexById([item("a", "A", "folder", "b"), item("b", "B", "folder", "a")]);
    expect(buildBreadcrumbs(cyclic, "a").length).toBeLessThanOrEqual(2);
  });
});

describe("filterByName", () => {
  const list = [item("1", "Catecismo Menor"), item("2", "Confissão de Fé"), item("3", "Jesus e as crianças")];

  it("sem termo devolve tudo", () => {
    expect(filterByName(list, "  ")).toHaveLength(3);
  });

  it("ignora acento e maiúscula e aceita parte do nome", () => {
    expect(filterByName(list, "CONFISSAO").map((i) => i.id)).toEqual(["2"]);
    expect(filterByName(list, "criancas").map((i) => i.id)).toEqual(["3"]);
    expect(filterByName(list, "zzz")).toEqual([]);
  });
});
```

Criar `web-portal/src/modules/teaching/library/permissions.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {itemPermissions, libraryPermissions} from "./permissions";
import type {LibraryItem, Viewer} from "./types";

const teacher: Viewer = {uid: "t1", isCurator: false, isAdmin: false};
const other: Viewer = {uid: "t2", isCurator: false, isAdmin: false};
const curator: Viewer = {uid: "c1", isCurator: true, isAdmin: false};
const curator2: Viewer = {uid: "c2", isCurator: true, isAdmin: false};
const adminOnly: Viewer = {uid: "a1", isCurator: false, isAdmin: true};

const base: LibraryItem = {id: "i1", type: "file", name: "Aula", parentId: null, authorId: "t1", status: "in_review", version: 1};
const make = (extra: Partial<LibraryItem>): LibraryItem => ({...base, ...extra});

describe("libraryPermissions", () => {
  it("só curador cria pasta; todos enviam arquivo e link", () => {
    expect(libraryPermissions(curator)).toEqual({canCreateFolder: true, canUpload: true, canAddLink: true});
    expect(libraryPermissions(teacher)).toEqual({canCreateFolder: false, canUpload: true, canAddLink: true});
    expect(libraryPermissions(adminOnly).canCreateFolder).toBe(false);
  });
});

describe("itemPermissions — votar na publicação", () => {
  it("curador que não é o autor vota em item em revisão", () => {
    const p = itemPermissions(make({}), curator2);
    expect(p.canVote).toBe(true);
  });

  it("autor curador, professor, admin sem papel e item fora de revisão não votam", () => {
    expect(itemPermissions(make({authorId: "c1"}), curator).canVote).toBe(false);
    expect(itemPermissions(make({}), teacher).canVote).toBe(false);
    expect(itemPermissions(make({}), adminOnly).canVote).toBe(false);
    expect(itemPermissions(make({status: "published"}), curator2).canVote).toBe(false);
    expect(itemPermissions(make({status: "returned"}), curator2).canVote).toBe(false);
  });

  it("nada é permitido enquanto o item está sendo apagado (deleting)", () => {
    const p = itemPermissions(make({deleting: "reject"}), curator2);
    expect(p).toMatchObject({canVote: false, canRename: false, canMove: false, canRequestDelete: false, canVoteDelete: false, canResubmit: false});
  });
});

describe("itemPermissions — organizar e excluir", () => {
  it("só curador renomeia e move", () => {
    expect(itemPermissions(make({status: "published"}), curator)).toMatchObject({canRename: true, canMove: true});
    expect(itemPermissions(make({status: "published"}), teacher)).toMatchObject({canRename: false, canMove: false});
    expect(itemPermissions(make({status: "published"}), adminOnly)).toMatchObject({canRename: false, canMove: false});
  });

  it("curador pede exclusão de item publicado ou pasta ativa, uma vez só", () => {
    expect(itemPermissions(make({status: "published"}), curator).canRequestDelete).toBe(true);
    expect(itemPermissions(make({type: "folder", status: "active"}), curator).canRequestDelete).toBe(true);
    expect(itemPermissions(make({status: "in_review"}), curator).canRequestDelete).toBe(false);
    expect(itemPermissions(make({status: "returned"}), curator).canRequestDelete).toBe(false);
    expect(itemPermissions(make({status: "published", deleteRequest: {id: "r", requestedBy: "c1", requestedAt: 1}}), curator).canRequestDelete).toBe(false);
    expect(itemPermissions(make({status: "published"}), teacher).canRequestDelete).toBe(false);
  });

  it("votos de exclusão: outro curador vota; quem pediu cancela", () => {
    const req = {id: "r", requestedBy: "c1", requestedAt: 1};
    const item = make({status: "published", deleteRequest: req});
    expect(itemPermissions(item, curator2)).toMatchObject({canVoteDelete: true, canCancelDelete: false});
    expect(itemPermissions(item, curator)).toMatchObject({canVoteDelete: false, canCancelDelete: true});
    expect(itemPermissions(item, teacher)).toMatchObject({canVoteDelete: false, canCancelDelete: false});
    expect(itemPermissions(item, adminOnly)).toMatchObject({canVoteDelete: false, canCancelDelete: false});
  });
});

describe("itemPermissions — reenviar", () => {
  it("só o autor reenvia item devolvido", () => {
    expect(itemPermissions(make({status: "returned"}), teacher).canResubmit).toBe(true);
    expect(itemPermissions(make({status: "returned"}), other).canResubmit).toBe(false);
    expect(itemPermissions(make({status: "in_review"}), teacher).canResubmit).toBe(false);
  });
});
```

Criar `web-portal/src/modules/teaching/library/status.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {countApprovals, countDeleteApprovals, statusBadge} from "./status";
import type {LibraryItem, LibraryVote} from "./types";

const item = (extra: Partial<LibraryItem> = {}): LibraryItem => ({
  id: "i1", type: "file", name: "Aula", parentId: null, authorId: "t1", status: "in_review", version: 1, ...extra,
});
const vote = (id: string, voterId: string, action: LibraryVote["action"], extra: Partial<LibraryVote> = {}): LibraryVote => ({
  id, voterId, action, createdAt: 1, version: 1, ...extra,
});

describe("countApprovals", () => {
  it("conta curadores distintos que aprovaram a versão atual (último voto de cada um)", () => {
    const votes = [
      vote("a", "c1", "approve", {createdAt: 1}),
      vote("b", "c2", "approve", {createdAt: 1}),
      vote("c", "c2", "return", {createdAt: 2, comment: "x"}),
      vote("d", "c3", "approve", {version: 0}),
      vote("e", "t1", "approve"),
    ];
    expect(countApprovals(item(), votes)).toBe(1);
  });
});

describe("countDeleteApprovals", () => {
  it("conta aprovações do pedido atual, sem a de quem pediu", () => {
    const withRequest = item({status: "published", deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: 1}});
    const votes = [
      vote("a", "c2", "delete_approve", {requestId: "r1", version: undefined}),
      vote("b", "c1", "delete_approve", {requestId: "r1", version: undefined}),
      vote("c", "c3", "delete_approve", {requestId: "velho", version: undefined}),
    ];
    expect(countDeleteApprovals(withRequest, votes)).toBe(1);
    expect(countDeleteApprovals(item(), votes)).toBe(0);
  });
});

describe("statusBadge", () => {
  it("em revisão mostra o andamento das aprovações", () => {
    expect(statusBadge(item(), 1)).toEqual({label: "Em revisão 1/2", tone: "info"});
  });

  it("publicado, devolvido e pasta", () => {
    expect(statusBadge(item({status: "published"}), 0)).toEqual({label: "Publicado", tone: "success"});
    expect(statusBadge(item({status: "returned"}), 0)).toEqual({label: "Devolvido", tone: "warning"});
    expect(statusBadge(item({type: "folder", status: "active"}), 0)).toEqual({label: "", tone: "neutral"});
  });

  it("pedido de exclusão e exclusão em andamento têm prioridade", () => {
    const req = {id: "r", requestedBy: "c1", requestedAt: 1};
    expect(statusBadge(item({status: "published", deleteRequest: req}), 0)).toEqual({label: "Exclusão solicitada", tone: "danger"});
    expect(statusBadge(item({status: "published", deleting: "execute"}), 0)).toEqual({label: "Excluindo…", tone: "danger"});
    expect(statusBadge(item({deleting: "reject"}), 0)).toEqual({label: "Excluindo…", tone: "danger"});
  });
});
```

Criar `web-portal/src/modules/teaching/library/files.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {
  MAX_FILE_BYTES,
  contentTypeFor,
  safeFileName,
  storagePathFor,
  validateFile,
  validateName,
  validateUrl,
} from "./files";

describe("validateName", () => {
  it("aceita de 1 a 120 caracteres e recusa vazio ou só espaços", () => {
    expect(validateName("Aula 1")).toBeNull();
    expect(validateName("a".repeat(120))).toBeNull();
    expect(validateName("")).toBe("Informe um nome.");
    expect(validateName("   ")).toBe("Informe um nome.");
    expect(validateName("a".repeat(121))).toBe("O nome pode ter no máximo 120 caracteres.");
  });
});

describe("validateUrl", () => {
  it("aceita http e https; recusa outros esquemas, vazio e URL muito longa", () => {
    expect(validateUrl("https://exemplo.org/livro")).toBeNull();
    expect(validateUrl("http://exemplo.org")).toBeNull();
    expect(validateUrl("javascript:alert(1)")).toBe("Use um endereço que comece com http:// ou https://.");
    expect(validateUrl("ftp://x.org")).toBe("Use um endereço que comece com http:// ou https://.");
    expect(validateUrl("")).toBe("Informe o endereço do link.");
    expect(validateUrl(`https://x.org/${"a".repeat(2000)}`)).toBe("O endereço é muito longo.");
  });
});

describe("contentTypeFor e validateFile", () => {
  it("usa o tipo do navegador quando existe e a extensão quando vem vazio", () => {
    expect(contentTypeFor({name: "a.pdf", type: "application/pdf"})).toBe("application/pdf");
    expect(contentTypeFor({name: "a.DOCX", type: ""})).toBe("application/vnd.openxmlformats-officedocument.wordprocessingml.document");
    expect(contentTypeFor({name: "a.pptx", type: ""})).toBe("application/vnd.openxmlformats-officedocument.presentationml.presentation");
    expect(contentTypeFor({name: "a.odt", type: ""})).toBe("application/vnd.oasis.opendocument.text");
    expect(contentTypeFor({name: "a.xyz", type: ""})).toBe("");
  });

  it("recusa arquivo vazio, grande demais ou de tipo não permitido", () => {
    expect(validateFile({name: "a.pdf", size: 10, type: "application/pdf"})).toBeNull();
    expect(validateFile({name: "a.png", size: 10, type: "image/png"})).toBeNull();
    expect(validateFile({name: "a.pdf", size: 0, type: "application/pdf"})).toBe("O arquivo está vazio.");
    expect(validateFile({name: "a.pdf", size: MAX_FILE_BYTES + 1, type: "application/pdf"})).toBe("O arquivo passa de 100 MB.");
    expect(validateFile({name: "a.exe", size: 10, type: "application/x-msdownload"})).toBe("Tipo de arquivo não permitido. Use PDF, Office ou imagem.");
    expect(validateFile({name: "a".repeat(201) + ".pdf", size: 10, type: "application/pdf"})).toBe("O nome do arquivo é muito longo.");
  });
});

describe("safeFileName e storagePathFor", () => {
  it("remove barras e mantém o resto", () => {
    expect(safeFileName("a/b\\c.pdf")).toBe("a_b_c.pdf");
    expect(safeFileName("  aula 1.pdf ")).toBe("aula 1.pdf");
  });

  it("monta o caminho no formato que as regras exigem", () => {
    expect(storagePathFor("abc123", 1, "aula 1.pdf")).toBe("teaching/materials/abc123/v1-aula 1.pdf");
    expect(storagePathFor("abc123", 3, "a/b.pdf")).toBe("teaching/materials/abc123/v3-a_b.pdf");
  });
});
```

- [ ] **Step 2: Rodar para ver falhar**

Run: `npm --prefix web-portal test -- library`
Expected: FAIL — módulos `./tree`, `./permissions`, `./status`, `./files` e `./types` não existem.

- [ ] **Step 3: Implementar**

Criar `web-portal/src/modules/teaching/library/types.ts`:

```ts
import type {AccessClaims} from "@/core/auth/access";

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

// Visão de teaching_items/{id}; tempos em milissegundos.
export interface LibraryItem {
  id: string;
  type: ItemType;
  name: string;
  parentId: string | null;
  authorId: string;
  status: ItemStatus;
  version: number;
  updatedBy?: string;
  fileName?: string;
  contentType?: string;
  size?: number;
  storagePath?: string;
  url?: string;
  description?: string;
  returnComment?: string | null;
  returnedBy?: string | null;
  deleteRequest?: DeleteRequest | null;
  deleting?: "reject" | "execute" | null;
  createdAt?: number;
}

// Visão de teaching_items/{id}/votes/{voteId}.
export interface LibraryVote {
  id: string;
  voterId: string;
  action: VoteAction;
  version?: number;
  requestId?: string;
  comment?: string;
  createdAt: number;
}

export interface Viewer {
  uid: string;
  isCurator: boolean;
  isAdmin: boolean;
}

export function viewerFrom(uid: string, claims: AccessClaims): Viewer {
  return {uid, isCurator: claims.teachingRole === "curator", isAdmin: claims.admin};
}
```

Criar `web-portal/src/modules/teaching/library/text.ts`:

```ts
export function normalizeText(text: string): string {
  return text.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase();
}

// Ordem natural em pt-BR: sem diferenciar acento/maiúscula; "Aula 2" < "Aula 10".
export function compareNames(a: string, b: string): number {
  return a.localeCompare(b, "pt-BR", {sensitivity: "base", numeric: true});
}
```

Criar `web-portal/src/modules/teaching/library/tree.ts`:

```ts
import {compareNames, normalizeText} from "./text";
import type {LibraryItem} from "./types";

export function sortItems(items: LibraryItem[]): LibraryItem[] {
  return [...items].sort((a, b) => {
    const folderA = a.type === "folder" ? 0 : 1;
    const folderB = b.type === "folder" ? 0 : 1;
    return folderA - folderB || compareNames(a.name, b.name);
  });
}

export function indexById(items: LibraryItem[]): Map<string, LibraryItem> {
  return new Map(items.map((item) => [item.id, item]));
}

// Da raiz até a pasta. Para se um pai não está disponível ou há ciclo.
export function buildBreadcrumbs(
  byId: Map<string, LibraryItem>,
  folderId: string | null
): LibraryItem[] {
  const trail: LibraryItem[] = [];
  const seen = new Set<string>();
  let current = folderId;
  while (current !== null) {
    if (seen.has(current)) break;
    seen.add(current);
    const folder = byId.get(current);
    if (!folder) return [];
    trail.unshift(folder);
    current = folder.parentId;
  }
  return trail;
}

export function filterByName(items: LibraryItem[], term: string): LibraryItem[] {
  const needle = normalizeText(term.trim());
  if (!needle) return items;
  return items.filter((item) => normalizeText(item.name).includes(needle));
}
```

Criar `web-portal/src/modules/teaching/library/permissions.ts`:

```ts
import type {LibraryItem, Viewer} from "./types";

export interface ItemPermissions {
  canVote: boolean;
  canRename: boolean;
  canMove: boolean;
  canRequestDelete: boolean;
  canCancelDelete: boolean;
  canVoteDelete: boolean;
  canResubmit: boolean;
}

export function libraryPermissions(viewer: Viewer) {
  return {
    canCreateFolder: viewer.isCurator,
    canUpload: true,
    canAddLink: true,
  };
}

// Espelha as regras do Firestore; as regras continuam sendo a barreira real.
export function itemPermissions(item: LibraryItem, viewer: Viewer): ItemPermissions {
  const none: ItemPermissions = {
    canVote: false,
    canRename: false,
    canMove: false,
    canRequestDelete: false,
    canCancelDelete: false,
    canVoteDelete: false,
    canResubmit: false,
  };
  if (item.deleting) return none;

  const request = item.deleteRequest ?? null;
  const decided = item.type !== "folder";
  return {
    canVote:
      viewer.isCurator &&
      decided &&
      item.status === "in_review" &&
      item.authorId !== viewer.uid,
    canRename: viewer.isCurator,
    canMove: viewer.isCurator,
    canRequestDelete:
      viewer.isCurator &&
      request === null &&
      (item.status === "published" || item.status === "active"),
    canCancelDelete: viewer.isCurator && request?.requestedBy === viewer.uid,
    canVoteDelete:
      viewer.isCurator && request !== null && request.requestedBy !== viewer.uid,
    canResubmit:
      decided && item.status === "returned" && item.authorId === viewer.uid,
  };
}
```

Criar `web-portal/src/modules/teaching/library/status.ts`:

```ts
import {REQUIRED_APPROVALS} from "./files";
import type {LibraryItem, LibraryVote} from "./types";

export type BadgeTone = "neutral" | "info" | "warning" | "success" | "danger";

// Último voto de cada votante (por createdAt e, no empate, id).
function latestPerVoter(votes: LibraryVote[]): LibraryVote[] {
  const sorted = [...votes].sort(
    (a, b) => a.createdAt - b.createdAt || a.id.localeCompare(b.id)
  );
  const byVoter = new Map<string, LibraryVote>();
  for (const vote of sorted) byVoter.set(vote.voterId, vote);
  return [...byVoter.values()];
}

// Aprovações da versão atual, sem o autor. O papel de cada votante não é
// conhecido aqui; a Function confere no Auth ao decidir (a contagem é um
// indicador de andamento).
export function countApprovals(item: LibraryItem, votes: LibraryVote[]): number {
  const eligible = votes.filter(
    (v) =>
      (v.action === "approve" || v.action === "reject" || v.action === "return") &&
      v.version === item.version &&
      v.voterId !== item.authorId
  );
  return latestPerVoter(eligible).filter((v) => v.action === "approve").length;
}

export function countDeleteApprovals(
  item: LibraryItem,
  votes: LibraryVote[]
): number {
  const request = item.deleteRequest;
  if (!request) return 0;
  const eligible = votes.filter(
    (v) =>
      (v.action === "delete_approve" || v.action === "delete_refuse") &&
      v.requestId === request.id &&
      v.voterId !== request.requestedBy
  );
  return latestPerVoter(eligible).filter((v) => v.action === "delete_approve")
    .length;
}

export function statusBadge(
  item: LibraryItem,
  approvals: number
): {label: string; tone: BadgeTone} {
  if (item.deleting) return {label: "Excluindo…", tone: "danger"};
  if (item.deleteRequest) return {label: "Exclusão solicitada", tone: "danger"};
  if (item.type === "folder") return {label: "", tone: "neutral"};
  if (item.status === "published") return {label: "Publicado", tone: "success"};
  if (item.status === "returned") return {label: "Devolvido", tone: "warning"};
  return {
    label: `Em revisão ${Math.min(approvals, REQUIRED_APPROVALS)}/${REQUIRED_APPROVALS}`,
    tone: "info",
  };
}
```

Criar `web-portal/src/modules/teaching/library/files.ts`:

```ts
export const MAX_FILE_BYTES = 100 * 1024 * 1024;
export const REQUIRED_APPROVALS = 2;

const EXTENSION_TYPES: Record<string, string> = {
  pdf: "application/pdf",
  doc: "application/msword",
  docx: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  ppt: "application/vnd.ms-powerpoint",
  pptx: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  xls: "application/vnd.ms-excel",
  xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  odt: "application/vnd.oasis.opendocument.text",
  odp: "application/vnd.oasis.opendocument.presentation",
  ods: "application/vnd.oasis.opendocument.spreadsheet",
};

const ALLOWED_TYPES = new Set(Object.values(EXTENSION_TYPES));

export function validateName(name: string): string | null {
  const trimmed = name.trim();
  if (trimmed.length === 0) return "Informe um nome.";
  if (trimmed.length > 120) return "O nome pode ter no máximo 120 caracteres.";
  return null;
}

export function validateUrl(url: string): string | null {
  const trimmed = url.trim();
  if (trimmed.length === 0) return "Informe o endereço do link.";
  if (trimmed.length > 2000) return "O endereço é muito longo.";
  if (!/^https?:\/\/.+/i.test(trimmed)) {
    return "Use um endereço que comece com http:// ou https://.";
  }
  return null;
}

// Alguns navegadores entregam `type` vazio para Office: usa a extensão.
export function contentTypeFor(file: {name: string; type: string}): string {
  if (file.type) return file.type;
  const extension = file.name.split(".").pop()?.toLowerCase() ?? "";
  return EXTENSION_TYPES[extension] ?? "";
}

export function validateFile(file: {
  name: string;
  size: number;
  type: string;
}): string | null {
  if (file.size <= 0) return "O arquivo está vazio.";
  if (file.size > MAX_FILE_BYTES) return "O arquivo passa de 100 MB.";
  if (safeFileName(file.name).length > 200) {
    return "O nome do arquivo é muito longo.";
  }
  const type = contentTypeFor(file);
  const allowed = type.startsWith("image/") || ALLOWED_TYPES.has(type);
  if (!allowed) return "Tipo de arquivo não permitido. Use PDF, Office ou imagem.";
  return null;
}

export function safeFileName(name: string): string {
  return name.trim().replace(/[/\\]/g, "_");
}

export function storagePathFor(
  itemId: string,
  version: number,
  fileName: string
): string {
  return `teaching/materials/${itemId}/v${version}-${safeFileName(fileName)}`;
}
```

- [ ] **Step 4: Rodar testes, lint e tipos**

Run (um por vez): `npm --prefix web-portal test -- library`, `npm --prefix web-portal run lint`, `npm --prefix web-portal run typecheck`
Expected: PASS; lint e typecheck limpos. Se um teste de `sortItems` falhar por diferença de ICU entre ambientes (ordem de acentos), ajuste só a expectativa do teste mantendo a intenção (sem diferenciar acento/maiúscula e com números naturais) e relate.

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add web-portal/src/modules/teaching/library
/usr/bin/git commit -m "feat(web-portal): lógica pura da biblioteca (árvore, permissões, selos, validação)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Documentos no formato das regras (payloads) e conversão do Firestore

**Files:**
- Modify: `web-portal/src/modules/teaching/library/types.ts` (acrescentar `LibraryNotification`)
- Create: `web-portal/src/modules/teaching/library/payloads.ts`, `web-portal/src/modules/teaching/library/convert.ts`
- Test: `web-portal/src/modules/teaching/library/payloads.test.ts`, `web-portal/src/modules/teaching/library/convert.test.ts`

**Interfaces:**
- Consumes: `LibraryItem`, `LibraryVote`, `VoteAction`, `safeFileName`, `storagePathFor` (Task 1).
- Produces (usados na Task 3):
  - `interface LibraryNotification {id: string; toUid: string; type: string; itemId: string; title: string; body: string; createdAt: number; readAt: number | null}` (em `types.ts`).
  - Construtores recebem `now` (o valor para `serverTimestamp()`, injetado) e devolvem o documento exato:
    `newFolderPayload(i: {uid; name; parentId}, now)`, `newFilePayload(i: {uid; itemId; name; parentId; fileName; contentType; size}, now)`, `newLinkPayload(i: {uid; name; parentId; url; description?}, now)`, `renamePayload(i: {uid; name}, now)`, `movePayload(i: {uid; parentId}, now)`, `deleteRequestPayload(i: {uid; requestId; reason?}, now)`, `cancelDeletePayload(i: {uid}, now)`, `resubmitFilePayload(i: {uid; itemId; currentVersion; fileName; contentType; size; name?}, now)`, `resubmitLinkPayload(i: {uid; currentVersion; url; name?; description?}, now)`, `votePayload(i: {uid; action; version?; requestId?; comment?}, now)` e `voteCommentError(action: VoteAction, comment: string | undefined): string | null`.
  - `toItem(id: string, data: Record<string, unknown>): LibraryItem | null` (null se `type` ou `status` desconhecidos), `toVote(id: string, data: Record<string, unknown>): LibraryVote | null`, `toNotification(id: string, data: Record<string, unknown>): LibraryNotification | null`.

- [ ] **Step 1: Escrever os testes (que vão falhar)**

Criar `web-portal/src/modules/teaching/library/payloads.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {
  cancelDeletePayload,
  deleteRequestPayload,
  movePayload,
  newFilePayload,
  newFolderPayload,
  newLinkPayload,
  renamePayload,
  resubmitFilePayload,
  resubmitLinkPayload,
  voteCommentError,
  votePayload,
} from "./payloads";

const NOW = "AGORA";

describe("criação", () => {
  it("pasta: ativa, versão 1, autor e updatedBy iguais ao uid", () => {
    expect(newFolderPayload({uid: "c1", name: "  Crianças ", parentId: null}, NOW)).toEqual({
      type: "folder", name: "Crianças", parentId: null, authorId: "c1", updatedBy: "c1",
      status: "active", version: 1, createdAt: NOW, updatedAt: NOW,
    });
  });

  it("arquivo: em revisão, caminho no Storage com o id do item e nome sem barras", () => {
    expect(newFilePayload({
      uid: "t1", itemId: "abc", name: "Aula 1", parentId: "f1",
      fileName: "aula/1.pdf", contentType: "application/pdf", size: 1000,
    }, NOW)).toEqual({
      type: "file", name: "Aula 1", parentId: "f1", authorId: "t1", updatedBy: "t1",
      status: "in_review", version: 1, fileName: "aula_1.pdf", contentType: "application/pdf",
      size: 1000, storagePath: "teaching/materials/abc/v1-aula_1.pdf", createdAt: NOW, updatedAt: NOW,
    });
  });

  it("link: em revisão; description só quando preenchida", () => {
    const withDescription = newLinkPayload({uid: "t1", name: "Livro", parentId: null, url: " https://x.org ", description: " bom "}, NOW);
    expect(withDescription).toMatchObject({type: "link", status: "in_review", url: "https://x.org", description: "bom"});
    const without = newLinkPayload({uid: "t1", name: "Livro", parentId: null, url: "https://x.org", description: "  "}, NOW);
    expect(Object.keys(without)).not.toContain("description");
  });

  it("nenhum construtor de criação inclui campos que só a Function escreve", () => {
    const docs = [
      newFolderPayload({uid: "c1", name: "A", parentId: null}, NOW),
      newFilePayload({uid: "t1", itemId: "i", name: "A", parentId: null, fileName: "a.pdf", contentType: "application/pdf", size: 1}, NOW),
      newLinkPayload({uid: "t1", name: "A", parentId: null, url: "https://x.org"}, NOW),
    ];
    for (const doc of docs) {
      for (const forbidden of ["deleteRequest", "deleteRequested", "deleting", "returnComment", "returnedBy"]) {
        expect(Object.keys(doc)).not.toContain(forbidden);
      }
    }
  });
});

describe("organização e exclusão", () => {
  it("renomear e mover mexem só nos campos permitidos", () => {
    expect(renamePayload({uid: "c1", name: " Novo "}, NOW)).toEqual({name: "Novo", updatedBy: "c1", updatedAt: NOW});
    expect(movePayload({uid: "c1", parentId: null}, NOW)).toEqual({parentId: null, updatedBy: "c1", updatedAt: NOW});
  });

  it("pedido de exclusão: uuid recebido, quem pediu, motivo opcional", () => {
    expect(deleteRequestPayload({uid: "c1", requestId: "uuid-1", reason: " obsoleto "}, NOW)).toEqual({
      deleteRequested: true,
      deleteRequest: {id: "uuid-1", requestedBy: "c1", requestedAt: NOW, reason: "obsoleto"},
      updatedBy: "c1", updatedAt: NOW,
    });
    const noReason = deleteRequestPayload({uid: "c1", requestId: "uuid-2"}, NOW);
    expect(Object.keys(noReason.deleteRequest)).toEqual(["id", "requestedBy", "requestedAt"]);
  });

  it("cancelar o pedido zera os dois campos", () => {
    expect(cancelDeletePayload({uid: "c1"}, NOW)).toEqual({deleteRequested: false, deleteRequest: null, updatedBy: "c1", updatedAt: NOW});
  });
});

describe("reenvio", () => {
  it("arquivo: versão + 1, novo caminho, volta para em revisão", () => {
    expect(resubmitFilePayload({uid: "t1", itemId: "abc", currentVersion: 1, fileName: "novo.pdf", contentType: "application/pdf", size: 5}, NOW)).toEqual({
      status: "in_review", version: 2, fileName: "novo.pdf", contentType: "application/pdf", size: 5,
      storagePath: "teaching/materials/abc/v2-novo.pdf", updatedBy: "t1", updatedAt: NOW,
    });
  });

  it("arquivo com novo nome do item inclui name", () => {
    expect(resubmitFilePayload({uid: "t1", itemId: "abc", currentVersion: 2, fileName: "n.pdf", contentType: "application/pdf", size: 5, name: " Aula nova "}, NOW)).toMatchObject({name: "Aula nova", version: 3});
  });

  it("link: versão + 1 e nova url", () => {
    expect(resubmitLinkPayload({uid: "t1", currentVersion: 1, url: " https://novo.org "}, NOW)).toEqual({
      status: "in_review", version: 2, url: "https://novo.org", updatedBy: "t1", updatedAt: NOW,
    });
  });
});

describe("votos", () => {
  it("voto de publicação leva a versão e nunca o requestId", () => {
    expect(votePayload({uid: "c1", action: "approve", version: 2, requestId: "x"}, NOW)).toEqual({
      voterId: "c1", action: "approve", version: 2, createdAt: NOW,
    });
    expect(votePayload({uid: "c1", action: "return", version: 1, comment: " Falta a referência "}, NOW)).toEqual({
      voterId: "c1", action: "return", version: 1, comment: "Falta a referência", createdAt: NOW,
    });
  });

  it("voto de exclusão leva o requestId e nunca a versão", () => {
    expect(votePayload({uid: "c2", action: "delete_approve", requestId: "r1", version: 3}, NOW)).toEqual({
      voterId: "c2", action: "delete_approve", requestId: "r1", createdAt: NOW,
    });
    expect(votePayload({uid: "c2", action: "delete_refuse", requestId: "r1", comment: "Ainda é usado"}, NOW)).toEqual({
      voterId: "c2", action: "delete_refuse", requestId: "r1", comment: "Ainda é usado", createdAt: NOW,
    });
  });

  it("comentário é obrigatório em devolver, rejeitar e recusar exclusão", () => {
    expect(voteCommentError("approve", undefined)).toBeNull();
    expect(voteCommentError("delete_approve", "")).toBeNull();
    for (const action of ["return", "reject", "delete_refuse"] as const) {
      expect(voteCommentError(action, "   ")).toBe("Escreva um comentário.");
      expect(voteCommentError(action, undefined)).toBe("Escreva um comentário.");
      expect(voteCommentError(action, "x".repeat(1001))).toBe("O comentário pode ter no máximo 1000 caracteres.");
      expect(voteCommentError(action, "ok")).toBeNull();
    }
  });
});
```

Criar `web-portal/src/modules/teaching/library/convert.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {toItem, toNotification, toVote} from "./convert";

const ts = (ms: number) => ({toMillis: () => ms});

describe("toItem", () => {
  it("converte campos, timestamps e padrões", () => {
    expect(toItem("i1", {
      type: "file", name: "Aula", parentId: "f1", authorId: "t1", status: "in_review", version: 2,
      fileName: "a.pdf", contentType: "application/pdf", size: 10, storagePath: "p",
      createdAt: ts(500),
      deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: ts(700), reason: "x"},
    })).toEqual({
      id: "i1", type: "file", name: "Aula", parentId: "f1", authorId: "t1", status: "in_review", version: 2,
      updatedBy: undefined, fileName: "a.pdf", contentType: "application/pdf", size: 10, storagePath: "p",
      url: undefined, description: undefined, returnComment: null, returnedBy: null,
      deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: 700, reason: "x"},
      deleting: null, createdAt: 500,
    });
  });

  it("parentId ausente vira null e versão ausente vira 1", () => {
    const item = toItem("f", {type: "folder", name: "P", authorId: "c1", status: "active"});
    expect(item).toMatchObject({parentId: null, version: 1, deleteRequest: null, deleting: null});
  });

  it("tipo ou status desconhecidos devolvem null", () => {
    expect(toItem("x", {type: "banana", name: "x", authorId: "a", status: "active"})).toBeNull();
    expect(toItem("x", {type: "file", name: "x", authorId: "a", status: "?"})).toBeNull();
    expect(toItem("x", {})).toBeNull();
  });

  it("deleting só aceita os dois valores conhecidos", () => {
    expect(toItem("x", {type: "file", name: "x", authorId: "a", status: "published", deleting: "execute"})?.deleting).toBe("execute");
    expect(toItem("x", {type: "file", name: "x", authorId: "a", status: "published", deleting: "qualquer"})?.deleting).toBeNull();
  });
});

describe("toVote", () => {
  it("converte e descarta ação desconhecida", () => {
    expect(toVote("v1", {voterId: "c1", action: "approve", version: 1, createdAt: ts(10)})).toEqual({
      id: "v1", voterId: "c1", action: "approve", version: 1, requestId: undefined, comment: undefined, createdAt: 10,
    });
    expect(toVote("v2", {voterId: "c1", action: "x", createdAt: ts(1)})).toBeNull();
    expect(toVote("v3", {action: "approve"})).toBeNull();
  });
});

describe("toNotification", () => {
  it("converte e trata readAt nulo", () => {
    expect(toNotification("n1", {toUid: "t1", type: "published", itemId: "i1", title: "T", body: "B", createdAt: ts(9), readAt: null})).toEqual({
      id: "n1", toUid: "t1", type: "published", itemId: "i1", title: "T", body: "B", createdAt: 9, readAt: null,
    });
    expect(toNotification("n2", {toUid: "t1", type: "x", itemId: "i", title: "T", body: "B", createdAt: ts(1), readAt: ts(5)})?.readAt).toBe(5);
    expect(toNotification("n3", {type: "x"})).toBeNull();
  });
});
```

- [ ] **Step 2: Rodar para ver falhar**

Run: `npm --prefix web-portal test -- payloads convert`
Expected: FAIL — módulos `./payloads` e `./convert` não existem.

- [ ] **Step 3: Implementar**

Acrescentar ao final de `web-portal/src/modules/teaching/library/types.ts`:

```ts

export interface LibraryNotification {
  id: string;
  toUid: string;
  type: string;
  itemId: string;
  title: string;
  body: string;
  createdAt: number;
  readAt: number | null;
}
```

Criar `web-portal/src/modules/teaching/library/payloads.ts`:

```ts
import {safeFileName, storagePathFor} from "./files";
import type {VoteAction} from "./types";

// `now` é o valor de serverTimestamp(), injetado para os construtores ficarem
// puros. Cada construtor produz exatamente os campos que as regras aceitam.

export function newFolderPayload(
  i: {uid: string; name: string; parentId: string | null},
  now: unknown
) {
  return {
    type: "folder",
    name: i.name.trim(),
    parentId: i.parentId,
    authorId: i.uid,
    updatedBy: i.uid,
    status: "active",
    version: 1,
    createdAt: now,
    updatedAt: now,
  };
}

export function newFilePayload(
  i: {
    uid: string;
    itemId: string;
    name: string;
    parentId: string | null;
    fileName: string;
    contentType: string;
    size: number;
  },
  now: unknown
) {
  return {
    type: "file",
    name: i.name.trim(),
    parentId: i.parentId,
    authorId: i.uid,
    updatedBy: i.uid,
    status: "in_review",
    version: 1,
    fileName: safeFileName(i.fileName),
    contentType: i.contentType,
    size: i.size,
    storagePath: storagePathFor(i.itemId, 1, i.fileName),
    createdAt: now,
    updatedAt: now,
  };
}

export function newLinkPayload(
  i: {
    uid: string;
    name: string;
    parentId: string | null;
    url: string;
    description?: string;
  },
  now: unknown
) {
  const description = i.description?.trim();
  return {
    type: "link",
    name: i.name.trim(),
    parentId: i.parentId,
    authorId: i.uid,
    updatedBy: i.uid,
    status: "in_review",
    version: 1,
    url: i.url.trim(),
    ...(description ? {description} : {}),
    createdAt: now,
    updatedAt: now,
  };
}

export function renamePayload(i: {uid: string; name: string}, now: unknown) {
  return {name: i.name.trim(), updatedBy: i.uid, updatedAt: now};
}

export function movePayload(
  i: {uid: string; parentId: string | null},
  now: unknown
) {
  return {parentId: i.parentId, updatedBy: i.uid, updatedAt: now};
}

export function deleteRequestPayload(
  i: {uid: string; requestId: string; reason?: string},
  now: unknown
) {
  const reason = i.reason?.trim();
  return {
    deleteRequested: true,
    deleteRequest: {
      id: i.requestId,
      requestedBy: i.uid,
      requestedAt: now,
      ...(reason ? {reason} : {}),
    },
    updatedBy: i.uid,
    updatedAt: now,
  };
}

export function cancelDeletePayload(i: {uid: string}, now: unknown) {
  return {
    deleteRequested: false,
    deleteRequest: null,
    updatedBy: i.uid,
    updatedAt: now,
  };
}

export function resubmitFilePayload(
  i: {
    uid: string;
    itemId: string;
    currentVersion: number;
    fileName: string;
    contentType: string;
    size: number;
    name?: string;
  },
  now: unknown
) {
  const version = i.currentVersion + 1;
  const name = i.name?.trim();
  return {
    status: "in_review",
    version,
    ...(name ? {name} : {}),
    fileName: safeFileName(i.fileName),
    contentType: i.contentType,
    size: i.size,
    storagePath: storagePathFor(i.itemId, version, i.fileName),
    updatedBy: i.uid,
    updatedAt: now,
  };
}

export function resubmitLinkPayload(
  i: {
    uid: string;
    currentVersion: number;
    url: string;
    name?: string;
    description?: string;
  },
  now: unknown
) {
  const name = i.name?.trim();
  const description = i.description?.trim();
  return {
    status: "in_review",
    version: i.currentVersion + 1,
    ...(name ? {name} : {}),
    url: i.url.trim(),
    ...(description ? {description} : {}),
    updatedBy: i.uid,
    updatedAt: now,
  };
}

const DELETION_ACTIONS: VoteAction[] = ["delete_approve", "delete_refuse"];

export function voteCommentError(
  action: VoteAction,
  comment: string | undefined
): string | null {
  if (action === "approve" || action === "delete_approve") return null;
  const text = comment?.trim() ?? "";
  if (text.length === 0) return "Escreva um comentário.";
  if (text.length > 1000) return "O comentário pode ter no máximo 1000 caracteres.";
  return null;
}

export function votePayload(
  i: {
    uid: string;
    action: VoteAction;
    version?: number;
    requestId?: string;
    comment?: string;
  },
  now: unknown
) {
  const comment = i.comment?.trim();
  const isDeletion = DELETION_ACTIONS.includes(i.action);
  return {
    voterId: i.uid,
    action: i.action,
    ...(isDeletion ?
      {requestId: i.requestId} :
      {version: i.version}),
    ...(comment ? {comment} : {}),
    createdAt: now,
  };
}
```

Criar `web-portal/src/modules/teaching/library/convert.ts`:

```ts
import type {
  ItemStatus,
  ItemType,
  LibraryItem,
  LibraryNotification,
  LibraryVote,
  VoteAction,
} from "./types";

type Data = Record<string, unknown>;

const TYPES: ItemType[] = ["folder", "file", "link"];
const STATUSES: ItemStatus[] = ["active", "in_review", "returned", "published"];
const ACTIONS: VoteAction[] = [
  "approve",
  "reject",
  "return",
  "delete_approve",
  "delete_refuse",
];

function millis(value: unknown): number {
  const maybe = value as {toMillis?: () => number} | null | undefined;
  if (maybe && typeof maybe.toMillis === "function") return maybe.toMillis();
  return typeof value === "number" ? value : 0;
}

const str = (value: unknown): string | undefined =>
  typeof value === "string" ? value : undefined;

export function toItem(id: string, data: Data): LibraryItem | null {
  const type = data.type as ItemType;
  const status = data.status as ItemStatus;
  if (!TYPES.includes(type) || !STATUSES.includes(status)) return null;

  const raw = data.deleteRequest as Data | null | undefined;
  const request = raw ?
    {
      id: String(raw.id),
      requestedBy: String(raw.requestedBy),
      requestedAt: millis(raw.requestedAt),
      reason: str(raw.reason),
    } :
    null;
  const deleting = data.deleting;
  return {
    id,
    type,
    name: str(data.name) ?? "",
    parentId: typeof data.parentId === "string" ? data.parentId : null,
    authorId: str(data.authorId) ?? "",
    status,
    version: typeof data.version === "number" ? data.version : 1,
    updatedBy: str(data.updatedBy),
    fileName: str(data.fileName),
    contentType: str(data.contentType),
    size: typeof data.size === "number" ? data.size : undefined,
    storagePath: str(data.storagePath),
    url: str(data.url),
    description: str(data.description),
    returnComment: str(data.returnComment) ?? null,
    returnedBy: str(data.returnedBy) ?? null,
    deleteRequest: request,
    deleting: deleting === "reject" || deleting === "execute" ? deleting : null,
    createdAt: data.createdAt === undefined ? undefined : millis(data.createdAt),
  };
}

export function toVote(id: string, data: Data): LibraryVote | null {
  const action = data.action as VoteAction;
  const voterId = str(data.voterId);
  if (!voterId || !ACTIONS.includes(action)) return null;
  return {
    id,
    voterId,
    action,
    version: typeof data.version === "number" ? data.version : undefined,
    requestId: str(data.requestId),
    comment: str(data.comment),
    createdAt: millis(data.createdAt),
  };
}

export function toNotification(id: string, data: Data): LibraryNotification | null {
  const toUid = str(data.toUid);
  const itemId = str(data.itemId);
  if (!toUid || !itemId) return null;
  return {
    id,
    toUid,
    type: str(data.type) ?? "",
    itemId,
    title: str(data.title) ?? "",
    body: str(data.body) ?? "",
    createdAt: millis(data.createdAt),
    readAt: data.readAt ? millis(data.readAt) : null,
  };
}
```

- [ ] **Step 4: Rodar testes, lint e tipos**

Run (um por vez): `npm --prefix web-portal test -- payloads convert`, `npm --prefix web-portal run lint`, `npm --prefix web-portal run typecheck`
Expected: PASS; lint e typecheck limpos.

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add web-portal/src/modules/teaching/library
/usr/bin/git commit -m "feat(web-portal): documentos no formato das regras e conversão do Firestore

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Camada de dados (leitura, escrita, envio de arquivo, notificações)

**Files:**
- Create: `web-portal/src/modules/teaching/library/merge.ts`, `uploadFlow.ts`, `repository.ts`, `mutations.ts`, `notifications.ts`
- Test: `web-portal/src/modules/teaching/library/merge.test.ts`, `uploadFlow.test.ts`

**Interfaces:**
- Consumes: Tasks 1 e 2 (tipos, `validateFile`, `validateName`, `contentTypeFor`, `newFilePayload`, conversores, construtores de payload) e `db`, `storage` de `@/core/firebase/client`.
- Produces (usados nas Tasks 4 a 7):
  - `mergeById(lists: LibraryItem[][]): LibraryItem[]` (sem repetidos; a última lista vence).
  - `uploadFileItem<F extends FileLike>(deps: UploadDeps<F>, input: {uid: string; parentId: string | null; file: F; name?: string; onProgress?: (fraction: number) => void}): Promise<string>` e `class UploadError extends Error {stage: "validate" | "upload" | "create"}`; `interface FileLike {name: string; size: number; type: string}`; `interface UploadDeps<F>` com `newId(): string`, `uploadObject(path: string, file: F, contentType: string, onProgress: (fraction: number) => void): Promise<void>`, `createItem(id: string, payload: Record<string, unknown>): Promise<void>`, `now(): unknown`.
  - `repository.ts`: `subscribeFolder(folderId: string | null, viewer: Viewer, onData: (items: LibraryItem[]) => void, onError: (e: Error) => void): () => void`; `loadAllVisible(viewer: Viewer): Promise<LibraryItem[]>`; `subscribeItem(id: string, onData: (item: LibraryItem | null) => void, onError: (e: Error) => void): () => void`; `subscribeVotes(itemId: string, onData: (votes: LibraryVote[]) => void, onError: (e: Error) => void): () => void`; `loadUserNames(uids: string[]): Promise<Record<string, string>>`; `loadReviewQueue(): Promise<{inReview: LibraryItem[]; deleteRequests: LibraryItem[]}>` (curador/admin); `canReadVotes(item: LibraryItem, viewer: Viewer): boolean`.
  - `mutations.ts`: `createFolder(uid, name, parentId)`, `createLink(uid, input)`, `uploadFile(uid, parentId, file, onProgress?, name?)`, `renameItem(uid, id, name)`, `moveItem(uid, id, parentId)`, `requestDelete(uid, id, reason?)`, `cancelDelete(uid, id)`, `resubmitFile(uid, item, file, onProgress?)`, `resubmitLink(uid, item, input)`, `castVote(uid, item, action, comment?)` — todas `Promise<void>` (exceto `uploadFile`/`createFolder`/`createLink`, que devolvem o id).
  - `notifications.ts`: `subscribeNotifications(uid: string, onData: (list: LibraryNotification[]) => void, onError: (e: Error) => void): () => void` (mais recentes primeiro, no máximo 100), `markRead(id: string): Promise<void>`, `markAllRead(ids: string[]): Promise<void>`.

- [ ] **Step 1: Escrever os testes (que vão falhar)**

Criar `web-portal/src/modules/teaching/library/merge.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {mergeById} from "./merge";
import type {LibraryItem} from "./types";

const item = (id: string, name: string): LibraryItem => ({
  id, name, type: "file", parentId: null, authorId: "a", status: "published", version: 1,
});

describe("mergeById", () => {
  it("junta listas sem repetir ids; a última lista vence", () => {
    const merged = mergeById([[item("1", "velho"), item("2", "B")], [item("1", "novo")], []]);
    expect(merged.map((i) => [i.id, i.name]).sort()).toEqual([["1", "novo"], ["2", "B"]]);
  });

  it("lista vazia devolve vazio", () => {
    expect(mergeById([])).toEqual([]);
  });
});
```

Criar `web-portal/src/modules/teaching/library/uploadFlow.test.ts`:

```ts
import {describe, expect, it, vi} from "vitest";
import {UploadError, uploadFileItem, type UploadDeps} from "./uploadFlow";

const pdf = {name: "aula.pdf", size: 100, type: "application/pdf"};

function makeDeps(overrides: Partial<UploadDeps<typeof pdf>> = {}) {
  const calls: string[] = [];
  const deps: UploadDeps<typeof pdf> = {
    newId: () => "item1",
    now: () => "AGORA",
    uploadObject: vi.fn(async (_path, _file, _type, onProgress) => {
      calls.push("upload");
      onProgress(0.5);
      onProgress(1);
    }),
    createItem: vi.fn(async () => {
      calls.push("create");
    }),
    ...overrides,
  };
  return {deps, calls};
}

describe("uploadFileItem", () => {
  it("envia o arquivo primeiro e só depois cria o documento, com o formato das regras", async () => {
    const {deps, calls} = makeDeps();
    const progress: number[] = [];
    const id = await uploadFileItem(deps, {uid: "t1", parentId: "f1", file: pdf, onProgress: (p) => progress.push(p)});
    expect(id).toBe("item1");
    expect(calls).toEqual(["upload", "create"]);
    expect(progress).toEqual([0.5, 1]);
    expect(deps.uploadObject).toHaveBeenCalledWith("teaching/materials/item1/v1-aula.pdf", pdf, "application/pdf", expect.any(Function));
    expect(deps.createItem).toHaveBeenCalledWith("item1", expect.objectContaining({
      type: "file", status: "in_review", authorId: "t1", parentId: "f1", name: "aula.pdf",
      storagePath: "teaching/materials/item1/v1-aula.pdf", createdAt: "AGORA",
    }));
  });

  it("nome do item opcional e limitado a 120 caracteres", async () => {
    const {deps} = makeDeps();
    await uploadFileItem(deps, {uid: "t1", parentId: null, file: pdf, name: "Aula especial"});
    expect(deps.createItem).toHaveBeenCalledWith("item1", expect.objectContaining({name: "Aula especial"}));
    const long = {name: `${"a".repeat(150)}.pdf`, size: 10, type: "application/pdf"};
    const second = makeDeps();
    await uploadFileItem(second.deps as unknown as UploadDeps<typeof long>, {uid: "t1", parentId: null, file: long});
    const payload = (second.deps.createItem as ReturnType<typeof vi.fn>).mock.calls[0][1] as {name: string};
    expect(payload.name.length).toBeLessThanOrEqual(120);
  });

  it("arquivo inválido não envia nem cria (estágio validate)", async () => {
    const {deps} = makeDeps();
    const error = await uploadFileItem(deps, {uid: "t1", parentId: null, file: {name: "a.exe", size: 10, type: "application/x-msdownload"}}).catch((e) => e);
    expect(error).toBeInstanceOf(UploadError);
    expect(error.stage).toBe("validate");
    expect(deps.uploadObject).not.toHaveBeenCalled();
    expect(deps.createItem).not.toHaveBeenCalled();
  });

  it("falha do envio não cria o documento (estágio upload)", async () => {
    const {deps} = makeDeps({uploadObject: vi.fn(async () => {
      throw new Error("rede");
    })});
    const error = await uploadFileItem(deps, {uid: "t1", parentId: null, file: pdf}).catch((e) => e);
    expect(error.stage).toBe("upload");
    expect(error.message).toBe("Não foi possível enviar o arquivo. Tente novamente.");
    expect(deps.createItem).not.toHaveBeenCalled();
  });

  it("falha ao criar o documento depois do envio é sinalizada (estágio create)", async () => {
    const {deps} = makeDeps({createItem: vi.fn(async () => {
      throw new Error("permission-denied");
    })});
    const error = await uploadFileItem(deps, {uid: "t1", parentId: null, file: pdf}).catch((e) => e);
    expect(error.stage).toBe("create");
    expect(error.message).toBe("O arquivo foi enviado, mas não foi possível registrar o item. Tente novamente.");
  });
});
```

- [ ] **Step 2: Rodar para ver falhar**

Run: `npm --prefix web-portal test -- merge uploadFlow`
Expected: FAIL — `./merge` e `./uploadFlow` não existem.

- [ ] **Step 3: Implementar**

Criar `web-portal/src/modules/teaching/library/merge.ts`:

```ts
import type {LibraryItem} from "./types";

export function mergeById(lists: LibraryItem[][]): LibraryItem[] {
  const byId = new Map<string, LibraryItem>();
  for (const list of lists) {
    for (const item of list) byId.set(item.id, item);
  }
  return [...byId.values()];
}
```

Criar `web-portal/src/modules/teaching/library/uploadFlow.ts`:

```ts
import {contentTypeFor, validateFile} from "./files";
import {newFilePayload} from "./payloads";
import {storagePathFor} from "./files";

export interface FileLike {
  name: string;
  size: number;
  type: string;
}

export interface UploadDeps<F extends FileLike> {
  newId(): string;
  now(): unknown;
  uploadObject(
    path: string,
    file: F,
    contentType: string,
    onProgress: (fraction: number) => void
  ): Promise<void>;
  createItem(id: string, payload: Record<string, unknown>): Promise<void>;
}

export class UploadError extends Error {
  constructor(
    public readonly stage: "validate" | "upload" | "create",
    message: string
  ) {
    super(message);
  }
}

// Ordem: validar → enviar o arquivo → criar o documento. Se o documento não
// for criado o objeto fica órfão e ilegível (as regras exigem o item).
export async function uploadFileItem<F extends FileLike>(
  deps: UploadDeps<F>,
  input: {
    uid: string;
    parentId: string | null;
    file: F;
    name?: string;
    onProgress?: (fraction: number) => void;
  }
): Promise<string> {
  const problem = validateFile(input.file);
  if (problem) throw new UploadError("validate", problem);

  const id = deps.newId();
  const contentType = contentTypeFor(input.file);
  const name = (input.name ?? input.file.name).trim().slice(0, 120);

  try {
    await deps.uploadObject(
      storagePathFor(id, 1, input.file.name),
      input.file,
      contentType,
      input.onProgress ?? (() => undefined)
    );
  } catch {
    throw new UploadError(
      "upload",
      "Não foi possível enviar o arquivo. Tente novamente."
    );
  }

  try {
    await deps.createItem(
      id,
      newFilePayload(
        {
          uid: input.uid,
          itemId: id,
          name,
          parentId: input.parentId,
          fileName: input.file.name,
          contentType,
          size: input.file.size,
        },
        deps.now()
      )
    );
  } catch {
    throw new UploadError(
      "create",
      "O arquivo foi enviado, mas não foi possível registrar o item. Tente novamente."
    );
  }
  return id;
}
```

Criar `web-portal/src/modules/teaching/library/repository.ts`:

```ts
import {
  collection,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  query,
  where,
  type DocumentData,
  type QuerySnapshot,
} from "firebase/firestore";
import {db} from "@/core/firebase/client";
import {toItem, toVote} from "./convert";
import {mergeById} from "./merge";
import type {LibraryItem, LibraryVote, Viewer} from "./types";

const items = () => collection(db, "teaching_items");

function itemsFrom(snapshot: QuerySnapshot<DocumentData>): LibraryItem[] {
  return snapshot.docs
    .map((d) => toItem(d.id, d.data()))
    .filter((item): item is LibraryItem => item !== null);
}

// Curador e admin leem tudo; professor precisa de filtros que provem a regra:
// publicado, ativo (pastas) e os próprios envios da pasta.
function folderQueries(folderId: string | null, viewer: Viewer) {
  if (viewer.isCurator || viewer.isAdmin) {
    return [query(items(), where("parentId", "==", folderId))];
  }
  return [
    query(items(), where("parentId", "==", folderId), where("status", "==", "published")),
    query(items(), where("parentId", "==", folderId), where("status", "==", "active")),
    query(items(), where("parentId", "==", folderId), where("authorId", "==", viewer.uid)),
  ];
}

export function subscribeFolder(
  folderId: string | null,
  viewer: Viewer,
  onData: (items: LibraryItem[]) => void,
  onError: (error: Error) => void
): () => void {
  const queries = folderQueries(folderId, viewer);
  const latest: Array<LibraryItem[] | undefined> = queries.map(() => undefined);
  let active = true;
  const unsubscribers = queries.map((q, index) =>
    onSnapshot(
      q,
      (snapshot) => {
        if (!active) return;
        latest[index] = itemsFrom(snapshot);
        if (latest.every((list) => list !== undefined)) {
          onData(mergeById(latest as LibraryItem[][]));
        }
      },
      (error) => active && onError(error)
    )
  );
  return () => {
    active = false;
    unsubscribers.forEach((stop) => stop());
  };
}

// Todos os itens que o espectador pode ver (busca por nome e migalhas).
export async function loadAllVisible(viewer: Viewer): Promise<LibraryItem[]> {
  if (viewer.isCurator || viewer.isAdmin) {
    return itemsFrom(await getDocs(items()));
  }
  const snapshots = await Promise.all([
    getDocs(query(items(), where("status", "==", "published"))),
    getDocs(query(items(), where("status", "==", "active"))),
    getDocs(query(items(), where("authorId", "==", viewer.uid))),
  ]);
  return mergeById(snapshots.map(itemsFrom));
}

export function subscribeItem(
  id: string,
  onData: (item: LibraryItem | null) => void,
  onError: (error: Error) => void
): () => void {
  return onSnapshot(
    doc(db, "teaching_items", id),
    (snapshot) => onData(snapshot.exists() ? toItem(snapshot.id, snapshot.data()) : null),
    onError
  );
}

export function canReadVotes(item: LibraryItem, viewer: Viewer): boolean {
  return viewer.isCurator || viewer.isAdmin || item.authorId === viewer.uid;
}

export function subscribeVotes(
  itemId: string,
  onData: (votes: LibraryVote[]) => void,
  onError: (error: Error) => void
): () => void {
  return onSnapshot(
    collection(db, "teaching_items", itemId, "votes"),
    (snapshot) =>
      onData(
        snapshot.docs
          .map((d) => toVote(d.id, d.data()))
          .filter((vote): vote is LibraryVote => vote !== null)
      ),
    onError
  );
}

const nameCache = new Map<string, string>();

// Nome de exibição dos votantes (users/{uid} é legível por quem está logado).
export async function loadUserNames(uids: string[]): Promise<Record<string, string>> {
  const result: Record<string, string> = {};
  await Promise.all(
    [...new Set(uids)].map(async (uid) => {
      if (!nameCache.has(uid)) {
        try {
          const snapshot = await getDoc(doc(db, "users", uid));
          const name = snapshot.data()?.name;
          nameCache.set(uid, typeof name === "string" && name ? name : "Curador");
        } catch {
          nameCache.set(uid, "Curador");
        }
      }
      result[uid] = nameCache.get(uid) as string;
    })
  );
  return result;
}

// Fila de revisão (curador e admin): em revisão e pedidos de exclusão.
export async function loadReviewQueue(): Promise<{
  inReview: LibraryItem[];
  deleteRequests: LibraryItem[];
}> {
  const [review, deletes] = await Promise.all([
    getDocs(query(items(), where("status", "==", "in_review"))),
    getDocs(query(items(), where("deleteRequested", "==", true))),
  ]);
  return {inReview: itemsFrom(review), deleteRequests: itemsFrom(deletes)};
}
```

Criar `web-portal/src/modules/teaching/library/mutations.ts`:

```ts
import {
  addDoc,
  collection,
  doc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from "firebase/firestore";
import {ref, uploadBytesResumable} from "firebase/storage";
import {db, storage} from "@/core/firebase/client";
import {contentTypeFor, storagePathFor, validateFile} from "./files";
import {
  cancelDeletePayload,
  deleteRequestPayload,
  movePayload,
  newFolderPayload,
  newLinkPayload,
  renamePayload,
  resubmitFilePayload,
  resubmitLinkPayload,
  voteCommentError,
  votePayload,
} from "./payloads";
import {UploadError, uploadFileItem} from "./uploadFlow";
import type {LibraryItem, VoteAction} from "./types";

const itemRef = (id: string) => doc(db, "teaching_items", id);

function uploadObject(
  path: string,
  file: File,
  contentType: string,
  onProgress: (fraction: number) => void
): Promise<void> {
  return new Promise((resolve, reject) => {
    const task = uploadBytesResumable(ref(storage, path), file, {contentType});
    task.on(
      "state_changed",
      (snapshot) => onProgress(snapshot.totalBytes ? snapshot.bytesTransferred / snapshot.totalBytes : 0),
      reject,
      () => resolve()
    );
  });
}

export async function createFolder(
  uid: string,
  name: string,
  parentId: string | null
): Promise<string> {
  const id = doc(collection(db, "teaching_items")).id;
  await setDoc(itemRef(id), newFolderPayload({uid, name, parentId}, serverTimestamp()));
  return id;
}

export async function createLink(
  uid: string,
  input: {name: string; parentId: string | null; url: string; description?: string}
): Promise<string> {
  const id = doc(collection(db, "teaching_items")).id;
  await setDoc(itemRef(id), newLinkPayload({uid, ...input}, serverTimestamp()));
  return id;
}

export function uploadFile(
  uid: string,
  parentId: string | null,
  file: File,
  onProgress?: (fraction: number) => void,
  name?: string
): Promise<string> {
  return uploadFileItem<File>(
    {
      newId: () => doc(collection(db, "teaching_items")).id,
      now: () => serverTimestamp(),
      uploadObject,
      createItem: (id, payload) => setDoc(itemRef(id), payload),
    },
    {uid, parentId, file, name, onProgress}
  );
}

export async function renameItem(uid: string, id: string, name: string): Promise<void> {
  await updateDoc(itemRef(id), renamePayload({uid, name}, serverTimestamp()));
}

export async function moveItem(uid: string, id: string, parentId: string | null): Promise<void> {
  await updateDoc(itemRef(id), movePayload({uid, parentId}, serverTimestamp()));
}

export async function requestDelete(uid: string, id: string, reason?: string): Promise<void> {
  await updateDoc(
    itemRef(id),
    deleteRequestPayload({uid, requestId: crypto.randomUUID(), reason}, serverTimestamp())
  );
}

export async function cancelDelete(uid: string, id: string): Promise<void> {
  await updateDoc(itemRef(id), cancelDeletePayload({uid}, serverTimestamp()));
}

// Reenvio de arquivo devolvido: novo objeto no Storage, depois o documento.
export async function resubmitFile(
  uid: string,
  item: LibraryItem,
  file: File,
  onProgress?: (fraction: number) => void
): Promise<void> {
  const problem = validateFile(file);
  if (problem) throw new UploadError("validate", problem);
  const contentType = contentTypeFor(file);
  const nextVersion = item.version + 1;
  try {
    await uploadObject(storagePathFor(item.id, nextVersion, file.name), file, contentType, onProgress ?? (() => undefined));
  } catch {
    throw new UploadError("upload", "Não foi possível enviar o arquivo. Tente novamente.");
  }
  try {
    await updateDoc(
      itemRef(item.id),
      resubmitFilePayload(
        {uid, itemId: item.id, currentVersion: item.version, fileName: file.name, contentType, size: file.size},
        serverTimestamp()
      )
    );
  } catch {
    throw new UploadError("create", "O arquivo foi enviado, mas não foi possível reenviar o item. Tente novamente.");
  }
}

export async function resubmitLink(
  uid: string,
  item: LibraryItem,
  input: {url: string; name?: string; description?: string}
): Promise<void> {
  await updateDoc(
    itemRef(item.id),
    resubmitLinkPayload({uid, currentVersion: item.version, ...input}, serverTimestamp())
  );
}

export async function castVote(
  uid: string,
  item: LibraryItem,
  action: VoteAction,
  comment?: string
): Promise<void> {
  const problem = voteCommentError(action, comment);
  if (problem) throw new Error(problem);
  const isDeletion = action === "delete_approve" || action === "delete_refuse";
  await addDoc(
    collection(db, "teaching_items", item.id, "votes"),
    votePayload(
      {
        uid,
        action,
        comment,
        version: isDeletion ? undefined : item.version,
        requestId: isDeletion ? item.deleteRequest?.id : undefined,
      },
      serverTimestamp()
    )
  );
}
```

Criar `web-portal/src/modules/teaching/library/notifications.ts`:

```ts
import {
  collection,
  doc,
  onSnapshot,
  query,
  serverTimestamp,
  updateDoc,
  where,
} from "firebase/firestore";
import {db} from "@/core/firebase/client";
import {toNotification} from "./convert";
import type {LibraryNotification} from "./types";

const MAX_NOTIFICATIONS = 100;

// Sem orderBy (evita índice composto): ordena e limita no cliente.
export function subscribeNotifications(
  uid: string,
  onData: (list: LibraryNotification[]) => void,
  onError: (error: Error) => void
): () => void {
  return onSnapshot(
    query(collection(db, "teaching_notifications"), where("toUid", "==", uid)),
    (snapshot) => {
      const list = snapshot.docs
        .map((d) => toNotification(d.id, d.data()))
        .filter((n): n is LibraryNotification => n !== null)
        .sort((a, b) => b.createdAt - a.createdAt)
        .slice(0, MAX_NOTIFICATIONS);
      onData(list);
    },
    onError
  );
}

export async function markRead(id: string): Promise<void> {
  await updateDoc(doc(db, "teaching_notifications", id), {readAt: serverTimestamp()});
}

export async function markAllRead(ids: string[]): Promise<void> {
  await Promise.all(ids.map((id) => markRead(id)));
}
```

- [ ] **Step 4: Rodar testes, lint, tipos e build**

Run (um por vez): `npm --prefix web-portal test`, `npm --prefix web-portal run lint`, `npm --prefix web-portal run typecheck`, `npm --prefix web-portal run build`
Expected: PASS; lint, typecheck e build limpos. Os arquivos `repository.ts`, `mutations.ts` e `notifications.ts` só têm lógica fina sobre o SDK (testada via as funções puras e, nas tarefas seguintes, por repositórios simulados nas telas); se o typecheck reclamar de algum tipo do SDK Firebase 13 (por exemplo, de `QuerySnapshot`), ajuste os tipos locais sem mudar o comportamento e relate.

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add web-portal/src/modules/teaching/library
/usr/bin/git commit -m "feat(web-portal): camada de dados da biblioteca (leitura, escrita, envio, notificações)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Página da biblioteca (navegação por pastas, busca, lista e grade) — somente leitura

**Files:**
- Create: `web-portal/src/modules/teaching/library/url.ts`, `useLibrary.ts`, `ui/StatusBadge.tsx`, `ui/Breadcrumbs.tsx`, `ui/ItemRow.tsx`, `ui/FolderView.tsx`, `ui/LibraryPage.tsx`
- Create: `web-portal/src/app/(portal)/ensino/biblioteca/page.tsx`
- Modify: `web-portal/src/modules/teaching/module.ts`, `web-portal/src/modules/teaching/pages/TeachingHomePage.tsx`, `web-portal/src/modules/teaching/library/status.ts` (aceitar `approvals: number | null`)
- Test: `web-portal/src/modules/teaching/library/url.test.ts`, `web-portal/src/modules/teaching/library/ui/LibraryPage.test.tsx`

**Interfaces:**
- Consumes: Tasks 1 a 3 (`sortItems`, `filterByName`, `indexById`, `buildBreadcrumbs`, `statusBadge`, `viewerFrom`, `subscribeFolder`, `loadAllVisible`) e `useAuth`.
- Produces (usados nas Tasks 5 a 7):
  - `libraryUrl(params: {pasta?: string | null; item?: string | null}): string` e `readParams(search: {get(name: string): string | null}): {pasta: string | null; item: string | null}`.
  - `useFolderItems(folderId: string | null, viewer: Viewer): {items: LibraryItem[] | null; error: string | null}` e `useCatalog(viewer: Viewer): {items: LibraryItem[] | null; error: string | null; reload: () => void}`.
  - `<StatusBadge badge={{label, tone}} />`, `<Breadcrumbs trail={LibraryItem[]} onNavigate={(url: string) => void} />`, `<ItemRow item badge view onOpen />`.
  - `<LibraryContent viewer={Viewer} folderId={string | null} itemId={string | null} navigate={(url: string) => void} />` (componente testável) e `export default function LibraryPage()` (lê `useSearchParams`, o usuário logado e chama `LibraryContent`).
  - `statusBadge(item, approvals: number | null)`: com `null` mostra "Em revisão" sem contagem.

- [ ] **Step 1: Escrever os testes (que vão falhar)**

Criar `web-portal/src/modules/teaching/library/url.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {libraryUrl, readParams} from "./url";

describe("libraryUrl", () => {
  it("raiz, pasta, item e os dois", () => {
    expect(libraryUrl({})).toBe("/ensino/biblioteca");
    expect(libraryUrl({pasta: null})).toBe("/ensino/biblioteca");
    expect(libraryUrl({pasta: "f1"})).toBe("/ensino/biblioteca?pasta=f1");
    expect(libraryUrl({item: "i1"})).toBe("/ensino/biblioteca?item=i1");
    expect(libraryUrl({pasta: "f1", item: "i1"})).toBe("/ensino/biblioteca?pasta=f1&item=i1");
  });

  it("codifica ids com caracteres especiais", () => {
    expect(libraryUrl({pasta: "a b&c"})).toBe("/ensino/biblioteca?pasta=a%20b%26c");
  });
});

describe("readParams", () => {
  it("lê pasta e item; vazios viram null", () => {
    const search = new URLSearchParams("pasta=f1&item=");
    expect(readParams(search)).toEqual({pasta: "f1", item: null});
    expect(readParams(new URLSearchParams(""))).toEqual({pasta: null, item: null});
  });
});
```

Criar `web-portal/src/modules/teaching/library/ui/LibraryPage.test.tsx`:

```tsx
import {render, screen, waitFor, fireEvent} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {LibraryItem, Viewer} from "../types";
import {LibraryContent} from "./LibraryPage";

const repo = vi.hoisted(() => ({
  subscribeFolder: vi.fn(),
  loadAllVisible: vi.fn(),
}));
vi.mock("../repository", () => repo);

const item = (id: string, name: string, extra: Partial<LibraryItem> = {}): LibraryItem => ({
  id, name, type: "file", parentId: null, authorId: "a", status: "published", version: 1, ...extra,
});
const folder = (id: string, name: string, parentId: string | null = null) =>
  item(id, name, {type: "folder", status: "active", parentId});

const catalog = [
  folder("f1", "Crianças"),
  folder("f2", "Antigo Testamento", "f1"),
  item("i1", "Catecismo Menor"),
  item("i2", "Aula 2", {parentId: "f1"}),
  item("i3", "Aula 10", {parentId: "f1", status: "in_review"}),
  item("i4", "Livro", {parentId: "f1", type: "link", url: "https://x.org", status: "returned"}),
];

const teacher: Viewer = {uid: "t1", isCurator: false, isAdmin: false};
const folderData = (id: string | null) => catalog.filter((i) => i.parentId === id);

let unsubscribe: ReturnType<typeof vi.fn>;
beforeEach(() => {
  unsubscribe = vi.fn();
  repo.subscribeFolder.mockReset().mockImplementation((id, _viewer, onData) => {
    onData(folderData(id));
    return unsubscribe;
  });
  repo.loadAllVisible.mockReset().mockResolvedValue(catalog);
});

function renderAt(folderId: string | null, navigate = vi.fn(), itemId: string | null = null) {
  render(<LibraryContent viewer={teacher} folderId={folderId} itemId={itemId} navigate={navigate} />);
  return navigate;
}

describe("LibraryContent", () => {
  it("lista a raiz com pastas primeiro e selos de estado", async () => {
    renderAt(null);
    expect(await screen.findByText("Crianças")).toBeInTheDocument();
    const rows = screen.getAllByRole("button", {name: /Abrir /});
    expect(rows[0]).toHaveAccessibleName("Abrir Crianças");
    expect(screen.getByText("Catecismo Menor")).toBeInTheDocument();
    expect(screen.getByText("Publicado")).toBeInTheDocument();
  });

  it("em uma pasta mostra em revisão e devolvido", async () => {
    renderAt("f1");
    expect(await screen.findByText("Aula 10")).toBeInTheDocument();
    expect(screen.getByText("Em revisão")).toBeInTheDocument();
    expect(screen.getByText("Devolvido")).toBeInTheDocument();
  });

  it("abrir uma pasta navega para ?pasta=; abrir um arquivo mantém a pasta e adiciona ?item=", async () => {
    const navigate = renderAt("f1");
    fireEvent.click(await screen.findByRole("button", {name: "Abrir Antigo Testamento"}));
    expect(navigate).toHaveBeenCalledWith("/ensino/biblioteca?pasta=f2");
    fireEvent.click(screen.getByRole("button", {name: "Abrir Aula 2"}));
    expect(navigate).toHaveBeenCalledWith("/ensino/biblioteca?pasta=f1&item=i2");
  });

  it("migalhas: da biblioteca até a pasta, clicáveis", async () => {
    const navigate = renderAt("f2");
    await screen.findByText("Esta pasta está vazia.");
    const nav = screen.getByRole("navigation", {name: "Caminho"});
    expect(nav).toHaveTextContent("Biblioteca");
    expect(nav).toHaveTextContent("Crianças");
    fireEvent.click(screen.getByRole("button", {name: "Crianças"}));
    expect(navigate).toHaveBeenCalledWith("/ensino/biblioteca?pasta=f1");
    fireEvent.click(screen.getByRole("button", {name: "Biblioteca"}));
    expect(navigate).toHaveBeenCalledWith("/ensino/biblioteca");
  });

  it("a busca filtra todos os itens visíveis pelo nome, sem acento nem maiúscula", async () => {
    renderAt(null);
    await screen.findByText("Crianças");
    fireEvent.change(screen.getByLabelText("Buscar na biblioteca"), {target: {value: "AULA"}});
    expect(await screen.findByText("Aula 2")).toBeInTheDocument();
    expect(screen.getByText("Aula 10")).toBeInTheDocument();
    expect(screen.queryByText("Catecismo Menor")).not.toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Buscar na biblioteca"), {target: {value: "zzz"}});
    expect(await screen.findByText("Nada encontrado.")).toBeInTheDocument();
  });

  it("pasta inexistente ou sem acesso mostra aviso com volta para a raiz", async () => {
    const navigate = renderAt("fantasma");
    expect(await screen.findByText("Pasta não encontrada ou sem acesso.")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", {name: "Voltar para a biblioteca"}));
    expect(navigate).toHaveBeenCalledWith("/ensino/biblioteca");
  });

  it("erro ao carregar a pasta mostra alerta", async () => {
    repo.subscribeFolder.mockImplementation((_id, _viewer, _onData, onError) => {
      onError(new Error("permission-denied"));
      return unsubscribe;
    });
    renderAt(null);
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível carregar esta pasta.");
  });

  it("trocar de pasta cancela a escuta anterior e assina a nova", async () => {
    const {rerender} = render(<LibraryContent viewer={teacher} folderId="f1" itemId={null} navigate={vi.fn()} />);
    await screen.findByText("Aula 2");
    rerender(<LibraryContent viewer={teacher} folderId="f2" itemId={null} navigate={vi.fn()} />);
    await waitFor(() => expect(unsubscribe).toHaveBeenCalled());
    expect(repo.subscribeFolder).toHaveBeenLastCalledWith("f2", teacher, expect.any(Function), expect.any(Function));
    expect(await screen.findByText("Esta pasta está vazia.")).toBeInTheDocument();
  });

  it("alterna entre lista e grade", async () => {
    renderAt(null);
    await screen.findByText("Crianças");
    fireEvent.click(screen.getByRole("button", {name: "Ver em grade"}));
    expect(screen.getByTestId("folder-view")).toHaveAttribute("data-view", "grid");
    fireEvent.click(screen.getByRole("button", {name: "Ver em lista"}));
    expect(screen.getByTestId("folder-view")).toHaveAttribute("data-view", "list");
  });
});
```

- [ ] **Step 2: Rodar para ver falhar**

Run: `npm --prefix web-portal test -- url LibraryPage`
Expected: FAIL — `./url` e `./LibraryPage` não existem.

- [ ] **Step 3: Implementar**

Em `web-portal/src/modules/teaching/library/status.ts`, trocar a assinatura e o ramo final de `statusBadge`:

```ts
export function statusBadge(
  item: LibraryItem,
  approvals: number | null
): {label: string; tone: BadgeTone} {
  if (item.deleting) return {label: "Excluindo…", tone: "danger"};
  if (item.deleteRequest) return {label: "Exclusão solicitada", tone: "danger"};
  if (item.type === "folder") return {label: "", tone: "neutral"};
  if (item.status === "published") return {label: "Publicado", tone: "success"};
  if (item.status === "returned") return {label: "Devolvido", tone: "warning"};
  if (approvals === null) return {label: "Em revisão", tone: "info"};
  return {
    label: `Em revisão ${Math.min(approvals, REQUIRED_APPROVALS)}/${REQUIRED_APPROVALS}`,
    tone: "info",
  };
}
```

Criar `web-portal/src/modules/teaching/library/url.ts`:

```ts
export function libraryUrl(params: {
  pasta?: string | null;
  item?: string | null;
}): string {
  const parts: string[] = [];
  if (params.pasta) parts.push(`pasta=${encodeURIComponent(params.pasta)}`);
  if (params.item) parts.push(`item=${encodeURIComponent(params.item)}`);
  return parts.length > 0 ?
    `/ensino/biblioteca?${parts.join("&")}` :
    "/ensino/biblioteca";
}

export function readParams(search: {get(name: string): string | null}): {
  pasta: string | null;
  item: string | null;
} {
  return {pasta: search.get("pasta") || null, item: search.get("item") || null};
}
```

Criar `web-portal/src/modules/teaching/library/useLibrary.ts`:

```ts
"use client";

import {useEffect, useState} from "react";
import {loadAllVisible, subscribeFolder} from "./repository";
import type {LibraryItem, Viewer} from "./types";

// A chave descarta respostas de uma pasta anterior: só vale o que corresponde
// à pasta e ao espectador atuais.
export function useFolderItems(folderId: string | null, viewer: Viewer) {
  const key = `${viewer.uid}|${viewer.isCurator}|${viewer.isAdmin}|${folderId ?? "raiz"}`;
  const [state, setState] = useState<{
    key: string;
    items: LibraryItem[] | null;
    error: string | null;
  }>({key, items: null, error: null});

  useEffect(() => {
    return subscribeFolder(
      folderId,
      viewer,
      (items) => setState({key, items, error: null}),
      () => setState({key, items: null, error: "Não foi possível carregar esta pasta."})
    );
  }, [folderId, viewer, key]);

  return state.key === key ? state : {key, items: null, error: null};
}

// Todos os itens visíveis: migalhas, busca por nome e escolha de destino.
export function useCatalog(viewer: Viewer) {
  const [items, setItems] = useState<LibraryItem[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [round, setRound] = useState(0);

  useEffect(() => {
    let active = true;
    loadAllVisible(viewer)
      .then((list) => {
        if (!active) return;
        setItems(list);
        setError(null);
      })
      .catch(() => active && setError("Não foi possível carregar a biblioteca."));
    return () => {
      active = false;
    };
  }, [viewer, round]);

  return {items, error, reload: () => setRound((r) => r + 1)};
}
```

Criar `web-portal/src/modules/teaching/library/ui/StatusBadge.tsx`:

```tsx
import type {BadgeTone} from "../status";

const TONES: Record<BadgeTone, string> = {
  neutral: "bg-white/10",
  info: "bg-secondary/30",
  success: "bg-primary/50",
  warning: "bg-white/20 ring-1 ring-secondary/60",
  danger: "bg-error/20 text-error",
};

export function StatusBadge({badge}: {badge: {label: string; tone: BadgeTone}}) {
  if (!badge.label) return null;
  return (
    <span className={`rounded-button px-2 py-0.5 text-xs ${TONES[badge.tone]}`}>
      {badge.label}
    </span>
  );
}
```

Criar `web-portal/src/modules/teaching/library/ui/Breadcrumbs.tsx`:

```tsx
import {libraryUrl} from "../url";
import type {LibraryItem} from "../types";

export function Breadcrumbs({
  trail,
  onNavigate,
}: {
  trail: LibraryItem[];
  onNavigate: (url: string) => void;
}) {
  return (
    <nav aria-label="Caminho" className="flex flex-wrap items-center gap-1 text-sm">
      <button type="button" className="rounded-button px-2 py-1 hover:bg-white/10" onClick={() => onNavigate(libraryUrl({}))}>
        Biblioteca
      </button>
      {trail.map((folder) => (
        <span key={folder.id} className="flex items-center gap-1">
          <span aria-hidden className="text-white/40">/</span>
          <button type="button" className="rounded-button px-2 py-1 hover:bg-white/10" onClick={() => onNavigate(libraryUrl({pasta: folder.id}))}>
            {folder.name}
          </button>
        </span>
      ))}
    </nav>
  );
}
```

Criar `web-portal/src/modules/teaching/library/ui/ItemRow.tsx`:

```tsx
import type {BadgeTone} from "../status";
import type {LibraryItem} from "../types";
import {StatusBadge} from "./StatusBadge";

const ICONS = {folder: "📁", file: "📄", link: "🔗"} as const;

export function ItemRow({
  item,
  badge,
  view,
  onOpen,
  subtitle,
}: {
  item: LibraryItem;
  badge: {label: string; tone: BadgeTone};
  view: "list" | "grid";
  onOpen: () => void;
  subtitle?: string;
}) {
  const grid = view === "grid";
  return (
    <button
      type="button"
      aria-label={`Abrir ${item.name}`}
      onClick={onOpen}
      className={`rounded-card bg-surface-elevated text-left transition hover:brightness-125 ${
        grid ? "flex flex-col gap-2 p-4" : "flex w-full items-center gap-3 px-4 py-3"
      }`}
    >
      <span aria-hidden className={grid ? "text-3xl" : "text-xl"}>{ICONS[item.type]}</span>
      <span className="min-w-0 flex-1">
        <span className="block truncate font-medium">{item.name}</span>
        {subtitle && <span className="block truncate text-xs text-white/60">{subtitle}</span>}
      </span>
      <StatusBadge badge={badge} />
    </button>
  );
}
```

Criar `web-portal/src/modules/teaching/library/ui/FolderView.tsx`:

```tsx
import {statusBadge} from "../status";
import type {LibraryItem} from "../types";
import {ItemRow} from "./ItemRow";

export function FolderView({
  items,
  view,
  onOpen,
  emptyMessage,
  subtitleFor,
}: {
  items: LibraryItem[];
  view: "list" | "grid";
  onOpen: (item: LibraryItem) => void;
  emptyMessage: string;
  subtitleFor?: (item: LibraryItem) => string | undefined;
}) {
  if (items.length === 0) {
    return <p className="rounded-card bg-surface-elevated p-6 text-center text-white/70">{emptyMessage}</p>;
  }
  return (
    <div
      data-testid="folder-view"
      data-view={view}
      className={view === "grid" ? "grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-4" : "space-y-2"}
    >
      {items.map((item) => (
        <ItemRow
          key={item.id}
          item={item}
          badge={statusBadge(item, null)}
          view={view}
          subtitle={subtitleFor?.(item)}
          onOpen={() => onOpen(item)}
        />
      ))}
    </div>
  );
}
```

Criar `web-portal/src/modules/teaching/library/ui/LibraryPage.tsx`:

```tsx
"use client";

import {useRouter, useSearchParams} from "next/navigation";
import {useMemo, useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {Button} from "@/core/ui/Button";
import {TextField} from "@/core/ui/TextField";
import {sortItems, buildBreadcrumbs, filterByName, indexById} from "../tree";
import type {LibraryItem, Viewer} from "../types";
import {viewerFrom} from "../types";
import {useCatalog, useFolderItems} from "../useLibrary";
import {libraryUrl, readParams} from "../url";
import {Breadcrumbs} from "./Breadcrumbs";
import {FolderView} from "./FolderView";

export function LibraryContent({
  viewer,
  folderId,
  itemId,
  navigate,
}: {
  viewer: Viewer;
  folderId: string | null;
  itemId: string | null;
  navigate: (url: string) => void;
}) {
  const [view, setView] = useState<"list" | "grid">("list");
  const [search, setSearch] = useState("");
  const catalog = useCatalog(viewer);
  const folder = useFolderItems(folderId, viewer);

  const byId = useMemo(() => indexById(catalog.items ?? []), [catalog.items]);
  const trail = buildBreadcrumbs(byId, folderId);
  const missingFolder =
    folderId !== null && catalog.items !== null && !byId.has(folderId);
  const searching = search.trim().length > 0;

  const shown = searching ?
    sortItems(filterByName(catalog.items ?? [], search)) :
    sortItems(folder.items ?? []);

  function open(item: LibraryItem) {
    if (item.type === "folder") {
      navigate(libraryUrl({pasta: item.id}));
    } else {
      navigate(libraryUrl({pasta: item.parentId, item: item.id}));
    }
  }

  function pathOf(item: LibraryItem): string | undefined {
    const names = buildBreadcrumbs(byId, item.parentId).map((f) => f.name);
    return names.length > 0 ? names.join(" / ") : "Biblioteca";
  }

  if (missingFolder) {
    return (
      <div className="space-y-4">
        <p className="rounded-card bg-surface-elevated p-6">Pasta não encontrada ou sem acesso.</p>
        <Button type="button" onClick={() => navigate(libraryUrl({}))}>Voltar para a biblioteca</Button>
      </div>
    );
  }

  const error = folder.error ?? catalog.error;
  const loading = !searching && folder.items === null && !folder.error;

  return (
    <div className="space-y-4" data-item={itemId ?? undefined}>
      <h1 className="text-2xl font-semibold">Biblioteca</h1>
      <Breadcrumbs trail={trail} onNavigate={navigate} />
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-[14rem] flex-1">
          <TextField id="library-search" label="Buscar na biblioteca" value={search} onChange={(e) => setSearch(e.target.value)} />
        </div>
        <div className="flex gap-2">
          <Button type="button" variant="text" onClick={() => setView("list")}>Ver em lista</Button>
          <Button type="button" variant="text" onClick={() => setView("grid")}>Ver em grade</Button>
        </div>
      </div>
      {error && <p role="alert" className="text-sm text-error">{error}</p>}
      {loading ? (
        <p className="text-white/70">Carregando…</p>
      ) : (
        <FolderView
          items={shown}
          view={view}
          onOpen={open}
          subtitleFor={searching ? pathOf : undefined}
          emptyMessage={searching ? "Nada encontrado." : "Esta pasta está vazia."}
        />
      )}
    </div>
  );
}

export default function LibraryPage() {
  const {state} = useAuth();
  const router = useRouter();
  const params = readParams(useSearchParams());
  const viewer = useMemo(
    () => (state.status === "signedIn" ? viewerFrom(state.user.uid, state.claims) : null),
    [state]
  );
  if (!viewer) return null;
  return (
    <LibraryContent
      viewer={viewer}
      folderId={params.pasta}
      itemId={params.item}
      navigate={(url) => router.push(url)}
    />
  );
}
```

Criar `web-portal/src/app/(portal)/ensino/biblioteca/page.tsx` (o `useSearchParams` exige `Suspense` na página estática):

```tsx
import {Suspense} from "react";
import LibraryPage from "@/modules/teaching/library/ui/LibraryPage";

export default function Page() {
  return (
    <Suspense fallback={<p className="text-white/70">Carregando…</p>}>
      <LibraryPage />
    </Suspense>
  );
}
```

Em `web-portal/src/modules/teaching/module.ts`, acrescentar o item de menu entre "Início" e "Grupo de professores":

```ts
    {label: "Biblioteca", href: "/ensino/biblioteca", access: "teacher"},
```

Em `web-portal/src/modules/teaching/pages/TeachingHomePage.tsx`, trocar o cartão "Biblioteca de materiais" (texto "Em breve: aulas, planos e bibliografia por faixa etária.") por um cartão com link:

```tsx
      <Card>
        <h2 className="font-semibold">Biblioteca de materiais</h2>
        <p className="mb-2 text-sm text-white/70">Aulas, planos e bibliografia, organizados em pastas.</p>
        <Link href="/ensino/biblioteca" className="text-secondary underline">
          Abrir a biblioteca
        </Link>
      </Card>
```

(`Link` já está importado nesse arquivo.)

- [ ] **Step 4: Rodar testes, lint, tipos e build**

Run (um por vez): `npm --prefix web-portal test`, `npm --prefix web-portal run lint`, `npm --prefix web-portal run typecheck`, `npm --prefix web-portal run build`
Expected: PASS; o build lista a rota `/ensino/biblioteca`. Se o `build` reclamar de `useSearchParams` sem `Suspense` ou de `cacheComponents`, mantenha o `Suspense` da página e, só se persistir, desligue `cacheComponents` em `web-portal/next.config.ts` e relate.
Atualize também `status.test.ts` (Task 1) acrescentando um caso: `statusBadge(item(), null)` → `{label: "Em revisão", tone: "info"}`.

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add web-portal/src
/usr/bin/git commit -m "feat(web-portal): página da biblioteca (pastas, busca, lista e grade)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Criar pastas e links, enviar arquivos, renomear e mover

**Files:**
- Create: `web-portal/src/modules/teaching/library/ui/Dialog.tsx`, `ui/Dialogs.tsx`, `ui/UploadPanel.tsx`
- Modify: `web-portal/src/modules/teaching/library/ui/LibraryPage.tsx`
- Test: `web-portal/src/modules/teaching/library/ui/Dialogs.test.tsx`, `ui/UploadPanel.test.tsx`; acrescentar casos a `ui/LibraryPage.test.tsx`

**Interfaces:**
- Consumes: Tasks 1 a 4 (`libraryPermissions`, `validateName`, `validateUrl`, `createFolder`, `createLink`, `uploadFile`, `renameItem`, `moveItem` de `../mutations`, `useCatalog().reload`).
- Produces (usados na Task 6):
  - `<Dialog title onClose>` (modal acessível: `role="dialog"`, `aria-modal`, fecha com Escape e clique no fundo).
  - `<TextPromptDialog title label initial? submitLabel validate onSubmit onClose />` (`validate(value: string): string | null`, `onSubmit(value: string): Promise<void>`; mostra o erro de validação e o erro do envio; desabilita enquanto grava).
  - `<LinkDialog title? initial? submitLabel onSubmit onClose />` (`onSubmit({name, url, description}: {name: string; url: string; description: string}): Promise<void>`).
  - `<ReasonDialog title label required submitLabel onSubmit onClose />` (`onSubmit(text: string): Promise<void>`; com `required`, recusa vazio e acima de 1000 caracteres).
  - `<MoveDialog item folders={LibraryItem[]} byId onPick onClose />` (`onPick(parentId: string | null): Promise<void>`; lista as pastas válidas, nunca a própria pasta nem descendentes, com a raiz).
  - `<UploadPanel uid parentId onUploaded />` (botão "Enviar arquivos", área de arrastar e soltar, fila com barra de progresso e erros por arquivo).
  - `eligibleTargets(item: LibraryItem, folders: LibraryItem[], byId: Map<string, LibraryItem>): LibraryItem[]` (em `Dialogs.tsx`).

- [ ] **Step 1: Escrever os testes (que vão falhar)**

Criar `web-portal/src/modules/teaching/library/ui/Dialogs.test.tsx`:

```tsx
import {fireEvent, render, screen, waitFor} from "@testing-library/react";
import {describe, expect, it, vi} from "vitest";
import {indexById} from "../tree";
import type {LibraryItem} from "../types";
import {LinkDialog, MoveDialog, ReasonDialog, TextPromptDialog, eligibleTargets} from "./Dialogs";

describe("TextPromptDialog", () => {
  const setup = (onSubmit = vi.fn().mockResolvedValue(undefined)) => {
    const onClose = vi.fn();
    render(<TextPromptDialog title="Nova pasta" label="Nome da pasta" submitLabel="Criar" validate={(v) => (v.trim() ? null : "Informe um nome.")} onSubmit={onSubmit} onClose={onClose} />);
    return {onSubmit, onClose};
  };

  it("envia o valor e fecha", async () => {
    const {onSubmit, onClose} = setup();
    fireEvent.change(screen.getByLabelText("Nome da pasta"), {target: {value: "  Crianças "}});
    fireEvent.click(screen.getByRole("button", {name: "Criar"}));
    await waitFor(() => expect(onSubmit).toHaveBeenCalledWith("  Crianças "));
    await waitFor(() => expect(onClose).toHaveBeenCalled());
  });

  it("mostra o erro de validação e não envia", () => {
    const {onSubmit} = setup();
    fireEvent.click(screen.getByRole("button", {name: "Criar"}));
    expect(screen.getByRole("alert")).toHaveTextContent("Informe um nome.");
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it("mostra o erro do envio e mantém o diálogo aberto", async () => {
    const {onClose} = setup(vi.fn().mockRejectedValue(new Error("permission-denied")));
    fireEvent.change(screen.getByLabelText("Nome da pasta"), {target: {value: "A"}});
    fireEvent.click(screen.getByRole("button", {name: "Criar"}));
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível concluir. Tente novamente.");
    expect(onClose).not.toHaveBeenCalled();
  });

  it("Escape fecha", () => {
    const {onClose} = setup();
    fireEvent.keyDown(window, {key: "Escape"});
    expect(onClose).toHaveBeenCalled();
  });
});

describe("LinkDialog", () => {
  it("valida nome e endereço antes de enviar", async () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined);
    render(<LinkDialog submitLabel="Adicionar" onSubmit={onSubmit} onClose={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", {name: "Adicionar"}));
    expect(screen.getByRole("alert")).toHaveTextContent("Informe um nome.");
    fireEvent.change(screen.getByLabelText("Nome"), {target: {value: "Livro"}});
    fireEvent.change(screen.getByLabelText("Endereço (URL)"), {target: {value: "ftp://x"}});
    fireEvent.click(screen.getByRole("button", {name: "Adicionar"}));
    expect(screen.getByRole("alert")).toHaveTextContent("Use um endereço que comece com http:// ou https://.");
    fireEvent.change(screen.getByLabelText("Endereço (URL)"), {target: {value: "https://x.org"}});
    fireEvent.change(screen.getByLabelText("Descrição (opcional)"), {target: {value: "Bom livro"}});
    fireEvent.click(screen.getByRole("button", {name: "Adicionar"}));
    await waitFor(() => expect(onSubmit).toHaveBeenCalledWith({name: "Livro", url: "https://x.org", description: "Bom livro"}));
  });
});

describe("ReasonDialog", () => {
  it("obrigatório recusa vazio e texto longo demais", async () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined);
    render(<ReasonDialog title="Devolver" label="Comentário" required submitLabel="Devolver" onSubmit={onSubmit} onClose={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", {name: "Devolver"}));
    expect(screen.getByRole("alert")).toHaveTextContent("Escreva um comentário.");
    fireEvent.change(screen.getByLabelText("Comentário"), {target: {value: "x".repeat(1001)}});
    fireEvent.click(screen.getByRole("button", {name: "Devolver"}));
    expect(screen.getByRole("alert")).toHaveTextContent("O comentário pode ter no máximo 1000 caracteres.");
    fireEvent.change(screen.getByLabelText("Comentário"), {target: {value: "Falta a referência"}});
    fireEvent.click(screen.getByRole("button", {name: "Devolver"}));
    await waitFor(() => expect(onSubmit).toHaveBeenCalledWith("Falta a referência"));
  });

  it("opcional aceita vazio", async () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined);
    render(<ReasonDialog title="Pedir exclusão" label="Motivo (opcional)" submitLabel="Pedir exclusão" onSubmit={onSubmit} onClose={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", {name: "Pedir exclusão"}));
    await waitFor(() => expect(onSubmit).toHaveBeenCalledWith(""));
  });
});

describe("eligibleTargets e MoveDialog", () => {
  const f = (id: string, name: string, parentId: string | null = null): LibraryItem => ({
    id, name, type: "folder", parentId, authorId: "c1", status: "active", version: 1,
  });
  const folders = [f("A", "Crianças"), f("B", "Antigo", "A"), f("C", "Gênesis", "B"), f("D", "Jovens")];
  const byId = indexById(folders);

  it("não oferece a própria pasta nem descendentes", () => {
    expect(eligibleTargets(folders[0], folders, byId).map((i) => i.id)).toEqual(["D"]);
    expect(eligibleTargets(folders[1], folders, byId).map((i) => i.id)).toEqual(["A", "D"]);
  });

  it("arquivo pode ir para qualquer pasta", () => {
    const file: LibraryItem = {id: "x", name: "Aula", type: "file", parentId: "A", authorId: "t", status: "published", version: 1};
    expect(eligibleTargets(file, folders, byId).map((i) => i.id)).toEqual(["A", "B", "C", "D"]);
  });

  it("MoveDialog lista a raiz e as pastas e devolve a escolha", async () => {
    const onPick = vi.fn().mockResolvedValue(undefined);
    render(<MoveDialog item={folders[2]} folders={folders} byId={byId} onPick={onPick} onClose={vi.fn()} />);
    fireEvent.click(screen.getByRole("button", {name: "Biblioteca (raiz)"}));
    await waitFor(() => expect(onPick).toHaveBeenCalledWith(null));
    fireEvent.click(screen.getByRole("button", {name: "Crianças / Antigo"}));
    await waitFor(() => expect(onPick).toHaveBeenCalledWith("B"));
  });
});
```

Criar `web-portal/src/modules/teaching/library/ui/UploadPanel.test.tsx`:

```tsx
import {fireEvent, render, screen, waitFor} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {UploadError} from "../uploadFlow";
import {UploadPanel} from "./UploadPanel";

const mutations = vi.hoisted(() => ({uploadFile: vi.fn()}));
vi.mock("../mutations", () => mutations);

const pdf = (name: string) => new File(["x"], name, {type: "application/pdf"});

beforeEach(() => {
  mutations.uploadFile.mockReset().mockImplementation(async (_uid, _parent, _file, onProgress) => {
    onProgress?.(0.5);
    onProgress?.(1);
    return "id";
  });
});

describe("UploadPanel", () => {
  it("envia os arquivos escolhidos, mostra concluído e avisa a tela", async () => {
    const onUploaded = vi.fn();
    render(<UploadPanel uid="t1" parentId="f1" onUploaded={onUploaded} />);
    fireEvent.change(screen.getByLabelText("Escolher arquivos"), {target: {files: [pdf("a.pdf"), pdf("b.pdf")]}});
    await waitFor(() => expect(screen.getAllByText("Enviado")).toHaveLength(2));
    expect(mutations.uploadFile).toHaveBeenCalledTimes(2);
    expect(mutations.uploadFile.mock.calls[0].slice(0, 3)).toEqual(["t1", "f1", expect.any(File)]);
    expect(onUploaded).toHaveBeenCalled();
  });

  it("arrastar e soltar também envia", async () => {
    render(<UploadPanel uid="t1" parentId={null} onUploaded={vi.fn()} />);
    fireEvent.drop(screen.getByTestId("drop-zone"), {dataTransfer: {files: [pdf("c.pdf")]}});
    await waitFor(() => expect(screen.getByText("Enviado")).toBeInTheDocument());
  });

  it("falha de um arquivo mostra o motivo e não impede os outros", async () => {
    mutations.uploadFile.mockImplementationOnce(async () => {
      throw new UploadError("validate", "O arquivo passa de 100 MB.");
    });
    render(<UploadPanel uid="t1" parentId={null} onUploaded={vi.fn()} />);
    fireEvent.change(screen.getByLabelText("Escolher arquivos"), {target: {files: [pdf("grande.pdf"), pdf("ok.pdf")]}});
    expect(await screen.findByText("O arquivo passa de 100 MB.")).toBeInTheDocument();
    await waitFor(() => expect(screen.getByText("Enviado")).toBeInTheDocument());
  });

  it("erro inesperado mostra mensagem genérica", async () => {
    mutations.uploadFile.mockRejectedValueOnce(new Error("boom"));
    render(<UploadPanel uid="t1" parentId={null} onUploaded={vi.fn()} />);
    fireEvent.change(screen.getByLabelText("Escolher arquivos"), {target: {files: [pdf("a.pdf")]}});
    expect(await screen.findByText("Não foi possível enviar o arquivo. Tente novamente.")).toBeInTheDocument();
  });
});
```

Acrescentar a `web-portal/src/modules/teaching/library/ui/LibraryPage.test.tsx` (mantendo os mocks existentes; adicionar `vi.mock("../mutations", ...)` com `vi.hoisted` e `uid` no `Viewer`): casos "professor não vê o botão Nova pasta; curador vê", "Nova pasta chama `createFolder(uid, nome, pastaAtual)` e recarrega o catálogo", "Adicionar link chama `createLink` com os dados" e "painel de envio aparece para todos". Use, por exemplo, `const mutations = vi.hoisted(() => ({createFolder: vi.fn(), createLink: vi.fn(), uploadFile: vi.fn(), renameItem: vi.fn(), moveItem: vi.fn()}))` e `vi.mock("../mutations", () => mutations)`.

- [ ] **Step 2: Rodar para ver falhar**

Run: `npm --prefix web-portal test -- Dialogs UploadPanel LibraryPage`
Expected: FAIL — `./Dialogs`, `./UploadPanel` não existem e os novos casos da página falham.

- [ ] **Step 3: Implementar**

Criar `web-portal/src/modules/teaching/library/ui/Dialog.tsx`:

```tsx
"use client";

import {useEffect, type ReactNode} from "react";

export function Dialog({
  title,
  onClose,
  children,
}: {
  title: string;
  onClose: () => void;
  children: ReactNode;
}) {
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div role="dialog" aria-modal="true" aria-label={title} className="w-full max-w-md rounded-dialog bg-surface p-6 shadow-xl">
        <h2 className="mb-4 text-lg font-semibold">{title}</h2>
        {children}
      </div>
    </div>
  );
}
```

Criar `web-portal/src/modules/teaching/library/ui/Dialogs.tsx`:

```tsx
"use client";

import {useState, type FormEvent, type ReactNode} from "react";
import {Button} from "@/core/ui/Button";
import {TextField} from "@/core/ui/TextField";
import {validateName, validateUrl} from "../files";
import {buildBreadcrumbs} from "../tree";
import type {LibraryItem} from "../types";
import {Dialog} from "./Dialog";

const GENERIC_ERROR = "Não foi possível concluir. Tente novamente.";

// Estado comum: erro de validação, erro de envio e "ocupado".
function useSubmit(onClose: () => void) {
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  async function run(problem: string | null, action: () => Promise<void>) {
    if (problem) {
      setError(problem);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await action();
      onClose();
    } catch {
      setError(GENERIC_ERROR);
      setBusy(false);
    }
  }
  return {error, busy, run};
}

function Actions({busy, submitLabel, onClose}: {busy: boolean; submitLabel: string; onClose: () => void}) {
  return (
    <div className="mt-4 flex justify-end gap-2">
      <Button type="button" variant="text" onClick={onClose}>Cancelar</Button>
      <Button type="submit" disabled={busy}>{submitLabel}</Button>
    </div>
  );
}

function ErrorLine({error}: {error: string | null}) {
  return error ? <p role="alert" className="mt-2 text-sm text-error">{error}</p> : null;
}

export function TextPromptDialog({
  title, label, initial = "", submitLabel, validate, onSubmit, onClose,
}: {
  title: string;
  label: string;
  initial?: string;
  submitLabel: string;
  validate: (value: string) => string | null;
  onSubmit: (value: string) => Promise<void>;
  onClose: () => void;
}) {
  const [value, setValue] = useState(initial);
  const {error, busy, run} = useSubmit(onClose);
  return (
    <Dialog title={title} onClose={onClose}>
      <form onSubmit={(e: FormEvent) => {
        e.preventDefault();
        void run(validate(value), () => onSubmit(value));
      }}>
        <TextField id="prompt-value" label={label} value={value} onChange={(e) => setValue(e.target.value)} autoFocus />
        <ErrorLine error={error} />
        <Actions busy={busy} submitLabel={submitLabel} onClose={onClose} />
      </form>
    </Dialog>
  );
}

export function LinkDialog({
  title = "Adicionar link", initial, submitLabel, onSubmit, onClose,
}: {
  title?: string;
  initial?: {name: string; url: string; description: string};
  submitLabel: string;
  onSubmit: (value: {name: string; url: string; description: string}) => Promise<void>;
  onClose: () => void;
}) {
  const [name, setName] = useState(initial?.name ?? "");
  const [url, setUrl] = useState(initial?.url ?? "");
  const [description, setDescription] = useState(initial?.description ?? "");
  const {error, busy, run} = useSubmit(onClose);
  return (
    <Dialog title={title} onClose={onClose}>
      <form className="space-y-3" onSubmit={(e: FormEvent) => {
        e.preventDefault();
        void run(validateName(name) ?? validateUrl(url), () => onSubmit({name, url, description}));
      }}>
        <TextField id="link-name" label="Nome" value={name} onChange={(e) => setName(e.target.value)} autoFocus />
        <TextField id="link-url" label="Endereço (URL)" value={url} onChange={(e) => setUrl(e.target.value)} />
        <TextField id="link-description" label="Descrição (opcional)" value={description} onChange={(e) => setDescription(e.target.value)} />
        <ErrorLine error={error} />
        <Actions busy={busy} submitLabel={submitLabel} onClose={onClose} />
      </form>
    </Dialog>
  );
}

export function ReasonDialog({
  title, label, required = false, submitLabel, onSubmit, onClose,
}: {
  title: string;
  label: string;
  required?: boolean;
  submitLabel: string;
  onSubmit: (text: string) => Promise<void>;
  onClose: () => void;
}) {
  const [text, setText] = useState("");
  const {error, busy, run} = useSubmit(onClose);
  function problem(): string | null {
    const size = text.trim().length;
    if (required && size === 0) return "Escreva um comentário.";
    if (size > 1000) return "O comentário pode ter no máximo 1000 caracteres.";
    return null;
  }
  return (
    <Dialog title={title} onClose={onClose}>
      <form onSubmit={(e: FormEvent) => {
        e.preventDefault();
        void run(problem(), () => onSubmit(text));
      }}>
        <label htmlFor="reason-text" className="block text-sm text-white/70">
          {label}
          <textarea id="reason-text" rows={4} value={text} onChange={(e) => setText(e.target.value)}
            className="mt-1 block w-full rounded-input border border-white/5 bg-surface-elevated/80 px-4 py-3 text-base text-on-surface focus:border-primary focus:outline-none" />
        </label>
        <ErrorLine error={error} />
        <Actions busy={busy} submitLabel={submitLabel} onClose={onClose} />
      </form>
    </Dialog>
  );
}

// Pastas para onde o item pode ir: nunca ele mesmo nem seus descendentes.
export function eligibleTargets(
  item: LibraryItem,
  folders: LibraryItem[],
  byId: Map<string, LibraryItem>
): LibraryItem[] {
  return folders.filter((folder) => {
    if (folder.id === item.id) return false;
    if (item.type !== "folder") return true;
    return !buildBreadcrumbs(byId, folder.id).some((p) => p.id === item.id);
  });
}

export function MoveDialog({
  item, folders, byId, onPick, onClose,
}: {
  item: LibraryItem;
  folders: LibraryItem[];
  byId: Map<string, LibraryItem>;
  onPick: (parentId: string | null) => Promise<void>;
  onClose: () => void;
}) {
  const {error, busy, run} = useSubmit(onClose);
  const targets = eligibleTargets(item, folders, byId);
  const pathOf = (folder: LibraryItem) => buildBreadcrumbs(byId, folder.id).map((p) => p.name).join(" / ");
  const choice = (label: ReactNode, parentId: string | null, key: string) => (
    <li key={key}>
      <button type="button" disabled={busy} onClick={() => void run(null, () => onPick(parentId))}
        className="w-full rounded-button px-3 py-2 text-left hover:bg-white/10 disabled:opacity-50">
        {label}
      </button>
    </li>
  );
  return (
    <Dialog title={`Mover "${item.name}"`} onClose={onClose}>
      <ul className="max-h-72 space-y-1 overflow-y-auto">
        {choice("Biblioteca (raiz)", null, "raiz")}
        {targets.map((folder) => choice(pathOf(folder), folder.id, folder.id))}
      </ul>
      <ErrorLine error={error} />
      <div className="mt-4 flex justify-end">
        <Button type="button" variant="text" onClick={onClose}>Cancelar</Button>
      </div>
    </Dialog>
  );
}
```

Criar `web-portal/src/modules/teaching/library/ui/UploadPanel.tsx`:

```tsx
"use client";

import {useRef, useState, type DragEvent} from "react";
import {Button} from "@/core/ui/Button";
import {uploadFile} from "../mutations";
import {UploadError} from "../uploadFlow";

interface Entry {
  key: number;
  name: string;
  progress: number;
  status: "uploading" | "done" | "error";
  message?: string;
}

export function UploadPanel({
  uid,
  parentId,
  onUploaded,
}: {
  uid: string;
  parentId: string | null;
  onUploaded: () => void;
}) {
  const [entries, setEntries] = useState<Entry[]>([]);
  const counter = useRef(0);
  const input = useRef<HTMLInputElement>(null);

  function patch(key: number, changes: Partial<Entry>) {
    setEntries((list) => list.map((e) => (e.key === key ? {...e, ...changes} : e)));
  }

  async function start(files: File[]) {
    for (const file of files) {
      const key = counter.current++;
      setEntries((list) => [...list, {key, name: file.name, progress: 0, status: "uploading"}]);
      try {
        await uploadFile(uid, parentId, file, (progress) => patch(key, {progress}));
        patch(key, {status: "done", progress: 1});
        onUploaded();
      } catch (error) {
        const message = error instanceof UploadError ?
          error.message :
          "Não foi possível enviar o arquivo. Tente novamente.";
        patch(key, {status: "error", message});
      }
    }
  }

  function onDrop(event: DragEvent) {
    event.preventDefault();
    void start(Array.from(event.dataTransfer?.files ?? []));
  }

  return (
    <div className="space-y-2">
      <div
        data-testid="drop-zone"
        onDragOver={(e) => e.preventDefault()}
        onDrop={onDrop}
        className="rounded-card border border-dashed border-white/20 p-4 text-center text-sm text-white/70"
      >
        Arraste arquivos aqui (PDF, Office ou imagem, até 100 MB) ou{" "}
        <Button type="button" variant="text" className="px-1 py-0" onClick={() => input.current?.click()}>
          Enviar arquivos
        </Button>
        <input
          ref={input}
          type="file"
          multiple
          aria-label="Escolher arquivos"
          className="hidden"
          onChange={(e) => {
            void start(Array.from(e.target.files ?? []));
            e.target.value = "";
          }}
        />
      </div>
      {entries.length > 0 && (
        <ul className="space-y-1">
          {entries.map((entry) => (
            <li key={entry.key} className="rounded-card bg-surface-elevated px-3 py-2 text-sm">
              <div className="flex items-center justify-between gap-2">
                <span className="truncate">{entry.name}</span>
                <span className={entry.status === "error" ? "text-error" : "text-white/70"}>
                  {entry.status === "uploading" && `${Math.round(entry.progress * 100)}%`}
                  {entry.status === "done" && "Enviado"}
                  {entry.status === "error" && entry.message}
                </span>
              </div>
              {entry.status === "uploading" && <progress className="mt-1 w-full" value={entry.progress} max={1} />}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
```

Em `ui/LibraryPage.tsx` (`LibraryContent`), acrescentar: imports de `libraryPermissions`, `createFolder`, `createLink`, `TextPromptDialog`, `LinkDialog`, `UploadPanel`, `validateName`; estado `dialog: "folder" | "link" | null`; depois do campo de busca, uma barra de ações:

```tsx
  const permissions = libraryPermissions(viewer);
  // ...
      <div className="flex flex-wrap gap-2">
        {permissions.canCreateFolder && (
          <Button type="button" onClick={() => setDialog("folder")}>Nova pasta</Button>
        )}
        {permissions.canAddLink && (
          <Button type="button" variant="text" onClick={() => setDialog("link")}>Adicionar link</Button>
        )}
      </div>
      <UploadPanel uid={viewer.uid} parentId={folderId} onUploaded={catalog.reload} />
      {dialog === "folder" && (
        <TextPromptDialog title="Nova pasta" label="Nome da pasta" submitLabel="Criar" validate={validateName}
          onSubmit={async (name) => { await createFolder(viewer.uid, name, folderId); catalog.reload(); }}
          onClose={() => setDialog(null)} />
      )}
      {dialog === "link" && (
        <LinkDialog submitLabel="Adicionar"
          onSubmit={async (value) => { await createLink(viewer.uid, {...value, parentId: folderId}); catalog.reload(); }}
          onClose={() => setDialog(null)} />
      )}
```

Observações: pasta e link criados por curador/professor aparecem na pasta atual pela escuta em tempo real; `catalog.reload()` mantém migalhas, busca e seletor de destino atualizados. Um envio por professor nasce "Em revisão" e aparece para ele pela consulta `authorId == uid`.

- [ ] **Step 4: Rodar testes, lint, tipos e build**

Run (um por vez): `npm --prefix web-portal test`, `npm --prefix web-portal run lint`, `npm --prefix web-portal run typecheck`, `npm --prefix web-portal run build`
Expected: PASS. (Renomear e mover são ligados na Task 6, no detalhe do item; aqui só ficam prontos os diálogos.)

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add web-portal/src
/usr/bin/git commit -m "feat(web-portal): criar pastas e links, enviar arquivos e diálogos da biblioteca

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Detalhe do item (visualização, histórico de votos e ações de curadoria)

**Files:**
- Create: `web-portal/src/modules/teaching/library/preview.ts`, `labels.ts`, `storageAccess.ts`, `useItemDetail.ts`, `ui/ItemDetail.tsx`
- Modify: `web-portal/src/modules/teaching/library/ui/LibraryPage.tsx` (abrir o detalhe com `?item=`)
- Test: `web-portal/src/modules/teaching/library/preview.test.ts`, `labels.test.ts`, `ui/ItemDetail.test.tsx`; acrescentar casos a `ui/LibraryPage.test.tsx`

**Interfaces:**
- Consumes: Tasks 1 a 5 (`itemPermissions`, `countApprovals`, `countDeleteApprovals`, `statusBadge`, `subscribeItem`, `subscribeVotes`, `canReadVotes`, `loadUserNames`, `castVote`, `requestDelete`, `cancelDelete`, `renameItem`, `moveItem`, `resubmitFile`, `resubmitLink`, `ReasonDialog`, `TextPromptDialog`, `MoveDialog`, `LinkDialog`).
- Produces (usados na Task 7):
  - `previewKind(contentType: string | undefined): "pdf" | "image" | "other"`.
  - `voteLabel(action: VoteAction): string`, `formatDateTime(ms: number): string`.
  - `downloadUrl(storagePath: string): Promise<string>` (`storageAccess.ts`, usa `getDownloadURL`).
  - `useItemDetail(itemId: string, viewer: Viewer): {item: LibraryItem | null | undefined; error: string | null; votes: LibraryVote[]; names: Record<string, string>; fileUrl: string | null; fileUrlError: boolean}` (`item === undefined` enquanto carrega; `null` quando não existe ou sem acesso).
  - `<ItemDetail itemId viewer folders byId onClose={(parentId: string | null) => void} onChanged={() => void} />`.

- [ ] **Step 1: Escrever os testes (que vão falhar)**

Criar `web-portal/src/modules/teaching/library/preview.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {previewKind} from "./preview";

describe("previewKind", () => {
  it("PDF e imagens têm visualização; o resto não", () => {
    expect(previewKind("application/pdf")).toBe("pdf");
    expect(previewKind("image/png")).toBe("image");
    expect(previewKind("image/jpeg")).toBe("image");
    expect(previewKind("application/vnd.openxmlformats-officedocument.wordprocessingml.document")).toBe("other");
    expect(previewKind(undefined)).toBe("other");
  });
});
```

Criar `web-portal/src/modules/teaching/library/labels.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {formatDateTime, voteLabel} from "./labels";

describe("voteLabel", () => {
  it("rótulos em pt-BR para cada ação", () => {
    expect(voteLabel("approve")).toBe("Aprovou");
    expect(voteLabel("reject")).toBe("Rejeitou");
    expect(voteLabel("return")).toBe("Devolveu");
    expect(voteLabel("delete_approve")).toBe("Aprovou a exclusão");
    expect(voteLabel("delete_refuse")).toBe("Recusou a exclusão");
  });
});

describe("formatDateTime", () => {
  it("devolve um texto não vazio e traço para tempo zero", () => {
    expect(formatDateTime(1_700_000_000_000).length).toBeGreaterThan(5);
    expect(formatDateTime(0)).toBe("—");
  });
});
```

Criar `web-portal/src/modules/teaching/library/ui/ItemDetail.test.tsx`:

```tsx
import {act, fireEvent, render, screen, waitFor} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {indexById} from "../tree";
import type {LibraryItem, LibraryVote, Viewer} from "../types";
import {ItemDetail} from "./ItemDetail";

const repo = vi.hoisted(() => ({
  subscribeItem: vi.fn(),
  subscribeVotes: vi.fn(),
  loadUserNames: vi.fn(),
  canReadVotes: vi.fn(),
}));
const mutations = vi.hoisted(() => ({
  castVote: vi.fn(), requestDelete: vi.fn(), cancelDelete: vi.fn(), renameItem: vi.fn(),
  moveItem: vi.fn(), resubmitFile: vi.fn(), resubmitLink: vi.fn(),
}));
const storageAccess = vi.hoisted(() => ({downloadUrl: vi.fn()}));
vi.mock("../repository", () => repo);
vi.mock("../mutations", () => mutations);
vi.mock("../storageAccess", () => storageAccess);

const curator1: Viewer = {uid: "c1", isCurator: true, isAdmin: false};
const curator2: Viewer = {uid: "c2", isCurator: true, isAdmin: false};
const teacher: Viewer = {uid: "t1", isCurator: false, isAdmin: false};
const other: Viewer = {uid: "t2", isCurator: false, isAdmin: false};

const file = (extra: Partial<LibraryItem> = {}): LibraryItem => ({
  id: "i1", type: "file", name: "Aula 1", parentId: "f1", authorId: "t1", status: "in_review", version: 1,
  fileName: "aula.pdf", contentType: "application/pdf", size: 2048, storagePath: "teaching/materials/i1/v1-aula.pdf", ...extra,
});
const folders: LibraryItem[] = [{id: "f1", name: "Crianças", type: "folder", parentId: null, authorId: "c1", status: "active", version: 1}];

let current: LibraryItem | null;
let votes: LibraryVote[];

function setup(viewer: Viewer, item: LibraryItem | null = file(), itemVotes: LibraryVote[] = []) {
  current = item;
  votes = itemVotes;
  repo.canReadVotes.mockImplementation((i: LibraryItem, v: Viewer) => v.isCurator || v.isAdmin || i.authorId === v.uid);
  repo.subscribeItem.mockImplementation((_id, onData) => {
    onData(current);
    return vi.fn();
  });
  repo.subscribeVotes.mockImplementation((_id, onData) => {
    onData(votes);
    return vi.fn();
  });
  repo.loadUserNames.mockResolvedValue({c1: "Ana Curadora", c2: "Beto Curador"});
  storageAccess.downloadUrl.mockResolvedValue("https://files.example/aula.pdf");
  const onClose = vi.fn();
  const onChanged = vi.fn();
  render(<ItemDetail itemId="i1" viewer={viewer} folders={folders} byId={indexById(folders)} onClose={onClose} onChanged={onChanged} />);
  return {onClose, onChanged};
}

beforeEach(() => {
  for (const fn of [...Object.values(repo), ...Object.values(mutations), ...Object.values(storageAccess)]) fn.mockReset();
  for (const fn of Object.values(mutations)) fn.mockResolvedValue(undefined);
});

describe("ItemDetail — votos de publicação", () => {
  it("curador que não é o autor vê Aprovar, Devolver e Rejeitar e aprova", async () => {
    setup(curator2);
    expect(await screen.findByText("Aula 1")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", {name: "Aprovar"}));
    await waitFor(() => expect(mutations.castVote).toHaveBeenCalledWith("c2", expect.objectContaining({id: "i1"}), "approve", undefined));
    expect(await screen.findByRole("status")).toHaveTextContent("Voto registrado.");
  });

  it("devolver exige comentário e envia o texto", async () => {
    setup(curator2);
    fireEvent.click(await screen.findByRole("button", {name: "Devolver"}));
    fireEvent.click(screen.getByRole("button", {name: "Devolver para o autor"}));
    expect(screen.getByRole("alert")).toHaveTextContent("Escreva um comentário.");
    fireEvent.change(screen.getByLabelText("Comentário para o autor"), {target: {value: "Falta a referência"}});
    fireEvent.click(screen.getByRole("button", {name: "Devolver para o autor"}));
    await waitFor(() => expect(mutations.castVote).toHaveBeenCalledWith("c2", expect.any(Object), "return", "Falta a referência"));
  });

  it("rejeitar exige motivo", async () => {
    setup(curator2);
    fireEvent.click(await screen.findByRole("button", {name: "Rejeitar"}));
    fireEvent.change(screen.getByLabelText("Motivo da rejeição"), {target: {value: "Fora do escopo"}});
    fireEvent.click(screen.getByRole("button", {name: "Rejeitar envio"}));
    await waitFor(() => expect(mutations.castVote).toHaveBeenCalledWith("c2", expect.any(Object), "reject", "Fora do escopo"));
  });

  it("autor curador, professor e admin sem papel não veem botões de voto", async () => {
    setup(curator1, file({authorId: "c1"}));
    await screen.findByText("Aula 1");
    expect(screen.queryByRole("button", {name: "Aprovar"})).not.toBeInTheDocument();
  });

  it("professor autor vê o andamento e nenhuma ação de curador", async () => {
    setup(teacher, file(), [{id: "v1", voterId: "c1", action: "approve", version: 1, createdAt: 1}]);
    await screen.findByText("Aula 1");
    expect(screen.getByText("Aprovações: 1/2")).toBeInTheDocument();
    for (const name of ["Aprovar", "Devolver", "Rejeitar", "Renomear", "Mover", "Pedir exclusão"]) {
      expect(screen.queryByRole("button", {name})).not.toBeInTheDocument();
    }
  });

  it("falha ao votar mostra erro e reabilita", async () => {
    mutations.castVote.mockRejectedValue(new Error("permission-denied"));
    setup(curator2);
    fireEvent.click(await screen.findByRole("button", {name: "Aprovar"}));
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível registrar o voto. Tente novamente.");
    expect(screen.getByRole("button", {name: "Aprovar"})).toBeEnabled();
  });
});

describe("ItemDetail — histórico e visualização", () => {
  it("curador vê os votos com nomes e comentários", async () => {
    setup(curator2, file(), [
      {id: "v1", voterId: "c1", action: "return", version: 1, comment: "Falta a referência", createdAt: 5},
    ]);
    expect(await screen.findByText(/Ana Curadora/)).toBeInTheDocument();
    expect(screen.getByText(/Devolveu/)).toBeInTheDocument();
    expect(screen.getByText("Falta a referência")).toBeInTheDocument();
  });

  it("professor que não é autor não assina os votos", async () => {
    setup(other, file({status: "published"}));
    await screen.findByText("Aula 1");
    expect(repo.subscribeVotes).not.toHaveBeenCalled();
  });

  it("PDF aparece em iframe e há link para baixar", async () => {
    setup(other, file({status: "published"}));
    expect(await screen.findByTitle("Visualização de Aula 1")).toHaveAttribute("src", "https://files.example/aula.pdf");
    expect(screen.getByRole("link", {name: "Baixar"})).toHaveAttribute("href", "https://files.example/aula.pdf");
  });

  it("arquivo Office não tem visualização: oferece baixar", async () => {
    setup(other, file({status: "published", contentType: "application/msword", fileName: "a.doc"}));
    expect(await screen.findByText("Este tipo de arquivo não tem visualização. Baixe para abrir.")).toBeInTheDocument();
    expect(screen.queryByTitle("Visualização de Aula 1")).not.toBeInTheDocument();
  });

  it("link abre em nova aba com rel seguro", async () => {
    setup(other, {id: "i1", type: "link", name: "Livro", parentId: null, authorId: "t1", status: "published", version: 1, url: "https://x.org/livro", description: "Bom livro"});
    const anchor = await screen.findByRole("link", {name: "https://x.org/livro"});
    expect(anchor).toHaveAttribute("target", "_blank");
    expect(anchor).toHaveAttribute("rel", "noopener noreferrer");
    expect(screen.getByText("Bom livro")).toBeInTheDocument();
  });

  it("item inexistente ou sem acesso mostra aviso e fecha", async () => {
    const {onClose} = setup(other, null);
    expect(await screen.findByText("Item não encontrado ou excluído.")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", {name: "Fechar"}));
    expect(onClose).toHaveBeenCalledWith(null);
  });

  it("item sendo excluído mostra aviso e nenhuma ação", async () => {
    setup(curator2, file({deleting: "reject"}));
    expect(await screen.findByText("Este item está sendo excluído.")).toBeInTheDocument();
    expect(screen.queryByRole("button", {name: "Aprovar"})).not.toBeInTheDocument();
  });
});

describe("ItemDetail — organizar e excluir", () => {
  it("curador renomeia", async () => {
    const {onChanged} = setup(curator1, file({status: "published"}));
    fireEvent.click(await screen.findByRole("button", {name: "Renomear"}));
    fireEvent.change(screen.getByLabelText("Novo nome"), {target: {value: "Aula 1 revisada"}});
    fireEvent.click(screen.getByRole("button", {name: "Salvar"}));
    await waitFor(() => expect(mutations.renameItem).toHaveBeenCalledWith("c1", "i1", "Aula 1 revisada"));
    expect(onChanged).toHaveBeenCalled();
  });

  it("curador move para a raiz", async () => {
    const {onChanged} = setup(curator1, file({status: "published"}));
    fireEvent.click(await screen.findByRole("button", {name: "Mover"}));
    fireEvent.click(screen.getByRole("button", {name: "Biblioteca (raiz)"}));
    await waitFor(() => expect(mutations.moveItem).toHaveBeenCalledWith("c1", "i1", null));
    expect(onChanged).toHaveBeenCalled();
  });

  it("curador pede exclusão com motivo opcional", async () => {
    setup(curator1, file({status: "published"}));
    fireEvent.click(await screen.findByRole("button", {name: "Pedir exclusão"}));
    fireEvent.change(screen.getByLabelText("Motivo (opcional)"), {target: {value: "Obsoleto"}});
    fireEvent.click(screen.getByRole("button", {name: "Enviar pedido"}));
    await waitFor(() => expect(mutations.requestDelete).toHaveBeenCalledWith("c1", "i1", "Obsoleto"));
  });

  it("com pedido aberto: outro curador aprova ou recusa; quem pediu cancela", async () => {
    const withRequest = file({status: "published", deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: 1, reason: "Obsoleto"}});
    setup(curator2, withRequest);
    expect(await screen.findByText(/Obsoleto/)).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", {name: "Aprovar exclusão"}));
    await waitFor(() => expect(mutations.castVote).toHaveBeenCalledWith("c2", expect.any(Object), "delete_approve", undefined));
  });

  it("recusar exclusão exige comentário", async () => {
    setup(curator2, file({status: "published", deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: 1}}));
    fireEvent.click(await screen.findByRole("button", {name: "Recusar exclusão"}));
    fireEvent.change(screen.getByLabelText("Motivo da recusa"), {target: {value: "Ainda é usado"}});
    fireEvent.click(screen.getByRole("button", {name: "Recusar pedido"}));
    await waitFor(() => expect(mutations.castVote).toHaveBeenCalledWith("c2", expect.any(Object), "delete_refuse", "Ainda é usado"));
  });

  it("quem pediu vê Cancelar pedido e não vota na própria exclusão", async () => {
    setup(curator1, file({status: "published", deleteRequest: {id: "r1", requestedBy: "c1", requestedAt: 1}}));
    fireEvent.click(await screen.findByRole("button", {name: "Cancelar pedido de exclusão"}));
    await waitFor(() => expect(mutations.cancelDelete).toHaveBeenCalledWith("c1", "i1"));
    expect(screen.queryByRole("button", {name: "Aprovar exclusão"})).not.toBeInTheDocument();
  });
});

describe("ItemDetail — reenvio", () => {
  it("autor reenvia arquivo devolvido", async () => {
    const {onChanged} = setup(teacher, file({status: "returned", returnComment: "Falta a referência"}));
    expect(await screen.findByText(/Falta a referência/)).toBeInTheDocument();
    const input = screen.getByLabelText("Escolher novo arquivo");
    const novo = new File(["x"], "novo.pdf", {type: "application/pdf"});
    await act(async () => fireEvent.change(input, {target: {files: [novo]}}));
    await waitFor(() => expect(mutations.resubmitFile).toHaveBeenCalledWith("t1", expect.objectContaining({id: "i1"}), novo, expect.any(Function)));
    expect(onChanged).toHaveBeenCalled();
  });

  it("autor reenvia link devolvido com nova URL", async () => {
    setup(teacher, {id: "i1", type: "link", name: "Livro", parentId: null, authorId: "t1", status: "returned", version: 1, url: "https://velho.org", returnComment: "Link quebrado"});
    fireEvent.click(await screen.findByRole("button", {name: "Reenviar link"}));
    fireEvent.change(screen.getByLabelText("Endereço (URL)"), {target: {value: "https://novo.org"}});
    fireEvent.click(screen.getByRole("button", {name: "Reenviar"}));
    await waitFor(() => expect(mutations.resubmitLink).toHaveBeenCalledWith("t1", expect.objectContaining({id: "i1"}), {url: "https://novo.org", name: "Livro", description: ""}));
  });

  it("outro professor não vê o reenvio", async () => {
    setup(other, file({status: "returned"}));
    await screen.findByText("Aula 1");
    expect(screen.queryByLabelText("Escolher novo arquivo")).not.toBeInTheDocument();
  });
});
```

Acrescentar a `ui/LibraryPage.test.tsx`: com `vi.mock("../storageAccess", ...)` e o `subscribeItem`/`subscribeVotes`/`loadUserNames`/`canReadVotes` no mock de `../repository`, o caso "com `itemId` abre o painel do item e, ao fechar, navega para a pasta do item" (`navigate` chamado com `/ensino/biblioteca?pasta=<parentId>`).

- [ ] **Step 2: Rodar para ver falhar**

Run: `npm --prefix web-portal test -- preview labels ItemDetail LibraryPage`
Expected: FAIL — módulos novos não existem.

- [ ] **Step 3: Implementar**

Criar `web-portal/src/modules/teaching/library/preview.ts`:

```ts
export function previewKind(
  contentType: string | undefined
): "pdf" | "image" | "other" {
  if (contentType === "application/pdf") return "pdf";
  if (contentType?.startsWith("image/")) return "image";
  return "other";
}
```

Criar `web-portal/src/modules/teaching/library/labels.ts`:

```ts
import type {VoteAction} from "./types";

const LABELS: Record<VoteAction, string> = {
  approve: "Aprovou",
  reject: "Rejeitou",
  return: "Devolveu",
  delete_approve: "Aprovou a exclusão",
  delete_refuse: "Recusou a exclusão",
};

export function voteLabel(action: VoteAction): string {
  return LABELS[action];
}

export function formatDateTime(ms: number): string {
  if (!ms) return "—";
  return new Date(ms).toLocaleString("pt-BR", {dateStyle: "short", timeStyle: "short"});
}
```

Criar `web-portal/src/modules/teaching/library/storageAccess.ts`:

```ts
import {getDownloadURL, ref} from "firebase/storage";
import {storage} from "@/core/firebase/client";

// A leitura é autorizada pelas regras do Storage (consulta o item no Firestore).
export function downloadUrl(storagePath: string): Promise<string> {
  return getDownloadURL(ref(storage, storagePath));
}
```

Criar `web-portal/src/modules/teaching/library/useItemDetail.ts`:

```ts
"use client";

import {useEffect, useState} from "react";
import {canReadVotes, loadUserNames, subscribeItem, subscribeVotes} from "./repository";
import {downloadUrl} from "./storageAccess";
import type {LibraryItem, LibraryVote, Viewer} from "./types";

export function useItemDetail(itemId: string, viewer: Viewer) {
  const [loaded, setLoaded] = useState<{
    id: string;
    item: LibraryItem | null;
    error: string | null;
  } | null>(null);
  const [voteState, setVoteState] = useState<{id: string; list: LibraryVote[]}>({id: itemId, list: []});
  const [names, setNames] = useState<Record<string, string>>({});
  const [file, setFile] = useState<{path: string; url: string | null; failed: boolean} | null>(null);

  useEffect(() => {
    return subscribeItem(
      itemId,
      (item) => setLoaded({id: itemId, item, error: null}),
      () => setLoaded({id: itemId, item: null, error: "Não foi possível abrir este item."})
    );
  }, [itemId]);

  const item = loaded?.id === itemId ? loaded.item : undefined;
  const readable = item ? canReadVotes(item, viewer) : false;

  useEffect(() => {
    if (!readable) return;
    return subscribeVotes(
      itemId,
      (list) => setVoteState({id: itemId, list}),
      () => setVoteState({id: itemId, list: []})
    );
  }, [itemId, readable]);

  const votes = voteState.id === itemId && readable ? voteState.list : [];
  const voterKey = [...new Set(votes.map((v) => v.voterId))].sort().join(",");

  useEffect(() => {
    if (!voterKey) return;
    let active = true;
    loadUserNames(voterKey.split(",")).then((map) => active && setNames(map));
    return () => {
      active = false;
    };
  }, [voterKey]);

  const path = item?.type === "file" ? item.storagePath : undefined;
  useEffect(() => {
    if (!path) return;
    let active = true;
    downloadUrl(path)
      .then((url) => active && setFile({path, url, failed: false}))
      .catch(() => active && setFile({path, url: null, failed: true}));
    return () => {
      active = false;
    };
  }, [path]);

  const current = path && file?.path === path ? file : null;
  return {
    item,
    error: loaded?.id === itemId ? loaded.error : null,
    votes,
    names,
    fileUrl: current?.url ?? null,
    fileUrlError: current?.failed ?? false,
  };
}
```

Criar `web-portal/src/modules/teaching/library/ui/ItemDetail.tsx`:

```tsx
"use client";

import {useState} from "react";
import {Button} from "@/core/ui/Button";
import {validateName} from "../files";
import {formatDateTime, voteLabel} from "../labels";
import {castVote, cancelDelete, moveItem, renameItem, requestDelete, resubmitFile, resubmitLink} from "../mutations";
import {itemPermissions} from "../permissions";
import {previewKind} from "../preview";
import {countApprovals, countDeleteApprovals, statusBadge} from "../status";
import {REQUIRED_APPROVALS} from "../files";
import type {LibraryItem, Viewer, VoteAction} from "../types";
import {useItemDetail} from "../useItemDetail";
import {LinkDialog, MoveDialog, ReasonDialog, TextPromptDialog} from "./Dialogs";
import {StatusBadge} from "./StatusBadge";

type Modal =
  | "return" | "reject" | "refuse" | "delete" | "rename" | "move" | "resubmit-link" | null;

export function ItemDetail({
  itemId, viewer, folders, byId, onClose, onChanged,
}: {
  itemId: string;
  viewer: Viewer;
  folders: LibraryItem[];
  byId: Map<string, LibraryItem>;
  onClose: (parentId: string | null) => void;
  onChanged: () => void;
}) {
  const {item, error, votes, names, fileUrl, fileUrlError} = useItemDetail(itemId, viewer);
  const [modal, setModal] = useState<Modal>(null);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const [progress, setProgress] = useState<number | null>(null);

  if (item === undefined && !error) return <p className="text-white/70">Carregando…</p>;
  if (!item) {
    return (
      <div className="space-y-3 rounded-card bg-surface-elevated p-6">
        <p>{error ?? "Item não encontrado ou excluído."}</p>
        <Button type="button" variant="text" onClick={() => onClose(null)}>Fechar</Button>
      </div>
    );
  }

  const permissions = itemPermissions(item, viewer);
  const approvals = countApprovals(item, votes);
  const deleteApprovals = countDeleteApprovals(item, votes);
  const request = item.deleteRequest ?? null;
  const preview = item.type === "file" ? previewKind(item.contentType) : "other";

  async function act(success: string, failureMessage: string, action: () => Promise<void>) {
    setBusy(true);
    setNotice(null);
    setFailure(null);
    try {
      await action();
      setNotice(success);
      onChanged();
    } catch {
      setFailure(failureMessage);
    } finally {
      setBusy(false);
    }
  }

  const vote = (action: VoteAction, comment?: string) =>
    act("Voto registrado.", "Não foi possível registrar o voto. Tente novamente.", () => castVote(viewer.uid, item, action, comment));

  return (
    <article className="space-y-4 rounded-card bg-surface-elevated p-5">
      <header className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <h2 className="text-xl font-semibold">{item.name}</h2>
          <StatusBadge badge={statusBadge(item, approvals)} />
        </div>
        <Button type="button" variant="text" onClick={() => onClose(item.parentId)}>Fechar</Button>
      </header>

      {item.deleting && <p className="text-error">Este item está sendo excluído.</p>}
      {request && !item.deleting && (
        <p className="rounded-card bg-error/10 p-3 text-sm">
          Pedido de exclusão aberto{request.reason ? `: ${request.reason}` : ""}. Aprovações: {deleteApprovals}/{REQUIRED_APPROVALS}
        </p>
      )}
      {item.status === "returned" && item.returnComment && (
        <p className="rounded-card bg-white/10 p-3 text-sm">Devolvido pelos curadores: {item.returnComment}</p>
      )}
      {item.status === "in_review" && !request && <p className="text-sm text-white/70">Aprovações: {approvals}/{REQUIRED_APPROVALS}</p>}

      {item.type === "file" && (
        <section aria-label="Arquivo" className="space-y-2">
          {fileUrlError && <p role="alert" className="text-sm text-error">Não foi possível abrir o arquivo.</p>}
          {fileUrl && preview === "pdf" && <iframe title={`Visualização de ${item.name}`} src={fileUrl} className="h-[60vh] w-full rounded-card bg-white" />}
          {fileUrl && preview === "image" && <img alt={item.name} src={fileUrl} className="max-h-[60vh] rounded-card" />}
          {fileUrl && preview === "other" && <p className="text-sm text-white/70">Este tipo de arquivo não tem visualização. Baixe para abrir.</p>}
          {fileUrl && <a href={fileUrl} target="_blank" rel="noopener noreferrer" download={item.fileName} className="text-secondary underline">Baixar</a>}
        </section>
      )}
      {item.type === "link" && item.url && (
        <section aria-label="Link" className="space-y-1">
          <a href={item.url} target="_blank" rel="noopener noreferrer" className="break-all text-secondary underline">{item.url}</a>
          {item.description && <p className="text-sm text-white/70">{item.description}</p>}
        </section>
      )}

      {notice && <p role="status" className="text-sm text-secondary">{notice}</p>}
      {failure && <p role="alert" className="text-sm text-error">{failure}</p>}
      {progress !== null && <progress className="w-full" value={progress} max={1} />}

      <div className="flex flex-wrap gap-2">
        {permissions.canVote && (
          <>
            <Button type="button" disabled={busy} onClick={() => void vote("approve")}>Aprovar</Button>
            <Button type="button" variant="text" disabled={busy} onClick={() => setModal("return")}>Devolver</Button>
            <Button type="button" variant="text" disabled={busy} onClick={() => setModal("reject")}>Rejeitar</Button>
          </>
        )}
        {permissions.canVoteDelete && (
          <>
            <Button type="button" disabled={busy} onClick={() => void vote("delete_approve")}>Aprovar exclusão</Button>
            <Button type="button" variant="text" disabled={busy} onClick={() => setModal("refuse")}>Recusar exclusão</Button>
          </>
        )}
        {permissions.canCancelDelete && (
          <Button type="button" variant="text" disabled={busy} onClick={() => void act("Pedido cancelado.", "Não foi possível cancelar o pedido.", () => cancelDelete(viewer.uid, item.id))}>
            Cancelar pedido de exclusão
          </Button>
        )}
        {permissions.canRename && <Button type="button" variant="text" disabled={busy} onClick={() => setModal("rename")}>Renomear</Button>}
        {permissions.canMove && <Button type="button" variant="text" disabled={busy} onClick={() => setModal("move")}>Mover</Button>}
        {permissions.canRequestDelete && <Button type="button" variant="text" disabled={busy} onClick={() => setModal("delete")}>Pedir exclusão</Button>}
        {permissions.canResubmit && item.type === "link" && (
          <Button type="button" disabled={busy} onClick={() => setModal("resubmit-link")}>Reenviar link</Button>
        )}
      </div>

      {permissions.canResubmit && item.type === "file" && (
        <label className="block text-sm text-white/70">
          Reenviar arquivo corrigido
          <input
            type="file"
            aria-label="Escolher novo arquivo"
            disabled={busy}
            className="mt-1 block"
            onChange={(event) => {
              const chosen = event.target.files?.[0];
              event.target.value = "";
              if (!chosen) return;
              void act("Arquivo reenviado para revisão.", "Não foi possível reenviar o arquivo. Tente novamente.", async () => {
                try {
                  await resubmitFile(viewer.uid, item, chosen, setProgress);
                } finally {
                  setProgress(null);
                }
              });
            }}
          />
        </label>
      )}

      {votes.length > 0 && (
        <section aria-label="Histórico de revisão" className="space-y-1">
          <h3 className="text-sm font-semibold">Histórico de revisão</h3>
          <ul className="space-y-1 text-sm">
            {[...votes].sort((a, b) => a.createdAt - b.createdAt).map((v) => (
              <li key={v.id} className="rounded-card bg-white/5 p-2">
                <span>{names[v.voterId] ?? "Curador"} — {voteLabel(v.action)}</span>
                <span className="text-white/50"> · {formatDateTime(v.createdAt)}</span>
                {v.comment && <p className="mt-1 text-white/80">{v.comment}</p>}
              </li>
            ))}
          </ul>
        </section>
      )}

      {modal === "return" && (
        <ReasonDialog title="Devolver para o autor" label="Comentário para o autor" required submitLabel="Devolver para o autor"
          onSubmit={(text) => vote("return", text)} onClose={() => setModal(null)} />
      )}
      {modal === "reject" && (
        <ReasonDialog title="Rejeitar envio" label="Motivo da rejeição" required submitLabel="Rejeitar envio"
          onSubmit={(text) => vote("reject", text)} onClose={() => setModal(null)} />
      )}
      {modal === "refuse" && (
        <ReasonDialog title="Recusar exclusão" label="Motivo da recusa" required submitLabel="Recusar pedido"
          onSubmit={(text) => vote("delete_refuse", text)} onClose={() => setModal(null)} />
      )}
      {modal === "delete" && (
        <ReasonDialog title="Pedir exclusão" label="Motivo (opcional)" submitLabel="Enviar pedido"
          onSubmit={(text) => act("Pedido de exclusão enviado.", "Não foi possível enviar o pedido.", () => requestDelete(viewer.uid, item.id, text || undefined))}
          onClose={() => setModal(null)} />
      )}
      {modal === "rename" && (
        <TextPromptDialog title="Renomear" label="Novo nome" initial={item.name} submitLabel="Salvar" validate={validateName}
          onSubmit={async (name) => { await renameItem(viewer.uid, item.id, name); onChanged(); }}
          onClose={() => setModal(null)} />
      )}
      {modal === "move" && (
        <MoveDialog item={item} folders={folders} byId={byId}
          onPick={async (parentId) => { await moveItem(viewer.uid, item.id, parentId); onChanged(); }}
          onClose={() => setModal(null)} />
      )}
      {modal === "resubmit-link" && (
        <LinkDialog title="Reenviar link" submitLabel="Reenviar"
          initial={{name: item.name, url: item.url ?? "", description: item.description ?? ""}}
          onSubmit={async (value) => {
            await resubmitLink(viewer.uid, item, {url: value.url, name: value.name, description: value.description});
            onChanged();
          }}
          onClose={() => setModal(null)} />
      )}
    </article>
  );
}
```

Em `ui/LibraryPage.tsx` (`LibraryContent`): importar `ItemDetail`; derivar `folders = (catalog.items ?? []).filter((i) => i.type === "folder")`; e, logo abaixo das migalhas, renderizar o painel quando houver `itemId`:

```tsx
      {itemId && (
        <ItemDetail
          itemId={itemId}
          viewer={viewer}
          folders={folders}
          byId={byId}
          onChanged={catalog.reload}
          onClose={(parentId) => navigate(libraryUrl({pasta: parentId ?? folderId}))}
        />
      )}
```

(Deixar a listagem da pasta visível abaixo do painel.)

- [ ] **Step 4: Rodar testes, lint, tipos e build**

Run (um por vez): `npm --prefix web-portal test`, `npm --prefix web-portal run lint`, `npm --prefix web-portal run typecheck`, `npm --prefix web-portal run build`
Expected: PASS. Se o lint reclamar de `<img>` (`@next/next/no-img-element`), troque por um comentário `// eslint-disable-next-line @next/next/no-img-element` na linha: a imagem vem de uma URL assinada do Storage e não passa pelo otimizador do Next.

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add web-portal/src
/usr/bin/git commit -m "feat(web-portal): detalhe do item com visualização, histórico e ações de curadoria

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Fila de revisão, notificações, aviso de curadores e menu

**Files:**
- Create: `web-portal/src/modules/teaching/library/curators.ts`, `ui/ReviewQueuePage.tsx`, `ui/NotificationsPage.tsx`, `ui/NotificationBell.tsx`, `ui/CuratorWarning.tsx`
- Create: `web-portal/src/app/(portal)/ensino/revisao/page.tsx`, `web-portal/src/app/(portal)/ensino/notificacoes/page.tsx`
- Modify: `web-portal/src/modules/teaching/library/repository.ts` (acrescentar `loadVotes` e `countCurators`), `ui/LibraryPage.tsx` (sino e aviso), `web-portal/src/modules/teaching/module.ts`, `web-portal/src/modules/teaching/pages/TeachingHomePage.tsx`
- Test: `ui/ReviewQueuePage.test.tsx`, `ui/NotificationsPage.test.tsx`, `ui/NotificationBell.test.tsx`, `ui/CuratorWarning.test.tsx`

**Interfaces:**
- Consumes: Tasks 1 a 6 (`loadReviewQueue`, `subscribeNotifications`, `markRead`, `markAllRead`, `countApprovals`, `countDeleteApprovals`, `statusBadge`, `useCatalog`, `libraryUrl`, `itemPermissions`).
- Produces:
  - `repository.ts`: `loadVotes(itemId: string): Promise<LibraryVote[]>` e `countCurators(): Promise<number>` (conta `users` com `teaching_role == "curator"`).
  - `<ReviewQueuePage />` (curador/admin), `<NotificationsPage />`, `<NotificationBell uid />` (link `/ensino/notificacoes` com contador de não lidas), `<CuratorWarning />` (aparece para curador/admin quando há menos de 3 curadores).
  - `needsCurators(count: number): boolean` (`count < 3`) em `curators.ts`.

- [ ] **Step 1: Escrever os testes (que vão falhar)**

Criar `web-portal/src/modules/teaching/library/ui/ReviewQueuePage.test.tsx`:

```tsx
import {fireEvent, render, screen, waitFor} from "@testing-library/react";
import type {User} from "firebase/auth";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {AuthContext, type AuthState} from "@/core/auth/AuthContext";
import type {LibraryItem, LibraryVote} from "../types";
import ReviewQueuePage from "./ReviewQueuePage";

const repo = vi.hoisted(() => ({loadReviewQueue: vi.fn(), loadVotes: vi.fn(), loadAllVisible: vi.fn(), countCurators: vi.fn()}));
vi.mock("../repository", () => repo);
const nav = vi.hoisted(() => ({push: vi.fn()}));
vi.mock("next/navigation", () => ({useRouter: () => ({push: nav.push})}));

const item = (id: string, name: string, extra: Partial<LibraryItem> = {}): LibraryItem => ({
  id, name, type: "file", parentId: "f1", authorId: "t1", status: "in_review", version: 1, ...extra,
});
const folder: LibraryItem = {id: "f1", name: "Crianças", type: "folder", parentId: null, authorId: "c9", status: "active", version: 1};

function renderAs(uid: string, claims = {admin: false, teachingRole: "curator" as const}) {
  const state: AuthState = {status: "signedIn", user: {uid} as User, claims};
  return render(
    <AuthContext.Provider value={{state, refreshAccess: vi.fn(), signOut: vi.fn()}}>
      <ReviewQueuePage />
    </AuthContext.Provider>
  );
}

beforeEach(() => {
  nav.push.mockReset();
  repo.countCurators.mockReset().mockResolvedValue(3);
  repo.loadAllVisible.mockReset().mockResolvedValue([folder]);
  repo.loadVotes.mockReset().mockImplementation(async (id: string): Promise<LibraryVote[]> =>
    id === "i1" ? [{id: "v1", voterId: "c3", action: "approve", version: 1, createdAt: 1}] : []);
  repo.loadReviewQueue.mockReset().mockResolvedValue({
    inReview: [item("i1", "Aula 1"), item("i2", "Meu envio", {authorId: "c1"}), item("i3", "Já votei")],
    deleteRequests: [item("d1", "Livro antigo", {status: "published", deleteRequest: {id: "r1", requestedBy: "c9", requestedAt: 1, reason: "Obsoleto"}})],
  });
});

describe("ReviewQueuePage", () => {
  it("lista os envios que o curador ainda pode votar, com o andamento, e os pedidos de exclusão", async () => {
    renderAs("c1");
    expect(await screen.findByText("Aula 1")).toBeInTheDocument();
    expect(screen.getByText("1/2 aprovações")).toBeInTheDocument();
    expect(screen.getByText("Livro antigo")).toBeInTheDocument();
    expect(screen.getByText(/Obsoleto/)).toBeInTheDocument();
    expect(screen.queryByText("Meu envio")).not.toBeInTheDocument();
  });

  it("quem já votou na versão atual não vê o item pendente", async () => {
    repo.loadVotes.mockImplementation(async (id: string) =>
      id === "i3" ? [{id: "v9", voterId: "c1", action: "approve", version: 1, createdAt: 1}] : []);
    renderAs("c1");
    await screen.findByText("Aula 1");
    expect(screen.queryByText("Já votei")).not.toBeInTheDocument();
  });

  it("o interruptor mostra também os itens que não precisam do meu voto", async () => {
    renderAs("c1");
    await screen.findByText("Aula 1");
    fireEvent.click(screen.getByLabelText("Mostrar todos os envios em revisão"));
    expect(await screen.findByText("Meu envio")).toBeInTheDocument();
  });

  it("abrir um item navega para a biblioteca naquele item", async () => {
    renderAs("c1");
    fireEvent.click(await screen.findByRole("button", {name: "Abrir Aula 1"}));
    expect(nav.push).toHaveBeenCalledWith("/ensino/biblioteca?pasta=f1&item=i1");
  });

  it("fila vazia mostra mensagem", async () => {
    repo.loadReviewQueue.mockResolvedValue({inReview: [], deleteRequests: []});
    renderAs("c1");
    expect(await screen.findByText("Nada aguardando a sua revisão.")).toBeInTheDocument();
  });

  it("erro ao carregar mostra alerta", async () => {
    repo.loadReviewQueue.mockRejectedValue(new Error("x"));
    renderAs("c1");
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível carregar a fila de revisão.");
  });

  it("aviso quando há menos de 3 curadores", async () => {
    repo.countCurators.mockResolvedValue(1);
    renderAs("c1");
    expect(await screen.findByText(/Há apenas 1 curador/)).toBeInTheDocument();
  });
});
```

Criar `web-portal/src/modules/teaching/library/ui/NotificationsPage.test.tsx`:

```tsx
import {fireEvent, render, screen, waitFor} from "@testing-library/react";
import type {User} from "firebase/auth";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {AuthContext, type AuthState} from "@/core/auth/AuthContext";
import type {LibraryNotification} from "../types";
import NotificationsPage from "./NotificationsPage";

const notifications = vi.hoisted(() => ({subscribeNotifications: vi.fn(), markRead: vi.fn(), markAllRead: vi.fn()}));
vi.mock("../notifications", () => notifications);
const nav = vi.hoisted(() => ({push: vi.fn()}));
vi.mock("next/navigation", () => ({useRouter: () => ({push: nav.push})}));

const list: LibraryNotification[] = [
  {id: "n1", toUid: "t1", type: "published", itemId: "i1", title: "Material publicado", body: "\"Aula\" foi aprovado.", createdAt: 5, readAt: null},
  {id: "n2", toUid: "t1", type: "returned", itemId: "i2", title: "Material devolvido", body: "\"Livro\": Link quebrado", createdAt: 3, readAt: 4},
];

function renderPage() {
  const state: AuthState = {status: "signedIn", user: {uid: "t1"} as User, claims: {admin: false, teachingRole: "teacher"}};
  render(
    <AuthContext.Provider value={{state, refreshAccess: vi.fn(), signOut: vi.fn()}}>
      <NotificationsPage />
    </AuthContext.Provider>
  );
}

beforeEach(() => {
  nav.push.mockReset();
  notifications.markRead.mockReset().mockResolvedValue(undefined);
  notifications.markAllRead.mockReset().mockResolvedValue(undefined);
  notifications.subscribeNotifications.mockReset().mockImplementation((_uid, onData) => {
    onData(list);
    return vi.fn();
  });
});

describe("NotificationsPage", () => {
  it("lista com não lidas destacadas", async () => {
    renderPage();
    expect(await screen.findByText("Material publicado")).toBeInTheDocument();
    expect(screen.getByText("Material devolvido")).toBeInTheDocument();
    expect(screen.getAllByLabelText("Não lida")).toHaveLength(1);
  });

  it("abrir marca como lida e navega para o item", async () => {
    renderPage();
    fireEvent.click(await screen.findByRole("button", {name: /Material publicado/}));
    await waitFor(() => expect(notifications.markRead).toHaveBeenCalledWith("n1"));
    expect(nav.push).toHaveBeenCalledWith("/ensino/biblioteca?item=i1");
  });

  it("não remarca uma notificação já lida", async () => {
    renderPage();
    fireEvent.click(await screen.findByRole("button", {name: /Material devolvido/}));
    expect(notifications.markRead).not.toHaveBeenCalled();
    expect(nav.push).toHaveBeenCalledWith("/ensino/biblioteca?item=i2");
  });

  it("marcar todas como lidas só envia as não lidas", async () => {
    renderPage();
    fireEvent.click(await screen.findByRole("button", {name: "Marcar todas como lidas"}));
    await waitFor(() => expect(notifications.markAllRead).toHaveBeenCalledWith(["n1"]));
  });

  it("sem notificações mostra mensagem; erro mostra alerta", async () => {
    notifications.subscribeNotifications.mockImplementation((_uid, onData) => {
      onData([]);
      return vi.fn();
    });
    renderPage();
    expect(await screen.findByText("Você não tem notificações.")).toBeInTheDocument();
  });

  it("erro na escuta mostra alerta", async () => {
    notifications.subscribeNotifications.mockImplementation((_uid, _onData, onError) => {
      onError(new Error("x"));
      return vi.fn();
    });
    renderPage();
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível carregar as notificações.");
  });
});
```

Criar `web-portal/src/modules/teaching/library/ui/NotificationBell.test.tsx`:

```tsx
import {render, screen} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {LibraryNotification} from "../types";
import {NotificationBell} from "./NotificationBell";

const notifications = vi.hoisted(() => ({subscribeNotifications: vi.fn()}));
vi.mock("../notifications", () => notifications);

const n = (id: string, readAt: number | null): LibraryNotification => ({id, toUid: "t1", type: "x", itemId: "i", title: "T", body: "B", createdAt: 1, readAt});

beforeEach(() => notifications.subscribeNotifications.mockReset());

describe("NotificationBell", () => {
  it("mostra o contador de não lidas no link", () => {
    notifications.subscribeNotifications.mockImplementation((_uid, onData) => {
      onData([n("1", null), n("2", null), n("3", 5)]);
      return vi.fn();
    });
    render(<NotificationBell uid="t1" />);
    const link = screen.getByRole("link", {name: "Notificações (2 não lidas)"});
    expect(link).toHaveAttribute("href", "/ensino/notificacoes");
  });

  it("sem não lidas não mostra contador", () => {
    notifications.subscribeNotifications.mockImplementation((_uid, onData) => {
      onData([n("1", 5)]);
      return vi.fn();
    });
    render(<NotificationBell uid="t1" />);
    expect(screen.getByRole("link", {name: "Notificações"})).toBeInTheDocument();
  });

  it("cancela a escuta ao desmontar", () => {
    const stop = vi.fn();
    notifications.subscribeNotifications.mockReturnValue(stop);
    const {unmount} = render(<NotificationBell uid="t1" />);
    unmount();
    expect(stop).toHaveBeenCalled();
  });
});
```

Criar `web-portal/src/modules/teaching/library/ui/CuratorWarning.test.tsx`:

```tsx
import {render, screen} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import {needsCurators} from "../curators";
import {CuratorWarning} from "./CuratorWarning";

const repo = vi.hoisted(() => ({countCurators: vi.fn()}));
vi.mock("../repository", () => repo);

beforeEach(() => repo.countCurators.mockReset());

describe("needsCurators", () => {
  it("menos de 3 curadores", () => {
    expect(needsCurators(0)).toBe(true);
    expect(needsCurators(2)).toBe(true);
    expect(needsCurators(3)).toBe(false);
  });
});

describe("CuratorWarning", () => {
  it("avisa quando há menos de 3 curadores, com singular e plural", async () => {
    repo.countCurators.mockResolvedValue(1);
    const {unmount} = render(<CuratorWarning />);
    expect(await screen.findByText(/Há apenas 1 curador\. /)).toBeInTheDocument();
    unmount();
    repo.countCurators.mockResolvedValue(2);
    render(<CuratorWarning />);
    expect(await screen.findByText(/Há apenas 2 curadores\. /)).toBeInTheDocument();
  });

  it("não aparece com 3 ou mais, nem quando a contagem falha", async () => {
    repo.countCurators.mockResolvedValue(3);
    const first = render(<CuratorWarning />);
    await Promise.resolve();
    expect(first.container).toBeEmptyDOMElement();
    first.unmount();
    repo.countCurators.mockRejectedValue(new Error("x"));
    const second = render(<CuratorWarning />);
    await Promise.resolve();
    expect(second.container).toBeEmptyDOMElement();
  });
});
```

- [ ] **Step 2: Rodar para ver falhar**

Run: `npm --prefix web-portal test -- ReviewQueue Notifications NotificationBell CuratorWarning`
Expected: FAIL — módulos novos não existem.

- [ ] **Step 3: Implementar**

Acrescentar ao final de `web-portal/src/modules/teaching/library/repository.ts` (e importar `getDocs`/`query`/`where` já existentes; adicionar `collection` de `users`):

```ts
export async function loadVotes(itemId: string): Promise<LibraryVote[]> {
  const snapshot = await getDocs(collection(db, "teaching_items", itemId, "votes"));
  return snapshot.docs
    .map((d) => toVote(d.id, d.data()))
    .filter((vote): vote is LibraryVote => vote !== null);
}

// Curadores = usuários com teaching_role == "curator" (users é legível por
// quem está logado). A Function confere o papel no Auth ao contar votos.
export async function countCurators(): Promise<number> {
  const snapshot = await getDocs(
    query(collection(db, "users"), where("teaching_role", "==", "curator"))
  );
  return snapshot.size;
}
```

Criar `web-portal/src/modules/teaching/library/curators.ts`:

```ts
// Envio de curador e exclusão exigem 2 outros curadores: com menos de 3,
// nada disso consegue ser aprovado.
export const MIN_CURATORS = 3;

export function needsCurators(count: number): boolean {
  return count < MIN_CURATORS;
}
```

Criar `web-portal/src/modules/teaching/library/ui/CuratorWarning.tsx`:

```tsx
"use client";

import {useEffect, useState} from "react";
import {needsCurators} from "../curators";
import {countCurators} from "../repository";

export function CuratorWarning() {
  const [count, setCount] = useState<number | null>(null);

  useEffect(() => {
    let active = true;
    countCurators()
      .then((n) => active && setCount(n))
      .catch(() => undefined);
    return () => {
      active = false;
    };
  }, []);

  if (count === null || !needsCurators(count)) return null;
  const quantity = count === 1 ? "1 curador" : `${count} curadores`;
  return (
    <p role="note" className="rounded-card bg-white/10 p-3 text-sm">
      Há apenas {quantity}. São necessários pelo menos 3 para aprovar o envio de
      um curador e para excluir materiais publicados.
    </p>
  );
}
```

Criar `web-portal/src/modules/teaching/library/ui/NotificationBell.tsx`:

```tsx
"use client";

import Link from "next/link";
import {useEffect, useState} from "react";
import {subscribeNotifications} from "../notifications";

export function NotificationBell({uid}: {uid: string}) {
  const [unread, setUnread] = useState(0);

  useEffect(() => {
    return subscribeNotifications(
      uid,
      (list) => setUnread(list.filter((n) => n.readAt === null).length),
      () => setUnread(0)
    );
  }, [uid]);

  const label = unread > 0 ? `Notificações (${unread} não lidas)` : "Notificações";
  return (
    <Link href="/ensino/notificacoes" aria-label={label} className="relative inline-flex items-center rounded-button px-3 py-2 hover:bg-white/10">
      <span aria-hidden>🔔</span>
      {unread > 0 && (
        <span aria-hidden className="ml-1 rounded-button bg-error/30 px-1.5 text-xs">{unread}</span>
      )}
    </Link>
  );
}
```

Criar `web-portal/src/modules/teaching/library/ui/NotificationsPage.tsx`:

```tsx
"use client";

import {useRouter} from "next/navigation";
import {useEffect, useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {Button} from "@/core/ui/Button";
import {formatDateTime} from "../labels";
import {markAllRead, markRead, subscribeNotifications} from "../notifications";
import type {LibraryNotification} from "../types";
import {libraryUrl} from "../url";

export default function NotificationsPage() {
  const {state} = useAuth();
  const router = useRouter();
  const uid = state.status === "signedIn" ? state.user.uid : null;
  const [list, setList] = useState<LibraryNotification[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!uid) return;
    return subscribeNotifications(
      uid,
      (items) => {
        setList(items);
        setError(null);
      },
      () => setError("Não foi possível carregar as notificações.")
    );
  }, [uid]);

  async function open(n: LibraryNotification) {
    if (n.readAt === null) {
      try {
        await markRead(n.id);
      } catch {
        // abrir o item continua funcionando mesmo se marcar falhar
      }
    }
    router.push(libraryUrl({item: n.itemId}));
  }

  const unreadIds = (list ?? []).filter((n) => n.readAt === null).map((n) => n.id);

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-2xl font-semibold">Notificações</h1>
        {unreadIds.length > 0 && (
          <Button type="button" variant="text" onClick={() => void markAllRead(unreadIds)}>Marcar todas como lidas</Button>
        )}
      </div>
      {error && <p role="alert" className="text-sm text-error">{error}</p>}
      {list === null && !error && <p className="text-white/70">Carregando…</p>}
      {list?.length === 0 && <p className="rounded-card bg-surface-elevated p-6 text-center text-white/70">Você não tem notificações.</p>}
      <ul className="space-y-2">
        {list?.map((n) => (
          <li key={n.id}>
            <button type="button" onClick={() => void open(n)} className="flex w-full items-start gap-3 rounded-card bg-surface-elevated px-4 py-3 text-left hover:brightness-125">
              {n.readAt === null ? <span aria-label="Não lida" className="mt-2 h-2 w-2 shrink-0 rounded-full bg-secondary" /> : <span className="mt-2 h-2 w-2 shrink-0" />}
              <span className="min-w-0 flex-1">
                <span className="block font-medium">{n.title}</span>
                <span className="block text-sm text-white/70">{n.body}</span>
                <span className="block text-xs text-white/50">{formatDateTime(n.createdAt)}</span>
              </span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

Criar `web-portal/src/modules/teaching/library/ui/ReviewQueuePage.tsx`:

```tsx
"use client";

import {useRouter} from "next/navigation";
import {useEffect, useMemo, useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {loadReviewQueue, loadVotes} from "../repository";
import {itemPermissions} from "../permissions";
import {countApprovals, countDeleteApprovals, statusBadge} from "../status";
import {REQUIRED_APPROVALS} from "../files";
import {buildBreadcrumbs, indexById, sortItems} from "../tree";
import type {LibraryItem, LibraryVote, Viewer} from "../types";
import {viewerFrom} from "../types";
import {libraryUrl} from "../url";
import {useCatalog} from "../useLibrary";
import {CuratorWarning} from "./CuratorWarning";
import {ItemRow} from "./ItemRow";

// Constante: um objeto novo a cada render dispararia o efeito de useCatalog
// em laço quando ainda não há usuário.
const NO_VIEWER: Viewer = {uid: "", isCurator: false, isAdmin: false};

interface Entry {
  item: LibraryItem;
  votes: LibraryVote[];
}

// Já votei na versão atual (publicação) ou no pedido atual (exclusão)?
function iVoted(item: LibraryItem, votes: LibraryVote[], uid: string): boolean {
  return votes.some((v) =>
    v.voterId === uid &&
    (item.deleteRequest ? v.requestId === item.deleteRequest.id : v.version === item.version));
}

export default function ReviewQueuePage() {
  const {state} = useAuth();
  const router = useRouter();
  const viewer = useMemo(
    () => (state.status === "signedIn" ? viewerFrom(state.user.uid, state.claims) : null),
    [state]
  );
  const catalog = useCatalog(viewer ?? NO_VIEWER);
  const [reviews, setReviews] = useState<Entry[] | null>(null);
  const [deletions, setDeletions] = useState<Entry[] | null>(null);
  const [showAll, setShowAll] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const queue = await loadReviewQueue();
        const withVotes = async (items: LibraryItem[]): Promise<Entry[]> =>
          Promise.all(items.map(async (item) => ({item, votes: await loadVotes(item.id).catch(() => [])})));
        const [r, d] = await Promise.all([withVotes(queue.inReview), withVotes(queue.deleteRequests)]);
        if (!active) return;
        setReviews(r);
        setDeletions(d);
      } catch {
        if (active) setError("Não foi possível carregar a fila de revisão.");
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  if (!viewer) return null;
  const byId = indexById(catalog.items ?? []);
  const pathOf = (item: LibraryItem) => {
    const names = buildBreadcrumbs(byId, item.parentId).map((f) => f.name);
    return names.length > 0 ? names.join(" / ") : "Biblioteca";
  };
  const open = (item: LibraryItem) => router.push(libraryUrl({pasta: item.parentId, item: item.id}));

  const visibleReviews = (reviews ?? []).filter(({item, votes}) =>
    showAll || (itemPermissions(item, viewer).canVote && !iVoted(item, votes, viewer.uid)));
  const visibleDeletions = (deletions ?? []).filter(({item, votes}) =>
    showAll || (itemPermissions(item, viewer).canVoteDelete && !iVoted(item, votes, viewer.uid)));
  const empty = reviews !== null && visibleReviews.length === 0 && visibleDeletions.length === 0;

  const rows = (entries: Entry[], deletion: boolean) =>
    sortItems(entries.map((e) => e.item)).map((item) => {
      const votes = entries.find((e) => e.item.id === item.id)?.votes ?? [];
      const subtitle = deletion ?
        `${pathOf(item)} · Pedido de exclusão${item.deleteRequest?.reason ? `: ${item.deleteRequest.reason}` : ""} · ${countDeleteApprovals(item, votes)}/${REQUIRED_APPROVALS} aprovações` :
        `${pathOf(item)} · ${countApprovals(item, votes)}/${REQUIRED_APPROVALS} aprovações`;
      return (
        <ItemRow key={item.id} item={item} badge={statusBadge(item, countApprovals(item, votes))} view="list" subtitle={subtitle} onOpen={() => open(item)} />
      );
    });

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Fila de revisão</h1>
      <CuratorWarning />
      <label className="flex items-center gap-2 text-sm text-white/70">
        <input type="checkbox" checked={showAll} onChange={(e) => setShowAll(e.target.checked)} aria-label="Mostrar todos os envios em revisão" />
        Mostrar também o que não precisa do meu voto
      </label>
      {error && <p role="alert" className="text-sm text-error">{error}</p>}
      {reviews === null && !error && <p className="text-white/70">Carregando…</p>}
      {empty && <p className="rounded-card bg-surface-elevated p-6 text-center text-white/70">Nada aguardando a sua revisão.</p>}
      {visibleReviews.length > 0 && (
        <section aria-label="Envios em revisão" className="space-y-2">
          <h2 className="font-semibold">Envios em revisão</h2>
          {rows(visibleReviews, false)}
        </section>
      )}
      {visibleDeletions.length > 0 && (
        <section aria-label="Pedidos de exclusão" className="space-y-2">
          <h2 className="font-semibold">Pedidos de exclusão</h2>
          {rows(visibleDeletions, true)}
        </section>
      )}
    </div>
  );
}
```

Criar as rotas (`web-portal/src/app/(portal)/ensino/revisao/page.tsx` e `.../notificacoes/page.tsx`), cada uma com uma linha:

```tsx
export {default} from "@/modules/teaching/library/ui/ReviewQueuePage";
```

```tsx
export {default} from "@/modules/teaching/library/ui/NotificationsPage";
```

Em `web-portal/src/modules/teaching/module.ts`, o `navItems` final:

```ts
  navItems: [
    {label: "Início", href: "/ensino", access: "teacher"},
    {label: "Biblioteca", href: "/ensino/biblioteca", access: "teacher"},
    {label: "Fila de revisão", href: "/ensino/revisao", access: "curator"},
    {label: "Notificações", href: "/ensino/notificacoes", access: "teacher"},
    {label: "Grupo de professores", href: "/ensino/admin", access: "admin"},
  ],
```

Em `ui/LibraryPage.tsx` (`LibraryContent`): no cabeçalho, ao lado do título, `<NotificationBell uid={viewer.uid} />`; e, abaixo do cabeçalho, `{(viewer.isCurator || viewer.isAdmin) && <CuratorWarning />}`. Em `pages/TeachingHomePage.tsx`, trocar o cartão "Fórum"? **Não**: o fórum é da etapa 4; manter o cartão "Fórum" como está, e acrescentar um cartão "Notificações" com `Link` para `/ensino/notificacoes`.

- [ ] **Step 4: Rodar testes, lint, tipos e build**

Run (um por vez): `npm --prefix web-portal test`, `npm --prefix web-portal run lint`, `npm --prefix web-portal run typecheck`, `npm --prefix web-portal run build`
Expected: PASS; o build lista `/ensino/biblioteca`, `/ensino/revisao` e `/ensino/notificacoes`.

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add web-portal/src
/usr/bin/git commit -m "feat(web-portal): fila de revisão, notificações, aviso de curadores e menu

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 8: App Flutter — tocar na notificação de curadoria abre o portal

**Files:**
- Create: `lib/src/modules/notifications/services/teaching_notification_url.dart`
- Create (teste): `test/modules/notifications/teaching_notification_url_test.dart`
- Modify: `lib/src/modules/notifications/services/notification_service.dart`

**Interfaces:**
- Consumes: o dado do push enviado pela Cloud Function do Plano A: `type: "teaching_review"`, `itemId`, `url` (`https://ipe-ensino.vercel.app/ensino/biblioteca?item={id}`).
- Produces: `Uri? teachingPortalUriFromData(Map<String, dynamic> data)` — devolve o endereço só quando `type == "teaching_review"` e o `url` é `https` do host do portal; caso contrário `null` (nunca abre outro endereço).

- [ ] **Step 1: Escrever o teste (que vai falhar)**

Criar `test/modules/notifications/teaching_notification_url_test.dart` (use o mesmo estilo de `import` de pacote que os outros testes de `test/modules/`; o nome do pacote vem de `name:` em `pubspec.yaml`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/notifications/services/teaching_notification_url.dart';

void main() {
  group('teachingPortalUriFromData', () {
    const valid = 'https://ipe-ensino.vercel.app/ensino/biblioteca?item=abc123';

    test('abre o item do portal quando o tipo e o endereço são os esperados', () {
      final uri = teachingPortalUriFromData({'type': 'teaching_review', 'url': valid});
      expect(uri, isNotNull);
      expect(uri.toString(), valid);
    });

    test('ignora outros tipos de notificação', () {
      expect(teachingPortalUriFromData({'type': 'chat_mention', 'url': valid}), isNull);
      expect(teachingPortalUriFromData({'url': valid}), isNull);
    });

    test('recusa endereço de outro host, inclusive truques de subdomínio e usuário', () {
      for (final bad in [
        'https://evil.com/ensino/biblioteca',
        'https://ipe-ensino.vercel.app.evil.com/x',
        'https://ipe-ensino.vercel.app@evil.com/x',
        'https://evil.com/?u=ipe-ensino.vercel.app',
      ]) {
        expect(teachingPortalUriFromData({'type': 'teaching_review', 'url': bad}), isNull, reason: bad);
      }
    });

    test('recusa http, esquemas estranhos, vazio, ausente e tipo errado', () {
      for (final bad in [
        'http://ipe-ensino.vercel.app/x',
        'javascript:alert(1)',
        '',
        'não é uma url',
      ]) {
        expect(teachingPortalUriFromData({'type': 'teaching_review', 'url': bad}), isNull, reason: bad);
      }
      expect(teachingPortalUriFromData({'type': 'teaching_review'}), isNull);
      expect(teachingPortalUriFromData({'type': 'teaching_review', 'url': 42}), isNull);
    });
  });
}
```

- [ ] **Step 2: Rodar para ver falhar**

Run: `flutter test test/modules/notifications/teaching_notification_url_test.dart`
Expected: FAIL — o arquivo `teaching_notification_url.dart` não existe. (Se o `flutter` não estiver no PATH ou um hook bloquear o comando, procure o executável em locais comuns, rode um comando por vez e relate se não conseguir rodar Flutter.)

- [ ] **Step 3: Implementar**

Criar `lib/src/modules/notifications/services/teaching_notification_url.dart`:

```dart
const String _teachingPortalHost = 'ipe-ensino.vercel.app';

/// Endereço do portal de ensino a abrir quando a notificação é de curadoria.
///
/// Só devolve um endereço `https` do host do portal; qualquer outro valor
/// (outro host, http, esquema estranho, dado ausente) resulta em `null`, para
/// que uma notificação nunca abra um endereço arbitrário.
Uri? teachingPortalUriFromData(Map<String, dynamic> data) {
  if (data['type'] != 'teaching_review') return null;
  final raw = data['url'];
  if (raw is! String || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (uri.scheme != 'https' || uri.host != _teachingPortalHost) return null;
  if (uri.userInfo.isNotEmpty) return null;
  return uri;
}
```

Em `lib/src/modules/notifications/services/notification_service.dart`:

1. Acrescentar aos imports: `import 'dart:convert';`, `import 'package:url_launcher/url_launcher.dart';` e `import 'teaching_notification_url.dart';`.
2. Em `_navigateFromNotification(RemoteMessage message)`, logo depois de `final data = message.data;` e **antes** da verificação `if (navigator == null)`, acrescentar:

```dart
    final portalUri = teachingPortalUriFromData(data);
    if (portalUri != null) {
      launchUrl(portalUri, mode: LaunchMode.externalApplication);
      return;
    }
```

3. Em `_showLocalNotification`, trocar `payload: message.data.toString(),` por `payload: jsonEncode(message.data),`.
4. Trocar o corpo de `_onNotificationTapped(NotificationResponse response)` por:

```dart
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notificação tocada: ${response.payload}');
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final portalUri = teachingPortalUriFromData(decoded);
        if (portalUri != null) {
          launchUrl(portalUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {
      // Payload antigo (não JSON): nada a fazer.
    }
  }
```

(Mantenha qualquer outro conteúdo existente de `_onNotificationTapped`, como o comentário, se houver; apenas acrescente o tratamento acima.)

- [ ] **Step 4: Rodar testes e análise**

Run (um por vez): `flutter test test/modules/notifications/teaching_notification_url_test.dart`, depois `flutter test`, depois `dart format lib/src/modules/notifications/services/teaching_notification_url.dart test/modules/notifications/teaching_notification_url_test.dart`.
Expected: o teste novo passa e a suíte inteira continua passando. `flutter analyze` não deve ganhar problemas novos em relação à linha de base (a worktree não tem `app_secrets.dart` nem `firebase_options.dart`, então há erros antigos de arquivos ausentes: compare a contagem antes e depois e relate; não formate `notification_service.dart` inteiro).

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add lib/src/modules/notifications/services/teaching_notification_url.dart lib/src/modules/notifications/services/notification_service.dart test/modules/notifications/teaching_notification_url_test.dart
/usr/bin/git commit -m "feat(notifications): tocar na notificação de curadoria abre o portal

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Documentação e verificação final

**Files:**
- Modify: `web-portal/README.md`

**Interfaces:**
- Consumes: tudo das Tasks 1 a 8.
- Produces: README atualizado e a lista de verificação ponta a ponta que o usuário executa com curadores reais depois do merge.

- [ ] **Step 1: Atualizar o README do portal**

Em `web-portal/README.md`, acrescentar uma seção "Biblioteca e curadoria" depois de "Como adicionar um módulo":

```markdown
## Biblioteca e curadoria

- Rotas: `/ensino/biblioteca` (parâmetros `?pasta={id}` abre uma pasta e `?item={id}` abre o detalhe de um item), `/ensino/revisao` (fila do curador) e `/ensino/notificacoes`.
- Código em `src/modules/teaching/library/`: lógica pura (`tree`, `permissions`, `status`, `files`, `payloads`, `convert`), camada de dados (`repository`, `mutations`, `notifications`, `uploadFlow`) e telas em `ui/`.
- As permissões reais estão nas regras do Firestore/Storage e nas Cloud Functions (`functions/src/teaching/library/`); a interface só esconde o que o papel não pode.
- Regras do produto: todo envio é revisado e precisa de 2 aprovações de curadores diferentes do autor; devolver é 1 curador; rejeitar e apagar exigem 2 curadores (e qualquer curador pode recusar um pedido de exclusão); só curador gerencia pastas.
- O portal precisa de pelo menos 3 curadores para aprovar envios de curadores e exclusões (a tela avisa).
```

- [ ] **Step 2: Rodar tudo**

Run (um por vez): `npm --prefix web-portal test`, `npm --prefix web-portal run lint`, `npm --prefix web-portal run typecheck`, `npm --prefix web-portal run build`, `flutter test`
Expected: tudo PASS.

- [ ] **Step 3: Commit**

```bash
/usr/bin/git add web-portal/README.md
/usr/bin/git commit -m "docs(web-portal): biblioteca e curadoria

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Entrega (fora das tarefas, com o usuário)

O deploy do portal é automático quando o PR é mesclado na `master` (Vercel ligada ao GitHub). O app Flutter só chega aos usuários numa nova versão publicada nas lojas.

**Verificação ponta a ponta no portal em produção** (precisa de **3 curadores reais**; promova-os na lista de pessoas do app):

1. **Envio de professor:** um professor envia um PDF numa pasta criada por um curador. Ele vê o item "Em revisão 0/2"; outro professor **não** vê o item.
2. **Aprovação:** o curador A aprova (andamento 1/2, ainda invisível para os outros professores); o curador B aprova → o item vira "Publicado" em instantes e o autor recebe a notificação (sino no portal e push no app).
3. **Leitura de arquivo:** outro professor abre o item publicado e visualiza/baixa o PDF; abrir diretamente o link de um arquivo ainda em revisão por outro usuário **falha** (confirma a regra do Storage com leitura cruzada ao Firestore em produção).
4. **Devolução:** curador devolve um envio com comentário; o autor vê o comentário, reenvia um arquivo corrigido (versão 2) e o item volta a "Em revisão 0/2"; o arquivo antigo some do Storage.
5. **Rejeição:** dois curadores rejeitam um envio com motivo; o item e o arquivo desaparecem e o autor é avisado.
6. **Exclusão:** um curador pede a exclusão de um item publicado; outro curador recusa (o pedido some); repita o pedido e dois outros curadores aprovam → o item é apagado. Peça a exclusão de uma pasta vazia → some na hora; de uma pasta com documento → exige os 2.
7. **Permissões visíveis:** professor não vê "Nova pasta", "Renomear", "Mover" nem votos; admin sem papel de curador não vê botões de voto; o autor curador não vê Aprovar no próprio envio.
8. **Fila de revisão e aviso:** a fila mostra o que falta votar; com menos de 3 curadores o aviso aparece.
9. **App:** tocar numa notificação de curadoria (app fechado, em segundo plano e em primeiro plano) abre o portal no item (exige a versão nova do app instalada).
10. Conferir no console do Firebase que as Functions executaram sem erros (`onTeachingVoteCreated`, `onTeachingItemCreated`, `onTeachingItemUpdated`) e que não há loops de execução.

## Self-Review (feita ao final da escrita)

**Cobertura da spec (seções 5 a 9 e 14)**
- Seção 5 e 6 (regras e dados): payloads exatamente no formato das regras (Task 2), permissões espelhadas (Task 1), reenvio, votos e exclusão (Tasks 3 e 6).
- Seção 7 (telas): biblioteca com migalhas, lista/grade, busca, selos (Task 4); criar pasta/link, enviar vários arquivos com progresso e arrastar e soltar, renomear e mover (Task 5); detalhe com visualização de PDF/imagem, download, histórico de votos e ações (Task 6); fila de revisão, caixa de notificações com sino e aviso de menos de 3 curadores (Task 7).
- Seção 8 (notificações): caixa no portal (Task 7) e push com link para o item (Task 8 abre o portal).
- Seção 9 (app): ajuste mínimo do toque na notificação (Task 8).
- Seção 14: consultas do professor em 3 igualdades, `uuid` no pedido de exclusão, `?item=`, reenvio com versão nova, item `returned` sem reenvio (sem ação de exclusão, decisão de produto pendente), campos só da Function nunca escritos.

**Limitações conhecidas (fora de escopo)**
- Item `returned` que o autor nunca reenvia não tem como ser removido (as regras só permitem pedido de exclusão para publicado/ativo).
- O progresso de aprovações na lista e na fila é um indicador do cliente (conta votos); quem decide é a Function, que relê o papel no Auth.
- Busca só por nome (não no conteúdo); mover é por diálogo (sem arrastar itens entre pastas); sem lixeira.
- Preferência de notificação `teaching_review` no app não tem tela própria (usa a chave de `disabled_notifications` se já existir).

**Placeholders:** nenhum "TBD/TODO"; os passos de Flutter dependem do ambiente (`flutter` no PATH) e têm instrução de contorno.

**Consistência de tipos:** `LibraryItem`, `LibraryVote`, `Viewer`, `LibraryNotification` definidos na Task 1/2 e usados com as mesmas assinaturas nas Tasks 3 a 7; `statusBadge(item, approvals: number | null)` ajustado na Task 4 (e `status.test.ts` ganha o caso `null`); `ItemDetail.onClose(parentId)` usado por `LibraryContent`; `libraryUrl`/`readParams` usados em Tasks 4, 6 e 7.

**Review Focus:** 1 em `permissions.test.ts` e `ItemDetail.test.tsx`; 2 em `payloads.test.ts`; 3 em `uploadFlow.test.ts` e no reenvio (`resubmitFile` separa estágios `upload` e `create`); 4 em `LibraryPage.test.tsx` (pasta inexistente, vazia, erro), `ItemDetail.test.tsx` (item inexistente, `deleting`) e `ReviewQueuePage.test.tsx`/`CuratorWarning.test.tsx`; 5 em `LibraryPage.test.tsx` (trocar de pasta cancela a escuta e descarta resposta velha) e `ItemDetail.test.tsx` (botões desabilitados durante a gravação).
