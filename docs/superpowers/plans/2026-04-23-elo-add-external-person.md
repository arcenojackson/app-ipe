# ELO — Incluir Pessoa Externa na Escala — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir que membros da Diretoria da ELO adicionem qualquer usuário do app a um instrumento da Equipe de Louvor em um culto, mesmo que essa pessoa não pertença à ELO ou não tenha marcado disponibilidade.

**Architecture:** Dois arquivos modificados. Em `EventEditorPage._manageTeam()`, derivar `canAddExternal` verificando se o usuário logado está em `SocietyModel.allBoardIds` da sociedade ELO e passar esse booleano ao `PeopleSelectorSheet`. No `PeopleSelectorSheet`, adicionar parâmetro `canAddExternal`, estado `_showAllUsers`, lógica de filtro expandida, banner de modo expandido e link de texto discreto.

**Tech Stack:** Flutter, Provider, `cloud_firestore` (sem mudanças), `AppState` (para obter usuário atual).

---

## Arquivo Map

| Ação | Arquivo |
|------|---------|
| Modificar | `lib/src/modules/people/presentation/widgets/people_selector_sheet.dart` |
| Modificar | `lib/src/modules/events/presentation/event_editor_page.dart` |
| Criar | `test/modules/elo_board_permission_test.dart` |

---

### Task 1: Teste unitário para a lógica de permissão

**Files:**
- Create: `test/modules/elo_board_permission_test.dart`

- [ ] **Step 1: Criar o arquivo de teste**

```dart
// test/modules/elo_board_permission_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/auth/models/user.dart';
import 'package:ipe_flutter/src/modules/societies/models/society.dart';

void main() {
  group('ELO board permission (canAddExternal)', () {
    final boardUserId = 'user-board-1';
    final regularUserId = 'user-regular-1';

    SocietyModel makeEloSociety({
      List<String> boardIds = const [],
      Map<String, List<String>> boardWithPositions = const {},
    }) {
      return SocietyModel(
        id: 'elo-id',
        name: 'ELO',
        description: '',
        color: 0xFF2F4F2F,
        userId: 'admin',
        boardIds: boardIds,
        boardWithPositions: boardWithPositions,
      );
    }

    UserModel makeUser(String id) => UserModel(
          id: id,
          name: 'Test',
          email: 'test@test.com',
          isAdmin: false,
          isPending: false,
        );

    test('membro da diretoria (formato antigo) pode adicionar pessoa externa', () {
      final society = makeEloSociety(boardIds: [boardUserId]);
      final user = makeUser(boardUserId);
      expect(society.allBoardIds.contains(user.id), isTrue);
    });

    test('membro da diretoria (formato novo boardWithPositions) pode adicionar pessoa externa', () {
      final society = makeEloSociety(
        boardWithPositions: {
          'Presidente': [boardUserId],
        },
      );
      final user = makeUser(boardUserId);
      expect(society.allBoardIds.contains(user.id), isTrue);
    });

    test('usuário comum não pode adicionar pessoa externa', () {
      final society = makeEloSociety(boardIds: [boardUserId]);
      final user = makeUser(regularUserId);
      expect(society.allBoardIds.contains(user.id), isFalse);
    });

    test('usuário nulo não pode adicionar pessoa externa', () {
      final society = makeEloSociety(boardIds: [boardUserId]);
      const String? nullId = null;
      expect(society.allBoardIds.contains(nullId), isFalse);
    });
  });
}
```

- [ ] **Step 2: Rodar o teste para verificar que passa (lógica já existe em `SocietyModel`)**

```bash
cd /Users/arcenojackson/www/church-apps/app-ipe
flutter test test/modules/elo_board_permission_test.dart
```

Esperado: todos os 4 testes PASS.

- [ ] **Step 3: Commit**

```bash
git add test/modules/elo_board_permission_test.dart
git commit -m "test: adicionar testes unitários para permissão de diretoria da ELO"
```

---

### Task 2: Atualizar `PeopleSelectorSheet` — parâmetro, estado e lógica de filtro

**Files:**
- Modify: `lib/src/modules/people/presentation/widgets/people_selector_sheet.dart`

- [ ] **Step 1: Adicionar parâmetro `canAddExternal` ao widget**

Localizar o construtor de `PeopleSelectorSheet` (linha ~10) e adicionar o parâmetro:

