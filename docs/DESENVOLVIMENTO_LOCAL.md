# Desenvolvimento local

Guia completo para rodar o App IPE (app Flutter, portal web e backend) **somente na sua máquina**, sem tocar na produção. Serve para pessoas e para agentes de IA (o roteiro resumido para agentes está no [`AGENTS.md`](../AGENTS.md)).

## Como funciona

```
 Flutter (Chrome / Android / iOS)  ─┐
                                    ├─►  Firebase Emulators (projeto "demo-ipe")
 Portal Next.js (localhost:3000)   ─┘     ├─ Auth       :9099
                                          ├─ Firestore  :8080
                                          ├─ Storage    :9199
                                          └─ Functions  :5001  (código de functions/)
```

- O projeto `demo-ipe` não existe na internet. O prefixo `demo-` faz o Firebase CLI recusar qualquer acesso a serviços reais.
- O app Flutter, com `--dart-define=USE_EMULATOR=true`, usa opções fictícias embutidas no código (`local_firebase_options.dart`) e conecta só nos emuladores. Sem a flag, a configuração local **recusa iniciar**.
- O portal liga os emuladores com `NEXT_PUBLIC_USE_EMULATORS=true` (já definido no `web-portal/.env.local` criado pelo setup).
- Os scripts de manutenção de `functions/scripts/` só rodam com emulador; para produção exigem `--prod` (só mantenedores).
- Os dados vêm de `functions/scripts/seed-local.ts` — tudo fictício.

## 1. Pré-requisitos

| Ferramenta | Versão | Para quê |
|---|---|---|
| Git | qualquer | clonar e versionar |
| Node.js | **22+** | scripts, Functions, portal |
| JDK | **21+** | exigido pelos emuladores do Firebase (Firestore/Storage) |
| Flutter | Dart **3.9.2+** (Flutter 3.35+) | o app |
| Chrome | atual | rodar o app na web (caminho mais leve) |
| Android Studio | opcional | emulador Android |
| Xcode (só macOS) | opcional | simulador iOS |

> ⚠️ O JDK **17 não serve**: o Firebase CLI 15 aborta com `no longer supports Java version before 21`. É o problema mais comum em máquinas que já têm Java.

### Windows

No PowerShell:

```powershell
winget install Git.Git
winget install OpenJS.NodeJS.LTS
winget install EclipseAdoptium.Temurin.21.JDK
```

