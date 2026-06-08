# Design: app-ipe GitHub Public Release

**Data:** 2026-06-08  
**Objetivo:** Preparar o repositório para ser público no GitHub, com segurança e documentação adequadas para uma equipe pequena e confiável de colaboradores.

---

## Contexto

O app-ipe é um aplicativo Flutter de gestão eclesiástica da Igreja Presbiteriana no Estreito (IPE), em produção nas lojas Apple App Store e Google Play Store. O repositório já existe em `github.com/arcenojackson/app-ipe` (atualmente privado). A intenção é abrir o código com MIT License para uma equipe pequena de colaboradores confiáveis.

---

## Seção 1: Segurança

### Problemas identificados

| Arquivo | Problema | Ação |
|---|---|---|
| `lib/src/core/config/app_secrets.dart.example` | Contém YouTube API key real (`AIzaSyAmdQS8...`) | Substituir por placeholder |
| `lib/firebase_options.dart` | Chaves reais do Firebase de produção; rastreado pelo git | Gitignore + `git rm --cached` + criar `.example` |
| `android/app/google-services.json` | Config Firebase Android de produção; rastreado pelo git | Gitignore + `git rm --cached` + criar `.example` |
| `ios/Runner/GoogleService-Info.plist` | Config Firebase iOS de produção; rastreado pelo git | Gitignore + `git rm --cached` + criar `.example` |

### Decisões

- `firebase_options.dart`, `google-services.json` e `GoogleService-Info.plist` são removidos do tracking e gitignored. Colaboradores regeneram esses arquivos usando o FlutterFire CLI com seu próprio projeto Firebase.
- `app_secrets.dart` (que contém o YouTube key real) já está no `.gitignore` — fica como está.
- `app_secrets.dart.example` terá a chave real substituída por `YOUR_YOUTUBE_API_KEY_HERE`.
- `plexels_key.txt` já está no `.gitignore` — fica como está.
- Os workflows existentes (`auto-pr.yml`, `notion-to-branch.yml`) usam GitHub Secrets — nenhum dado hardcoded, podem permanecer.

### Arquivos `.example` a criar

- `lib/firebase_options.dart.example` — estrutura real do arquivo com valores substituídos por placeholders
- `android/app/google-services.json.example` — estrutura real com valores substituídos
- `ios/Runner/GoogleService-Info.plist.example` — estrutura real com valores substituídos

---

## Seção 2: Arquivos do Repositório

### `LICENSE`
MIT License com nome "Jackson Felipe Arceno" e ano 2026.

### `README.md`
Reescrita completa substituindo o boilerplate Flutter. Seções:
1. **Header** — Nome do projeto, descrição breve, badges (license, flutter)
2. **Sobre o projeto** — O que é o app-ipe, para quem é, stack (Flutter + Firebase)
3. **Módulos principais** — Lista dos módulos (Auth, Membros, Eventos, Calendário, Chat, ELO, Sociedades, Biblioteca Musical, Avaliações, Holyrics, Notificações)
4. **Setup para Colaboradores** — Passo a passo:
   - Pré-requisitos (Flutter SDK, Firebase CLI, FlutterFire CLI)
   - Clone do repositório
   - Criação e configuração do projeto Firebase
   - Geração dos arquivos de config (`flutterfire configure`)
   - Configuração de `app_secrets.dart` a partir do `.example`
   - `flutter pub get`
   - Rodar o app
5. **Contribuindo** — Link para `CONTRIBUTING.md`
6. **Licença** — MIT

### `CONTRIBUTING.md`
- Fluxo de branches: `feat/`, `fix/`, `chore/`
- PR process: branch → PR → review → merge para `master`
- Checklist de PR (já existe template em `.github/pull_request_template.md`)
- Como reportar bugs (link para issue templates)
- Convenções de commit (Conventional Commits: `feat:`, `fix:`, `chore:`, etc.)

### Issue Templates (`.github/ISSUE_TEMPLATE/`)
- `bug_report.md` — template com campos: descrição, passos para reproduzir, comportamento esperado, screenshots, versão do app
- `feature_request.md` — template com campos: problema que resolve, solução proposta, alternativas consideradas

---

## Seção 3: O que NÃO muda

- Workflows `.github/workflows/` — ficam como estão
- `firestore.rules` — pode ficar público (são as regras de segurança, não secrets)
- `functions/` — sem secrets hardcoded, usa Firebase admin SDK com credenciais de ambiente
- `CLAUDE.md` — já está no `.gitignore` via `.claude/`
- `.superpowers/` — já está no `.gitignore`

---

## Ordem de execução

1. Corrigir `app_secrets.dart.example` (substituir chave real)
2. Criar arquivos `.example` para firebase_options, google-services e GoogleService-Info
3. Atualizar `.gitignore` com os novos padrões
4. `git rm --cached` nos 3 arquivos Firebase
5. Criar `LICENSE`
6. Reescrever `README.md`
7. Criar `CONTRIBUTING.md`
8. Criar issue templates
9. Commit único com todas as mudanças
