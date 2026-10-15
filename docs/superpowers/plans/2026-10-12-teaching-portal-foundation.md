# Portal de Ensino IPE — Etapa 1: Fundação — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar a base segura do portal web de ensino: papéis de professor/curador viram custom claims, as regras do Firestore e do Storage as respeitam, e um portal Next.js (com a identidade visual do app e uma casca modular) permite que um admin gerencie o grupo de professores.

**Architecture:** O portal (`web-portal/`, Next.js na Vercel) usa o mesmo projeto Firebase `app-ipe` do app Flutter. `users/{uid}.teaching_role` (`none|teacher|curator`) e `is_admin` são copiados para custom claims por uma Cloud Function; as regras do Firestore (campos protegidos) e do Storage (acesso a `teaching/**`) leem as claims. O portal tem uma casca compartilhada (login, menu, guarda de acesso) e módulos registrados (`src/modules/teaching`), de modo que módulos futuros entrem sem mexer nos existentes.

**Tech Stack:** Next.js 16 (App Router, TypeScript, Tailwind v4), Firebase JS SDK 13 (Auth, Firestore, Storage), Firebase Functions v1 (Node 22, TypeScript), Vitest + Testing Library, `@firebase/rules-unit-testing` 6 com os emuladores do Firebase, Vercel.

**Spec:** `docs/superpowers/specs/2026-10-12-teaching-portal-design.md`

**Nota de ambiente:** nesta máquina o hook do `rtk` pode bloquear `git` simples dentro da worktree. Se isso acontecer, use `/usr/bin/git` no lugar de `git` em todos os passos de commit. Todos os caminhos abaixo são relativos à raiz da worktree (`.claude/worktrees/teaching-portal`).

## Global Constraints

- Só a IPE. Sem multi-tenant.
- Só o grupo de professores acessa: leem todo o material e criam e respondem tópicos no fórum. Quem tem `teaching_role = none` não acessa a área, nem no app nem na web.
- Login: a mesma conta do app (Firebase Auth). Sem fluxo de cadastro separado.
- Portal: Next.js na Vercel, em `web-portal/`, **dentro deste repositório**, compartilhando `firestore.rules`, `storage.rules`, `functions/` e `firebase.json`.
- Backend: o mesmo Firebase (Auth, Firestore, Storage, Functions). Nenhum segundo backend.
- Papéis: `users/{uid}.teaching_role` ∈ `none | teacher | curator`. O curador é um professor com poder extra. O `is_admin` existente continua sendo o administrador. **Só o admin atribui e retira papéis.**
- Uma Cloud Function copia `teaching_role` e `is_admin` para custom claims (`teaching_role`, `admin`). As regras leem a claim, sem consultar outro documento.
- Identidade visual idêntica à do app (`lib/src/shared/theme/app_theme.dart`): tema escuro; fundo `#0B0F19`, superfície `#111828`, superfície elevada `#1B2435`; primária `#2F4F2F`, secundária `#6B8E23`, erro `#FF5470`, texto branco; cards raio 18, diálogos e bottom sheets raio 28, campos raio 18 com borda branca a 5%, borda de foco na cor primária; botão principal preenchido na cor primária, raio 18, texto 16 px peso 600; "vidro" com gradiente branco 12% → 4%, borda branca a 8%, blur 20, raio 24; tipografia do sistema, sem fonte customizada.
- Os tokens visuais ficam num único arquivo (`web-portal/src/styles/tokens.css`). Nenhum componente usa cor ou raio fixo.
- Estrutura modular: `src/modules/<módulo>/*` com rotas, componentes, acesso a dados e tipos; casca compartilhada fora dos módulos; guarda de acesso por módulo; camada de dados tipada por módulo.
- Storage: arquivos em `teaching/materials/{id}/{nome}`; leitura exige professor ou superior; escrita com limite de tamanho e lista de tipos permitidos (PDF, Office, imagens).
- Todo texto de interface em português do Brasil (pt-BR).
- Node 22 (`functions/package.json` → `engines.node`).
- Não modificar o código Flutter (`lib/`) nesta etapa.

## Review Focus

Entradas e falhas que a spec sugere e que as tarefas abaixo cobrem com testes (cada linha tem seu teste na tarefa dona):

1. **Autoescalada de privilégio:** usuário comum edita o próprio `users/{uid}` para virar `is_admin` ou ganhar `teaching_role`, na criação ou na atualização. Esperado: negado. (Task 1)
2. **Papel inválido:** valor como `"god"` em `teaching_role`. Esperado: as regras recusam a escrita do admin e a Function ignora o valor (sem claim). (Tasks 1 e 2)
3. **Token velho depois de mudar o papel:** o professor continua com a claim antiga até o token renovar. Esperado: o portal força renovação no login, e a tela de acesso restrito tem "Verificar acesso novamente". Limite conhecido: um professor revogado pode manter a leitura do Storage por até 1 hora se já estiver com sessão aberta. (Task 5)
4. **Usuário sem documento, pendente ou sem claims:** conta que existe no Auth mas não tem papel. Esperado: tela de acesso restrito, nunca erro nem tela em branco. (Tasks 4 e 5)
5. **Documento de usuário apagado ou conta removida do Auth:** a Function não pode lançar erro. Esperado: limpa as claims quando dá, e ignora o caso `auth/user-not-found`. (Task 2)

## Premissas a confirmar com o usuário

- **Admin tem acesso total à área** (nível de curador ou acima), mesmo sem `teaching_role`. A spec diz que "curador e admin" aprovam, e este plano trata `admin` como superconjunto.
- **Limite de upload: 100 MB**, com tipos PDF, Office (doc/docx/ppt/pptx/xls/xlsx e equivalentes OpenDocument) e imagens. A spec pede limite e lista, mas não os valores.
- **Login do portal nesta etapa: e-mail/senha e Google.** Apple na web exige configurar um Services ID e fica fora da etapa 1.
- **O deploy das regras aperta `users` em produção** (Task 1). O app já faz só `update()` parcial e o admin alterna `is_admin` pelo próprio app, então não quebra, mas o deploy tem um portão de confirmação (Task 7).

---

## File Structure

```
firebase.json                                  (modificar: storage + emuladores)
firestore.rules                                (modificar: bloco users)
storage.rules                                  (criar)
.gitignore                                     (modificar)
rules-tests/                                   (criar: testes das regras no emulador)
  package.json
  tsconfig.json
  env.ts
  users.rules.test.ts
  storage.rules.test.ts
functions/
  package.json                                 (modificar: vitest)
  .eslintrc.js                                 (modificar: ignorar test/ e scripts/)
  src/index.ts                                 (modificar: exportar o trigger)
  src/teaching/claims.ts                       (criar: funções puras)
  src/teaching/syncClaims.ts                   (criar: lógica + trigger)
  test/claims.test.ts                          (criar)
  test/syncClaims.test.ts                      (criar)
  scripts/backfill-teaching-claims.ts          (criar: reparo manual)
web-portal/                                    (criar via create-next-app)
  .env.example
  README.md
  vitest.config.ts
  vitest.setup.ts
  src/styles/tokens.css
  src/styles/tokens.test.ts
  src/app/globals.css
  src/app/layout.tsx
  src/app/login/page.tsx
  src/app/(portal)/layout.tsx
  src/app/(portal)/page.tsx
  src/app/(portal)/ensino/page.tsx
  src/app/(portal)/ensino/admin/page.tsx
  src/core/firebase/client.ts
  src/core/auth/access.ts            (+ access.test.ts)
  src/core/auth/errors.ts            (+ errors.test.ts)
  src/core/auth/AuthContext.ts
  src/core/auth/AuthProvider.tsx
  src/core/auth/LoginForm.tsx
  src/core/modules/types.ts
  src/core/modules/registry.ts       (+ registry.test.ts)
  src/core/ui/Button.tsx             (+ Button.test.tsx)
  src/core/ui/Card.tsx
  src/core/ui/GlassCard.tsx
  src/core/ui/TextField.tsx
  src/core/ui/AccessDenied.tsx
  src/core/ui/PortalShell.tsx        (+ PortalShell.test.tsx)
  src/modules/teaching/module.ts
  src/modules/teaching/data/memberRows.ts            (+ memberRows.test.ts)
  src/modules/teaching/data/membersRepository.ts
  src/modules/teaching/pages/TeachingHomePage.tsx
  src/modules/teaching/pages/GroupAdminPage.tsx      (+ GroupAdminPage.test.tsx)
```

---

### Task 1: Regras de segurança (Firestore `users` + Storage) com testes no emulador

**Files:**
- Create: `rules-tests/package.json`, `rules-tests/tsconfig.json`, `rules-tests/env.ts`, `rules-tests/users.rules.test.ts`, `rules-tests/storage.rules.test.ts`
- Create: `storage.rules`
- Modify: `firebase.json`, `firestore.rules` (bloco `match /users/{userId}`), `.gitignore`

**Interfaces:**
- Consumes: nada de tarefas anteriores. Usa o `isAdmin()` já existente em `firestore.rules`.
- Produces: contrato das claims lido pelas regras do Storage: `request.auth.token.admin == true` e `request.auth.token.teaching_role ∈ {teacher, curator}`. Contrato dos campos de `users/{uid}`: `teaching_role` (`none|teacher|curator`) e `is_admin` só mudam por admin.

- [ ] **Step 1: Preparar o ambiente de testes das regras**

Adicionar ao `.gitignore` da raiz (se ainda não houver):

```
node_modules/
rules-tests/node_modules/
web-portal/node_modules/
web-portal/.next/
```

Criar `rules-tests/package.json`:

```json
{
  "name": "rules-tests",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "firebase emulators:exec --only firestore,storage --project demo-ipe-rules \"vitest run\""
  }
}
```

Criar `rules-tests/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "skipLibCheck": true,
    "types": ["node"]
  },
  "include": ["*.ts"]
}
```

Instalar:

```bash
cd rules-tests && npm install -D @firebase/rules-unit-testing firebase vitest typescript @types/node
```

Esperado: `package.json` passa a listar as dependências e o `node_modules` é criado.

Em `firebase.json`, adicionar (ao lado de `"firestore"`):

```json
  "storage": {
    "rules": "storage.rules"
  },
  "emulators": {
    "firestore": {"port": 8080},
    "storage": {"port": 9199},
    "ui": {"enabled": false}
  },
```

- [ ] **Step 2: Escrever o helper e os testes (que vão falhar) das regras de `users`**

Criar `rules-tests/env.ts`:

```ts
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";

const root = resolve(import.meta.dirname, "..");

export async function createEnv(): Promise<RulesTestEnvironment> {
  return initializeTestEnvironment({
    projectId: "demo-ipe-rules",
    firestore: {rules: readFileSync(resolve(root, "firestore.rules"), "utf8")},
    storage: {rules: readFileSync(resolve(root, "storage.rules"), "utf8")},
  });
}
```

Criar `rules-tests/users.rules.test.ts`:

```ts
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
});
```

- [ ] **Step 3: Rodar para ver falhar**

Criar um `storage.rules` provisório vazio de regras só para o ambiente subir? Não: o `createEnv` lê `storage.rules`, então crie primeiro o arquivo completo no Step 6. Por ora, crie `storage.rules` com o conteúdo mínimo abaixo, só para o emulador iniciar:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

Run: `cd rules-tests && npm test -- users`
Expected: os testes "NÃO vira admin", "NÃO se atribui teaching_role", "criação com is_admin true ou teaching_role é negada" e "admin NÃO grava teaching_role inválido" **FALHAM** (as regras atuais permitem). Os demais passam.

- [ ] **Step 4: Implementar as regras de `users`**

Em `firestore.rules`, logo abaixo da função `isAdmin()`, adicionar:

