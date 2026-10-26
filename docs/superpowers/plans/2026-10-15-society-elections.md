> **SUBSTITUÍDO** em 2026-10-26 por `docs/superpowers/plans/2026-10-26-society-elections-scrutinies.md` (rito por escrutínios, condução na web, acesso por diretoria). Mantido só como histórico.

# Eleição de diretoria das sociedades — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir que admins conduzam, pelo app, a eleição anual da diretoria de cada sociedade, com voto secreto feito numa página web aberta por QR/link, voto único garantido pelo servidor e ata auditável.

**Architecture:** Todo voto e toda transição de estado passam por Cloud Functions (v1, `onCall`) que usam o Admin SDK; o cliente só lê coleções novas `elections/**`, protegidas por regras aditivas. O app Flutter (menu só para admins) cria e conduz a eleição; a página pública `/votar/[id]` no portal Next.js (`web-portal/`) é onde as pessoas votam, com conta do app ou como convidado (Firebase Anonymous Auth + aprovação do admin).

**Tech Stack:** Firebase Functions v1 (TypeScript, Node 22, vitest), Firestore + emulador, `@firebase/rules-unit-testing`, Next.js 16 / React 19 / vitest / Testing Library (portal), Flutter + Provider + `cloud_firestore` + `cloud_functions`.

**Spec:** `docs/superpowers/specs/2026-10-15-society-elections-design.md`

## Notas de ambiente

- Esta worktree não tem `node_modules`: rode `npm ci` em `functions/`, `rules-tests/` e `web-portal/` antes de testar cada parte.
- Um hook reescreve `git` para `rtk git` e a guarda da worktree recusa. Use `/usr/bin/git ...` (caminho completo) nos comandos de commit.
- Mensagens de commit terminam com a linha `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- O Next.js do portal tem mudanças de API: antes de escrever código de rota, leia o guia relevante em `web-portal/node_modules/next/dist/docs/` (ver `web-portal/AGENTS.md`).
- A worktree não tem `lib/firebase_options.dart` nem `lib/src/core/config/app_secrets.dart` (gitignored); por isso o app Flutter não roda aqui. Verifique o Flutter com `flutter analyze` e `flutter test`.

## Global Constraints

Copiadas do spec; valem para todas as tarefas.

- Todo voto e toda transição de estado passam por Cloud Function; o cliente só lê. `ballots` não tem leitura nenhuma pelo cliente.
- Coleções novas com regras próprias e aditivas; as regras de `users` e `societies` **não** são alteradas.
- O voto é sempre secreto: `ballots/{randomId}` guarda só a escolha, **sem identidade e sem timestamp**; `voted/{uid}` guarda só a marca de que votou.
- Cargos são os de `BoardPosition`: `presidente`, `vice`, `secretario`, `tesoureiro` (chave em `societies.board`: `presidente`, `vice`, `secretario(a)`, `tesoureiro(a)`).
- Maioria simples; Branco é registrado e não vence. Candidato único: voto `yes`/`no`/`blank`, vence se `yes > no`. Empate: nova rodada (`runoff`) só com os empatados, aberta pelo admin.
- Ninguém ocupa dois cargos: quem já foi eleito para outro cargo sai dos candidatos das rodadas seguintes.
- Membro logado em `membersIds` da sociedade vota sem aprovação; qualquer outro (convidado anônimo ou logado fora da sociedade) fica `pending` até o admin aprovar.
- "Aplicar diretoria" é ação explícita do admin e só altera os cargos eleitos.
- Funções na região padrão `us-central1`. Aspas duplas, indentação de 2 espaços e estilo Google no lint das Functions (o `predeploy` roda `npm run lint`).
- Nenhuma regra de `users` ou `societies` é apertada (decisão anterior do usuário). Risco aceito: qualquer logado pode se marcar `is_admin`.
- Fora da v1: ata em PDF, QR rotativo, assembleias gerais, push para o admin, tela de projeção, App Check.

## Review Focus

Entradas e condições que o spec implica mas que nenhuma tarefa "óbvia" exercitaria; cada uma tem teste na tarefa dona do código.

1. Eleitor aprovado clica duas vezes / envia duas requisições ao mesmo tempo → exatamente um `ballot` (Task 3).
2. Voto chega enquanto o admin encerra a rodada → ou entra na contagem, ou é rejeitado; nunca fica um `voted` sem `ballot` (Task 3).
3. Todos votam Branco, ou ninguém vota → sem vencedor e sem empate falso (Tasks 1 e 3).
4. Convidado aprovado recarrega a página (novo check-in) → continua aprovado, não volta a `pending` (Task 2).
5. Aplicar diretoria com `board` em formato antigo (lista), com chaves em outra caixa (`Presidente`) ou sem nenhuma rodada decidida → não duplica cargo e dá erro claro quando não há o que aplicar (Tasks 1 e 4).
6. Eleição encerrada com o eleitor ainda na tela de voto → voto rejeitado com mensagem, tela mostra "encerrada" (Tasks 3 e 7).

---

## Parte A — Cloud Functions

### Task 1: Lógica pura (apuração, vencedores, candidatos, diretoria)

**Files:**
- Create: `functions/src/elections/types.ts`
- Create: `functions/src/elections/tally.ts`
- Create: `functions/src/elections/winners.ts`
- Create: `functions/src/elections/candidates.ts`
- Create: `functions/src/elections/board.ts`
- Test: `functions/test/electionsTally.test.ts`
- Test: `functions/test/electionsWinners.test.ts`
- Test: `functions/test/electionsBoard.test.ts`

**Interfaces:**
- Produces (usados nas Tasks 2–4):
  - `types.ts`: `ElectionStatus`, `RoundStatus`, `RoundType`, `VoterStatus`, `VoterKind`, `Candidate {id,name}`, `RoundResult {counts,total,votedCount,winnerId,tie,divergence}`, constantes `YES`, `NO`, `BLANK`.
  - `tallyRound(type: RoundType, candidates: Candidate[], choices: string[], votedCount: number): RoundResult`
  - `winners.ts`: `RoundSummary {position,status,closedAtMs,winnerId}`, `pickWinners(rounds: RoundSummary[]): Record<string,string>` (cargo → userId), `electedElsewhere(rounds: RoundSummary[], position: string): Set<string>`
  - `candidates.ts`: `removeElected(candidates: Candidate[], elected: Set<string>): Candidate[]`, `roundTypeFor(candidates: Candidate[], requested: RoundType): RoundType`
  - `board.ts`: `boardKey(position: string): string`, `applyWinners(currentBoard: unknown, winners: Record<string,string>): Record<string,string[]>`

- [ ] **Step 1: Instalar dependências**

Run: `cd functions && npm ci`
Expected: instala sem erro.

- [ ] **Step 2: Escrever os testes que falham**

`functions/test/electionsTally.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {tallyRound} from "../src/elections/tally";

const ana = {id: "ana", name: "Ana"};
const bia = {id: "bia", name: "Bia"};

describe("tallyRound — rodada normal", () => {
  it("vence quem tem mais votos", () => {
    const r = tallyRound("normal", [ana, bia], ["ana", "ana", "bia", "blank"], 4);
    expect(r.counts).toEqual({ana: 2, bia: 1, blank: 1});
    expect(r.winnerId).toBe("ana");
    expect(r.tie).toEqual([]);
    expect(r.total).toBe(4);
    expect(r.divergence).toBe(false);
  });

  it("empate no topo devolve os empatados e nenhum vencedor", () => {
    const r = tallyRound("normal", [ana, bia], ["ana", "bia"], 2);
    expect(r.winnerId).toBeNull();
    expect(r.tie).toEqual(["ana", "bia"]);
  });

  it("só votos em branco: sem vencedor e sem empate", () => {
    const r = tallyRound("normal", [ana, bia], ["blank", "blank"], 2);
    expect(r.winnerId).toBeNull();
    expect(r.tie).toEqual([]);
  });

  it("nenhum voto: sem vencedor e sem empate", () => {
    const r = tallyRound("normal", [ana, bia], [], 0);
    expect(r.winnerId).toBeNull();
    expect(r.tie).toEqual([]);
    expect(r.total).toBe(0);
  });

  it("branco não vence mesmo sendo maioria", () => {
    const r = tallyRound("normal", [ana, bia], ["blank", "blank", "ana"], 3);
    expect(r.winnerId).toBe("ana");
  });

  it("voto inválido (inclusive chave herdada de Object) marca divergência", () => {
    const r = tallyRound("normal", [ana], ["ana", "constructor"], 2);
    expect(r.divergence).toBe(true);
    expect(r.winnerId).toBe("ana");
  });

  it("divergência quando ballots e voted não batem", () => {
    const r = tallyRound("normal", [ana, bia], ["ana"], 2);
    expect(r.divergence).toBe(true);
    expect(r.votedCount).toBe(2);
  });
});

describe("tallyRound — candidato único", () => {
  it("vence com mais Sim que Não", () => {
    const r = tallyRound("single", [ana], ["yes", "yes", "no", "blank"], 4);
    expect(r.counts).toEqual({yes: 2, no: 1, blank: 1});
    expect(r.winnerId).toBe("ana");
  });

  it("empate Sim x Não não elege", () => {
    const r = tallyRound("single", [ana], ["yes", "no"], 2);
    expect(r.winnerId).toBeNull();
    expect(r.tie).toEqual([]);
  });

  it("só Branco não elege", () => {
    const r = tallyRound("single", [ana], ["blank"], 1);
    expect(r.winnerId).toBeNull();
  });
});
```

`functions/test/electionsWinners.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {electedElsewhere, pickWinners, type RoundSummary} from "../src/elections/winners";
import {removeElected, roundTypeFor} from "../src/elections/candidates";

const r = (over: Partial<RoundSummary>): RoundSummary => ({
  position: "presidente",
  status: "closed",
  closedAtMs: 1,
  winnerId: "ana",
  ...over,
});

describe("pickWinners", () => {
  it("pega o vencedor de cada cargo e ignora rodadas não fechadas", () => {
    const winners = pickWinners([
      r({}),
      r({position: "vice", winnerId: "bia"}),
      r({position: "secretario", status: "open", winnerId: "caio"}),
    ]);
    expect(winners).toEqual({presidente: "ana", vice: "bia"});
  });

  it("a rodada fechada mais recente do cargo vale (desempate)", () => {
    const winners = pickWinners([
      r({winnerId: null, closedAtMs: 1}),
      r({winnerId: "bia", closedAtMs: 2}),
    ]);
    expect(winners).toEqual({presidente: "bia"});
  });

  it("uma rodada mais recente sem vencedor anula a anterior", () => {
    const winners = pickWinners([
      r({winnerId: "ana", closedAtMs: 1}),
      r({winnerId: null, closedAtMs: 2}),
    ]);
    expect(winners).toEqual({});
  });
});

describe("electedElsewhere", () => {
  it("lista quem foi eleito em outros cargos, não no próprio", () => {
    const rounds = [r({}), r({position: "vice", winnerId: "bia"})];
    expect([...electedElsewhere(rounds, "presidente")]).toEqual(["bia"]);
    expect([...electedElsewhere(rounds, "tesoureiro")].sort()).toEqual(["ana", "bia"]);
  });
});

describe("removeElected / roundTypeFor", () => {
  const ana = {id: "ana", name: "Ana"};
  const bia = {id: "bia", name: "Bia"};

  it("remove eleitos da lista de candidatos", () => {
    expect(removeElected([ana, bia], new Set(["ana"]))).toEqual([bia]);
  });

  it("um candidato vira rodada single; vários mantêm normal/runoff", () => {
    expect(roundTypeFor([ana], "normal")).toBe("single");
    expect(roundTypeFor([ana], "runoff")).toBe("single");
    expect(roundTypeFor([ana, bia], "normal")).toBe("normal");
    expect(roundTypeFor([ana, bia], "runoff")).toBe("runoff");
    expect(roundTypeFor([ana, bia], "single")).toBe("normal");
  });
});
```

`functions/test/electionsBoard.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import {applyWinners, boardKey} from "../src/elections/board";

describe("boardKey", () => {
  it("usa a mesma chave que o app Flutter grava", () => {
    expect(boardKey("presidente")).toBe("presidente");
    expect(boardKey("vice")).toBe("vice");
    expect(boardKey("secretario")).toBe("secretario(a)");
    expect(boardKey("tesoureiro")).toBe("tesoureiro(a)");
  });

  it("recusa cargo desconhecido", () => {
    expect(() => boardKey("pastor")).toThrow();
  });
});

