# Fórum de professores no app Flutter — Design (Etapa 2)

Data: 2026-10-26. Status: spec, sem código. Continua a Etapa 1 (portal web + backend, em produção): `docs/superpowers/specs/2026-10-26-teaching-forum-design.md`.

## 1. Intenção

Professores, curadores e quem coordena o ensino usam o Fórum no celular, com a mesma experiência de fórum clássico do portal: tópico → comentários aninhados → 👍/👎. Sem backend novo: o app usa as mesmas coleções, regras, índices e Functions da Etapa 1.

## 2. Objetivos / Não objetivos

Objetivos: acesso ao Fórum pelo app; avisos de resposta que abrem o tópico no app; opção de desligar o aviso.

Não objetivos (v1 do app): citar Biblioteca/Plano ao escrever (só exibir citações existentes); upload de arquivos; denúncia; Biblioteca no app (outra sessão; a área pedagógica deixa o espaço); mudança de regras, índices ou Functions; restringir admin no servidor/portal.

Anti-objetivo: tornar o app dependente de publicação em loja para o que já funciona no portal.

## 3. Onde fica e quem vê (decidido pelo usuário)

- Sem aba nova. Em **Configurações** (`lib/src/modules/auth/presentation/settings_page.dart`) entra a seção **"Plataforma pedagógica"**, entre "Integrações" e "Conta", com um item que abre a tela `TeachingHomePage` ("Plataforma pedagógica").
- `TeachingHomePage` tem hoje um botão **"Fórum"**; a Biblioteca entra aqui no futuro.
- **Regra de visibilidade:** `user.teachingRole` ∈ {teacher, curator} e usuário não pendente (`!isPending`). `UserModel` já lê `users.teaching_role`. **Admin sem papel de ensino não vê.**
- Efeitos colaterais: (a) admin que precise do Fórum recebe Professor/Curador na lista de pessoas (já existe); (b) é restrição só de interface: regras do Firestore e portal continuam liberando qualquer admin (`hasAdminClaim`) e não serão alteradas. Moderação no Fórum (apagar qualquer coisa, fixar, trancar) vale para curador e, como no servidor, para admin que tenha o papel/claim.
- Decisão do builder (minha): as permissões por conteúdo usam o claim/papel como na web (`permissions.ts`), calculadas num `ForumPermissions` puro em Dart, testável.

## 4. Telas (padrão visual do app: GlassContainer, tema escuro, navegação imperativa)

1. **Lista (`ForumListPage`)**: fixados no topo (consulta separada), depois tópicos por `lastActivityAt` desc, 20 por página por cursor ("carregar mais"). Cada cartão: título, autor, assuntos, nº de respostas, data da última atividade. Filtro por assunto OU busca por título, nunca os dois (uma `array-contains` por consulta). Botão "Novo tópico".
2. **Tópico (`ForumTopicPage`)**: cabeçalho (título, corpo com links tocáveis só http/https, citações, assuntos, selos Fixado/Trancado), árvore de comentários até profundidade 3, 👍/👎 e placar por comentário, responder, editar/apagar o próprio; curador/admin apagam qualquer um, fixam e trancam o tópico. Comentário removido aparece como "Comentário removido"; tópico removido só é visto por autor/moderador.
3. **Criar/editar tópico (`ForumEditorPage`)**: título (3–120), mensagem (1–5000), até 3 assuntos (`teaching_tags`, `kind == subject`, `active`, por `order`). Citações: v1 não adiciona (§2).
4. Respostas: campo de texto na própria tela do tópico (comentário 1–5000, aninhado conforme o botão Responder).

Regras espelhadas da web: máx. profundidade 3; sem resposta a comentário removido; tópico trancado/removido não aceita comentário nem voto; sem voto no próprio comentário; 1 voto por pessoa, trocável ou removível; `searchTokens` do título = prefixos de 2–20 letras sem acento (mesma função da Biblioteca; portar para Dart com teste cruzado contra os casos do portal).

## 5. Reuso do backend e estrutura

Cliente grava só conteúdo e moderação; `score`, `commentCount` e `lastActivityAt` são das Functions (`onForumCommentCreated/Updated`, `onForumVoteWritten`). O app não escreve esses campos. Campos e limites: iguais ao documento da Etapa 1 (§ modelo de dados).