```
    // Campos de acesso: só administradores podem alterar (viram custom claims)
    function touchesProtectedFields() {
      return request.resource.data.diff(resource.data).affectedKeys()
        .hasAny(['is_admin', 'isAdmin', 'teaching_role']);
    }

    function validTeachingRole() {
      return request.resource.data.get('teaching_role', 'none')
        in ['none', 'teacher', 'curator'];
    }
```

Substituir o bloco `match /users/{userId} { ... }` inteiro por:

```
    // Regras para usuários
    match /users/{userId} {
      // Qualquer usuário autenticado pode ler qualquer usuário (para listar equipe)
      allow read: if request.auth != null;

      // O usuário edita o próprio perfil, exceto os campos de acesso.
      // Administradores podem editar qualquer usuário (is_admin, teaching_role).
      allow update: if request.auth != null && validTeachingRole() &&
        (isAdmin() ||
          (request.auth.uid == userId && !touchesProtectedFields()));

      // O usuário cria apenas o próprio documento, sem privilégios.
      allow create: if request.auth != null &&
        request.auth.uid == userId &&
        request.resource.data.get('is_admin', false) == false &&
        request.resource.data.get('isAdmin', false) == false &&
        !('teaching_role' in request.resource.data);

      // Apenas administradores podem deletar usuários
      allow delete: if isAdmin();
    }
```

- [ ] **Step 5: Rodar os testes de `users` e ver passar**

Run: `cd rules-tests && npm test -- users`
Expected: todos os testes de `users` PASS.

- [ ] **Step 6: Escrever os testes (que vão falhar) do Storage**

Criar `rules-tests/storage.rules.test.ts`:

```ts
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

  it("outros caminhos do bucket seguem negados", async () => {
    await assertFails(uploadBytes(ref(teacher(), "outros/a.pdf"), bytes, pdf));
  });
});
```

Run: `cd rules-tests && npm test -- storage`
Expected: "professor, curador e admin leem" e "professor envia PDF…" FALHAM (o `storage.rules` provisório nega tudo). Os de negação passam por acidente.

- [ ] **Step 7: Implementar `storage.rules`**

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

    // Curador ou administrador
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

    match /teaching/materials/{materialId}/{fileName} {
      allow read: if hasTeachingAccess();

      // 100 MB por arquivo
      allow create, update: if hasTeachingAccess() &&
        request.resource.size <= 100 * 1024 * 1024 &&
        allowedContentType();

      allow delete: if isCuratorOrAdmin();
    }
  }
}
```

- [ ] **Step 8: Rodar a suíte completa das regras**

Run: `cd rules-tests && npm test`
Expected: todos os testes de `users` e de Storage PASS.

- [ ] **Step 9: Commit**

```bash
git add firebase.json firestore.rules storage.rules .gitignore rules-tests/package.json rules-tests/package-lock.json rules-tests/tsconfig.json rules-tests/env.ts rules-tests/users.rules.test.ts rules-tests/storage.rules.test.ts
git commit -m "feat(rules): proteger campos de acesso em users e regras do Storage de ensino

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Cloud Function que sincroniza as claims

**Files:**
- Create: `functions/src/teaching/claims.ts`, `functions/src/teaching/syncClaims.ts`, `functions/test/claims.test.ts`, `functions/test/syncClaims.test.ts`, `functions/scripts/backfill-teaching-claims.ts`
- Modify: `functions/package.json`, `functions/.eslintrc.js`, `functions/src/index.ts`

**Interfaces:**
- Consumes: o contrato de campos de `users/{uid}` da Task 1 (`is_admin`, `teaching_role`).
- Produces (usados nas Tasks 4 a 6 e no deploy):
  - `type TeachingRole = "teacher" | "curator"`
  - `interface TeachingClaims {admin?: true; teaching_role?: TeachingRole}`
  - `computeTeachingClaims(userData: Record<string, unknown> | undefined): TeachingClaims`
  - `claimsEqual(a: TeachingClaims, b: TeachingClaims): boolean`
  - `mergeTeachingClaims(existing: Record<string, unknown> | undefined, next: TeachingClaims): Record<string, unknown>`
  - `syncTeachingClaims(auth: ClaimsAuth, uid: string, before: UserData | undefined, after: UserData | undefined): Promise<"updated" | "skipped">`
  - Cloud Function exportada: `syncTeachingClaimsOnUserWrite`
  - Claims no token: `admin: true` e `teaching_role: "teacher" | "curator"` (ausentes quando não se aplicam).

- [ ] **Step 1: Instalar o Vitest e configurar o lint**

```bash
cd functions && npm install -D vitest
```

Em `functions/package.json`, adicionar aos `scripts`:

```json
    "test": "vitest run",
```

Em `functions/.eslintrc.js`, trocar `ignorePatterns` por:

```js
  ignorePatterns: [
    "/lib/**/*", // Ignore built files.
    "/generated/**/*", // Ignore generated files.
    "/test/**/*", // Testes rodam no Vitest, fora do tsconfig de build.
    "/scripts/**/*", // Scripts manuais de manutenção.
  ],
```

- [ ] **Step 2: Escrever os testes (que vão falhar) das funções puras**

Criar `functions/test/claims.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {
  claimsEqual,
  computeTeachingClaims,
  mergeTeachingClaims,
} from "../src/teaching/claims";

describe("computeTeachingClaims", () => {
  it("sem documento não há claims", () => {
    expect(computeTeachingClaims(undefined)).toEqual({});
  });

  it("is_admin true vira admin", () => {
    expect(computeTeachingClaims({is_admin: true})).toEqual({admin: true});
  });

  it("teacher e curator viram teaching_role", () => {
    expect(computeTeachingClaims({teaching_role: "teacher"})).toEqual({teaching_role: "teacher"});
    expect(computeTeachingClaims({teaching_role: "curator"})).toEqual({teaching_role: "curator"});
  });

  it("admin e professor juntos", () => {
    expect(computeTeachingClaims({is_admin: true, teaching_role: "curator"})).toEqual({
      admin: true,
      teaching_role: "curator",
    });
  });

  it("none, valor inválido ou tipo errado não geram claim", () => {
    expect(computeTeachingClaims({teaching_role: "none"})).toEqual({});
    expect(computeTeachingClaims({teaching_role: "god"})).toEqual({});
    expect(computeTeachingClaims({teaching_role: 3})).toEqual({});
  });

  it("is_admin só vale como booleano true (alinhado às regras)", () => {
    expect(computeTeachingClaims({is_admin: "true"})).toEqual({});
    expect(computeTeachingClaims({isAdmin: true})).toEqual({});
    expect(computeTeachingClaims({is_admin: false})).toEqual({});
  });
});

describe("claimsEqual", () => {
  it("compara admin e teaching_role", () => {
    expect(claimsEqual({}, {})).toBe(true);
    expect(claimsEqual({admin: true}, {admin: true})).toBe(true);
    expect(claimsEqual({admin: true}, {})).toBe(false);
    expect(claimsEqual({teaching_role: "teacher"}, {teaching_role: "curator"})).toBe(false);
  });
});

describe("mergeTeachingClaims", () => {
  it("preserva claims de outros sistemas e troca as de ensino", () => {
    const merged = mergeTeachingClaims(
      {foo: 1, admin: true, teaching_role: "teacher"},
      {teaching_role: "curator"}
    );
    expect(merged).toEqual({foo: 1, teaching_role: "curator"});
  });

  it("remove claims de ensino quando não se aplicam mais", () => {
    expect(mergeTeachingClaims({admin: true, teaching_role: "teacher"}, {})).toEqual({});
  });

  it("aceita claims existentes indefinidas", () => {
    expect(mergeTeachingClaims(undefined, {admin: true})).toEqual({admin: true});
  });
});
```

Run: `cd functions && npm test`
Expected: FAIL — `Cannot find module '../src/teaching/claims'`.

- [ ] **Step 3: Implementar as funções puras**

Criar `functions/src/teaching/claims.ts`:

```ts
export type TeachingRole = "teacher" | "curator";

export interface TeachingClaims {
  admin?: true;
  teaching_role?: TeachingRole;
}

const CLAIM_KEYS = ["admin", "teaching_role"] as const;

/**
 * Calcula as custom claims de ensino a partir do documento users/{uid}.
 * Só `is_admin === true` vale como admin (igual às regras do Firestore).
 * @param {Record<string, unknown> | undefined} userData - dados do usuário
 * @return {TeachingClaims} claims derivadas do documento
 */
export function computeTeachingClaims(
  userData: Record<string, unknown> | undefined
): TeachingClaims {
  const claims: TeachingClaims = {};
  if (!userData) return claims;
  if (userData.is_admin === true) claims.admin = true;
  const role = userData.teaching_role;
  if (role === "teacher" || role === "curator") claims.teaching_role = role;
  return claims;
}

/**
 * Compara dois conjuntos de claims de ensino.
 * @param {TeachingClaims} a - primeiro conjunto
 * @param {TeachingClaims} b - segundo conjunto
 * @return {boolean} true quando são equivalentes
 */
export function claimsEqual(a: TeachingClaims, b: TeachingClaims): boolean {
  return a.admin === b.admin && a.teaching_role === b.teaching_role;
}

/**
 * Aplica as claims de ensino sobre as claims existentes, preservando
 * qualquer claim que não seja de ensino.
 * @param {Record<string, unknown> | undefined} existing - claims atuais
 * @param {TeachingClaims} next - claims de ensino calculadas
 * @return {Record<string, unknown>} claims finais a gravar
 */
export function mergeTeachingClaims(
  existing: Record<string, unknown> | undefined,
  next: TeachingClaims
): Record<string, unknown> {
  const merged: Record<string, unknown> = {...(existing ?? {})};
  for (const key of CLAIM_KEYS) delete merged[key];
  return {...merged, ...next};
}
```

Run: `cd functions && npm test`
Expected: PASS nos testes de `claims.test.ts`.

- [ ] **Step 4: Escrever os testes (que vão falhar) da sincronização**

Criar `functions/test/syncClaims.test.ts`:

```ts
import {describe, expect, it, vi} from "vitest";
import {syncTeachingClaims} from "../src/teaching/syncClaims";

function fakeAuth(existing?: Record<string, unknown>) {
  return {
    getUser: vi.fn().mockResolvedValue({customClaims: existing}),
    setCustomUserClaims: vi.fn().mockResolvedValue(undefined),
  };
}

describe("syncTeachingClaims", () => {
  it("grava a claim quando o papel é atribuído", async () => {
    const auth = fakeAuth();
    const result = await syncTeachingClaims(auth, "u1", {name: "Ana"}, {name: "Ana", teaching_role: "teacher"});
    expect(result).toBe("updated");
    expect(auth.setCustomUserClaims).toHaveBeenCalledWith("u1", {teaching_role: "teacher"});
  });

  it("ignora mudanças que não afetam o acesso", async () => {
    const auth = fakeAuth();
    const result = await syncTeachingClaims(auth, "u1", {name: "Ana"}, {name: "Ana Maria"});
    expect(result).toBe("skipped");
    expect(auth.setCustomUserClaims).not.toHaveBeenCalled();
    expect(auth.getUser).not.toHaveBeenCalled();
  });

  it("criação de documento sem privilégios não faz nada", async () => {
    const auth = fakeAuth();
    expect(await syncTeachingClaims(auth, "u1", undefined, {name: "Ana", is_admin: false})).toBe("skipped");
    expect(auth.setCustomUserClaims).not.toHaveBeenCalled();
  });

  it("remove a claim ao retirar o papel, preservando claims alheias", async () => {
    const auth = fakeAuth({foo: 1, teaching_role: "teacher"});
    await syncTeachingClaims(auth, "u1", {teaching_role: "teacher"}, {teaching_role: "none"});
    expect(auth.setCustomUserClaims).toHaveBeenCalledWith("u1", {foo: 1});
  });

  it("papel inválido é ignorado (sem claim)", async () => {
    const auth = fakeAuth();
    expect(await syncTeachingClaims(auth, "u1", {}, {teaching_role: "god"})).toBe("skipped");
    expect(auth.setCustomUserClaims).not.toHaveBeenCalled();
  });

  it("limpa as claims quando o documento é apagado", async () => {
    const auth = fakeAuth({admin: true, teaching_role: "curator"});
    const result = await syncTeachingClaims(auth, "u1", {is_admin: true, teaching_role: "curator"}, undefined);
    expect(result).toBe("updated");
    expect(auth.setCustomUserClaims).toHaveBeenCalledWith("u1", {});
  });

  it("conta removida do Auth (user-not-found) não lança erro", async () => {
    const auth = fakeAuth();
    auth.getUser.mockRejectedValue(Object.assign(new Error("nope"), {code: "auth/user-not-found"}));
    expect(await syncTeachingClaims(auth, "u1", {}, {teaching_role: "teacher"})).toBe("skipped");
    expect(auth.setCustomUserClaims).not.toHaveBeenCalled();
  });

  it("outros erros do Auth são propagados", async () => {
    const auth = fakeAuth();
    auth.getUser.mockRejectedValue(Object.assign(new Error("boom"), {code: "auth/internal-error"}));
    await expect(syncTeachingClaims(auth, "u1", {}, {teaching_role: "teacher"})).rejects.toThrow("boom");
  });
});
```

