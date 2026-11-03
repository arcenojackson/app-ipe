# Votação da eleição dentro do app — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membros da sociedade votam na eleição dentro do app: push + balão ao abrir a eleição, leitura do QR do condutor como check-in, telas de voto em Flutter.

**Architecture:** O servidor continua decidindo tudo (`electionCheckIn`, `electionCastVote`). Um gatilho Firestore (draft → open) grava um convite por membro em `users/{uid}/election_invites/{electionId}` e manda o push. O app lê o próprio convite para o balão, abre a tela de voto (máquina de estados portada de `web-portal/src/modules/elections/voteState.ts`) e faz o check-in pelo QR, com `memberOnly: true`.

**Tech Stack:** Flutter (Provider, `cloud_firestore`, `cloud_functions`, novo `mobile_scanner`), Firebase Functions v1 (TypeScript, vitest), regras do Firestore (`rules-tests/`).

**Spec:** `docs/superpowers/specs/2026-11-02-election-voting-in-app-design.md`

## Global Constraints

- Ambiente de desenvolvimento: emuladores, projeto `demo-ipe`; **nunca produção** (`AGENTS.md`). Siga o playbook do `AGENTS.md` para subir emuladores e rodar testes.
- Texto da interface em português (pt_BR).
- Tipo de notificação: id `election_open`; payload `data: {type: "election_open", electionId}`.
- Caminho do convite: `users/{uid}/election_invites/{electionId}` com `{electionId, title, societyName, createdAt}`; imutável (sem atualização no encerramento).
- Mensagem de recusa de não-membro: `"A votação é só para membros da sociedade."`
- Texto do push: título `"Eleição aberta"`; corpo `"<título da eleição>. Abra o app para votar; se não abrir a votação, atualize o app."`
- QR/link: o app extrai o id **só pelo caminho** `/votar/{id}`, ignorando o host.
- Sem novo parâmetro = comportamento atual da web (convidado pendente) intacto.
- O gatilho de push (`electionOpened`) **só é publicado depois** da nova versão do app estar nas lojas; regras e `electionCheckIn` podem ir antes.
- Commits pequenos por tarefa; não commitar em `main`. Não incluir chaves/segredos.

## Review Focus

1. **Update que não é abertura** (ex.: gravar `openedAt` depois, ou outro campo): não pode reenviar push nem recriar convites. Teste em Task 2.
2. **Membro sem `fcmToken`, sem documento `users/{uid}` ou com `election_open` desativado**; sociedade sem membros: o gatilho não pode quebrar; convite é gravado para todos os membros, push só para quem tem token e não desativou. Teste em Task 2.
3. **QR que não é de votação** (link de condução `/eleicoes/{id}`, texto qualquer, URL sem id, vazio): vira "QR inválido", sem exceção. Teste em Task 4.
4. **Rodada fecha entre mostrar a cédula e confirmar**: o erro do servidor aparece na cédula, o botão volta a habilitar, e a tela reage ao novo estado. Teste em Task 5.
5. **Câmera negada ou inexistente (simulador)**: o campo de código/link continua visível e funcional. Teste em Task 6.

---

### Task 1: Check-in só de membros (`memberOnly`)

**Files:**
- Modify: `functions/src/elections/voters.ts` (função `checkIn`)
- Test: `functions/integration/voters.itest.ts`

**Interfaces:**
- Produces: `checkIn(db, caller, data)` passa a aceitar `data.memberOnly === true`. Com ele, quem não está em `societies/{societyId}.members` recebe `HttpsError("permission-denied", "A votação é só para membros da sociedade.")`, **sem** criar `voters/{uid}` nem `users/{uid}`. Retorno inalterado: `{status, kind}`.

- [ ] **Step 1: Escrever os testes que falham** em `describe("checkIn")` (usar os helpers/constantes existentes; `expectCode` já existe):
  - `memberOnly` + `outsider` → `permission-denied`; depois disso `voterDoc(OUTSIDER)` é `undefined`.
  - `memberOnly` + conta Google nova `google` (sem `users/g1`) → `permission-denied` e `userDoc("g1")` continua `undefined`.
  - `memberOnly` + `outsider` que **já tem** `elections/e1/voters/out1` com `status: "pending", kind: "guest"` (gravado antes) → `permission-denied` (a checagem vem antes do atalho "eleitor já existe").
  - `memberOnly` + `member` → `{status: "approved", kind: "member"}`.
  - Sem `memberOnly`, `outsider` continua `{status: "pending", kind: "guest"}` (já coberto; garantir que segue passando).
