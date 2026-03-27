# DOCUMENTACAO DO PROJETO ipe_flutter

Este documento fornece uma visão geral do aplicativo, sua arquitetura, dependencias, fluxos de negocio e instrucoes para desenvolvedao e operacao local. O objetivo e facilitar a onboarding de novos integrantes e servir como referencia de alto nivel durante manutencao.

Observacoes
- O projeto e divido entre frontend em Flutter (ipe_flutter) e backend serverless em Firebase Functions (functions/).
- A base de dados e Firestore com collections como usuarios, services (eventos) e societies (associacoes/igrejas), alem de mensagens registradas nos chats.
- Notificacoes push sao enviadas via Firebase Cloud Messaging (FCM) atraves das funcoes do backend.
- Existem documents de apoio ja incluidos no repositorio sob assets/docs, alem de documentos legais na raiz (politicas, guias de publicacao, etc).

\n## Estrutura do Projeto
- /pubspec.yaml: definicoes do projeto Flutter, dependencias, assets e configuracoes de compilacao.
- /functions: Firebase Cloud Functions em Typescript/API Node. Contem triggers de Firestore, funcoes agendadas e a logica de notificacoes.
- /assets: assets do app, incluindo imagens, logos e arquivos markdown com documentacao interna (coerencia doctrinal, guias de publicacao, etc).
- /lib: codigo Flutter (na shell deste patch, o conteudo nao e detalhado aqui).
- /ios / android / web / windows / linux / macos: pastas de plataforma do Flutter.

\n## Tecnologias Principais
- Frontend: Flutter (Dart)
- Backend: Firebase Functions (Node.js + TypeScript)
- Banco de Dados: Firestore
- Autenticacao: FirebaseAuth (com Google Sign-In, Sign in with Apple e outras opcoes)
- Notificacoes: Firebase Cloud Messaging (FCM)
- Geracao de emissao de informes e lembretes via Functions
- Geracao de log e monitoramento via Console do Firebase

\n## Fluxos Principais de Negocio
- Chat e mencoes: quando um usuario e mencionado em uma mensagem, as funcaoes enviam notificacao push para usuarios mencionados. Isso ocorre para eventos (services) e sociedades (societies).
- Lembretes de liturgia e oracao: funcoes agendadas (fridayLiturgyReminder, mondayPrayerMeetingReminder etc) enviam lembretes para as diretorias das sociedades sobre documentos/rotinas do proximo periodo.
- Escalacao de membros: quando usuarios sao adicionados a escalas de eventos, notificacoes sao enviadas com o papel atribuido (dirigente, pregador, equipe de louvor etc).
- Disponibilidade Elo: lembretes de disponibilidade mensal para a equipe Elo.
 - Tratamento de erros: logs mantidos para capturar falhas de envio de notificacoes e invalidade de tokens.

## Contexto Especifico da IPB Estreito
Este aplicativo atende à comunidade da Igreja Presbiteriana do Brasil, bairro Estreito, em Florianópolis (SC). Principais recursos incluem:
- Gestão de membros e equipes locais (cadastro de membros, atribuição de papéis nas liturgias e eventos).
- Comunicação interna via chat para eventos e sociedades, com suporte a menções.
- Agenda de cultos, liturgias, reuniões e atividades, com lembretes automáticos.
- Escalas de serviço (liturgia, pregadores, líderes, equipe de som/imagem, diaconia) com notificações de alterações.
- Gerenciamento de disponibilidade para equipes (ELO) e lembretes mensais.
- Notificações push via FCM com controle de preferências de usuário (disabled_notifications).
- Armazenamento de dados em Firestore (users, services, societies, messages).

\n## Backend: Firebase Functions (resumo tecnico)
- Arquivo principal: functions/src/index.ts (TypeScript)
- Principais triggers:
  - onMessageCreated: dispara quando uma mensagem e criada na collecao services/{eventId}/messages/{messageId}
  - onSocietyMessageCreated: dispara quando uma mensagem e criada na collecao societies/{societyId}/messages/{messageId}
  - fridayLiturgyReminder: agenda sexta as 9h (horario Brasilia) para lembretes de liturgia
  - mondayPrayerMeetingReminder: agenda segunda as 9h para reuniçao de oracao
  - eloAvailabilityReminder: lembrete de disponibilidade para a equipe Elo