Run: `cd functions && npm test -- syncClaims`
Expected: FAIL — módulo `../src/teaching/syncClaims` não existe.

- [ ] **Step 5: Implementar a sincronização e o trigger**

Criar `functions/src/teaching/syncClaims.ts`:

```ts
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {
  claimsEqual,
  computeTeachingClaims,
  mergeTeachingClaims,
} from "./claims";

type UserData = Record<string, unknown>;

export interface ClaimsAuth {
  getUser(uid: string): Promise<{customClaims?: Record<string, unknown>}>;
  setCustomUserClaims(
    uid: string,
    claims: Record<string, unknown> | null
  ): Promise<void>;
}

/**
 * Copia teaching_role e is_admin de users/{uid} para as custom claims do
 * usuário, só quando algo que afeta o acesso mudou.
 * @param {ClaimsAuth} auth - cliente do Firebase Auth (injetável em testes)
 * @param {string} uid - id do usuário
 * @param {UserData | undefined} before - documento antes da escrita
 * @param {UserData | undefined} after - documento depois da escrita
 * @return {Promise<string>} "updated" quando gravou, "skipped" caso contrário
 */
export async function syncTeachingClaims(
  auth: ClaimsAuth,
  uid: string,
  before: UserData | undefined,
  after: UserData | undefined
): Promise<"updated" | "skipped"> {
  const beforeClaims = computeTeachingClaims(before);
  const afterClaims = computeTeachingClaims(after);
  if (claimsEqual(beforeClaims, afterClaims)) return "skipped";

  let existing: Record<string, unknown> | undefined;
  try {
    const user = await auth.getUser(uid);
    existing = user.customClaims;
  } catch (error) {
    if ((error as {code?: string}).code === "auth/user-not-found") {
      return "skipped";
    }
    throw error;
  }

  await auth.setCustomUserClaims(uid, mergeTeachingClaims(existing, afterClaims));
  return "updated";
}

export const syncTeachingClaimsOnUserWrite = functions.firestore
  .document("users/{userId}")
  .onWrite(async (change, context) => {
    const {userId} = context.params;
    try {
      await syncTeachingClaims(
        admin.auth(),
        userId,
        change.before.exists ? change.before.data() : undefined,
        change.after.exists ? change.after.data() : undefined
      );
    } catch (error) {
      console.error("Erro ao sincronizar claims de ensino:", error);
    }
    return null;
  });
```

No final de `functions/src/index.ts`, adicionar:

```ts
export {syncTeachingClaimsOnUserWrite} from "./teaching/syncClaims";
```

- [ ] **Step 6: Rodar testes, lint e build**

Run: `cd functions && npm test && npm run lint && npm run build`
Expected: todos os testes PASS; lint sem erros (se o ESLint do Google reclamar de largura de linha ou espaços em `{}`, ajuste os arquivos de `src/` ao estilo do `index.ts` existente: sem espaços dentro de chaves, máx. 80 colunas, vírgula final em multilinha); `tsc` sem erros.

- [ ] **Step 7: Criar o script de reparo (backfill)**

Os admins que já existem não têm a claim `admin` até o documento mudar. Este script é rodado uma vez, manualmente, depois do deploy. Criar `functions/scripts/backfill-teaching-claims.ts`:

```ts
import * as admin from "firebase-admin";
import {
  computeTeachingClaims,
  mergeTeachingClaims,
} from "../src/teaching/claims";

async function main(): Promise<void> {
  admin.initializeApp({projectId: "app-ipe"});
  const snapshot = await admin.firestore().collection("users").get();
  let updated = 0;
  let failed = 0;

  for (const doc of snapshot.docs) {
    const claims = computeTeachingClaims(doc.data());
    if (Object.keys(claims).length === 0) continue;
    try {
      const user = await admin.auth().getUser(doc.id);
      await admin
        .auth()
        .setCustomUserClaims(doc.id, mergeTeachingClaims(user.customClaims, claims));
      updated++;
    } catch (error) {
      failed++;
      console.error(`Falha em ${doc.id}:`, (error as Error).message);
    }
  }
  console.log(`Claims gravadas: ${updated}. Falhas: ${failed}.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
```

(Não é executado agora. A execução é o Step 4 da Task 7.)

- [ ] **Step 8: Commit**

```bash
git add functions/package.json functions/package-lock.json functions/.eslintrc.js functions/src functions/test functions/scripts
git commit -m "feat(functions): sincronizar teaching_role e is_admin com custom claims

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Projeto Next.js, tokens visuais e componentes base

**Files:**
- Create: `web-portal/` (via `create-next-app`), `web-portal/vitest.config.ts`, `web-portal/vitest.setup.ts`, `web-portal/src/styles/tokens.css`, `web-portal/src/styles/tokens.test.ts`, `web-portal/src/core/ui/Button.tsx`, `web-portal/src/core/ui/Button.test.tsx`, `web-portal/src/core/ui/Card.tsx`, `web-portal/src/core/ui/GlassCard.tsx`, `web-portal/src/core/ui/TextField.tsx`
- Modify: `web-portal/src/app/globals.css`, `web-portal/src/app/layout.tsx`, `web-portal/src/app/page.tsx` (será removido na Task 5)

**Interfaces:**
- Consumes: `lib/src/shared/theme/app_theme.dart` (fonte de verdade das cores).
- Produces: tokens CSS `--ipe-*`; utilitários Tailwind `bg-background`, `bg-surface`, `bg-surface-elevated`, `bg-primary`, `bg-secondary`, `text-on-surface`, `text-on-primary`, `text-error`, `rounded-card`, `rounded-input`, `rounded-button`, `rounded-dialog`, `rounded-glass`; componentes `Button({variant?: "primary" | "text"} & ButtonHTMLAttributes)`, `Card`, `GlassCard`, `TextField({label, ...InputHTMLAttributes})`.

- [ ] **Step 1: Criar o projeto Next.js**

Na raiz da worktree:

```bash
npx create-next-app@16.4.0 web-portal --ts --tailwind --eslint --app --src-dir --import-alias "@/*" --use-npm --yes
```

Esperado: a pasta `web-portal/` é criada com `src/app`, `package.json` e Tailwind v4 (`@import "tailwindcss"` em `src/app/globals.css`). Se o CLI pedir alguma escolha não coberta pelas flags, escolha o padrão. Confirmar que existe `web-portal/src/app/layout.tsx` e `globals.css`.

Instalar Firebase e as dependências de teste:

```bash
cd web-portal && npm install firebase && npm install -D vitest @vitejs/plugin-react jsdom @testing-library/react @testing-library/jest-dom
```

Em `web-portal/package.json`, garantir nos `scripts`:

```json
    "test": "vitest run",
    "typecheck": "tsc --noEmit"
```

- [ ] **Step 2: Configurar o Vitest**

Criar `web-portal/vitest.config.ts`:

```ts
import {fileURLToPath} from "node:url";
import react from "@vitejs/plugin-react";
import {defineConfig} from "vitest/config";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {"@": fileURLToPath(new URL("./src", import.meta.url))},
  },
  test: {
    environment: "jsdom",
    setupFiles: ["./vitest.setup.ts"],
  },
});
```

Criar `web-portal/vitest.setup.ts`:

```ts
import "@testing-library/jest-dom/vitest";
import {cleanup} from "@testing-library/react";
import {afterEach} from "vitest";

afterEach(() => {
  cleanup();
});
```

- [ ] **Step 3: Escrever o teste (que vai falhar) dos tokens contra o app**

Criar `web-portal/src/styles/tokens.test.ts`:

```ts
import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {describe, expect, it} from "vitest";

const css = readFileSync(resolve(import.meta.dirname, "tokens.css"), "utf8");
const dart = readFileSync(
  resolve(import.meta.dirname, "../../../lib/src/shared/theme/app_theme.dart"),
  "utf8"
);

function cssHex(name: string): string {
  const match = css.match(new RegExp(`${name}:\\s*(#[0-9a-fA-F]{6})`));
  if (!match) throw new Error(`Token ${name} não encontrado em tokens.css`);
  return match[1].toLowerCase();
}

function dartHex(pattern: RegExp): string {
  const match = dart.match(pattern);
  if (!match) throw new Error(`Cor não encontrada em app_theme.dart: ${pattern}`);
  return `#${match[1].toLowerCase()}`;
}

const hex = "([0-9A-Fa-f]{6})";
const cases: [string, RegExp][] = [
  ["--ipe-primary", new RegExp(`const primary = Color\\(0xFF${hex}\\)`)],
  ["--ipe-background", new RegExp(`const background = Color\\(0xFF${hex}\\)`)],
  ["--ipe-surface", new RegExp(`const surface = Color\\(0xFF${hex}\\)`)],
  ["--ipe-surface-elevated", new RegExp(`const surfaceElevated = Color\\(0xFF${hex}\\)`)],
  ["--ipe-secondary", new RegExp(`secondary: Color\\(0xFF${hex}\\)`)],
  ["--ipe-error", new RegExp(`error: Color\\(0xFF${hex}\\)`)],
];

describe("design tokens do portal", () => {
  it.each(cases)("%s coincide com app_theme.dart", (token, pattern) => {
    expect(cssHex(token)).toBe(dartHex(pattern));
  });
});
```

Run: `cd web-portal && npm test`
Expected: FAIL — `ENOENT ... tokens.css`.

- [ ] **Step 4: Criar os tokens e o CSS global**

Criar `web-portal/src/styles/tokens.css`:

```css
/* Tokens visuais do portal. A fonte de verdade é lib/src/shared/theme/app_theme.dart
   (conferido por tokens.test.ts). */
:root {
  --ipe-background: #0b0f19;
  --ipe-surface: #111828;
  --ipe-surface-elevated: #1b2435;
  --ipe-primary: #2f4f2f;
  --ipe-secondary: #6b8e23;
  --ipe-error: #ff5470;
  --ipe-on-surface: #ffffff;
  --ipe-on-primary: #ffffff;

  --ipe-radius-card: 18px;
  --ipe-radius-input: 18px;
  --ipe-radius-button: 18px;
  --ipe-radius-dialog: 28px;
  --ipe-radius-glass: 24px;
}
```

Substituir `web-portal/src/app/globals.css` por:

```css
@import "tailwindcss";
@import "../styles/tokens.css";

@theme inline {
  --color-background: var(--ipe-background);
  --color-surface: var(--ipe-surface);
  --color-surface-elevated: var(--ipe-surface-elevated);
  --color-primary: var(--ipe-primary);
  --color-secondary: var(--ipe-secondary);
  --color-error: var(--ipe-error);
  --color-on-surface: var(--ipe-on-surface);
  --color-on-primary: var(--ipe-on-primary);
  --radius-card: var(--ipe-radius-card);
  --radius-input: var(--ipe-radius-input);
  --radius-button: var(--ipe-radius-button);
  --radius-dialog: var(--ipe-radius-dialog);
  --radius-glass: var(--ipe-radius-glass);
}

