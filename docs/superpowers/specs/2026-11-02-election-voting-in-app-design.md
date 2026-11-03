# Votação da eleição dentro do app — design

Data: 2026-11-02 · Status: aguardando aprovação

## Intenção e por quê

O primeiro teste real da Eleição (8 pessoas) mostrou que votar pelo portal web
é frágil: o login Google falhou em um celular, e quem criou a conta com Apple no
iPhone não tem como entrar na web (sem Google e sem senha). O app já tem a
sessão de todo membro, em qualquer provedor. Votar dentro do app elimina o login
externo, e o QR do condutor passa a servir também como confirmação de presença.

A web fica focada em quem conduz a eleição. O login com Apple na web é desejável
(o portal será também plataforma pedagógica), mas é um trabalho separado, depois.

## Como funciona (visão do usuário)

1. O diretor **abre** a eleição (hoje na tela web de condução; nada muda aí).
2. Todo **membro da sociedade** recebe um push ("Eleição aberta: <título>") e vê
   um **balão na tela inicial**, no mesmo estilo do aviso "Nova versão
   disponível!" (`home_shell.dart`).
3. Tocar no push ou no balão abre uma tela que **pede para ler o QR** mostrado
   pelo condutor.
4. Ao ler, o app faz o check-in do membro (aprovado na hora) e segue direto para
   a votação, dentro do app: aguardando rodada → cédula → "voto registrado" com
   código do comprovante → aguardando a próxima rodada, até a eleição encerrar.
5. Quem não é membro da sociedade vê "A votação é só para membros da sociedade".

## Objetivos

- Membro vota sem sair do app, com qualquer tipo de conta (e-mail/senha, Google,
  Apple).
- Notificação e balão aparecem **quando a eleição é aberta**, não na criação.
- Leitura do QR confirma presença (check-in).
- Mesmas regras de votação de hoje (escrutínios, branco, busca no 1º escrutínio,
  comprovante, um voto por rodada), sem reimplementar a lógica no cliente.

## Não-objetivos

- Login com Apple no portal web (fica para depois).
- Votação de convidados / não membros (a votação é só de membros).
- QR rotativo/anti-foto: o QR continua sendo o link fixo `/votar/{id}`; a
  conferência de presença segue sendo o painel de presentes do diretor.
- Condução da eleição no app (continua na web).
- Mostrar resultados parciais ao eleitor (paridade com a web atual).
- Remover a página `/votar/{id}` da web: **fica como plano B** (app
  desatualizado), só deixa de ser divulgada.

## Anti-objetivos (seria falha mesmo funcionando)

- Votar sem check-in, ou votar mais de uma vez na mesma rodada.
- Qualquer caminho que revele em quem alguém votou (nenhum cliente lê as cédulas;
  isso não muda).
- Push/balão para quem já votou ou para eleição já encerrada.
- App antigo quebrar ao receber um push de tipo que ele não conhece.

## O que já existe e será reaproveitado (verificado no código)

- Servidor: `electionCheckIn` e `electionCastVote` só dependem do `uid`
  autenticado (`functions/src/elections/`). Membro entra `approved`; o servidor
  decide pelo `members` da sociedade.
- Regras do Firestore: qualquer usuário autenticado já lê as rodadas
  (`rounds`) e o próprio registro de eleitor (`voters/{uid}`) e a própria marca
  de voto (`rounds/{id}/voted/{uid}`).
- App: `ElectionRound`, `ElectionVoter`, `Candidate` em
  `lib/src/modules/elections/models/election.dart`.
- Web: `voteState.ts` (máquina de estados do eleitor) e `BallotStep.tsx` são a
  referência de comportamento a portar para Flutter.
- Push: padrão de `functions/src/index.ts` (tokens FCM, `disabled_notifications`,
  payload `data.type`), `NotificationType` e o roteamento de toque em
  `notification_service.dart` (`_handleTeachingTap`).

## O que muda

### Servidor (Functions + regras)

- **Disparo do push ao abrir.** Gatilho Firestore na transição
  `status: draft → open` de `elections/{id}`. Envia a cada membro da sociedade
  (campo `members` da sociedade, menos quem desativou o tipo
  `election_open`), com `data: {type: "election_open", electionId}`.
- **Caixa de convites (decisão minha).** No mesmo gatilho, grava
  `users/{uid}/election_invites/{electionId}` com `{electionId, title,
  societyName, createdAt}` para cada membro. O balão da home lê só esse
  subconjunto do próprio usuário. Motivo: hoje só diretores podem *listar*
  eleições, e guardar `memberIds` no documento da eleição o exporia (o `get` é
  público). Regra nova: usuário lê apenas o próprio `election_invites`.
