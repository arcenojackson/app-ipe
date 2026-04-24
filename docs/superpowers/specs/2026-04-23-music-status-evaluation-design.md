# Music Status & Evaluation Flow — Design Spec

**Data:** 2026-04-23  
**Autor:** Jackson Felipe  
**Status:** Aprovado

---

## Visão Geral

Introduzir um sistema de status para as músicas da biblioteca, integrando-o ao fluxo de Avaliação de Músicas (Fórum) já existente. Ministros ELO passam a ser os únicos que podem adicionar músicas; toda música nova entra automaticamente no Fórum para avaliação. A diretoria ELO define o status final após todas as avaliações serem concluídas.

---

## Contexto

- **Biblioteca de Músicas (`musics`):** coleção Firestore com título, artista, cifra, letra, YouTube, categorias. Sem campo de status hoje.
- **Fórum de Avaliação (`music_evaluation_forms`):** formulários por categoria (teológica, congregacional, musical), com avaliadores por categoria definidos em `eloSociety.forumUsersByCategory`. Hoje as músicas são adicionadas manualmente nos formulários.
- **ELO Society:** tem `ministrosIds` (ministros) e `allBoardIds` (diretoria), além de `forumUsersByCategory`.

---

## Regras de Negócio

### Status das Músicas

| Valor | Label UI | Cor | Significado |
|---|---|---|---|
| `avaliar` | Avaliar | Âmbar | Música existente aguardando ser enviada ao Fórum |
| `em_avaliacao` | Em avaliação | Azul | Música no Fórum, avaliações em andamento |
| `aprovada` | Aprovada | Verde | Diretoria ELO aprovou |
| `reprovada` | Reprovada | Vermelho | Diretoria ELO reprovou |

### Transições de status

```
[existentes] → avaliar  (migração na criação do campo)
avaliar      → em_avaliacao  (ministro envia para avaliação)
[nova]       → em_avaliacao  (ministro adiciona música nova)
em_avaliacao → aprovada | reprovada  (diretoria, após todos os forms fechados)
```

### Permissões

| Ação | Quem pode |
|---|---|
| Ver badge de status nas músicas | Todos |
| Adicionar música nova | Ministros ELO (`ministrosIds`) |
| Enviar música existente para avaliação | Ministros ELO (`ministrosIds`) |
| Avaliar nos forms do Fórum | `allowedUserIds` do form (sem mudança) |
| Ver botão "Aguardando decisão" na tela Músicas | Diretoria ELO (`allBoardIds`) |
| Acessar tela de decisão final | Diretoria ELO (`allBoardIds`) |
| Definir aprovada / reprovada | Diretoria ELO (`allBoardIds`) |

---

## Mudanças de Dados

### `MusicModel` — novo campo

```dart
final MusicStatus status; // enum: avaliar, em_avaliacao, aprovada, reprovada
```

- Firestore: campo `status` (String) na coleção `musics`
- **Migração lazy:** `fetchAll()` e `fetchById()` tratam documentos sem o campo como `avaliar`. Nenhum script de migração necessário.

### `EvaluationFormModel` — novo campo

```dart
final String? musicLibraryId;
```

- Firestore: campo `music_library_id` (String, nullable) em `music_evaluation_forms`
- `null` para formulários criados manualmente (comportamento atual preservado)
- Preenchido com o `id` do `MusicModel` quando criado automaticamente

---

## Fluxo: Música Nova (Ministro)

1. Ministro adiciona música via `MusicFormSheet` (fluxo existente)
2. `MusicsRepository.create()` salva com `status: "em_avaliacao"`
3. Logo após a criação bem-sucedida, `MusicEvaluationsRepository.createFormsForMusic(music, eloSociety)` cria **3 formulários** simultaneamente:
   - Um por categoria: teológica, congregacional, musical
   - Título: `"[Título da música] – [Categoria]"`
   - `allowedUserIds`: `eloSociety.forumUsersByCategory[categoria]`
   - `musicLibraryId`: `music.id`
   - Status: `active`
4. Os 3 forms aparecem normalmente no Fórum para os avaliadores

**Erro na criação dos forms:** se falhar, exibe toast de aviso mas não reverte a criação da música. A música fica com status `em_avaliacao` e pode ser reenviada manualmente.

---

## Fluxo: Enviar Música Existente para Avaliação (Ministro)

1. Na tela Músicas, ministro vê botão "Enviar para avaliação" em cards com status `avaliar`
2. Dialog de confirmação: "Enviar [título] para avaliação no Fórum?"
3. Ao confirmar:
   - `MusicsRepository.sendToEvaluation(musicId)` atualiza `status → "em_avaliacao"`
   - `MusicEvaluationsRepository.createFormsForMusic(music, eloSociety)` cria os 3 forms
4. Card atualiza badge para "Em avaliação" e botão some

---

## Fluxo: Decisão Final (Diretoria ELO)

### Condição de elegibilidade
Uma música está pronta para decisão quando **todos os 3 forms** com `musicLibraryId == music.id` têm `status == closed`.