html {
  color-scheme: dark;
}

body {
  background: var(--ipe-background);
  color: var(--ipe-on-surface);
  font-family: system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
}
```

Substituir `web-portal/src/app/layout.tsx` por:

```tsx
import type {Metadata} from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Portal de Ensino IPE",
  description: "Materiais, bibliografia e fórum para os professores da IPE.",
};

export default function RootLayout({children}: {children: React.ReactNode}) {
  return (
    <html lang="pt-BR">
      <body className="min-h-screen bg-background text-on-surface antialiased">
        {children}
      </body>
    </html>
  );
}
```

Run: `cd web-portal && npm test`
Expected: PASS nos 6 casos de tokens. (Se algum falhar, os valores do `tokens.css` divergem do app: corrija o CSS, nunca o teste.)

- [ ] **Step 5: Escrever o teste (que vai falhar) do Button**

Criar `web-portal/src/core/ui/Button.test.tsx`:

```tsx
import {fireEvent, render, screen} from "@testing-library/react";
import {describe, expect, it, vi} from "vitest";
import {Button} from "./Button";

describe("Button", () => {
  it("dispara onClick", () => {
    const onClick = vi.fn();
    render(<Button onClick={onClick}>Salvar</Button>);
    fireEvent.click(screen.getByRole("button", {name: "Salvar"}));
    expect(onClick).toHaveBeenCalledTimes(1);
  });

  it("não dispara quando desabilitado", () => {
    const onClick = vi.fn();
    render(<Button disabled onClick={onClick}>Salvar</Button>);
    fireEvent.click(screen.getByRole("button", {name: "Salvar"}));
    expect(onClick).not.toHaveBeenCalled();
  });

  it("variante primária usa os tokens do app", () => {
    render(<Button>Entrar</Button>);
    const button = screen.getByRole("button", {name: "Entrar"});
    expect(button.className).toContain("bg-primary");
    expect(button.className).toContain("rounded-button");
  });
});
```

Run: `cd web-portal && npm test -- Button`
Expected: FAIL — módulo `./Button` não existe.

- [ ] **Step 6: Implementar os componentes base**

Criar `web-portal/src/core/ui/Button.tsx`:

```tsx
import type {ButtonHTMLAttributes} from "react";

type Variant = "primary" | "text";

export function Button({
  variant = "primary",
  className = "",
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {variant?: Variant}) {
  const base =
    "inline-flex items-center justify-center font-semibold transition disabled:cursor-not-allowed disabled:opacity-50";
  const styles =
    variant === "primary"
      ? "rounded-button bg-primary px-5 py-4 text-base text-on-primary hover:brightness-125"
      : "rounded-button px-4 py-2 text-on-surface hover:bg-white/10";
  return <button className={`${base} ${styles} ${className}`} {...props} />;
}
```

Criar `web-portal/src/core/ui/Card.tsx`:

```tsx
import type {HTMLAttributes} from "react";

export function Card({className = "", ...props}: HTMLAttributes<HTMLDivElement>) {
  return <div className={`rounded-card bg-surface-elevated p-5 ${className}`} {...props} />;
}
```

Criar `web-portal/src/core/ui/GlassCard.tsx`:

```tsx
import type {HTMLAttributes} from "react";

export function GlassCard({className = "", ...props}: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={`rounded-glass border border-white/[0.08] bg-gradient-to-br from-white/[0.12] to-white/[0.04] p-5 backdrop-blur-[20px] ${className}`}
      {...props}
    />
  );
}
```

Criar `web-portal/src/core/ui/TextField.tsx`:

```tsx
import type {InputHTMLAttributes} from "react";

export function TextField({
  label,
  id,
  className = "",
  ...props
}: InputHTMLAttributes<HTMLInputElement> & {label: string; id: string}) {
  return (
    <label htmlFor={id} className="block text-sm text-white/70">
      {label}
      <input
        id={id}
        className={`mt-1 block w-full rounded-input border border-white/5 bg-surface-elevated/80 px-4 py-3 text-base text-on-surface placeholder:text-white/40 focus:border-primary focus:outline-none ${className}`}
        {...props}
      />
    </label>
  );
}
```

Remover o conteúdo de exemplo do scaffold: substituir `web-portal/src/app/page.tsx` por um componente mínimo (será trocado na Task 5):

```tsx
export default function Home() {
  return <main className="p-6">Portal de Ensino IPE</main>;
}
```

- [ ] **Step 7: Rodar testes, lint, typecheck e build**

Run: `cd web-portal && npm test && npm run lint && npm run typecheck && npm run build`
Expected: testes PASS; lint e typecheck sem erros; build conclui. (A página atual não usa Firebase, então o build não exige variáveis de ambiente ainda.)

- [ ] **Step 8: Commit**

```bash
git add web-portal
git commit -m "feat(web-portal): projeto Next.js com tokens visuais do app e componentes base

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Cliente Firebase, lógica de acesso, AuthProvider e login

**Files:**
- Create: `web-portal/.env.example`, `web-portal/src/core/firebase/client.ts`, `web-portal/src/core/auth/access.ts`, `web-portal/src/core/auth/access.test.ts`, `web-portal/src/core/auth/errors.ts`, `web-portal/src/core/auth/errors.test.ts`, `web-portal/src/core/auth/AuthContext.ts`, `web-portal/src/core/auth/AuthProvider.tsx`, `web-portal/src/core/auth/LoginForm.tsx`, `web-portal/src/app/login/page.tsx`
- Modify: `web-portal/src/app/layout.tsx` (envolver com `AuthProvider`)

**Interfaces:**
- Consumes: componentes `Button`, `GlassCard`, `TextField` e tokens da Task 3. Claims `admin` e `teaching_role` da Task 2.
- Produces (usados nas Tasks 5 e 6):
  - `type TeachingRole = "teacher" | "curator"`
  - `interface AccessClaims {admin: boolean; teachingRole: TeachingRole | null}`
  - `parseClaims(raw: Record<string, unknown> | null | undefined): AccessClaims`
  - `type AccessRequirement = "authenticated" | "teacher" | "curator" | "admin"`
  - `hasAccess(claims: AccessClaims | null, requirement: AccessRequirement): boolean` (admin é superconjunto; `claims === null` nega tudo)
  - `type AuthState = {status: "loading"} | {status: "signedOut"} | {status: "signedIn"; user: User; claims: AccessClaims}`
  - `AuthContext`, `useAuth(): {state: AuthState; refreshAccess(): Promise<void>; signOut(): Promise<void>}` (em `AuthContext.ts`, sem importar o Firebase)
  - `AuthProvider({children})` (em `AuthProvider.tsx`)
  - `authErrorMessage(code: string): string`
  - `db`, `auth`, `storage` exportados de `src/core/firebase/client.ts`

- [ ] **Step 1: Escrever os testes (que vão falhar) de acesso**

Criar `web-portal/src/core/auth/access.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {hasAccess, parseClaims, type AccessClaims} from "./access";

const none: AccessClaims = {admin: false, teachingRole: null};
const teacher: AccessClaims = {admin: false, teachingRole: "teacher"};
const curator: AccessClaims = {admin: false, teachingRole: "curator"};
const admin: AccessClaims = {admin: true, teachingRole: null};

describe("parseClaims", () => {
  it("sem claims (conta sem papel) não dá acesso", () => {
    expect(parseClaims(undefined)).toEqual(none);
    expect(parseClaims(null)).toEqual(none);
    expect(parseClaims({})).toEqual(none);
  });

  it("lê admin e teaching_role válidos", () => {
    expect(parseClaims({admin: true})).toEqual(admin);
    expect(parseClaims({teaching_role: "teacher"})).toEqual(teacher);
    expect(parseClaims({teaching_role: "curator", admin: true})).toEqual({admin: true, teachingRole: "curator"});
  });

  it("ignora valores inválidos ou de tipo errado", () => {
    expect(parseClaims({teaching_role: "god"})).toEqual(none);
    expect(parseClaims({teaching_role: 1, admin: "true"})).toEqual(none);
  });
});

describe("hasAccess", () => {
  it("sem claims (deslogado) nega tudo", () => {
    for (const req of ["authenticated", "teacher", "curator", "admin"] as const) {
      expect(hasAccess(null, req)).toBe(false);
    }
  });

  it("logado sem papel só passa em 'authenticated'", () => {
    expect(hasAccess(none, "authenticated")).toBe(true);
    expect(hasAccess(none, "teacher")).toBe(false);
    expect(hasAccess(none, "curator")).toBe(false);
    expect(hasAccess(none, "admin")).toBe(false);
  });

  it("professor passa em teacher, não em curator nem admin", () => {
    expect(hasAccess(teacher, "teacher")).toBe(true);
    expect(hasAccess(teacher, "curator")).toBe(false);
    expect(hasAccess(teacher, "admin")).toBe(false);
  });

  it("curador passa em teacher e curator, não em admin", () => {
    expect(hasAccess(curator, "teacher")).toBe(true);
    expect(hasAccess(curator, "curator")).toBe(true);
    expect(hasAccess(curator, "admin")).toBe(false);
  });

  it("admin é superconjunto: passa em tudo", () => {
    for (const req of ["authenticated", "teacher", "curator", "admin"] as const) {
      expect(hasAccess(admin, req)).toBe(true);
    }
  });
});
```

Criar `web-portal/src/core/auth/errors.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {authErrorMessage} from "./errors";

describe("authErrorMessage", () => {
  it("credenciais erradas", () => {
    expect(authErrorMessage("auth/invalid-credential")).toBe("E-mail ou senha incorretos.");
    expect(authErrorMessage("auth/wrong-password")).toBe("E-mail ou senha incorretos.");
    expect(authErrorMessage("auth/user-not-found")).toBe("E-mail ou senha incorretos.");
  });

  it("muitas tentativas, popup fechado e rede", () => {
    expect(authErrorMessage("auth/too-many-requests")).toBe("Muitas tentativas. Tente novamente em alguns minutos.");
    expect(authErrorMessage("auth/popup-closed-by-user")).toBe("Login cancelado.");
    expect(authErrorMessage("auth/network-request-failed")).toBe("Sem conexão. Verifique sua internet.");
  });

  it("código desconhecido cai na mensagem genérica", () => {
    expect(authErrorMessage("auth/qualquer-coisa")).toBe("Não foi possível entrar. Tente novamente.");
  });
});
```

Run: `cd web-portal && npm test -- auth`
Expected: FAIL — módulos `./access` e `./errors` não existem.

- [ ] **Step 2: Implementar `access.ts` e `errors.ts`**

Criar `web-portal/src/core/auth/access.ts`:

```ts
export type TeachingRole = "teacher" | "curator";

export interface AccessClaims {
  admin: boolean;
  teachingRole: TeachingRole | null;
}

export type AccessRequirement = "authenticated" | "teacher" | "curator" | "admin";

export function parseClaims(
  raw: Record<string, unknown> | null | undefined
): AccessClaims {
  const role = raw?.teaching_role;
  return {
    admin: raw?.admin === true,
    teachingRole: role === "teacher" || role === "curator" ? role : null,
  };
}

/** `claims === null` significa deslogado. Admin é superconjunto de tudo. */
export function hasAccess(
  claims: AccessClaims | null,
  requirement: AccessRequirement
): boolean {
  if (claims === null) return false;
  if (claims.admin) return true;
  switch (requirement) {
    case "authenticated":
      return true;
    case "teacher":
      return claims.teachingRole === "teacher" || claims.teachingRole === "curator";
    case "curator":
      return claims.teachingRole === "curator";
    case "admin":
      return false;
  }
}
```

Criar `web-portal/src/core/auth/errors.ts`:

