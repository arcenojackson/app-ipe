# Eleição por escrutínios (condução na web, acesso por diretoria) — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refazer a feature de eleição para seguir o rito da UMP Nacional (até 3 escrutínios por cargo), conduzida pelos diretores da sociedade numa tela web, mantendo o voto secreto e a página de voto.

**Architecture:** Toda gravação passa por Cloud Function (Admin SDK); o cliente só lê. As Functions conferem `directorIds` da eleição. Uma função pura decide cada escrutínio. A web ganha a tela de condução (com QR) e a tela de voto passa a mostrar as opções do escrutínio aberto. O app Flutter só cria a eleição, lista as das sociedades do diretor, abre a condução na web e mostra a ata.

**Tech Stack:** Firebase Functions v1 (TypeScript, vitest, emulador do Firestore), `@firebase/rules-unit-testing`, Next.js 16 / React 19 / vitest no `web-portal/`, Flutter + Provider + `cloud_firestore` + `cloud_functions`.

**Spec:** `docs/superpowers/specs/2026-10-15-society-elections-design.md` (revisado em 2026-10-25). Este plano **substitui** `docs/superpowers/plans/2026-10-15-society-elections.md`, cujas tarefas já foram executadas e agora são refeitas.

## Notas de ambiente

- Use `/usr/bin/git ...` (um hook reescreve `git` e a guarda da worktree recusa). Comandos de teste com `rtk proxy ...` mostram a saída completa. Evite `cd` composto e heredocs em comandos com git.
- `functions/`, `rules-tests/` e `web-portal/` já têm `node_modules` nesta worktree. A worktree não tem `lib/firebase_options.dart` nem `app_secrets.dart`: testes Flutter só podem importar arquivos de `models/` (sem Firebase). Isso vale também para qualquer arquivo novo de lógica.
- O `next build` local precisa das variáveis `NEXT_PUBLIC_FIREBASE_*` (use valores de teste).
- Mensagens de commit terminam com `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Nada foi publicado: não há migração de dados nem compatibilidade com eleições antigas.

## Contratos compartilhados (valem para todas as tarefas)

**Cargos** (`positions`, nesta ordem canônica): `presidente`, `vice`, `secretario` (1º Secretário), `secretario2` (2º Secretário), `tesoureiro`. Obrigatórios: `presidente` e `vice`. Chave em `societies.board`: `presidente`, `vice`, `secretario(a)`, `2º secretario(a)`, `tesoureiro(a)`.

**Estados do cargo** (`CargoStage`): `idle` | `scrutiny1` | `confirming` | `scrutiny2` | `awaiting3` | `scrutiny3` | `tiebreak` | `decided`.

**Documentos:**
- `elections/{id}`: `societyId`, `societyName`, `title`, `scheduledAt` (Timestamp), `status` (`draft`|`open`|`closed`), `positions[]`, `directorIds[]`, `createdBy`, `createdAt`, `openedAt`, `closedAt`, `boardAppliedAt`.
- `elections/{id}/cargos/{position}`: `stage`, `cycle` (começa em 1), `candidates[]` (`{id, name, votes}`), `tiedIds[]`, `winnerId` (string ou `null`).
- `elections/{id}/rounds/{rid}`: `position`, `cycle`, `number` (1 a 3), `status` (`open`|`closed`), `options[]` (`{id, name}`), `openedAt`, `closedAt`, `votedCount`, `result` (só depois de fechado): `{counts, blank, total, presentCount, threshold, winnerId, tie, divergence}`.
- `voters/{uid}`, `rounds/{rid}/voted/{uid}`, `rounds/{rid}/ballots/{randomId}` (`{choice}` apenas, sem identidade e sem timestamp), `events/{autoId}`: como já existem.

**Callables** (região `us-central1`): `electionCreate` `{societyId, title, scheduledAtMs, positions}` → `{electionId}`; `electionSetStatus` `{electionId, status}`; `electionCheckIn` `{electionId, name?}`; `electionReviewVoter` `{electionId, voterId, decision}`; `electionStartScrutiny` `{electionId, position}` → `{roundId, number}`; `electionCastVote` `{electionId, roundId, choice}` → `{receipt}`; `electionCloseScrutiny` `{electionId, position}` → `{stage, result}`; `electionRemoveCandidate` `{electionId, position, candidateId}`; `electionRestartCargo` `{electionId, position}`; `electionPickOldest` `{electionId, position, candidateId}`; `electionApplyBoard` `{electionId}` → `{winners, missingRequired}`. Gatilho `electionVoteRecorded` (contador ao vivo) continua.

## Global Constraints

- Só os diretores da própria sociedade (qualquer cargo em `board`) criam e conduzem; diretor de outra sociedade e admin global que não é diretor são recusados. Sociedade sem diretoria não tem eleição. Sessão anônima nunca é aceita.
- Limiar de vitória: ⌊presentes ÷ 2⌋ + 1, onde presentes = eleitores com `status: approved`, contados quando o escrutínio é encerrado. Voto em branco nunca elege.
- 1º escrutínio não elege ninguém; vence no 2º quem atinge o limiar; no 3º vence o mais votado e o empate no topo vai ao diretor (`tiebreak`).
- Remover candidato vale só para aquele cargo; a pessoa continua podendo votar. Quem já foi eleito (cargo `decided`) não é opção no 1º escrutínio dos outros cargos.
- Voto secreto: `ballots` sem identidade e sem timestamp, nenhum cliente lê `ballots`; o voto não escreve no documento da rodada (o contador é do gatilho); o encerramento grava o `votedCount` exato.
- O cliente não escreve nada em `elections/**`. Regras do Firestore aditivas; `users` e `societies` não são alteradas.
- Aspas duplas, indentação de 2 e estilo Google no lint das Functions; comentários em `functions/src/` usam `//`.
- Fora da v1: data de nascimento, cronômetro, WhatsApp, voto assistido, reabrir cargo decidido, ata em PDF, QR rotativo, App Check.

## Review Focus

1. Quem foi removido como candidato (ou nunca foi) continua votando nos escrutínios seguintes do mesmo cargo (Task 5).
2. Eleitor liberado depois do início do escrutínio, mas antes do encerramento, pode votar e entra no total de presentes (Task 4).
3. Diretor de **outra** sociedade chamando qualquer ação, e admin global que não é diretor, são recusados (Tasks 3 e 5).
4. Todos declinam, ninguém recebe voto no 1º, ou só brancos no 3º: o cargo não trava, volta a `idle` com `cycle` + 1 e o novo 1º escrutínio parte de opções frescas (Tasks 4 e 5).
5. Voto concorrente com o encerramento: o voto entra na contagem ou é recusado, nunca sobra `voted` sem `ballot` (Task 4).
6. Presentes ímpares e pares: limiar correto (9 → 5, 10 → 6) e candidato único abaixo do limiar vai ao 3º (Task 1).

---

### Task 1: Decisão pura do escrutínio

**Files:**
- Create: `functions/src/elections/scrutiny.ts`
- Modify: `functions/src/elections/types.ts` (acrescentar `CargoStage`, `CandidateVotes`, `ScrutinyOutcome`; manter o que existe até a Task 4)
- Test: `functions/test/electionsScrutiny.test.ts`

**Interfaces:**
- Produces:
  - `requiredVotes(presentCount: number): number` → `Math.floor(presentCount / 2) + 1`.
  - `countBallots(options: Candidate[], choices: string[], votedCount: number): {counts: Record<string, number>; blank: number; total: number; divergence: boolean}` (usa `hasOwnProperty`; escolha fora das opções e de `blank` marca `divergence`; `total` = quantidade de ballots).
  - `decideScrutiny(input: {number: 1 | 2 | 3; options: Candidate[]; counts: Record<string, number>; presentCount: number}): ScrutinyOutcome`.
  - `ScrutinyResult` = `{counts: Record<string, number>; blank: number; total: number; presentCount: number; threshold: number; winnerId: string | null; tie: string[]; divergence: boolean}` (o `result` gravado na rodada; usado pela Task 4).
  - `ScrutinyOutcome` = `{stage: "confirming"; candidates: CandidateVotes[]}` | `{stage: "decided"; winnerId: string}` | `{stage: "awaiting3"}` | `{stage: "tiebreak"; tiedIds: string[]}` | `{stage: "idle"}` (reinício), com `CandidateVotes = {id: string; name: string; votes: number}`.

- [ ] **Step 1: Escrever os testes que falham** em `electionsScrutiny.test.ts`: `requiredVotes`: 10 → 6, 9 → 5, 1 → 1, 0 → 1. `countBallots`: conta por opção e separa `blank`; `"constructor"` como escolha marca `divergence`; `total !== votedCount` marca `divergence`. `decideScrutiny` no 1º: devolve `confirming` com só quem teve ≥ 1 voto, ordenado por votos (desc) e depois por nome; ninguém com voto → `confirming` com lista vazia. No 2º: candidato com votos ≥ limiar → `decided` (10 presentes, 6 votos vence; 5 não); dois candidatos, só um atinge → ele vence; nenhum atinge → `awaiting3`; candidato único abaixo do limiar → `awaiting3`. No 3º: único mais votado → `decided` mesmo sem maioria; empate no topo → `tiebreak` com os ids empatados; todos com 0 votos (só brancos) → `idle`; candidato único com ≥ 1 voto → `decided`.
- [ ] **Step 2: Rodar e ver falhar:** `rtk proxy npm --prefix functions test` → FAIL (módulo `scrutiny` inexistente).
- [ ] **Step 3: Implementar** as três funções e os tipos em `scrutiny.ts`/`types.ts`, puras (sem Firebase).
- [ ] **Step 4: Rodar e ver passar:** `rtk proxy npm --prefix functions test` → PASS (toda a suíte).
- [ ] **Step 5: Commit:** `feat(elections): decisão pura do escrutínio`.

---

### Task 2: Cargos (Functions e app)

**Files:**
- Create: `functions/src/elections/positions.ts`
- Modify: `functions/src/elections/board.ts` (chave do `secretario2`); `lib/src/modules/societies/models/society.dart` (`BoardPosition.secretario2`)
- Test: `functions/test/electionsPositions.test.ts`, `functions/test/electionsBoard.test.ts`, `test/modules/societies/board_position_test.dart`

**Interfaces:**
- Produces: `POSITIONS: readonly string[]` (ordem canônica), `REQUIRED_POSITIONS = ["presidente", "vice"]`, `normalizePositions(input: unknown): string[]` (ordena na ordem canônica, remove repetidos, exige `presidente` e `vice`, recusa chave desconhecida; erro via `fail("invalid-argument", ...)` de `common.ts`). `boardKey("secretario2")` → `"2º secretario(a)"`; as outras chaves não mudam.
- Dart: `BoardPosition.secretario2` com label `'2º Secretario(a)'` (a chave gravada continua `label.toLowerCase()`).

- [ ] **Step 1: Escrever os testes que falham.** `normalizePositions`: aceita as 5; ordena `["tesoureiro","vice","presidente"]` → `["presidente","vice","tesoureiro"]`; sem `vice` → `invalid-argument`; `"pastor"` → `invalid-argument`; repetidos viram um; não-array → `invalid-argument`. `boardKey`: o novo mapeamento. `applyWinners` com `secretario2` grava `"2º secretario(a)"` e não apaga `"secretario(a)"`. Dart: `BoardPosition.values` tem 5 itens; `BoardPosition.secretario2.label.toLowerCase()` é `'2º secretario(a)'`; `fromString('secretario2')` resolve.
- [ ] **Step 2: Rodar e ver falhar:** `rtk proxy npm --prefix functions test` e `rtk proxy flutter test test/modules/societies/board_position_test.dart`.
- [ ] **Step 3: Implementar** `positions.ts`, a chave nova em `board.ts` e o valor do enum (a tela de diretoria das Sociedades já itera `BoardPosition.values`; confira que o 2º cargo aparece lá sem outras mudanças).
- [ ] **Step 4: Rodar e ver passar** os mesmos comandos, mais `rtk proxy flutter analyze lib/src/modules/societies`.
- [ ] **Step 5: Commit:** `feat(elections): cargos com 2º Secretário`.

---

### Task 3: Acesso por diretoria e criação da eleição

**Files:**
- Create: `functions/src/elections/directors.ts`
- Modify: `functions/src/elections/lifecycle.ts` (`createElection`, `setElectionStatus` por diretor), `functions/src/elections/voters.ts` (`reviewVoter` por diretor), `functions/src/elections/index.ts` (callable `electionCreate`, wrapper `needDirectorAuth` que recusa anônimo), `functions/integration/helpers.ts`
- Test: `functions/test/electionsDirectors.test.ts`, `functions/integration/lifecycle.itest.ts`, `functions/integration/voters.itest.ts`

**Interfaces:**
- Produces: `directorIdsOf(board: unknown): string[]` (mapa de cargo → lista ou string; lista antiga de ids; deduplicado; qualquer outro formato → `[]`); `assertElectionDirector(db, uid: string, electionId: string): Promise<ElectionDoc>` (carrega a eleição e exige `uid` em `directorIds`, senão `permission-denied`); `createElection(db, uid, data): Promise<{electionId: string}>`.
- `createElection`: confere a diretoria **atual** da sociedade (`directorIdsOf(society.board)` contém `uid`; vazia → `failed-precondition`), valida `title` não vazio, `scheduledAtMs` numérico e `normalizePositions`; cria a eleição `draft` com `directorIds` (snapshot), `societyName` e os documentos `cargos/{position}` com `stage: "idle"`, `cycle: 1`, `candidates: []`, `tiedIds: []`, `winnerId: null`; registra evento `election_created`.
- Em `helpers.ts`: constantes `DIRECTOR = "d1"`, `DIRECTOR2 = "d2"`, `OTHER_DIRECTOR = "od1"`; a sociedade `s1` passa a ter `board: {presidente: [DIRECTOR], vice: [DIRECTOR2]}`, existe a sociedade `s2` com `board: {presidente: [OTHER_DIRECTOR]}` e a eleição `e1` tem `directorIds: [DIRECTOR, DIRECTOR2]`. `ADMIN` continua `is_admin` mas fora da diretoria.

- [ ] **Step 1: Escrever os testes que falham.** Unitário `directorIdsOf`: mapa com listas; valor string; lista antiga; duplicados; `undefined`/`null`/número → `[]`. Integração `createElection`: diretor de `s1` cria e o resultado tem `directorIds` com os dois diretores, `societyName`, status `draft` e cinco `cargos` `idle`; diretor de `s2` → `permission-denied`; `ADMIN` (admin, não diretor) → `permission-denied`; sociedade com `board` vazio → `failed-precondition`; sem `vice` nas posições → `invalid-argument`; título vazio → `invalid-argument`. `setElectionStatus` e `reviewVoter`: diretor passa, `OTHER_DIRECTOR` e `ADMIN` → `permission-denied` (reaproveite os casos de transição que já existem).
- [ ] **Step 2: Rodar e ver falhar:** `rtk proxy npm --prefix functions test` e `rtk proxy npm --prefix functions run test:integration`.
- [ ] **Step 3: Implementar** `directors.ts` e `createElection`; trocar `assertAdmin` por `assertElectionDirector` em `setElectionStatus` e `reviewVoter`; registrar `electionCreate` e o wrapper `needDirectorAuth` (anônimo recusado) em `index.ts`; exportar em `functions/src/index.ts`. `applyBoard` ainda usa `assertAdmin` até a Task 5.
- [ ] **Step 4: Rodar e ver passar:** os dois comandos, mais `rtk proxy npm --prefix functions run lint` e `run build`.
- [ ] **Step 5: Commit:** `feat(elections): acesso por diretoria e criação da eleição`.

---

### Task 4: Escrutínios — iniciar, votar e encerrar

**Files:**
- Create: `functions/src/elections/scrutinies.ts`
- Delete: `functions/src/elections/rounds.ts`, `tally.ts`, `candidates.ts`, `winners.ts` e os testes `functions/test/electionsTally.test.ts`, `electionsWinners.test.ts`, `functions/integration/rounds.itest.ts` (substituídos)
- Modify: `functions/src/elections/index.ts` (callables `electionStartScrutiny`, `electionCloseScrutiny`; `electionCastVote` e o gatilho passam a vir de `scrutinies.ts`; remove `electionOpenRound` e `electionCloseRound`), `functions/src/elections/common.ts` (`summarizeRound` sai), `functions/src/index.ts`
- Test: `functions/integration/scrutinies.itest.ts`

**Interfaces:**
- Consumes: `decideScrutiny`, `countBallots`, `requiredVotes` (Task 1); `assertElectionDirector` (Task 3).
- Produces:
  - `startScrutiny(db, uid, data): Promise<{roundId: string; number: 1 | 2 | 3}>` — exige eleição `open`, `position` em `positions`, nenhum escrutínio aberto na eleição, e o estado do cargo: `idle` → número 1 (`stage: scrutiny1`); `confirming` com ≥ 1 candidato → número 2; `awaiting3` → número 3. Outro estado → `failed-precondition`. Opções: no 1º, `society.members` (nomes de `users/{id}.name`) menos os `winnerId` dos cargos `decided`; no 2º e 3º, `cargo.candidates` (`{id, name}`). Grava a rodada com `cycle` do cargo e `votedCount: 0`; atualiza o `stage` do cargo; evento `scrutiny_started`.
  - `castVote(db, uid, data): Promise<{receipt: string}>` — mesma transação de antes (`voted` e `ballot` juntos, sem escrever na rodada), escolha válida = id de uma opção da rodada ou `blank`.
  - `closeScrutiny(db, uid, data): Promise<{stage: CargoStage; result: ScrutinyResult}>` — uma transação lê rodada, `ballots`, `voted` e os eleitores `approved` (`presentCount`), chama `decideScrutiny`, fecha a rodada com o `result` e `votedCount` exato e atualiza o cargo: `confirming` (candidatos com votos), `decided` (`winnerId`), `awaiting3`, `tiebreak` (`tiedIds`) ou `idle` (`cycle` + 1, `candidates: []`). Evento `scrutiny_closed` (sem identificar votos).
  - `bumpVotedCount` continua como está (só incrementa rodada `open`).

- [ ] **Step 1: Escrever os testes que falham** em `scrutinies.itest.ts` (semeie cargos e eleitores a partir de `helpers.ts`). `startScrutiny`: diretor inicia o 1º e a rodada tem `number: 1` e todos os membros como opções; quem já é `winnerId` de outro cargo `decided` não aparece; segundo início com um aberto → `failed-precondition`; eleição fora de `open` → `failed-precondition`; diretor de outra sociedade → `permission-denied`; 2º sem candidatos → `failed-precondition`; no 2º as opções são os candidatos do cargo. `castVote`: membro liberado vota e o ballot tem só `choice`; voto repetido → `already-exists`; duas chamadas simultâneas geram um ballot; opção fora da lista → `invalid-argument`; pendente/recusado → `permission-denied`; escrutínio fechado → `failed-precondition`; **o voto não altera `updateTime` da rodada**; eleitor liberado *depois* do início e antes do encerramento vota e entra em `presentCount` (Review Focus 2). `closeScrutiny`: 1º → `confirming` com candidatos por votos; ninguém votou ou só brancos no 1º → `confirming` com lista vazia; 2º com 10 presentes e 6 votos → `decided`; 5 votos → `awaiting3`; 3º com empate → `tiebreak` com `tiedIds`; 3º só brancos → `idle` e `cycle` 2; `result` traz `presentCount`, `threshold`, `blank`, `total`; divergência entre `voted` e `ballots` é marcada; **voto concorrente com o encerramento**: com 3 votos e um fechamento simultâneos, `ballots`, `voted` e `result.total` coincidem e a divergência é falsa (Review Focus 5).
- [ ] **Step 2: Rodar e ver falhar:** `rtk proxy npm --prefix functions run test:integration`.
- [ ] **Step 3: Implementar** `scrutinies.ts` e ajustar `index.ts`; remover os arquivos obsoletos e seus testes; atualizar os exports em `functions/src/index.ts`.
- [ ] **Step 4: Rodar e ver passar:** `rtk proxy npm --prefix functions run test:integration`, `rtk proxy npm --prefix functions test`, `run lint`, `run build`. Rode a integração 3 vezes para checar estabilidade da concorrência.
- [ ] **Step 5: Commit:** `feat(elections): escrutínios (iniciar, votar, encerrar)`.

---

### Task 5: Ações do diretor entre escrutínios e aplicar diretoria

**Files:**
- Create: `functions/src/elections/cargoActions.ts`
- Modify: `functions/src/elections/lifecycle.ts` (`applyBoard` reescrita), `functions/src/elections/common.ts` (`assertAdmin` sai), `functions/src/elections/index.ts` e `functions/src/index.ts` (callables `electionRemoveCandidate`, `electionRestartCargo`, `electionPickOldest`; `electionApplyBoard` com `needDirectorAuth`)
- Test: `functions/integration/cargoActions.itest.ts`, `functions/integration/lifecycle.itest.ts`

**Interfaces:**
- Produces: `removeCandidate(db, uid, data): Promise<void>` (cargo em `confirming` e `candidateId` entre os candidatos, senão `failed-precondition`); `restartCargo(db, uid, data): Promise<void>` (cargo em `confirming` **com lista vazia**, ou em `idle`, volta a `idle` com `cycle` + 1; demais estados → `failed-precondition`); `pickOldest(db, uid, data): Promise<void>` (cargo em `tiebreak` e `candidateId` em `tiedIds` → `decided` com `winnerId`, grava evento com quem escolheu); `applyBoard(db, uid, data): Promise<{winners: Record<string, string>; missingRequired: string[]}>`.
- `applyBoard`: usa os `winnerId` dos cargos `decided`; `missingRequired` lista `presidente`/`vice` que não estão decididos (não é erro); sem nenhum cargo decidido → `failed-precondition`; mantém a recusa de `board` em formato antigo não vazio; grava via `applyWinners`/`boardKey`; acrescenta os diretores do novo `board` a `directorIds` da eleição (união, sem remover ninguém); `boardAppliedAt`; evento `board_applied`.

- [ ] **Step 1: Escrever os testes que falham.** `removeCandidate`: remove em `confirming`; em outro estado → `failed-precondition`; id desconhecido → `failed-precondition`; diretor de outra sociedade → `permission-denied`. **Quem foi removido continua votando**: com cargo no 2º escrutínio aberto e o removido liberado, `castVote` dele em outro candidato e em `blank` funciona (Review Focus 1). Removido como candidato de um cargo aparece de novo nas opções do 1º escrutínio do cargo seguinte (Review Focus 1). `restartCargo`: em `confirming` com lista vazia → `idle`, `cycle` 2, e o novo 1º escrutínio tem opções frescas e `cycle` 2 (Review Focus 4); com candidatos → `failed-precondition`. `pickOldest`: só em `tiebreak`, só entre `tiedIds`, cargo vira `decided`. `applyBoard`: grava só os cargos decididos e preserva os outros; `secretario2` grava `"2º secretario(a)"`; `missingRequired` lista o que falta; nenhum decidido → `failed-precondition`; lista antiga não vazia → `failed-precondition` e nada muda; lista vazia vira mapa; chave `Presidente` não duplica; os novos diretores entram em `directorIds`, os antigos permanecem; reaplicar funciona; `ADMIN` e `OTHER_DIRECTOR` → `permission-denied`.
- [ ] **Step 2: Rodar e ver falhar:** `rtk proxy npm --prefix functions run test:integration`.
- [ ] **Step 3: Implementar** `cargoActions.ts`, reescrever `applyBoard`, remover `assertAdmin` (nada mais o usa), registrar e exportar os callables.
- [ ] **Step 4: Rodar e ver passar:** integração (3 vezes), testes unitários, `lint` e `build`.
- [ ] **Step 5: Commit:** `feat(elections): remover candidato, reiniciar cargo, mais velho e aplicar diretoria`.

---

### Task 6: Regras do Firestore

**Files:**
- Modify: `firestore.rules` (bloco `elections`)
- Test: `rules-tests/elections.rules.test.ts`

**Interfaces:**
- Produces (regras): `elections/{id}`: `get` público; `list` só com `request.auth.uid in resource.data.directorIds`; nenhuma escrita pelo cliente. `rounds`: leitura para qualquer autenticado; nenhuma escrita. `cargos`, `voters` (além do próprio eleitor), `voted` (além do próprio eleitor) e `events`: leitura só dos diretores (`request.auth.uid in get(/databases/$(database)/documents/elections/$(electionId)).data.directorIds`). `ballots`: nenhum acesso.

- [ ] **Step 1: Reescrever os testes que falham.** Semeie uma eleição com `directorIds: ["dir1"]`. Casos: `get` sem login funciona; `list` por consulta `where("directorIds", "array-contains", "dir1")` funciona para `dir1`; a mesma consulta com `uid` de outro usuário falha; `list` sem filtro falha para todos (inclusive admin global); **nenhuma** escrita (`set`, `update`, `delete`, em `elections`, `rounds`, `cargos`, `voters`, `voted`, `events`, `ballots`) passa, nem para o diretor nem para admin; `cargos`, `events`, `voters` e `voted` legíveis pelo diretor e negados a um usuário comum (exceto o próprio `voters/{uid}` e `voted/{uid}`); `ballots` negado a todos; `rounds` legível por anônimo do Firebase e negado sem login.
- [ ] **Step 2: Rodar e ver falhar:** `rtk proxy npm --prefix rules-tests test`.
- [ ] **Step 3: Reescrever o bloco `elections`** em `firestore.rules`, sem tocar nos demais blocos (inclusive os do ensino).
- [ ] **Step 4: Rodar e ver passar:** `rtk proxy npm --prefix rules-tests test` (todos os arquivos).
- [ ] **Step 5: Commit:** `feat(elections): regras de leitura por diretoria; sem escrita do cliente`.

---

### Task 7: Página de voto (web) com opções do escrutínio

**Files:**
- Modify: `web-portal/src/modules/elections/types.ts` (`Round` com `number` e `options`; `positionLabel` com `secretario2` e "1º Secretário(a)"), `components/BallotStep.tsx`, `pages/VotePage.tsx`, `data/electionClient.ts` (se o formato mudar)
- Create: `web-portal/src/modules/elections/filterOptions.ts`
- Test: `web-portal/src/modules/elections/filterOptions.test.ts`, `components/BallotStep.test.tsx`, `pages/VotePage.test.tsx`

**Interfaces:**
- Produces: `filterOptions(options: Candidate[], query: string): Candidate[]` (sem diferenciar maiúsculas nem acentos; consulta vazia devolve tudo; mantém a ordem). `Round = {id: string; position: string; number: 1 | 2 | 3; options: Candidate[]}`. Também exporta, para a Task 8: `CargoStage` (os 8 estados), `CandidateVotes = {id: string; name: string; votes: number}` e `RoundResult` (mesmo formato de `ScrutinyResult`). `positionLabel("secretario")` = `"1º Secretário(a)"`, `positionLabel("secretario2")` = `"2º Secretário(a)"`.

- [ ] **Step 1: Escrever os testes que falham.** `filterOptions`: "joao" acha "João Silva"; ignora caixa; consulta vazia devolve todas; nenhuma correspondência devolve `[]`. `BallotStep`: no 1º escrutínio há campo "Buscar por nome" que filtra a lista; no 2º/3º não há busca; sempre há "Branco"; título "Votação para Presidente — 1º escrutínio"; "Confirmar voto" só habilita com escolha; enviar chama `onSubmit` com o id escolhido. `VotePage`: segue funcionando (entrada, aprovação, voto, comprovante, encerrada) com o novo formato de rodada.
- [ ] **Step 2: Rodar e ver falhar:** `rtk proxy npm --prefix web-portal test`.
- [ ] **Step 3: Implementar** as mudanças; a rodada aberta continua vindo da consulta `status == "open"`.
- [ ] **Step 4: Rodar e ver passar:** `rtk proxy npm --prefix web-portal test`, `run typecheck`, `run lint`.
- [ ] **Step 5: Commit:** `feat(elections): página de voto com opções do escrutínio e busca`.

---

### Task 8: Tela de condução (web)

**Files:**
- Create: `web-portal/src/modules/elections/module.ts`, `data/conductClient.ts`, `conduct/cargoView.ts`, `components/QrPanel.tsx`, `components/PresentesPanel.tsx`, `components/CargoCard.tsx`, `pages/ConductPage.tsx`, `web-portal/src/app/(portal)/eleicoes/[id]/page.tsx`
- Modify: `web-portal/src/core/modules/registry.ts` (registrar o módulo), `web-portal/package.json` (dependência de QR)
- Test: `conduct/cargoView.test.ts`, `pages/ConductPage.test.tsx`

**Interfaces:**
- Produces: `electionsModule: PortalModule` (`id: "elections"`, `basePath: "/eleicoes"`, `access: "authenticated"`, `navItems: []`). Rota com `Suspense` em volta da leitura de `params` (o projeto usa `cacheComponents`). Dependência `qrcode.react` (versão compatível com React 19; confira ao instalar).
- `cargoView(input: {stage: CargoStage; position: string; number?: 1 | 2 | 3; round?: Round; result?: RoundResult; candidates: CandidateVotes[]; tiedIds: string[]; winnerName?: string}): {title: string; actions: Array<{kind: "start" | "close" | "removeCandidate" | "restart" | "pickOldest"; label: string; targetId?: string}>}` — função pura que decide o texto e os botões de cada fase.
- `conductClient.ts`: observadores (`watchElection`, `watchCargos`, `watchRounds`, `watchVoters`, `watchVoted` da rodada aberta) e chamadas das callables do contrato.

- [ ] **Step 1: Escrever os testes que falham.** `cargoView` por fase: `idle` → ação `start` "Iniciar 1º escrutínio"; `scrutiny1` aberto → ação `close`; `confirming` com candidatos → uma ação `removeCandidate` por candidato (com `targetId`) e `start` "Iniciar 2º escrutínio"; `confirming` vazio → só `restart`; `awaiting3` → `start` "Iniciar 3º escrutínio"; `tiebreak` → uma ação `pickOldest` por empatado; `decided` → título "Eleito(a): <nome>" e nenhuma ação. `ConductPage` (módulos de dados simulados): quem não está em `directorIds` vê "Acesso restrito aos diretores" e nenhum botão; diretor vê o QR com o link `/votar/<id>`; convidado pendente tem aceitar/recusar; escrutínio aberto mostra "3 de 5 votaram" e a lista de **quem falta votar** (liberados menos quem votou); resultado encerrado mostra a meta "6 de 10 necessários"; clicar em "Iniciar 1º escrutínio" chama `electionStartScrutiny` com `{electionId, position}`; "Remover como candidato" chama `electionRemoveCandidate`; "Aplicar diretoria" mostra aviso quando `missingRequired` não é vazio.
- [ ] **Step 2: Rodar e ver falhar:** `rtk proxy npm --prefix web-portal test`.
- [ ] **Step 3: Implementar** os arquivos, instalar a dependência de QR e registrar o módulo; o QR codifica `${window.location.origin}/votar/${electionId}` com botão copiar.
- [ ] **Step 4: Rodar e ver passar:** `rtk proxy npm --prefix web-portal test`, `run typecheck`, `run lint` e `run build` com as variáveis de teste (a rota `/eleicoes/[id]` deve aparecer como prerender parcial).
- [ ] **Step 5: Commit:** `feat(elections): tela web de condução com QR`.

---

### Task 9: App Flutter (criar, listar, abrir na web, ata)

**Files:**
- Modify: `lib/src/modules/elections/models/election.dart`, `election_logic.dart`, `minutes_text.dart`, `lib/src/modules/elections/data/elections_repository.dart`, `presentation/elections_page.dart`, `presentation/widgets/election_form_sheet.dart`, `presentation/election_detail_page.dart`, `presentation/widgets/election_minutes_tab.dart`
- Delete: `presentation/widgets/election_voters_tab.dart`, `election_rounds_tab.dart`, `candidate_picker_sheet.dart`
- Test: `test/modules/elections/election_models_test.dart`, `election_logic_test.dart`, `minutes_text_test.dart`, `election_form_test.dart`

**Interfaces:**
- Produces (modelos, arquivos de `models/`): `CargoStage` (enum com os 8 estados e `parse`); `ElectionCargo {position, stage, cycle, candidates (CandidateVotes), tiedIds, winnerId}`; `ElectionRound` com `number`, `cycle`, `options` e `result` no novo formato (`counts`, `blank`, `total`, `presentCount`, `threshold`, `winnerId`, `tie`, `divergence`); `Election.directorIds`.
- `election_logic.dart`: `buildVoteLink(id)`, `buildConductLink(id)` (`${portalBaseUrl}/eleicoes/<id>`), `directorSocieties(List<SocietyModel> societies, String userId): List<SocietyModel>` (usa `allBoardIds`), `defaultElectionTitle` (já existe). Sem importar nada que traga Firebase. Remover `latestWinners`, `candidateOptions`, `duplicateVoterIds`.
- `ElectionsRepository`: `watchElections(String userId)` com `where("directorIds", arrayContains: userId)` e **ordenação no cliente** (evita índice composto); `watchElection`, `watchCargos`, `watchRounds`, `watchVoters`, `watchEvents`; `createElection(...)` chamando `electionCreate`. Saem `setStatus`, `reviewVoter`, `openRound`, `closeRound`, `saveRoundCandidates`, `deleteRound`, `applyBoard`.
- `buildMinutesText({election, cargos, voters, rounds, events})`: por cargo, cada escrutínio com contagem por opção, branco, "limiar X de Y presentes", quem foi removido (eventos `candidate_removed`), empate e quem foi escolhido como mais velho (evento `oldest_picked`), eleito; presentes liberados; linha do tempo.

- [ ] **Step 1: Escrever os testes que falham.** Modelos: `ElectionCargo.fromJson` e `CargoStage.parse` (desconhecido → `idle`); `ElectionRound.fromJson` com `number`, `options` e `result` novos; `Election.fromJson` lê `directorIds`. Lógica: `buildConductLink("abc")` termina em `/eleicoes/abc`; `directorSocieties` devolve só as sociedades cujo `allBoardIds` contém o usuário e ignora as outras. Ata: contém "1º escrutínio", a contagem por opção, "6 de 10", o nome de quem foi removido, "Empate", o mais velho escolhido e "Eleito(a): <nome>"; um cargo sem escrutínio aparece como "Não votado"; presentes só os liberados. `election_form_test`: título padrão continua.
- [ ] **Step 2: Rodar e ver falhar:** `rtk proxy flutter test test/modules/elections --reporter expanded`.
- [ ] **Step 3: Implementar** modelos, lógica, repositório e a ata; reescrever a tela de detalhe (cabeçalho, botão "Abrir condução na web" com `url_launcher`, "Copiar link do QR", e a ata); o formulário lista só `directorSocieties` e marca Presidente e Vice como obrigatórios; a lista chama `watchElections` com o uid do usuário logado (`AppState.currentUser`); excluir os arquivos obsoletos; o item de menu em Configurações continua visível para admins (todos os diretores são admins; o filtro real é o do servidor e da lista).
- [ ] **Step 4: Rodar e ver passar:** `rtk proxy flutter test --reporter expanded` (suíte inteira) e `rtk proxy flutter analyze lib/src/modules/elections`.
- [ ] **Step 5: Commit:** `feat(elections): app cria e lista eleições, abre a condução na web e mostra a ata`.

---

### Task 10: Verificação final e fechamento

**Files:**
- Modify: `docs/superpowers/plans/2026-10-15-society-elections.md` (aviso de substituído no topo), `docs/superpowers/specs/2026-10-15-society-elections-design.md` (somente se algo divergir do implementado)

- [ ] **Step 1: Procurar resíduos:** `rtk proxy grep -rn "electionOpenRound\|electionCloseRound\|tallyRound\|roundTypeFor\|assertAdmin" functions/src web-portal/src lib` não pode achar nada; idem `signInAnonymously`.
- [ ] **Step 2: Rodar tudo:** `rtk proxy npm --prefix functions run lint`, `run build`, `test`, `run test:integration`, `run test:emulator`; `rtk proxy npm --prefix rules-tests test`; `rtk proxy npm --prefix web-portal test`, `run typecheck`, `run lint`; `rtk proxy flutter test --reporter expanded`; `next build` com variáveis de teste. Tudo verde; qualquer falha é relatada com a saída.
- [ ] **Step 3: Marcar o plano antigo como substituído** (linha no topo apontando para este) e conferir se o spec ainda descreve o que foi feito.
- [ ] **Step 4: Commit:** `docs(elections): plano antigo substituído; verificação final`.
- [ ] **Step 5: Roteiro de publicação (entregar ao usuário, não executar):** confirmar o provedor Google no Firebase Auth e não ativar o Anônimo; `firebase deploy --only` com as Functions de eleição (`electionCreate`, `electionSetStatus`, `electionCheckIn`, `electionReviewVoter`, `electionStartScrutiny`, `electionCastVote`, `electionCloseScrutiny`, `electionRemoveCandidate`, `electionRestartCargo`, `electionPickOldest`, `electionApplyBoard`, `electionVoteRecorded`) e `firestore:rules`, com confirmação antes; remover do projeto as Functions antigas `electionOpenRound` e `electionCloseRound` se tiverem sido publicadas (não foram); novo build do app; teste real numa sociedade de teste ou revertendo o `board` depois.
