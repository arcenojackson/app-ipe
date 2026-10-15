# Eleição de diretoria das sociedades — Design

Data: 2026-10-15 · Branch: `worktree-society-elections` · Status: rascunho para revisão

## 1. Objetivo

O estatuto manda que a diretoria de cada sociedade seja eleita todo ano pelos membros ativos dela. Hoje a diretoria é definida pelo ADM em `societies/{id}.board`.

Esta feature leva a eleição para dentro do app. O app **facilita o voto, a contagem e a auditoria**. A reunião continua presencial: vota quem está presente no dia, e pode haver presentes sem conta no app.

Critérios de sucesso:
- Cada pessoa liberada vota uma única vez por cargo.
- O voto é secreto.
- A contagem é conferível e deixa um registro auditável.
- O resultado atualiza a diretoria da sociedade sem retrabalho manual.

## 2. Decisões já tomadas

| Tema | Decisão |
|---|---|
| Quem conduz | Admins globais (`is_admin`), em um menu novo do app Flutter. |
| Escopo da eleição | Uma eleição por sociedade, com data e hora. Os cargos são os de `BoardPosition` (presidente, vice, secretário(a), tesoureiro(a)), podendo desmarcar algum. |
| Formato | Cargo a cargo, uma rodada por cargo. |
| Candidatos | Membros da sociedade (`membersIds`). Cadastrados antes ou adicionados na hora. Quem não usa o app já existe como usuário e pode ser candidato. |
| Regra de vitória | Maioria simples. Branco é registrado e não vence. |
| Candidato único | Voto Sim, Não ou Branco. Vence se tiver mais Sim que Não. |
| Empate | O admin abre uma rodada de desempate só com os empatados. |
| Acúmulo de cargos | Proibido. Quem já foi eleito sai dos candidatos dos cargos seguintes. |
| Sigilo | Voto sempre secreto. |
| Acesso do eleitor | QR/link estático por eleição, abre uma página web. |
| Eleitor com conta do app | Entra com a conta e vota sem aprovação, se estiver em `membersIds` da sociedade. |
| Eleitor sem conta | Entra com nome e e-mail e espera a aprovação do admin. |
| Logado, mas fora da sociedade | Tratado como convidado: precisa de aprovação. |
| Aplicar o resultado | O admin toca em "Aplicar diretoria"; nada muda sozinho. |
| Plataforma web | Módulo novo no portal Next.js (`web-portal/`), em rota pública. |

## 3. Arquitetura

Todo voto passa por Cloud Function. O cliente só lê. Os dados ficam em **coleções novas** com regras próprias e aditivas; `users` e `societies` não são alteradas nas regras.

- **App Flutter**: menu "Eleições" (só admins). Cria e conduz a eleição, aprova convidados, copia o link do QR, vê resultados e a ata.
- **Portal Next.js**: módulo `src/modules/elections/` e a rota pública `src/app/(public)/votar/[id]`, fora do grupo `(portal)`, que exige login e papel. É a página de voto.
- **Cloud Functions** (`functions/src/elections/`): `electionSetStatus` (abrir/encerrar a eleição), `electionCheckIn`, `electionReviewVoter` (aprovar/recusar), `electionOpenRound`, `electionCastVote`, `electionCloseRound`, `electionApplyBoard`, mais o gatilho `electionVoteRecorded` (contador ao vivo "X de Y votaram").

Identidade do eleitor na web: conta do app (Firebase Auth) ou Firebase Anonymous Auth para convidados. O `voterKey` é sempre o uid. Conta só-Apple não entra na web (limite já aceito no portal).

## 4. Dados

- `elections/{id}`: `societyId`, `societyName`, `title`, `scheduledAt`, `status` (`draft` | `open` | `closed`), `positions[]`, `createdBy`, `createdAt`, `openedAt`, `closedAt`, `boardAppliedAt`.
- `elections/{id}/rounds/{rid}`: `position`, `candidates[]` (userId e nome), `type` (`normal` | `single` | `runoff`), `status` (`pending` | `open` | `closed`), `createdAt`, `openedAt`, `closedAt`, `votedCount`, `result` (preenchido só ao fechar: contagens, vencedor ou empate, divergência). `votedCount` é só informativo: o gatilho `electionVoteRecorded` o incrementa a cada novo `voted`, e o encerramento grava o valor exato. O voto **não** escreve no documento da rodada (testes mostraram que isso faz os eleitores e o encerramento disputarem o mesmo documento).
- `elections/{id}/voters/{uid}`: `name`, `email`, `kind` (`member` | `guest`), `status` (`pending` | `approved` | `rejected`), `approvedBy`, datas.
- `elections/{id}/rounds/{rid}/voted/{uid}`: só marca "já votou nesta rodada".
- `elections/{id}/rounds/{rid}/ballots/{randomId}`: a escolha (candidato, `yes`, `no` ou `blank`). **Sem identidade e sem timestamp.**
- `elections/{id}/events/{autoId}`: log de auditoria só de escrita (check-in, aprovação, abertura e fechamento de rodada, aplicação da diretoria, divergências).

Sigilo e voto único: `voted` diz que a pessoa votou; `ballots` guarda o que foi votado, sem ligação entre os dois. A Function grava ambos numa transação. O recibo do eleitor é o id aleatório do ballot.

## 5. Fluxos