```ts
export function authErrorMessage(code: string): string {
  switch (code) {
    case "auth/invalid-credential":
    case "auth/wrong-password":
    case "auth/user-not-found":
      return "E-mail ou senha incorretos.";
    case "auth/too-many-requests":
      return "Muitas tentativas. Tente novamente em alguns minutos.";
    case "auth/popup-closed-by-user":
      return "Login cancelado.";
    case "auth/network-request-failed":
      return "Sem conexão. Verifique sua internet.";
    default:
      return "Não foi possível entrar. Tente novamente.";
  }
}
```

Run: `cd web-portal && npm test -- auth`
Expected: PASS.

- [ ] **Step 3: Cliente Firebase e variáveis de ambiente**

Registrar o app web no projeto Firebase (cria um recurso no projeto `app-ipe`; **confirme com o usuário antes de rodar**) e obter a configuração:

```bash
firebase apps:create WEB "Portal de Ensino IPE" --project app-ipe
firebase apps:sdkconfig WEB <APP_ID_RETORNADO> --project app-ipe
```

Criar `web-portal/.env.example`:

```
NEXT_PUBLIC_FIREBASE_API_KEY=
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=app-ipe.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=app-ipe
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=890190525302
NEXT_PUBLIC_FIREBASE_APP_ID=
```

Copiar para `web-portal/.env.local` (já ignorado pelo scaffold) e preencher `API_KEY`, `STORAGE_BUCKET` e `APP_ID` com a saída do `sdkconfig`.

Criar `web-portal/src/core/firebase/client.ts`:

```ts
import {getApp, getApps, initializeApp} from "firebase/app";
import {getAuth} from "firebase/auth";
import {getFirestore} from "firebase/firestore";
import {getStorage} from "firebase/storage";

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

const app = getApps().length ? getApp() : initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);
```

- [ ] **Step 4: Contexto e provider de autenticação**

Criar `web-portal/src/core/auth/AuthContext.ts` (sem importar o Firebase, para os testes não inicializarem o SDK):

```ts
import type {User} from "firebase/auth";
import {createContext, useContext} from "react";
import type {AccessClaims} from "./access";

export type AuthState =
  | {status: "loading"}
  | {status: "signedOut"}
  | {status: "signedIn"; user: User; claims: AccessClaims};

export interface AuthContextValue {
  state: AuthState;
  /** Renova o token e relê as claims (use depois que um admin mudar o papel). */
  refreshAccess: () => Promise<void>;
  signOut: () => Promise<void>;
}

export const AuthContext = createContext<AuthContextValue | null>(null);

export function useAuth(): AuthContextValue {
  const value = useContext(AuthContext);
  if (!value) throw new Error("useAuth deve ser usado dentro de AuthProvider");
  return value;
}
```

Criar `web-portal/src/core/auth/AuthProvider.tsx`:

```tsx
"use client";

import {onAuthStateChanged, signOut as firebaseSignOut} from "firebase/auth";
import {useCallback, useEffect, useMemo, useState, type ReactNode} from "react";
import {auth} from "@/core/firebase/client";
import {parseClaims} from "./access";
import {AuthContext, type AuthState} from "./AuthContext";

export function AuthProvider({children}: {children: ReactNode}) {
  const [state, setState] = useState<AuthState>({status: "loading"});

  useEffect(() => {
    return onAuthStateChanged(auth, async (user) => {
      if (!user) {
        setState({status: "signedOut"});
        return;
      }
      try {
        // Força a renovação para pegar claims recém-atribuídas por um admin.
        const token = await user.getIdTokenResult(true);
        setState({status: "signedIn", user, claims: parseClaims(token.claims)});
      } catch {
        setState({status: "signedIn", user, claims: parseClaims(undefined)});
      }
    });
  }, []);

  const refreshAccess = useCallback(async () => {
    const user = auth.currentUser;
    if (!user) return;
    const token = await user.getIdTokenResult(true);
    setState({status: "signedIn", user, claims: parseClaims(token.claims)});
  }, []);

  const signOut = useCallback(() => firebaseSignOut(auth), []);

  const value = useMemo(
    () => ({state, refreshAccess, signOut}),
    [state, refreshAccess, signOut]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
```

Em `web-portal/src/app/layout.tsx`, importar `AuthProvider` e envolver `{children}`:

```tsx
import {AuthProvider} from "@/core/auth/AuthProvider";
// ...
      <body className="min-h-screen bg-background text-on-surface antialiased">
        <AuthProvider>{children}</AuthProvider>
      </body>
```

- [ ] **Step 5: Tela de login**

Criar `web-portal/src/core/auth/LoginForm.tsx`:

```tsx
"use client";

import {
  GoogleAuthProvider,
  signInWithEmailAndPassword,
  signInWithPopup,
} from "firebase/auth";
import {useRouter} from "next/navigation";
import {useEffect, useState, type FormEvent} from "react";
import {auth} from "@/core/firebase/client";
import {Button} from "@/core/ui/Button";
import {GlassCard} from "@/core/ui/GlassCard";
import {TextField} from "@/core/ui/TextField";
import {useAuth} from "./AuthContext";
import {authErrorMessage} from "./errors";

export function LoginForm() {
  const router = useRouter();
  const {state} = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (state.status === "signedIn") router.replace("/");
  }, [state.status, router]);

  async function run(action: () => Promise<unknown>) {
    setBusy(true);
    setError(null);
    try {
      await action();
    } catch (e) {
      setError(authErrorMessage((e as {code?: string}).code ?? ""));
    } finally {
      setBusy(false);
    }
  }

  function onSubmit(event: FormEvent) {
    event.preventDefault();
    void run(() => signInWithEmailAndPassword(auth, email.trim(), password));
  }

  return (
    <GlassCard className="w-full max-w-sm">
      <h1 className="mb-1 text-2xl font-semibold">Portal de Ensino</h1>
      <p className="mb-6 text-sm text-white/70">
        Entre com a mesma conta do app IPE.
      </p>
      <form onSubmit={onSubmit} className="space-y-4">
        <TextField id="email" label="E-mail" type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        <TextField id="password" label="Senha" type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
        {error && <p role="alert" className="text-sm text-error">{error}</p>}
        <Button type="submit" disabled={busy} className="w-full">Entrar</Button>
      </form>
      <Button
        type="button"
        variant="text"
        disabled={busy}
        className="mt-3 w-full"
        onClick={() => run(() => signInWithPopup(auth, new GoogleAuthProvider()))}
      >
        Entrar com Google
      </Button>
    </GlassCard>
  );
}
```

Criar `web-portal/src/app/login/page.tsx`:

```tsx
import {LoginForm} from "@/core/auth/LoginForm";

export default function LoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center p-6">
      <LoginForm />
    </main>
  );
}
```

- [ ] **Step 6: Verificar tipos, lint, testes e login manual**

Run: `cd web-portal && npm test && npm run lint && npm run typecheck && npm run build`
Expected: testes PASS; lint/typecheck sem erros; build conclui (exige o `.env.local` do Step 3).

Verificação manual: `cd web-portal && npm run dev`, abrir `http://localhost:3000/login`, entrar com uma conta existente do app. Esperado: o login funciona e a página redireciona para `/` (a rota `/` ainda mostra o texto provisório, será trocada na Task 5). Em caso de erro de "domínio não autorizado", conferir no console do Firebase (Authentication → Settings → Authorized domains) que `localhost` está listado.

- [ ] **Step 7: Commit**

```bash
git add web-portal/.env.example web-portal/src
git commit -m "feat(web-portal): cliente Firebase, lógica de acesso por claims, AuthProvider e login

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Casca modular, guarda de acesso e módulo de ensino

**Files:**
- Create: `web-portal/src/core/modules/types.ts`, `web-portal/src/core/modules/registry.ts`, `web-portal/src/core/modules/registry.test.ts`, `web-portal/src/core/ui/AccessDenied.tsx`, `web-portal/src/core/ui/PortalShell.tsx`, `web-portal/src/core/ui/PortalShell.test.tsx`, `web-portal/src/modules/teaching/module.ts`, `web-portal/src/modules/teaching/pages/TeachingHomePage.tsx`, `web-portal/src/app/(portal)/layout.tsx`, `web-portal/src/app/(portal)/page.tsx`, `web-portal/src/app/(portal)/ensino/page.tsx`
- Delete: `web-portal/src/app/page.tsx` (a rota `/` passa a ser `(portal)/page.tsx`)

**Interfaces:**
- Consumes: `AccessClaims`, `AccessRequirement`, `hasAccess` (Task 4); `AuthContext`, `useAuth` (Task 4); `Button`, `Card`, `GlassCard` (Task 3).
- Produces (usados na Task 6):
  - `interface NavItem {label: string; href: string; access: AccessRequirement}`
  - `interface PortalModule {id: string; label: string; basePath: string; access: AccessRequirement; navItems: NavItem[]}`
  - `interface NavGroup {moduleId: string; label: string; items: NavItem[]}`
  - `visibleNavGroups(modules: PortalModule[], claims: AccessClaims | null): NavGroup[]`
  - `isPathAllowed(modules: PortalModule[], pathname: string, claims: AccessClaims | null): boolean`
  - `defaultLandingPath(modules: PortalModule[], claims: AccessClaims | null): string | null`
  - `portalModules: PortalModule[]`
  - `teachingModule: PortalModule` (rotas `/ensino` → `teacher`, `/ensino/admin` → `admin`)
  - `<PortalShell modules?>`, `<AccessDenied />`

- [ ] **Step 1: Escrever os testes (que vão falhar) do registro de módulos**

Criar `web-portal/src/core/modules/registry.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import type {AccessClaims} from "@/core/auth/access";
import {defaultLandingPath, isPathAllowed, visibleNavGroups} from "./registry";
import type {PortalModule} from "./types";

const modules: PortalModule[] = [
  {
    id: "teaching",
    label: "Ensino",
    basePath: "/ensino",
    access: "teacher",
    navItems: [
      {label: "Início", href: "/ensino", access: "teacher"},
      {label: "Grupo", href: "/ensino/admin", access: "admin"},
    ],
  },
  {
    id: "members",
    label: "Membros",
    basePath: "/membros",
    access: "admin",
    navItems: [{label: "Lista", href: "/membros", access: "admin"}],
  },
];

const none: AccessClaims = {admin: false, teachingRole: null};
const teacher: AccessClaims = {admin: false, teachingRole: "teacher"};
const admin: AccessClaims = {admin: true, teachingRole: null};

describe("visibleNavGroups", () => {
  it("sem papel não vê nenhum módulo", () => {
    expect(visibleNavGroups(modules, none)).toEqual([]);
    expect(visibleNavGroups(modules, null)).toEqual([]);
  });

  it("professor vê só o que seu papel permite dentro do módulo", () => {
    const groups = visibleNavGroups(modules, teacher);
    expect(groups.map((g) => g.moduleId)).toEqual(["teaching"]);
    expect(groups[0].items.map((i) => i.href)).toEqual(["/ensino"]);
  });

  it("admin vê todos os módulos e itens", () => {
    const groups = visibleNavGroups(modules, admin);
    expect(groups.map((g) => g.moduleId)).toEqual(["teaching", "members"]);
    expect(groups[0].items.map((i) => i.href)).toEqual(["/ensino", "/ensino/admin"]);
  });
});

describe("isPathAllowed", () => {
  it("rota fora de qualquer módulo exige apenas estar logado", () => {
    expect(isPathAllowed(modules, "/", none)).toBe(true);
    expect(isPathAllowed(modules, "/", null)).toBe(false);
  });

  it("professor acessa /ensino mas não /ensino/admin", () => {
    expect(isPathAllowed(modules, "/ensino", teacher)).toBe(true);
    expect(isPathAllowed(modules, "/ensino/admin", teacher)).toBe(false);
  });

  it("usa o item mais específico e respeita o acesso do módulo", () => {
    expect(isPathAllowed(modules, "/ensino/admin", admin)).toBe(true);
    expect(isPathAllowed(modules, "/ensino/outra-pagina", teacher)).toBe(true);
    expect(isPathAllowed(modules, "/ensino/outra-pagina", none)).toBe(false);
    expect(isPathAllowed(modules, "/membros", teacher)).toBe(false);
  });

  it("não confunde prefixos parecidos (/ensinoX)", () => {
    expect(isPathAllowed(modules, "/ensinoX", none)).toBe(true);
  });
});

