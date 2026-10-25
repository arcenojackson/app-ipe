# Eleição de diretoria das sociedades — Design

Data: 2026-10-15 · Revisado em 2026-10-25 · Branch: `worktree-society-elections` · Status: rascunho para revisão

> **Revisão de 2026-10-25.** Depois de usar o sistema da UMP Nacional numa eleição real, o rito de votação passou a seguir o dela (escrutínios, confirmação de candidatos, 50% + 1), a condução passou para a web e o acesso passou a ser só dos diretores de cada sociedade. Nada disso foi publicado: o que já foi implementado é refeito (ver seção 12).

## 1. Objetivo

O estatuto manda que a diretoria de cada sociedade seja eleita todo ano pelos membros ativos dela. Hoje a diretoria é definida pelo ADM em `societies/{id}.board`.

Esta feature leva a eleição para dentro do app e do portal web. O sistema **facilita o voto, a contagem e a auditoria**. A reunião continua presencial: vota quem está presente no dia, e pode haver presentes que ainda não usam o app (eles entram com Google e são cadastrados como usuários novos).

Critérios de sucesso:
- Cada presente liberado vota uma única vez por escrutínio.
- O voto é secreto, inclusive para quem conduz.
- A contagem é conferível e deixa um registro auditável.
- Só os diretores da sociedade enxergam e conduzem a eleição dela.
- O resultado atualiza a diretoria da sociedade sem retrabalho manual.

## 2. Decisões já tomadas

| Tema | Decisão |
|---|---|
| Quem conduz | Só os **diretores da própria sociedade** (qualquer cargo em `board`). Sem exceção para admin global. Sociedade sem diretoria não tem eleição; o admin corrige a diretoria antes, em Sociedades. |
| Onde se conduz | **Só na web.** O app cria a eleição, lista as eleições, abre a condução na web e guarda a ata. |
| Acesso dos eleitores | Um QR/link por eleição, mostrado na tela de condução. Entra com Google ou com a conta do app. **Sem voto anônimo.** |
| Membro da sociedade | Entra liberado automaticamente. |
| Quem não é membro | É cadastrado como usuário novo (pendente na lista de Pessoas, igual ao login Google do app) e aparece na lista de presentes para o diretor aceitar ou recusar. Aceitar na eleição não aprova o usuário no app. |
| Cargos | Presidente, Vice, 1º Secretário, 2º Secretário e Tesoureiro. Só Presidente e Vice são obrigatórios; o diretor desmarca os que a sociedade não tem. |
| Rito | Escrutínios, no máximo 3 por cargo (seção 3), como na UMP Nacional. |
| Base do 50% + 1 | Os **presentes liberados** naquela eleição, contados quando o escrutínio é encerrado (não os votos dados, não todos os membros cadastrados). |
| Empate no 3º escrutínio | O diretor escolhe na tela quem é o mais velho (não há data de nascimento no cadastro por enquanto). |
| Quem declinou | O diretor remove a pessoa como candidata **só daquele cargo**. Ela continua podendo votar e volta a ser opção ao iniciar um novo cargo. |
| Sigilo | Voto sempre secreto. O diretor vê quem já votou e quem falta, nunca em quem cada um votou. |
| Quem já foi eleito | Não aparece como opção nos cargos seguintes. |
| Encerramento | O diretor encerra cada escrutínio manualmente; não há cronômetro. |
| Aplicar o resultado | Ação explícita do diretor ("Aplicar diretoria"); só altera os cargos decididos. |

## 3. O rito de cada cargo

Estados do cargo: `idle` → `scrutiny1` → `confirming` → `scrutiny2` → `awaiting3` → `scrutiny3` → `tiebreak` → `decided`.