- [ ] **Step 2: Rodar e ver falhar:** `cd functions && npm run test:integration` — os 3 primeiros novos falham (esperado: não lançam `permission-denied`).
- [ ] **Step 3: Implementar** em `checkIn`: ler `memberOnly` de `data`; calcular `isMember` (busca da sociedade já existente) **antes** do bloco `existing.exists`; se `memberOnly && !isMember` lançar `fail("permission-denied", <mensagem das constraints>)`. Mover só o necessário; não mudar o resto do fluxo.
- [ ] **Step 4: Rodar tudo:** `cd functions && npm run test:integration && npm test && npm run lint` — Expected: PASS.
- [ ] **Step 5: Commit** `feat(elections): check-in memberOnly recusa quem não é da sociedade`

---

### Task 2: Convites e push ao abrir a eleição

**Files:**
- Create: `functions/src/elections/invites.ts`
- Modify: `functions/src/elections/index.ts` (exportar `electionOpened`), `functions/src/index.ts` (lista de re-exports de `./elections`)
- Test: `functions/test/electionsInvites.test.ts` (unitário), `functions/integration/invites.itest.ts` (emulador)

**Interfaces:**
- Produces (em `invites.ts`):
  - `isOpening(before: {status?: unknown} | undefined, after: {status?: unknown} | undefined): boolean` — `true` só se `before.status === "draft"` e `after.status === "open"`.
  - `buildOpenMessage(title: string, electionId: string, tokens: string[]): admin.messaging.MulticastMessage` — `notification` e `data` conforme Global Constraints; `android.priority: "high"`; `apns.payload.aps` `{sound: "default"}`.
  - `inviteMembers(db: Firestore, electionId: string, send: (message: admin.messaging.MulticastMessage) => Promise<unknown>): Promise<{invited: number; notified: number}>` — lê `elections/{id}` (title, societyId, societyName) e `societies/{societyId}.members`; grava o convite de cada membro com `set` (idempotente; em lotes ≤ 500); envia push (lotes ≤ 500 tokens) só a membros com `fcmToken` e sem `"election_open"` em `disabled_notifications`.
- Produces: Cloud Function `electionOpened` = `functions.firestore.document("elections/{electionId}").onUpdate(...)` que chama `inviteMembers(admin.firestore(), electionId, (m) => admin.messaging().sendEachForMulticast(m))` somente quando `isOpening`.

- [ ] **Step 1: Testes unitários que falham** (`functions/test/electionsInvites.test.ts`): `isOpening` é `true` para draft→open; `false` para open→open, open→closed, draft→draft, `undefined`; `buildOpenMessage("Eleição UMP 2026", "e1", ["t1"])` tem `data` igual a `{type: "election_open", electionId: "e1"}`, `notification.title === "Eleição aberta"` e corpo começando por `"Eleição UMP 2026. "`.
- [ ] **Step 2: Rodar:** `cd functions && npm test` — Expected: FAIL (módulo não existe).
- [ ] **Step 3: Implementar** `isOpening` e `buildOpenMessage`; rodar `npm test` — Expected: PASS.
- [ ] **Step 4: Testes de integração que falham** (`invites.itest.ts`, mesmo padrão de `voters.itest.ts`; `send` é um `vi.fn()`): sociedade `s1` com membros m1, m2, m3 e eleição `e1`; m1 tem `fcmToken`, m2 tem token mas `disabled_notifications: ["election_open"]`, m3 sem token e sem documento `users/m3`:
  - `inviteMembers` grava `users/m1|m2|m3/election_invites/e1` com `{electionId, title, societyName}` e `createdAt`; retorna `{invited: 3, notified: 1}`; `send` chamado uma vez com `tokens: [<token de m1>]`.
  - Chamar duas vezes não duplica convites (mesmo documento).
  - Sociedade sem membros → `{invited: 0, notified: 0}` e `send` não chamado.
  - Diretor que não é membro **não** recebe convite.