```dart
class PeopleSelectorSheet extends StatefulWidget {
  const PeopleSelectorSheet({
    super.key,
    required this.people,
    required this.selectedIds,
    this.eventDate,
    this.filterByELO = false,
    this.filterBySociety,
    this.instrument,
    this.showTalkBack = false,
    this.title,
    this.canGoBack = false,
    this.canAddExternal = false, // NOVO
  });

  final List<UserModel> people;
  final List<String> selectedIds;
  final DateTime? eventDate;
  final bool filterByELO;
  final String? filterBySociety;
  final String? instrument;
  final bool showTalkBack;
  final String? title;
  final bool canGoBack;
  final bool canAddExternal; // NOVO
```

- [ ] **Step 2: Adicionar estado `_showAllUsers` em `_PeopleSelectorSheetState`**

Localizar o bloco de campos da State (linha ~40) e adicionar:

```dart
class _PeopleSelectorSheetState extends State<PeopleSelectorSheet> {
  late List<String> _selectedIds;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<UserModel> _filteredPeople = [];
  bool _isLoading = true;
  final Map<String, bool> _talkBackSelections = {};
  bool _showAllUsers = false; // NOVO
```

- [ ] **Step 3: Atualizar `_filterPeople()` para respeitar `_showAllUsers`**

Substituir o bloco de guarda no início de `_filterPeople()` para tratar o modo expandido:

```dart
Future<void> _filterPeople() async {
  // Modo expandido: listar todos os usuários sem filtro de ELO/sociedade
  if (_showAllUsers) {
    setState(() {
      _isLoading = false;
      if (_searchQuery.isEmpty) {
        _filteredPeople = widget.people;
      } else {
        _filteredPeople = widget.people.where((person) {
          final name = person.name.toLowerCase();
          final email = person.email.toLowerCase();
          return name.contains(_searchQuery) || email.contains(_searchQuery);
        }).toList();
      }
      _filteredPeople.sort((a, b) => compareNamesIgnoreAccents(a.name, b.name));
    });
    return;
  }

  // Resto do método permanece igual (filtro por sociedade/ELO/disponibilidade)
  if (!widget.filterByELO && widget.filterBySociety == null) {
    // ... código existente inalterado
  }
  // ... restante do método existente inalterado
```

- [ ] **Step 4: Rodar análise estática**

```bash
cd /Users/arcenojackson/www/church-apps/app-ipe
flutter analyze lib/src/modules/people/presentation/widgets/people_selector_sheet.dart
```

Esperado: sem erros (pode haver warnings de depreciação pré-existentes, ignorar).

- [ ] **Step 5: Commit**

```bash
git add lib/src/modules/people/presentation/widgets/people_selector_sheet.dart
git commit -m "feat(elo): adicionar parâmetro canAddExternal e estado _showAllUsers ao PeopleSelectorSheet"
```

---

### Task 3: Atualizar `PeopleSelectorSheet` — UI (banner + link)

**Files:**
- Modify: `lib/src/modules/people/presentation/widgets/people_selector_sheet.dart`

- [ ] **Step 1: Adicionar o banner de modo expandido acima da lista**

No método `build()`, localizar o bloco `SizedBox(height: 400, child: ...)` que contém a lista e adicionar o banner imediatamente antes dele:

```dart
// Banner "Todos os usuários" (visível apenas em modo expandido)
if (_showAllUsers) ...[
  Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.group, size: 16, color: Colors.white60),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Todos os usuários',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 16, color: Colors.white60),
          onPressed: () {
            setState(() => _showAllUsers = false);
            _filterPeople();
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ),
  ),
],
SizedBox(
  height: 400,
  // ... código existente da lista
```

- [ ] **Step 2: Adicionar o link discreto abaixo da lista, antes do botão "Salvar"**

Localizar o bloco `const SizedBox(height: 16)` que vem após o `SizedBox(height: 400, ...)` da lista, e adicionar o link entre eles:

```dart
// Fim da SizedBox(height: 400) com a lista
const SizedBox(height: 16),

// Link "Incluir outra pessoa" (apenas para diretoria ELO, quando filtro ativo)
if (widget.filterByELO && widget.canAddExternal && !_showAllUsers) ...[
  Center(
    child: TextButton.icon(
      onPressed: () {
        setState(() => _showAllUsers = true);
        _filterPeople();
      },
      icon: const Icon(
        Icons.person_add_outlined,
        size: 16,
        color: Colors.white38,
      ),
      label: const Text(
        '+ Incluir outra pessoa',
        style: TextStyle(
          color: Colors.white38,
          fontSize: 13,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white38,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    ),
  ),
  const SizedBox(height: 8),
],

// Botão Salvar (código existente)
SizedBox(
  width: double.infinity,
  child: FilledButton(
```

- [ ] **Step 3: Rodar análise estática**