O status `closed` já é gerenciado pelo `updateFormStatusIfNeeded()` existente (auto-fecha quando todos os avaliadores respondem).

### Acesso à tela de decisão
- **Tela Músicas:** chip/botão no topo — "Aguardando decisão (N)" — visível apenas para diretoria ELO. N = quantidade de músicas elegíveis.
- **Fórum:** nos cards de forms com `musicLibraryId` preenchido e `status == closed`, chip "Ver decisão final" visível para diretoria. Abre `MusicDecisionPage` filtrada para aquela música.

---

## Tela: `MusicDecisionPage`

### Conteúdo
Lista de músicas com status `em_avaliacao` cujos 3 forms estão `closed`.

Para cada música:
- Cabeçalho: título e artista
- **Carrossel horizontal** de cards de avaliação — um card por resposta (N avaliadores × 3 categorias):
  - Nome do avaliador
  - Categoria (Teológica / Congregacional / Musical) com cor correspondente
  - Rating em estrelas
  - Comentário completo
- Botões de ação: **Aprovar** | **Reprovar**
- Ao confirmar (dialog): `MusicsRepository.setFinalStatus(musicId, status)` atualiza o campo; item some da lista

### Estado vazio
"Nenhuma música aguardando decisão." com ícone ilustrativo.

---

## Mudanças na Tela Músicas (`MusicsSection`)

### Badge de status
Todo card de música exibe um badge colorido (pill) com o label e cor do status atual. Visível para todos os usuários.

### Botão "Enviar para avaliação" (ministros, status `avaliar`)
Ícone de envio no card, ao lado dos botões de editar/excluir. Visível apenas quando `canManage == true` (ministros e admins que sejam ministros) e `music.status == avaliar`.

### Chip "Aguardando decisão" no topo (diretoria)
Aparece acima da barra de busca **somente quando N > 0**. Busca assíncrona no `initState` da `MusicsSection` — mesmo padrão do `_checkMinistroStatus` já implementado no `HomeShell`. Quando N == 0, o chip não é exibido.

---

## Mudanças no Fórum (`EvaluationsListPage` e viewers)

### Comportamento atual: preservado integralmente
Forms sem `musicLibraryId` funcionam exatamente como hoje.

### Forms vinculados à biblioteca
- Aparecem normalmente em todas as abas de categoria
- Card do form exibe chip de status da música (`Em avaliação`)
- Quando `closed` e diretoria está visualizando: chip "Ver decisão final" → `MusicDecisionPage` filtrada

---

## Novos Métodos de Repositório

### `MusicsRepository`

```dart
// Cria música com status em_avaliacao
Future<MusicModel> create(MusicModel music) // já existe, recebe status no model

// Atualiza status para em_avaliacao + salva no Firestore
Future<void> sendToEvaluation(String musicId)

// Define status final (aprovada ou reprovada)
Future<void> setFinalStatus(String musicId, MusicStatus status)

// Retorna músicas cujos 3 forms estão fechados (para o badge de contagem)
Future<int> countPendingDecisions(String eloSocietyId)
```

### `MusicEvaluationsRepository`

```dart
// Cria 3 forms automaticamente para uma música da biblioteca
Future<void> createFormsForMusic(MusicModel music, SocietyModel eloSociety)

// Retorna músicas (com seus forms e respostas) prontas para decisão
Future<List<MusicWithEvaluations>> fetchPendingDecisions(String eloSocietyId)
```

### Novo modelo auxiliar

```dart
class MusicWithEvaluations {
  final MusicModel music;
  final List<EvaluationFormModel> forms;      // os 3 forms
  final List<EvaluationResponseModel> responses; // todas as respostas
}
```

---

## Arquivos a Criar / Modificar

### Criar
- `lib/src/modules/musics/models/music_status.dart` — enum `MusicStatus`
- `lib/src/modules/music_evaluations/models/music_with_evaluations.dart`
- `lib/src/modules/music_evaluations/presentation/music_decision_page.dart`

### Modificar
- `lib/src/modules/musics/models/music.dart` — adicionar campo `status`
- `lib/src/modules/musics/data/musics_repository.dart` — novos métodos
- `lib/src/modules/musics/presentation/musics_section.dart` — badge, botão enviar, chip diretoria
- `lib/src/modules/musics/presentation/widgets/music_form_sheet.dart` — passar status ao criar
- `lib/src/modules/music_evaluations/models/evaluation_form.dart` — adicionar `musicLibraryId`
- `lib/src/modules/music_evaluations/data/music_evaluations_repository.dart` — novos métodos
- `lib/src/modules/music_evaluations/presentation/evaluations_list_page.dart` — chip "Ver decisão final"
- `lib/src/modules/music_evaluations/presentation/evaluation_responses_viewer_page.dart` — chip diretoria

---

## Fora de Escopo (por ora)

- Ações que músicas aprovadas/reprovadas desencadeiam em outras partes do app
- Notificações push para diretoria quando todos os forms fecham
- Histórico de mudanças de status