- [ ] **Step 5: Rodar:** `npm run test:integration` — Expected: FAIL.
- [ ] **Step 6: Implementar `inviteMembers` e a função `electionOpened`**; exportar nos dois `index.ts`. Rodar `npm run test:integration && npm test && npm run lint && npm run build` — Expected: PASS.
- [ ] **Step 7: Commit** `feat(elections): convite e push aos membros quando a eleição é aberta`

---

### Task 3: Regras do Firestore para os convites

**Files:**
- Modify: `firestore.rules` (novo `match /users/{userId}/election_invites/{electionId}` — hoje `users/{userId}` não tem subcoleções, então o padrão é negar)
- Test: `rules-tests/elections.rules.test.ts`

**Interfaces:**
- Produces: leitura (get e list) permitida só ao próprio `uid`; nenhuma escrita pelo cliente.

- [ ] **Step 1: Testes que falham** (mesmo arquivo, helper `env.authenticatedContext`): semear `users/user1/election_invites/e1`; `user1` lê o documento e lista a coleção (`assertSucceeds`); `user2` não lê nem lista (`assertFails`); `user1` não cria, atualiza nem apaga (`assertFails`); deslogado não lê. Incluir também um teste de regressão: `user1` (membro não diretor) lê `elections/e1/rounds/r1`, `elections/e1/voters/user1` e `elections/e1/rounds/r1/voted/user1` (`assertSucceeds`) e **não** lê `elections/e1/rounds/r1/voted/other`.
- [ ] **Step 2: Rodar:** `cd rules-tests && npm test` (ver `rules-tests/package.json`; usa emulador) — Expected: os testes de convite falham.
- [ ] **Step 3: Implementar a regra** em `firestore.rules`, junto das regras de `users`.
- [ ] **Step 4: Rodar** `cd rules-tests && npm test` — Expected: PASS (suíte inteira).
- [ ] **Step 5: Commit** `feat(rules): convites de eleição legíveis só pelo dono`

---

### Task 4: Lógica pura em Dart (QR, estados da votação, convites, push)

**Files:**
- Modify: `lib/src/modules/elections/models/election_logic.dart`, `lib/src/modules/elections/models/election.dart` (modelo `ElectionInvite`)
- Test: `test/modules/elections/election_vote_logic_test.dart`

**Interfaces:**
- Produces em `election.dart`: `class ElectionInvite { final String id; final String title; final String societyName; factory ElectionInvite.fromJson(String id, Map<String, dynamic> json); }` (`id` = id da eleição; campos ausentes viram `''`, como os demais modelos).
- Produces em `election_logic.dart`:
  - `String? parseElectionId(String raw)` — aceita URL com caminho terminando em `/votar/{id}` (qualquer host/porta, barra final, query/fragmento) **ou** um id solto (`^[A-Za-z0-9_-]{8,64}$` após `trim()`); qualquer outra coisa → `null`.
  - `List<Candidate> filterCandidates(List<Candidate> options, String query)` — porta de `web-portal/src/modules/elections/filterOptions.ts` (sem maiúsculas/acentos, mantém ordem, consulta vazia devolve tudo).
  - `class Loadable<T> { const Loadable.loading(); const Loadable(T value); bool get isLoaded; T get value; }`
  - `enum VoteViewKind { loading, notFound, notOpen, closed, needsCheckIn, notMember, waitingRound, ballot, voted }` e `class VoteView { final VoteViewKind kind; final ElectionRound? round; }`
  - `VoteView deriveVoteView({required Loadable<Election?> election, required Loadable<ElectionVoter?> voter, required Loadable<ElectionRound?> openRound, required Loadable<bool> hasVoted})` — mesma ordem de `voteState.ts`: eleição carregando→`loading`; nula→`notFound`; `draft`→`notOpen`; `closed`→`closed`; voter carregando→`loading`; voter nulo→`needsCheckIn`; voter com `status != approved` ou `kind != member`→`notMember`; rodada carregando→`loading`; rodada nula→`waitingRound`; `hasVoted` carregando→`loading`; senão `voted` ou `ballot` (com `round`).
  - `List<ElectionInvite> invitesToShow(List<ElectionInvite> invites, Map<String, ElectionStatus> statusById)` — só convites cuja eleição está `open`; mantém a ordem; id sem status conhecido é omitido.
  - `String? electionIdFromPush(Map<String, dynamic> data)` — `data['type'] == 'election_open'` e `data['electionId']` não vazio (após `trim`) → o id; senão `null`.