- **Flutter:** siga o [guia oficial para Windows](https://docs.flutter.dev/get-started/install/windows) e coloque `flutter\bin` no PATH.
- **Modo Desenvolvedor:** o Flutter precisa de symlinks. Execute `start ms-settings:developers` e ative.
- **PowerShell bloqueando `npm`:** rode uma vez `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.
- **Android (opcional):** instale o [Android Studio](https://developer.android.com/studio), abra-o uma vez para baixar o SDK, crie um emulador (Device Manager) e aceite as licenças com `flutter doctor --android-licenses`.
- **Firewall:** na primeira execução o Windows pergunta se o Java/Node podem receber conexões. Permita apenas em **redes privadas**.

### macOS

```bash
brew install node@22
brew install --cask temurin@21
```

- **Flutter:** [guia oficial para macOS](https://docs.flutter.dev/get-started/install/macos).
- **iOS (opcional):** instale o Xcode pela App Store, rode `sudo xcode-select --switch /Applications/Xcode.app` e abra um simulador.
- **Android (opcional):** igual ao Windows (Android Studio).

Depois de instalar tudo, **abra um terminal novo** e confira:

```bash
node -v        # v22 ou maior
java -version  # 21 ou maior
flutter --version
```

## 2. Primeira execução

```bash
git clone https://github.com/arcenojackson/app-ipe.git
cd app-ipe
npm run doctor   # lista o que falta e como resolver
npm run setup    # instala tudo e cria os arquivos locais
```

O `npm run setup` é seguro para repetir: **nunca sobrescreve** arquivos que já existem. Ele:

1. instala dependências (raiz, `functions/`, `web-portal/`) e roda `flutter pub get`;
2. compila as Functions;
3. cria, se ainda não existirem, os arquivos ignorados pelo git:
   `lib/firebase_options.dart` (stub local), `android/app/google-services.json` e `ios/Runner/GoogleService-Info.plist` (fictícios, só para o projeto compilar),
   `lib/src/core/config/app_secrets.dart` (chaves vazias) e `web-portal/.env.local` (modo emulador).

## 3. Rotina de desenvolvimento

**Terminal 1** — backend local:

```bash
npm run dev
```

Compila as Functions (com recompilação automática ao salvar), sobe os emuladores e popula os dados. Quando aparecer `Ambiente local no ar`, está pronto. `Ctrl+C` encerra tudo.

- `npm run dev -- --portal` também inicia o portal web em http://localhost:3000.
- `npm run dev:persist` guarda os dados em `.emulator-data/` entre execuções (apague a pasta para recomeçar).
- Os dados resetam a cada `npm run dev` comum — é proposital: o estado é sempre reproduzível.
- A interface web dos emuladores (inspecionar Firestore/Auth) fica em http://127.0.0.1:4000.

**Terminal 2** — o app:

```bash
npm run app
```

### Contas de teste (senha `senha123`)

| E-mail | Perfil |
|---|---|
| `admin@ipe.test` | administrador + curador do ensino |
| `curador@ipe.test` | curador do ensino |
| `professor@ipe.test` | professor do ensino |
| `membro@ipe.test` | membro comum |
| `louvor@ipe.test` | membro da equipe de louvor |
| `pendente@ipe.test` | cadastro aguardando aprovação |

Também dá para criar contas novas pelo próprio app.

### Onde rodar o app

| Alvo | Comando | Observações |
|---|---|---|
| **Chrome** (recomendado para começar) | `npm run app` | Não exige Android Studio nem Xcode. Alguns recursos nativos (push, partes do layout) diferem do celular. |
| **Emulador Android** | `flutter emulators --launch <id>` e depois `npm run app -- -d emulator-5554` | O host dos emuladores vira `10.0.2.2` automaticamente. HTTP local é liberado só no build debug. |
| **Simulador iOS** (macOS) | `open -a Simulator` e `npm run app -- -d ios` | Usa `127.0.0.1`. |
| **Celular físico** | `EMULATOR_HOST=192.168.x.x npm run app -- -d <id>` | Celular e computador na mesma rede; use o IP do computador. No Windows PowerShell: `$env:EMULATOR_HOST="192.168.x.x"; npm run app -- -d <id>`. |

Veja os dispositivos com `flutter devices`. Argumentos extras depois de `npm run app --` vão direto ao `flutter run`.

### Portal web

`npm run dev -- --portal` (ou, depois dos emuladores no ar, `cd web-portal && npm run dev`). O `.env.local` já aponta para os emuladores. Entre com `curador@ipe.test` / `senha123`.

## 4. Testes e qualidade

```bash
flutter analyze
dart format lib test            # nunca "dart format ." na raiz
flutter test

cd functions && npm run lint && npm run build && npm test
cd web-portal && npm run lint && npm run typecheck && npm test
```

Testes que sobem emuladores próprios (precisam de JDK 21, não precisam do `npm run dev` ligado):

```bash
cd rules-tests && npm install && npm test        # regras do Firestore e Storage
cd functions && npm run test:integration         # eleições, contra o Firestore emulado
```

## 5. O que não existe localmente

- **Push (FCM), Analytics e Crashlytics** — desligados no modo emulador.
- **Login com Google e Apple** — botões ocultos; use e-mail e senha.
- **Funções agendadas** (lembretes de liturgia, oração e ELO; fechamento automático de eleições) — dependem do emulador de Pub/Sub, que não é iniciado. As demais Functions (gatilhos do Firestore e chamadas HTTP/callable) rodam normalmente.
- **Chaves do YouTube e do Pexels** — opcionais. Sem elas só a busca de vídeos/imagens fica inativa. Para testar a sua, defina a variável `PEXELS_API_KEY` antes de `npm run app`, ou edite o `app_secrets.dart` local (ignorado pelo git).
- **Holyrics** — exige um servidor Holyrics na sua rede.

## 6. Garantias de isolamento

- Projeto `demo-*`: o Firebase CLI bloqueia serviços reais.
- Os scripts locais removem `GOOGLE_APPLICATION_CREDENTIALS` e `FIREBASE_TOKEN` e apontam o gcloud para uma pasta vazia ao iniciar os emuladores.
- Scripts de `functions/scripts/` abortam sem emulador; produção só com `--prod`.
- As Functions, no emulador, usam bucket `demo-ipe` e apontam o portal para `localhost`.
- Não faça `firebase login`, `flutterfire configure` nem `firebase deploy`. Se já tem login no Firebase/gcloud na máquina, tudo bem: os scripts ignoram essas credenciais — mas nunca use `--project app-ipe`.

## 7. Resolução de problemas

| Sintoma | Solução |
|---|---|
| `firebase-tools no longer supports Java version before 21` | Instale o JDK 21+ e abra um terminal novo. `java -version` deve mostrar 21 ou mais. Com várias versões de Java, ajuste `JAVA_HOME`. |
| `Porta 8080 (firestore) já está em uso` | Há outro programa (ou emuladores antigos) na porta. Feche-o. No macOS/Linux: `lsof -i :8080`; no Windows: `netstat -ano \| findstr :8080`. |
| App mostra erro pedindo `USE_EMULATOR` | O app foi iniciado sem a flag. Use `npm run app`. |
| Login falha com "usuário não encontrado" | Os emuladores reiniciaram sem dados ou o seed não rodou. Rode `npm run seed` (com `npm run dev` ligado). |
| Usuário sem permissões de ensino logo após mudar o papel | Saia e entre de novo para renovar o token (as claims são atualizadas por uma Function). |
| App no Android não conecta | Confirme que `npm run dev` está ligado e que está usando `npm run app` (usa `10.0.2.2`). Em celular físico defina `EMULATOR_HOST`. |
| `flutter pub get` falha no Windows por link simbólico | Ative o Modo Desenvolvedor. |
| `npm` bloqueado no PowerShell | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`. |
| `FirebaseMessagingError: Permission denied on resource project demo-ipe` no log das Functions | Esperado: o push (FCM) não existe localmente. A Function termina normalmente; ignore. |
| Warning "Application Default Credentials detected" ao subir emuladores | Esperado se você já usou o gcloud. É inofensivo: o gcloud é apontado para uma pasta vazia e o projeto é `demo-ipe`. |
| Quero recomeçar do zero | `Ctrl+C`, apague `.emulator-data/` (se usou `dev:persist`) e rode `npm run dev` de novo. |

Para um diagnóstico completo: `npm run doctor` (ou `npm run doctor -- --json`).

## 8. Para mantenedores

- A configuração de produção (`flutterfire configure`, `google-services.json` real etc.) continua funcionando e **não** é afetada: o modo emulador ignora esses arquivos. Em celular, o `google-services.json` real ainda inicia o app nativo; para testes locais em Android/iOS prefira trocar temporariamente pelos arquivos de `scripts/local/templates/` (ou use o Chrome).
- Scripts de manutenção em produção: `cd functions && npm run seed-tags -- --prod` (idem para `backfill-*`, `seed-plan` e `purge-library`). Sem `--prod` e sem emulador eles abortam.
- Publicação nas lojas, deploy e regras: [`docs/mantenedores/`](mantenedores/).
