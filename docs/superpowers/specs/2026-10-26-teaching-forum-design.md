# Fórum de professores — design (v1)

Data: 2026-10-26. Projeto 2 da ordem combinada (Plano pedagógico → **Fórum** → Biblioteca no app).
Entrega em duas etapas: **Etapa 1 = portal web (+ backend)**, **Etapa 2 = app Flutter**. Esta spec cobre as duas; o plano da Etapa 1 vem primeiro.

## 1. Intenção

Os professores da IPE hoje conversam sobre aulas e dúvidas em grupos de mensagens, onde o assunto se perde. O Fórum é um espaço **clássico de internet** (não é chat): alguém abre um **tópico** com título e mensagem/dúvida; os outros respondem com **comentários**, e cada comentário pode receber **respostas** (aninhadas). Comentários têm 👍/👎. O acervo fica organizado e pesquisável.

Público: usuários que já existem no app (mesmo login). Hoje só `teacher`, `curator` e admin (mesma regra `canUseTeaching` do resto do Portal de Ensino). **No futuro, talvez todos os membros**: o controle de acesso deve ficar concentrado em um ponto (regra `canUseForum()` nas regras e `forumAccess` no módulo web) para ampliar sem refatorar.

## 2. Objetivos / não objetivos

Objetivos (v1): tópicos; comentários aninhados; 👍/👎; editar/apagar o próprio; moderação por curador/admin (apagar, trancar, fixar); assuntos opcionais nos tópicos (tags da Biblioteca); busca por título; citar documento PUBLICADO da Biblioteca ou aula do Plano; sino no portal + push no app quando respondem ao seu conteúdo.

Fora da v1 (decidido): denúncia/fila de moderação; upload de imagem/arquivo; menções `@`; faixa etária como filtro; membros em geral; tempo real (a tela carrega ao abrir e atualiza após o usuário agir); 👍/👎 em tópicos (só comentários — **palpite meu**, o usuário descreveu like só em comentários).

Anti-objetivos: virar chat; exigir categoria; notificar todos a cada tópico novo (spam).

## 3. Decisões do usuário

- Fórum clássico: tópico (título + mensagem) → comentários → respostas aninhadas, com 👍/👎 nos comentários.
- Moderação: o autor edita e apaga o que escreveu; curador e admin apagam qualquer coisa, **trancam** e **fixam** tópicos. Sem denúncia na v1.
- Notificações: sino no portal + push no app, **só** quando respondem ao SEU tópico ou comentário; tópico novo sem push; desligável nas preferências do app.
- Tópicos: reaproveitar as tags de **assunto** da Biblioteca (`teaching_tags`), **opcionais**. Busca por título.
- Anexos: só texto + links colados, com atalho para citar documento da Biblioteca e aula do Plano. **Selecionar um documento já PUBLICADO da Biblioteca é o mais importante.** Sem upload.
- Web primeiro, app depois.
- Escopo da lista: filtro por assunto + busca por título; ordenada por atividade recente; fixados no topo; comentários aninhados até 3 níveis.

## 4. Decisões minhas (marcadas, o usuário não decidiu)

- 1 voto por pessoa por comentário, trocável e removível; só o saldo (👍 − 👎) é exibido; não se vota no próprio comentário.
- Apagar = **remoção lógica**: o item vira "[removido]" e as respostas continuam visíveis. Não há exclusão física pelo cliente.
- Texto puro (sem HTML/Markdown) com quebras de linha; URLs são exibidas como links clicáveis (`rel="noopener noreferrer"`, nova aba).
- Limites: título 3–120 caracteres; mensagem de tópico e comentário 1–5000; até 3 assuntos por tópico; até 3 citações (documento/aula) por tópico ou comentário.
- Comentário editado mostra "(editado)"; editar não notifica de novo.
- Tópico trancado: ninguém comenta nem vota (editar o próprio e moderar continuam).
- Curador/admin também edita só o que escreveu (moderação = apagar/trancar/fixar, não reescrever alheio).

## 5. Modelo de dados (Firestore)

