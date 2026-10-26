# Fórum de professores — Etapa 1 (portal web + backend) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o Fórum no portal web (tópicos, comentários aninhados, 👍/👎, moderação, sino) com regras, índices e Functions, sem publicar nada.

**Architecture:** Coleções novas `forum_topics` (+ `comments` + `votes`); cliente escreve só campos permitidos pelas regras e Functions recalculam `score`, `commentCount`, `lastActivityAt` e notificam (padrão "Function como juiz" da Biblioteca). Módulo web novo `modules/teaching/forum/` com rotas finas em `app/(portal)/ensino/forum/`.

**Tech Stack:** Next.js (versão atual do repo; **não mexer em `web-portal/package.json` nem no lockfile**: outra sessão atualiza o Next), React 19, Tailwind v4, Vitest + Testing Library (sem `user-event`; usar `fireEvent`), Firebase JS SDK, Cloud Functions v1 (Node 22, TS), `rules-tests` (emulador).

**Spec:** `docs/superpowers/specs/2026-10-26-teaching-forum-design.md` (seções 3–8, 10). A Etapa 2 (app Flutter, spec §9) terá plano próprio depois.

## Global Constraints

- Nada é publicado: sem `git push`, PR, deploy de regras/índices/Functions. Só commits locais. Git sempre como `/usr/bin/git` (sem `-C`, sem heredocs; para editar vários arquivos use um script `.py` no scratchpad).
- Regras do Firestore existentes **não podem ser apertadas**: só blocos novos (aditivos). Índices antigos de `firestore.indexes.json` não são removidos.
- Reutilizar `core/ui` (`Button`, `Card`, `TextField`, `GlassCard`) sem restilizar. Não editar arquivos da Biblioteca/Fila (`library/ui/*`), `ensino/page.tsx`, `ensino/biblioteca/page.tsx`, `TeachingHomePage`. Só leitura de `library/*` (importar funções/tipos).
- `modules/teaching/module.ts` e a página de notificações: **só na Tarefa 8, depois que a Central avisar que a UX/UI foi mergeada** (rebase antes).
- Limites: título 3–120; corpo de tópico/comentário 1–5000; ≤3 assuntos; ≤3 citações; profundidade máx. 3; fixados ≤5 (interface); lista pagina por cursor, 20 por página.
- Textos de interface em português (pt-BR). Sem `onSnapshot` no Fórum (carregamento único + recarregar após ação).
- Functions: lint com JSDoc em `function` declaradas (use arrow `const`) e `max-len` 80; testes de lógica com portas em memória.
- Comandos: `npm --prefix web-portal test|run lint|run typecheck`, `npm --prefix functions test|run lint|run build`, `npm --prefix rules-tests test` (emulador, Java 17).

## Review Focus

- Comentário em tópico **trancado** ou **removido**: regra nega criar, votar e responder (Tarefa 1; Tarefa 7 esconde os botões).
- Responder ao comentário **removido** ou de profundidade 3: negado nas regras e sem botão (Tarefas 1 e 3).
- **Votar no próprio comentário** e votar com `value` inválido (0, 2): negados (Tarefa 1).
- Retentativa de gatilho: `score` e `commentCount` recalculados do zero dão o mesmo resultado se o evento rodar duas vezes (Tarefa 2).
- Autor responde ao **próprio** tópico/comentário: não gera notificação (Tarefa 2).
- Texto com `<script>`/HTML e URLs: exibido como texto, URL vira link `noreferrer`; só `http(s)` vira link (Tarefa 3).
- Citação cujo documento deixou de ser publicado ou foi removido: mostra só o rótulo, sem quebrar (Tarefas 3 e 7).

## File Structure

- `firestore.rules` (modify, bloco novo no fim) · `firestore.indexes.json` (modify, só adiciona) · `rules-tests/forum.firestore.rules.test.ts` (create)
- `functions/src/teaching/forum/{constants,types,processComment,processVote,adapters,triggers}.ts` + `*.test.ts` · `functions/src/index.ts` (modify: 3 exports)
- `web-portal/src/modules/teaching/forum/`: `types.ts`, `convert.ts`, `payloads.ts`, `tree.ts`, `permissions.ts`, `linkify.ts` (lógica pura + `forum.test.ts`); `repository.ts` (Firestore); `ui/{TopicListPage,NewTopicPage,TopicPage,CommentNode,RefPicker,RefCard}.tsx`
- `web-portal/src/app/(portal)/ensino/forum/{page.tsx,novo/page.tsx,[topicId]/page.tsx}` (rotas finas)