describe("applyWinners", () => {
  it("troca só os cargos eleitos e preserva os demais", () => {
    const next = applyWinners(
      {presidente: ["old"], vice: ["v1"], "tesoureiro(a)": ["t1"]},
      {presidente: "ana"}
    );
    expect(next).toEqual({presidente: ["ana"], vice: ["v1"], "tesoureiro(a)": ["t1"]});
  });

  it("não duplica cargo gravado com outra caixa (Presidente)", () => {
    const next = applyWinners({Presidente: ["old"]}, {presidente: "ana"});
    expect(next).toEqual({presidente: ["ana"]});
  });

  it("board em formato antigo (lista) começa do zero com os eleitos", () => {
    expect(applyWinners(["a", "b"], {vice: "bia"})).toEqual({vice: ["bia"]});
  });

  it("board vazio ou ausente", () => {
    expect(applyWinners(undefined, {secretario: "caio"})).toEqual({"secretario(a)": ["caio"]});
  });

  it("aceita valor string legado em um cargo não eleito", () => {
    expect(applyWinners({vice: "v1"}, {presidente: "ana"})).toEqual({vice: ["v1"], presidente: ["ana"]});
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `cd functions && npx vitest run test/electionsTally.test.ts test/electionsWinners.test.ts test/electionsBoard.test.ts`
Expected: FAIL (módulos `../src/elections/*` não existem).

- [ ] **Step 4: Implementar**

`functions/src/elections/types.ts`:

```ts
export type ElectionStatus = "draft" | "open" | "closed";
export type RoundStatus = "pending" | "open" | "closed";
export type RoundType = "normal" | "single" | "runoff";
export type VoterStatus = "pending" | "approved" | "rejected";
export type VoterKind = "member" | "guest";

export interface Candidate {
  id: string;
  name: string;
}

export interface RoundResult {
  counts: Record<string, number>;
  total: number;
  votedCount: number;
  winnerId: string | null;
  tie: string[];
  divergence: boolean;
}

export const YES = "yes";
export const NO = "no";
export const BLANK = "blank";
```

`functions/src/elections/tally.ts`:

```ts
import {
  BLANK,
  NO,
  YES,
  type Candidate,
  type RoundResult,
  type RoundType,
} from "./types";

const has = (obj: object, key: string): boolean =>
  Object.prototype.hasOwnProperty.call(obj, key);

// Conta os votos de uma rodada. `votedCount` é o número de documentos em
// `voted`; se não bater com o número de ballots (ou houver escolha
// inválida), o resultado sai marcado com `divergence`.
export const tallyRound = (
  type: RoundType,
  candidates: Candidate[],
  choices: string[],
  votedCount: number
): RoundResult => {
  const keys = type === "single" ?
    [YES, NO, BLANK] :
    [...candidates.map((c) => c.id), BLANK];
  const counts: Record<string, number> = {};
  for (const key of keys) counts[key] = 0;

  let invalid = 0;
  for (const choice of choices) {
    if (has(counts, choice)) counts[choice] += 1;
    else invalid += 1;
  }

  const base = {
    counts,
    total: choices.length,
    votedCount,
    divergence: invalid > 0 || choices.length !== votedCount,
  };

  if (type === "single") {
    const winnerId = candidates.length > 0 && counts[YES] > counts[NO] ?
      candidates[0].id :
      null;
    return {...base, winnerId, tie: []};
  }

  const top = Math.max(0, ...candidates.map((c) => counts[c.id]));
  if (top === 0) return {...base, winnerId: null, tie: []};
  const leaders = candidates
    .filter((c) => counts[c.id] === top)
    .map((c) => c.id);
  return leaders.length === 1 ?
    {...base, winnerId: leaders[0], tie: []} :
    {...base, winnerId: null, tie: leaders};
};
```

`functions/src/elections/winners.ts`:

```ts
export interface RoundSummary {
  position: string;
  status: string;
  closedAtMs: number;
  winnerId: string | null;
}

// Vencedor de cada cargo: vale a rodada fechada mais recente do cargo.
// Se a mais recente não tem vencedor, o cargo fica sem vencedor.
export const pickWinners = (
  rounds: RoundSummary[]
): Record<string, string> => {
  const latest: Record<string, RoundSummary> = {};
  for (const round of rounds) {
    if (round.status !== "closed") continue;
    const current = latest[round.position];
    if (!current || round.closedAtMs >= current.closedAtMs) {
      latest[round.position] = round;
    }
  }
  const winners: Record<string, string> = {};
  for (const [position, round] of Object.entries(latest)) {
    if (round.winnerId) winners[position] = round.winnerId;
  }
  return winners;
};

// Quem já foi eleito para algum cargo diferente de `position`.
export const electedElsewhere = (
  rounds: RoundSummary[],
  position: string
): Set<string> =>
  new Set(
    Object.values(pickWinners(rounds.filter((r) => r.position !== position)))
  );
```

`functions/src/elections/candidates.ts`:

```ts
import type {Candidate, RoundType} from "./types";

export const removeElected = (
  candidates: Candidate[],
  elected: Set<string>
): Candidate[] => candidates.filter((c) => !elected.has(c.id));

// Um candidato só vira rodada `single`; senão mantém normal/runoff.
export const roundTypeFor = (
  candidates: Candidate[],
  requested: RoundType
): RoundType => {
  if (candidates.length === 1) return "single";
  return requested === "runoff" ? "runoff" : "normal";
};
```

`functions/src/elections/board.ts`:

```ts
const KEYS: Record<string, string> = {
  presidente: "presidente",
  vice: "vice",
  secretario: "secretario(a)",
  tesoureiro: "tesoureiro(a)",
};

// Chave de `societies.board` (mesma que o app grava: label em minúsculas).
export const boardKey = (position: string): string => {
  const key = KEYS[position];
  if (!key) throw new Error(`Cargo desconhecido: ${position}`);
  return key;
};

// Aplica os vencedores sobre a diretoria atual, só nos cargos eleitos.
// Board em formato antigo (lista) é descartado; chaves do mesmo cargo em
// outra caixa são removidas para não duplicar o cargo.
export const applyWinners = (
  currentBoard: unknown,
  winners: Record<string, string>
): Record<string, string[]> => {
  const next: Record<string, string[]> = {};
  if (
    currentBoard &&
    typeof currentBoard === "object" &&
    !Array.isArray(currentBoard)
  ) {
    for (const [key, value] of Object.entries(currentBoard)) {
      if (Array.isArray(value)) next[key] = value.map(String);
      else if (typeof value === "string") next[key] = [value];
    }
  }
  for (const [position, userId] of Object.entries(winners)) {
    const key = boardKey(position);
    for (const existing of Object.keys(next)) {
      const lower = existing.toLowerCase();
      if (lower === key || lower === position) delete next[existing];
    }
    next[key] = [userId];
  }
  return next;
};
```

- [ ] **Step 5: Rodar e ver passar**

Run: `cd functions && npx vitest run test/electionsTally.test.ts test/electionsWinners.test.ts test/electionsBoard.test.ts`
Expected: PASS (todos).

- [ ] **Step 6: Commit**

```bash
/usr/bin/git add functions/src/elections functions/test/electionsTally.test.ts functions/test/electionsWinners.test.ts functions/test/electionsBoard.test.ts
/usr/bin/git commit -m "feat(elections): lógica pura de apuração, vencedores e diretoria"
```

---

### Task 2: Infra de testes de integração + check-in, aprovação e status da eleição

**Files:**
- Modify: `functions/package.json` (script `test:integration`, devDependency `firebase-tools`)
- Modify: `functions/.eslintrc.js` (ignorar `/integration/**/*`)
- Create: `functions/vitest.integration.config.ts`
- Create: `functions/integration/helpers.ts`
- Create: `functions/src/elections/common.ts`
- Create: `functions/src/elections/voters.ts`
- Create: `functions/src/elections/lifecycle.ts` (apenas `setElectionStatus` nesta task)
- Test: `functions/integration/voters.itest.ts`
- Test: `functions/integration/lifecycle.itest.ts`

**Interfaces:**
- Consumes: `types.ts`, `winners.ts` (Task 1).
- Produces:
  - `common.ts`: `fail(code, message): HttpsError`, `assertAdmin(db, uid): Promise<void>`, `requireString(data: unknown, key: string): string`, `logEvent(db, electionId, event): Promise<void>`, `getElection(db, electionId): Promise<ElectionDoc>`, `summarizeRound(doc: QueryDocumentSnapshot): RoundSummary`, `type ElectionDoc = {status: ElectionStatus; societyId: string; [k: string]: unknown}`.
  - `voters.ts`: `type Caller = {uid: string; isAnonymous: boolean; email?: string}`; `checkIn(db, caller, data): Promise<{status: VoterStatus; kind: VoterKind}>`; `reviewVoter(db, uid, data): Promise<void>` com `data = {electionId, voterId, decision: "approved"|"rejected"}`.
  - `lifecycle.ts`: `setElectionStatus(db, uid, data): Promise<void>` com `data = {electionId, status: "open"|"closed"}`.
  - `integration/helpers.ts`: `db`, `clearDb()`, `seedBase()`, `expectCode(promise, code)`, constantes de ids: `ADMIN="admin1"`, `MEMBER="m1"`, `OUTSIDER="out1"`, `ELECTION="e1"`, `SOCIETY="s1"`.

- [ ] **Step 1: Configurar o runner de integração**

`functions/package.json` — adicionar em `scripts` e `devDependencies`:

```json
"test:integration": "firebase emulators:exec --only firestore --project demo-ipe-elections \"vitest run --config vitest.integration.config.ts\"",
```
```json
"firebase-tools": "^14.27.0",
```

`functions/.eslintrc.js` — acrescentar a `ignorePatterns`: `"/integration/**/*", // Testes de integração (emulador), fora do tsconfig de build.`

`functions/vitest.integration.config.ts`:

```ts
import {defineConfig} from "vitest/config";

// Testes de integração rodam contra o emulador do Firestore (emulators:exec).
export default defineConfig({
  test: {
    include: ["integration/**/*.itest.ts"],
    fileParallelism: false,
    testTimeout: 20000,
  },
});
```

Run: `cd functions && npm install`
Expected: instala `firebase-tools` e atualiza `package-lock.json`.

`functions/integration/helpers.ts`:

```ts
import * as admin from "firebase-admin";
import {expect} from "vitest";

const PROJECT = "demo-ipe-elections";
if (!admin.apps.length) admin.initializeApp({projectId: PROJECT});

export const db = admin.firestore();

export const ADMIN = "admin1";
export const MEMBER = "m1";
export const MEMBER2 = "m2";
export const MEMBER3 = "m3";
export const OUTSIDER = "out1";
export const SOCIETY = "s1";
export const ELECTION = "e1";

export const clearDb = async (): Promise<void> => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(
    `http://${host}/emulator/v1/projects/${PROJECT}/databases/(default)/documents`,
    {method: "DELETE"}
  );
};

/** Usuários, sociedade s1 (m1, m2, m3) e eleição e1 aberta. */
export const seedBase = async (status = "open"): Promise<void> => {
  await db.doc(`users/${ADMIN}`).set({name: "Admin", is_admin: true});
  await db.doc(`users/${MEMBER}`).set({name: "Ana", is_admin: false});
  await db.doc(`users/${MEMBER2}`).set({name: "Bia", is_admin: false});
  await db.doc(`users/${MEMBER3}`).set({name: "Caio", is_admin: false});
  await db.doc(`users/${OUTSIDER}`).set({name: "Fora", is_admin: false});
  await db.doc(`societies/${SOCIETY}`).set({
    name: "UMP",
    members: [MEMBER, MEMBER2, MEMBER3],
    board: {presidente: ["old"], vice: ["v1"]},
  });
  await db.doc(`elections/${ELECTION}`).set({
    societyId: SOCIETY,
    societyName: "UMP",
    title: "Eleição 2026",
    status,
    positions: ["presidente", "vice", "secretario", "tesoureiro"],
  });
};

export const expectCode = async (
  promise: Promise<unknown>,
  code: string
): Promise<void> => {
  await expect(promise).rejects.toMatchObject({code});
};
```

- [ ] **Step 2: Escrever os testes que falham**

`functions/integration/voters.itest.ts`:

```ts
import {beforeEach, describe, expect, it} from "vitest";
import {checkIn, reviewVoter} from "../src/elections/voters";
import {
  ADMIN, ELECTION, MEMBER, OUTSIDER, clearDb, db, expectCode, seedBase,
} from "./helpers";

const member = {uid: MEMBER, isAnonymous: false, email: "ana@ipe.org"};
const outsider = {uid: OUTSIDER, isAnonymous: false, email: "fora@x.org"};
const guest = {uid: "anon1", isAnonymous: true};

const voterDoc = async (uid: string) =>
  (await db.doc(`elections/${ELECTION}/voters/${uid}`).get()).data();

beforeEach(async () => {
  await clearDb();
  await seedBase();
});

describe("checkIn", () => {
  it("membro logado da sociedade entra aprovado, com nome do cadastro", async () => {
    const res = await checkIn(db, member, {electionId: ELECTION});
    expect(res).toEqual({status: "approved", kind: "member"});
    expect((await voterDoc(MEMBER))?.name).toBe("Ana");
  });

  it("convidado anônimo entra pendente com nome e e-mail informados", async () => {
    const res = await checkIn(db, guest, {
      electionId: ELECTION, name: " Dona Maria ", email: "maria@x.org",
    });
    expect(res).toEqual({status: "pending", kind: "guest"});
    const doc = await voterDoc("anon1");
    expect(doc?.name).toBe("Dona Maria");
    expect(doc?.email).toBe("maria@x.org");
  });

  it("convidado sem nome é recusado", async () => {
    await expectCode(checkIn(db, guest, {electionId: ELECTION}), "invalid-argument");
  });

  it("logado que não é da sociedade vira convidado pendente", async () => {
    const res = await checkIn(db, outsider, {electionId: ELECTION});
    expect(res).toEqual({status: "pending", kind: "guest"});
    expect((await voterDoc(OUTSIDER))?.name).toBe("Fora");
  });

  it("eleição fora de 'open' recusa o check-in", async () => {
    await db.doc(`elections/${ELECTION}`).update({status: "draft"});
    await expectCode(checkIn(db, member, {electionId: ELECTION}), "failed-precondition");
    await db.doc(`elections/${ELECTION}`).update({status: "closed"});
    await expectCode(checkIn(db, member, {electionId: ELECTION}), "failed-precondition");
  });

  it("eleição inexistente", async () => {
    await expectCode(checkIn(db, member, {electionId: "nope"}), "not-found");
  });

  it("check-in repetido é idempotente e NÃO derruba a aprovação", async () => {
    await checkIn(db, guest, {electionId: ELECTION, name: "Maria"});
    await reviewVoter(db, ADMIN, {electionId: ELECTION, voterId: "anon1", decision: "approved"});
    const again = await checkIn(db, guest, {electionId: ELECTION, name: "Outro nome"});
    expect(again).toEqual({status: "approved", kind: "guest"});
    expect((await voterDoc("anon1"))?.name).toBe("Maria");
  });

  it("chamadas simultâneas criam um único eleitor", async () => {
    const results = await Promise.all([
      checkIn(db, guest, {electionId: ELECTION, name: "Maria"}),
      checkIn(db, guest, {electionId: ELECTION, name: "Maria"}),
    ]);
    expect(results[0]).toEqual(results[1]);
    const snap = await db.collection(`elections/${ELECTION}/voters`).get();
    expect(snap.size).toBe(1);
  });
});

describe("reviewVoter", () => {
  it("só admin aprova", async () => {
    await checkIn(db, guest, {electionId: ELECTION, name: "Maria"});
    await expectCode(
      reviewVoter(db, MEMBER, {electionId: ELECTION, voterId: "anon1", decision: "approved"}),
      "permission-denied"
    );
  });

  it("admin aprova e recusa, registrando quem decidiu", async () => {
    await checkIn(db, guest, {electionId: ELECTION, name: "Maria"});
    await reviewVoter(db, ADMIN, {electionId: ELECTION, voterId: "anon1", decision: "approved"});
    expect((await voterDoc("anon1"))?.status).toBe("approved");
    expect((await voterDoc("anon1"))?.reviewedBy).toBe(ADMIN);
    await reviewVoter(db, ADMIN, {electionId: ELECTION, voterId: "anon1", decision: "rejected"});
    expect((await voterDoc("anon1"))?.status).toBe("rejected");
  });

  it("decisão inválida e eleitor inexistente", async () => {
    await expectCode(
      reviewVoter(db, ADMIN, {electionId: ELECTION, voterId: "x", decision: "approved"}),
      "not-found"
    );
    await checkIn(db, guest, {electionId: ELECTION, name: "Maria"});
    await expectCode(
      reviewVoter(db, ADMIN, {electionId: ELECTION, voterId: "anon1", decision: "maybe"}),
      "invalid-argument"
    );
  });

  it("grava eventos de auditoria do check-in e da decisão", async () => {
    await checkIn(db, guest, {electionId: ELECTION, name: "Maria"});
    await reviewVoter(db, ADMIN, {electionId: ELECTION, voterId: "anon1", decision: "approved"});
    const events = await db.collection(`elections/${ELECTION}/events`).get();
    const types = events.docs.map((d) => d.get("type")).sort();
    expect(types).toEqual(["checkin", "voter_reviewed"]);
  });
});
```

`functions/integration/lifecycle.itest.ts` (nesta task, só `setElectionStatus`; Task 4 acrescenta `applyBoard`):

```ts
import {beforeEach, describe, expect, it} from "vitest";
import {setElectionStatus} from "../src/elections/lifecycle";
import {
  ADMIN, ELECTION, MEMBER, clearDb, db, expectCode, seedBase,
} from "./helpers";

const status = async () =>
  (await db.doc(`elections/${ELECTION}`).get()).get("status");

describe("setElectionStatus", () => {
  beforeEach(async () => {
    await clearDb();
    await seedBase("draft");
  });

  it("só admin muda o status", async () => {
    await expectCode(
      setElectionStatus(db, MEMBER, {electionId: ELECTION, status: "open"}),
      "permission-denied"
    );
  });

  it("draft → open → closed", async () => {
    await setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "open"});
    expect(await status()).toBe("open");
    await setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "closed"});
    expect(await status()).toBe("closed");
  });

  it("não fecha eleição em rascunho nem reabre fechada", async () => {
    await expectCode(
      setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "closed"}),
      "failed-precondition"
    );
    await setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "open"});
    await setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "closed"});
    await expectCode(
      setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "open"}),
      "failed-precondition"
    );
  });

  it("não encerra a eleição com votação aberta", async () => {
    await setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "open"});
    await db.doc(`elections/${ELECTION}/rounds/r1`).set({
      position: "presidente", status: "open", candidates: [], type: "normal",
    });
    await expectCode(
      setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "closed"}),
      "failed-precondition"
    );
  });

  it("status inválido", async () => {
    await expectCode(
      setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "draft"}),
      "invalid-argument"
    );
  });

  it("registra evento", async () => {
    await setElectionStatus(db, ADMIN, {electionId: ELECTION, status: "open"});
    const events = await db.collection(`elections/${ELECTION}/events`).get();
    expect(events.docs.map((d) => d.get("type"))).toEqual(["election_opened"]);
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `cd functions && npm run test:integration`
Expected: FAIL (módulos `common`, `voters`, `lifecycle` não existem).

- [ ] **Step 4: Implementar**

`functions/src/elections/common.ts`:

```ts
import * as functions from "firebase-functions/v1";
import {
  FieldValue,
  type Firestore,
  type QueryDocumentSnapshot,
} from "firebase-admin/firestore";
import type {ElectionStatus} from "./types";
import type {RoundSummary} from "./winners";

type ErrorCode = ConstructorParameters<typeof functions.https.HttpsError>[0];

export const fail = (code: ErrorCode, message: string) =>
  new functions.https.HttpsError(code, message);

export interface ElectionDoc {
  status: ElectionStatus;
  societyId: string;
  [key: string]: unknown;
}

// Só `users/{uid}.is_admin === true` vale (mesma fonte de isAdmin()).
export const assertAdmin = async (
  db: Firestore,
  uid: string
): Promise<void> => {
  const snap = await db.doc(`users/${uid}`).get();
  if (!snap.exists || snap.get("is_admin") !== true) {
    throw fail("permission-denied", "Apenas administradores podem fazer isso.");
  }
};

export const requireString = (data: unknown, key: string): string => {
  const value = (data as Record<string, unknown> | null)?.[key];
  if (typeof value !== "string" || value.trim() === "") {
    throw fail("invalid-argument", `Campo obrigatório: ${key}.`);
  }
  return value.trim();
};

export const getElection = async (
  db: Firestore,
  electionId: string
): Promise<ElectionDoc> => {
  const snap = await db.doc(`elections/${electionId}`).get();
  if (!snap.exists) throw fail("not-found", "Eleição não encontrada.");
  return snap.data() as ElectionDoc;
};

// Log de auditoria só de escrita. Nunca registre quem votou em quê.
export const logEvent = async (
  db: Firestore,
  electionId: string,
  event: Record<string, unknown>
): Promise<void> => {
  await db.collection(`elections/${electionId}/events`).add({
    ...event,
    at: FieldValue.serverTimestamp(),
  });
};

export const summarizeRound = (doc: QueryDocumentSnapshot): RoundSummary => {
  const closedAt = doc.get("closedAt");
  return {
    position: String(doc.get("position")),
    status: String(doc.get("status")),
    closedAtMs: closedAt ? closedAt.toMillis() : 0,
    winnerId: doc.get("result")?.winnerId ?? null,
  };
};
```

`functions/src/elections/voters.ts`:

```ts
import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {
  assertAdmin, fail, getElection, logEvent, requireString,
} from "./common";
import type {VoterKind, VoterStatus} from "./types";

export interface Caller {
  uid: string;
  isAnonymous: boolean;
  email?: string;
}

const str = (value: unknown): string =>
  typeof value === "string" ? value.trim() : "";

// Entrada do eleitor. Membro logado da sociedade entra aprovado; os demais
// ficam pendentes. Idempotente: repetir não altera o estado já gravado.
export const checkIn = async (
  db: Firestore,
  caller: Caller,
  data: unknown
): Promise<{status: VoterStatus; kind: VoterKind}> => {
  const electionId = requireString(data, "electionId");
  const election = await getElection(db, electionId);
  if (election.status !== "open") {
    throw fail("failed-precondition", "A eleição não está aberta para entrada.");
  }

  const voterRef = db.doc(`elections/${electionId}/voters/${caller.uid}`);
  const existing = await voterRef.get();
  if (existing.exists) {
    return {status: existing.get("status"), kind: existing.get("kind")};
  }

  const society = await db.doc(`societies/${election.societyId}`).get();
  const members: string[] = (society.get("members") ?? []).map(String);
  const isMember = !caller.isAnonymous && members.includes(caller.uid);
  const userDoc = caller.isAnonymous ?
    undefined :
    (await db.doc(`users/${caller.uid}`).get()).data();

  const input = data as {name?: unknown; email?: unknown};
  const registered = str(userDoc?.name);
  const name = isMember ? registered : (str(input.name) || registered);
  if (!name) throw fail("invalid-argument", "Informe seu nome.");
  const email = caller.email ?? str(input.email);

  const kind: VoterKind = isMember ? "member" : "guest";
  const status: VoterStatus = isMember ? "approved" : "pending";

  try {
    await voterRef.create({
      name, email, kind, status, createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    // 6 = ALREADY_EXISTS: outra chamada simultânea criou primeiro.
    if ((error as {code?: number}).code === 6) {
      const again = await voterRef.get();
      return {status: again.get("status"), kind: again.get("kind")};
    }
    throw error;
  }
  await logEvent(db, electionId, {type: "checkin", voterId: caller.uid, kind});
  return {status, kind};
};

export const reviewVoter = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<void> => {
  await assertAdmin(db, uid);
  const electionId = requireString(data, "electionId");
  const voterId = requireString(data, "voterId");
  const decision = requireString(data, "decision");
  if (decision !== "approved" && decision !== "rejected") {
    throw fail("invalid-argument", "Decisão inválida.");
  }
  await getElection(db, electionId);
  const voterRef = db.doc(`elections/${electionId}/voters/${voterId}`);
  if (!(await voterRef.get()).exists) {
    throw fail("not-found", "Eleitor não encontrado.");
  }
  await voterRef.update({
    status: decision,
    reviewedBy: uid,
    reviewedAt: FieldValue.serverTimestamp(),
  });
  await logEvent(db, electionId, {
    type: "voter_reviewed", actorId: uid, voterId, decision,
  });
};
```

`functions/src/elections/lifecycle.ts`:

```ts
import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {
  assertAdmin, fail, getElection, logEvent, requireString,
} from "./common";

export const setElectionStatus = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<void> => {
  await assertAdmin(db, uid);
  const electionId = requireString(data, "electionId");
  const target = requireString(data, "status");
  if (target !== "open" && target !== "closed") {
    throw fail("invalid-argument", "Status inválido.");
  }
  const election = await getElection(db, electionId);
  const ref = db.doc(`elections/${electionId}`);

  if (target === "open") {
    if (election.status !== "draft") {
      throw fail("failed-precondition", "Só é possível abrir uma eleição em rascunho.");
    }
    await ref.update({status: "open", openedAt: FieldValue.serverTimestamp()});
  } else {
    if (election.status !== "open") {
      throw fail("failed-precondition", "Só é possível encerrar uma eleição aberta.");
    }
    const open = await ref.collection("rounds").where("status", "==", "open").limit(1).get();
    if (!open.empty) {
      throw fail("failed-precondition", "Encerre a votação em andamento antes de encerrar a eleição.");
    }
    await ref.update({status: "closed", closedAt: FieldValue.serverTimestamp()});
  }
  await logEvent(db, electionId, {
    type: target === "open" ? "election_opened" : "election_closed",
    actorId: uid,
  });
};
```

- [ ] **Step 5: Rodar e ver passar**

Run: `cd functions && npm run test:integration`
Expected: PASS (voters + lifecycle).

- [ ] **Step 6: Commit**

```bash
/usr/bin/git add functions
/usr/bin/git commit -m "feat(elections): check-in, aprovação e status da eleição (Functions)"
```

---

### Task 3: Rodadas — abrir, votar e apurar

**Files:**
- Create: `functions/src/elections/rounds.ts`
- Test: `functions/integration/rounds.itest.ts`

**Interfaces:**
- Consumes: `common.ts` (`assertAdmin`, `fail`, `getElection`, `logEvent`, `requireString`, `summarizeRound`), `tally.ts`, `winners.ts` (`electedElsewhere`), `candidates.ts` (`removeElected`, `roundTypeFor`), `types.ts`.
- Produces:
  - `openRound(db, uid, data): Promise<void>` com `data = {electionId, roundId}`
  - `castVote(db, uid, data): Promise<{receipt: string}>` com `data = {electionId, roundId, choice}`
  - `closeRound(db, uid, data): Promise<RoundResult>` com `data = {electionId, roundId}`

- [ ] **Step 1: Escrever os testes que falham**

`functions/integration/rounds.itest.ts`:

```ts
import {beforeEach, describe, expect, it} from "vitest";
import {castVote, closeRound, openRound} from "../src/elections/rounds";
import {
  ADMIN, ELECTION, MEMBER, MEMBER2, MEMBER3, OUTSIDER, clearDb, db, expectCode, seedBase,
} from "./helpers";

const ana = {id: MEMBER, name: "Ana"};
const bia = {id: MEMBER2, name: "Bia"};
const caio = {id: MEMBER3, name: "Caio"};

const rounds = () => db.collection(`elections/${ELECTION}/rounds`);
const round = async (id: string) => (await rounds().doc(id).get()).data()!;

const seedRound = (id: string, over: Record<string, unknown> = {}) =>
  rounds().doc(id).set({
    position: "presidente",
    candidates: [ana, bia],
    type: "normal",
    status: "pending",
    votedCount: 0,
    ...over,
  });

const approve = (uid: string) =>
  db.doc(`elections/${ELECTION}/voters/${uid}`).set({
    name: uid, email: "", kind: "member", status: "approved",
  });

const vote = (uid: string, choice: string, roundId = "r1") =>
  castVote(db, uid, {electionId: ELECTION, roundId, choice});

beforeEach(async () => {
  await clearDb();
  await seedBase();
});

describe("openRound", () => {
  it("só admin abre; abre a rodada e zera o contador", async () => {
    await seedRound("r1");
    await expectCode(openRound(db, MEMBER, {electionId: ELECTION, roundId: "r1"}), "permission-denied");
    await openRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    const r = await round("r1");
    expect(r.status).toBe("open");
    expect(r.votedCount).toBe(0);
    expect(r.type).toBe("normal");
  });

  it("exige eleição aberta", async () => {
    await seedRound("r1");
    await db.doc(`elections/${ELECTION}`).update({status: "draft"});
    await expectCode(openRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"}), "failed-precondition");
  });

  it("não abre duas votações ao mesmo tempo nem reabre uma já aberta", async () => {
    await seedRound("r1");
    await seedRound("r2", {position: "vice"});
    await openRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    await expectCode(openRound(db, ADMIN, {electionId: ELECTION, roundId: "r2"}), "failed-precondition");
    await expectCode(openRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"}), "failed-precondition");
  });

  it("tira dos candidatos quem já foi eleito em outro cargo", async () => {
    await seedRound("r0", {
      status: "closed",
      closedAt: new Date(1000),
      result: {winnerId: MEMBER},
    });
    await seedRound("r1", {position: "vice", candidates: [ana, bia, caio]});
    await openRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    expect((await round("r1")).candidates).toEqual([bia, caio]);
    const events = await db.collection(`elections/${ELECTION}/events`).get();
    expect(events.docs[0].get("removed")).toEqual([MEMBER]);
  });

  it("sobrando um candidato vira rodada 'single'", async () => {
    await seedRound("r0", {status: "closed", closedAt: new Date(1000), result: {winnerId: MEMBER}});
    await seedRound("r1", {position: "vice", candidates: [ana, bia]});
    await openRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    expect((await round("r1")).type).toBe("single");
  });

  it("sem candidato elegível, recusa", async () => {
    await seedRound("r0", {status: "closed", closedAt: new Date(1000), result: {winnerId: MEMBER}});
    await seedRound("r1", {position: "vice", candidates: [ana]});
    await expectCode(openRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"}), "failed-precondition");
  });

  it("refazer o mesmo cargo mantém o vencedor anterior como elegível", async () => {
    await seedRound("r0", {status: "closed", closedAt: new Date(1000), result: {winnerId: MEMBER}});
    await seedRound("r1", {candidates: [ana, bia]});
    await openRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    expect((await round("r1")).candidates).toEqual([ana, bia]);
  });
});

describe("castVote", () => {
  beforeEach(async () => {
    await seedRound("r1", {status: "open"});
    await approve(MEMBER);
  });

  it("registra voto, devolve recibo e mantém o sigilo", async () => {
    const res = await vote(MEMBER, MEMBER2);
    const ballot = await db.doc(`elections/${ELECTION}/rounds/r1/ballots/${res.receipt}`).get();
    expect(ballot.exists).toBe(true);
    expect(Object.keys(ballot.data()!)).toEqual(["choice"]);
    expect(ballot.get("choice")).toBe(MEMBER2);
    const voted = await db.doc(`elections/${ELECTION}/rounds/r1/voted/${MEMBER}`).get();
    expect(voted.exists).toBe(true);
    expect(voted.data()).toEqual({});
    expect((await round("r1")).votedCount).toBe(1);
  });

  it("segundo voto do mesmo eleitor é recusado", async () => {
    await vote(MEMBER, MEMBER2);
    await expectCode(vote(MEMBER, "blank"), "already-exists");
    const ballots = await db.collection(`elections/${ELECTION}/rounds/r1/ballots`).get();
    expect(ballots.size).toBe(1);
  });

  it("duas requisições simultâneas geram um único voto", async () => {
    const results = await Promise.allSettled([vote(MEMBER, MEMBER2), vote(MEMBER, MEMBER2)]);
    expect(results.filter((r) => r.status === "fulfilled")).toHaveLength(1);
    const ballots = await db.collection(`elections/${ELECTION}/rounds/r1/ballots`).get();
    expect(ballots.size).toBe(1);
    expect((await round("r1")).votedCount).toBe(1);
  });

  it("eleitor inexistente, pendente ou recusado não vota", async () => {
    await expectCode(vote(OUTSIDER, "blank"), "permission-denied");
    await db.doc(`elections/${ELECTION}/voters/${OUTSIDER}`).set({status: "pending", kind: "guest", name: "x"});
    await expectCode(vote(OUTSIDER, "blank"), "permission-denied");
    await db.doc(`elections/${ELECTION}/voters/${OUTSIDER}`).update({status: "rejected"});
    await expectCode(vote(OUTSIDER, "blank"), "permission-denied");
  });

  it("escolha fora da lista é inválida (inclusive yes/no em rodada normal)", async () => {
    await expectCode(vote(MEMBER, "ninguem"), "invalid-argument");
    await expectCode(vote(MEMBER, "yes"), "invalid-argument");
    expect((await round("r1")).votedCount).toBe(0);
  });

  it("rodada 'single' aceita yes/no/blank e recusa candidato", async () => {
    await seedRound("r2", {status: "open", position: "vice", type: "single", candidates: [ana]});
    await rounds().doc("r1").update({status: "closed"});
    await expectCode(vote(MEMBER, MEMBER, "r2"), "invalid-argument");
    await vote(MEMBER, "yes", "r2");
  });

  it("rodada fechada ou pendente não recebe voto", async () => {
    await rounds().doc("r1").update({status: "closed"});
    await expectCode(vote(MEMBER, "blank"), "failed-precondition");
    await seedRound("r3", {status: "pending", position: "vice"});
    await expectCode(vote(MEMBER, "blank", "r3"), "failed-precondition");
  });

  it("eleição encerrada rejeita o voto", async () => {
    await db.doc(`elections/${ELECTION}`).update({status: "closed"});
    await expectCode(vote(MEMBER, "blank"), "failed-precondition");
  });
});

describe("closeRound", () => {
  beforeEach(async () => {
    await seedRound("r1", {status: "open"});
    for (const uid of [MEMBER, MEMBER2, MEMBER3]) await approve(uid);
  });

  it("só admin encerra; apura e grava o resultado", async () => {
    await vote(MEMBER, MEMBER);
    await vote(MEMBER2, MEMBER);
    await vote(MEMBER3, "blank");
    await expectCode(closeRound(db, MEMBER, {electionId: ELECTION, roundId: "r1"}), "permission-denied");
    const result = await closeRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    expect(result.winnerId).toBe(MEMBER);
    expect(result.counts).toEqual({[MEMBER]: 2, [MEMBER2]: 0, blank: 1});
    expect(result.divergence).toBe(false);
    const r = await round("r1");
    expect(r.status).toBe("closed");
    expect(r.result.winnerId).toBe(MEMBER);
    expect(r.closedAt).toBeDefined();
  });

  it("empate devolve os empatados", async () => {
    await vote(MEMBER, MEMBER);
    await vote(MEMBER2, MEMBER2);
    const result = await closeRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    expect(result.winnerId).toBeNull();
    expect(result.tie.sort()).toEqual([MEMBER, MEMBER2].sort());
  });

  it("todos em branco ou ninguém votou: sem vencedor e sem empate", async () => {
    await vote(MEMBER, "blank");
    const blank = await closeRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    expect(blank.winnerId).toBeNull();
    expect(blank.tie).toEqual([]);

    await seedRound("r2", {status: "open", position: "vice"});
    const empty = await closeRound(db, ADMIN, {electionId: ELECTION, roundId: "r2"});
    expect(empty.total).toBe(0);
    expect(empty.winnerId).toBeNull();
    expect(empty.tie).toEqual([]);
  });

  it("detecta divergência entre voted e ballots", async () => {
    await vote(MEMBER, MEMBER);
    await db.doc(`elections/${ELECTION}/rounds/r1/voted/ghost`).set({});
    const result = await closeRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    expect(result.divergence).toBe(true);
    expect(result.votedCount).toBe(2);
  });

  it("não encerra rodada que não está aberta", async () => {
    await closeRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"});
    await expectCode(closeRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"}), "failed-precondition");
  });

  it("voto concorrente com o encerramento: nunca sobra voted sem ballot", async () => {
    const settled = await Promise.allSettled([
      vote(MEMBER, MEMBER),
      vote(MEMBER2, MEMBER),
      vote(MEMBER3, MEMBER),
      closeRound(db, ADMIN, {electionId: ELECTION, roundId: "r1"}),
    ]);
    expect(settled[3].status).toBe("fulfilled");
    const accepted = settled.slice(0, 3).filter((s) => s.status === "fulfilled").length;
    const ballots = await db.collection(`elections/${ELECTION}/rounds/r1/ballots`).get();
    const voted = await db.collection(`elections/${ELECTION}/rounds/r1/voted`).get();
    const r = await round("r1");
    expect(ballots.size).toBe(accepted);
    expect(voted.size).toBe(accepted);
    // Tudo que foi aceito antes do fechamento entra na contagem.
    expect(r.result.total).toBe(accepted);
    expect(r.result.divergence).toBe(false);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd functions && npx firebase emulators:exec --only firestore --project demo-ipe-elections "npx vitest run --config vitest.integration.config.ts integration/rounds.itest.ts"`
Expected: FAIL (`../src/elections/rounds` não existe).

- [ ] **Step 3: Implementar `functions/src/elections/rounds.ts`**

```ts
import {FieldValue, type Firestore} from "firebase-admin/firestore";
import {
  assertAdmin, fail, getElection, logEvent, requireString, summarizeRound,
} from "./common";
import {removeElected, roundTypeFor} from "./candidates";
import {tallyRound} from "./tally";
import {
  BLANK, NO, YES, type Candidate, type RoundResult, type RoundType,
} from "./types";
import {electedElsewhere} from "./winners";

interface RoundDoc {
  position: string;
  candidates: Candidate[];
  type: RoundType;
  status: string;
}

export const openRound = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<void> => {
  await assertAdmin(db, uid);
  const electionId = requireString(data, "electionId");
  const roundId = requireString(data, "roundId");
  const election = await getElection(db, electionId);
  if (election.status !== "open") {
    throw fail("failed-precondition", "Abra a eleição antes de abrir uma votação.");
  }

  const roundsRef = db.collection(`elections/${electionId}/rounds`);
  const all = await roundsRef.get();
  const target = all.docs.find((d) => d.id === roundId);
  if (!target) throw fail("not-found", "Votação não encontrada.");
  const round = target.data() as RoundDoc;
  if (round.status !== "pending") {
    throw fail("failed-precondition", "Esta votação já foi aberta.");
  }
  if (all.docs.some((d) => d.id !== roundId && d.get("status") === "open")) {
    throw fail("failed-precondition", "Já existe uma votação aberta.");
  }

  const elected = electedElsewhere(all.docs.map(summarizeRound), round.position);
  const eligible = removeElected(round.candidates, elected);
  if (eligible.length === 0) {
    throw fail("failed-precondition", "Nenhum candidato elegível para este cargo.");
  }
  const removed = round.candidates
    .filter((c) => elected.has(c.id))
    .map((c) => c.id);

  await target.ref.update({
    candidates: eligible,
    type: roundTypeFor(eligible, round.type),
    status: "open",
    votedCount: 0,
    openedAt: FieldValue.serverTimestamp(),
  });
  await logEvent(db, electionId, {
    type: "round_opened",
    actorId: uid,
    roundId,
    position: round.position,
    removed,
  });
};

// Registra o voto. `voted/{uid}` (quem votou) e `ballots/{randomId}` (o que
// foi votado) são gravados na mesma transação e não se referenciam; o
// `ballot` não tem identidade nem timestamp. O recibo é o id do ballot.
export const castVote = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<{receipt: string}> => {
  const electionId = requireString(data, "electionId");
  const roundId = requireString(data, "roundId");
  const choice = requireString(data, "choice");

  const electionRef = db.doc(`elections/${electionId}`);
  const voterRef = electionRef.collection("voters").doc(uid);
  const roundRef = electionRef.collection("rounds").doc(roundId);
  const votedRef = roundRef.collection("voted").doc(uid);
  const ballotRef = roundRef.collection("ballots").doc();

  await db.runTransaction(async (tx) => {
    const [election, voter, round, voted] = await Promise.all([
      tx.get(electionRef), tx.get(voterRef), tx.get(roundRef), tx.get(votedRef),
    ]);
    if (!election.exists || election.get("status") !== "open") {
      throw fail("failed-precondition", "A eleição não está aberta.");
    }
    if (!voter.exists || voter.get("status") !== "approved") {
      throw fail("permission-denied", "Você ainda não foi liberado para votar.");
    }
    if (!round.exists || round.get("status") !== "open") {
      throw fail("failed-precondition", "Esta votação não está aberta.");
    }
    if (voted.exists) {
      throw fail("already-exists", "Você já votou nesta votação.");
    }
    const allowed = round.get("type") === "single" ?
      [YES, NO, BLANK] :
      [...(round.get("candidates") as Candidate[]).map((c) => c.id), BLANK];
    if (!allowed.includes(choice)) {
      throw fail("invalid-argument", "Opção de voto inválida.");
    }
    tx.create(votedRef, {});
    tx.create(ballotRef, {choice});
    tx.update(roundRef, {votedCount: FieldValue.increment(1)});
  });
  return {receipt: ballotRef.id};
};

// Encerra e apura numa única transação: leitura de `ballots` e `voted` e a
// troca de status acontecem juntas, então um voto concorrente ou entra na
// contagem ou é rejeitado (rodada fechada).
export const closeRound = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<RoundResult> => {
  await assertAdmin(db, uid);
  const electionId = requireString(data, "electionId");
  const roundId = requireString(data, "roundId");
  await getElection(db, electionId);
  const roundRef = db.doc(`elections/${electionId}/rounds/${roundId}`);

  const {result, position} = await db.runTransaction(async (tx) => {
    const roundSnap = await tx.get(roundRef);
    if (!roundSnap.exists) throw fail("not-found", "Votação não encontrada.");
    if (roundSnap.get("status") !== "open") {
      throw fail("failed-precondition", "Esta votação não está aberta.");
    }
    const ballots = await tx.get(roundRef.collection("ballots"));
    const voted = await tx.get(roundRef.collection("voted"));
    const outcome = tallyRound(
      roundSnap.get("type") as RoundType,
      roundSnap.get("candidates") as Candidate[],
      ballots.docs.map((d) => String(d.get("choice"))),
      voted.size
    );
    tx.update(roundRef, {
      status: "closed",
      closedAt: FieldValue.serverTimestamp(),
      result: outcome,
    });
    return {result: outcome, position: String(roundSnap.get("position"))};
  });

  await logEvent(db, electionId, {
    type: "round_closed",
    actorId: uid,
    roundId,
    position,
    winnerId: result.winnerId,
    tie: result.tie,
    total: result.total,
    votedCount: result.votedCount,
    divergence: result.divergence,
  });
  return result;
};
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd functions && npm run test:integration`
Expected: PASS (voters, lifecycle, rounds). Se o teste de concorrência do `closeRound` ficar instável no emulador, **não** relaxe a asserção: investigue a transação (leituras antes das escritas) antes de continuar.

- [ ] **Step 5: Commit**

```bash
/usr/bin/git add functions/src/elections/rounds.ts functions/integration/rounds.itest.ts
/usr/bin/git commit -m "feat(elections): abrir, votar e apurar rodadas (Functions)"
```

---

### Task 4: Aplicar diretoria + callables exportados

**Files:**
- Modify: `functions/src/elections/lifecycle.ts` (acrescentar `applyBoard`)
- Create: `functions/src/elections/index.ts`
- Modify: `functions/src/index.ts` (uma linha de export)
- Modify: `functions/integration/lifecycle.itest.ts` (testes de `applyBoard`)

**Interfaces:**
- Consumes: `common.ts` (`summarizeRound`, ...), `winners.ts` (`pickWinners`), `board.ts` (`applyWinners`), `voters.ts` (`Caller`, `checkIn`, `reviewVoter`), `rounds.ts`, `lifecycle.ts` (`setElectionStatus`).
- Produces:
  - `applyBoard(db, uid, data): Promise<{winners: Record<string,string>}>` com `data = {electionId}`
  - Callables exportados em `functions/src/elections/index.ts` e reexportados em `functions/src/index.ts`: `electionSetStatus`, `electionCheckIn`, `electionReviewVoter`, `electionOpenRound`, `electionCastVote`, `electionCloseRound`, `electionApplyBoard` (esses nomes são usados literalmente pelo Flutter e pela web).

- [ ] **Step 1: Escrever os testes que falham** — acrescentar a `functions/integration/lifecycle.itest.ts`:

```ts
import {applyBoard} from "../src/elections/lifecycle";

const closedRound = (id: string, position: string, winnerId: string | null, ms: number) =>
  db.doc(`elections/${ELECTION}/rounds/${id}`).set({
    position, status: "closed", candidates: [], type: "normal",
    closedAt: new Date(ms), result: {winnerId},
  });

const board = async () => (await db.doc("societies/s1").get()).get("board");

describe("applyBoard", () => {
  beforeEach(async () => {
    await clearDb();
    await seedBase("closed");
  });

  it("só admin aplica", async () => {
    await closedRound("r1", "presidente", "m2", 1);
    await expectCode(applyBoard(db, MEMBER, {electionId: ELECTION}), "permission-denied");
  });

  it("troca só os cargos eleitos e preserva os demais", async () => {
    await closedRound("r1", "presidente", "m2", 1);
    const res = await applyBoard(db, ADMIN, {electionId: ELECTION});
    expect(res.winners).toEqual({presidente: "m2"});
    expect(await board()).toEqual({presidente: ["m2"], vice: ["v1"]});
    const election = await db.doc(`elections/${ELECTION}`).get();
    expect(election.get("boardAppliedAt")).toBeDefined();
  });

  it("usa a chave com sufixo para secretário e tesoureiro", async () => {
    await closedRound("r1", "secretario", "m3", 1);
    await closedRound("r2", "tesoureiro", "m1", 1);
    await applyBoard(db, ADMIN, {electionId: ELECTION});
    const b = await board();
    expect(b["secretario(a)"]).toEqual(["m3"]);
    expect(b["tesoureiro(a)"]).toEqual(["m1"]);
  });

  it("cargo decidido em desempate vale a rodada mais recente", async () => {
    await closedRound("r1", "presidente", null, 1);
    await closedRound("r2", "presidente", "m3", 2);
    await applyBoard(db, ADMIN, {electionId: ELECTION});
    expect((await board()).presidente).toEqual(["m3"]);
  });

  it("board em formato antigo (lista) vira mapa só com os eleitos", async () => {
    await db.doc("societies/s1").update({board: ["a", "b"]});
    await closedRound("r1", "vice", "m2", 1);
    await applyBoard(db, ADMIN, {electionId: ELECTION});
    expect(await board()).toEqual({vice: ["m2"]});
  });

  it("não duplica cargo gravado como 'Presidente'", async () => {
    await db.doc("societies/s1").update({board: {Presidente: ["old"]}});
    await closedRound("r1", "presidente", "m2", 1);
    await applyBoard(db, ADMIN, {electionId: ELECTION});
    expect(await board()).toEqual({presidente: ["m2"]});
  });

  it("sem cargo decidido, erro claro e nada muda", async () => {
    await db.doc(`elections/${ELECTION}/rounds/r1`).set({
      position: "presidente", status: "open", candidates: [], type: "normal",
    });
    await expectCode(applyBoard(db, ADMIN, {electionId: ELECTION}), "failed-precondition");
    expect(await board()).toEqual({presidente: ["old"], vice: ["v1"]});
  });

  it("registra evento e pode ser reaplicado", async () => {
    await closedRound("r1", "presidente", "m2", 1);
    await applyBoard(db, ADMIN, {electionId: ELECTION});
    await applyBoard(db, ADMIN, {electionId: ELECTION});
    const events = await db.collection(`elections/${ELECTION}/events`).get();
    expect(events.docs.filter((d) => d.get("type") === "board_applied")).toHaveLength(2);
  });
});
```

(Ajuste o cabeçalho do arquivo para importar `applyBoard` junto de `setElectionStatus` numa só linha: `import {applyBoard, setElectionStatus} from "../src/elections/lifecycle";`.)

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd functions && npm run test:integration`
Expected: FAIL (`applyBoard` não é exportado).

- [ ] **Step 3: Implementar `applyBoard`** — em `functions/src/elections/lifecycle.ts`, acrescentar os imports `import {applyWinners} from "./board";` e `import {pickWinners} from "./winners";`, trocar o import de `./common` para incluir `summarizeRound`, e adicionar:

```ts
export const applyBoard = async (
  db: Firestore,
  uid: string,
  data: unknown
): Promise<{winners: Record<string, string>}> => {
  await assertAdmin(db, uid);
  const electionId = requireString(data, "electionId");
  const election = await getElection(db, electionId);

  const rounds = await db.collection(`elections/${electionId}/rounds`).get();
  const winners = pickWinners(rounds.docs.map(summarizeRound));
  if (Object.keys(winners).length === 0) {
    throw fail("failed-precondition", "Nenhum cargo foi decidido ainda.");
  }

  const societyRef = db.doc(`societies/${election.societyId}`);
  await db.runTransaction(async (tx) => {
    const society = await tx.get(societyRef);
    if (!society.exists) throw fail("not-found", "Sociedade não encontrada.");
    tx.update(societyRef, {board: applyWinners(society.get("board"), winners)});
    tx.update(db.doc(`elections/${electionId}`), {
      boardAppliedAt: FieldValue.serverTimestamp(),
    });
  });
  await logEvent(db, electionId, {type: "board_applied", actorId: uid, winners});
  return {winners};
};
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd functions && npm run test:integration`
Expected: PASS (todas as suítes).

- [ ] **Step 5: Criar os callables** — `functions/src/elections/index.ts`:

```ts
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {applyBoard, setElectionStatus} from "./lifecycle";
import {castVote, closeRound, openRound} from "./rounds";
import {checkIn, reviewVoter} from "./voters";

const needAuth = (context: functions.https.CallableContext) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated", "Entre para continuar."
    );
  }
  return context.auth;
};