- **Check-in só de membros pelo app (decisão minha).** `electionCheckIn` ganha
  um parâmetro opcional (ex.: `memberOnly: true`) enviado pelo app: se a pessoa
  não é membro, responde `permission-denied` com mensagem clara, **sem** criar
  registro de convidado nem usuário. Sem o parâmetro, o comportamento atual da
  web (convidado pendente) fica intacto. **Ordem das checagens:** a de
  `memberOnly` roda **antes** do atalho "eleitor já existe", para que um não
  membro que entrou antes como convidado na web também veja "só para membros" no
  app (e não "aguardando aprovação"). O app, portanto, não precisa de telas para
  `pending`/`rejected`.
- **Push e versões antigas (decisão minha).** O texto do push é autossuficiente
  ("Eleição aberta: <título>. Abra o app para votar; se não abrir a votação,
  atualize o app."), porque quem está com versão antiga receberá a notificação
  sem ter o fluxo (não há campo de versão em `users`, então não dá para filtrar
  por versão). Esses membros usam o link `/votar/{id}` da web (plano B).
- **Ordem de publicação (decisão minha).** Regras, o parâmetro do check-in e o
  gatilho de push são retrocompatíveis, mas o **gatilho de push só é publicado
  depois que a nova versão do app estiver disponível nas lojas**; o restante pode
  ir antes. Assim ninguém recebe aviso de algo que o app instalado não sabe abrir.

### App (Flutter)

- **Leitor de QR.** Novo plugin de scanner (hoje o `pubspec.yaml` não tem), com
  permissão de câmera no iOS (`NSCameraUsageDescription`) e Android. *Decisão
  minha:* o app extrai o `electionId` olhando **só o caminho** `/votar/{id}` e
  ignora o host (o QR usa a origem de onde o condutor abriu o portal: produção,
  preview da Vercel ou emulador local, então uma lista fixa de hosts impediria
  testar). O id lido é só um identificador: quem decide é o servidor (o
  check-in recusa eleição inexistente, fechada ou de outra sociedade).
- **Alternativa ao QR (decisão minha).** Campo "digitar código/link" como
  contingência (simulador iOS não tem câmera; câmera negada; QR danificado).
- **Telas de voto** portando `voteState.ts`: carregando, não aberta, encerrada,
  só-membros (recusa), aguardando rodada, cédula (lista + "Branco"; busca por
  nome no 1º escrutínio), voto registrado + código do comprovante, e volta a
  aguardar. Tudo reativo (streams do Firestore, sem botão de atualizar).
- **Balão na home**, estilo do aviso de versão. *Ciclo de vida (decisão minha):*
  aparece quando a eleição é aberta e **fica até a eleição encerrar**, inclusive
  depois do check-in e depois de votar em uma rodada, porque é o caminho de volta
  para a votação (a eleição tem vários cargos e até 3 rodadas por cargo; "já
  votei" é por rodada, não da eleição). A home observa o convite do usuário, o
  documento da eleição (leitura pública) e o registro do eleitor; o convite é
  imutável e a limpeza é um filtro no cliente (eleição `closed` não aparece).
  Toque → tela do scanner, ou direto à votação se o check-in já foi feito.
  O anti-objetivo "sem balão para quem já votou" vale só para eleição encerrada.
- **Toque no push** → mesma tela (roteamento no `notification_service.dart`).
- **Preferência de notificação:** novo `NotificationType` `election_open` na tela
  de configurações.
- Repositório: métodos para observar o próprio eleitor, a rodada aberta e a marca
  "já votei", e chamar `electionCheckIn` / `electionCastVote`.

## Restrições

- Mexe no app: exige **nova versão nas lojas** (App Store e Play Store). Usar o
  fluxo de release já existente.
- Ambiente local de desenvolvimento usa emuladores e e-mail/senha (Google/Apple
  não existem localmente); câmera não existe no simulador iOS.
- O repositório é aberto a contribuições por fork/PR; CI roda Flutter, Functions,
  portal e regras. Testes de regras do Firestore existem (`rules-tests/`) e
  devem cobrir a regra nova.
- Nunca usar produção para desenvolver (ver `AGENTS.md`).

## Deixado ao construtor

- Escolha do plugin de scanner (compatível com Flutter/SDK atuais) e o fluxo de
  permissão de câmera.
- Nome exato do parâmetro do check-in, formato do documento de convite, e como
  limpar convites de eleições encerradas.
- Layout/visual das telas (seguir o tema e os componentes do app).
- Ordem de entrega e divisão em PRs.

## Pontos para o usuário conferir (chamadas minhas, não decididas)

1. Caixa de convites por usuário em vez de listar eleições pela sociedade.
2. Parâmetro `memberOnly` no check-in, mantendo o comportamento da web.
3. Campo manual de código como alternativa à câmera.
4. A web continua aceitando convidados em `/votar/{id}`: não removido agora.
5. Balão fica até a eleição encerrar (inclusive depois de votar).
6. QR validado só pelo caminho `/votar/{id}`, sem lista de hosts.
7. Texto do push autossuficiente e gatilho de push publicado só depois do app
   estar nas lojas.
8. `memberOnly` roda antes do atalho "eleitor já existe".
