# Contribuindo com o App IPE

Obrigado pelo interesse em contribuir! Este guia descreve o processo e as convenções adotadas no projeto.

## Antes de começar

Configure o ambiente local seguindo o [README](README.md#início-rápido-ambiente-local) e o [guia de desenvolvimento local](docs/DESENVOLVIMENTO_LOCAL.md). Tudo roda nos emuladores do Firebase (projeto `demo-ipe`) — **ninguém usa a produção**. Se for usar uma IA, ela deve seguir o [`AGENTS.md`](AGENTS.md).

Combinados do projeto:

- Nunca faça `firebase login`/`firebase deploy` para o projeto real, nem peça chaves de produção. Deploy e publicação são dos mantenedores.
- Nunca faça commit de arquivos de configuração local ou segredos (`firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`, `app_secrets.dart`, `.env.local`).
- Use apenas os dados fictícios do seed; nunca dados reais de membros.
- Mudanças em `firestore.rules`, `storage.rules`, `firebase.json`, `.github/` e `functions/` exigem atenção extra na revisão — descreva o impacto no PR.

## Fluxo de branches

Use os seguintes prefixos para nomear suas branches:

| Prefixo | Uso |
|---|---|
| `feat/` | Nova funcionalidade |
| `fix/` | Correção de bug |
| `chore/` | Tarefas de manutenção (deps, config, CI) |
| `docs/` | Documentação |
| `refactor/` | Refatoração sem mudança de comportamento |

Exemplos: `feat/music-search`, `fix/calendar-crash`, `docs/setup-guide`

## Padrão de commits

Este projeto segue o padrão [Conventional Commits](https://www.conventionalcommits.org/):

```
<tipo>: <descrição curta>

[corpo opcional]
```

Tipos aceitos:

| Tipo | Uso |
|---|---|
| `feat` | Nova funcionalidade |
| `fix` | Correção de bug |
| `chore` | Manutenção, dependências, configuração |
| `docs` | Documentação |
| `refactor` | Refatoração de código |
| `test` | Adição ou correção de testes |
| `style` | Formatação, espaços em branco (sem mudança de lógica) |

Exemplos:
```
feat: adicionar busca por título na biblioteca musical
fix: corrigir crash ao abrir calendário em fevereiro
chore: atualizar dependências Flutter
docs: adicionar guia de configuração do Firebase
```

## Como abrir um Pull Request

1. **Faça um fork** do repositório no GitHub (botão *Fork*) e clone o **seu** fork. Contribuições chegam sempre por PR de fork: ninguém precisa de acesso direto ao repositório principal.
   ```bash
   git clone https://github.com/<seu-usuario>/app-ipe.git
   cd app-ipe
   git remote add upstream https://github.com/arcenojackson/app-ipe.git
   ```
   Mantenha o fork atualizado e crie a branch a partir da `main` do projeto:
   ```bash
   git fetch upstream
   git checkout -b feat/minha-feature upstream/main
   ```

2. Implemente as mudanças e faça commits seguindo o padrão acima.

3. Antes de abrir o PR, execute (veja o que se aplica à sua mudança):
   ```bash
   flutter analyze
   dart format lib test        # não use "dart format ." na raiz (pega node_modules)
   flutter test
   cd functions && npm run lint && npm run build && npm test     # se mexeu em functions/
   cd web-portal && npm run lint && npm run typecheck && npm test # se mexeu no portal
   ```

4. Envie a branch para o seu fork (`git push -u origin feat/minha-feature`) e abra um Pull Request do seu fork para `arcenojackson/app-ipe`, base `main`. O template em `.github/pull_request_template.md` será carregado automaticamente — preencha todas as seções.

5. O CI (`.github/workflows/ci.yml`) roda no seu PR. Por segurança, em PRs de fork um mantenedor precisa aprovar a execução na primeira vez (e nas seguintes, se mudar o código). Se algum check falhar, corrija e envie novos commits à mesma branch.

6. Aguarde review. A branch `main` é **protegida**: não aceita push direto nem `--force`, e o merge exige a aprovação de um mantenedor (o *Code Owner* das áreas sensíveis, definido em `.github/CODEOWNERS`). Após aprovado, o mantenedor faz o merge.

## Reportar bugs

Use os [issue templates do GitHub](.github/ISSUE_TEMPLATE/) para reportar bugs ou sugerir funcionalidades. Escolha o template adequado ao abrir uma nova issue.

## Convenções de código

- **Análise estática:** siga as regras definidas em `analysis_options.yaml`. Execute `flutter analyze` antes de abrir o PR — o CI bloqueia erros, e novos warnings serão pedidos para corrigir na revisão.
- **Formatação:** use `dart format lib test` (nunca `dart format .` na raiz, que pega `node_modules`).
- **Idioma do código:** inglês (nomes de variáveis, funções, classes, arquivos).
- **Idioma dos comentários e documentação:** português, pois o app é voltado para a IPE e a equipe é brasileira.
- **Padrão arquitetural:** Provider + Repository pattern. Consulte o `CLAUDE.md` para detalhes da arquitetura.
- **Testes:** adicione testes unitários para lógica de negócio nova sempre que possível.
- **Windows e macOS:** o fluxo local funciona nos dois; os scripts em `scripts/local/` são Node puro. Use `npm run doctor` se algo não funcionar.
