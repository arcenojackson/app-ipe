[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.35%2B-blue.svg)](https://flutter.dev)

# App IPE

Aplicativo de gestão eclesiástica da **Igreja Presbiteriana no Estreito (IPE)**, Florianópolis/SC. Em produção na App Store e no Google Play.

Este repositório é aberto para que a equipe de voluntários de tecnologia da igreja possa contribuir. **Todo o desenvolvimento acontece num ambiente local que simula o Firebase: ninguém precisa (nem pode) usar a produção.**

## Stack

- **App:** Flutter (iOS, Android e web)
- **Backend:** Firebase — Auth, Firestore, Cloud Functions (TypeScript), Storage, FCM
- **Portal web:** Next.js (`web-portal/`), hospedado na Vercel
- **Idioma:** Português (pt_BR)

## Módulos

| Módulo | Descrição |
|---|---|
| Autenticação | E-mail e senha, Google e Apple Sign-In |
| Membros | Cadastro e gestão de membros |
| Eventos/Cultos | Criação e gestão de eventos, escalas e liturgia |
| Calendário | Agenda em calendário |
| Chat | Mensagens por evento/sociedade com @menções |
| ELO | Equipe de louvor, escalas e disponibilidade |
| Sociedades | Grupos e diretorias |
| Biblioteca Musical e Avaliações | Repertório e avaliação de músicas |
| Eleições | Eleição de diretoria das sociedades (app + portal) |
| Portal de Ensino | Biblioteca de materiais, plano pedagógico e curadoria (web) |
| Fórum | Discussões do ensino (app + web) |
| Holyrics | Integração com o software de projeção |
| Notificações | Push via FCM com preferências por tipo |

## Início rápido (ambiente local)

Você precisa de **Git, Node.js 22+, JDK 21+ e Flutter** (Dart 3.9.2+). Não precisa de conta Google/Firebase, cartão, nem de qualquer chave.

```bash
git clone https://github.com/arcenojackson/app-ipe.git
cd app-ipe
npm run doctor     # confere o que falta instalar (e diz como instalar)
npm run setup      # instala dependências e cria os arquivos locais
npm run dev        # terminal 1: emuladores Firebase + dados de teste
npm run app        # terminal 2: app Flutter no Chrome
```

Contas de teste (senha `senha123`): `admin@ipe.test`, `curador@ipe.test`, `professor@ipe.test`, `membro@ipe.test`.
Portal web (opcional): `npm run dev -- --portal` → http://localhost:3000.

**Pré-requisitos por sistema**

| | Windows | macOS |
|---|---|---|
| Git | `winget install Git.Git` | `xcode-select --install` |
| Node.js 22+ | `winget install OpenJS.NodeJS.LTS` | `brew install node@22` |
| JDK 21+ | `winget install EclipseAdoptium.Temurin.21.JDK` | `brew install --cask temurin@21` |
| Flutter | [guia oficial (Windows)](https://docs.flutter.dev/get-started/install/windows) | [guia oficial (macOS)](https://docs.flutter.dev/get-started/install/macos) |

Para rodar em **emulador Android** (Android Studio) ou **simulador iOS** (só macOS, Xcode), veja o guia completo: **[docs/DESENVOLVIMENTO_LOCAL.md](docs/DESENVOLVIMENTO_LOCAL.md#emulador-android-e-simulador-ios)** (`npm run doctor -- --native` diz o que falta). Uma IA também consegue configurar isso: peça *"configure o emulador Android/iOS"* e ela segue o `AGENTS.md`. O caminho mais leve é o Chrome, que não exige Android Studio nem Xcode (alguns recursos nativos, como push, não existem na web).

### Usando uma IA para configurar

Se preferir, abra o repositório no Claude Code, Codex, Cursor ou similar e peça: *"configure o ambiente local deste projeto"*. O arquivo [`AGENTS.md`](AGENTS.md) traz o passo a passo, as verificações e as regras de segurança que o agente deve seguir.

## Como funciona o ambiente local

Os **Firebase Emulators** (Auth, Firestore, Storage, Functions) rodam na sua máquina com o projeto fictício `demo-ipe`. O app e o portal conectam neles quando iniciados em "modo emulador"; os scripts já cuidam disso. Os dados de teste (usuários, cultos, sociedades, músicas, tags e plano pedagógico) são recriados a cada `npm run dev`.

O que **não** existe localmente: push (FCM), Analytics/Crashlytics, login Google/Apple, funções agendadas e Holyrics. Detalhes em [docs/DESENVOLVIMENTO_LOCAL.md](docs/DESENVOLVIMENTO_LOCAL.md#5-o-que-não-existe-localmente).

## Estrutura

```
lib/            app Flutter (módulos em lib/src/modules/)
functions/      Cloud Functions (TypeScript)
web-portal/     portal Next.js
rules-tests/    testes das regras do Firestore/Storage
scripts/local/  orquestração do ambiente local (setup, dev, doctor…)
docs/           documentação (docs/mantenedores/ = só para quem publica)
```

## Contribuindo

1. Faça um **fork** do repositório, clone o seu fork e siga o setup acima.
2. Crie uma branch (`feat/…`, `fix/…`) a partir da `main`, desenvolva e teste localmente.
3. Abra um Pull Request do seu fork para `main` — o CI roda e a branch é protegida: exige aprovação de um mantenedor.

Guia completo: [CONTRIBUTING.md](CONTRIBUTING.md). Deploy, publicação nas lojas e regras de produção são feitos pelos mantenedores ([docs/mantenedores/](docs/mantenedores/)).

## Licença

[MIT](LICENSE).