export const electionSetStatus = functions.https.onCall((data, context) =>
  setElectionStatus(admin.firestore(), needAuth(context).uid, data));

export const electionCheckIn = functions.https.onCall((data, context) => {
  const auth = needAuth(context);
  return checkIn(admin.firestore(), {
    uid: auth.uid,
    isAnonymous: auth.token.firebase?.sign_in_provider === "anonymous",
    email: auth.token.email,
  }, data);
});

export const electionReviewVoter = functions.https.onCall((data, context) =>
  reviewVoter(admin.firestore(), needAuth(context).uid, data));

export const electionOpenRound = functions.https.onCall((data, context) =>
  openRound(admin.firestore(), needAuth(context).uid, data));

export const electionCastVote = functions.https.onCall((data, context) =>
  castVote(admin.firestore(), needAuth(context).uid, data));

export const electionCloseRound = functions.https.onCall((data, context) =>
  closeRound(admin.firestore(), needAuth(context).uid, data));

export const electionApplyBoard = functions.https.onCall((data, context) =>
  applyBoard(admin.firestore(), needAuth(context).uid, data));
```

`functions/src/index.ts` — acrescentar, logo abaixo da linha 1822 (`export {syncTeachingClaimsOnUserWrite} ...`):

```ts
export {
  electionApplyBoard,
  electionCastVote,
  electionCheckIn,
  electionCloseRound,
  electionOpenRound,
  electionReviewVoter,
  electionSetStatus,
} from "./elections";
```

- [ ] **Step 6: Lint e build (o `predeploy` roda os dois)**

Run: `cd functions && npm run lint -- --fix && npm run build && npm test`
Expected: lint sem erros, `tsc` compila, testes unitários passam. O `--fix` não quebra linhas longas: o estilo Google limita a 80 colunas (inclusive strings); quebre à mão o que sobrar. Comentários em `functions/src/` usam `//` (um `/** */` exigiria `@param`/`@return`).