---

### Task 1: Regras do Firestore e índices

**Files:**
- Modify: `firestore.rules` (blocos novos), `firestore.indexes.json`
- Create: `rules-tests/forum.firestore.rules.test.ts` (padrão de `plan.firestore.rules.test.ts`: `createEnv`, contextos `teacher`/`curator`/`adminOnly`/`plain`)

**Interfaces:**
- Produces: funções de regra `canUseForum()` (= `canUseTeaching()`), `isModerator()` (= `isCurator() || hasAdminClaim()`); modelo de documentos da spec §5 (campos exatos de tópico/comentário/voto).

- [ ] **Step 1: Escrever os testes de regras (falhando)** em `forum.firestore.rules.test.ts`. Casos mínimos, cada um `assertSucceeds`/`assertFails`:
  - leitura de tópico/comentário: teacher/curator/admin ok; usuário sem papel e anônimo negados.
  - criar tópico válido (teacher) ok; com `pinned:true`, `locked:true`, `commentCount:1`, título de 2 ou 121 caracteres, 4 `tagIds`, 4 `refs`, `authorUid` de outro, `createdAt` ≠ `serverTimestamp()` → negados.
  - atualizar tópico: autor muda `title/body/tagIds/refs/searchTokens/updatedAt/editedAt` ok; autor muda `pinned` negado; autor `deleted:true` ok; não-autor teacher `deleted:true` negado; curator e admin mudam `pinned/locked/deleted` ok; ninguém muda `commentCount/lastActivityAt/authorUid`; `delete` negado para todos.
  - criar comentário: raiz (`parentId:null, depth:1`) ok; resposta com `depth` = pai+1 ok; `depth` errado, pai inexistente, pai `deleted`, `depth:4`, tópico `locked`, tópico `deleted`, `score:1`, corpo vazio ou >5000, `refs` >3 → negados.
  - atualizar comentário: autor muda `body/refs/editedAt` ok e `deleted:true` ok; curator `deleted:true` ok; curator muda `body` negado; qualquer um muda `score` negado.
  - votos em `comments/{c}/votes/{uid}`: criar com `value` 1 e −1 ok; `value` 0 ou 2 negado; id ≠ uid negado; no próprio comentário negado; em tópico trancado negado; trocar (`update`) e apagar o próprio ok; ler voto de outro negado.
- [ ] **Step 2: Rodar `npm --prefix rules-tests test -- forum` e ver falhar.**
- [ ] **Step 3: Implementar os blocos em `firestore.rules`** (`match /forum_topics/{topicId}` com sub-`match` para `comments/{commentId}` e `comments/{commentId}/votes/{uid}`; validadores `validTopicCreate`, `validCommentCreate`; edições limitadas com `request.resource.data.diff(resource.data).affectedKeys().hasOnly([...])`; `get(...)` do tópico e do pai para trancado/removido/profundidade). Seguir as regras literais da spec §6.
- [ ] **Step 4: Adicionar índices em `firestore.indexes.json`** (só acrescentar): `forum_topics` `(deleted asc, pinned asc, lastActivityAt desc)`, `(deleted asc, tagIds array-contains, lastActivityAt desc)`, `(deleted asc, searchTokens array-contains, lastActivityAt desc)`; comentários ordenam por `createdAt` (índice simples, nada a declarar).
- [ ] **Step 5: Rodar `npm --prefix rules-tests test` (todos os arquivos) e ver passar**, inclusive os testes antigos.
- [ ] **Step 6: Commit** `feat(forum): regras e índices do Firestore`.

---

### Task 2: Cloud Functions do Fórum

**Files:**
- Create: `functions/src/teaching/forum/{constants.ts,types.ts,processComment.ts,processVote.ts,adapters.ts,triggers.ts}`, `processComment.test.ts`, `processVote.test.ts`
- Modify: `functions/src/index.ts` (exportar `onForumCommentCreated`, `onForumCommentUpdated`, `onForumVoteWritten` perto da linha 1822)

