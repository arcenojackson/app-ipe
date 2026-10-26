# Fórum de professores no app Flutter — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Fórum de professores no app: entrada em Configurações > Plataforma pedagógica, lista/tópico/editor, e toque no push de resposta abrindo o tópico no app.

**Architecture:** Módulo novo `lib/src/modules/teaching_forum/{data,models,presentation}`; lógica pura (permissões, árvore, busca, decisor de toque) testada à parte; repositório Firestore direto, injetado em `main.dart`. Zero mudança de backend, regras ou índices.

**Tech Stack:** Flutter, Provider/ChangeNotifier, cloud_firestore, firebase_auth, url_launcher, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-26-teaching-forum-app-design.md` (inclui §9b, decisões do builder). Referência de comportamento: `web-portal/src/modules/teaching/forum/**` (`convert.ts`, `payloads.ts`, `permissions.ts`, `queries.ts`, `tree.ts`, `repository.ts`, `linkify.ts`) e `web-portal/src/modules/teaching/library/searchTokens.ts`.

## Global Constraints

- Coleções: `forum_topics/{id}` (title, body, authorUid, authorName, tagIds[≤3], refs[≤3 {kind: library|plan, id, label}], searchTokens, pinned, locked, deleted, commentCount, createdAt, updatedAt, editedAt?, lastActivityAt); `.../comments/{cid}` (body, authorUid, authorName, parentId|null, depth 1..3, refs, score, deleted, createdAt, editedAt?); `.../comments/{cid}/votes/{uid}` `{value: 1|-1}`.
- Cliente grava só conteúdo e moderação. **Nunca** escrever `score`, `commentCount`, `lastActivityAt` em edições (na criação, o payload segue `newTopicPayload`/`newCommentPayload` do portal, com `serverTimestamp()` onde o portal usa `TS`).
- Limites: título 3–120 (após trim), mensagem 1–5000, ≤3 assuntos, ≤3 citações, 500 comentários por tópico, 20 tópicos por página.
- Profundidade máx. 3; sem resposta a comentário removido; tópico trancado/removido sem comentário nem voto; sem voto no próprio comentário.
- Visibilidade: `user.teachingRole` ∈ {teacher, curator} e `!user.isPending`. Admin sem papel não vê. Moderação: `teachingRole == curator || user.isAdminUser`.
- Textos em pt_BR, tema escuro com `GlassContainer`, navegação imperativa (`Navigator.push`). Commits com `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Usar `/usr/bin/git`.
- Não fazer push/PR sem autorização do usuário.

## Review Focus

- Documento de tópico/comentário incompleto ou com tipo errado: ignorado, não derruba a tela (`fromMap` devolve `null`).
- Busca com acento, maiúscula, palavra de 1 letra, palavra >20 letras: token = palavra mais longa, sem acento, cortada em 20; vazia = lista normal.
- Toque no push com `topicId` malicioso/vazio, URL de outro host, usuário sem papel, tipo desconhecido: nunca abre algo arbitrário.
- Falha de rede ao enviar comentário/tópico: mantém o texto digitado e mostra erro.
- Dupla toque em enviar / votar: um único envio em andamento.

## Estrutura de arquivos

Criar em `lib/src/modules/teaching_forum/`:
- `models/forum_models.dart` — `ForumRef`, `ForumTopic`, `ForumComment` (+ `fromMap` tolerante).
- `models/forum_logic.dart` — `ForumViewer`, `topicPermissions`, `commentPermissions`, `buildCommentTree`, `validateTopicInput`, `validateCommentInput`, `searchTokens`, `topicQueryFrom`, `linkify`.
- `data/forum_repository.dart` — Firestore.
- `presentation/` — `teaching_home_page.dart`, `forum_list_page.dart`, `forum_topic_page.dart`, `forum_editor_page.dart`, `widgets/*`.
Modificar: `lib/main.dart`, `lib/src/modules/auth/presentation/settings_page.dart`, `lib/src/modules/notifications/{models/notification_type.dart,services/teaching_notification_url.dart,services/notification_service.dart,presentation/notification_settings_page.dart}`.
Testes em `test/modules/teaching_forum/` e `test/modules/notifications/`.

---

### Task 1: Modelos e lógica pura

**Files:** Create `models/forum_models.dart`, `models/forum_logic.dart`; Test `test/modules/teaching_forum/forum_logic_test.dart`.

**Interfaces — Produces:**
- `ForumRef({kind, id, label})`; `ForumTopic` (campos acima; `createdAt/updatedAt/lastActivityAt` como `DateTime`, `editedAt` opcional); `ForumComment` (+ `topicId`).
- `ForumTopic? ForumTopic.fromMap(String id, Map<String, dynamic> data)`, `ForumComment? ForumComment.fromMap(String topicId, String id, Map<String, dynamic> data)` — `null` se faltar title/body/authorUid ou `depth` fora de 1..3; `Timestamp`/`null` tolerados; `refs` inválidas descartadas.
- `class ForumViewer {final String uid; final bool isCurator; final bool isAdmin; bool get isModerator}`.
- `TopicPermissions topicPermissions(ForumTopic t, ForumViewer v)` → `{canEdit, canDelete, canPin, canLock, canComment, visibleBody}`; `CommentPermissions commentPermissions(ForumComment c, ForumTopic t, ForumViewer v)` → `{canReply, canVote, canEdit, canDelete}`. Regras idênticas a `permissions.ts` (testes do portal em `forum.test.ts` são a tabela).
- `List<CommentNode> buildCommentTree(List<ForumComment>)` (aninha por `parentId`, ordena por `createdAt` asc, órfão vai à raiz).
- `String? validateTopicInput({title, body, tagIds, refs})`, `String? validateCommentInput({body, refs})` (mensagens iguais às do portal: "título", "mensagem", "assuntos", "Cite").
- `List<String> searchTokens(String text)` (prefixos 2–20 de cada palavra normalizada sem acento; máx. 150 tokens) e `({String? tagId, String? token, List<String> words}) topicQueryFrom({String? tagId, String? search})` (lança `ArgumentError` se ambos preenchidos; busca em branco = sem filtro).
- `List<LinkSegment> linkify(String text)` (só http/https vira link; pontuação final fica de fora).

- [ ] **Step 1:** Escrever testes portando os casos de `web-portal/src/modules/teaching/forum/forum.test.ts` (converters, validação nos limites exatos, árvore, permissões, linkify, topicQuery: `"A Graça de Deus"` → token `graca`, words `[graca, de, deus]`; 30 `x` → 20 `x`) e de `searchTokens` ("Aula três" contém `au` e `tres`).
- [ ] **Step 2:** `flutter test test/modules/teaching_forum/forum_logic_test.dart` → FAIL (arquivos inexistentes).
- [ ] **Step 3:** Implementar os dois arquivos conforme assinaturas. Normalização: `toLowerCase` + remoção de diacríticos (mapa explícito de acentos pt-BR); separar por `[^\p{L}\p{N}]+` (unicode).
- [ ] **Step 4:** Rodar o teste → PASS; `flutter analyze` limpo.
- [ ] **Step 5:** Commit `feat(forum-app): modelos e lógica pura do Fórum`.

### Task 2: Repositório Firestore

**Files:** Create `data/forum_repository.dart`; Modify `lib/main.dart` (registrar `Provider<ForumRepository>.value(value: ForumRepository())` no `MultiProvider`); Test `test/modules/teaching_forum/forum_repository_payload_test.dart` (só funções puras de payload).

**Interfaces — Produces** (`ForumRepository`, construtor com `FirebaseFirestore? firestore` opcional):
- `Future<List<ForumTopic>> loadPinned({String? tagId, String? token, List<String> words = const []})` — `deleted==false, pinned==true` + filtro, sem `orderBy`; filtra `words` no cliente (`matchesWords`: toda palavra é prefixo de alguma palavra de título normalizado) e ordena por `lastActivityAt` desc.
- `Future<TopicPage> loadPage({tagId, token, words, TopicCursor? after})` — como `loadTopicsPage` do portal: sem filtro adiciona `pinned==false`; ordena `lastActivityAt desc`, `limit(20)`, cursor = último `DocumentSnapshot`; com filtro descarta fixados e faz `matchesWords`; `done = docs.length < 20`.
- `Future<ForumTopic?> loadTopic(String id)`; `Future<List<ForumComment>> loadComments(String topicId)` (`createdAt asc`, limit 500).
- `Future<int?> loadMyVote(topicId, commentId, uid)`; `Future<void> setVote(topicId, commentId, uid, int? value)` (`null` apaga).
- `Future<String> createTopic(input, author)` / `updateTopic(id, input)` / `createComment(topicId, input, author, parent)` / `updateComment(...)` — payloads iguais a `newTopicPayload`, `topicEditPatch` (`title, body, tagIds, refs, searchTokens, updatedAt, editedAt`), `newCommentPayload`, `commentEditPatch` (`body, refs, editedAt`); funções puras `newTopicPayload(...)`, `topicEditPatch(...)` etc. exportadas para teste (aceitam o carimbo de tempo como parâmetro).
- `Future<void> setTopicFlags(id, {bool? pinned, bool? locked, bool? deleted})`, `Future<void> setCommentDeleted(topicId, commentId)`.
- `Future<List<SubjectTag>> loadSubjectTags()` — `teaching_tags` com `kind=="subject"`, `active==true`, `orderBy order`.

- [ ] **Step 1:** Teste de payload: tópico novo tem `pinned/locked/deleted=false`, `commentCount=0`, `searchTokens` do título; `topicEditPatch` só tem as 7 chaves acima; comentário novo calcula `depth` (pai 2 → 3; pai 3 → lança) e `score=0`.
- [ ] **Step 2:** Rodar → FAIL. **Step 3:** Implementar repositório e registrar em `main.dart`. **Step 4:** Teste → PASS; `flutter analyze`.
- [ ] **Step 5:** Commit `feat(forum-app): repositório do Fórum`.

### Task 3: Seção "Plataforma pedagógica" em Configurações

**Files:** Create `presentation/teaching_home_page.dart`, `models/teaching_access.dart` (`bool canUseTeachingForum(UserModel? user)`); Modify `settings_page.dart` (nova seção entre "Integrações" e "Conta", mesmo estilo de `GlassContainer`/`ListTile`); Test `test/modules/teaching_forum/teaching_access_test.dart`, `test/modules/teaching_forum/teaching_home_page_test.dart`.

- [ ] **Step 1:** Testes: `canUseTeachingForum` verdadeiro só para teacher/curator não pendente; falso para admin sem papel, `none`, pendente, `null`. Widget: `TeachingHomePage` mostra o botão "Fórum" e navega para `ForumListPage` (usar repositório falso via `Provider`).
- [ ] **Step 2:** FAIL. **Step 3:** Implementar; na seção usar `if (canUseTeachingForum(user))`, título "Plataforma pedagógica", item `Icons.school_outlined`, subtítulo "Fórum de professores". **Step 4:** PASS + analyze.
- [ ] **Step 5:** Commit `feat(forum-app): seção Plataforma pedagógica em Configurações`.

### Task 4: Lista do Fórum

**Files:** Create `presentation/forum_list_page.dart`, `presentation/forum_list_controller.dart` (`ChangeNotifier`), `presentation/widgets/topic_card.dart`; Test `test/modules/teaching_forum/forum_list_controller_test.dart`.

**Interfaces — Consumes:** `ForumRepository`, `topicQueryFrom`. **Produces:** `ForumListController({repository})` com `load()`, `loadMore()`, `setTagId(String?)`, `setSearch(String)` (assunto e busca exclusivos: definir um limpa o outro), estados `loading/error/done`, listas `pinned` e `topics`.

- [ ] **Step 1:** Teste do controller com repositório falso: carrega fixados + 1ª página; `setSearch` limpa `tagId`; `loadMore` acrescenta e para quando `done`; erro de rede vira `error` com `retry`.
- [ ] **Step 2:** FAIL. **Step 3:** Implementar controller, tela (barra de busca com debounce 400 ms, chips de assuntos, botão "Novo tópico" → Task 6, cartão: título, autor, assuntos, nº de respostas, data, selo Fixado/Trancado) e `topic_card`. **Step 4:** PASS + analyze.
- [ ] **Step 5:** Commit `feat(forum-app): lista de tópicos`.

### Task 5: Tela do tópico (comentários, votos, moderação)

**Files:** Create `presentation/forum_topic_page.dart`, `forum_topic_controller.dart`, `widgets/comment_tile.dart`, `widgets/comment_composer.dart`, `widgets/linkified_text.dart`; Test `test/modules/teaching_forum/forum_topic_controller_test.dart`.

**Interfaces — Produces:** `ForumTopicPage({required String topicId, required ForumViewer viewer})`; `ForumTopicController` com `load()` (tópico + comentários + `loadMyVote` em paralelo; antes, `FirebaseAuth.currentUser?.getIdToken(true)` uma vez), `vote(commentId, int value)` (mesmo valor = remove; atualização otimista do placar local ±; reverte em erro), `submitComment(body, parent)`, `editComment`, `deleteComment`, `togglePin`, `toggleLock`, `deleteTopic`, flag `notFound`.

- [ ] **Step 1:** Testes do controller (repositório falso): voto otimista e reversão em erro; segundo toque no mesmo voto remove; voto bloqueado no próprio comentário/trancado (via `commentPermissions`); `submitComment` mantém texto em erro; `notFound` quando `loadTopic` devolve `null`.
- [ ] **Step 2:** FAIL. **Step 3:** Implementar. Tópico removido: corpo só para quem `visibleBody`. Comentário removido: "Comentário removido". Links via `linkify` com `launchUrl(mode: externalApplication)`. Em `notFound`, ver Task 7 (fallback para navegador). Mensagem "Sem permissão" em `permission-denied`. **Step 4:** PASS + analyze.
- [ ] **Step 5:** Commit `feat(forum-app): tópico, comentários, votos e moderação`.

### Task 6: Criar/editar tópico

**Files:** Create `presentation/forum_editor_page.dart`, `forum_editor_controller.dart`; Test `test/modules/teaching_forum/forum_editor_controller_test.dart`.

**Interfaces:** `ForumEditorPage({ForumTopic? editing, required ForumViewer viewer})`; controller valida com `validateTopicInput`, assuntos de `loadSubjectTags()` (máx. 3), preserva `refs` existentes ao editar (v1 não adiciona citações; exibe as atuais só leitura), envia uma vez (ignora toque duplo), em sucesso retorna o id do tópico.

- [ ] **Step 1:** Testes: título curto/longo e mensagem vazia bloqueiam; 4º assunto recusado; edição preserva `refs`; envio duplo cria um só documento; erro mantém campos.
- [ ] **Step 2:** FAIL. **Step 3:** Implementar. **Step 4:** PASS + analyze.
- [ ] **Step 5:** Commit `feat(forum-app): criar e editar tópico`.

### Task 7: Aviso de resposta abre o tópico no app

**Files:** Modify `teaching_notification_url.dart`, `notification_type.dart`, `notification_service.dart`, `notification_settings_page.dart`; Test `test/modules/notifications/teaching_notification_url_test.dart` (estender).

**Interfaces — Produces** em `teaching_notification_url.dart`:
- `String? teachingForumTopicIdFromData(Map<String, dynamic> data)` — só `type == 'teaching_forum'` e `topicId` casando `^[A-Za-z0-9_-]{1,128}$`.
- `sealed class TeachingTap` com `OpenTopic(String id)`, `OpenBrowser(Uri uri)`, `Ignore()`; `TeachingTap resolveTeachingTap(Map<String, dynamic> data, UserModel? user)`: `teaching_review` → `OpenBrowser` (comportamento atual, URL validada); `teaching_forum` com `topicId` e `canUseTeachingForum(user)` → `OpenTopic`; `teaching_forum` sem papel → `OpenBrowser` se a URL é https do host `ipe-ensino.vercel.app` sem userInfo; senão `Ignore`; outros tipos → `Ignore` (o fluxo antigo continua tratando-os).
- `teachingPortalUriFromData` passa a aceitar também `teaching_forum` (só para o fallback), mantendo as validações.
- `NotificationType.teachingForum('teaching_forum', 'Respostas no Fórum', 'Aviso quando alguém responder ao seu tópico ou comentário')`.

**Modify `notification_service.dart`:** nos três pontos (`_navigateFromNotification`, `_onNotificationTapped`, e `getInitialMessage` que passa por `_navigateFromNotification`) chamar `resolveTeachingTap(data, usuário)`; usuário vem de `Provider.of<AppState>(IpeApp.navigatorKey.currentContext!, listen: false).currentUser`; se o navegador/usuário ainda não estiver pronto, repetir após o atraso de 500 ms já usado. `OpenTopic` → `navigator.push(ForumTopicPage(...))`; `OpenBrowser` → `launchUrl(externalApplication)`; `Ignore` → segue o fluxo existente. Em `ForumTopicPage`, `notFound` aberto pelo push chama `launchUrl` do portal (`https://ipe-ensino.vercel.app/ensino/forum/<id>`) e fecha a tela.

**Modify `notification_settings_page.dart`:** esconder `teachingForum` de quem não tem `canUseTeachingForum`.

- [ ] **Step 1:** Testes de tabela para `resolveTeachingTap`: forum+professor → `OpenTopic`; forum+admin sem papel+URL válida → `OpenBrowser`; forum+`topicId` com `../` ou vazio → não abre tópico; URL `http`, host alheio, userInfo → `Ignore`; review mantém o comportamento dos testes atuais; tipo desconhecido → `Ignore`.
- [ ] **Step 2:** FAIL. **Step 3:** Implementar. **Step 4:** `flutter test` completo + `flutter analyze` → PASS.
- [ ] **Step 5:** Commit `feat(forum-app): push de resposta abre o tópico no app`.

### Task 8: Verificação final

- [ ] `flutter analyze` e `flutter test` limpos; `dart format .` só nos arquivos tocados.
- [ ] Teste manual no simulador iOS (ver "Como testar" abaixo).
- [ ] Atualizar a spec se algo mudou; commit. **Parar:** push/PR e publicação nas lojas só com autorização do usuário.

## Como testar no app

1. Conta A (professor) e B (professor) em dois dispositivos/simuladores.
2. A: Configurações > Plataforma pedagógica > Fórum > Novo tópico. Conferir que um admin sem papel de ensino **não** vê a seção.
3. B: abrir o tópico, comentar; A recebe push; tocar abre o tópico no app; com a conta de admin sem papel, o toque abre o navegador.
4. Votar, trocar, remover; responder até o nível 3; curador fixa/tranca/apaga.
5. Configurações > Notificações: desligar "Respostas no Fórum" e ver que o push não chega mais.

## Decisões que precisam do usuário

Nenhuma bloqueia o plano. Itens de produto já combinados: citações no editor ficam para v2; links do portal no celular (universal links) ficam para depois da decisão de domínio/lojas. A publicação nas lojas é do usuário.