- [ ] **Step 7: Commit**

```bash
/usr/bin/git add functions
/usr/bin/git commit -m "feat(elections): aplicar diretoria e exportar callables"
```

---

## Parte B — Regras do Firestore

### Task 5: Regras aditivas de `elections` + testes no emulador

**Files:**
- Modify: `firestore.rules` (novo bloco antes do último `}` de `match /databases`)
- Test: `rules-tests/elections.rules.test.ts`

**Interfaces:**
- Consumes: `isAdmin()` já definida em `firestore.rules`.
- Produces: coleção `elections/**` legível/escrevível conforme o spec §6 (usada pelo Flutter e pela web).

**Atenção — desvio do spec, já aprovado na fase de plano:** `get` do documento `elections/{id}` é **público** (sem login) para que a página de voto mostre título e situação antes da identificação; `list` exige login. O documento só tem título, nome da sociedade, status e cargos. Registrar isso no spec (Task 13).

- [ ] **Step 1: Instalar dependências**

Run: `cd rules-tests && npm ci`

- [ ] **Step 2: Escrever o teste que falha** — `rules-tests/elections.rules.test.ts`:

```ts
import {afterAll, beforeAll, beforeEach, describe, it} from "vitest";
import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  addDoc, collection, deleteDoc, doc, getDoc, getDocs, setDoc, updateDoc,
} from "firebase/firestore";
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
    await setDoc(doc(db, "users/admin1"), {is_admin: true});
    await setDoc(doc(db, "users/user1"), {is_admin: false});
    await setDoc(doc(db, "elections/draft1"), {status: "draft", title: "t"});
    await setDoc(doc(db, "elections/open1"), {status: "open", title: "t"});
    await setDoc(doc(db, "elections/draft1/rounds/pend"), {status: "pending", position: "vice", candidates: [], type: "normal"});
    await setDoc(doc(db, "elections/open1/rounds/live"), {status: "open", position: "vice", candidates: [], type: "normal"});
    await setDoc(doc(db, "elections/open1/voters/user1"), {status: "approved"});
    await setDoc(doc(db, "elections/open1/voters/other"), {status: "approved"});
    await setDoc(doc(db, "elections/open1/rounds/live/voted/user1"), {});
    await setDoc(doc(db, "elections/open1/rounds/live/voted/other"), {});
    await setDoc(doc(db, "elections/open1/rounds/live/ballots/b1"), {choice: "x"});
    await setDoc(doc(db, "elections/open1/events/ev1"), {type: "checkin"});
  });
});

const admin = () => env.authenticatedContext("admin1").firestore();
const user = () => env.authenticatedContext("user1").firestore();
const anon = () => env.authenticatedContext("anon9", {firebase: {sign_in_provider: "anonymous"}}).firestore();
const noAuth = () => env.unauthenticatedContext().firestore();

describe("elections", () => {
  it("get do documento é público; list exige login", async () => {
    await assertSucceeds(getDoc(doc(noAuth(), "elections/open1")));
    await assertFails(getDocs(collection(noAuth(), "elections")));
    await assertSucceeds(getDocs(collection(user(), "elections")));
  });

  it("admin cria rascunho; outros e status diferente de draft, não", async () => {
    await assertSucceeds(setDoc(doc(admin(), "elections/new1"), {status: "draft", title: "n"}));
    await assertFails(setDoc(doc(user(), "elections/new2"), {status: "draft", title: "n"}));
    await assertFails(setDoc(doc(admin(), "elections/new3"), {status: "open", title: "n"}));
  });

  it("admin edita só rascunho e não muda o status pelo cliente", async () => {
    await assertSucceeds(updateDoc(doc(admin(), "elections/draft1"), {title: "novo"}));
    await assertFails(updateDoc(doc(admin(), "elections/draft1"), {status: "open"}));
    await assertFails(updateDoc(doc(admin(), "elections/open1"), {title: "novo"}));
    await assertFails(updateDoc(doc(user(), "elections/draft1"), {title: "novo"}));
  });

  it("só admin exclui, e só rascunho", async () => {
    await assertSucceeds(deleteDoc(doc(admin(), "elections/draft1")));
    await assertFails(deleteDoc(doc(admin(), "elections/open1")));
    await assertFails(deleteDoc(doc(user(), "elections/draft1")));
  });
});

describe("elections/rounds", () => {
  it("leitura exige login (anônimo do Firebase vale)", async () => {
    await assertSucceeds(getDoc(doc(anon(), "elections/open1/rounds/live")));
    await assertFails(getDoc(doc(noAuth(), "elections/open1/rounds/live")));
  });

  it("admin cria rodada pendente em eleição draft/open; nunca com outro status", async () => {
    const data = {status: "pending", position: "presidente", candidates: [], type: "normal"};
    await assertSucceeds(setDoc(doc(admin(), "elections/draft1/rounds/n1"), data));
    await assertSucceeds(setDoc(doc(admin(), "elections/open1/rounds/n2"), data));
    await assertFails(setDoc(doc(admin(), "elections/open1/rounds/n3"), {...data, status: "open"}));
    await assertFails(setDoc(doc(user(), "elections/open1/rounds/n4"), data));
  });

  it("admin edita candidatos só de rodada pendente e não muda status/resultado", async () => {
    const pend = doc(admin(), "elections/draft1/rounds/pend");
    await assertSucceeds(updateDoc(pend, {candidates: [{id: "a", name: "A"}]}));
    await assertFails(updateDoc(pend, {status: "open"}));
    await assertFails(updateDoc(pend, {result: {winnerId: "a"}}));
    await assertFails(updateDoc(doc(admin(), "elections/open1/rounds/live"), {candidates: []}));
    await assertFails(updateDoc(doc(user(), "elections/draft1/rounds/pend"), {candidates: []}));
  });

  it("exclui só rodada pendente, só admin", async () => {
    await assertSucceeds(deleteDoc(doc(admin(), "elections/draft1/rounds/pend")));
    await assertFails(deleteDoc(doc(admin(), "elections/open1/rounds/live")));
  });
});

describe("voters, voted, ballots, events", () => {
  it("eleitor lê só o próprio documento; admin lê todos; ninguém escreve", async () => {
    await assertSucceeds(getDoc(doc(user(), "elections/open1/voters/user1")));
    await assertFails(getDoc(doc(user(), "elections/open1/voters/other")));
    await assertSucceeds(getDoc(doc(admin(), "elections/open1/voters/other")));
    await assertFails(setDoc(doc(user(), "elections/open1/voters/user1"), {status: "approved"}));
    await assertFails(updateDoc(doc(admin(), "elections/open1/voters/other"), {status: "rejected"}));
  });

  it("eleitor pode ler o próprio voted (e não o dos outros); ninguém escreve", async () => {
    await assertSucceeds(getDoc(doc(user(), "elections/open1/rounds/live/voted/user1")));
    await assertFails(getDoc(doc(user(), "elections/open1/rounds/live/voted/other")));
    await assertFails(setDoc(doc(user(), "elections/open1/rounds/live/voted/new"), {}));
    await assertFails(setDoc(doc(admin(), "elections/open1/rounds/live/voted/new"), {}));
  });

  it("ballots: nenhuma leitura nem escrita, nem para o admin", async () => {
    await assertFails(getDoc(doc(admin(), "elections/open1/rounds/live/ballots/b1")));
    await assertFails(getDocs(collection(admin(), "elections/open1/rounds/live/ballots")));
    await assertFails(addDoc(collection(admin(), "elections/open1/rounds/live/ballots"), {choice: "x"}));
    await assertFails(getDoc(doc(user(), "elections/open1/rounds/live/ballots/b1")));
  });

  it("events: só admin lê; ninguém escreve", async () => {
    await assertSucceeds(getDoc(doc(admin(), "elections/open1/events/ev1")));
    await assertFails(getDoc(doc(user(), "elections/open1/events/ev1")));
    await assertFails(addDoc(collection(admin(), "elections/open1/events"), {type: "x"}));
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `cd rules-tests && npm test`
Expected: FAIL (sem regras para `elections`, tudo negado: falham os `assertSucceeds`).

- [ ] **Step 4: Implementar** — em `firestore.rules`, antes do `}` que fecha `match /databases/{database}/documents`, depois do bloco `match /musics/{musicId}`:

```
    // Eleição de diretoria das sociedades.
    // Votos, aprovações e mudanças de estado só passam pelas Cloud Functions
    // (Admin SDK ignora estas regras). O cliente só lê.
    match /elections/{electionId} {
      // O documento não guarda nada secreto; a página de voto o lê antes do login.
      allow get: if true;
      allow list: if request.auth != null;

      allow create: if isAdmin() && request.resource.data.status == 'draft';
      allow update: if isAdmin()
        && resource.data.status == 'draft'
        && request.resource.data.status == 'draft';
      allow delete: if isAdmin() && resource.data.status == 'draft';

      match /rounds/{roundId} {
        allow read: if request.auth != null;

        allow create: if isAdmin()
          && request.resource.data.status == 'pending'
          && get(/databases/$(database)/documents/elections/$(electionId)).data.status in ['draft', 'open'];
        allow update: if isAdmin()
          && resource.data.status == 'pending'
          && request.resource.data.status == 'pending'
          && request.resource.data.diff(resource.data).affectedKeys()
              .hasOnly(['candidates', 'position', 'type']);
        allow delete: if isAdmin() && resource.data.status == 'pending';

        // Só a marca "já votei" do próprio usuário. Sem regra para ballots:
        // nenhum cliente (nem admin) lê ou escreve votos.
        match /voted/{voterId} {
          allow read: if request.auth != null && request.auth.uid == voterId;
        }
      }

      match /voters/{voterId} {
        allow read: if request.auth != null
          && (request.auth.uid == voterId || isAdmin());
      }

      match /events/{eventId} {
        allow read: if isAdmin();
      }
    }
```

- [ ] **Step 5: Rodar e ver passar**

Run: `cd rules-tests && npm test`
Expected: PASS em `elections.rules.test.ts` **e** nas suítes existentes (`users.rules.test.ts`, `storage.rules.test.ts`).

- [ ] **Step 6: Commit**

```bash
/usr/bin/git add firestore.rules rules-tests/elections.rules.test.ts
/usr/bin/git commit -m "feat(elections): regras aditivas do Firestore para elections"
```

---

## Parte C — Página de voto no portal Next.js

### Task 6: Tipos, cliente Firebase Functions e estado da tela (puro)

**Files:**
- Modify: `web-portal/src/core/firebase/client.ts`
- Create: `web-portal/src/modules/elections/types.ts`
- Create: `web-portal/src/modules/elections/voteState.ts`
- Test: `web-portal/src/modules/elections/voteState.test.ts`

**Interfaces:**
- Produces:
  - `client.ts`: `export const functions = getFunctions(app, "us-central1")`
  - `types.ts`: `Election {id,title,societyName,status}`, `Candidate {id,name}`, `Round {id,position,candidates,type}`, `Voter {status,kind,name}`, `positionLabel(position: string): string`
  - `voteState.ts`: `type VoteView`, `deriveView(input: DeriveInput): VoteView` com `DeriveInput = {election, voter, openRound, hasVoted, hasUser}` (cada um `T | null | undefined`, onde `undefined` = carregando)

- [ ] **Step 1: Instalar dependências**

Run: `cd web-portal && npm ci`

- [ ] **Step 2: Escrever o teste que falha** — `web-portal/src/modules/elections/voteState.test.ts`:

```ts
import {describe, expect, it} from "vitest";
import type {Election, Round, Voter} from "./types";
import {deriveView} from "./voteState";

const election = (status: Election["status"]): Election => ({
  id: "e1", title: "Eleição 2026", societyName: "UMP", status,
});
const round: Round = {
  id: "r1", position: "presidente", type: "normal",
  candidates: [{id: "a", name: "Ana"}],
};
const voter = (status: Voter["status"]): Voter => ({status, kind: "guest", name: "Maria"});

const base = {
  election: election("open"),
  voter: undefined as Voter | null | undefined,
  openRound: undefined as Round | null | undefined,
  hasVoted: undefined as boolean | undefined,
  hasUser: false,
};

