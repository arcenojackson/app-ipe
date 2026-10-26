# Biblioteca — redesenho de UX/UI (spec curta)

Data: 2026-10-26. Mockup: `docs/superpowers/mockups/teaching-ux/biblioteca.html` (abas A e B). Só apresentação e fluxo: sem mudar dados, regras, Functions nem regras de negócio.

## Decisões do usuário
- A **Início é a Biblioteca**: `/ensino` renderiza a Biblioteca; sem item de menu "Biblioteca".
- `/ensino/biblioteca?item=ID` continua válido (push/notificações) e **redireciona** para `/ensino?item=ID`, preservando a query.
- **Duas exibições**, com alternância Lista/Grade (lembrada no navegador):
  - **Lista** (mockup A): linhas densas + **painel lateral fixo** com mini-visualização, metadados, tags e ações.
  - **Grade** (mockup B): cartões com miniatura; clicar abre a **visualização completa** (janela atual, sem o painel mini).
- **Filtros** só como chips (mockup A), com **seleção múltipla dentro de cada tipo** (Tipo, Assunto, Faixa etária). Cada chip abre uma lista com busca e caixas; os escolhidos viram chips com ✕; "Limpar filtros". Semântica de filtro inalterada (`libraryQuery`).
- Visual: tokens do app Flutter (nenhum token novo); sidebar e topo no estilo dos mockups; ícone de tipo por extensão em vez de emoji; esqueleto de carregamento; estados vazio/erro mais claros; em tela estreita a lista vira cartões e o painel vira janela.

## Mudanças de código previstas
1. `src/app/(portal)/ensino/page.tsx`: renderiza `LibraryPage` (com `Suspense`). `ensino/biblioteca/page.tsx`: `redirect` mantendo `?item=`.
2. `url.ts` (`libraryUrl`/`readParams`): base `/ensino`. Testes ajustados.
3. `teaching/module.ts`: remove "Biblioteca", renomeia "Início" para "Biblioteca" (`/ensino`). **Toca arquivo compartilhado com o Fórum; avisar a Central.**
4. `TeachingHomePage` deixa de ser a Início (cards migram para o menu; sem perda de função).
5. `LibraryPage`: barra de topo (busca, Enviar material → `/ensino/revisao`, sino), alternância Lista/Grade, `LibraryTable` → `LibraryList` + `LibraryGrid` + `ItemSidePanel`; `TagFilterBar` → chips com seleção múltipla.
6. `core/ui`: apenas adições pequenas e opcionais (ex.: `Chip`, `Skeleton`); sem alterar APIs existentes.

## Fora de escopo
Fila de Revisão, Plano, Notificações e Grupo (próximas etapas, em PRs próprios). Janela do item só ganha a visualização completa; a reorganização interna fica para a etapa da Fila.

## Verificação
`npm --prefix web-portal test | run lint | run typecheck | run build`; conferência visual local com dados falsos (login real só em produção).