describe("defaultLandingPath", () => {
  it("devolve o primeiro item visível ou null", () => {
    expect(defaultLandingPath(modules, teacher)).toBe("/ensino");
    expect(defaultLandingPath(modules, none)).toBeNull();
  });
});
```

Run: `cd web-portal && npm test -- registry`
Expected: FAIL — `./registry` e `./types` não existem.

- [ ] **Step 2: Implementar tipos, registro e módulo de ensino**

Criar `web-portal/src/core/modules/types.ts`:

```ts
import type {AccessRequirement} from "@/core/auth/access";

export interface NavItem {
  label: string;
  href: string;
  access: AccessRequirement;
}

/**
 * Um módulo do portal (ensino, e no futuro membros, eventos etc.).
 * Para adicionar um módulo: criar src/modules/<id>/module.ts com este tipo,
 * registrá-lo em registry.ts e criar as rotas finas em src/app/(portal)/.
 */
export interface PortalModule {
  id: string;
  label: string;
  basePath: string;
  access: AccessRequirement;
  navItems: NavItem[];
}

export interface NavGroup {
  moduleId: string;
  label: string;
  items: NavItem[];
}
```

Criar `web-portal/src/modules/teaching/module.ts`:

```ts
import type {PortalModule} from "@/core/modules/types";

export const teachingModule: PortalModule = {
  id: "teaching",
  label: "Ensino",
  basePath: "/ensino",
  access: "teacher",
  navItems: [
    {label: "Início", href: "/ensino", access: "teacher"},
    {label: "Grupo de professores", href: "/ensino/admin", access: "admin"},
  ],
};
```

Criar `web-portal/src/core/modules/registry.ts`:

```ts
import {hasAccess, type AccessClaims} from "@/core/auth/access";
import {teachingModule} from "@/modules/teaching/module";
import type {NavGroup, PortalModule} from "./types";

export const portalModules: PortalModule[] = [teachingModule];

function isUnder(pathname: string, base: string): boolean {
  return pathname === base || pathname.startsWith(`${base}/`);
}

export function visibleNavGroups(
  modules: PortalModule[],
  claims: AccessClaims | null
): NavGroup[] {
  const groups: NavGroup[] = [];
  for (const mod of modules) {
    if (!hasAccess(claims, mod.access)) continue;
    const items = mod.navItems.filter((item) => hasAccess(claims, item.access));
    if (items.length > 0) {
      groups.push({moduleId: mod.id, label: mod.label, items});
    }
  }
  return groups;
}

export function isPathAllowed(
  modules: PortalModule[],
  pathname: string,
  claims: AccessClaims | null
): boolean {
  const mod = modules.find((m) => isUnder(pathname, m.basePath));
  if (!mod) return hasAccess(claims, "authenticated");
  if (!hasAccess(claims, mod.access)) return false;
  const item = mod.navItems
    .filter((i) => isUnder(pathname, i.href))
    .sort((a, b) => b.href.length - a.href.length)[0];
  return item ? hasAccess(claims, item.access) : true;
}

export function defaultLandingPath(
  modules: PortalModule[],
  claims: AccessClaims | null
): string | null {
  return visibleNavGroups(modules, claims)[0]?.items[0]?.href ?? null;
}
```

Run: `cd web-portal && npm test -- registry`
Expected: PASS.

- [ ] **Step 3: Escrever os testes (que vão falhar) da guarda `PortalShell`**

Criar `web-portal/src/core/ui/PortalShell.test.tsx`:

```tsx
import {fireEvent, render, screen} from "@testing-library/react";
import type {User} from "firebase/auth";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {AccessClaims} from "@/core/auth/access";
import {AuthContext, type AuthState} from "@/core/auth/AuthContext";
import {teachingModule} from "@/modules/teaching/module";
import {PortalShell} from "./PortalShell";

const nav = vi.hoisted(() => ({path: "/", replace: vi.fn()}));

vi.mock("next/navigation", () => ({
  usePathname: () => nav.path,
  useRouter: () => ({replace: nav.replace}),
}));

const refreshAccess = vi.fn().mockResolvedValue(undefined);
const signOut = vi.fn().mockResolvedValue(undefined);
const user = {displayName: "Ana", email: "ana@ipe.org"} as User;

function renderAt(path: string, state: AuthState) {
  nav.path = path;
  return render(
    <AuthContext.Provider value={{state, refreshAccess, signOut}}>
      <PortalShell modules={[teachingModule]}>
        <p>conteúdo da página</p>
      </PortalShell>
    </AuthContext.Provider>
  );
}

const signedIn = (claims: AccessClaims): AuthState => ({status: "signedIn", user, claims});
const noRole: AccessClaims = {admin: false, teachingRole: null};
const teacher: AccessClaims = {admin: false, teachingRole: "teacher"};
const admin: AccessClaims = {admin: true, teachingRole: null};

beforeEach(() => {
  nav.replace.mockClear();
  refreshAccess.mockClear();
});

describe("PortalShell", () => {
  it("mostra carregando enquanto resolve a sessão", () => {
    renderAt("/ensino", {status: "loading"});
    expect(screen.getByText("Carregando…")).toBeInTheDocument();
    expect(screen.queryByText("conteúdo da página")).not.toBeInTheDocument();
  });

  it("deslogado é enviado para /login", () => {
    renderAt("/ensino", {status: "signedOut"});
    expect(nav.replace).toHaveBeenCalledWith("/login");
    expect(screen.queryByText("conteúdo da página")).not.toBeInTheDocument();
  });

  it("conta sem papel vê acesso restrito (nunca tela em branco ou erro)", () => {
    renderAt("/ensino", signedIn(noRole));
    expect(screen.getByText(/acesso restrito ao grupo de professores/i)).toBeInTheDocument();
    expect(screen.queryByText("conteúdo da página")).not.toBeInTheDocument();
  });

  it("'Verificar acesso novamente' renova o token", () => {
    renderAt("/ensino", signedIn(noRole));
    fireEvent.click(screen.getByRole("button", {name: "Verificar acesso novamente"}));
    expect(refreshAccess).toHaveBeenCalledTimes(1);
  });

  it("professor vê o conteúdo em /ensino, mas não em /ensino/admin", () => {
    renderAt("/ensino", signedIn(teacher));
    expect(screen.getByText("conteúdo da página")).toBeInTheDocument();
    cleanupAndRender("/ensino/admin", signedIn(teacher));
    expect(screen.queryByText("conteúdo da página")).not.toBeInTheDocument();
    expect(screen.getByText(/acesso restrito/i)).toBeInTheDocument();
  });

  it("admin vê o conteúdo em /ensino/admin e o menu completo", () => {
    renderAt("/ensino/admin", signedIn(admin));
    expect(screen.getByText("conteúdo da página")).toBeInTheDocument();
    expect(screen.getByRole("link", {name: "Grupo de professores"})).toBeInTheDocument();
  });

  it("o menu do professor não mostra itens de admin", () => {
    renderAt("/ensino", signedIn(teacher));
    expect(screen.getByRole("link", {name: "Início"})).toBeInTheDocument();
    expect(screen.queryByRole("link", {name: "Grupo de professores"})).not.toBeInTheDocument();
  });
});

function cleanupAndRender(path: string, state: AuthState) {
  document.body.innerHTML = "";
  renderAt(path, state);
}
```

Run: `cd web-portal && npm test -- PortalShell`
Expected: FAIL — `./PortalShell` não existe.

- [ ] **Step 4: Implementar `AccessDenied` e `PortalShell`**

Criar `web-portal/src/core/ui/AccessDenied.tsx`:

```tsx
"use client";