- [ ] **Step 1: Escrever os testes que falham** (mesmo padrão dos testes existentes em `test/modules/elections/`):
  - `parseElectionId`: `'https://ipe-ensino.vercel.app/votar/abc12345XYZ'`, `'http://localhost:3000/votar/abc12345XYZ/'`, `'https://x.com/votar/abc12345XYZ?a=1#f'` → `'abc12345XYZ'`; `'  abc12345XYZ '` → `'abc12345XYZ'`; `'https://x.com/eleicoes/abc12345XYZ'`, `'https://x.com/votar/'`, `'oi'`, `''`, `'javascript:alert(1)'` → `null`.
  - `filterCandidates`: `'joao'` encontra `'João Silva'`; consulta vazia devolve tudo; ordem preservada.
  - `deriveVoteView`: uma asserção por transição da lista acima, incluindo `voter` pendente → `notMember` e `kind: guest` aprovado → `notMember`.
  - `invitesToShow`: convite de eleição `closed` some; de `open` fica; sem status some.
  - `electionIdFromPush`: tipo certo com id → id; tipo `chat_mention` → `null`; id vazio/ausente → `null`.
- [ ] **Step 2: Rodar:** `flutter test test/modules/elections/election_vote_logic_test.dart` — Expected: FAIL (símbolos não existem).
- [ ] **Step 3: Implementar** os símbolos acima.
- [ ] **Step 4: Rodar** o mesmo teste e `flutter analyze` — Expected: PASS.
- [ ] **Step 5: Commit** `feat(elections): lógica pura da votação no app`

---

### Task 5: Repositório e telas de voto

**Files:**
- Modify: `lib/src/modules/elections/data/elections_repository.dart`
- Create: `lib/src/modules/elections/presentation/election_vote_page.dart`, `lib/src/modules/elections/presentation/widgets/election_ballot.dart`
- Test: `test/modules/elections/election_ballot_test.dart` (widget)

**Interfaces:**
- Consumes: Task 4 (`deriveVoteView`, `Loadable`, `filterCandidates`, `ElectionInvite`).
- Produces em `ElectionsRepository`:
  - `Stream<List<ElectionInvite>> watchInvites(String uid)` — `users/{uid}/election_invites`, mais novos primeiro (`createdAt` desc).
  - `Stream<ElectionVoter?> watchMyVoter(String electionId, String uid)`
  - `Stream<ElectionRound?> watchOpenRound(String electionId)` — rodada com `status == 'open'` (limit 1).
  - `Stream<bool> watchHasVoted(String electionId, String roundId, String uid)`
  - `Future<void> checkIn(String electionId)` — chama `electionCheckIn` com `{electionId, memberOnly: true}`; `FirebaseFunctionsException` → `AppException(message: e.message ?? 'Não foi possível entrar na votação.')`.
  - `Future<String> castVote(String electionId, String roundId, String choice)` — chama `electionCastVote`, devolve `receipt`; mesmo tratamento de erro.
- Produces: `ElectionBallot({required ElectionRound round, required bool busy, String? error, required ValueChanged<String> onSubmit})` e `ElectionVotePage({required String electionId})`.