**Interfaces:**
- Consumes: padrão de `library/adapterNotifier.ts` (coleção `teaching_notifications`, criação idempotente com `ref.create`, push FCM respeitando `users.disabled_notifications`).
- Produces: `NOTIFICATION_PREFERENCE = "teaching_forum"`; `interface ForumDb { getTopic(id): Promise<TopicData|null>; getComment(topicId, id): Promise<CommentData|null>; countActiveComments(topicId): Promise<number>; sumVotes(topicId, commentId): Promise<number>; updateTopic(id, patch): Promise<void>; updateComment(topicId, id, patch): Promise<void> }`; `interface ForumNotifier { notify(n: {id; toUid; title; body; topicId; commentId}): Promise<void> }`; `processCommentCreated(deps, topicId, commentId): Promise<void>`; `processCommentUpdated(deps, topicId, before, after): Promise<void>`; `processVoteWritten(deps, topicId, commentId): Promise<void>`.

- [ ] **Step 1: Testes (portas em memória) em `processComment.test.ts`:** (a) comentário raiz → `commentCount` = nº de ativos, `lastActivityAt` atualizado, notifica o autor do tópico com id `forum_reply_<commentId>`; (b) resposta → notifica só o autor do comentário-pai (não o do tópico); (c) autor respondendo a si mesmo → nenhuma notificação; (d) processar o mesmo evento duas vezes → mesmo `commentCount` e notificação não duplicada; (e) `deleted` false→true → `commentCount` recalculado; (f) corpo longo é truncado em ~100 caracteres na notificação; (g) tópico removido ou inexistente → não faz nada. Em `processVote.test.ts`: `score` = soma dos votos; rodar 2× dá o mesmo valor; voto removido reduz; comentário inexistente → não faz nada.
- [ ] **Step 2: Rodar `npm --prefix functions test -- forum` e ver falhar.**
- [ ] **Step 3: Implementar** as três funções puras em `processComment.ts`/`processVote.ts` (recalcular, nunca incrementar), `adapters.ts` (Admin SDK: `count()` com `where("deleted","==",false)`, agregação `sum("value")`, notificador igual ao da Biblioteca com `data: {type: "teaching_forum", topicId, url: PORTAL_URL + "/ensino/forum/" + topicId}` e título "Nova resposta no Fórum"; documento de notificação com `type: "forum_reply"`, `topicId`, `commentId`, `itemId: ""`) e `triggers.ts` (gatilhos v1 finos com `failurePolicy: true`, como `library/triggers.ts`: `forum_topics/{topicId}/comments/{commentId}` onCreate e onUpdate; `.../votes/{uid}` `onWrite`). Exportar no `index.ts`.
- [ ] **Step 4: Rodar `npm --prefix functions test`, `run lint` e `run build`; tudo verde.**
- [ ] **Step 5: Commit** `feat(forum): Functions de contadores e notificações`.

---

### Task 3: Lógica pura do portal (tipos, payloads, árvore, permissões, links)

**Files:**
- Create: `web-portal/src/modules/teaching/forum/{types.ts,convert.ts,payloads.ts,tree.ts,permissions.ts,linkify.ts}`, `forum.test.ts`