import {useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {Button} from "./Button";
import {GlassCard} from "./GlassCard";

export function AccessDenied() {
  const {refreshAccess, signOut} = useAuth();
  const [checking, setChecking] = useState(false);

  async function recheck() {
    setChecking(true);
    try {
      await refreshAccess();
    } finally {
      setChecking(false);
    }
  }

  return (
    <GlassCard className="mx-auto mt-10 max-w-lg">
      <h1 className="mb-2 text-xl font-semibold">Acesso restrito ao grupo de professores</h1>
      <p className="mb-6 text-sm text-white/70">
        Esta área é só para o grupo de professores da IPE. Se você deveria ter
        acesso, peça a um administrador que adicione você ao grupo e depois
        verifique novamente.
      </p>
      <div className="flex flex-wrap gap-2">
        <Button type="button" disabled={checking} onClick={recheck}>
          Verificar acesso novamente
        </Button>
        <Button type="button" variant="text" onClick={() => void signOut()}>
          Sair
        </Button>
      </div>
    </GlassCard>
  );
}
```

Criar `web-portal/src/core/ui/PortalShell.tsx`:

```tsx
"use client";

import Link from "next/link";
import {usePathname, useRouter} from "next/navigation";
import {useEffect, type ReactNode} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {
  isPathAllowed,
  portalModules,
  visibleNavGroups,
} from "@/core/modules/registry";
import type {PortalModule} from "@/core/modules/types";
import {AccessDenied} from "./AccessDenied";
import {Button} from "./Button";

export function PortalShell({
  children,
  modules = portalModules,
}: {
  children: ReactNode;
  modules?: PortalModule[];
}) {
  const {state, signOut} = useAuth();
  const pathname = usePathname();
  const router = useRouter();

  useEffect(() => {
    if (state.status === "signedOut") router.replace("/login");
  }, [state.status, router]);

  if (state.status !== "signedIn") {
    return <p className="p-6 text-white/70">Carregando…</p>;
  }

  const groups = visibleNavGroups(modules, state.claims);
  const allowed = isPathAllowed(modules, pathname, state.claims);

  return (
    <div className="flex min-h-screen flex-col md:flex-row">
      <aside className="border-b border-white/5 bg-surface p-4 md:min-h-screen md:w-64 md:border-b-0 md:border-r">
        <p className="mb-4 text-lg font-semibold">Portal de Ensino</p>
        <nav aria-label="Principal" className="space-y-4">
          {groups.map((group) => (
            <div key={group.moduleId}>
              <p className="mb-1 text-xs uppercase tracking-wide text-white/50">{group.label}</p>
              <ul className="space-y-1">
                {group.items.map((item) => (
                  <li key={item.href}>
                    <Link
                      href={item.href}
                      className={`block rounded-button px-3 py-2 text-sm hover:bg-white/10 ${
                        pathname === item.href ? "bg-primary/30 font-semibold" : ""
                      }`}
                    >
                      {item.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </nav>
        <div className="mt-6 border-t border-white/5 pt-4 text-sm">
          <p className="truncate text-white/70">{state.user.displayName ?? state.user.email}</p>
          <Button type="button" variant="text" className="mt-1 px-0" onClick={() => void signOut()}>
            Sair
          </Button>
        </div>
      </aside>
      <main className="flex-1 p-6">{allowed ? children : <AccessDenied />}</main>
    </div>
  );
}
```

Run: `cd web-portal && npm test -- PortalShell`
Expected: PASS. (O texto "Carregando…" também cobre `signedOut` enquanto o redirecionamento acontece; o teste de "loading" só verifica esse texto.)

- [ ] **Step 5: Rotas finas e página inicial do módulo**

Criar `web-portal/src/modules/teaching/pages/TeachingHomePage.tsx`:

```tsx
"use client";

import Link from "next/link";
import {useAuth} from "@/core/auth/AuthContext";
import {Card} from "@/core/ui/Card";

export default function TeachingHomePage() {
  const {state} = useAuth();
  if (state.status !== "signedIn") return null;
  const {claims, user} = state;
  const roleLabel = claims.admin
    ? "Administrador"
    : claims.teachingRole === "curator"
      ? "Curador"
      : "Professor";

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Olá, {user.displayName ?? user.email}</h1>
      <p className="text-white/70">Seu papel no grupo: {roleLabel}</p>
      <Card>
        <h2 className="font-semibold">Biblioteca de materiais</h2>
        <p className="text-sm text-white/70">Em breve: aulas, planos e bibliografia por faixa etária.</p>
      </Card>
      <Card>
        <h2 className="font-semibold">Fórum</h2>
        <p className="text-sm text-white/70">Em breve: dúvidas e conversas entre os professores.</p>
      </Card>
      {claims.admin && (
        <Link href="/ensino/admin" className="text-secondary underline">
          Gerenciar o grupo de professores
        </Link>
      )}
    </div>
  );
}
```

Criar `web-portal/src/app/(portal)/layout.tsx`:

```tsx
import {PortalShell} from "@/core/ui/PortalShell";

export default function PortalLayout({children}: {children: React.ReactNode}) {
  return <PortalShell>{children}</PortalShell>;
}
```

Criar `web-portal/src/app/(portal)/ensino/page.tsx`:

```tsx
export {default} from "@/modules/teaching/pages/TeachingHomePage";
```

Remover `web-portal/src/app/page.tsx` e criar `web-portal/src/app/(portal)/page.tsx`:

```tsx
"use client";

import {useRouter} from "next/navigation";
import {useEffect} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {defaultLandingPath, portalModules} from "@/core/modules/registry";
import {AccessDenied} from "@/core/ui/AccessDenied";

export default function HomeRedirect() {
  const {state} = useAuth();
  const router = useRouter();
  const target =
    state.status === "signedIn" ? defaultLandingPath(portalModules, state.claims) : null;

  useEffect(() => {
    if (target) router.replace(target);
  }, [target, router]);

  if (state.status === "signedIn" && !target) return <AccessDenied />;
  return null;
}
```

A rota `/ensino/admin` é criada na Task 6.

- [ ] **Step 6: Rodar testes, lint, typecheck e build**

Run: `cd web-portal && npm test && npm run lint && npm run typecheck && npm run build`
Expected: tudo PASS e build conclui.

Verificação manual: `npm run dev`; entrar com uma conta **sem** papel. Esperado: tela "Acesso restrito ao grupo de professores" com o menu vazio.

- [ ] **Step 7: Commit**

```bash
git add web-portal/src
git commit -m "feat(web-portal): casca modular com guarda de acesso e módulo de ensino

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Administração do grupo de professores

**Files:**
- Create: `web-portal/src/modules/teaching/data/memberRows.ts`, `web-portal/src/modules/teaching/data/memberRows.test.ts`, `web-portal/src/modules/teaching/data/membersRepository.ts`, `web-portal/src/modules/teaching/pages/GroupAdminPage.tsx`, `web-portal/src/modules/teaching/pages/GroupAdminPage.test.tsx`, `web-portal/src/app/(portal)/ensino/admin/page.tsx`

**Interfaces:**
- Consumes: `db` (Task 4), `Card`/`TextField`/`Button` (Task 3), rota `/ensino/admin` protegida por `admin` (Task 5). Campos de `users/{uid}`: `name`, `email`, `is_admin`, `is_pending`, `teaching_role`.
- Produces:
  - `type TeachingRoleValue = "none" | "teacher" | "curator"`
  - `interface MemberRow {id: string; name: string; email: string; teachingRole: TeachingRoleValue; isAdmin: boolean; isPending: boolean}`
  - `toMemberRow(id: string, data: Record<string, unknown>): MemberRow`
  - `filterMembers(rows: MemberRow[], term: string): MemberRow[]`
  - `ROLE_LABELS: Record<TeachingRoleValue, string>`
  - `listMembers(): Promise<MemberRow[]>` e `setTeachingRole(uid: string, role: TeachingRoleValue): Promise<void>` (em `membersRepository.ts`)

- [ ] **Step 1: Escrever os testes (que vão falhar) da lógica pura**

Criar `web-portal/src/modules/teaching/data/memberRows.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {filterMembers, toMemberRow, type MemberRow} from "./memberRows";

describe("toMemberRow", () => {
  it("mapeia os campos do documento", () => {
    expect(
      toMemberRow("u1", {name: "Ana", email: "ana@ipe.org", is_admin: true, is_pending: false, teaching_role: "curator"})
    ).toEqual({id: "u1", name: "Ana", email: "ana@ipe.org", isAdmin: true, isPending: false, teachingRole: "curator"});
  });

  it("aplica padrões quando faltam campos", () => {
    expect(toMemberRow("u2", {})).toEqual({
      id: "u2", name: "(sem nome)", email: "", isAdmin: false, isPending: false, teachingRole: "none",
    });
  });

  it("papel inválido vira 'none'", () => {
    expect(toMemberRow("u3", {teaching_role: "god"}).teachingRole).toBe("none");
  });
});

describe("filterMembers", () => {
  const rows: MemberRow[] = [
    {id: "1", name: "José Ávila", email: "jose@ipe.org", isAdmin: false, isPending: false, teachingRole: "none"},
    {id: "2", name: "Maria", email: "maria@exemplo.com", isAdmin: false, isPending: false, teachingRole: "teacher"},
  ];

  it("termo vazio devolve todos", () => {
    expect(filterMembers(rows, "  ")).toHaveLength(2);
  });

  it("busca por nome ou e-mail, sem diferenciar maiúsculas nem acentos", () => {
    expect(filterMembers(rows, "jose").map((r) => r.id)).toEqual(["1"]);
    expect(filterMembers(rows, "ÁVILA").map((r) => r.id)).toEqual(["1"]);
    expect(filterMembers(rows, "exemplo.com").map((r) => r.id)).toEqual(["2"]);
  });

  it("sem resultado devolve lista vazia", () => {
    expect(filterMembers(rows, "zzz")).toEqual([]);
  });
});
```

Run: `cd web-portal && npm test -- memberRows`
Expected: FAIL — `./memberRows` não existe.

- [ ] **Step 2: Implementar a lógica pura e o repositório**

Criar `web-portal/src/modules/teaching/data/memberRows.ts`:

```ts
export type TeachingRoleValue = "none" | "teacher" | "curator";

export interface MemberRow {
  id: string;
  name: string;
  email: string;
  teachingRole: TeachingRoleValue;
  isAdmin: boolean;
  isPending: boolean;
}

export const ROLE_LABELS: Record<TeachingRoleValue, string> = {
  none: "Sem acesso",
  teacher: "Professor",
  curator: "Curador",
};

export function toMemberRow(id: string, data: Record<string, unknown>): MemberRow {
  const role = data.teaching_role;
  return {
    id,
    name: typeof data.name === "string" && data.name ? data.name : "(sem nome)",
    email: typeof data.email === "string" ? data.email : "",
    teachingRole: role === "teacher" || role === "curator" ? role : "none",
    isAdmin: data.is_admin === true,
    isPending: data.is_pending === true,
  };
}

function normalize(text: string): string {
  return text.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase();
}

export function filterMembers(rows: MemberRow[], term: string): MemberRow[] {
  const needle = normalize(term.trim());
  if (!needle) return rows;
  return rows.filter(
    (row) => normalize(row.name).includes(needle) || normalize(row.email).includes(needle)
  );
}
```

Criar `web-portal/src/modules/teaching/data/membersRepository.ts`:

```ts
import {collection, doc, getDocs, updateDoc} from "firebase/firestore";
import {db} from "@/core/firebase/client";
import {toMemberRow, type MemberRow, type TeachingRoleValue} from "./memberRows";

export async function listMembers(): Promise<MemberRow[]> {
  const snapshot = await getDocs(collection(db, "users"));
  return snapshot.docs
    .map((d) => toMemberRow(d.id, d.data()))
    .sort((a, b) => a.name.localeCompare(b.name, "pt-BR"));
}

/** Só administradores conseguem gravar (regras do Firestore). */
export async function setTeachingRole(uid: string, role: TeachingRoleValue): Promise<void> {
  await updateDoc(doc(db, "users", uid), {teaching_role: role});
}
```

Run: `cd web-portal && npm test -- memberRows`
Expected: PASS.

- [ ] **Step 3: Escrever os testes (que vão falhar) da página**

Criar `web-portal/src/modules/teaching/pages/GroupAdminPage.test.tsx`:

```tsx
import {fireEvent, render, screen, waitFor} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {MemberRow} from "../data/memberRows";
import GroupAdminPage from "./GroupAdminPage";

const repo = vi.hoisted(() => ({
  listMembers: vi.fn(),
  setTeachingRole: vi.fn(),
}));

vi.mock("../data/membersRepository", () => repo);

const rows: MemberRow[] = [
  {id: "u1", name: "Ana", email: "ana@ipe.org", isAdmin: false, isPending: false, teachingRole: "none"},
  {id: "u2", name: "Bia", email: "bia@ipe.org", isAdmin: true, isPending: false, teachingRole: "teacher"},
];

beforeEach(() => {
  repo.listMembers.mockReset().mockResolvedValue(rows);
  repo.setTeachingRole.mockReset().mockResolvedValue(undefined);
});

describe("GroupAdminPage", () => {
  it("lista os usuários com o papel atual", async () => {
    render(<GroupAdminPage />);
    expect(await screen.findByText("Ana")).toBeInTheDocument();
    expect(screen.getByLabelText("Papel de Ana")).toHaveValue("none");
    expect(screen.getByLabelText("Papel de Bia")).toHaveValue("teacher");
    expect(screen.getByText("Admin")).toBeInTheDocument();
  });

  it("filtra pela busca", async () => {
    render(<GroupAdminPage />);
    await screen.findByText("Ana");
    fireEvent.change(screen.getByLabelText("Buscar por nome ou e-mail"), {target: {value: "bia"}});
    expect(screen.queryByText("Ana")).not.toBeInTheDocument();
    expect(screen.getByText("Bia")).toBeInTheDocument();
  });

  it("muda o papel e grava", async () => {
    render(<GroupAdminPage />);
    await screen.findByText("Ana");
    fireEvent.change(screen.getByLabelText("Papel de Ana"), {target: {value: "curator"}});
    await waitFor(() => expect(repo.setTeachingRole).toHaveBeenCalledWith("u1", "curator"));
    expect(screen.getByLabelText("Papel de Ana")).toHaveValue("curator");
  });

  it("se a gravação falha, volta ao papel anterior e avisa", async () => {
    repo.setTeachingRole.mockRejectedValue(new Error("permission-denied"));
    render(<GroupAdminPage />);
    await screen.findByText("Ana");
    fireEvent.change(screen.getByLabelText("Papel de Ana"), {target: {value: "teacher"}});
    expect(await screen.findByRole("alert")).toHaveTextContent(
      "Não foi possível salvar o papel de Ana. Tente novamente."
    );
    expect(screen.getByLabelText("Papel de Ana")).toHaveValue("none");
  });

  it("mostra erro quando a lista não carrega", async () => {
    repo.listMembers.mockRejectedValue(new Error("offline"));
    render(<GroupAdminPage />);
    expect(await screen.findByRole("alert")).toHaveTextContent("Não foi possível carregar os usuários.");
  });
});
```

Run: `cd web-portal && npm test -- GroupAdminPage`
Expected: FAIL — `./GroupAdminPage` não existe.

- [ ] **Step 4: Implementar a página e a rota**

Criar `web-portal/src/modules/teaching/pages/GroupAdminPage.tsx`:

```tsx
"use client";

import {useEffect, useMemo, useState} from "react";
import {Card} from "@/core/ui/Card";
import {TextField} from "@/core/ui/TextField";
import {
  ROLE_LABELS,
  filterMembers,
  type MemberRow,
  type TeachingRoleValue,
} from "../data/memberRows";
import {listMembers, setTeachingRole} from "../data/membersRepository";

export default function GroupAdminPage() {
  const [members, setMembers] = useState<MemberRow[] | null>(null);
  const [term, setTerm] = useState("");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    listMembers()
      .then((rows) => active && setMembers(rows))
      .catch(() => active && setError("Não foi possível carregar os usuários."));
    return () => {
      active = false;
    };
  }, []);

  const visible = useMemo(() => filterMembers(members ?? [], term), [members, term]);

  function patch(id: string, role: TeachingRoleValue) {
    setMembers((current) =>
      current?.map((m) => (m.id === id ? {...m, teachingRole: role} : m)) ?? null
    );
  }

  async function onChangeRole(member: MemberRow, role: TeachingRoleValue) {
    const previous = member.teachingRole;
    setError(null);
    patch(member.id, role);
    try {
      await setTeachingRole(member.id, role);
    } catch {
      patch(member.id, previous);
      setError(`Não foi possível salvar o papel de ${member.name}. Tente novamente.`);
    }
  }

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-semibold">Grupo de professores</h1>
      <p className="text-sm text-white/70">
        Defina quem faz parte do grupo. A mudança vale quando a pessoa abrir ou
        recarregar o portal (ou usar &quot;Verificar acesso novamente&quot;).
      </p>
      <TextField
        id="search"
        label="Buscar por nome ou e-mail"
        value={term}
        onChange={(e) => setTerm(e.target.value)}
      />
      {error && <p role="alert" className="text-sm text-error">{error}</p>}
      {members === null && !error && <p className="text-white/70">Carregando…</p>}
      <ul className="space-y-2">
        {visible.map((member) => (
          <li key={member.id}>
            <Card className="flex flex-wrap items-center justify-between gap-3">
              <div>
                <p className="font-semibold">{member.name}</p>
                <p className="text-sm text-white/70">{member.email}</p>
                <div className="mt-1 flex gap-2 text-xs">
                  {member.isAdmin && <span className="rounded-button bg-primary/40 px-2 py-0.5">Admin</span>}
                  {member.isPending && <span className="rounded-button bg-white/10 px-2 py-0.5">Pendente</span>}
                </div>
              </div>
              <select
                aria-label={`Papel de ${member.name}`}
                value={member.teachingRole}
                onChange={(e) => void onChangeRole(member, e.target.value as TeachingRoleValue)}
                className="rounded-input border border-white/5 bg-surface px-3 py-2 text-on-surface focus:border-primary focus:outline-none"
              >
                {(Object.keys(ROLE_LABELS) as TeachingRoleValue[]).map((role) => (
                  <option key={role} value={role}>{ROLE_LABELS[role]}</option>
                ))}
              </select>
            </Card>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

Criar `web-portal/src/app/(portal)/ensino/admin/page.tsx`:

```tsx
export {default} from "@/modules/teaching/pages/GroupAdminPage";
```

- [ ] **Step 5: Rodar testes, lint, typecheck e build**

Run: `cd web-portal && npm test && npm run lint && npm run typecheck && npm run build`
Expected: tudo PASS e build conclui.

- [ ] **Step 6: Commit**

```bash
git add web-portal/src
git commit -m "feat(web-portal): administração do grupo de professores

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: README, deploy e verificação ponta a ponta

**Files:**
- Create: `web-portal/README.md`

**Interfaces:**
- Consumes: tudo das Tasks 1 a 6.
- Produces: portal em preview na Vercel, regras e Function em produção, primeiro grupo de professores configurado.

Esta task tem **portões de confirmação**: os passos marcados com 🔒 alteram produção ou criam recursos externos. **Peça confirmação ao usuário antes de cada um.**

- [ ] **Step 1: README do portal**

Criar `web-portal/README.md`:

```markdown
# Portal de Ensino IPE

Portal web (Next.js) da área de ensino da IPE. Usa o mesmo projeto Firebase
(`app-ipe`) e a mesma conta do app Flutter.

## Rodar localmente

1. `cp .env.example .env.local` e preencha com `firebase apps:sdkconfig WEB <APP_ID> --project app-ipe`.
2. `npm install`
3. `npm run dev` → http://localhost:3000

Scripts: `npm test`, `npm run lint`, `npm run typecheck`, `npm run build`.
O `build` precisa das variáveis `NEXT_PUBLIC_FIREBASE_*` definidas.

## Estrutura

- `src/core/` — casca compartilhada: Firebase, autenticação, acesso por claims,
  registro de módulos, componentes de UI.
- `src/modules/<módulo>/` — um módulo por área (hoje só `teaching`), com `module.ts`,
  `data/` e `pages/`.
- `src/app/` — rotas do Next.js; as de módulos são finas e só reexportam a página do módulo.
- `src/styles/tokens.css` — tokens visuais. A fonte de verdade é
  `lib/src/shared/theme/app_theme.dart`; `tokens.test.ts` falha se divergirem.

## Como adicionar um módulo

1. Criar `src/modules/<id>/module.ts` exportando um `PortalModule`
   (`basePath`, `access` e `navItems`).
2. Registrá-lo em `src/core/modules/registry.ts` (`portalModules`).
3. Criar as rotas finas em `src/app/(portal)/<basePath>/`.

Menu e guarda de acesso passam a valer sozinhos.

## Acesso

- `none` não entra; `teacher` lê a biblioteca e usa o fórum; `curator` também aprova;
  `admin` (campo `is_admin`) tem acesso total e é quem gerencia o grupo.
- Papéis vêm de custom claims (`teaching_role`, `admin`), copiadas de `users/{uid}`
  pela Cloud Function `syncTeachingClaimsOnUserWrite`.
- Limite conhecido: quem perde o papel pode manter acesso ao Storage por até 1 hora
  se já estiver com a sessão aberta (o token só renova então).
```

- [ ] **Step 2: Suíte completa antes de publicar**

Run (em ordem): `cd rules-tests && npm test`, `cd ../functions && npm test && npm run lint && npm run build`, `cd ../web-portal && npm test && npm run lint && npm run typecheck && npm run build`
Expected: tudo PASS. Parar e corrigir antes de seguir se algo falhar.

- [ ] **Step 3: 🔒 Deploy da Cloud Function**

Confirmar com o usuário e rodar:

```bash
firebase deploy --only functions:syncTeachingClaimsOnUserWrite --project app-ipe
```

Esperado: deploy concluído, a função aparece em `firebase functions:list --project app-ipe`. As outras funções não são alteradas.

- [ ] **Step 4: 🔒 Backfill das claims dos admins existentes**

O script grava claims no Auth de produção. Confirmar com o usuário. Pré-requisito: credenciais da conta de serviço (`export GOOGLE_APPLICATION_CREDENTIALS=<caminho do JSON>`) ou `gcloud auth application-default login`.

```bash
cd functions
npm run backfill-claims
```

Esperado: uma linha `Atualizadas: N. Sem mudança: M. Sem conta no Auth: K. Falhas: 0.`, com `Falhas: 0`; N conta os usuários cujas claims foram corrigidas (admins e professores ainda sem claim, ou quem perdeu o papel e ainda tinha a claim). Rodar de novo deve dar `Atualizadas: 0`.

- [ ] **Step 5: 🔒 Deploy das regras do Firestore e do Storage**

Este passo muda o comportamento de produção para `users`. Confirmar com o usuário e informar o efeito: usuários comuns deixam de poder editar `is_admin` e `teaching_role` no próprio documento. Antes, abrir o console do Firebase → Storage e clicar em "Começar" se o Storage ainda não estiver inicializado.

```bash
firebase deploy --only firestore:rules,storage --project app-ipe
```

Smoke test no app Flutter em produção ou em um build local: (a) um usuário comum edita o próprio nome; (b) um admin alterna `is_admin` de outro usuário na tela de pessoas. Esperado: ambos continuam funcionando. Se algo falhar, restaurar as regras anteriores com `git show master:firestore.rules > firestore.rules` e `firebase deploy --only firestore:rules --project app-ipe`.

- [ ] **Step 6: 🔒 Preview na Vercel**

Confirmar com o usuário (cria um projeto na Vercel e envia o código). Em `web-portal/`:

```bash
cd web-portal
vercel link
vercel env add NEXT_PUBLIC_FIREBASE_API_KEY preview
vercel env add NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN preview
vercel env add NEXT_PUBLIC_FIREBASE_PROJECT_ID preview
vercel env add NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET preview
vercel env add NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID preview
vercel env add NEXT_PUBLIC_FIREBASE_APP_ID preview
vercel deploy
```

Valores: os mesmos do `.env.local`. Anotar a URL de preview devolvida. Em seguida, no console do Firebase → Authentication → Settings → Authorized domains, adicionar o domínio da URL de preview (sem isso o login falha com "domínio não autorizado").

- [ ] **Step 7: Verificação ponta a ponta (com o usuário)**

1. Abrir a URL de preview e entrar com a conta de admin. Esperado: `/ensino` abre e o menu mostra "Início" e "Grupo de professores".
2. Abrir "Grupo de professores", buscar uma pessoa de teste e mudar o papel para "Professor". Conferir no Firestore que `users/{uid}.teaching_role == "teacher"` e, em instantes, que o usuário tem a claim (`firebase auth:export` ou um novo login dela).
3. Entrar com essa conta de teste (ou usar "Verificar acesso novamente"). Esperado: `/ensino` abre, e `/ensino/admin` mostra "Acesso restrito".
4. Entrar com uma conta sem papel. Esperado: tela "Acesso restrito ao grupo de professores", sem erros no console do navegador.
5. Mudar o papel de volta para "Sem acesso" e confirmar que, depois de renovar, a conta volta a ver a tela restrita.

- [ ] **Step 8: Commit**

```bash
git add web-portal/README.md
git commit -m "docs(web-portal): README com estrutura, módulos e modelo de acesso

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Self-Review (feita ao final da escrita)

**Cobertura da spec (seção 9, etapa 1 "Fundação")**
- Projeto Next.js na Vercel com casca modular e tokens visuais → Tasks 3, 5, 7.
- Login compartilhado → Task 4.
- `teaching_role` e Function de claims → Task 2 (e campos protegidos na Task 1).
- Regras do Firestore e do Storage → Task 1.
- Administração do grupo → Task 6.
- Requisitos transversais 3.1 (identidade visual idêntica, conferida contra `app_theme.dart`) → Task 3, Steps 3 e 4. Raios de borda e o estilo "vidro" estão nos tokens e nos componentes (`Card`, `GlassCard`, `Button`, `TextField`); só as **cores** têm teste automático contra o app.
- Requisitos 3.2 (modularidade) → Tasks 5 e 7 (README "Como adicionar um módulo").
- Pendências da seção 13 da spec: o bucket e o domínio do portal não são resolvidos aqui. O deploy usa a URL de preview da Vercel; o domínio definitivo fica para depois. O bucket só importa na Task 7, Step 5.

**Placeholders:** nenhum "TBD" ou passo sem código. Os valores de `.env` dependem do `firebase apps:sdkconfig` (comando explícito no Task 4, Step 3).

**Consistência de tipos:** `TeachingRole`/`AccessClaims`/`hasAccess` (Task 4) são os mesmos usados em `registry.ts` (Task 5), `PortalShell` e `TeachingHomePage`. `TeachingRoleValue` e `MemberRow` (Task 6) só vivem no módulo de ensino. Os nomes das claims (`admin`, `teaching_role`) são idênticos nas Tasks 1, 2, 4.

**Review Focus:** os 5 itens têm teste na task dona (1: Task 1 `users.rules.test.ts`; 2: Tasks 1 e 2; 3: Task 5 `PortalShell.test.tsx` "Verificar acesso novamente"; 4: Tasks 4 e 5; 5: Task 2 `syncClaims.test.ts`).
