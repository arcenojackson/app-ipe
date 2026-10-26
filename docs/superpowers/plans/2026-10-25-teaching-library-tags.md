# Biblioteca por tags, Fila de Revisão e visualização rápida — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar a biblioteca em pastas do Portal de Ensino por uma lista de arquivos publicados filtrada por tags (tipo, assunto, faixa etária), mover todo envio/revisão para a Fila de Revisão e abrir qualquer arquivo numa janela de visualização.

**Architecture:** Mantém `teaching_items` e a máquina de estados já em produção (2 aprovações, devolução, exclusão, Functions como juiz) e acrescenta campos de tag, `publishedAt` e `searchTokens` ao item, mais a coleção `teaching_tags` (editada à mão no banco). A Biblioteca consulta só itens `published` ordenados por `publishedAt`, com um filtro "principal" no servidor (uma tag ou um token de busca) e o restante filtrado no cliente com paginação por cursor. A visualização lê os bytes pelo SDK autenticado do Storage e desenha PDF/DOCX no navegador.

**Tech Stack:** Next.js 16 / React 19 / Vitest no `web-portal/`, Firebase JS SDK 13 (Firestore, Storage), Cloud Functions v1 (Node 22) em `functions/`, regras testadas em `rules-tests/` (emulador), `pdfjs-dist` e `docx-preview` (versões fixadas na Task 7).

**Spec:** `docs/superpowers/specs/2026-10-25-teaching-library-tags-design.md` (leia também; este plano a implementa). Base de código: PR #4 (Plano B) já mergeado; branch `teaching-library-tags`.

## Global Constraints