**Interfaces:**
- Consumes: `searchTokens(text)` de `../library/searchTokens`; `viewerFrom`/`Viewer` de `../library/types`.
- Produces (assinaturas exatas):
  - `type Ref = {kind: "library" | "plan"; id: string; label: string}`; `interface Topic {id; title; body; authorUid; authorName; tagIds: string[]; refs: Ref[]; pinned; locked; deleted; createdAt: number; updatedAt: number; editedAt?: number; lastActivityAt: number; commentCount: number}`; `interface Comment {id; topicId; body; authorUid; authorName; parentId: string|null; depth: 1|2|3; refs: Ref[]; score: number; deleted; createdAt: number; editedAt?: number}`
  - `toTopic(id: string, data: DocumentData): Topic | null`, `toComment(topicId: string, id: string, data: DocumentData): Comment | null` (null se campos obrigatórios faltam)
  - `validateTopicInput(input: {title; body; tagIds; refs}): string | null` (mensagem de erro em português ou null); `validateCommentInput(input: {body; refs}): string | null`; `newTopicPayload(input, author: {uid; name}, ts): Record<string, unknown>`; `newCommentPayload(input, author, parent: Comment | null, ts): Record<string, unknown>`; `topicEditPatch(input, ts)`, `commentEditPatch(input, ts)`
  - `buildTree(comments: Comment[]): CommentNodeData[]` com `type CommentNodeData = {comment: Comment; children: CommentNodeData[]}`, ordenado por `createdAt` asc; órfãos (pai ausente) sobem para a raiz
  - `topicPermissions(topic: Topic, viewer: Viewer): {canEdit; canDelete; canPin; canLock; canComment; visibleBody}` e `commentPermissions(c: Comment, topic: Topic, viewer: Viewer): {canReply; canVote; canEdit; canDelete}` (`isModerator = viewer.isCurator || viewer.isAdmin`)
  - `linkify(text: string): Array<{type: "text" | "link"; value: string}>` (só `http://`/`https://`)

- [ ] **Step 1: Escrever `forum.test.ts` (falhando).** Casos: `validateTopicInput` rejeita título de 2/121, corpo vazio/5001, 4 assuntos, 4 refs e aceita os limites exatos (3/120/5000); `buildTree` aninha 1→1.1→1.1.1, ordena, e coloca órfão na raiz; `commentPermissions`: autor edita/apaga, não-autor teacher não; curator/admin apagam mas não editam alheio; `canReply` falso em depth 3, comentário removido, tópico trancado ou removido; `canVote` falso no próprio comentário, em trancado e removido; `topicPermissions.canPin` só moderador; `visibleBody` esconde tópico removido de quem não é autor/moderador; `linkify("veja https://a.com/x e <script>")` devolve link só para a URL e o `<script>` como texto; `javascript:alert(1)` não vira link; `newCommentPayload` calcula `depth = pai.depth + 1` e `score: 0, deleted: false`; `newTopicPayload` traz `pinned/locked/deleted: false`, `commentCount: 0`, `searchTokens` do título.
- [ ] **Step 2: Rodar `npm --prefix web-portal test -- forum` e ver falhar.**
- [ ] **Step 3: Implementar os arquivos** conforme as assinaturas acima (`payloads.ts` recebe o timestamp como parâmetro, como `plan/payloads.ts`).
- [ ] **Step 4: Rodar `npm --prefix web-portal test -- forum`, `run lint`, `run typecheck`; verdes.**
- [ ] **Step 5: Commit** `feat(forum): lógica pura do portal`.

---

### Task 4: Camada de dados do portal

**Files:**
- Create: `web-portal/src/modules/teaching/forum/repository.ts`

**Interfaces:**
- Consumes: Task 3 (`toTopic`, `toComment`, payloads); `db` de `@/core/firebase/client`; `loadLibraryPage` e tipos da Biblioteca (só leitura) para citar documentos publicados; leitura de `teaching_plan` (`../plan/convert` `toPlanRow`) e `teaching_tags`.
- Produces: `loadTopicsPage(opts: {tagId?: string; search?: string; cursor?: TopicCursor | null}): Promise<{topics: Topic[]; next: TopicCursor | null}>` (não fixados, `deleted == false`, `lastActivityAt desc`, 20 por página; `search` usa `array-contains` do primeiro prefixo normalizado e é exclusivo com `tagId`); `loadPinnedTopics(opts: {tagId?; search?}): Promise<Topic[]>` (≤5); `loadTopic(id): Promise<Topic | null>`; `loadComments(topicId): Promise<Comment[]>` (até 500, `createdAt asc`); `loadMyVotes(topicId, uid, commentIds): Promise<Record<string, 1 | -1>>`; `createTopic(input, author): Promise<string>`; `editTopic(id, input)`; `setTopicFlags(id, flags: Partial<{pinned; locked; deleted}>)`; `createComment(topicId, input, author, parent)`; `editComment(topicId, id, input)`; `removeComment(topicId, id)`; `setVote(topicId, commentId, uid, value: 1 | -1 | 0)` (0 apaga); `loadSubjectTags(): Promise<{id; name}[]>` (`kind == "subject"`, `active == true`, por `order`); `loadPublishedDocs(search: string): Promise<Ref[]>` (itens `status == "published"` e `type != "folder"`, rótulo = nome); `loadPlanLessons(): Promise<Ref[]>` (rótulo "Aula N — tema").