1. **1º escrutínio (`scrutiny1`).** O diretor inicia. As opções são todos os membros da sociedade, menos quem já foi eleito em outro cargo, mais o voto em branco. Ninguém é eleito aqui: ele serve para levantar candidatos.
2. **Confirmação (`confirming`).** Ao encerrar, ficam como candidatos as pessoas que receberam ao menos um voto, com a contagem do 1º escrutínio visível. O diretor, depois de perguntar em voz alta, **remove quem declina**. Para seguir, é preciso ao menos um candidato.
3. **2º escrutínio (`scrutiny2`).** As opções são os candidatos que restaram, mais branco. Quem tiver **50% + 1 dos presentes liberados** é eleito na hora (`decided`), seja um candidato ou vários. Limiar = ⌊presentes ÷ 2⌋ + 1 (exemplo: 10 presentes exigem 6 votos). Se ninguém atinge, o cargo vai a `awaiting3`.
4. **3º escrutínio (`scrutiny3`).** Os mesmos candidatos do 2º. Vence o **mais votado**, mesmo sem maioria. Se há empate no topo, o cargo vai a `tiebreak` e o diretor escolhe, entre os empatados, o mais velho (`decided`).

Casos de borda:
- Todos os votados no 1º escrutínio declinam, ou ninguém recebe voto no 1º: o diretor usa "Reiniciar cargo", que volta a `idle` e soma 1 ao `cycle` do cargo.
- No 3º escrutínio só há votos em branco: ninguém é eleito e o cargo volta a `idle` com `cycle` + 1.
- Só um escrutínio fica aberto por vez na eleição inteira.
- Voto em branco conta para o total de votos, mas nunca elege; o limiar usa só os presentes liberados.
- Um cargo `decided` não é reaberto na v1.

## 4. Cargos

Chaves: `presidente`, `vice`, `secretario` (1º Secretário), `secretario2` (2º Secretário) e `tesoureiro`. Cada eleição guarda a lista ordenada dos cargos escolhidos em `positions`, com `presidente` e `vice` sempre presentes.

Chaves em `societies.board` (mesma regra do app: o rótulo do cargo em minúsculas):
- `presidente` → `presidente`
- `vice` → `vice`
- `secretario` → `secretario(a)` (continua a chave que já existe, para não quebrar diretorias gravadas)
- `secretario2` → `2º secretario(a)` (nova)
- `tesoureiro` → `tesoureiro(a)`

O app ganha o cargo `2º Secretario(a)` em `BoardPosition` e na tela de diretoria das Sociedades. Na eleição, o primeiro secretário aparece como "1º Secretário(a)".

## 5. Arquitetura

Toda gravação e toda mudança de fase passa por Cloud Function; o cliente só lê. Os dados ficam em coleções novas com regras próprias e aditivas; `users` e `societies` não são alteradas nas regras.

- **App Flutter**: menu "Eleições" para quem é diretor de alguma sociedade. Cria a eleição (por Function), lista as eleições das sociedades em que a pessoa é diretora, abre a condução na web e mostra a ata.
- **Portal Next.js, condução**: rota `/eleicoes/[id]`, só para os diretores da eleição. Módulo `src/modules/elections/` registrado no portal com acesso "qualquer pessoa logada" (a checagem de diretor é da Function e das regras).
- **Portal Next.js, voto**: rota pública `/votar/[id]`, fora do grupo `(portal)`.
- **Cloud Functions** (`functions/src/elections/`):
  - `electionCreate`: cria a eleição e os cargos. Confere a diretoria *atual* da sociedade e grava `directorIds`.
  - `electionSetStatus`: abre e encerra a eleição.
  - `electionCheckIn`: entrada do eleitor (membro liberado; os demais pendentes; cadastra o usuário novo).
  - `electionReviewVoter`: aceita ou recusa um presente.
  - `electionStartScrutiny`: inicia o 1º, 2º ou 3º escrutínio do cargo e monta as opções.
  - `electionCastVote`: registra o voto.
  - `electionCloseScrutiny`: apura e decide a próxima fase do cargo.
  - `electionRemoveCandidate`, `electionRestartCargo`, `electionPickOldest`: ações do diretor entre os escrutínios.
  - `electionApplyBoard`: grava os eleitos em `societies/{id}.board` e acrescenta os novos diretores a `directorIds`.
  - Gatilho `electionVoteRecorded`: contador ao vivo "X de Y votaram".
- Todas as funções de diretor conferem se quem chama está em `directorIds` da eleição (exceto `electionCreate`, que confere a diretoria atual da sociedade). Sessão anônima nunca é aceita.

## 6. Dados

