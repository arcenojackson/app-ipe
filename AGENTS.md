# AGENTS.md — instruções para agentes de IA (e pessoas)

Este é o arquivo canônico para qualquer agente (Claude Code, Codex, Cursor, Gemini, Copilot…) que trabalhe neste repositório. O `CLAUDE.md` aponta para cá.

**App IPE** — app de gestão da Igreja Presbiteriana no Estreito (Florianópolis/SC). Flutter (app) + Firebase (Auth, Firestore, Functions, Storage) + portal web Next.js (`web-portal/`). Idioma do produto: pt-BR.

## 1. Regras invioláveis (leia antes de qualquer comando)

Existe **um único Firebase de produção** (`app-ipe`) e um único deploy de produção na Vercel. Quem contribui **nunca** os usa.

1. **Nunca** conecte a produção: nada de `firebase login` para o projeto `app-ipe`, `firebase deploy`, `flutterfire configure`, `gcloud auth application-default login`, nem copiar chaves/arquivos reais (`google-services.json`, `GoogleService-Info.plist`, `.env` de produção) de ninguém.
2. Todo desenvolvimento roda nos **emuladores locais** com o projeto fictício `demo-ipe` (`npm run dev`). O prefixo `demo-` impede o Firebase CLI de acessar serviços reais.
3. **Nunca** use `--prod` nos scripts de `functions/scripts/` e nunca rode `firebase ... --project app-ipe`. Esses scripts abortam sozinhos sem emulador; não contorne.
4. **Nunca** rode o app Flutter sem `--dart-define=USE_EMULATOR=true`. Use `npm run app`, que já passa tudo.
5. **Nunca** faça commit de: `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `lib/src/core/config/app_secrets.dart`, `web-portal/.env.local`, `.emulator-data/`, chaves de API, tokens ou senhas. Estão no `.gitignore`; se algum aparecer no `git status`, pare e investigue.
6. **Nunca** use dados reais de membros (LGPD). Só os dados fictícios do seed (`functions/scripts/seed-local.ts`).
7. Deploy, publicação nas lojas, regras de produção e variáveis da Vercel são **exclusivos dos mantenedores** (veja `docs/mantenedores/`). Contribuições chegam por Pull Request para `main`.

Se uma tarefa parecer exigir quebrar uma dessas regras, **pare e pergunte** a quem está usando você.

## 2. Playbook: configurar uma máquina do zero

Siga na ordem e **confirme cada passo antes do próximo**. Sistemas: Windows (principal), macOS e Linux. Instruções detalhadas por sistema: `docs/DESENVOLVIMENTO_LOCAL.md`.

1. **Clone** o repositório e entre na pasta (`cd app-ipe`).
2. **Instale os pré-requisitos** que faltarem (peça confirmação antes de instalar software):
   | Ferramenta | Versão | Windows | macOS |
   |---|---|---|---|
   | Git | qualquer | `winget install Git.Git` | `xcode-select --install` |
   | Node.js | **22+** | `winget install OpenJS.NodeJS.LTS` | `brew install node@22` |
   | JDK | **21+** (obrigatório: o Firebase CLI 15 recusa o Java 17) | `winget install EclipseAdoptium.Temurin.21.JDK` | `brew install --cask temurin@21` |
   | Flutter | Dart **3.9.2+** (Flutter 3.35+) | https://docs.flutter.dev/get-started/install/windows | https://docs.flutter.dev/get-started/install/macos |
   Depois de instalar, **abra um terminal novo** (o PATH só atualiza em terminais novos).
3. Rode `npm run doctor` (use `npm run doctor -- --json` para saída estruturada). Ele precisa terminar com "Máquina pronta". Cada pendência traz o comando para resolver.
4. Rode `npm run setup`. É idempotente e **nunca sobrescreve** arquivos existentes. Ele instala as dependências (raiz, `functions/`, `web-portal/`, `flutter pub get`), compila as Functions e cria os arquivos locais ignorados pelo git.
5. Em um terminal: `npm run dev` — sobe Auth/Firestore/Storage/Functions emulados e popula dados fictícios. Espere a linha `Ambiente local no ar`. Deixe rodando.
6. Em outro terminal: `npm run app` — abre o app no Chrome, já apontado para os emuladores.
7. Entre com uma conta de teste (senha `senha123`): `admin@ipe.test`, `curador@ipe.test`, `professor@ipe.test`, `membro@ipe.test`, `louvor@ipe.test`, `pendente@ipe.test`.
8. (Opcional) Portal web: `npm run dev -- --portal` e abra http://localhost:3000.

**Quer rodar em emulador Android ou simulador iOS?** Siga a seção 2.1 abaixo.

**Critério de pronto:** login funciona, o app mostra 3 cultos na Agenda e aparece o aviso "Running in emulator mode" no rodapé do app web.

## 2.1 Playbook: emulador Android / simulador iOS

Só depois do playbook da seção 2. Detalhes e solução de problemas: `docs/DESENVOLVIMENTO_LOCAL.md` (seção "Emulador Android e simulador iOS").

1. Rode `npm run doctor -- --native --json` e leia os itens `android`, `xcode`, `cocoapods`, `emulators` e `devices`. Mostre ao usuário o que falta e **peça confirmação antes de instalar** qualquer software (Android Studio, Xcode e runtimes são grandes).
2. **Android** (Windows/macOS/Linux): Android Studio instalado e aberto uma vez (baixa o SDK) → `flutter doctor --android-licenses` → criar um emulador no Device Manager → `flutter emulators --launch <id>`.
3. **iOS** (apenas macOS; no Windows não existe): Xcode completo da App Store (`sudo xcode-select --switch /Applications/Xcode.app && sudo xcodebuild -runFirstLaunch`), CocoaPods (`brew install cocoapods`), runtime de simulador baixado → `open -a Simulator`. Mínimo: iOS 15.0.
4. Pegue o id em `flutter devices` e rode, com `npm run dev` já no ar: `npm run app -- -d <id>` (Android: `emulator-5554`; iOS: `ios` ou o id do simulador).
5. **Nunca** substitua `android/app/google-services.json` nem `ios/Runner/GoogleService-Info.plist` por arquivos reais e nunca rode `flutterfire configure`: os fictícios criados pelo `npm run setup` bastam. Rodar pelo Android Studio/Xcode exige `--dart-define=USE_EMULATOR=true`.
6. Critério de pronto: o app abre no emulador, mostra o aviso de ambiente local no login, `admin@ipe.test` / `senha123` entra e a Agenda mostra 3 cultos.

## 3. Comandos do dia a dia

| Ação | Comando |
|---|---|
| Subir tudo (dados resetam a cada start) | `npm run dev` |
| Subir guardando os dados entre execuções | `npm run dev:persist` (pasta `.emulator-data/`; apague para recomeçar) |
| Recarregar os dados de teste com os emuladores no ar | `npm run seed` |
| App no Chrome | `npm run app` |
| App em emulador Android | `npm run app -- -d emulator-5554` (veja `flutter devices`) |
| App em simulador iOS (só macOS) | `npm run app -- -d ios` |
| Celular físico na mesma rede Wi‑Fi | `EMULATOR_HOST=<IP-da-máquina> npm run app -- -d <id>` |
| Diagnóstico | `npm run doctor` (`-- --native` inclui Android/iOS) |

Verificações antes de abrir PR:

```bash
flutter analyze            # sem erros novos
dart format lib test       # só lib/ e test/ (nunca na raiz: pegaria node_modules)
flutter test
cd functions && npm run lint && npm run build && npm test
cd web-portal && npm run lint && npm run typecheck && npm test
```

Todo PR para a `main` roda o CI (`.github/workflows/ci.yml`: Flutter, Functions, Portal web, Regras e integração) com estes mesmos comandos; o PR só pode ser mesclado com o check **CI ok** verde. Rode-os localmente antes de abrir o PR.

Testes que usam emulador (regras do Firestore/Storage e integração) exigem JDK 21:
`cd rules-tests && npm install && npm test` · `cd functions && npm run test:integration`.

## 4. Mapa do repositório

- `lib/` — app Flutter. Módulos em `lib/src/modules/<modulo>/{data,models,presentation}`. Estado com Provider; repositórios injetados em `lib/main.dart`.
  - `lib/src/core/config/app_environment.dart` — alternância produção × emulador (`USE_EMULATOR`).
  - `lib/src/core/config/firebase_config.dart` — inicialização do Firebase; no modo emulador usa `local_firebase_options.dart` e conecta nos emuladores.
- `functions/` — Cloud Functions (TypeScript, Node 22). Entrada `src/index.ts`; módulos `src/teaching/` e `src/elections/`. Scripts de manutenção em `functions/scripts/` (travados para o emulador).
- `web-portal/` — portal Next.js (ensino, fórum, eleições). Em local, `.env.local` liga os emuladores.
- `firestore.rules`, `storage.rules`, `firestore.indexes.json` — regras e índices. Mudanças aqui exigem teste em `rules-tests/` e revisão dos mantenedores.
- `rules-tests/` — testes das regras no emulador.
- `scripts/local/` — orquestração do ambiente local (Node puro, multiplataforma).
- `docs/` — documentação. `docs/mantenedores/` é só para quem publica.

Coleções principais do Firestore: `users`, `services` (eventos/cultos), `societies`, `musics`, `teaching_*`, `forum_*`, eleições. Papéis vêm de `users/{uid}.is_admin` e `teaching_role` (viram *custom claims* via Function `syncTeachingClaimsOnUserWrite`; o seed já grava as claims).

## 5. O que não existe localmente

Aceite estas limitações em vez de tentar contorná-las:

- **Push (FCM)**, Analytics e Crashlytics: desligados no modo emulador. As Functions que enviam push rodam e registram `FirebaseMessagingError: Permission denied on resource project demo-ipe` — é esperado e inofensivo.
- **Login com Google/Apple**: botões ocultos; use e-mail e senha.
- **Funções agendadas** (lembretes de liturgia/oração/ELO, fechamento automático de eleições): não rodam localmente (exigem o emulador de Pub/Sub). Dispare a lógica manualmente se precisar testá-la.
- **Chave do YouTube e do Pexels**: opcionais; sem elas só a busca de vídeos/imagens fica inativa.
- **Holyrics**: precisa de um servidor Holyrics na sua rede; não faz parte do ambiente local.

## 6. Convenções

- Branches: `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`. Commits: Conventional Commits (`feat: …`). Detalhes em `CONTRIBUTING.md`.
- Código em inglês; comentários e documentação em português.
- `main` é protegida: só entra por Pull Request aprovado. Não faça push direto nem `--force`.
- Não adicione dependências sem justificar no PR.
- Não altere `firestore.rules`, `storage.rules`, `.github/` nem `firebase.json` sem avisar no PR (são áreas de revisão obrigatória).

## 7. Armadilhas conhecidas

| Sintoma | Causa e solução |
|---|---|
| `firebase-tools no longer supports Java version before 21` | JDK antigo. Instale o JDK 21 e abra um terminal novo; confirme com `java -version`. |
| `Porta 8080 (firestore) já está em uso` | Outro programa usa a porta (ou emuladores antigos). Feche-o e rode `npm run dev` de novo. |
| App abre e mostra erro "configuração local… USE_EMULATOR" | O app foi iniciado sem a flag. Use `npm run app`. |
| No emulador Android o app não conecta | O host do emulador é `10.0.2.2` (já automático). Em celular físico defina `EMULATOR_HOST`. |
| Usuário logado sem permissões de ensino | As claims só atualizam no próximo token: saia e entre de novo. |
| `npm` bloqueado no PowerShell | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` (uma vez). |
| `flutter pub get` falha por symlinks no Windows | Ative o Modo Desenvolvedor do Windows (`start ms-settings:developers`). |