- [ ] **Step 1: Teste de unidade só da parte pura de montagem de consulta** (`forum.test.ts`, bloco "queries"): função exportada `topicQueryKey({tagId, search})` rejeita os dois juntos (lança) e normaliza o prefixo da busca; falha antes, passa depois. O acesso real ao Firestore é validado na Tarefa 9 (emulador/manual).
- [ ] **Step 2: Rodar o teste e ver falhar; implementar `repository.ts`; ver passar.**
- [ ] **Step 3: `npm --prefix web-portal run lint` e `run typecheck`.**
- [ ] **Step 4: Commit** `feat(forum): camada de dados do portal`.

---

### Task 5: Lista de tópicos e rotas

**Files:**
- Create: `web-portal/src/modules/teaching/forum/ui/TopicListPage.tsx`, `TopicListPage.test.tsx`, `web-portal/src/app/(portal)/ensino/forum/page.tsx` (`export {default} from "@/modules/teaching/forum/ui/TopicListPage";`), mesmo estilo para `novo/page.tsx` e `[topicId]/page.tsx` (apontando para as páginas das Tarefas 6 e 7; criar já com placeholder mínimo se necessário e substituir depois)

**Interfaces:**
- Consumes: `loadTopicsPage`, `loadPinnedTopics`, `loadSubjectTags` (Tarefa 4); `Button`, `Card`, `TextField`.
- Produces: `default export function TopicListPage()`.

- [ ] **Step 1: Teste (mockando `../repository`)**: renderiza fixados antes dos demais com selo "Fixado"; mostra título, autor, nº de comentários, "Trancado"; "Carregar mais" chama a próxima página; escolher assunto chama o repositório com `tagId` e limpa a busca; digitar busca limpa o assunto; lista vazia mostra "Nenhum tópico ainda."; erro mostra "Não foi possível carregar o fórum."; botão "Novo tópico" leva a `/ensino/forum/novo`.
- [ ] **Step 2: Rodar e ver falhar; implementar a página; ver passar.**
- [ ] **Step 3: lint + typecheck. Commit** `feat(forum): lista de tópicos`.

---

### Task 6: Criar/editar tópico e seletor de citações

**Files:**
- Create: `ui/NewTopicPage.tsx`, `ui/RefPicker.tsx`, `ui/RefCard.tsx`, testes `NewTopicPage.test.tsx`, `RefPicker.test.tsx`

**Interfaces:**
- Consumes: Tarefa 3 (`validateTopicInput`, `Ref`), Tarefa 4 (`createTopic`, `loadSubjectTags`, `loadPublishedDocs`, `loadPlanLessons`).
- Produces: `RefPicker({value: Ref[]; onChange(refs: Ref[]): void; max?: number})` (abas "Documento da Biblioteca" com busca e "Aula do Plano"); `RefCard({ref: Ref})` (documento → link `/ensino/biblioteca?item=<id>`; aula → `/ensino/plano`; nova aba não necessária); `NewTopicPage()` aceita `?editar=<topicId>` para editar o próprio tópico.

- [ ] **Step 1: Testes**: botão "Publicar" desabilitado/mostra erro de `validateTopicInput`; escolher até 3 assuntos (o 4º é recusado); `RefPicker` lista só os documentos devolvidos pelo repositório mockado e limita a 3; submit chama `createTopic` com o autor (`uid` e nome do usuário logado) e navega para `/ensino/forum/<id>`; falha do repositório mostra "Não foi possível publicar. Tente novamente." sem perder o texto.
- [ ] **Step 2: Rodar e ver falhar; implementar; ver passar. Lint + typecheck.**
- [ ] **Step 3: Commit** `feat(forum): criar e editar tópico, citar documento ou aula`.

---

### Task 7: Tópico, comentários, votos e moderação

**Files:**
- Create: `ui/TopicPage.tsx`, `ui/CommentNode.tsx`, `ui/ForumText.tsx` (renderiza `linkify`, `rel="noopener noreferrer"`, `target="_blank"`, `white-space: pre-wrap`), testes `TopicPage.test.tsx`, `CommentNode.test.tsx`