- `elections/{id}`: `societyId`, `societyName`, `title`, `scheduledAt`, `status` (`draft` | `open` | `closed`), `positions[]`, `directorIds[]`, `createdBy`, `createdAt`, `openedAt`, `closedAt`, `boardAppliedAt`.
- `elections/{id}/cargos/{position}`: `stage`, `cycle`, `candidates[]` (id, nome, votos no 1º escrutínio), `tiedIds[]`, `winnerId`.
- `elections/{id}/rounds/{rid}` (cada escrutínio): `position`, `cycle`, `number` (1 a 3), `status` (`open` | `closed`), `options[]` (id e nome), `openedAt`, `closedAt`, `votedCount` e, depois de encerrado, `result` (votos por opção, branco, total de votos, `presentCount`, `threshold`, vencedor ou empatados, divergência).
- `elections/{id}/voters/{uid}`: `name`, `email`, `kind` (`member` | `guest`), `status` (`pending` | `approved` | `rejected`), `reviewedBy`, datas.
- `elections/{id}/rounds/{rid}/voted/{uid}`: só marca "já votou neste escrutínio".
- `elections/{id}/rounds/{rid}/ballots/{randomId}`: a escolha (id da opção ou `blank`). **Sem identidade e sem timestamp.**
- `elections/{id}/events/{autoId}`: log de auditoria só de escrita (check-in, liberação, início e encerramento de escrutínio, remoção de candidato, mais velho escolhido, reinício de cargo, aplicação da diretoria, divergências).

Sigilo e voto único: `voted` diz que a pessoa votou; `ballots` guarda o que foi votado, sem ligação entre os dois. A Function grava ambos numa transação. O recibo do eleitor é o id aleatório do ballot. `votedCount` é só informativo (atualizado pelo gatilho) e o encerramento grava o valor exato.

## 7. Telas

**Condução (web, `/eleicoes/[id]`)**
- Cabeçalho: título, sociedade, situação, botões Abrir e Encerrar eleição, e o **QR da votação desenhado na tela** com o link e o botão copiar.
- Presentes: convidados esperando liberação (aceitar ou recusar) e o total de liberados.
- Um cartão por cargo, conforme a fase:
  - `idle`: "Iniciar 1º escrutínio".
  - Escrutínio aberto: "X de Y votaram", a lista de quem ainda falta votar (entre os presentes liberados) e "Encerrar escrutínio".
  - `confirming`: quem recebeu voto no 1º, com a contagem e "Remover como candidato", e "Iniciar 2º escrutínio" (ou "Reiniciar cargo" se não sobrou ninguém).
  - Depois do 2º ou 3º: contagem por candidato, a meta ("6 de 10 necessários") e o resultado. Sem vencedor no 2º: "Iniciar 3º escrutínio".
  - `tiebreak`: "Escolher o mais velho" entre os empatados.
  - `decided`: "Eleito(a): fulano".
- Rodapé: "Aplicar diretoria" (avisa se faltar Presidente ou Vice) e a ata.
- Os resultados aparecem só nesta tela (própria para projetar).

**Voto (web, `/votar/[id]`)**
- Sem escrutínio aberto: "Aguardando o diretor iniciar".
- 1º escrutínio: lista de todos os membros com busca por nome, mais Branco.
- 2º e 3º: só os candidatos que restaram, mais Branco.
- Depois de votar: "Seu voto foi registrado" com o código do comprovante.
- Entrada: "Entrar com Google" ou "Entrar com e-mail e senha"; conta nova é cadastrada automaticamente; se a conta não traz nome, a tela pede só o nome.

**App Flutter**
- Menu "Eleições" (para diretores): lista, criação (sociedade, título, data e hora, cargos), botão que abre a condução na web e a ata, que mostra os escrutínios de cada cargo (contagem, quem foi removido e o eleito).

## 8. Segurança e regras do Firestore

Bloco `elections`, aditivo; o cliente não escreve nada:
- `elections/{id}`: `get` público (a página de voto o lê antes do login; só guarda título, nome da sociedade, status e cargos). `list`: só quem está em `directorIds` (a consulta filtra por `directorIds`). Nenhuma escrita pelo cliente.
- `rounds`: leitura para qualquer usuário autenticado (as opções são nomes de membros, necessárias para votar).
- `cargos`: leitura só dos diretores da eleição.
- `voters`: o eleitor lê só o próprio; os diretores leem todos.
- `voted`: o eleitor lê só o próprio; os diretores leem todos (para "quem falta votar").
- `events`: leitura só dos diretores.
- `ballots`: nenhuma leitura nem escrita pelo cliente.