```
forum_topics/{topicId}
  title, body, authorUid, authorName          (nome copiado na criação)
  tagIds: string[]                            (opcional, ≤3, ids de teaching_tags de tipo assunto)
  refs: Ref[]                                 (≤3)
  searchTokens: string[]                      (prefixos do título, mesma função de searchTokens da Biblioteca)
  pinned: bool, locked: bool, deleted: bool
  createdAt, updatedAt, editedAt?             (timestamps)
  lastActivityAt                              (Function atualiza ao comentar; = createdAt no início)
  commentCount                                (Function; conta comentários não removidos)

forum_topics/{topicId}/comments/{commentId}
  body, authorUid, authorName
  parentId: string|null, depth: 1|2|3         (depth = depth do pai + 1)
  refs: Ref[]
  score: number                               (Function; saldo de votos)
  deleted: bool
  createdAt, editedAt?

forum_topics/{topicId}/comments/{commentId}/votes/{uid}
  value: 1 | -1      (remover voto = apagar o documento)

Ref = { kind: "library" | "plan", id: string, label: string }
```

Notificações: reutilizar a coleção `teaching_notifications` (já com regra: dono lê e marca `readAt`; só Functions criam) com `type: "forum_reply"` e campos `topicId`, `commentId` (e `itemId` vazio). **Ponto de coordenação:** a página `/ensino/notificacoes` hoje renderiza notificações da Biblioteca; é preciso que ela trate o tipo `forum_reply` (rótulo + link para `/ensino/forum/<topicId>#<commentId>`). Esse arquivo pode estar em redesenho pela sessão de UX/UI: mudança mínima, após o merge dela.

Preferência de push: nova chave `teaching_forum` em `users.disabled_notifications` (a Biblioteca usa `teaching_review`). Push com `data: {type: "teaching_forum", topicId, url}` (url = `https://ipe-ensino.vercel.app/ensino/forum/<topicId>`; no app, tocar abre o portal, como hoje, até o app ter tela própria na Etapa 2).

## 6. Regras do Firestore (somente aditivas)

Padrão do projeto: o cliente escreve só campos permitidos; **Functions decidem** contadores. Nenhuma regra existente é alterada.

- `canUseForum()` = `canUseTeaching()` hoje (ponto único para ampliar depois).
- Tópico: `read` se `canUseForum()`. `create` se `canUseForum()`, `authorUid == uid`, `authorName` string, título/corpo nos limites, `tagIds ≤3`, `refs ≤3`, `pinned == false`, `locked == false`, `deleted == false`, `commentCount == 0`, `createdAt == request.time`, `lastActivityAt == request.time`. `update`: (a) **autor** altera só `title, body, tagIds, refs, searchTokens, updatedAt, editedAt` e `deleted: false→true`, em tópico não removido; (b) **curador/admin** altera só `pinned, locked, deleted`; contadores e `lastActivityAt` nunca pelo cliente. Sem `delete` pelo cliente.
- Comentário: `read` se `canUseForum()`. `create` se `canUseForum()`, tópico existente, não removido e **não trancado** (lido com `get`), `authorUid == uid`, `score == 0`, `deleted == false`, `depth` entre 1 e 3 e coerente com o pai (`parentId == null` ⇒ `depth == 1`; caso contrário o pai existe, não removido, e `depth == pai.depth + 1`). `update`: autor altera só `body, refs, editedAt` e `deleted: false→true`; curador/admin só `deleted: false→true`. `score` só Function. Sem `delete`.
- Voto: `read` do próprio; `create/update` se `canUseForum()`, `{uid}` do documento == `request.auth.uid`, `value in [1,-1]`, tópico não trancado/removido, comentário não removido e `authorUid != uid`; `delete` do próprio voto.
- Testes de regras (emulador, `rules-tests`) cobrindo cada caminho permitido e negado.

## 7. Cloud Functions (`functions/src/teaching/forum/`, v1, us-central1, mesmo estilo da Biblioteca)

Lógica pura testável com portas em memória; gatilhos finos.

- `onForumCommentCreated`: incrementa `commentCount` e atualiza `lastActivityAt` do tópico; notifica (a) o autor do comentário-pai (se `parentId`) ou o autor do tópico (se resposta direta), exceto se for o próprio autor; se pai e tópico têm autores diferentes, notifica só o destinatário imediato (pai). Cria `teaching_notifications` (id determinístico `forum_reply_<commentId>`, idempotente) e envia push respeitando `disabled_notifications`.
- `onForumCommentUpdated`: quando `deleted` vira `true`, decrementa `commentCount`.
- `onForumVoteWritten` (create/update/delete): recalcula `score` do comentário por delta (`after.value − before.value`, ausente = 0) com transação/`FieldValue.increment`; idempotente por evento.
- `searchTokens` do tópico é calculado no **cliente** (como na Biblioteca) e validado em tamanho pelas regras.

## 8. Portal web (Etapa 1)