describe("deriveView", () => {
  it("carregando a eleição", () => {
    expect(deriveView({...base, election: undefined}).kind).toBe("loading");
  });

  it("eleição inexistente, em rascunho ou encerrada (mesmo sem login)", () => {
    expect(deriveView({...base, election: null}).kind).toBe("notFound");
    expect(deriveView({...base, election: election("draft")}).kind).toBe("notOpen");
    expect(deriveView({...base, election: election("closed")}).kind).toBe("closed");
  });

  it("encerrada vale mesmo para quem está na tela de voto", () => {
    const view = deriveView({
      ...base, election: election("closed"), hasUser: true,
      voter: voter("approved"), openRound: round, hasVoted: false,
    });
    expect(view.kind).toBe("closed");
  });

  it("sem usuário pede identificação", () => {
    expect(deriveView(base).kind).toBe("join");
  });

  it("com usuário, aguarda o eleitor carregar; sem check-in volta a join", () => {
    expect(deriveView({...base, hasUser: true, voter: undefined}).kind).toBe("loading");
    expect(deriveView({...base, hasUser: true, voter: null}).kind).toBe("join");
  });

  it("pendente e recusado", () => {
    expect(deriveView({...base, hasUser: true, voter: voter("pending")}).kind).toBe("pending");
    expect(deriveView({...base, hasUser: true, voter: voter("rejected")}).kind).toBe("rejected");
  });

  it("aprovado: carrega rodada, espera rodada, vota, já votou", () => {
    const approved = {...base, hasUser: true, voter: voter("approved")};
    expect(deriveView({...approved, openRound: undefined}).kind).toBe("loading");
    expect(deriveView({...approved, openRound: null}).kind).toBe("waitingRound");
    expect(deriveView({...approved, openRound: round, hasVoted: undefined}).kind).toBe("loading");
    expect(deriveView({...approved, openRound: round, hasVoted: false})).toEqual({kind: "ballot", round});
    expect(deriveView({...approved, openRound: round, hasVoted: true})).toEqual({kind: "voted", round});
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `cd web-portal && npx vitest run src/modules/elections/voteState.test.ts`
Expected: FAIL (módulos não existem).

- [ ] **Step 4: Implementar**

`web-portal/src/core/firebase/client.ts` — acrescentar o import `import {getFunctions} from "firebase/functions";` e, no fim:

```ts
export const functions = getFunctions(app, "us-central1");
```

`web-portal/src/modules/elections/types.ts`:

```ts
export type ElectionStatus = "draft" | "open" | "closed";

export interface Election {
  id: string;
  title: string;
  societyName: string;
  status: ElectionStatus;
}

export interface Candidate {
  id: string;
  name: string;
}

export type RoundType = "normal" | "single" | "runoff";

export interface Round {
  id: string;
  position: string;
  candidates: Candidate[];
  type: RoundType;
}

export type VoterStatus = "pending" | "approved" | "rejected";

export interface Voter {
  status: VoterStatus;
  kind: "member" | "guest";
  name: string;
}

const POSITION_LABELS: Record<string, string> = {
  presidente: "Presidente",
  vice: "Vice",
  secretario: "Secretário(a)",
  tesoureiro: "Tesoureiro(a)",
};

export const positionLabel = (position: string): string =>
  POSITION_LABELS[position] ?? position;
```

`web-portal/src/modules/elections/voteState.ts`:

```ts
import type {Election, Round, Voter} from "./types";

export type VoteView =
  | {kind: "loading"}
  | {kind: "notFound"}
  | {kind: "notOpen"}
  | {kind: "closed"}
  | {kind: "join"}
  | {kind: "pending"}
  | {kind: "rejected"}
  | {kind: "waitingRound"}
  | {kind: "ballot"; round: Round}
  | {kind: "voted"; round: Round};

/** `undefined` = ainda carregando; `null` = carregou e não existe. */
export interface DeriveInput {
  election: Election | null | undefined;
  voter: Voter | null | undefined;
  openRound: Round | null | undefined;
  hasVoted: boolean | undefined;
  hasUser: boolean;
}

export function deriveView(input: DeriveInput): VoteView {
  const {election, voter, openRound, hasVoted, hasUser} = input;
  if (election === undefined) return {kind: "loading"};
  if (election === null) return {kind: "notFound"};
  if (election.status === "draft") return {kind: "notOpen"};
  if (election.status === "closed") return {kind: "closed"};

  if (!hasUser) return {kind: "join"};
  if (voter === undefined) return {kind: "loading"};
  if (voter === null) return {kind: "join"};
  if (voter.status === "pending") return {kind: "pending"};
  if (voter.status === "rejected") return {kind: "rejected"};

  if (openRound === undefined) return {kind: "loading"};
  if (openRound === null) return {kind: "waitingRound"};
  if (hasVoted === undefined) return {kind: "loading"};
  return hasVoted ?
    {kind: "voted", round: openRound} :
    {kind: "ballot", round: openRound};
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `cd web-portal && npx vitest run src/modules/elections/voteState.test.ts && npm run typecheck`
Expected: PASS e typecheck sem erros.

- [ ] **Step 6: Commit**

```bash
/usr/bin/git add web-portal/src
/usr/bin/git commit -m "feat(elections): tipos e estado puro da página de voto"
```

---

### Task 7: Página pública de voto (`/votar/[id]`)

**Files:**
- Create: `web-portal/src/modules/elections/data/electionClient.ts`
- Create: `web-portal/src/modules/elections/components/JoinStep.tsx`
- Create: `web-portal/src/modules/elections/components/BallotStep.tsx`
- Create: `web-portal/src/modules/elections/pages/VotePage.tsx`
- Create: `web-portal/src/app/(public)/votar/[id]/page.tsx`
- Test: `web-portal/src/modules/elections/pages/VotePage.test.tsx`

**Interfaces:**
- Consumes: `types.ts`, `voteState.ts` (Task 6); `useAuth` de `@/core/auth/AuthContext`; `authErrorMessage` de `@/core/auth/errors`; `Button`, `GlassCard`, `TextField` de `@/core/ui/*`; callables `electionCheckIn` e `electionCastVote` (Task 4).
- Produces (`electionClient.ts`):
  - `watchElection(id, onData: (e: Election | null) => void, onError: (m: string) => void): Unsubscribe`
  - `watchVoter(electionId, uid, onData: (v: Voter | null) => void, onError): Unsubscribe`
  - `watchOpenRound(electionId, onData: (r: Round | null) => void, onError): Unsubscribe`
  - `watchHasVoted(electionId, roundId, uid, onData: (b: boolean) => void, onError): Unsubscribe`
  - `checkIn(electionId: string, guest?: {name: string; email: string}): Promise<void>`
  - `castVote(electionId: string, roundId: string, choice: string): Promise<string>` (devolve o recibo)
  - `signInGuest(): Promise<unknown>`, `signInWithPassword(email: string, password: string): Promise<unknown>`, `signInWithGoogle(): Promise<unknown>`
  - `errorMessage(e: unknown): string`

- [ ] **Step 1: Ler a documentação do Next.js desta versão**

Run: `ls web-portal/node_modules/next/dist/docs/` e leia o guia sobre **dynamic routes / `params`** e **route groups**. Confirme se `params` chega como `Promise` (esperado em Next 15+). Ajuste o `page.tsx` do Step 4 se a API for diferente.

- [ ] **Step 2: Escrever o teste que falha** — `web-portal/src/modules/elections/pages/VotePage.test.tsx`:

```tsx
import {fireEvent, render, screen, waitFor} from "@testing-library/react";
import {beforeEach, describe, expect, it, vi} from "vitest";
import type {Election, Round, Voter} from "../types";
import {VotePage} from "./VotePage";

const auth = vi.hoisted(() => ({state: {status: "signedOut"} as unknown}));
vi.mock("@/core/auth/AuthContext", () => ({
  useAuth: () => ({state: auth.state, refreshAccess: vi.fn(), signOut: vi.fn()}),
}));

const api = vi.hoisted(() => ({
  election: undefined as unknown,
  voter: undefined as unknown,
  round: undefined as unknown,
  hasVoted: undefined as unknown,
  checkIn: vi.fn(),
  castVote: vi.fn(),
  signInGuest: vi.fn(),
  signInWithPassword: vi.fn(),
  signInWithGoogle: vi.fn(),
}));

vi.mock("../data/electionClient", () => ({
  watchElection: (_id: string, cb: (v: unknown) => void) => { cb(api.election); return () => {}; },
  watchVoter: (_e: string, _u: string, cb: (v: unknown) => void) => { cb(api.voter); return () => {}; },
  watchOpenRound: (_e: string, cb: (v: unknown) => void) => { cb(api.round); return () => {}; },
  watchHasVoted: (_e: string, _r: string, _u: string, cb: (v: unknown) => void) => { cb(api.hasVoted); return () => {}; },
  checkIn: api.checkIn,
  castVote: api.castVote,
  signInGuest: api.signInGuest,
  signInWithPassword: api.signInWithPassword,
  signInWithGoogle: api.signInWithGoogle,
  errorMessage: (e: unknown) => (e instanceof Error ? e.message : "Algo deu errado."),
}));

const election = (status: Election["status"] = "open"): Election => ({
  id: "e1", title: "Eleição 2026", societyName: "UMP", status,
});
const round: Round = {
  id: "r1", position: "presidente", type: "normal",
  candidates: [{id: "a", name: "Ana"}, {id: "b", name: "Bia"}],
};
const voter = (status: Voter["status"]): Voter => ({status, kind: "guest", name: "Maria"});
const signedIn = (isAnonymous: boolean) => ({
  status: "signedIn",
  user: {uid: "u1", isAnonymous},
  claims: {admin: false, teachingRole: null},
});

beforeEach(() => {
  auth.state = {status: "signedOut"};
  api.election = election();
  api.voter = undefined;
  api.round = undefined;
  api.hasVoted = undefined;
  Object.values(api).forEach((v) => typeof v === "function" && (v as ReturnType<typeof vi.fn>).mockReset?.());
  api.checkIn.mockResolvedValue(undefined);
  api.castVote.mockResolvedValue("RECIBO123");
  api.signInGuest.mockResolvedValue(undefined);
});

describe("VotePage", () => {
  it("enquanto a sessão carrega não mostra o formulário de entrada", () => {
    auth.state = {status: "loading"};
    render(<VotePage electionId="e1" />);
    expect(screen.getByText("Carregando...")).toBeInTheDocument();
    expect(screen.queryByRole("button", {name: "Votar sem conta"})).not.toBeInTheDocument();
  });

  it("mostra título e pede identificação a quem não entrou", () => {
    render(<VotePage electionId="e1" />);
    expect(screen.getByText("Eleição 2026")).toBeInTheDocument();
    expect(screen.getByRole("button", {name: "Votar sem conta"})).toBeInTheDocument();
    expect(screen.getByRole("button", {name: "Entrar com a conta do app"})).toBeInTheDocument();
  });

  it("convidado: entra como anônimo e faz check-in com nome e e-mail", async () => {
    render(<VotePage electionId="e1" />);
    fireEvent.click(screen.getByRole("button", {name: "Votar sem conta"}));
    fireEvent.change(screen.getByLabelText("Seu nome"), {target: {value: "Maria"}});
    fireEvent.change(screen.getByLabelText("Seu e-mail"), {target: {value: "maria@x.org"}});
    fireEvent.click(screen.getByRole("button", {name: "Continuar"}));
    await waitFor(() => expect(api.checkIn).toHaveBeenCalledWith("e1", {name: "Maria", email: "maria@x.org"}));
    expect(api.signInGuest).toHaveBeenCalled();
  });

  it("logado com a conta do app faz check-in automático, sem formulário", async () => {
    auth.state = signedIn(false);
    api.voter = null;
    render(<VotePage electionId="e1" />);
    await waitFor(() => expect(api.checkIn).toHaveBeenCalledWith("e1"));
  });

  it("anônimo sem check-in vê só o formulário de convidado", () => {
    auth.state = signedIn(true);
    api.voter = null;
    render(<VotePage electionId="e1" />);
    expect(screen.getByLabelText("Seu nome")).toBeInTheDocument();
    expect(api.checkIn).not.toHaveBeenCalled();
  });

  it("pendente e recusado", () => {
    auth.state = signedIn(true);
    api.voter = voter("pending");
    const { rerender } = render(<VotePage electionId="e1" />);
    expect(screen.getByText(/Aguardando aprovação/)).toBeInTheDocument();
    api.voter = voter("rejected");
    rerender(<VotePage electionId="e1" key="again" />);
    expect(screen.getByText(/não foi liberada/)).toBeInTheDocument();
  });

  it("aprovado sem votação aberta aguarda", () => {
    auth.state = signedIn(true);
    api.voter = voter("approved");
    api.round = null;
    render(<VotePage electionId="e1" />);
    expect(screen.getByText(/Aguardando a próxima votação/)).toBeInTheDocument();
  });

  it("vota: só habilita com escolha, envia e mostra o recibo", async () => {
    auth.state = signedIn(true);
    api.voter = voter("approved");
    api.round = round;
    api.hasVoted = false;
    render(<VotePage electionId="e1" />);
    const confirm = screen.getByRole("button", {name: "Confirmar voto"});
    expect(confirm).toBeDisabled();
    fireEvent.click(screen.getByLabelText("Bia"));
    expect(confirm).toBeEnabled();
    fireEvent.click(confirm);
    await waitFor(() => expect(api.castVote).toHaveBeenCalledWith("e1", "r1", "b"));
    expect(await screen.findByText("RECIBO123")).toBeInTheDocument();
  });

  it("candidato único: Sim, Não ou Branco", () => {
    auth.state = signedIn(true);
    api.voter = voter("approved");
    api.round = {...round, type: "single", candidates: [round.candidates[0]]};
    api.hasVoted = false;
    render(<VotePage electionId="e1" />);
    expect(screen.getByLabelText("Sim")).toBeInTheDocument();
    expect(screen.getByLabelText("Não")).toBeInTheDocument();
    expect(screen.getByLabelText("Branco")).toBeInTheDocument();
  });

  it("erro do servidor ao votar aparece na tela", async () => {
    auth.state = signedIn(true);
    api.voter = voter("approved");
    api.round = round;
    api.hasVoted = false;
    api.castVote.mockRejectedValue(new Error("Esta votação não está aberta."));
    render(<VotePage electionId="e1" />);
    fireEvent.click(screen.getByLabelText("Branco"));
    fireEvent.click(screen.getByRole("button", {name: "Confirmar voto"}));
    expect(await screen.findByRole("alert")).toHaveTextContent("Esta votação não está aberta.");
  });

  it("já votou", () => {
    auth.state = signedIn(true);
    api.voter = voter("approved");
    api.round = round;
    api.hasVoted = true;
    render(<VotePage electionId="e1" />);
    expect(screen.getByText(/Seu voto foi registrado/)).toBeInTheDocument();
  });

  it("eleição encerrada e inexistente", () => {
    api.election = election("closed");
    const { rerender } = render(<VotePage electionId="e1" />);
    expect(screen.getByText(/foi encerrada/)).toBeInTheDocument();
    api.election = null;
    rerender(<VotePage electionId="e1" key="x" />);
    expect(screen.getByText(/não encontrada/)).toBeInTheDocument();
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `cd web-portal && npx vitest run src/modules/elections/pages/VotePage.test.tsx`
Expected: FAIL (módulos não existem).

- [ ] **Step 4: Implementar**

`web-portal/src/modules/elections/data/electionClient.ts`:

```ts
import {
  GoogleAuthProvider,
  signInAnonymously,
  signInWithEmailAndPassword,
  signInWithPopup,
} from "firebase/auth";
import {
  collection,
  doc,
  limit,
  onSnapshot,
  query,
  where,
  type Unsubscribe,
} from "firebase/firestore";
import {httpsCallable} from "firebase/functions";
import {auth, db, functions} from "@/core/firebase/client";
import type {Election, Round, Voter} from "../types";

type OnError = (message: string) => void;

export function watchElection(
  id: string,
  onData: (election: Election | null) => void,
  onError: OnError
): Unsubscribe {
  return onSnapshot(
    doc(db, "elections", id),
    (snap) =>
      onData(snap.exists() ? ({id: snap.id, ...snap.data()} as Election) : null),
    (e) => onError(e.message)
  );
}

export function watchVoter(
  electionId: string,
  uid: string,
  onData: (voter: Voter | null) => void,
  onError: OnError
): Unsubscribe {
  return onSnapshot(
    doc(db, "elections", electionId, "voters", uid),
    (snap) => onData(snap.exists() ? (snap.data() as Voter) : null),
    (e) => onError(e.message)
  );
}

export function watchOpenRound(
  electionId: string,
  onData: (round: Round | null) => void,
  onError: OnError
): Unsubscribe {
  const q = query(
    collection(db, "elections", electionId, "rounds"),
    where("status", "==", "open"),
    limit(1)
  );
  return onSnapshot(
    q,
    (snap) =>
      onData(
        snap.empty ?
          null :
          ({id: snap.docs[0].id, ...snap.docs[0].data()} as Round)
      ),
    (e) => onError(e.message)
  );
}

export function watchHasVoted(
  electionId: string,
  roundId: string,
  uid: string,
  onData: (hasVoted: boolean) => void,
  onError: OnError
): Unsubscribe {
  return onSnapshot(
    doc(db, "elections", electionId, "rounds", roundId, "voted", uid),
    (snap) => onData(snap.exists()),
    (e) => onError(e.message)
  );
}

export async function checkIn(
  electionId: string,
  guest?: {name: string; email: string}
): Promise<void> {
  const call = httpsCallable(functions, "electionCheckIn");
  await call({electionId, ...guest});
}

export async function castVote(
  electionId: string,
  roundId: string,
  choice: string
): Promise<string> {
  const call = httpsCallable<
    {electionId: string; roundId: string; choice: string},
    {receipt: string}
  >(functions, "electionCastVote");
  const res = await call({electionId, roundId, choice});
  return res.data.receipt;
}

export const signInGuest = () => signInAnonymously(auth);

export const signInWithPassword = (email: string, password: string) =>
  signInWithEmailAndPassword(auth, email.trim(), password);

export const signInWithGoogle = () =>
  signInWithPopup(auth, new GoogleAuthProvider());

export function errorMessage(e: unknown): string {
  return e instanceof Error && e.message ? e.message : "Algo deu errado.";
}
```

`web-portal/src/modules/elections/components/JoinStep.tsx`:

```tsx
"use client";

import {useState, type FormEvent} from "react";
import {authErrorMessage} from "@/core/auth/errors";
import {Button} from "@/core/ui/Button";
import {TextField} from "@/core/ui/TextField";
import {
  checkIn,
  errorMessage,
  signInGuest,
  signInWithGoogle,
  signInWithPassword,
} from "../data/electionClient";

type Mode = "choose" | "login" | "guest";

interface Props {
  electionId: string;
  /** Já há sessão anônima sem check-in: só falta o formulário de convidado. */
  anonymousSession: boolean;
  /** Sessão com conta do app: o check-in automático está em andamento. */
  verifying: boolean;
}

export function JoinStep({electionId, anonymousSession, verifying}: Props) {
  const [mode, setMode] = useState<Mode>(anonymousSession ? "guest" : "choose");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [guestEmail, setGuestEmail] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function run(action: () => Promise<unknown>, onError = errorMessage) {
    setBusy(true);
    setError(null);
    try {
      await action();
    } catch (e) {
      setError(onError(e));
    } finally {
      setBusy(false);
    }
  }

  const authMessage = (e: unknown) =>
    authErrorMessage((e as {code?: string}).code ?? "");

  if (verifying) {
    return <p className="text-sm text-white/70">Verificando sua presença...</p>;
  }

  if (mode === "choose") {
    return (
      <div className="space-y-3">
        <Button type="button" className="w-full" onClick={() => setMode("login")}>
          Entrar com a conta do app
        </Button>
        <Button type="button" variant="text" className="w-full" onClick={() => setMode("guest")}>
          Votar sem conta
        </Button>
      </div>
    );
  }

  if (mode === "login") {
    return (
      <div className="space-y-4">
        <form
          className="space-y-4"
          onSubmit={(event: FormEvent) => {
            event.preventDefault();
            void run(() => signInWithPassword(email, password), authMessage);
          }}
        >
          <TextField id="email" label="E-mail" type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
          <TextField id="password" label="Senha" type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
          {error && <p role="alert" className="text-sm text-error">{error}</p>}
          <Button type="submit" disabled={busy} className="w-full">Entrar</Button>
        </form>
        <Button type="button" variant="text" disabled={busy} className="w-full" onClick={() => run(() => signInWithGoogle(), authMessage)}>
          Entrar com Google
        </Button>
        <Button type="button" variant="text" className="w-full" onClick={() => { setError(null); setMode("choose"); }}>
          Voltar
        </Button>
      </div>
    );
  }

  return (
    <form
      className="space-y-4"
      onSubmit={(event: FormEvent) => {
        event.preventDefault();
        void run(async () => {
          if (!anonymousSession) await signInGuest();
          await checkIn(electionId, {name: name.trim(), email: guestEmail.trim()});
        });
      }}
    >
      <TextField id="guest-name" label="Seu nome" required value={name} onChange={(e) => setName(e.target.value)} />
      <TextField id="guest-email" label="Seu e-mail" type="email" required value={guestEmail} onChange={(e) => setGuestEmail(e.target.value)} />
      {error && <p role="alert" className="text-sm text-error">{error}</p>}
      <Button type="submit" disabled={busy} className="w-full">Continuar</Button>
      {!anonymousSession && (
        <Button type="button" variant="text" className="w-full" onClick={() => { setError(null); setMode("choose"); }}>
          Voltar
        </Button>
      )}
    </form>
  );
}
```

`web-portal/src/modules/elections/components/BallotStep.tsx`:

```tsx
"use client";

import {useState} from "react";
import {Button} from "@/core/ui/Button";
import {positionLabel, type Round} from "../types";

interface Props {
  round: Round;
  busy: boolean;
  error: string | null;
  onSubmit: (choice: string) => void;
}

export function BallotStep({round, busy, error, onSubmit}: Props) {
  const [choice, setChoice] = useState<string | null>(null);
  const cargo = positionLabel(round.position);
  const single = round.type === "single";

  const options = single ?
    [
      {value: "yes", label: "Sim"},
      {value: "no", label: "Não"},
      {value: "blank", label: "Branco"},
    ] :
    [
      ...round.candidates.map((c) => ({value: c.id, label: c.name})),
      {value: "blank", label: "Branco"},
    ];

  return (
    <div className="space-y-4">
      <h2 className="text-lg font-semibold">
        {single ?
          `${round.candidates[0]?.name} deve ser ${cargo}?` :
          `Votação para ${cargo}`}
      </h2>
      <div role="radiogroup" className="space-y-2">
        {options.map((option) => (
          <label
            key={option.value}
            className="flex cursor-pointer items-center gap-3 rounded-card bg-white/5 px-4 py-3"
          >
            <input
              type="radio"
              name="choice"
              value={option.value}
              checked={choice === option.value}
              onChange={() => setChoice(option.value)}
            />
            {option.label}
          </label>
        ))}
      </div>
      {error && <p role="alert" className="text-sm text-error">{error}</p>}
      <Button
        type="button"
        className="w-full"
        disabled={busy || choice === null}
        onClick={() => choice !== null && onSubmit(choice)}
      >
        Confirmar voto
      </Button>
    </div>
  );
}
```

`web-portal/src/modules/elections/pages/VotePage.tsx`:

```tsx
"use client";

import {useEffect, useRef, useState} from "react";
import {useAuth} from "@/core/auth/AuthContext";
import {GlassCard} from "@/core/ui/GlassCard";
import {BallotStep} from "../components/BallotStep";
import {JoinStep} from "../components/JoinStep";
import {
  castVote,
  checkIn,
  errorMessage,
  watchElection,
  watchHasVoted,
  watchOpenRound,
  watchVoter,
} from "../data/electionClient";
import type {Election, Round, Voter} from "../types";
import {positionLabel} from "../types";
import {deriveView, type VoteView} from "../voteState";

export function VotePage({electionId}: {electionId: string}) {
  const {state} = useAuth();
  const user = state.status === "signedIn" ? state.user : null;
  const uid = user?.uid;

  const [election, setElection] = useState<Election | null | undefined>(undefined);
  const [voter, setVoter] = useState<Voter | null | undefined>(undefined);
  const [openRound, setOpenRound] = useState<Round | null | undefined>(undefined);
  const [hasVoted, setHasVoted] = useState<boolean | undefined>(undefined);
  const [receipts, setReceipts] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const autoCheckIn = useRef(false);

  useEffect(
    () => watchElection(electionId, setElection, setError),
    [electionId]
  );
  useEffect(() => {
    if (!uid) return;
    return watchVoter(electionId, uid, setVoter, setError);
  }, [electionId, uid]);

  const approved = voter?.status === "approved";
  useEffect(() => {
    if (!uid || !approved) return;
    return watchOpenRound(electionId, setOpenRound, setError);
  }, [electionId, uid, approved]);

  const roundId = openRound?.id;
  useEffect(() => {
    if (!uid || !roundId) return;
    return watchHasVoted(electionId, roundId, uid, setHasVoted, setError);
  }, [electionId, uid, roundId]);

  // Quem entrou com a conta do app não digita nada: o servidor decide se é
  // membro (liberado) ou convidado (pendente).
  const needsAutoCheckIn =
    !!user && !user.isAnonymous && voter === null && election?.status === "open";
  useEffect(() => {
    if (!needsAutoCheckIn || autoCheckIn.current) return;
    autoCheckIn.current = true;
    checkIn(electionId).catch((e) => {
      autoCheckIn.current = false;
      setError(errorMessage(e));
    });
  }, [needsAutoCheckIn, electionId]);

  // Enquanto a sessão carrega, ainda não se sabe se há usuário: não mostre
  // o formulário de entrada para quem já está logado.
  const view: VoteView =
    state.status === "loading" ?
      {kind: "loading"} :
      deriveView({
        election,
        voter: uid ? voter : undefined,
        openRound: uid && approved ? openRound : undefined,
        hasVoted: uid && roundId ? hasVoted : undefined,
        hasUser: !!user,
      });

  async function submit(round: Round, choice: string) {
    setBusy(true);
    setError(null);
    try {
      const receipt = await castVote(electionId, round.id, choice);
      setReceipts((prev) => ({...prev, [round.id]: receipt}));
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-md items-center justify-center p-6">
      <GlassCard className="w-full">
        {election && (
          <header className="mb-6">
            <h1 className="text-2xl font-semibold">{election.title}</h1>
            <p className="text-sm text-white/70">{election.societyName}</p>
          </header>
        )}
        {view.kind === "loading" && <p className="text-sm text-white/70">Carregando...</p>}
        {view.kind === "notFound" && <p>Eleição não encontrada.</p>}
        {view.kind === "notOpen" && <p>Esta eleição ainda não foi aberta. Aguarde o início.</p>}
        {view.kind === "closed" && <p>Esta eleição foi encerrada.</p>}
        {view.kind === "join" && (
          <JoinStep
            electionId={electionId}
            anonymousSession={!!user?.isAnonymous}
            verifying={!!user && !user.isAnonymous}
          />
        )}
        {view.kind === "pending" && (
          <p>Aguardando aprovação do administrador. Esta tela atualiza sozinha.</p>
        )}
        {view.kind === "rejected" && (
          <p>Sua participação não foi liberada. Procure o administrador da eleição.</p>
        )}
        {view.kind === "waitingRound" && (
          <p>Aguardando a próxima votação. Esta tela atualiza sozinha.</p>
        )}
        {view.kind === "ballot" && (
          <BallotStep
            key={view.round.id}
            round={view.round}
            busy={busy}
            error={error}
            onSubmit={(choice) => void submit(view.round, choice)}
          />
        )}
        {view.kind === "voted" && (
          <div className="space-y-2">
            <p>
              Seu voto foi registrado para {positionLabel(view.round.position)}.
              Aguarde a próxima votação.
            </p>
            {receipts[view.round.id] && (
              <div>
                <p className="text-sm text-white/70">Código do seu comprovante:</p>
                <p className="font-mono text-lg">{receipts[view.round.id]}</p>
              </div>
            )}
          </div>
        )}
        {error && view.kind !== "ballot" && (
          <p role="alert" className="mt-4 text-sm text-error">{error}</p>
        )}
      </GlassCard>
    </main>
  );
}
```

`web-portal/src/app/(public)/votar/[id]/page.tsx`:

```tsx
import type {Metadata} from "next";
import {VotePage} from "@/modules/elections/pages/VotePage";

export const metadata: Metadata = {
  title: "Votação — IPE",
  description: "Votação da diretoria.",
};

export default async function Page({
  params,
}: {
  params: Promise<{id: string}>;
}) {
  const {id} = await params;
  return <VotePage electionId={id} />;
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `cd web-portal && npx vitest run && npm run typecheck && npm run lint && npm run build`
Expected: todos os testes passam (incluindo os do módulo `teaching`), typecheck/lint/build sem erros. Se o lint reclamar de `setState` em efeito, ajuste conforme a regra do `eslint-config-next` desta versão sem mudar o comportamento testado.

- [ ] **Step 6: Commit**

```bash
/usr/bin/git add web-portal/src
/usr/bin/git commit -m "feat(elections): página pública de voto no portal"
```

---

## Parte D — App Flutter (admins)

### Task 8: Modelos e lógica pura do app

**Files:**
- Modify: `pubspec.yaml` (dependência `cloud_functions`)
- Modify: `lib/src/core/config/app_config.dart` (URL base do portal)
- Create: `lib/src/modules/elections/models/election.dart`
- Create: `lib/src/modules/elections/models/election_logic.dart`
- Create: `lib/src/modules/elections/models/minutes_text.dart`
- Test: `test/modules/elections/election_models_test.dart`
- Test: `test/modules/elections/election_logic_test.dart`
- Test: `test/modules/elections/minutes_text_test.dart`

**Interfaces:**
- Produces (`election.dart`): enums `ElectionStatus {draft,open,closed}`, `RoundStatus {pending,open,closed}`, `RoundType {normal,single,runoff}`, `VoterStatus {pending,approved,rejected}`, `VoterKind {member,guest}` (todos com `static parse(Object?)`); classes `Candidate {id,name; fromJson; toJson}`, `RoundResult {counts,total,votedCount,winnerId,tie,divergence; fromJson}`, `Election`, `ElectionRound`, `ElectionVoter`, `ElectionEvent` — todas com `fromJson(String id, Map<String,dynamic>)` (`Candidate`/`RoundResult` sem id).
  - `Election {id, societyId, societyName, title, scheduledAt (DateTime), status, positions (List<String>), boardAppliedAt (DateTime?)}`
  - `ElectionRound {id, position, candidates (List<Candidate>), type, status, votedCount, result (RoundResult?), closedAt (DateTime?)}`
  - `ElectionVoter {id, name, email, kind, status}`
  - `ElectionEvent {id, type, at (DateTime?), data (Map<String,dynamic>)}`
- Produces (`election_logic.dart`): `Map<String,String> latestWinners(List<ElectionRound>)` (cargo → candidateId), `List<Candidate> candidateOptions({required List<Candidate> members, required List<ElectionRound> rounds, required String position})`, `Set<String> duplicateVoterIds(List<ElectionVoter>)`, `String buildVoteLink(String electionId)`.
- Produces (`minutes_text.dart`): `String buildMinutesText({required Election election, required List<ElectionVoter> voters, required List<ElectionRound> rounds, required List<ElectionEvent> events})`.
- Produces (`AppConfig`): `static const String portalBaseUrl` (env `PORTAL_BASE_URL`, padrão `https://ipe-ensino.vercel.app`).

- [ ] **Step 1: Dependência e configuração**

`pubspec.yaml` — logo abaixo de `cloud_firestore: ^5.4.3`:

```yaml
  cloud_functions: ^5.1.3
```

`lib/src/core/config/app_config.dart` — dentro de `AppConfig`:

```dart
  /// URL base do portal web (página pública de votação em /votar/{id}).
  static const String portalBaseUrl = String.fromEnvironment(
    'PORTAL_BASE_URL',
    defaultValue: 'https://ipe-ensino.vercel.app',
  );
```

Run: `flutter pub get`
Expected: resolve `cloud_functions` compatível com `firebase_core ^3.6.0`. Se a resolução falhar, use a versão que o `pub` sugerir para `firebase_core 3.x`.

- [ ] **Step 2: Escrever os testes que falham**

`test/modules/elections/election_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';

void main() {
  test('Election.fromJson lê campos e usa defaults seguros', () {
    final e = Election.fromJson('e1', {
      'societyId': 's1',
      'societyName': 'UMP',
      'title': 'Eleição 2026',
      'scheduledAt': DateTime(2026, 10, 20, 19, 30),
      'status': 'open',
      'positions': ['presidente', 'vice'],
    });
    expect(e.id, 'e1');
    expect(e.status, ElectionStatus.open);
    expect(e.positions, ['presidente', 'vice']);
    expect(e.boardAppliedAt, isNull);
    expect(Election.fromJson('x', {}).status, ElectionStatus.draft);
  });

  test('ElectionRound.fromJson com resultado', () {
    final r = ElectionRound.fromJson('r1', {
      'position': 'presidente',
      'type': 'single',
      'status': 'closed',
      'votedCount': 3,
      'candidates': [
        {'id': 'a', 'name': 'Ana'}
      ],
      'closedAt': DateTime(2026, 10, 20, 20),
      'result': {
        'counts': {'yes': 2, 'no': 1, 'blank': 0},
        'total': 3,
        'votedCount': 3,
        'winnerId': 'a',
        'tie': [],
        'divergence': false,
      },
    });
    expect(r.type, RoundType.single);
    expect(r.status, RoundStatus.closed);
    expect(r.candidates.single.name, 'Ana');
    expect(r.result!.winnerId, 'a');
    expect(r.result!.counts['yes'], 2);
    expect(r.closedAt, DateTime(2026, 10, 20, 20));
  });

  test('ElectionRound.fromJson sem resultado nem candidatos', () {
    final r = ElectionRound.fromJson('r1', {'position': 'vice'});
    expect(r.status, RoundStatus.pending);
    expect(r.candidates, isEmpty);
    expect(r.result, isNull);
  });

  test('ElectionVoter e ElectionEvent', () {
    final v = ElectionVoter.fromJson('u1', {
      'name': 'Maria', 'email': 'm@x.org', 'kind': 'guest', 'status': 'pending',
    });
    expect(v.kind, VoterKind.guest);
    expect(v.status, VoterStatus.pending);
    final ev = ElectionEvent.fromJson('ev1', {
      'type': 'round_opened', 'at': DateTime(2026, 10, 20, 19, 40), 'position': 'vice',
    });
    expect(ev.type, 'round_opened');
    expect(ev.data['position'], 'vice');
  });

  test('Candidate.toJson', () {
    expect(const Candidate(id: 'a', name: 'Ana').toJson(), {'id': 'a', 'name': 'Ana'});
  });
}
```

`test/modules/elections/election_logic_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';
import 'package:ipe_flutter/src/modules/elections/models/election_logic.dart';

ElectionRound round(
  String id,
  String position, {
  RoundStatus status = RoundStatus.closed,
  String? winner,
  int closedMs = 1,
}) =>
    ElectionRound(
      id: id,
      position: position,
      candidates: const [],
      type: RoundType.normal,
      status: status,
      votedCount: 0,
      closedAt: DateTime.fromMillisecondsSinceEpoch(closedMs),
      result: winner == null
          ? null
          : RoundResult(
              counts: const {},
              total: 0,
              votedCount: 0,
              winnerId: winner,
              tie: const [],
              divergence: false,
            ),
    );

ElectionVoter voter(String id, String name, String email) => ElectionVoter(
      id: id,
      name: name,
      email: email,
      kind: VoterKind.guest,
      status: VoterStatus.pending,
    );

void main() {
  group('latestWinners', () {
    test('pega o vencedor de cada cargo, ignora rodadas não fechadas', () {
      final w = latestWinners([
        round('1', 'presidente', winner: 'ana'),
        round('2', 'vice', winner: 'bia'),
        round('3', 'secretario', status: RoundStatus.open, winner: 'caio'),
      ]);
      expect(w, {'presidente': 'ana', 'vice': 'bia'});
    });

    test('a rodada fechada mais recente do cargo vale', () {
      final w = latestWinners([
        round('1', 'presidente', winner: 'ana', closedMs: 1),
        round('2', 'presidente', closedMs: 2),
      ]);
      expect(w, isEmpty);
    });
  });

  group('candidateOptions', () {
    const ana = Candidate(id: 'ana', name: 'Ana');
    const bia = Candidate(id: 'bia', name: 'Bia');

    test('remove quem foi eleito em OUTRO cargo', () {
      final options = candidateOptions(
        members: [ana, bia],
        rounds: [round('1', 'presidente', winner: 'ana')],
        position: 'vice',
      );
      expect(options, [bia]);
    });

    test('mantém o vencedor atual do próprio cargo (refazer a votação)', () {
      final options = candidateOptions(
        members: [ana, bia],
        rounds: [round('1', 'presidente', winner: 'ana')],
        position: 'presidente',
      );
      expect(options, [ana, bia]);
    });
  });

  group('duplicateVoterIds', () {
    test('marca quem divide e-mail ou nome (sem diferenciar caixa)', () {
      final ids = duplicateVoterIds([
        voter('1', 'Maria Silva', 'maria@x.org'),
        voter('2', 'maria silva', 'outro@x.org'),
        voter('3', 'João', 'MARIA@x.org'),
        voter('4', 'Pedro', 'pedro@x.org'),
      ]);
      expect(ids, {'1', '2', '3'});
    });

    test('ignora e-mail vazio', () {
      final ids = duplicateVoterIds([
        voter('1', 'Ana', ''),
        voter('2', 'Bia', ''),
      ]);
      expect(ids, isEmpty);
    });
  });

  test('buildVoteLink usa a base do portal', () {
    expect(buildVoteLink('abc'), endsWith('/votar/abc'));
    expect(buildVoteLink('abc'), startsWith('https://'));
  });
}
```

`test/modules/elections/minutes_text_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/elections/models/election.dart';
import 'package:ipe_flutter/src/modules/elections/models/minutes_text.dart';

void main() {
  final election = Election(
    id: 'e1',
    societyId: 's1',
    societyName: 'UMP',
    title: 'Eleição 2026',
    scheduledAt: DateTime(2026, 10, 20, 19, 5),
    status: ElectionStatus.closed,
    positions: const ['presidente', 'vice'],
  );
  const ana = Candidate(id: 'ana', name: 'Ana');
  const bia = Candidate(id: 'bia', name: 'Bia');

  final voters = [
    const ElectionVoter(id: '1', name: 'Ana', email: '', kind: VoterKind.member, status: VoterStatus.approved),
    const ElectionVoter(id: '2', name: 'Maria', email: 'm@x', kind: VoterKind.guest, status: VoterStatus.approved),
    const ElectionVoter(id: '3', name: 'Intruso', email: '', kind: VoterKind.guest, status: VoterStatus.rejected),
    const ElectionVoter(id: '4', name: 'Pendente', email: '', kind: VoterKind.guest, status: VoterStatus.pending),
  ];

  final rounds = [
    ElectionRound(
      id: 'r1', position: 'presidente', candidates: const [ana, bia],
      type: RoundType.normal, status: RoundStatus.closed, votedCount: 3,
      result: const RoundResult(
        counts: {'ana': 2, 'bia': 1, 'blank': 0}, total: 3, votedCount: 3,
        winnerId: 'ana', tie: [], divergence: false,
      ),
    ),
    ElectionRound(
      id: 'r2', position: 'vice', candidates: const [ana, bia],
      type: RoundType.normal, status: RoundStatus.closed, votedCount: 2,
      result: const RoundResult(
        counts: {'ana': 1, 'bia': 1, 'blank': 0}, total: 2, votedCount: 3,
        winnerId: null, tie: ['ana', 'bia'], divergence: true,
      ),
    ),
  ];

  final events = [
    ElectionEvent(id: '2', type: 'round_opened', at: DateTime(2026, 10, 20, 19, 40), data: const {'position': 'presidente'}),
    ElectionEvent(id: '1', type: 'election_opened', at: DateTime(2026, 10, 20, 19, 10), data: const {}),
  ];

  final text = buildMinutesText(
    election: election, voters: voters, rounds: rounds, events: events,
  );

  test('cabeçalho', () {
    expect(text, contains('ATA DA ELEIÇÃO — Eleição 2026'));
    expect(text, contains('Sociedade: UMP'));
    expect(text, contains('20/10/2026 19:05'));
    expect(text, contains('Encerrada'));
  });

  test('presentes: só aprovados, com o tipo', () {
    expect(text, contains('PRESENTES (2)'));
    expect(text, contains('- Ana (membro)'));
    expect(text, contains('- Maria (convidado)'));
    expect(text, isNot(contains('Intruso')));
    expect(text, isNot(contains('Pendente')));
  });

  test('votações com contagem, vencedor, empate e divergência', () {
    expect(text, contains('Presidente'));
    expect(text, contains('Ana: 2'));
    expect(text, contains('Eleito(a): Ana'));
    expect(text, contains('Empate entre: Ana, Bia'));
    expect(text, contains('ATENÇÃO'));
  });

  test('linha do tempo ordenada por horário', () {
    final i1 = text.indexOf('19:10');
    final i2 = text.indexOf('19:40');
    expect(i1, greaterThan(-1));
    expect(i2, greaterThan(i1));
    expect(text, contains('Votação aberta — Presidente'));
    expect(text, contains('Eleição aberta'));
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/modules/elections`
Expected: FAIL (arquivos de `lib/src/modules/elections/models/` não existem).

- [ ] **Step 4: Implementar**

`lib/src/modules/elections/models/election.dart`:

```dart
DateTime? _date(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}

List<String> _strings(Object? value) =>
    value is List ? value.map((e) => e.toString()).toList() : const [];

T _parse<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return fallback;
}

enum ElectionStatus {
  draft,
  open,
  closed;

  static ElectionStatus parse(Object? raw) =>
      _parse(values, raw, ElectionStatus.draft);
}

enum RoundStatus {
  pending,
  open,
  closed;

  static RoundStatus parse(Object? raw) =>
      _parse(values, raw, RoundStatus.pending);
}

enum RoundType {
  normal,
  single,
  runoff;

  static RoundType parse(Object? raw) => _parse(values, raw, RoundType.normal);
}

enum VoterStatus {
  pending,
  approved,
  rejected;

  static VoterStatus parse(Object? raw) =>
      _parse(values, raw, VoterStatus.pending);
}

enum VoterKind {
  member,
  guest;

  static VoterKind parse(Object? raw) => _parse(values, raw, VoterKind.guest);
}

class Candidate {
  const Candidate({required this.id, required this.name});

  final String id;
  final String name;

  factory Candidate.fromJson(Map<String, dynamic> json) => Candidate(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class RoundResult {
  const RoundResult({
    required this.counts,
    required this.total,
    required this.votedCount,
    required this.winnerId,
    required this.tie,
    required this.divergence,
  });

  final Map<String, int> counts;
  final int total;
  final int votedCount;
  final String? winnerId;
  final List<String> tie;
  final bool divergence;

  factory RoundResult.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['counts'];
    return RoundResult(
      counts: rawCounts is Map
          ? rawCounts.map((k, v) => MapEntry(k.toString(), (v as num).toInt()))
          : const {},
      total: (json['total'] as num?)?.toInt() ?? 0,
      votedCount: (json['votedCount'] as num?)?.toInt() ?? 0,
      winnerId: json['winnerId']?.toString(),
      tie: _strings(json['tie']),
      divergence: json['divergence'] == true,
    );
  }
}

class Election {
  const Election({
    required this.id,
    required this.societyId,
    required this.societyName,
    required this.title,
    required this.scheduledAt,
    required this.status,
    required this.positions,
    this.boardAppliedAt,
  });

  final String id;
  final String societyId;
  final String societyName;
  final String title;
  final DateTime scheduledAt;
  final ElectionStatus status;
  final List<String> positions;
  final DateTime? boardAppliedAt;

  factory Election.fromJson(String id, Map<String, dynamic> json) => Election(
        id: id,
        societyId: json['societyId']?.toString() ?? '',
        societyName: json['societyName']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        scheduledAt: _date(json['scheduledAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        status: ElectionStatus.parse(json['status']),
        positions: _strings(json['positions']),
        boardAppliedAt: _date(json['boardAppliedAt']),
      );
}

class ElectionRound {
  const ElectionRound({
    required this.id,
    required this.position,
    required this.candidates,
    required this.type,
    required this.status,
    required this.votedCount,
    this.result,
    this.closedAt,
  });

  final String id;
  final String position;
  final List<Candidate> candidates;
  final RoundType type;
  final RoundStatus status;
  final int votedCount;
  final RoundResult? result;
  final DateTime? closedAt;

  factory ElectionRound.fromJson(String id, Map<String, dynamic> json) {
    final rawCandidates = json['candidates'];
    final rawResult = json['result'];
    return ElectionRound(
      id: id,
      position: json['position']?.toString() ?? '',
      candidates: rawCandidates is List
          ? rawCandidates
              .map((c) => Candidate.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList()
          : const [],
      type: RoundType.parse(json['type']),
      status: RoundStatus.parse(json['status']),
      votedCount: (json['votedCount'] as num?)?.toInt() ?? 0,
      result: rawResult is Map
          ? RoundResult.fromJson(Map<String, dynamic>.from(rawResult))
          : null,
      closedAt: _date(json['closedAt']),
    );
  }
}

class ElectionVoter {
  const ElectionVoter({
    required this.id,
    required this.name,
    required this.email,
    required this.kind,
    required this.status,
  });

  final String id;
  final String name;
  final String email;
  final VoterKind kind;
  final VoterStatus status;

  factory ElectionVoter.fromJson(String id, Map<String, dynamic> json) =>
      ElectionVoter(
        id: id,
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        kind: VoterKind.parse(json['kind']),
        status: VoterStatus.parse(json['status']),
      );
}

class ElectionEvent {
  const ElectionEvent({
    required this.id,
    required this.type,
    required this.at,
    required this.data,
  });

  final String id;
  final String type;
  final DateTime? at;
  final Map<String, dynamic> data;

  factory ElectionEvent.fromJson(String id, Map<String, dynamic> json) =>
      ElectionEvent(
        id: id,
        type: json['type']?.toString() ?? '',
        at: _date(json['at']),
        data: Map<String, dynamic>.from(json),
      );
}
```

`lib/src/modules/elections/models/election_logic.dart`:

```dart
import '../../../core/config/app_config.dart';
import 'election.dart';

/// Vencedor de cada cargo (cargo → id do candidato): vale a rodada fechada
/// mais recente do cargo; sem vencedor nela, o cargo fica sem vencedor.
/// Espelha `pickWinners` das Functions.
Map<String, String> latestWinners(List<ElectionRound> rounds) {
  final latest = <String, ElectionRound>{};
  for (final r in rounds) {
    if (r.status != RoundStatus.closed) continue;
    final current = latest[r.position];
    final ms = r.closedAt?.millisecondsSinceEpoch ?? 0;
    final currentMs = current?.closedAt?.millisecondsSinceEpoch ?? 0;
    if (current == null || ms >= currentMs) latest[r.position] = r;
  }
  return {
    for (final e in latest.entries)
      if (e.value.result?.winnerId != null) e.key: e.value.result!.winnerId!,
  };
}

/// Membros que ainda podem ser candidatos ao cargo: tira quem já foi eleito
/// em OUTRO cargo. (O servidor repete essa regra ao abrir a votação.)
List<Candidate> candidateOptions({
  required List<Candidate> members,
  required List<ElectionRound> rounds,
  required String position,
}) {
  final others = rounds.where((r) => r.position != position).toList();
  final elected = latestWinners(others).values.toSet();
  return members.where((m) => !elected.contains(m.id)).toList();
}

/// Ids de eleitores que dividem e-mail (não vazio) ou nome com outro.
Set<String> duplicateVoterIds(List<ElectionVoter> voters) {
  final byEmail = <String, List<String>>{};
  final byName = <String, List<String>>{};
  for (final v in voters) {
    final email = v.email.trim().toLowerCase();
    final name = v.name.trim().toLowerCase();
    if (email.isNotEmpty) byEmail.putIfAbsent(email, () => []).add(v.id);
    if (name.isNotEmpty) byName.putIfAbsent(name, () => []).add(v.id);
  }
  return {
    for (final ids in [...byEmail.values, ...byName.values])
      if (ids.length > 1) ...ids,
  };
}

String buildVoteLink(String electionId) =>
    '${AppConfig.portalBaseUrl}/votar/$electionId';
```

`lib/src/modules/elections/models/minutes_text.dart`:

```dart
import '../../societies/models/society.dart';
import 'election.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String _dateTime(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';

String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String positionLabel(String position) =>
    BoardPosition.fromString(position)?.label ?? position;

String _statusLabel(ElectionStatus s) => switch (s) {
      ElectionStatus.draft => 'Rascunho',
      ElectionStatus.open => 'Em andamento',
      ElectionStatus.closed => 'Encerrada',
    };

String _candidateName(ElectionRound round, String id) {
  for (final c in round.candidates) {
    if (c.id == id) return c.name;
  }
  return id;
}

String _eventLine(ElectionEvent e) {
  final cargo = positionLabel((e.data['position'] ?? '').toString());
  final label = switch (e.type) {
    'election_opened' => 'Eleição aberta',
    'election_closed' => 'Eleição encerrada',
    'round_opened' => 'Votação aberta — $cargo',
    'round_closed' => 'Votação encerrada — $cargo',
    'board_applied' => 'Diretoria aplicada na sociedade',
    _ => null,
  };
  if (label == null || e.at == null) return '';
  return '- ${_time(e.at!)} $label';
}

/// Ata da eleição em texto puro, gerada do que está gravado (presentes,
/// rodadas apuradas e log de eventos).
String buildMinutesText({
  required Election election,
  required List<ElectionVoter> voters,
  required List<ElectionRound> rounds,
  required List<ElectionEvent> events,
}) {
  final b = StringBuffer()
    ..writeln('ATA DA ELEIÇÃO — ${election.title}')
    ..writeln('Sociedade: ${election.societyName}')
    ..writeln('Data: ${_dateTime(election.scheduledAt)}')
    ..writeln('Situação: ${_statusLabel(election.status)}')
    ..writeln();

  final present =
      voters.where((v) => v.status == VoterStatus.approved).toList();
  b.writeln('PRESENTES (${present.length})');
  for (final v in present) {
    b.writeln('- ${v.name} (${v.kind == VoterKind.member ? 'membro' : 'convidado'})');
  }
  b.writeln();

  b.writeln('VOTAÇÕES');
  for (final r in rounds) {
    final tipo = switch (r.type) {
      RoundType.single => 'candidato único',
      RoundType.runoff => 'desempate',
      RoundType.normal => 'maioria simples',
    };
    b.writeln('${positionLabel(r.position)} — $tipo');
    final res = r.result;
    if (r.status != RoundStatus.closed || res == null) {
      b.writeln('  ${r.status == RoundStatus.open ? 'Em andamento' : 'Ainda não votada'}');
      continue;
    }
    final parts = <String>[];
    if (r.type == RoundType.single) {
      parts.add('Sim: ${res.counts['yes'] ?? 0}');
      parts.add('Não: ${res.counts['no'] ?? 0}');
    } else {
      for (final c in r.candidates) {
        parts.add('${c.name}: ${res.counts[c.id] ?? 0}');
      }
    }
    parts.add('Branco: ${res.counts['blank'] ?? 0}');
    b.writeln('  ${parts.join(' · ')} (total ${res.total})');
    if (res.winnerId != null) {
      b.writeln('  Eleito(a): ${_candidateName(r, res.winnerId!)}');
    } else if (res.tie.isNotEmpty) {
      b.writeln('  Empate entre: ${res.tie.map((id) => _candidateName(r, id)).join(', ')}');
    } else {
      b.writeln('  Ninguém foi eleito(a).');
    }
    if (res.divergence) {
      b.writeln('  ATENÇÃO: votos contados (${res.total}) diferem de votantes (${res.votedCount}).');
    }
  }
  b.writeln();

  final timeline = events.where((e) => e.at != null).toList()
    ..sort((a, b) => a.at!.compareTo(b.at!));
  final lines = timeline.map(_eventLine).where((l) => l.isNotEmpty).toList();
  if (lines.isNotEmpty) {
    b.writeln('LINHA DO TEMPO');
    for (final l in lines) {
      b.writeln(l);
    }
  }
  return b.toString().trimRight();
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/modules/elections && flutter analyze lib/src/modules/elections lib/src/core/config/app_config.dart`
Expected: PASS e sem problemas no analyze.

- [ ] **Step 6: Commit**

```bash
/usr/bin/git add pubspec.yaml pubspec.lock lib/src/core/config/app_config.dart lib/src/modules/elections test/modules/elections
/usr/bin/git commit -m "feat(elections): modelos e lógica pura no app Flutter"
```

---

### Task 9: Repositório do app (Firestore + Functions)

**Files:**
- Create: `lib/src/modules/elections/data/elections_repository.dart`
- Modify: `lib/main.dart` (registrar o provider)

**Interfaces:**
- Consumes: `election.dart` (Task 8); `AppException` de `lib/src/core/utils/app_exception.dart`.
- Produces `ElectionsRepository`:
  - `Stream<List<Election>> watchElections()`
  - `Stream<Election?> watchElection(String id)`
  - `Stream<List<ElectionRound>> watchRounds(String electionId)`
  - `Stream<List<ElectionVoter>> watchVoters(String electionId)`
  - `Stream<List<ElectionEvent>> watchEvents(String electionId)`
  - `Future<String> createElection({required String societyId, required String societyName, required String title, required DateTime scheduledAt, required List<String> positions})`
  - `Future<void> saveRoundCandidates({required String electionId, required String position, required List<Candidate> candidates, String? roundId, RoundType type = RoundType.normal})` (cria ou edita rodada pendente)
  - `Future<void> deleteRound(String electionId, String roundId)`
  - `Future<void> setStatus(String electionId, ElectionStatus target)` (`open`/`closed`)
  - `Future<void> reviewVoter(String electionId, String voterId, VoterStatus decision)`
  - `Future<void> openRound(String electionId, String roundId)`
  - `Future<RoundResult> closeRound(String electionId, String roundId)`
  - `Future<void> applyBoard(String electionId)`

Sem teste unitário próprio (envolve Firebase); a lógica de cada chamada é coberta nas Tasks 3–5 e a fiação é verificada na Task 13. Rode o `analyze` ao final.

- [ ] **Step 1: Implementar** — `lib/src/modules/elections/data/elections_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/utils/app_exception.dart';
import '../models/election.dart';

class ElectionsRepository {
  ElectionsRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _election(String id) =>
      _db.collection('elections').doc(id);

  Stream<List<Election>> watchElections() => _db
      .collection('elections')
      .orderBy('scheduledAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Election.fromJson(d.id, d.data())).toList());

  Stream<Election?> watchElection(String id) => _election(id)
      .snapshots()
      .map((d) => d.exists ? Election.fromJson(d.id, d.data()!) : null);

  Stream<List<ElectionRound>> watchRounds(String electionId) => _election(electionId)
      .collection('rounds')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map((d) => ElectionRound.fromJson(d.id, d.data())).toList());

  Stream<List<ElectionVoter>> watchVoters(String electionId) => _election(electionId)
      .collection('voters')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map((d) => ElectionVoter.fromJson(d.id, d.data())).toList());

  Stream<List<ElectionEvent>> watchEvents(String electionId) => _election(electionId)
      .collection('events')
      .orderBy('at')
      .snapshots()
      .map((s) => s.docs.map((d) => ElectionEvent.fromJson(d.id, d.data())).toList());

  Future<String> createElection({
    required String societyId,
    required String societyName,
    required String title,
    required DateTime scheduledAt,
    required List<String> positions,
  }) async {
    try {
      final ref = await _db.collection('elections').add({
        'societyId': societyId,
        'societyName': societyName,
        'title': title,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'status': 'draft',
        'positions': positions,
        'createdBy': _auth.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      throw AppException(message: 'Erro ao criar eleição: $e');
    }
  }

  /// Cria a rodada pendente do cargo ou, com [roundId], troca os candidatos.
  Future<void> saveRoundCandidates({
    required String electionId,
    required String position,
    required List<Candidate> candidates,
    String? roundId,
    RoundType type = RoundType.normal,
  }) async {
    try {
      final rounds = _election(electionId).collection('rounds');
      if (roundId == null) {
        await rounds.add({
          'position': position,
          'candidates': candidates.map((c) => c.toJson()).toList(),
          'type': type.name,
          'status': 'pending',
          'votedCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await rounds.doc(roundId).update({
          'candidates': candidates.map((c) => c.toJson()).toList(),
        });
      }
    } catch (e) {
      throw AppException(message: 'Erro ao salvar candidatos: $e');
    }
  }

  Future<void> deleteRound(String electionId, String roundId) async {
    try {
      await _election(electionId).collection('rounds').doc(roundId).delete();
    } catch (e) {
      throw AppException(message: 'Erro ao remover votação: $e');
    }
  }

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    try {
      final res = await _functions.httpsCallable(name).call<dynamic>(data);
      final body = res.data;
      return body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    } on FirebaseFunctionsException catch (e) {
      throw AppException(message: e.message ?? 'Erro ao falar com o servidor.');
    } catch (e) {
      throw AppException(message: 'Erro ao falar com o servidor: $e');
    }
  }

  Future<void> setStatus(String electionId, ElectionStatus target) async {
    await _call('electionSetStatus', {'electionId': electionId, 'status': target.name});
  }

  Future<void> reviewVoter(String electionId, String voterId, VoterStatus decision) async {
    await _call('electionReviewVoter', {
      'electionId': electionId,
      'voterId': voterId,
      'decision': decision.name,
    });
  }

  Future<void> openRound(String electionId, String roundId) async {
    await _call('electionOpenRound', {'electionId': electionId, 'roundId': roundId});
  }

  Future<RoundResult> closeRound(String electionId, String roundId) async {
    final data = await _call('electionCloseRound', {'electionId': electionId, 'roundId': roundId});
    return RoundResult.fromJson(data);
  }

  Future<void> applyBoard(String electionId) async {
    await _call('electionApplyBoard', {'electionId': electionId});
  }
}
```

Nota: `watchRounds`/`watchVoters` usam `orderBy('createdAt')`. Rodadas criadas pelo app e eleitores criados pela Function sempre têm `createdAt`; documentos sem o campo não aparecem. Mantenha isso em mente ao semear dados manualmente.

- [ ] **Step 2: Registrar o provider** — em `lib/main.dart`, adicionar o import `import 'src/modules/elections/data/elections_repository.dart';` (junto dos outros imports de módulos) e, no `MultiProvider`, depois do `Provider<SocietiesRepository>.value(...)`:

```dart
        Provider<ElectionsRepository>.value(value: ElectionsRepository()),
```

- [ ] **Step 3: Verificar**

Run: `flutter analyze lib/src/modules/elections lib/main.dart`
Expected: sem erros.

- [ ] **Step 4: Commit**

```bash
/usr/bin/git add lib/main.dart lib/src/modules/elections/data
/usr/bin/git commit -m "feat(elections): repositório do app (Firestore + Functions)"
```

---

### Task 10: Lista de eleições, criação e entrada no menu (só admins)

**Files:**
- Create: `lib/src/modules/elections/presentation/elections_page.dart`
- Create: `lib/src/modules/elections/presentation/widgets/election_form_sheet.dart`
- Modify: `lib/src/modules/auth/presentation/settings_page.dart` (tile "Eleições" para admins)
- Test: `test/modules/elections/election_form_test.dart` (lógica pura do título padrão)

**Interfaces:**
- Consumes: `ElectionsRepository` (Task 9), `SocietiesRepository.fetchAll()` (existente), `SocietyModel`, `BoardPosition`, `showErrorToast`/`showSuccessToast`, `GlassContainer`.
- Produces: `ElectionsPage` (`const ElectionsPage()`), `ElectionFormSheet` (`const ElectionFormSheet()` → fecha com `true` ao criar), função pura `String defaultElectionTitle(String societyName, int year)` em `election_form_sheet.dart`. `ElectionsPage` abre `ElectionDetailPage(electionId: ...)` (criada na Task 11); até lá use o import já apontando para ela.

- [ ] **Step 1: Teste da lógica pura que falha** — `test/modules/elections/election_form_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/elections/presentation/widgets/election_form_sheet.dart';

void main() {
  test('título padrão inclui sociedade e ano', () {
    expect(defaultElectionTitle('UMP', 2026), 'Eleição da diretoria UMP 2026');
    expect(defaultElectionTitle('', 2026), 'Eleição da diretoria 2026');
  });
}
```

Run: `flutter test test/modules/elections/election_form_test.dart`
Expected: FAIL (arquivo não existe).

- [ ] **Step 2: Implementar o formulário** — `lib/src/modules/elections/presentation/widgets/election_form_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/utils/app_toast.dart';
import '../../../societies/data/societies_repository.dart';
import '../../../societies/models/society.dart';
import '../../data/elections_repository.dart';

String defaultElectionTitle(String societyName, int year) {
  final name = societyName.trim();
  return name.isEmpty
      ? 'Eleição da diretoria $year'
      : 'Eleição da diretoria $name $year';
}

class ElectionFormSheet extends StatefulWidget {
  const ElectionFormSheet({super.key});

  @override
  State<ElectionFormSheet> createState() => _ElectionFormSheetState();
}

class _ElectionFormSheetState extends State<ElectionFormSheet> {
  final _titleController = TextEditingController();
  List<SocietyModel> _societies = const [];
  SocietyModel? _society;
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  final Set<BoardPosition> _positions = {...BoardPosition.values};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await context.read<SocietiesRepository>().fetchAll();
      if (!mounted) return;
      setState(() {
        _societies = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorToast(context, 'Não foi possível carregar as sociedades.');
    }
  }

  void _selectSociety(SocietyModel? society) {
    setState(() {
      _society = society;
      _titleController.text =
          defaultElectionTitle(society?.name ?? '', _scheduledAt.year);
    });
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final society = _society;
    final title = _titleController.text.trim();
    if (society == null || title.isEmpty || _positions.isEmpty) {
      showErrorToast(context, 'Escolha a sociedade, o título e ao menos um cargo.');
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<ElectionsRepository>().createElection(
            societyId: society.id,
            societyName: society.name,
            title: title,
            scheduledAt: _scheduledAt,
            positions: [
              for (final p in BoardPosition.values)
                if (_positions.contains(p)) p.name,
            ],
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorToast(context, e.toString());
    }
  }

  String _formatted(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _loading
          ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Nova eleição', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<SocietyModel>(
                    value: _society,
                    decoration: const InputDecoration(labelText: 'Sociedade'),
                    items: [
                      for (final s in _societies)
                        DropdownMenuItem(value: s, child: Text(s.name)),
                    ],
                    onChanged: _selectSociety,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Título'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: Text(_formatted(_scheduledAt)),
                    subtitle: const Text('Data e hora da eleição'),
                    onTap: _pickDateTime,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final p in BoardPosition.values)
                        FilterChip(
                          label: Text(p.label),
                          selected: _positions.contains(p),
                          onSelected: (on) => setState(() {
                            on ? _positions.add(p) : _positions.remove(p);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Criando...' : 'Criar eleição'),
                  ),
                ],
              ),
            ),
    );
  }
}
```

- [ ] **Step 3: Implementar a lista** — `lib/src/modules/elections/presentation/elections_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/glass_container.dart';
import '../data/elections_repository.dart';
import '../models/election.dart';
import 'election_detail_page.dart';
import 'widgets/election_form_sheet.dart';

class ElectionsPage extends StatefulWidget {
  const ElectionsPage({super.key});

  @override
  State<ElectionsPage> createState() => _ElectionsPageState();
}

class _ElectionsPageState extends State<ElectionsPage> {
  late final Stream<List<Election>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = context.read<ElectionsRepository>().watchElections();
  }

  String _statusLabel(ElectionStatus s) => switch (s) {
        ElectionStatus.draft => 'Rascunho',
        ElectionStatus.open => 'Em andamento',
        ElectionStatus.closed => 'Encerrada',
      };

  String _date(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1220), Color(0xFF05070D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: Colors.white,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Eleições',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<List<Election>>(
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Erro: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final elections = snapshot.data!;
                    if (elections.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhuma eleição ainda.\nToque no botão + para criar.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                      itemCount: elections.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, i) {
                        final e = elections[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ElectionDetailPage(electionId: e.id),
                            ),
                          ),
                          child: GlassContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${e.societyName} · ${_date(e.scheduledAt)}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                                ),
                                const SizedBox(height: 8),
                                Chip(label: Text(_statusLabel(e.status))),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const ElectionFormSheet(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 4: Entrada no menu (só admins)** — em `lib/src/modules/auth/presentation/settings_page.dart`: adicionar o import `import '../../elections/presentation/elections_page.dart';` e, dentro do bloco `if (user?.isAdmin == true) ...[` que contém "Responsáveis semanais" (depois do `ListTile` cujo `onTap` chama `_navigateToWeeklyAssignments(context)`, antes do `],` que fecha o bloco), acrescentar:

```dart
                            const Divider(height: 1, color: Colors.white12),
                            ListTile(
                              leading: const Icon(
                                Icons.how_to_vote,
                                color: Colors.white70,
                              ),
                              title: const Text(
                                'Eleições',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                'Eleição de diretoria das sociedades',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white60,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Colors.white54,
                              ),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ElectionsPage(),
                                ),
                              ),
                            ),
```

- [ ] **Step 5: Verificar** (o detalhe da Task 11 ainda não existe; crie antes um stub mínimo para compilar)

Crie temporariamente `lib/src/modules/elections/presentation/election_detail_page.dart` com `class ElectionDetailPage extends StatelessWidget { const ElectionDetailPage({super.key, required this.electionId}); final String electionId; @override Widget build(BuildContext context) => const Scaffold(); }` — a Task 11 o substitui por inteiro.

Run: `flutter test test/modules/elections && flutter analyze lib/src/modules/elections lib/src/modules/auth/presentation/settings_page.dart`
Expected: testes passam; analyze sem erros novos.

- [ ] **Step 6: Commit**

```bash
/usr/bin/git add lib test
/usr/bin/git commit -m "feat(elections): lista, criação e menu de eleições (admins)"
```

---

### Task 11: Tela da eleição — cabeçalho, Presentes e Cargos

**Files:**
- Create (substitui o stub): `lib/src/modules/elections/presentation/election_detail_page.dart`
- Create: `lib/src/modules/elections/presentation/widgets/election_voters_tab.dart`
- Create: `lib/src/modules/elections/presentation/widgets/election_rounds_tab.dart`
- Create: `lib/src/modules/elections/presentation/widgets/candidate_picker_sheet.dart`

**Interfaces:**
- Consumes: `ElectionsRepository`, modelos e `election_logic.dart` (Task 8), `PeopleRepository.fetchAll({UserModel? currentUser})`, `SocietiesRepository.fetchById(id)`, `AppState.currentUser`, `showErrorToast`/`showSuccessToast`.
- Produces:
  - `ElectionDetailPage({required String electionId})` (abas: Presentes, Cargos, Ata — a aba Ata vem da Task 12; use `ElectionMinutesTab` já referenciada).
  - `ElectionVotersTab({required Election election})`
  - `ElectionRoundsTab({required Election election})`
  - `CandidatePickerSheet({required List<Candidate> options, List<Candidate> initial = const []})` → fecha com `List<Candidate>?`.

- [ ] **Step 1: Seletor de candidatos** — `candidate_picker_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../../models/election.dart';

class CandidatePickerSheet extends StatefulWidget {
  const CandidatePickerSheet({
    super.key,
    required this.options,
    this.initial = const [],
  });

  final List<Candidate> options;
  final List<Candidate> initial;

  @override
  State<CandidatePickerSheet> createState() => _CandidatePickerSheetState();
}

class _CandidatePickerSheetState extends State<CandidatePickerSheet> {
  late final Set<String> _selected = {for (final c in widget.initial) c.id};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Candidatos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Flexible(
            child: widget.options.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nenhum membro disponível para este cargo.'),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in widget.options)
                        CheckboxListTile(
                          value: _selected.contains(c.id),
                          title: Text(c.name),
                          onChanged: (on) => setState(() {
                            on == true ? _selected.add(c.id) : _selected.remove(c.id);
                          }),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.of(context).pop([
                          for (final c in widget.options)
                            if (_selected.contains(c.id)) c,
                        ]),
                child: const Text('Confirmar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Aba Presentes** — `election_voters_tab.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/utils/app_toast.dart';
import '../../data/elections_repository.dart';
import '../../models/election.dart';
import '../../models/election_logic.dart';

class ElectionVotersTab extends StatefulWidget {
  const ElectionVotersTab({super.key, required this.election});

  final Election election;

  @override
  State<ElectionVotersTab> createState() => _ElectionVotersTabState();
}

class _ElectionVotersTabState extends State<ElectionVotersTab> {
  late final Stream<List<ElectionVoter>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = context.read<ElectionsRepository>().watchVoters(widget.election.id);
  }

  Future<void> _review(ElectionVoter voter, VoterStatus decision) async {
    try {
      await context
          .read<ElectionsRepository>()
          .reviewVoter(widget.election.id, voter.id, decision);
    } catch (e) {
      if (!mounted) return;
      showErrorToast(context, e.toString());
    }
  }

  Widget _tile(ElectionVoter v, Set<String> duplicates, {required bool pending}) {
    return ListTile(
      title: Text(v.name),
      subtitle: Text([
        v.kind == VoterKind.member ? 'Membro' : 'Convidado',
        if (v.email.isNotEmpty) v.email,
      ].join(' · ')),
      leading: duplicates.contains(v.id)
          ? const Tooltip(
              message: 'Mesmo nome ou e-mail de outra pessoa na lista',
              child: Icon(Icons.warning_amber, color: Colors.amber),
            )
          : null,
      trailing: pending
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Recusar',
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  onPressed: () => _review(v, VoterStatus.rejected),
                ),
                IconButton(
                  tooltip: 'Aprovar',
                  icon: const Icon(Icons.check, color: Colors.greenAccent),
                  onPressed: () => _review(v, VoterStatus.approved),
                ),
              ],
            )
          : v.status == VoterStatus.rejected
              ? TextButton(
                  onPressed: () => _review(v, VoterStatus.approved),
                  child: const Text('Aprovar'),
                )
              : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ElectionVoter>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final voters = snapshot.data!;
        final duplicates = duplicateVoterIds(voters);
        final pending = voters.where((v) => v.status == VoterStatus.pending).toList();
        final approved = voters.where((v) => v.status == VoterStatus.approved).toList();
        final rejected = voters.where((v) => v.status == VoterStatus.rejected).toList();
        if (voters.isEmpty) {
          return const Center(
            child: Text(
              'Ninguém entrou ainda.\nCompartilhe o link para o pessoal votar.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            if (pending.isNotEmpty) ...[
              _Header('Aguardando aprovação (${pending.length})'),
              for (final v in pending) _tile(v, duplicates, pending: true),
            ],
            _Header('Liberados (${approved.length})'),
            for (final v in approved) _tile(v, duplicates, pending: false),
            if (rejected.isNotEmpty) ...[
              _Header('Recusados (${rejected.length})'),
              for (final v in rejected) _tile(v, duplicates, pending: false),
            ],
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white70),
        ),
      );
}
```

- [ ] **Step 3: Aba Cargos** — `election_rounds_tab.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/state/app_state.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../people/data/people_repository.dart';
import '../../../societies/data/societies_repository.dart';
import '../../data/elections_repository.dart';
import '../../models/election.dart';
import '../../models/election_logic.dart';
import '../../models/minutes_text.dart' show positionLabel;
import 'candidate_picker_sheet.dart';

class ElectionRoundsTab extends StatefulWidget {
  const ElectionRoundsTab({super.key, required this.election});

  final Election election;

  @override
  State<ElectionRoundsTab> createState() => _ElectionRoundsTabState();
}

class _ElectionRoundsTabState extends State<ElectionRoundsTab> {
  late final Stream<List<ElectionRound>> _rounds;
  late final Stream<List<ElectionVoter>> _voters;
  List<Candidate>? _members;

  ElectionsRepository get _repo => context.read<ElectionsRepository>();

  @override
  void initState() {
    super.initState();
    _rounds = _repo.watchRounds(widget.election.id);
    _voters = _repo.watchVoters(widget.election.id);
  }

  Future<List<Candidate>> _loadMembers() async {
    final cached = _members;
    if (cached != null) return cached;
    final society = await context
        .read<SocietiesRepository>()
        .fetchById(widget.election.societyId);
    if (!mounted) return const [];
    final people = await context
        .read<PeopleRepository>()
        .fetchAll(currentUser: context.read<AppState>().currentUser);
    final members = [
      for (final u in people)
        if (society.membersIds.contains(u.id)) Candidate(id: u.id, name: u.name),
    ]..sort((a, b) => a.name.compareTo(b.name));
    _members = members;
    return members;
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      showErrorToast(context, e.toString());
    }
  }

  Future<void> _editCandidates(
    String position,
    List<ElectionRound> rounds, {
    ElectionRound? round,
  }) {
    return _guard(() async {
      final members = await _loadMembers();
      if (!mounted) return;
      final options = candidateOptions(members: members, rounds: rounds, position: position);
      final picked = await showModalBottomSheet<List<Candidate>>(
        context: context,
        isScrollControlled: true,
        builder: (_) => CandidatePickerSheet(
          options: options,
          initial: round?.candidates ?? const [],
        ),
      );
      if (picked == null || !mounted) return;
      await _repo.saveRoundCandidates(
        electionId: widget.election.id,
        position: position,
        candidates: picked,
        roundId: round?.id,
      );
    });
  }

  Future<void> _createRunoff(String position, RoundResult result, ElectionRound from) {
    return _guard(() async {
      final tied = [for (final c in from.candidates) if (result.tie.contains(c.id)) c];
      await _repo.saveRoundCandidates(
        electionId: widget.election.id,
        position: position,
        candidates: tied,
        type: RoundType.runoff,
      );
    });
  }

  Future<void> _closeRound(ElectionRound round) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar votação?'),
        content: Text('Nenhum voto novo será aceito para ${positionLabel(round.position)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Encerrar')),
        ],
      ),
    );
    if (ok != true) return;
    await _guard(() async {
      await _repo.closeRound(widget.election.id, round.id);
    });
  }

  Widget _roundCard(
    String position,
    ElectionRound round,
    List<ElectionRound> all,
    int approved,
  ) {
    final election = widget.election;
    final canOperate = election.status == ElectionStatus.open;
    String nameOf(String id) =>
        round.candidates.where((c) => c.id == id).map((c) => c.name).firstOrNull ?? id;

    switch (round.status) {
      case RoundStatus.pending:
        return Card(
          child: ListTile(
            title: Text(round.type == RoundType.runoff ? 'Desempate' : 'Candidatos'),
            subtitle: Text(round.candidates.map((c) => c.name).join(', ')),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: 'Editar candidatos',
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editCandidates(position, all, round: round),
                ),
                IconButton(
                  tooltip: 'Remover',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _guard(() => _repo.deleteRound(election.id, round.id)),
                ),
                FilledButton(
                  onPressed: canOperate
                      ? () => _guard(() => _repo.openRound(election.id, round.id))
                      : null,
                  child: const Text('Abrir votação'),
                ),
              ],
            ),
          ),
        );
      case RoundStatus.open:
        return Card(
          child: ListTile(
            title: const Text('Votação em andamento'),
            subtitle: Text(
              '${round.votedCount} de $approved votaram · '
              '${round.candidates.map((c) => c.name).join(', ')}',
            ),
            trailing: FilledButton(
              onPressed: () => _closeRound(round),
              child: const Text('Encerrar'),
            ),
          ),
        );
      case RoundStatus.closed:
        final result = round.result;
        final String text;
        if (result == null) {
          text = 'Encerrada';
        } else if (result.winnerId != null) {
          text = 'Eleito(a): ${nameOf(result.winnerId!)}';
        } else if (result.tie.isNotEmpty) {
          text = 'Empate: ${result.tie.map(nameOf).join(', ')}';
        } else {
          text = 'Ninguém foi eleito(a)';
        }
        return Card(
          child: ListTile(
            title: Text(text),
            subtitle: result == null
                ? null
                : Text(
                    '${result.total} votos${result.divergence ? ' · ATENÇÃO: contagem divergente' : ''}',
                  ),
            trailing: result != null && result.tie.isNotEmpty
                ? OutlinedButton(
                    onPressed: () => _createRunoff(position, result, round),
                    child: const Text('Criar desempate'),
                  )
                : null,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ElectionRound>>(
      stream: _rounds,
      builder: (context, roundsSnap) {
        return StreamBuilder<List<ElectionVoter>>(
          stream: _voters,
          builder: (context, votersSnap) {
            if (roundsSnap.hasError) return Center(child: Text('Erro: ${roundsSnap.error}'));
            if (!roundsSnap.hasData) return const Center(child: CircularProgressIndicator());
            final rounds = roundsSnap.data!;
            final approved = (votersSnap.data ?? const <ElectionVoter>[])
                .where((v) => v.status == VoterStatus.approved)
                .length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                for (final position in widget.election.positions) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: Text(
                      positionLabel(position),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final r in rounds.where((r) => r.position == position))
                    _roundCard(position, r, rounds, approved),
                  if (!rounds.any((r) =>
                      r.position == position &&
                      (r.status == RoundStatus.pending || r.status == RoundStatus.open)))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.person_add_alt),
                        label: Text(
                          rounds.any((r) => r.position == position)
                              ? 'Nova votação para este cargo'
                              : 'Definir candidatos',
                        ),
                        onPressed: () => _editCandidates(position, rounds),
                      ),
                    ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
```

- [ ] **Step 4: Tela da eleição** — substituir o stub `election_detail_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../shared/utils/app_toast.dart';
import '../data/elections_repository.dart';
import '../models/election.dart';
import '../models/election_logic.dart';
import 'widgets/election_minutes_tab.dart';
import 'widgets/election_rounds_tab.dart';
import 'widgets/election_voters_tab.dart';

class ElectionDetailPage extends StatefulWidget {
  const ElectionDetailPage({super.key, required this.electionId});

  final String electionId;

  @override
  State<ElectionDetailPage> createState() => _ElectionDetailPageState();
}

class _ElectionDetailPageState extends State<ElectionDetailPage> {
  late final Stream<Election?> _stream;

  ElectionsRepository get _repo => context.read<ElectionsRepository>();

  @override
  void initState() {
    super.initState();
    _stream = _repo.watchElection(widget.electionId);
  }

  Future<void> _confirm(
    String title,
    String message,
    Future<void> Function() action, {
    String? success,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await action();
      if (mounted && success != null) showSuccessToast(context, success);
    } catch (e) {
      if (mounted) showErrorToast(context, e.toString());
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: buildVoteLink(widget.electionId)));
    if (mounted) showSuccessToast(context, 'Link copiado. Cole no computador para abrir o QR.');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Election?>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(appBar: AppBar(), body: Center(child: Text('Erro: ${snapshot.error}')));
        }
        if (!snapshot.hasData) {
          return snapshot.connectionState == ConnectionState.waiting
              ? Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()))
              : Scaffold(appBar: AppBar(), body: const Center(child: Text('Eleição não encontrada.')));
        }
        final election = snapshot.data!;
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(election.title),
              actions: [
                IconButton(
                  tooltip: 'Copiar link do QR',
                  icon: const Icon(Icons.link),
                  onPressed: _copyLink,
                ),
              ],
              bottom: const TabBar(
                tabs: [Tab(text: 'Presentes'), Tab(text: 'Cargos'), Tab(text: 'Ata')],
              ),
            ),
            body: Column(
              children: [
                _ActionBar(
                  election: election,
                  onOpen: () => _confirm(
                    'Abrir eleição?',
                    'As pessoas poderão entrar pelo link e aguardar a votação.',
                    () => _repo.setStatus(election.id, ElectionStatus.open),
                  ),
                  onClose: () => _confirm(
                    'Encerrar eleição?',
                    'Ninguém mais poderá entrar ou votar.',
                    () => _repo.setStatus(election.id, ElectionStatus.closed),
                  ),
                  onApply: () => _confirm(
                    'Aplicar diretoria?',
                    'Os eleitos substituem os cargos correspondentes na diretoria da sociedade.',
                    () => _repo.applyBoard(election.id),
                    success: 'Diretoria atualizada.',
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ElectionVotersTab(election: election),
                      ElectionRoundsTab(election: election),
                      ElectionMinutesTab(election: election),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.election,
    required this.onOpen,
    required this.onClose,
    required this.onApply,
  });

  final Election election;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final status = switch (election.status) {
      ElectionStatus.draft => 'Rascunho',
      ElectionStatus.open => 'Em andamento',
      ElectionStatus.closed => 'Encerrada',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(label: Text(status)),
          if (election.status == ElectionStatus.draft)
            FilledButton(onPressed: onOpen, child: const Text('Abrir eleição')),
          if (election.status == ElectionStatus.open)
            OutlinedButton(onPressed: onClose, child: const Text('Encerrar eleição')),
          if (election.status != ElectionStatus.draft)
            OutlinedButton(
              onPressed: onApply,
              child: Text(election.boardAppliedAt == null ? 'Aplicar diretoria' : 'Reaplicar diretoria'),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Verificar** — a aba Ata é criada na Task 12; crie antes um stub `election_minutes_tab.dart` (`class ElectionMinutesTab extends StatelessWidget { const ElectionMinutesTab({super.key, required this.election}); final Election election; @override Widget build(BuildContext context) => const SizedBox(); }`) apenas para compilar.

Run: `flutter analyze lib/src/modules/elections && flutter test test/modules/elections`
Expected: sem erros; testes passam.

- [ ] **Step 6: Commit**

```bash
/usr/bin/git add lib/src/modules/elections
/usr/bin/git commit -m "feat(elections): tela da eleição com presentes e cargos"
```

---

### Task 12: Aba Ata

**Files:**
- Create (substitui o stub): `lib/src/modules/elections/presentation/widgets/election_minutes_tab.dart`

**Interfaces:**
- Consumes: `buildMinutesText` (Task 8), `ElectionsRepository.watchVoters/watchRounds/watchEvents` (Task 9).
- Produces: `ElectionMinutesTab({required Election election})` — mostra o texto da ata e um botão para copiar.

- [ ] **Step 1: Implementar** — `election_minutes_tab.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../shared/utils/app_toast.dart';
import '../../data/elections_repository.dart';
import '../../models/election.dart';
import '../../models/minutes_text.dart';

class ElectionMinutesTab extends StatefulWidget {
  const ElectionMinutesTab({super.key, required this.election});

  final Election election;

  @override
  State<ElectionMinutesTab> createState() => _ElectionMinutesTabState();
}

class _ElectionMinutesTabState extends State<ElectionMinutesTab> {
  late final Stream<List<ElectionVoter>> _voters;
  late final Stream<List<ElectionRound>> _rounds;
  late final Stream<List<ElectionEvent>> _events;

  @override
  void initState() {
    super.initState();
    final repo = context.read<ElectionsRepository>();
    _voters = repo.watchVoters(widget.election.id);
    _rounds = repo.watchRounds(widget.election.id);
    _events = repo.watchEvents(widget.election.id);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ElectionVoter>>(
      stream: _voters,
      builder: (context, votersSnap) => StreamBuilder<List<ElectionRound>>(
        stream: _rounds,
        builder: (context, roundsSnap) => StreamBuilder<List<ElectionEvent>>(
          stream: _events,
          builder: (context, eventsSnap) {
            final error = votersSnap.error ?? roundsSnap.error ?? eventsSnap.error;
            if (error != null) return Center(child: Text('Erro: $error'));
            if (!votersSnap.hasData || !roundsSnap.hasData || !eventsSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final text = buildMinutesText(
              election: widget.election,
              voters: votersSnap.data!,
              rounds: roundsSnap.data!,
              events: eventsSnap.data!,
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                SelectableText(text),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar ata'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) showSuccessToast(context, 'Ata copiada.');
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verificar**

Run: `flutter analyze && flutter test`
Expected: analyze sem erros novos em `lib/src/modules/elections`; toda a suíte Flutter passa.

- [ ] **Step 3: Commit**

```bash
/usr/bin/git add lib/src/modules/elections
/usr/bin/git commit -m "feat(elections): aba de ata na tela da eleição"
```

---

## Parte E — Fechamento

### Task 13: Verificação ponta a ponta, spec e entrega

**Files:**
- Modify: `docs/superpowers/specs/2026-10-15-society-elections-design.md` (alinhar com decisões do plano)

- [ ] **Step 1: Alinhar o spec com o que o plano decidiu** — editar o spec:
  - §4, em `elections/{id}`: acrescentar `societyName` e `boardAppliedAt`; em `rounds/{rid}`: acrescentar `createdAt`, `openedAt`, `closedAt`.
  - §6 (regras): trocar "Eleição e rodadas: leitura para qualquer usuário autenticado (inclusive anônimo)" por "O `get` do documento da eleição é público (a página de voto o lê antes do login; ele não guarda nada secreto) e o `list` exige login; rodadas exigem login".
  - §6: acrescentar que `rounds` só aceita criação com `status = pending` e edição de `candidates`/`position`/`type` enquanto `pending`.

- [ ] **Step 2: Rodar tudo**

Run, um por vez:
- `cd functions && npm run lint && npm run build && npm test && npm run test:integration`
- `cd rules-tests && npm test`
- `cd web-portal && npx vitest run && npm run typecheck && npm run lint && npm run build`
- `flutter analyze && flutter test`

Expected: tudo verde. Reportar qualquer falha com a saída; não declarar pronto sem isso.

- [ ] **Step 3: Checklist de rollout manual (o executor NÃO faz sozinho; entrega ao usuário)**
  1. Console do Firebase → Authentication → Sign-in method → **ativar "Anônimo"**.
  2. `firebase deploy --only functions:electionSetStatus,functions:electionCheckIn,functions:electionReviewVoter,functions:electionOpenRound,functions:electionCastVote,functions:electionCloseRound,functions:electionApplyBoard` (usar `--only` para não tocar nas outras Functions).
  3. `firebase deploy --only firestore:rules` (o bloco novo é aditivo; confirmar com o usuário antes, dado o histórico de problemas com regras).
  4. Merge na `master` publica o portal na Vercel (`ipe-ensino.vercel.app`); previews da Vercel só validam o build, o login só funciona no domínio autorizado.
  5. Publicar o app com `cloud_functions` (nova dependência nativa → exige novo build das lojas).
  6. Teste real: criar eleição de teste numa sociedade, abrir o link no celular (membro logado e convidado anônimo), aprovar o convidado no app, votar, encerrar, aplicar diretoria, conferir a ata. Fazer o primeiro teste com uma sociedade de teste ou revertendo `board` depois.
  7. Combinar com o outro agente (`teaching-portal`) o merge de `firestore.rules`, `functions/src/index.ts` e `firebase.json`, se ele ainda tiver mudanças pendentes nesses arquivos.

- [ ] **Step 4: Commit e relatório**

```bash
/usr/bin/git add docs/superpowers/specs/2026-10-15-society-elections-design.md
/usr/bin/git commit -m "docs(elections): alinhar spec com o plano de implementação"
```

Relatar ao usuário: o que passou (com os comandos acima), o que ficou como passo manual e os riscos aceitos do spec §6.