- [ ] **Step 1: Teste de widget que falha** (`election_ballot_test.dart`): rodada `number: 1` com opções Ana, Bruno → mostra "Buscar por nome", lista as duas e "Branco"; digitar `ana` filtra para Ana (+ Branco); "Confirmar voto" desabilitado até escolher; escolher e tocar chama `onSubmit` com o id do candidato; escolher "Branco" chama `onSubmit('blank')`; rodada `number: 2` **não** mostra o campo de busca; `busy: true` desabilita o botão; `error: 'Rodada encerrada'` mostra o texto e, com `busy: false`, o botão volta a habilitar (foco 4 do Review Focus).
- [ ] **Step 2: Rodar:** `flutter test test/modules/elections/election_ballot_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implementar `ElectionBallot`** (rádios + busca só no 1º escrutínio + "Branco" sempre; título `Votação para <cargo> — Nº escrutínio`, usando o rótulo de cargo que o módulo já tiver em Dart; se não houver, criar um helper em `election_logic.dart`). Rodar o teste — Expected: PASS.
- [ ] **Step 4: Implementar os métodos do repositório** (sem teste de unidade: são wrappers finos do SDK; cobertos na Task 8).
- [ ] **Step 5: Implementar `ElectionVotePage`:** assina os streams com `Provider<ElectionsRepository>` e o usuário de `AppState`; encadeia a rodada → `watchHasVoted` só quando há rodada; monta `deriveVoteView`; renderiza por `kind` (carregando, não encontrada, "ainda não aberta", "encerrada", `notMember` com a mensagem das constraints, "Aguardando a próxima votação. Esta tela atualiza sozinha.", cédula, "Voto registrado" com o código do comprovante guardado em estado local por rodada). Em `needsCheckIn` mostra o botão "Ler QR do condutor" (a ação é ligada na Task 6, quando `ElectionScanPage` existir; até lá o botão fica sem ação). Título mostra o título da eleição e a sociedade. Enviar voto com guarda contra toque duplo (`busy`); erro vai para `ElectionBallot.error`.
- [ ] **Step 6: Rodar** `flutter analyze && flutter test` — Expected: PASS.
- [ ] **Step 7: Commit** `feat(elections): telas de voto no app`

---

### Task 6: Leitor de QR e código manual

**Files:**
- Modify: `pubspec.yaml` (adicionar `mobile_scanner`, versão compatível com o SDK atual: usar `flutter pub add mobile_scanner`), `ios/Runner/Info.plist` (`NSCameraUsageDescription` em pt_BR, ex.: "Usamos a câmera para ler o QR code da eleição."), `android/app/src/main/AndroidManifest.xml` (permissão de câmera, se o plugin não a mesclar sozinho)
- Create: `lib/src/modules/elections/presentation/election_scan_page.dart`, `lib/src/modules/elections/presentation/widgets/manual_code_field.dart`
- Test: `test/modules/elections/manual_code_field_test.dart`

**Interfaces:**
- Consumes: `parseElectionId`, `ElectionsRepository.checkIn` (Tasks 4–5).
- Produces: `ManualCodeField({required ValueChanged<String> onElectionId})` — campo "Código ou link da eleição" + botão; entrada inválida mostra `"Código ou link inválido."`, válida chama `onElectionId(id)`. `ElectionScanPage` — `Navigator.pop(context, String electionId)` após check-in bem-sucedido.

- [ ] **Step 1: Teste de widget que falha** (`manual_code_field_test.dart`): link `https://x.com/votar/abc12345XYZ` chama o callback com `abc12345XYZ`; `oi` mostra a mensagem e não chama; link de condução (`/eleicoes/...`) mostra a mensagem.
- [ ] **Step 2: Rodar** `flutter test test/modules/elections/manual_code_field_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implementar `ManualCodeField`**; rodar o teste — Expected: PASS.
- [ ] **Step 4: Implementar `ElectionScanPage`:** câmera (`mobile_scanner`) em cima, `ManualCodeField` **sempre visível** embaixo; leitura → `parseElectionId` → `null` mostra "QR inválido." e continua escaneando; id válido → ignora novas leituras enquanto `busy`, chama `checkIn(id)`; erro mostra a mensagem do servidor (ex.: não-membro) e libera nova tentativa; sucesso → `pop(id)`. Se a câmera for negada ou indisponível (callback de erro do plugin), mostrar aviso "Câmera indisponível. Digite o código ou link abaixo." (foco 5).
- [ ] **Step 5: Ligar o botão "Ler QR do condutor"** de `ElectionVotePage` (estado `needsCheckIn`) a `ElectionScanPage`; se o id devolvido for diferente do da página, fazer `pushReplacement` para `ElectionVotePage(electionId: idDevolvido)`.
- [ ] **Step 6: Adicionar as permissões** (Info.plist / manifest) e rodar `flutter pub get && flutter analyze && flutter test` — Expected: PASS.
- [ ] **Step 7: Commit** `feat(elections): leitor de QR e código manual para entrar na votação`

---

### Task 7: Balão na home, toque no push e preferência de notificação

**Files:**
- Modify: `lib/src/modules/notifications/models/notification_type.dart` (novo `electionOpen('election_open', 'Eleição aberta', 'Aviso quando a eleição da sua sociedade for aberta para votação')`), `lib/src/modules/notifications/services/notification_service.dart`, `lib/src/modules/home/presentation/home_shell.dart`, `lib/src/modules/elections/data/elections_repository.dart` (método abaixo)
- Create: `lib/src/modules/home/presentation/widgets/announcement_card.dart`, `lib/src/modules/elections/presentation/widgets/election_invite_banner.dart`
- Test: `test/modules/home/announcement_card_test.dart`

**Interfaces:**
- Consumes: `invitesToShow`, `electionIdFromPush`, `watchInvites` (Tasks 4–5), `ElectionVotePage` (Task 5).
- Produces: `ElectionsRepository.watchOpenInvites(String uid): Stream<List<ElectionInvite>>` — combina `watchInvites(uid)` com o status (`watchElection(id)`) de cada convite e aplica `invitesToShow`. `AnnouncementCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap})` — o cartão em gradiente azul hoje inline no aviso "Nova versão disponível!". `ElectionInviteBanner` — um cartão por convite aberto (título `"Eleição aberta!"`, subtítulo `"<título> · <sociedade>"`), toque abre `ElectionVotePage(electionId)`; não mostra nada sem convites.

- [ ] **Step 1: Teste de widget que falha** (`announcement_card_test.dart`): mostra título e subtítulo; toque chama `onTap`.
- [ ] **Step 2: Rodar** `flutter test test/modules/home/announcement_card_test.dart` — Expected: FAIL.
- [ ] **Step 3: Extrair `AnnouncementCard`** do aviso de versão (visual idêntico: mesmo gradiente, sombra, ícone, seta) e passar a usá-lo no `home_shell.dart` com o ícone/texto atuais; rodar o teste — Expected: PASS. Conferir no emulador que o aviso de versão não mudou (Task 8).
- [ ] **Step 4: Implementar `watchOpenInvites` e `ElectionInviteBanner`**; inserir o banner no `home_shell.dart` logo abaixo do aviso de versão (mesmo `Padding` lateral).
- [ ] **Step 5: Toque no push:** em `notification_service.dart`, criar `_handleElectionTap(Map<String, dynamic> data, {int attempt = 0})` seguindo o padrão de `_handleTeachingTap` (repetir até 6 vezes a cada 500 ms se o navegador/sessão ainda não existirem — app abrindo a frio): usa `electionIdFromPush`, abre `ElectionVotePage`. Chamá-lo no início de `_navigateFromNotification` e em `_onNotificationTapped`, antes dos tratamentos existentes.
- [ ] **Step 6: Rodar** `flutter analyze && flutter test` — Expected: PASS.
- [ ] **Step 7: Commit** `feat(elections): balão na home, toque no push e preferência election_open`

---

### Task 8: Verificação ponta a ponta e roteiro de publicação

**Files:**
- Modify: `docs/DESENVOLVIMENTO_LOCAL.md` (nota: simulador sem câmera → usar "código ou link"; como testar a eleição no app)
- Test: roteiro manual nos emuladores

- [ ] **Step 1: Suítes completas:** `cd functions && npm test && npm run test:integration && npm run lint && npm run build`; `cd rules-tests && npm test`; na raiz `flutter analyze && flutter test` — Expected: tudo PASS.
- [ ] **Step 2: Roteiro no simulador** (emuladores, `npm run dev` + `npm run app`, conforme `AGENTS.md`): criar sociedade com 2 membros e 1 não-membro; criar a eleição como diretor; abrir pela web de condução. Verificar: convite aparece para os 2 membros e não para o não-membro (Firestore emulator UI); balão aparece na home do membro; tocar abre a tela "Ler QR"; colar o link de votação no campo manual → entra e fica "Aguardando a próxima votação"; iniciar escrutínio na web → cédula aparece sozinha; votar → comprovante; não-membro colando o link vê a mensagem de recusa; encerrar a eleição → balão some; aviso de "Nova versão" visual inalterado.
- [ ] **Step 3: Documentar a ordem de publicação** no `docs/DESENVOLVIMENTO_LOCAL.md` ou no PR: `firebase deploy --only firestore:rules` e `--only functions:electionCheckIn` antes; `--only functions:electionOpened` **só após** a nova versão do app estar nas lojas (um deploy geral de Functions publicaria o gatilho — usar sempre `--only` por nome). Publicação do app via skill `release-church-hub`.
- [ ] **Step 4: Commit** `docs: roteiro de teste e ordem de publicação da votação no app`