- Eventos de escala: onServicePeopleUpdated; onServiceStepsUpdated geram notificacoes para escalados quando a escala ou musicas mudam
- Dependencias do backend: npm, Node 22, TypeScript, firebase-admin, firebase-functions
- Entry point: lib/index.js (transpilado)

\n## Dados (Firestore)
- users/{userId}: dados do usuario, incluindo fcmToken, preferencias de notificacao (disabled_notifications)
- services/{eventId}: dados de evento, including name, date, teams (liturgia, abertural_EBD, etc), people (elo, preacher, lead, diaconia, eloWithInstruments)
- societies/{societyId}: dados de sociedade, com board (diretoria) e possivelmente membros
- services/{eventId}/messages/{messageId} e societies/{societyId}/messages/{messageId}: mensagens de chat
- keys de tokens FCM armazenadas em cada usuario

\n## Configuracao e Execucao Local
- Requisitos: Flutter SDK instalado; Node.js; Firebase CLI; acesso a um projeto Firebase existente (com Firestore e Cloud Messaging configurados).
- Passos iniciais:
  1) Instalar dependencias do Flutter: `flutter pub get` (na raiz: ipe_flutter)
  2) Configurar Firebase no app iOS/Android (google-services.json/GoogleService-Info.plist) conforme a plataforma
  3) Iniciar emuladores: firebase emulators:start (para functions, firestore, auth, etc) se estiver desenvolvendo localmente
  4) Rodar o frontend: `flutter run` (na pasta raiz do app Flutter)
- Backend: editar/instalar dependencias em /functions, depois:
  - `npm install` (na pasta /functions)
  - `npm run build` para compilar TS -> JS
  - `firebase emulators:start --only functions` para testes locais ou `firebase deploy --only functions` para implantacao
- Observacoes: as funcoes esperam acesso a um projeto Firebase com as colecoes mencionadas; tokens FCM sao extraidos de usuarios; habilitacoes de notificacao sao controladas por `disabled_notifications` no usuario.

\n## Desenvolvimento e Contribuicao
- Padrao de commits: manter foco no motivo e impacto; evitar alterar commit if desnecessario
- Padrao de codigo: usar Dart/Flutter e TS conforme as regras de lint ja configuradas nos arquivos de projeto (analysis_options.yaml no Flutter; eslint no Functions)
- Documentacao existente: assets/docs contem coerencia_teologica.md, coerencia_congregacional.md, coerencia_musical.md, ja integrados como assets no pubspec.yaml
- Guias publicacao e privacidade existem na raiz (GUIA_PUBLICACAO.md, POLITICA_PRIVACIDADE.md, etc)
- Arquivos relevantes no repositorio que merecem atualizacao considera-se incluir no PRs/Issues de forma clara

\n## Arquitectura de Alta Nivel (Resumo)
- App Flutter atua como frontend, consumindo dados de Firestore e interagindo com Cloud Functions para tarefas servidoras e notificacoes
- Back-end serverless lida com notificacoes push por meio de FCM, triggers Firestore (onCreate, onUpdate) e agendas de tempo
- Dados estruturados em colecoes: users, services, societies e subcolecoes/messages
- Seguranca e configuracao de notificacoes: random acess e tokens FCM sao protegidos por regras de Firestore (na configuracao real)

\n## Documentacao Relevante ja no Repositorio
- pubspec.yaml: dependencias Flutter, assets, e ambientes
- /assets/docs/: coerencia_teologica.md, coerencia_congregacional.md, coerencia_musical.md
- SIGN_IN_WITH_APPLE_GUIDE.md, GUIA_PUBLICACAO_PLAY_STORE.md, GUIA_PUBLICACAO.md, POLITICA_PRIVACIDADE.md, ATUALIZAR_VERSAO_APP_STORE.md
- /functions/src/index.ts: Implementacao das lógicas de notificacao, triggers, e lembretes
- /functions/package.json: scripts de desenvolvimento e deployment, Node 22
- /README.md: template do Flutter app (ja existente)

\n## Observacoes Finais e Proximos Passos
- Se voce estiver introduzindo novas features, atualize este documento com os fluxos, dados e dependencias novas
- Considere criar um diagrama de arquitetura (frontend, backend, firestore, notificacoes) para facilitar a comunicacao com a equipe
- Facilidade de onboarding: manter documentação atualizada e padronizada ajuda na manutencao de longo prazo