**Interfaces:**
- Consumes: Tarefas 3 e 4 (`buildTree`, `commentPermissions`, `topicPermissions`, `loadTopic`, `loadComments`, `loadMyVotes`, `createComment`, `editComment`, `removeComment`, `setVote`, `setTopicFlags`, `editTopic`), `RefPicker`, `RefCard`.
- Produces: `TopicPage({topicId}: {topicId: string})` (a rota `[topicId]/page.tsx` repassa o parâmetro).

- [ ] **Step 1: Testes**: árvore renderiza níveis 1–3 com recuo; nível 3 não tem "Responder"; comentário removido mostra "[removido]" sem corpo e sem "Responder", mas seus filhos aparecem; 👍 chama `setVote(..., 1)`, clicar de novo no mesmo 👍 chama `setVote(..., 0)`, 👎 depois de 👍 troca para −1; saldo e voto atual aparecem; próprio comentário não mostra botões de voto; autor vê Editar/Apagar; curador vê Apagar mas não Editar em alheio; moderador vê Fixar/Trancar e o clique chama `setTopicFlags`; tópico trancado mostra "Tópico trancado" e esconde formulário, Responder e votos; tópico removido mostra "Tópico removido" a quem não é autor/moderador; `<script>` aparece como texto; URL vira link com `rel="noopener noreferrer"`; após comentar a lista recarrega; erro de carga/gravação mostra mensagens em português.
- [ ] **Step 2: Rodar e ver falhar; implementar; ver passar. Lint + typecheck.**
- [ ] **Step 3: Commit** `feat(forum): página do tópico, comentários, votos e moderação`.

---

### Task 8: Menu e notificações (BLOQUEADA até a Central avisar que a UX/UI foi mergeada)

**Files:**
- Modify: `web-portal/src/modules/teaching/module.ts` (+ `module.test.ts`), arquivo da página/lista de notificações existente em `/ensino/notificacoes` e seu conversor (localizar com `grep -rn "teaching_notifications" web-portal/src`)

**Interfaces:**
- Consumes: documentos `teaching_notifications` com `type: "forum_reply"`, `topicId`, `commentId`.

- [ ] **Step 1: Rebase na `master` já com a UX/UI; reler `module.ts` e a página de notificações atuais.**
- [ ] **Step 2: Testes**: `module.test.ts` espera o item `{label: "Fórum", href: "/ensino/forum", access: "teacher"}`; teste do conversor/lista: notificação `forum_reply` é aceita (não descartada como inválida), mostra título/corpo e leva a `/ensino/forum/<topicId>`; notificações da Biblioteca continuam iguais.
- [ ] **Step 3: Implementar com mudança mínima** (1 item de menu; ramo para `forum_reply` no conversor e no link). Rodar testes, lint, typecheck.
- [ ] **Step 4: Commit** `feat(forum): item de menu e notificações do Fórum`.

---

### Task 9: Verificação final e entrega

**Files:**
- Modify: `docs/superpowers/specs/2026-10-26-teaching-forum-design.md` (só se algo mudou na prática; anotar na seção correspondente)

- [ ] **Step 1: Rodar tudo:** `npm --prefix web-portal test`, `run lint`, `run typecheck`, `run build` (repetir se aparecer `SecurityFatalError`); `npm --prefix functions test`, `run lint`, `run build`; `npm --prefix functions run test:emulator`; `npm --prefix rules-tests test`. Tudo verde.
- [ ] **Step 2: Teste manual com emulador (se viável) ou checklist para o usuário:** criar tópico com assunto e citação de documento publicado; comentar, responder em 3 níveis, votar; trancar e fixar como curador; apagar como autor; ver o sino com `forum_reply`. Registrar no relatório o que não pôde ser exercitado (push FCM e gatilhos só funcionam em produção).
- [ ] **Step 3: Escrever o roteiro de publicação para a Central (sem executar):** ordem `firestore:indexes` → `functions:onForumCommentCreated,onForumCommentUpdated,onForumVoteWritten --force` → `firestore:rules` → merge (Vercel publica). Commit final e aviso à Central.
