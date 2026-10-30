# Convenções de código para agentes

> O arquivo principal é o [`AGENTS.md`](../AGENTS.md) na raiz (regras de ambiente e setup). Este documento complementa com comandos e estilo.

Este arquivo orienta agentes automatizados (e humanos) a trabalhar no repositório, descrevendo comandos de build/linters/test, convenções de código e boas práticas. Aborda tanto o frontend Flutter quanto o backend Functions em Node/TypeScript presentes neste projeto.

1) Build, lint e teste (recomendações rápidas)
- Flutter (frontend)
  - Inicializar dependencies: `flutter pub get`
  - Analisar código: `flutter analyze`
  - Executar testes: `flutter test`
  - Executar apenas um arquivo de teste: `flutter test path/to/file_test.dart --plain-name "nome do teste"` (verifique `flutter test --help` para opções de filtro de nome)
  - Build para Android/iOS/web (depende do alvo):
    - Android: `flutter build apk --debug` / `--release`
    - iOS: `flutter build ios --debug` / `--release` (requer macOS e setup de Xcode)
    - Web: `flutter build web` (produca os artefatos em build/web/)

- Firebase Functions (backend)
  - Instalar dependencias: `cd functions && npm install`
  - Linting: `cd functions && npm run lint`
  - Build (TypeScript -> JavaScript): `cd functions && npm run build`
  - Emulators (para testes locais): `firebase emulators:start --only functions`
  - Deploy de funcoes: `firebase deploy --only functions`
  - Observacao: para testes locais de integracao, veja `functions/src/index.ts` e use `firebase-functions-test` conforme as regras do projeto.

- Execucao paralela (opcional):
  - Em ambientes com mais de uma tarefa, rode em paralelo onde possivel:
    - `bash -lc 'flutter pub get & npm ci --prefix ./functions'`

2) Convenções de estilo de código
- Visao geral: o código segue as regras do Dart (Flutter) com flutter_lints e do TypeScript com ESLint (google style) para o backend.

- Dart (Flutter)
  - Imports: organize em grupos (dart:core, outros pacotes, imports de pacote, imports locais) e ordene alfabeticamente dentro de cada grupo.
  - Tipagem: use null-safety; prefira tipos explícitos sobre dynamic; marque parâmetros obrigatórios com `required`.
  - Widgets e classes: use UpperCamelCase para nomes de classes e constantes; lowerCamelCase para variáveis e métodos.
  - Constância: use `const` onde possível; utilize `final` para valores imutáveis calculados em runtime.
  - Erros: capture exceções específicas quando possível; não silencie exceções genéricas sem log. Registre falhas com informações de contexto.
  - Formatação: rode `flutter format .` (ou `dart format .`) antes de commit; siga análise com `flutter analyze`.
  - Tela de testes: use `group`, `test` e `expect` de forma clara; mantenha mocks simples.

- TypeScript (Functions)
  - Imports: mantenha ordem por origem (core/stdlib, external, internal); use alias quando necessário; remova imports não usados.
  - Tipos: prefira `unknown`/interfaces em vez de `any`; use `interface` para formas de dados públicas; `type` para unions quando adequado.
  - Nomes: nomes descritivos; use PascalCase para classes/constructors, camelCase para variáveis e funções; exports nomeados.
  - Erros: utilize try/catch com mensagens descritivas; não empurre erros silenciosamente; registre contexto relevante.
  - Formatacao: rode `npm run lint` e `npm run build`; use ESLint com as regras do Google (confg em `.eslintrc.js`).
  - Testes: para funções, use `firebase-functions-test` onde aplicável; mantenha mocks simples e previsíveis.

3) Boas práticas
- Não exponha segredos no código (vars/keys devem estar em environments ou .env; ignore arquivos sensíveis no git).
- Documente APIs e funções públicas com comentários claros (JSDoc/TS docs).
- Evite duplicação de lógica; considere utilitarios comuns para padrões repetidos (validação, formatação, etc).
- Considere adicionar pre-commit hooks para rodar lint/format antes de commit (opcional).

4) Estrutura do repositório e dependências
- Flutter: pubspec.yaml define dependencias, assets e configurações. Use `flutter pub get` para sincronia.
- Functions: `functions/package.json` define scripts (lint, build, serve, deploy). ESLint com TypeScript e Google style é utilizado.
- Analysis: `analysis_options.yaml` usa `package:flutter_lints/flutter.yaml` e impõe lintes padrões.
- SO: Não altere os nomes de rotas/colecoes Firestore sem atualizacoes coerentes no frontend/backend.

5) Regras de Copilot e Cursor
- Não há regras de Cursor/Copilot neste repositório (nenhum diretório .cursor ou .cursorrules presentes).
- Nenhum override especial para CopilotInstrs. Se surgirem, inclua no AGENTS.md conforme necessidade.

6) Exemplo de pipeline simples
- Instalar, analisar, testar e construir em sequência:
  - Flutter: `flutter pub get && flutter analyze && flutter test && flutter build apk --release`
  - Functions: `cd functions && npm install && npm run lint && npm run build && firebase emulators:start --only functions`

7) Observacoes finais
- Este AGENTS.md deve orientar agentes autonomos do repositório; mantenha-o atualizado com mudanças relevantes no fluxo de build/test/estilo.
- Caso haja mudanças de stack (novas linguagens, novas ferramentas), atualize as seções correspondentes.
8) Cursor e Copilot rules
- Cursor rules: nao detectados (nao ha diretorios .cursor/rules/ ou .cursorrules no repositorio).
- Copilot rules: nao ha arquivo em .github/copilot-instructions.md; nenhuma diretriz adicional aplicada.