**Admin (app)**
1. Criar: sociedade, título, data e hora; cargos pré-marcados.
2. Tela da eleição: botão "Copiar link"; aba **Presentes** (fila de pendentes e lista de liberados); aba **Cargos** (cartão por cargo, candidatos escolhidos entre os membros da sociedade).
3. "Abrir eleição" abre o check-in. Por cargo: "Abrir votação" (contador "X de Y votaram") e "Encerrar".
4. "Aplicar diretoria" grava os vencedores em `societies/{id}.board` só nos cargos eleitos. "Encerrar eleição" fecha tudo.
5. Ao aprovar, o app avisa se o mesmo e-mail ou nome já está na lista.

**Eleitor (web `/votar/[id]`)**
1. Escolhe "Entrar com a conta do app" ou "Votar sem conta" (nome e e-mail).
2. Membro da sociedade entra liberado. Os demais ficam em "Aguardando aprovação", atualizando em tempo real.
3. Liberado, vê a rodada aberta, vota uma vez, confirma e recebe o código de recibo.
4. Entre rodadas vê "Aguardando próxima rodada".

**Apuração (ao fechar a rodada)**
- A Function conta os `ballots` e confere com `voted`. Grava o resultado e registra divergências no log.
- Aplica as regras de vitória, empate e candidato único da seção 2.

**Ata**: tela de leitura gerada do log: presentes (com quem aprovou cada convidado), contagem por rodada, vencedores, divergências e horários. O admin copia o texto.

## 6. Segurança e regras do Firestore

Bloco novo `elections`, aditivo:
- Admin (`isAdmin()` existente) cria a eleição (sempre como `draft`) e edita candidatos, **só em rodadas `pending`**; só cria rodadas `pending` e não muda `status` pelo cliente.
- Documento da eleição: o `get` é público (a página de voto o lê antes do login; ele só guarda título, nome da sociedade, status e cargos) e o `list` é só do admin (a página de voto usa `get` com o id do link). Rodadas: leitura para qualquer usuário autenticado (inclusive anônimo).
- `voted`: o eleitor lê só o próprio documento.
- `voters`: o eleitor lê só o próprio documento; o admin lê todos.
- `events`: leitura só do admin.
- `ballots`: nenhuma leitura pelo cliente. `voted`, `events` e transições de estado: só Functions.

As Functions validam o admin lendo `users/{uid}.is_admin` (a mesma fonte de `isAdmin()`), **recusam sessões anônimas nas operações de admin**, usam transações e tornam o voto idempotente.

"Aplicar diretoria" recusa, com mensagem clara, uma sociedade cuja diretoria ainda está no formato antigo (lista de ids sem cargos) e não vazia, para não perder ninguém em silêncio; uma lista vazia (padrão de sociedade nova) é convertida normalmente.

### Riscos aceitos

0. **Login anônimo dá `request.auth != null` a qualquer visitante.** As regras antigas do projeto (`users`, `invites`, `settings`, chats etc.) usam `request.auth != null` e a regra de `users` deixa criar o próprio documento com qualquer campo. O app já tem cadastro aberto (`createUserWithEmailAndPassword`), então esse acesso já existia para quem cria uma conta; o convidado anônimo remove só o atrito do cadastro. As Functions de eleição não aceitam token anônimo como admin. Decisão do usuário pendente antes de ativar o provedor Anônimo em produção (ver relatório da execução).
1. A regra atual de `users` permite que qualquer logado marque `is_admin` no próprio documento. Aqui isso permitiria abrir e fechar eleições. Por decisão anterior, as regras de `users` não são apertadas.
2. O sigilo vale contra a interface e contra o admin. Quem tivesse acesso administrativo bruto ao Firestore poderia tentar casar `voted` com `ballots` pelo horário interno de criação dos documentos. Mitigado com ids aleatórios e sem timestamps nos votos, mas não eliminado.
3. Se a resposta do voto se perder na rede, o recibo não pode ser reexibido, porque não pode ficar ligado ao eleitor.
4. Um membro logado que receba uma foto do QR poderia votar de casa. Sem QR rotativo na v1.

## 7. Erros

- Voto em rodada fechada ou não aberta: rejeitado com mensagem clara.
- Voto repetido: devolve "já votou", sem duplicar.
- Eleitor pendente ou recusado: rejeitado.
- Abrir rodada com candidato já eleito: a Function remove esse candidato e avisa.
- Divergência entre `voted` e `ballots` ao fechar: registrada no log e destacada no resultado.

## 8. Testes

- **Regras no emulador do Firestore** (já configurado em `firebase.json`): quem lê e quem escreve cada coleção.
- **Functions**: voto duplicado, rodada fechada, eleitor não liberado, desempate, regra do candidato único, exclusão de quem já foi eleito, divergência `voted` × `ballots`.
- **Web (Vitest)**: estados da página de voto.
- **Flutter**: modelos e lógica pura.

## 9. Passos manuais

- Ativar **Anonymous Auth** no console do Firebase.
- A página de voto só loga no domínio já autorizado (`ipe-ensino.vercel.app`); previews da Vercel validam só o build.

## 10. Coordenação com o portal de ensino

O portal já está na `master`. Os arquivos compartilhados são `firestore.rules`, `functions/src/index.ts` e `firebase.json`. O código da eleição fica isolado em `functions/src/elections/`, `web-portal/src/modules/elections/` e `web-portal/src/app/(public)/votar/[id]`, para que o merge seja uma linha em cada arquivo compartilhado.

## 11. Fora da v1

Ata em PDF, QR rotativo, assembleias gerais (muita gente), push para o admin quando um convidado chega (a fila é em tempo real), tela de projeção no portal e App Check.