Módulo novo `web-portal/src/modules/teaching/forum/` (pastas `data/`, `ui/`, lógica pura ao lado dos testes), rotas finas em `src/app/(portal)/ensino/forum/` (`page.tsx` lista; `novo/page.tsx` criar; `[topicId]/page.tsx` tópico). Reutiliza `core/ui` (`Button`, `Card`, `TextField`, `GlassCard`) **sem restilizar**. Texto em português; mobile funciona (portal responsivo).

- **Lista**: tópicos ordenados por `lastActivityAt` (desc), fixados no topo (consulta própria de `pinned == true`); filtro por assunto (`array-contains` em `tagIds`); busca por prefixo de palavra do título (`searchTokens`); paginação por cursor ("carregar mais"); cada linha mostra título, autor, assuntos, nº de comentários, última atividade, selos "Fixado"/"Trancado". Tópicos removidos não aparecem (curador/admin vê "[removido]"? **decisão do builder**).
- **Criar/editar tópico**: título, mensagem, assuntos opcionais (seletor das tags de assunto ativas), citações. 
- **Tópico**: cabeçalho + mensagem; árvore de comentários até profundidade 3 (no nível 3 o botão "Responder" não existe; responder a um nível 3 não é permitido); cada comentário: autor, data, "(editado)", citações, saldo com botões 👍/👎 (voto atual destacado), Responder, Editar/Apagar (autor), Apagar (curador/admin). Curador/admin: Fixar/Trancar no cabeçalho. Tópico trancado mostra aviso e esconde Responder/votos.
- **Citar documento/aula**: seletor com busca. Biblioteca: **só itens `status == "published"`** (reaproveita `libraryQuery`/repositório da Biblioteca em modo leitura, sem editar arquivos dela); Plano: aulas de `teaching_plan`. A citação grava `{kind, id, label}`; renderiza como cartão/link: documento abre a Biblioteca no item (`/ensino/biblioteca?item=<id>`), aula abre `/ensino/plano` (âncora da aula se existir). Se o alvo deixou de existir/publicado, mostra só o rótulo.
- **Sino/notificações**: tratar `forum_reply` na página de notificações existente (ver §5) e contador de não lidas já existente no portal.
- **Menu**: um item "Fórum" em `modules/teaching/module.ts` (acesso `teacher`) — **somente após a sessão UX/UI mergear** suas mudanças nesse arquivo (rebase, adição de 1 linha).
- Atualização: carregamentos únicos + recarregar a lista/árvore após cada ação do usuário (sem `onSnapshot` nesta versão; **decisão minha**).

Testes: Vitest + Testing Library (sem `user-event`; usar `fireEvent`) para lógica pura (montagem da árvore, permissões, limites, tokens) e componentes principais.

## 9. App Flutter (Etapa 2)

Área de ensino no app (hoje inexistente), entrada visível só para professor/curador/admin: lista de tópicos, tópico com árvore, criar tópico/comentário, votar, editar/apagar, moderação do curador, citar (somente leitura da citação), preferência "Fórum" nas notificações, e tocar no push `teaching_forum` abrindo o tópico no app (estender `teaching_notification_url.dart`). Repositório em `lib/src/modules/teaching_forum/{data,models,presentation}`, Provider/ChangeNotifier como o resto. O app só chega aos professores quando o usuário publicar nas lojas. Detalhe de telas fica para uma spec/plano próprios da Etapa 2.

## 10. Operação e publicação

Nada é publicado sem autorização: regras, índices (`firestore.indexes.json` recebe os novos índices sem remover os existentes), Functions (`--force`), merge. Índices esperados: `forum_topics` por `(pinned, lastActivityAt desc)`, por `(tagIds array-contains, lastActivityAt desc)` e por `(searchTokens array-contains, lastActivityAt desc)`; `comments` por `createdAt` (índice simples). O builder confirma e ajusta.

## 11. Deixado ao builder

Nomes de arquivos/funções, estilo visual dentro de `core/ui`, textos exatos dos rótulos em português, estrutura interna das Functions, estratégia de paginação dos comentários (todos de uma vez é aceitável até um limite razoável, ex.: 500 por tópico), se curador/admin enxerga o conteúdo removido.

## 12. Riscos conhecidos

- `users.teaching_role` é gravável pelo próprio usuário (risco já aceito no projeto); o Fórum herda isso.
- O `get` nas regras (tópico/pai) acrescenta leituras cobradas por escrita; volume pequeno, aceitável.
- Contadores por Function podem divergir em falhas; retentativa ligada e operações idempotentes mitigam.