Módulo novo `lib/src/modules/teaching_forum/{data,models,presentation}`:
- `ForumRepository` (Firestore direto, injetado por `Provider.value` no `MultiProvider` raiz, como os demais), `Topic`, `Comment`, `ForumRef` com `fromMap` tolerante (documento incompleto é ignorado, como no `convert.ts`), `forum_permissions.dart`, `forum_tree.dart` (monta árvore, órfão vai à raiz), `forum_search_tokens.dart`.
- Paginação, estado e erros: `ChangeNotifier` por tela (padrão do app). Falha de rede mostra erro com "tentar de novo", sem perder o texto digitado.

## 6. Aviso (push) de resposta

Backend já envia FCM com `data: {type: "teaching_forum", topicId, url: https://ipe-ensino.vercel.app/ensino/forum/<topicId>}`, respeitando `disabled_notifications` contendo `teaching_forum`, e cria o `teaching_notifications` `forum_reply`.

**Quando abre no app (decidido pelo usuário: app primeiro, navegador como queda):**
- Toque no push (app em segundo plano, fechado ou em primeiro plano via notificação local) com `type == teaching_forum`, `topicId` não vazio e **usuário com papel de ensino**: abre `ForumTopicPage(topicId)` dentro do app (por `IpeApp.navigatorKey`, depois do login/bootstrap, igual aos outros tipos).
- Cai no **navegador** (a URL do `data.url`, validada: https, host `ipe-ensino.vercel.app`, sem userInfo) quando: o usuário não tem papel de ensino no app (ex.: admin sem papel); o tópico não existe/foi removido e não é visível; ou `topicId` ausente mas a URL é válida. Sem URL válida nem `topicId`: nada abre.
- `teaching_review` continua abrindo o navegador, sem mudança.

**O que isso exige:**
- `teaching_notification_url.dart`: nova função (ex.: `teachingForumTopicIdFromData`) que valida `type == teaching_forum` e devolve o `topicId` (apenas `[A-Za-z0-9_-]{1,128}`), mais um decisor puro `resolveTeachingTap(data, user)` → `{openTopic(id) | openBrowser(uri) | none}` com testes de tabela. `teachingPortalUriFromData` passa a aceitar também `teaching_forum` só para o fallback.
- `notification_service.dart`: usar o decisor nos três pontos de toque (`getInitialMessage`, `onMessageOpenedApp`, toque na notificação local, cujo payload já é `jsonEncode(message.data)`).
- `NotificationType.teachingForum('teaching_forum', ...)` com título "Respostas no Fórum" e descrição "Aviso quando alguém responder ao seu tópico ou comentário". Aparece em `notification_settings_page.dart` só para quem tem papel de ensino. É a preferência para desligar (usa `disable/enableNotification` existentes, que gravam em `disabled_notifications`).
- **Sem mudança de backend e sem dependência de loja para o toque no push**: o payload já tem `topicId`. Só o app novo (versão que publicarmos) entende; versões antigas continuam abrindo nada/ignorando o tipo, sem quebrar.

**Link do portal aberto no celular (universal/app links): fora desta versão.** Hoje o projeto não tem `associated-domains` (iOS) nem intent-filter de link verificado (Android), e o domínio é da Vercel (`ipe-ensino.vercel.app`), o que exige hospedar `apple-app-site-association` e `assetlinks.json` e publicar nas lojas. Depende da publicação nas lojas e de decisão de domínio; fica como evolução. Nesse caso o link abre no navegador, como hoje.

## 7. Dependência de publicação

Tudo desta spec só chega ao usuário com nova versão do app nas lojas (App Store e Google Play), o que cabe ao usuário. Nada de Functions/regras/índices a publicar. Ordem segura: o backend já está no ar, então o app pode sair a qualquer momento.

## 8. Testes (para o plano)

Unitários: permissões, árvore, tokens de busca (casos cruzados com o portal), decisor de toque do push, visibilidade da seção por papel, conversores tolerantes. Widget: lista (fixados, filtro/busca exclusivos, paginação), tópico (aninhamento até 3, voto, trancado), seção em Configurações por papel. Regras do Firestore já cobertas na Etapa 1 (91 testes); não mudam.

## 9. Fica a critério do builder

Layout fino dos cartões, texto vazio/erro, ordem dos assuntos no seletor, debounce da busca, otimismo de UI no voto (recalcular placar localmente até a Function atualizar). Marcado como decisão do builder, não do usuário.

## 10. Perguntas abertas (nenhuma bloqueia o plano)

- Universal/app links do portal no celular: fazer depois, junto com a publicação nas lojas e decisão de domínio próprio?
- Citar Biblioteca/Plano ao escrever pelo app: v2, junto com a Biblioteca no app.