As Functions conferem `directorIds`, usam transações, tornam o voto idempotente e recusam sessão anônima. Elas não dependem mais de `is_admin`.

### Riscos aceitos
1. A regra de `societies` permite que o criador ou qualquer admin edite a diretoria; quem se marcar `is_admin` no próprio documento (regra de `users`, que não é apertada por decisão anterior) poderia se colocar na diretoria e passar a conduzir eleições dessa sociedade.
2. O sigilo vale contra a interface e contra os diretores. Quem tivesse acesso administrativo bruto ao Firestore poderia tentar casar `voted` com `ballots` pelo horário interno de criação dos documentos. Mitigado com ids aleatórios e sem timestamps nos votos, mas não eliminado. Os diretores veem a ordem em que as pessoas votaram, não o conteúdo.
3. Se a resposta do voto se perder na rede, o recibo não pode ser reexibido, porque não pode ficar ligado ao eleitor.
4. Quem entra pela página de voto vira usuário pendente do app; o admin vai ver esses nomes na lista de Pessoas.
5. Quem está saindo da diretoria conduz a própria eleição, como no rito presencial.
6. Quem não tem Google nem e-mail e senha não consegue votar pelo próprio celular na v1.

## 9. Erros e casos de borda

- Voto em escrutínio fechado ou eleição encerrada: recusado com mensagem clara.
- Voto repetido: devolve "já votou", sem duplicar.
- Eleitor pendente, recusado ou fora da lista: recusado.
- Ação do diretor fora da fase certa (por exemplo iniciar o 2º escrutínio sem candidatos): recusada com a razão.
- Diretor de **outra** sociedade chamando qualquer ação: recusado.
- Diretoria da sociedade em formato antigo (lista não vazia) ao aplicar: recusada, para não perder ninguém.
- Divergência entre `voted` e `ballots` ao encerrar: registrada no log e destacada no resultado.

## 10. Testes

- **Função pura de decisão do escrutínio**, em tabela: limiar de 50% + 1 por número de presentes, empate no topo, só brancos, candidato único, 2º e 3º escrutínios.
- **Integração no emulador do Firestore**: diretor da sociedade pode, diretor de outra não, cada passagem de fase, voto único e concorrente, encerramento concorrente com voto, opções do 1º escrutínio sem os já eleitos.
- **Regras no emulador**: quem lê e quem escreve cada coleção.
- **Web (Vitest)**: estados da tela de condução e da tela de voto.
- **Flutter**: modelos, lista de eleições e ata.

## 11. Passos manuais

- Confirmar que o provedor **Google** está ativo no Firebase Auth (o app já usa) e **não** ativar o login Anônimo.
- Deploy só das Functions de eleição e das regras, com confirmação antes (histórico de problemas com regras).
- Novo build do app nas lojas (dependência `cloud_functions`, menu de eleições e o 2º Secretário).
- O login Google funciona só nos domínios autorizados do Firebase (`ipe-ensino.vercel.app`); previews da Vercel validam só o build.

## 12. O que já existe e muda

- Mantém: identidade e check-in, voto secreto e voto único, gatilho do contador, página de voto (entrada e comprovante), regras de `ballots`.
- Reescreve: rodadas com candidatos pré-cadastrados e maioria simples viram escrutínios; abrir e encerrar rodada; apuração; regras de acesso por diretoria; criação pelo app via Function.
- Remove: as abas de condução do app (Presentes, Cargos) e a gravação direta de eleições e candidatos pelo cliente.
- Acrescenta: tela web de condução com QR, o 2º Secretário e a biblioteca de QR no portal.

## 13. Fora da v1

Data de nascimento no cadastro (o mais velho é escolhido pelo diretor), cronômetro de votação, envio do link por WhatsApp, voto assistido para quem não tem Google nem e-mail, reabrir um cargo decidido, ata em PDF, QR rotativo, assembleias gerais (muita gente), notificações para o diretor e App Check.
