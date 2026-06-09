[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)

# App IPE

Aplicativo de gestão eclesiástica para a **Igreja Presbiteriana no Estreito (IPE)**, Florianópolis/SC. Em produção nas lojas App Store e Google Play.

## Stack

- **Frontend:** Flutter (iOS & Android)
- **Backend:** Firebase (Auth, Firestore, Cloud Functions, FCM, Storage)
- **Idioma:** Português (pt_BR)

## Módulos

| Módulo | Descrição |
|---|---|
| Auth & Settings | Autenticação Firebase (e-mail, Google, Apple Sign-In) e configurações do usuário |
| Membros | Gestão de membros da igreja |
| Eventos/Cultos | Criação e gestão de eventos e cultos |
| Calendário | Visualização de agenda em calendário |
| Chat com menções | Mensagens por evento/sociedade com suporte a @menções |
| ELO | Gestão da equipe de louvor e escalas |
| Sociedades | Grupos e sociedades da igreja |
| Biblioteca Musical | Gerenciamento do repertório musical |
| Avaliações Musicais | Sistema de avaliação e rating de músicas |
| Holyrics | Integração com o software de projeção Holyrics |
| Notificações | Push notifications via FCM com preferências por tipo |

## Configuração para Contribuidores

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versão estável mais recente)
- [Node.js](https://nodejs.org) (para Firebase CLI)
- Conta Google (para criar projeto Firebase)
- Conta [Pexels](https://www.pexels.com/api/) (para funcionalidades de imagem)

### Passo a passo

1. **Instalar Flutter SDK**

   Siga o guia oficial: https://docs.flutter.dev/get-started/install

2. **Instalar Firebase CLI**

   ```bash
   npm install -g firebase-tools
   firebase login
   ```

3. **Instalar FlutterFire CLI**

   ```bash
   dart pub global activate flutterfire_cli
   ```

4. **Clonar o repositório**

   ```bash
   git clone https://github.com/arcenojackson/app-ipe.git
   cd app-ipe
   ```

5. **Criar projeto Firebase**

   Acesse [console.firebase.google.com](https://console.firebase.google.com) e crie um novo projeto. Habilite os seguintes serviços:
   - Authentication (e-mail/senha, Google, Apple)
   - Firestore Database
   - Storage
   - Cloud Messaging (FCM)

6. **Configurar Firebase no projeto**

   Execute na raiz do projeto:

   ```bash
   flutterfire configure
   ```

   Isso irá gerar automaticamente:
   - `lib/firebase_options.dart`
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`

   > Os arquivos de exemplo (`.example`) em cada local descrevem a estrutura esperada.

7. **Configurar segredos do app**

   ```bash
   cp lib/src/core/config/app_secrets.dart.example lib/src/core/config/app_secrets.dart
   ```

   Edite `app_secrets.dart` e preencha sua chave da YouTube Data API v3.
   Para obter uma chave: [console.cloud.google.com/apis/credentials](https://console.cloud.google.com/apis/credentials) — habilite "YouTube Data API v3".

8. **Instalar dependências Flutter**

   ```bash
   flutter pub get
   ```

9. **Rodar o app**

   Obtenha uma chave da API Pexels em https://www.pexels.com/api/ e rode:

   ```bash
   flutter run --dart-define=PEXELS_API_KEY=sua_chave_pexels_aqui
   ```

10. **Build de release**

    ```bash
    # Android
    flutter build appbundle --release --dart-define=PEXELS_API_KEY=sua_chave_pexels_aqui

    # iOS (requer macOS + Xcode)
    flutter build ios --release --dart-define=PEXELS_API_KEY=sua_chave_pexels_aqui
    ```

## Firebase Functions

O backend roda em Cloud Functions (TypeScript). Para deploy:

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

Para testar localmente:

```bash
firebase emulators:start --only functions
```

## Contribuindo

Veja [CONTRIBUTING.md](CONTRIBUTING.md) para o guia completo de contribuição, padrões de código e fluxo de Pull Requests.

## Licença

Este projeto está licenciado sob a [MIT License](LICENSE).
