# Contribuindo com o App IPE

Obrigado pelo interesse em contribuir! Este guia descreve o processo e as convenções adotadas no projeto.

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

1. Crie sua branch a partir de `main`:
   ```bash
   git checkout main && git pull
   git checkout -b feat/minha-feature
   ```

2. Implemente as mudanças e faça commits seguindo o padrão acima.

3. Antes de abrir o PR, execute:
   ```bash
   flutter analyze
   dart format .
   flutter test
   ```

4. Abra um Pull Request para `main`. O template em `.github/pull_request_template.md` será carregado automaticamente — preencha todas as seções.

5. Aguarde review. Após aprovação, o merge é feito em `main`.

## Reportar bugs

Use os [issue templates do GitHub](.github/ISSUE_TEMPLATE/) para reportar bugs ou sugerir funcionalidades. Escolha o template adequado ao abrir uma nova issue.

## Convenções de código

- **Análise estática:** siga as regras definidas em `analysis_options.yaml`. Execute `flutter analyze` antes de abrir o PR — PRs com warnings não serão aprovados.
- **Formatação:** use `dart format .` para formatar o código.
- **Idioma do código:** inglês (nomes de variáveis, funções, classes, arquivos).
- **Idioma dos comentários e documentação:** português, pois o app é voltado para a IPE e a equipe é brasileira.
- **Padrão arquitetural:** Provider + Repository pattern. Consulte o `CLAUDE.md` para detalhes da arquitetura.
- **Testes:** adicione testes unitários para lógica de negócio nova sempre que possível.