```bash
cd /Users/arcenojackson/www/church-apps/app-ipe
flutter analyze lib/src/modules/people/presentation/widgets/people_selector_sheet.dart
```

Esperado: sem erros.

- [ ] **Step 4: Commit**

```bash
git add lib/src/modules/people/presentation/widgets/people_selector_sheet.dart
git commit -m "feat(elo): adicionar banner de modo expandido e link 'Incluir outra pessoa' ao PeopleSelectorSheet"
```

---

### Task 4: Atualizar `EventEditorPage._manageTeam()` para derivar e passar `canAddExternal`

**Files:**
- Modify: `lib/src/modules/events/presentation/event_editor_page.dart`

- [ ] **Step 1: Derivar `canAddExternal` no início de `_manageTeam()`**

Localizar o método `_manageTeam()` (~linha 785). Logo após o bloco `try/catch` que recarrega `_people`, adicionar a derivação:

```dart
Future<void> _manageTeam() async {
  // Recarregar usuários
  try {
    final peopleRepository = context.read<PeopleRepository>();
    final people = await peopleRepository.fetchAll();
    setState(() {
      _people = people;
    });
  } catch (e) {
    if (mounted) {
      showErrorToast(context, 'Erro ao carregar usuários: ${e.toString()}');
    }
    return;
  }

  // Verificar se o usuário atual é da Diretoria da ELO
  final currentUser = context.read<AppState>().currentUser;
  final eloSociety = _societies.firstWhere(
    (s) => s.name == 'ELO',
    orElse: () => SocietyModel(
      id: '',
      name: '',
      description: '',
      color: 0xFF2F4F2F,
      userId: '',
    ),
  );
  final canAddExternal = eloSociety.allBoardIds.contains(currentUser?.id);

  // ... resto do método
```

- [ ] **Step 2: Passar `canAddExternal` ao `PeopleSelectorSheet` quando ELO**

Localizar o `showModalBottomSheet` que abre o `PeopleSelectorSheet` (dentro do bloco `else if (currentStep == 'people_selector' || currentStep == 'people_selector_elo')`). Adicionar o parâmetro:

```dart
final result = await showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => PeopleSelectorSheet(
    people: _people,
    selectedIds: currentSelectedIds,
    eventDate: _event?.date,
    filterByELO: filterByELO,
    filterBySociety: filterBySociety,
    title: title,
    canGoBack: canGoBack,
    instrument: instrumentParam,
    showTalkBack: showTalkBack,
    canAddExternal: currentStep == 'people_selector_elo' ? canAddExternal : false, // NOVO
  ),
);
```

- [ ] **Step 3: Adicionar import do `AppState` se necessário**

Verificar se `AppState` já está importado no arquivo:

```bash
grep "app_state" /Users/arcenojackson/www/church-apps/app-ipe/lib/src/modules/events/presentation/event_editor_page.dart
```

Se não estiver, adicionar no bloco de imports:

```dart
import '../../../shared/state/app_state.dart';
```

- [ ] **Step 4: Rodar análise estática**

```bash
cd /Users/arcenojackson/www/church-apps/app-ipe
flutter analyze lib/src/modules/events/presentation/event_editor_page.dart
```

Esperado: sem erros.

- [ ] **Step 5: Commit**

```bash
git add lib/src/modules/events/presentation/event_editor_page.dart
git commit -m "feat(elo): passar canAddExternal ao PeopleSelectorSheet para diretoria da ELO"
```

---

### Task 5: Verificação final

**Files:**
- No changes

- [ ] **Step 1: Rodar todos os testes**

```bash
cd /Users/arcenojackson/www/church-apps/app-ipe
flutter test
```

Esperado: todos os testes PASS.

- [ ] **Step 2: Rodar análise geral**

```bash
cd /Users/arcenojackson/www/church-apps/app-ipe
flutter analyze
```

Esperado: sem erros novos.

- [ ] **Step 3: Checklist de verificação manual no app**

Testar com um usuário da Diretoria da ELO:
1. Abrir um culto na tela Planejar
2. Ir em aba Pessoas → FAB → "Equipe de louvor" → selecionar instrumento
3. Verificar que o link `"+ Incluir outra pessoa"` aparece abaixo da lista
4. Tocar no link → verificar que a lista muda para todos os usuários e o banner aparece
5. Tocar no `[x]` do banner → verificar que a lista volta ao filtro ELO + disponibilidade
6. Selecionar uma pessoa da lista expandida e salvar → verificar que aparece no culto

Testar com um usuário comum (não diretoria da ELO):
1. Mesmo fluxo → verificar que o link **não aparece**