- Texto da interface em pt-BR. Execução por subagentes **somente Sonnet**.
- **Não apertar** regras do Firestore existentes: só mudanças aditivas ou que afrouxam o necessário. Nenhum deploy (regras, índices, Functions, CORS, Vercel) sem autorização do usuário no momento (Task 10).
- Três tipos de tag; **todo envio e reenvio exige pelo menos uma tag de cada tipo**; vários por tipo permitidos.
- Tags vivem em `teaching_tags/{id}` = `{kind: "type"|"subject"|"age", name, order, active}`; criar/editar tags é manual pelo banco. Nunca escrever tags no código além do arquivo de semente (Task 3).
- Faixas etárias (exatas): `UCP`, `UPA`, `UMP`, `ADULTOS`, `CASAIS`, `SAF`, `HOMENS`. Tipos (exatos): `Sermões`, `Recursos pedagógicos`, `Fichamentos e resumos`, `Bibliografia`, `Aulas`, `Artigos`. Os 25 assuntos são os da seção 4.2 da spec, com os nomes exatamente como lá.
- Biblioteca mostra **somente `status == "published"`**, para todos (curadores inclusive), com o nome do autor. Itens em revisão/devolvidos só na Fila de Revisão.
- Fila de Revisão: professor vê só os próprios envios (`in_review`, `returned`); curador vê os seus, os de outros em revisão e os pedidos de exclusão. Aprovado sai da Fila.
- Links abrem em **nova aba** (`target="_blank" rel="noopener noreferrer"`, só `http://`/`https://`), nunca na janela de visualização.
- Visualização **somente web**; sem URL pública do arquivo; sem serviço externo de visualização. Tipos sem pré-visualização mostram nome, tipo, tamanho e botão de baixar. Limite de arquivo continua 100 MB.
- Editar tags **não** muda `version` nem zera votos; fica no log (`teaching_log`) e notifica o autor.
- Escala: nada de carregar todos os itens para filtrar no navegador; paginação por cursor; se a busca exigir serviço externo pago, **parar e consultar o usuário**.
- Ambiente: o hook bloqueia `git` simples e scripts de shell: use `/usr/bin/git`, comandos simples, caminhos literais, `npm --prefix web-portal …` / `npm --prefix functions …`. Commits terminam com `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Review Focus

1. Busca com acentos, maiúsculas e palavras curtas ("fé", "é"): sem diferenciar acento/caixa; palavra de 1 caractere é ignorada (Tasks 4 e 5).
2. Filtros que eliminam quase tudo: o cliente varre vários lotes até encher a página; se bater no limite de varredura, mostra o que achou e mantém "Carregar mais"; zero resultado mostra "Nenhum arquivo encontrado." (Tasks 5 e 6).
3. PDF/DOCX corrompido, protegido por senha ou enorme: estado de erro com botão de baixar, sem quebrar a janela (Task 7).
4. DOCX com links hostis (`javascript:`): nenhum link executável na pré-visualização (Task 7).
5. Tag desativada ou removida de `teaching_tags` mas ainda presente em arquivos: o chip mostra "Tag removida" e os filtros só oferecem tags `active` (Task 3).

---

### Task 1: Regras do Firestore e do Storage

**Files:**
- Modify: `firestore.rules` (funções `validContentType`, `validNewFile`, `validNewLink`, `curatorOrganizes`, `authorResubmits`, `match /teaching_items`, novo `match /teaching_tags`)
- Modify: `storage.rules` (`allowedContentType`)
- Test: `rules-tests/library.firestore.rules.test.ts`, `rules-tests/storage.rules.test.ts`

**Interfaces:**
- Produces (campos do item que o resto do plano usa): `typeTags: string[]`, `subjectTags: string[]`, `ageTags: string[]` (1 a 10 itens cada), `searchTokens: string[]` (até 200), `publishedAt` (só Function). `teaching_tags/{id}` legível por `canUseTeaching()`, sem escrita do cliente.

- [ ] **Step 1: Escrever os testes que falham** em `library.firestore.rules.test.ts`, reutilizando os helpers de contexto/semente do arquivo (o payload válido de arquivo/link existente passa a incluir `typeTags:["tipo-artigos"]`, `subjectTags:["assunto-trindade"]`, `ageTags:["faixa-ump"]`, `searchTokens:["tr","tri"]`). Nomes e asserções:
  - `"professor cria arquivo com uma tag de cada tipo"` → `assertSucceeds`; `"nega criar arquivo sem tag de tipo"`, `"…sem tag de assunto"`, `"…sem tag de faixa"` (array vazio em cada) → `assertFails`; `"nega mais de 10 tags num tipo"`; `"nega searchTokens com mais de 200 itens"`.
  - `"aceita qualquer content type"`: `application/zip` → sucesso; `contentType: ""` → falha.
  - `"curador edita só as tags de item publicado"`: `update` com `{typeTags, subjectTags, ageTags, updatedBy, updatedAt}` → sucesso; `"professor não edita tags"` → falha; `"curador não altera tags junto com status"` → falha; `"curador não esvazia um tipo de tag"` → falha.
  - `"curador renomeia atualizando searchTokens"` → sucesso (`name`, `searchTokens`, `updatedBy`, `updatedAt`).
  - `"autor reenvia item devolvido trocando as tags"` → sucesso; `"reenvio com tag de tipo vazia"` → falha.
  - `teaching_tags`: `"professor lê tags"` → sucesso; `"ninguém grava tags"` (professor, curador e admin) → falha.
  - Em `storage.rules.test.ts`: `"aceita application/zip até 100 MB"` → sucesso; `"nega objeto acima de 100 MB"` → falha (já existente: manter).

- [ ] **Step 2: Rodar e ver falhar:** `npm --prefix rules-tests test` → os novos testes FALHAM (o conjunto antigo de content types e a falta de campos de tag).

- [ ] **Step 3: Implementar as regras.**
  - `validContentType(ct)`: `ct is string && ct.size() >= 1 && ct.size() <= 255`. `storage.rules`: `allowedContentType()` passa a `return true;` (manter `resource == null` e o limite de 100 MB).
  - Nova `validTags(d)`: os três arrays são `list` com `size()` entre 1 e 10, e `d.searchTokens is list && d.searchTokens.size() <= 200`.
  - `validNewFile` e `validNewLink`: acrescentar `'typeTags','subjectTags','ageTags','searchTokens'` ao `hasOnly` **e** ao `hasAll`, e exigir `validTags(data)`. `validNewFolder` não muda.
  - `curatorOrganizes`: `changedKeys().hasOnly(['name','parentId','searchTokens','updatedBy','updatedAt'])`.
  - Nova `curatorEditsTags()`: `isCurator() && changedKeys().hasOnly(['typeTags','subjectTags','ageTags','updatedBy','updatedAt']) && validTags(request.resource.data)`; incluir no `allow update` do item.
  - `authorResubmits`: acrescentar `typeTags, subjectTags, ageTags, searchTokens` à lista de `hasOnly` e exigir `validTags(request.resource.data)`.
  - `match /teaching_tags/{tagId} { allow read: if canUseTeaching(); }` (sem escrita).

- [ ] **Step 4: Rodar e ver passar:** `npm --prefix rules-tests test` → todos os testes (antigos ajustados + novos) PASSAM.

- [ ] **Step 5: Commit:** `git add firestore.rules storage.rules rules-tests` e commit `feat(rules): tags obrigatórias, qualquer tipo de arquivo e edição de tags pelo curador`.

---

### Task 2: Cloud Functions — `publishedAt` e aviso de edição de tags

**Files:**
- Modify: `functions/src/teaching/library/types.ts`, `convert.ts`, `adapterDb.ts`, `processVote.ts`, `processItemChange.ts`, `messages.ts`
- Test: os `*.test.ts` vizinhos de cada um (siga o arquivo de teste existente de `processVote` e `processItemChange`)

**Interfaces:**
- Produces: `ItemDoc.typeTags?/subjectTags?/ageTags?: string[]`; `ItemPatch.publishedAt?: true` (o adaptador grava `FieldValue.serverTimestamp()`); `ChangeOutcome` ganha `"tags_edited"`; notificação ao autor com `type: "tags_edited"`.

- [ ] **Step 1: Testes que falham.**
  - `processVote.test.ts` — `"ao publicar, grava publishedAt"`: o `updateItem` da decisão `publish` recebe `{status:"published", returnComment:null, returnedBy:null, publishedAt:true}`; `"devolver e rejeitar não gravam publishedAt"`.
  - `adapterDb` (teste existente do adaptador, ou novo `adapterDb.test.ts` com Firestore fake): `toWrite({publishedAt:true})` devolve `publishedAt` como sentinela de server timestamp (não o booleano).
  - `processItemChange.test.ts` — `"edição de tags por curador notifica o autor e audita"`: `before.typeTags=["a"]`, `after.typeTags=["a","b"]`, `after.updatedBy="curador1"` ≠ autor → resultado `"tags_edited"`, uma notificação para o autor com `type:"tags_edited"` e id determinístico (mesma convenção de `idStamp` dos outros ramos), e um registro de auditoria `"editar tags"`; `"sem mudança de tags não faz nada"`; `"autor editando as próprias tags (reenvio) não dispara tags_edited"`; `"mudança só de ordem dos ids não dispara"` (comparar como conjuntos).

- [ ] **Step 2: Rodar e ver falhar:** `npm --prefix functions test`.

- [ ] **Step 3: Implementar.** `convert.ts toItem` lê os três arrays (default `[]`); `processVote.ts` acrescenta `publishedAt: true` só no ramo `publish`; `adapterDb.ts toWrite` converte `publishedAt` em `admin.firestore.FieldValue.serverTimestamp()`; `messages.ts` ganha o texto `tagsEdited(item)` no formato dos demais builders (pt-BR, ex.: "As tags de "<nome>" foram ajustadas na revisão."); `processItemChange.ts` ganha um ramo "tags alteradas" avaliado antes de "nada a fazer", que só age se o conjunto de tags mudou **e** `after.updatedBy !== after.authorId`. Não mexa nos ramos existentes.

- [ ] **Step 4: Rodar e ver passar:** `npm --prefix functions test`, `npm --prefix functions run lint`, `npm --prefix functions run build` → verdes.

- [ ] **Step 5: Commit** `feat(functions): publishedAt na publicação e aviso de edição de tags`.

---

### Task 3: Tags no portal (semente, leitura e componentes)

**Files:**
- Create: `functions/src/teaching/tagSeed.ts`, `functions/scripts/seed-teaching-tags.ts`; `web-portal/src/modules/teaching/library/tags.ts`, `tagsRepository.ts`, `useTags.ts`, `ui/TagChips.tsx`, `ui/TagPicker.tsx`
- Modify: `functions/package.json` (scripts `seed-tags`, `seed-tags:dry`, no padrão de `backfill-claims`)
- Test: `functions/src/teaching/tagSeed.test.ts`, `web-portal/src/modules/teaching/library/tags.test.ts`, `ui/TagPicker.test.tsx`, `ui/TagChips.test.tsx`

**Interfaces:**
- Produces (`tags.ts`): 
  `type TagKind = "type" | "subject" | "age"`; `interface Tag {id: string; kind: TagKind; name: string; order: number; active: boolean}`; `interface ItemTags {typeTags: string[]; subjectTags: string[]; ageTags: string[]}`; `const EMPTY_TAGS: ItemTags`; `const TAG_FIELD: Record<TagKind, keyof ItemTags>` (`type→typeTags`, `subject→subjectTags`, `age→ageTags`); `const TAG_KIND_LABEL: Record<TagKind,string>` (`Tipo`, `Assunto`, `Faixa`); `function validateTags(tags: ItemTags): string | null` (primeira falta: "Escolha pelo menos uma tag de tipo." / "… de assunto." / "… de faixa."); `function tagName(byId: Map<string, Tag>, id: string): string` (nome, ou `"Tag removida"` se ausente/inativa e ausente do mapa).
- Produces (`tagsRepository.ts`): `loadTags(): Promise<Tag[]>` (lê `teaching_tags` inteira, ordena por `kind` e `order`).
- Produces (`useTags.ts`): `useTags(): {tags: Tag[] | null; error: string | null; byId: Map<string, Tag>; active(kind: TagKind): Tag[]}` com cache em memória de módulo (uma leitura por sessão).
- Produces: `<TagChips ids byId />`; `<TagPicker tags value onChange error? />` (três grupos "Tipo", "Assunto", "Faixa" com caixas de seleção só das tags ativas; mostra `error` em `role="alert"`).
- `ItemTags` é consumido por Tasks 4–8; a Task 4 reexporta de `types.ts`.

- [ ] **Step 1: Testes que falham.**
  - `tagSeed.test.ts`: `TAG_SEED` tem 6 de `type`, 25 de `subject` e 7 de `age`; ids únicos e no formato `^(tipo|assunto|faixa)-[a-z0-9-]+$`; `order` de cada tipo é 1..n sem buracos; nomes de `age` são exatamente `["UCP","UPA","UMP","ADULTOS","CASAIS","SAF","HOMENS"]` nessa ordem; nomes de `type` e `subject` iguais à spec 4.2.
  - `tags.test.ts`: `validateTags` retorna a mensagem do primeiro tipo vazio (assertar as três) e `null` com um de cada; `tagName` retorna `"Tag removida"` para id ausente.
  - `TagPicker.test.tsx`: lista só tags ativas, marcar chama `onChange` com o id acrescentado no campo certo (`subjectTags`), desmarcar remove, `error` aparece com `role="alert"`.
  - `TagChips.test.tsx`: mostra os nomes na ordem recebida e `"Tag removida"` para id desconhecido.

- [ ] **Step 2: Rodar e ver falhar:** `npm --prefix functions test` e `npm --prefix web-portal test`.

- [ ] **Step 3: Implementar.** `tagSeed.ts` exporta `TAG_SEED: Array<{id; kind; name; order; active: true}>` com os 38 itens; ids = prefixo + slug do nome (minúsculas, sem acento, hífens). `seed-teaching-tags.ts` segue o padrão de `backfill-teaching-claims.ts` (ADC, `--dry-run` só imprime): cria `teaching_tags/{id}` **somente se não existir** (não sobrescreve edições manuais) e imprime quantos criou/pulou. Componentes usam os componentes de `core/ui` já existentes e tokens do tema (sem cores fixas).

- [ ] **Step 4: Rodar e ver passar:** os dois conjuntos de testes + `npm --prefix web-portal run lint && npm --prefix web-portal run typecheck`.

- [ ] **Step 5: Commit** `feat(teaching): coleção de tags, semente inicial e seletor de tags`.

---

### Task 4: Domínio web — campos de tag, busca por tokens, payloads e envio

**Files:**
- Modify: `web-portal/src/modules/teaching/library/types.ts`, `convert.ts`, `payloads.ts`, `uploadFlow.ts`, `mutations.ts`, `permissions.ts`
- Create: `searchTokens.ts`
- Test: `searchTokens.test.ts`, `payloads.test.ts`, `convert.test.ts`, `uploadFlow.test.ts`, `permissions.test.ts`

**Interfaces:**
- Consumes: `ItemTags`, `validateTags` (Task 3).
- Produces: `LibraryItem` ganha `typeTags: string[]`, `subjectTags: string[]`, `ageTags: string[]`, `searchTokens?: string[]`, `publishedAt?: number` (ms); `toItem` converte (arrays ausentes viram `[]`; `publishedAt` Timestamp→ms).
- Produces (`searchTokens.ts`): `const MAX_TOKEN_LENGTH = 20`; `function searchTokens(text: string): string[]` — normaliza com `normalizeText`, separa em palavras por `/[^\p{L}\p{N}]+/u`, ignora palavras de 1 caractere, e para cada palavra gera todos os prefixos de tamanho 2 até `min(len, 20)`; sem repetições; no máximo 150 tokens; ex.: `searchTokens("Fé")` → `["fe"]`.
- Produces (payloads): `newFilePayload(i: {uid; id; name; fileName; contentType; size; storagePath; tags: ItemTags}, now)` e `newLinkPayload(i: {uid; name; url; description?; tags: ItemTags}, now)` incluem `parentId: null`, os três arrays e `searchTokens: searchTokens(name)`; `renamePayload` inclui `searchTokens: searchTokens(name)`; `editTagsPayload(i: {uid; tags: ItemTags}, now)` → `{typeTags, subjectTags, ageTags, updatedBy, updatedAt}`; `resubmitFilePayload`/`resubmitLinkPayload` aceitam `tags?: ItemTags` e, quando vier `name`, recalculam `searchTokens`.
- Produces (envio): `uploadFileItem`/`resubmitFileItem` recebem `tags: ItemTags` (no envio é obrigatório e validado no estágio `"validate"` com `validateTags`, antes de qualquer upload); `mutations.ts`: `createLink(uid, input)` e `uploadFile(uid, file, {name?, tags, onProgress})` com tags, e nova `editTags(uid: string, id: string, tags: ItemTags): Promise<void>`.
- Produces (`permissions.ts`): `ItemPermissions.canEditTags: boolean` = `viewer.isCurator && !item.deleting`.

- [ ] **Step 1: Testes que falham.**
  - `searchTokens.test.ts`: `searchTokens("Fé")` = `["fe"]`; `searchTokens("A")` = `[]`; acentos e caixa: `searchTokens("Santificação")` contém `"santificacao"` e `"sa"`, e não contém `"santificação"`; palavra de 30 letras gera prefixos só até 20; nunca passa de 150 tokens; sem duplicatas.
  - `payloads.test.ts`: `newFilePayload` tem exatamente as chaves permitidas por `validNewFile` (type, name, parentId:null, authorId, status:"in_review", version:1, updatedBy, createdAt, updatedAt, fileName, contentType, size, storagePath, typeTags, subjectTags, ageTags, searchTokens) e nenhuma `undefined`; `editTagsPayload` tem só as chaves de `curatorEditsTags`; `renamePayload` traz `searchTokens`.
  - `uploadFlow.test.ts`: `"envio sem tag de assunto falha em validate e não envia nada"` (`uploadObject` e `createItem` não chamados); `"reenvio com tags novas inclui tags no payload"`.
  - `convert.test.ts`: item sem campos de tag vira arrays vazios; `publishedAt` vira milissegundos.
  - `permissions.test.ts`: `canEditTags` verdadeiro para curador em item publicado e em revisão, falso para professor, falso com `deleting`.

- [ ] **Step 2: Rodar e ver falhar:** `npm --prefix web-portal test`.

- [ ] **Step 3: Implementar** conforme as interfaces. Reexportar `ItemTags` em `types.ts`. Não remova ainda o código de pastas (Task 9).

- [ ] **Step 4: Rodar e ver passar:** `npm --prefix web-portal test && npm --prefix web-portal run lint && npm --prefix web-portal run typecheck` (os testes de UI existentes que montam `LibraryItem` precisam dos arrays: ajuste-os com uma fábrica de item de teste).

- [ ] **Step 5: Commit** `feat(web-portal): tags e tokens de busca no domínio e nos payloads`.

---

### Task 5: Consulta paginada da Biblioteca

**Files:**
- Create: `web-portal/src/modules/teaching/library/libraryQuery.ts`, `useLibraryPage.ts`, `firestore.indexes.json` (raiz do repositório)
- Modify: `web-portal/src/modules/teaching/library/repository.ts`, `firebase.json` (`"firestore": {"rules": "firestore.rules", "indexes": "firestore.indexes.json"}`)
- Test: `libraryQuery.test.ts`, `useLibraryPage.test.ts`, `indexes.test.ts`

**Interfaces:**
- Consumes: `searchTokens`, `MAX_TOKEN_LENGTH` (Task 4), `normalizeText`.
- Produces (`libraryQuery.ts`):
  `interface LibraryFilters {typeTags: string[]; subjectTags: string[]; ageTags: string[]; text: string}`; `const EMPTY_FILTERS: LibraryFilters`;
  `type ServerFilter = {field: "searchTokens" | "subjectTags" | "typeTags" | "ageTags"; op: "array-contains" | "array-contains-any"; values: string[]} | null`;
  `function planQuery(f: LibraryFilters): {server: ServerFilter; matches(item: LibraryItem): boolean}` — prioridade do filtro de servidor: texto (maior palavra com ≥2 caracteres, cortada em 20, `array-contains` em `searchTokens`) > assunto > tipo > faixa (`array-contains-any`); `matches` reaplica **tudo**: cada palavra do texto aparece (substring, normalizado) em `normalizeText(item.name)`, e cada tipo de tag com seleção tem interseção com o item ("ou" dentro do tipo, "e" entre tipos).
  `interface Batch<C> {items: Array<{item: LibraryItem; cursor: C}>; exhausted: boolean}`; `function collectPage<C>(fetch: (after: C | null, size: number) => Promise<Batch<C>>, matches: (i: LibraryItem) => boolean, after: C | null, pageSize: number): Promise<{items: LibraryItem[]; cursor: C | null; done: boolean}>` — pede lotes de 50, acumula os que casam até `pageSize`, no máximo 10 lotes por chamada; `cursor` é o do **último item devolvido**; `done` só quando o servidor esgotou e não sobrou item casado além da página.
- Produces (`repository.ts`): `type LibraryCursor = QueryDocumentSnapshot<DocumentData>`; `loadLibraryPage(filters: LibraryFilters, after: LibraryCursor | null, pageSize?: number): Promise<{items: LibraryItem[]; cursor: LibraryCursor | null; done: boolean}>` — consulta `where("status","==","published")` + filtro de servidor + `orderBy("publishedAt","desc")` + `startAfter` + `limit(50)`, usando `collectPage`.
- Produces (`useLibraryPage.ts`): `useLibraryPage(filters: LibraryFilters): {items: LibraryItem[]; loading: boolean; error: string | null; done: boolean; loadMore(): void}` — recarrega do zero quando `filters` muda (comparar por valor), ignora respostas de uma consulta anterior (contador de requisição).

- [ ] **Step 1: Testes que falham.**
  - `libraryQuery.test.ts`: `planQuery({text:"Fé ", …})` → server `searchTokens` `array-contains` `["fe"]`; texto + assunto → server continua sendo `searchTokens` e `matches` ainda exige o assunto; só assunto `["a","b"]` → `subjectTags`/`array-contains-any`; só tipo → `typeTags`; só faixa → `ageTags`; nada → `null`; palavra de 1 caractere ("é") é ignorada; palavra de 30 letras vira token de 20; `matches`: tipo "ou" (dois tipos selecionados, item com um deles casa), "e" entre assunto e faixa (item sem a faixa não casa), texto com acento ("santificacao" casa "Santificação").
  - `collectPage`: com `matches` que rejeita 3 de cada 4 itens, enche a página varrendo vários lotes; para após 10 lotes devolvendo parcial com `done:false`; `cursor` é o do último item devolvido (não o do último lote); `done:true` quando `exhausted` e nada sobrou; lote vazio exausto → `{items:[], cursor:null, done:true}`.
  - `useLibraryPage.test.ts` (mock de `../repository`): carrega a 1ª página; `loadMore` acrescenta usando o cursor anterior; mudar filtros zera a lista e ignora resposta atrasada da consulta antiga; erro vira `error` pt-BR ("Não foi possível carregar a biblioteca.").
  - `indexes.test.ts`: lê `../../../../../firestore.indexes.json` (a partir da raiz do repo via `process.cwd()`), confere que há 5 índices de `teaching_items` — `status ASC + publishedAt DESC` e, para cada um de `subjectTags`, `typeTags`, `ageTags`, `searchTokens`: `status ASC + <campo> arrayConfig CONTAINS + publishedAt DESC` — e que `firebase.json` aponta para o arquivo.

- [ ] **Step 2: Rodar e ver falhar:** `npm --prefix web-portal test`.

- [ ] **Step 3: Implementar.** Não use índice composto além dos cinco; ordenação sempre por `publishedAt` desc. Em `repository.ts` mantenha por ora as funções antigas (removidas na Task 9).

- [ ] **Step 4: Rodar e ver passar:** `npm --prefix web-portal test && npm --prefix web-portal run lint && npm --prefix web-portal run typecheck`.

- [ ] **Step 5: Commit** `feat(web-portal): consulta paginada da biblioteca com filtros por tag e busca`.

### Task 6: Biblioteca — tabela estilo Drive com filtros e busca

**Files:**
- Create: `web-portal/src/modules/teaching/library/ui/LibraryTable.tsx`, `ui/TagFilterBar.tsx`, `ui/LibraryTable.test.tsx`, `ui/TagFilterBar.test.tsx`
- Modify (reescrever): `ui/LibraryPage.tsx` e `ui/LibraryPage.test.tsx`; `url.ts` (+ `url.test.ts`)
- Rota: `web-portal/src/app/(portal)/ensino/biblioteca/page.tsx` continua com `Suspense`.

**Interfaces:**
- Consumes: `useLibraryPage`, `EMPTY_FILTERS` (Task 5); `useTags`, `TagChips`, `tags.ts` (Task 3); `loadUserNames` (repository); `formatDateTime`/`formatBytes` (`labels.ts`; criar `formatBytes(size: number): string` se não existir, com teste: 250 KB → "250 KB", 6 KB, 1,5 MB).
- Produces: `<LibraryTable items byTagId authorNames onOpenFile(id) />` (colunas Nome, Tags, Enviado por, Publicado em, Tamanho; link = ícone de link e `<a href target="_blank" rel="noopener noreferrer">` só para `http(s)`; arquivo = botão que chama `onOpenFile`); `<TagFilterBar tags value onChange text onTextChange />` (menus "Tipo", "Assunto", "Faixa", chips dos filtros ativos com ✕ e campo "Buscar…"); `libraryUrl({item?: string | null})` e `readParams(search)` → `{item: string | null}` (o parâmetro `pasta` deixa de existir; a limpeza das funções de pasta fica na Task 9).
- Comportamento da página: texto de busca com debounce de 300 ms; `?item=<id>` abre a janela da Task 7 (aqui apenas renderizar `<ItemModal>` quando existir; até a Task 7, um stub exportado por `ui/ItemModal.tsx` que a Task 7 substitui); sem botões de envio, sem pastas, sem breadcrumbs.

- [ ] **Step 1: Testes que falham** (mock de `../useLibraryPage`, `../useTags`, `../repository` com `loadUserNames`; Ruling do Plano B: nenhum teste importa o cliente real do Firebase).
  - `LibraryTable.test.tsx`: `"mostra nome, chips de tag, autor, data e tamanho"`; `"clicar num arquivo chama onOpenFile com o id"`; `"link vira âncora com target _blank e rel noopener noreferrer"`; `"link com esquema diferente de http(s) não vira âncora"`; `"tag removida aparece como Tag removida"`.
  - `TagFilterBar.test.tsx`: marcar uma tag chama `onChange` com ela no campo certo; chip ✕ remove; só tags ativas nos menus; digitar chama `onTextChange`.
  - `LibraryPage.test.tsx`: `"lista só o que o hook devolve (sem itens em revisão por construção da consulta)"`; `"filtro marcado passa filters ao hook"`; `"busca só chega ao hook após 300 ms"` (fake timers); `"mostra Carregar mais enquanto done=false e chama loadMore"`; `"zero itens mostra Nenhum arquivo encontrado."`; `"erro mostra alerta"`; `"não há botões Nova pasta, Enviar arquivo nem breadcrumbs"`; `"?item=ID renderiza a janela do item"`.
  - `url.test.ts`: `libraryUrl({item:"a"})` = `"/ensino/biblioteca?item=a"`, `libraryUrl({})` = `"/ensino/biblioteca"`; `readParams` ignora `pasta`.

- [ ] **Step 2: Rodar e ver falhar:** `npm --prefix web-portal test`.

- [ ] **Step 3: Implementar** os componentes e a página. Autores: coletar `authorId` distintos da lista e chamar `loadUserNames` só para os ainda desconhecidos (cache no estado da página).

- [ ] **Step 4: Rodar e ver passar:** testes, lint, typecheck e `npm --prefix web-portal run build` (a rota `/ensino/biblioteca` continua listada).

- [ ] **Step 5: Commit** `feat(web-portal): biblioteca em tabela com filtros por tag, busca e paginação`.

---

### Task 7: Janela de visualização (modal) e CORS do bucket

**Files:**
- Create: `web-portal/src/modules/teaching/library/ui/PreviewPane.tsx`, `ui/FileInfo.tsx`, `pdfRender.ts`, `docxRender.ts`, `useFileBytes.ts`, `storage-cors.json` (raiz do repositório); testes `ui/PreviewPane.test.tsx`, `docxRender.test.ts`, `preview.test.ts`
- Modify: `preview.ts`, `storageAccess.ts`, `ui/ItemModal.tsx` (substitui o stub), `ui/ItemDetail.tsx` (+ `ItemDetail.test.tsx`), `ui/Dialog.tsx` (variante larga), `web-portal/package.json` (dependências)
- Dependências: `pdfjs-dist` e `docx-preview`. Antes de instalar, consulte `npm view <pacote> version` e **fixe a versão exata** (sem `^`) de uma versão publicada há pelo menos duas semanas; registre as versões no relatório.

**Interfaces:**
- Produces (`preview.ts`): `previewKind(contentType: string | undefined, fileName?: string): "pdf" | "image" | "docx" | "other"` — `docx` para `application/vnd.openxmlformats-officedocument.wordprocessingml.document` ou nome terminando em `.docx` (sem diferenciar caixa); `.doc` e demais → `"other"`; `const MAX_INLINE_PREVIEW_BYTES = 50 * 1024 * 1024`.
- Produces (`storageAccess.ts`): `fileBytes(storagePath: string): Promise<ArrayBuffer>` (`getBytes` do `firebase/storage`).
- Produces (`useFileBytes.ts`): `useFileBytes(storagePath: string | undefined, enabled: boolean): {bytes: ArrayBuffer | null; loading: boolean; error: string | null}`.
- Produces (`pdfRender.ts`): `renderPdf(container: HTMLElement, bytes: ArrayBuffer): Promise<() => void>` (importa `pdfjs-dist` dinamicamente, desenha uma `<canvas>` por página na largura do container, devolve função de limpeza). `docxRender.ts`: `renderDocx(container: HTMLElement, bytes: ArrayBuffer): Promise<() => void>` (import dinâmico de `docx-preview`) e `sanitizeDocxLinks(container: HTMLElement): void` (remove o `href` de qualquer `<a>` cujo esquema não seja `http:`, `https:` ou `mailto:` e põe `target="_blank" rel="noopener noreferrer"` nos demais).
- Produces: `<PreviewPane item />` — `pdf`/`docx`/`image` (imagem por `URL.createObjectURL`, revogada na limpeza) com estado "Carregando visualização…"; `other`, arquivo acima de `MAX_INLINE_PREVIEW_BYTES` ou erro → `<FileInfo>` (nome, tipo, tamanho com `formatBytes`, botão "Baixar" que usa `downloadUrl`); no erro mostra antes "Não foi possível exibir o arquivo. Baixe para abri-lo."; para `type: "link"` não renderiza pré-visualização. `<ItemModal itemId viewer onClose />` = `Dialog` largo com o `ItemDetail` modificado para embutir `<PreviewPane>` no lugar do bloco de visualização antigo, mostrar `TagChips` e o autor; fecha com Esc e clique fora; item inexistente/sem acesso mostra `ITEM_ACCESS_ERROR`.
- `storage-cors.json`: `[{"origin":["https://ipe-ensino.vercel.app","http://localhost:3000"],"method":["GET"],"maxAgeSeconds":3600}]` (aplicado só na Task 10, com autorização).

- [ ] **Step 1: Testes que falham.**
  - `preview.test.ts`: tipo pdf, imagens, docx por content type, docx por nome `RELATORIO.DOCX` com tipo vazio, `.doc` → `other`, `application/zip` → `other`.
  - `docxRender.test.ts`: `sanitizeDocxLinks` num container com `<a href="javascript:alert(1)">`, `<a href="https://x.org">`, `<a href="mailto:a@b.c">` e `<a href="data:text/html,x">` → as âncoras `javascript:` e `data:` perdem o `href`; as `https:` e `mailto:` mantêm o `href` e ganham `target="_blank"` e `rel="noopener noreferrer"`.
  - `PreviewPane.test.tsx` (mock de `useFileBytes`, `pdfRender`, `docxRender`, `storageAccess.downloadUrl`): pdf chama `renderPdf` com o container; docx chama `renderDocx`; imagem renderiza `<img>` com blob URL e revoga ao desmontar; `.zip` mostra nome, tipo, tamanho e "Baixar" sem chamar `useFileBytes` habilitado; arquivo de 60 MB mostra `FileInfo` sem baixar bytes; erro de `renderPdf` (rejeição) mostra "Não foi possível exibir o arquivo" e mantém o botão "Baixar"; item `link` não renderiza pré-visualização.
  - `ItemDetail.test.tsx` (ajustar): mostra chips de tag, autor, `PreviewPane`; curador em item em revisão continua vendo as ações de voto.
  - `ItemModal`: fecha com Escape e clique no fundo; mostra erro de acesso.

- [ ] **Step 2: Rodar e ver falhar:** `npm --prefix web-portal test`.

- [ ] **Step 3: Implementar.** Worker do pdf.js: `pdfjs.GlobalWorkerOptions.workerSrc = new URL("pdfjs-dist/build/pdf.worker.min.mjs", import.meta.url).toString()` (ajuste ao empacotador do Next 16 se necessário e registre). Ambas as bibliotecas só no navegador, via `import()` dentro das funções (nada no bundle inicial). Sem `dangerouslySetInnerHTML`.

- [ ] **Step 4: Rodar e ver passar:** testes, lint, typecheck, `npm --prefix web-portal run build`. Conferir manualmente no navegador local (`npm --prefix web-portal run dev`) com um PDF e um DOCX reais **se houver bucket acessível**; sem CORS aplicado a leitura falhará: registre isso no relatório (a Task 10 aplica o CORS).

- [ ] **Step 5: Commit** `feat(web-portal): janela de visualização com PDF, imagens e DOCX no navegador`.

---

### Task 8: Fila de Revisão — envio com tags, meus envios e revisão

**Files:**
- Modify (reescrever): `ui/ReviewQueuePage.tsx` + `ui/ReviewQueuePage.test.tsx`; `ui/UploadPanel.tsx` + teste; `ui/Dialogs.tsx` (`LinkDialog` com tags; novo `TagEditDialog`; diálogo de reenvio com tags) + teste; `ui/ItemDetail.tsx` (botão "Editar tags"); `repository.ts` (+ `subscribeReviewQueue`); `web-portal/src/modules/teaching/module.ts` (item "Fila de revisão" com `access: "teacher"`); `ui/NotificationsPage.tsx` (link para `libraryUrl({item})` já existente: conferir)
- Test: arquivos acima.

**Interfaces:**
- Consumes: `ItemTags`, `validateTags`, `TagPicker`, `useTags` (Task 3); `uploadFile`, `createLink`, `editTags`, `resubmit*` (Task 4); `ItemModal` (Task 7).
- Produces (`repository.ts`): `interface ReviewQueue {mine: LibraryItem[]; toReview: LibraryItem[]; deleteRequests: LibraryItem[]}`; `subscribeReviewQueue(viewer: Viewer, onData: (q: ReviewQueue) => void, onError: (e: Error) => void): () => void` — professor: `authorId == uid` e `status in ["in_review","returned"]` (só `mine`); curador/admin: o mesmo para `mine` **mais** `status == "in_review"` (descarta os do próprio viewer; vira `toReview`) **mais** `deleteRequested == true` (`deleteRequests`); primeiro erro é terminal; sem índice composto novo.
- Página: seções "Enviar material" (todos: `UploadPanel` + botão "Adicionar link"), "Meus envios", "Para revisar" (só curador/admin), "Pedidos de exclusão" (só curador/admin); cada linha mostra nome, tags, selo de status (devolvido mostra o comentário), e abre `?item=<id>` na janela da Task 7. Aprovado some da fila (a consulta já não o traz).
- `UploadPanel`: um `TagPicker` único para o lote; sem tags completas, mostra o erro de `validateTags` e não envia; envia cada arquivo com as mesmas tags. `LinkDialog`: nome, URL, descrição (limites existentes) + `TagPicker`. `TagEditDialog` (curador, via "Editar tags" no `ItemDetail` quando `canEditTags`): `TagPicker` pré-preenchido, valida e chama `editTags`; reenvio de item devolvido pelo autor também permite trocar tags.

- [ ] **Step 1: Testes que falham** (mocks de `../repository`, `../mutations`, `../useTags`, sem importar o Firebase real).
  - `ReviewQueuePage.test.tsx`: `"professor vê só Meus envios e o formulário de envio"` (sem "Para revisar" nem "Pedidos de exclusão"); `"curador vê Meus envios, Para revisar e Pedidos de exclusão"`; `"item devolvido mostra o comentário de devolução"`; `"clicar numa linha abre ?item=ID"`; `"fila vazia mostra mensagem por seção"`; `"primeiro erro da assinatura vira alerta e é terminal"`.
  - `repository` (teste com `firebase/firestore` mockado no padrão dos testes existentes de repositório, se houver; senão cobrir via a página): professor não dispara a consulta de `toReview`.
  - `UploadPanel.test.tsx`: `"sem tag de faixa mostra erro e não chama uploadFile"`; `"com as três tags envia cada arquivo com as tags"`; `"erro de UploadError aparece com a mensagem"`.
  - `Dialogs.test.tsx`: `LinkDialog` não envia sem tags e envia com `tags`; `TagEditDialog` chama `editTags(uid, id, tags)` e não deixa esvaziar um tipo.
  - `ItemDetail.test.tsx`: "Editar tags" só para curador (`canEditTags`); abre o diálogo.
  - `module.test`/`module.ts`: a Fila de revisão está disponível para `teacher`.

- [ ] **Step 2: Rodar e ver falhar:** `npm --prefix web-portal test`.

- [ ] **Step 3: Implementar.** A rota `/ensino/revisao` continua; `CuratorWarning` e o sino de notificações continuam na Fila/Biblioteca como hoje (mover o sino para a Fila se a Biblioteca deixar de usá-lo, sem perder o teste).

- [ ] **Step 4: Rodar e ver passar:** testes, lint, typecheck, build.

- [ ] **Step 5: Commit** `feat(web-portal): fila de revisão com envio por tags, meus envios e edição de tags`.

---

### Task 9: Limpeza do código de pastas, README e script de limpeza dos dados antigos

**Files:**
- Delete (se nada mais os importar): `ui/FolderView.tsx`, `ui/Breadcrumbs.tsx`, `ui/ItemRow.tsx`, `tree.ts`(+teste), `merge.ts`(+teste), e o que ficar sem uso entre `useLibrary.ts` (`useFolderItems`, `useCatalog`, `NO_VIEWER` só se ninguém usar), `repository.ts` (`subscribeFolder`, `loadAllVisible`, `loadReviewQueue`), `mutations.ts` (`createFolder`, `moveItem`), `payloads.ts` (`newFolderPayload`, `movePayload`), `permissions.ts` (`canMove`, `canCreateFolder`), `Dialogs.tsx` (`PromptDialog`/`MoveDialog` sem uso)
- Modify: `web-portal/README.md` (seção "Biblioteca e curadoria" reescrita: tags, Biblioteca vs Fila de Revisão, visualização, scripts de semente/limpeza, índices e CORS)
- Create: `functions/scripts/purge-teaching-library.ts` e script npm `purge-library`, `purge-library:dry`

**Interfaces:**
- `purge-teaching-library.ts`: por padrão (**sem** `--execute`) só conta e imprime `teaching_items`, subcoleções `votes`, `teaching_notifications` e objetos em `teaching/materials/`; com `--execute` apaga esses três grupos (mantém `teaching_log`). Mesmo padrão de ADC dos demais scripts. Nunca roda sozinho; a Task 10 só o executa com autorização.

- [ ] **Step 1: Verificar o que está sem uso:** `grep -rn` de cada símbolo acima em `web-portal/src` (os testes antigos desses símbolos devem ser removidos junto). Nada que ainda seja importado por código vivo pode ser apagado.

- [ ] **Step 2: Remover e ajustar** os arquivos/funções sem uso e seus testes; ajustar `permissions.test.ts`, `payloads.test.ts` e demais testes que referenciavam pastas/mover.

- [ ] **Step 3: Escrever o script de limpeza e o README.** Teste do script: extrair a contagem para uma função pura `describePurge(counts): string` e testá-la (`functions/scripts/purge-teaching-library.test.ts` ou junto aos testes existentes de scripts).

- [ ] **Step 4: Rodar tudo:** `npm --prefix web-portal test && npm --prefix web-portal run lint && npm --prefix web-portal run typecheck && npm --prefix web-portal run build`, `npm --prefix functions test && npm --prefix functions run lint && npm --prefix functions run build`, `npm --prefix rules-tests test`. Todos verdes; informe as contagens de testes.

- [ ] **Step 5: Commit** `refactor(web-portal): remove o código de pastas; docs e script de limpeza da biblioteca antiga`.

---

### Task 10: Entrega e verificação com o usuário (não é dispatchada a subagente)

Cada passo exige autorização do usuário no momento; registrar o resultado de cada um.

- [ ] **Step 1:** Abrir o PR da branch `teaching-library-tags` para `master` (não faz deploy por si; o merge faz o deploy do portal na Vercel).
- [ ] **Step 2 (antes do merge):** `firebase deploy --only firestore:indexes` e aguardar os índices ficarem prontos; depois `firebase deploy --only firestore:rules` e `--only storage`; depois `firebase deploy --only functions:onTeachingVoteCreated,functions:onTeachingItemCreated,functions:onTeachingItemUpdated --force`. Ordem: índices → regras → Functions.
- [ ] **Step 3:** Aplicar o CORS do bucket: `gcloud storage buckets update gs://app-ipe.firebasestorage.app --cors-file=storage-cors.json`.
- [ ] **Step 4:** `npm --prefix functions run seed-tags:dry` e, aprovado, `npm --prefix functions run seed-tags` (38 tags).
- [ ] **Step 5:** Mergear o PR (deploy do portal). Depois `purge-library:dry`, mostrar as contagens ao usuário e só então `purge-library` com `--execute` (a biblioteca antiga é descartada por decisão do usuário).
- [ ] **Step 6 (ponta a ponta, com ≥3 curadores reais):** professor envia PDF e DOCX com as três tags e um link; vê só os seus na Fila; 2 curadores revisam, um deles corrige uma tag (autor recebe notificação, aprovações não zeram); item aprovado aparece na Biblioteca (com o autor) e some da Fila; filtros por tipo/assunto/faixa e busca com acento funcionam; paginação com "Carregar mais"; janela abre PDF, DOCX e imagem e mostra só informações para um `.zip`; link abre em nova aba; devolver e reenviar funciona.

