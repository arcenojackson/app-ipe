# Design: Incluir pessoa externa na escala da ELO

**Data:** 2026-04-23  
**Status:** Aprovado

---

## Contexto

Na tela Planejar, ao abrir um culto e acessar a aba Pessoas, o usuário com permissão pode adicionar membros da Equipe de Louvor (ELO) a um instrumento específico. A lista exibida hoje é filtrada por: (1) membros/diretoria da sociedade ELO e (2) disponibilidade marcada para aquela data.

Eventualmente, a responsável pelas escalas precisa incluir uma pessoa que não pertence à ELO ou que não marcou disponibilidade. Esta feature adiciona essa possibilidade de forma discreta, acessível apenas à Diretoria da ELO.

---

## Permissão

A opção é visível somente para usuários cujo ID consta em `SocietyModel.allBoardIds` da sociedade chamada `"ELO"`. Nenhum campo novo no Firestore ou no `UserModel` é necessário — `allBoardIds` já existe e é compatível com ambos os formatos de diretoria (antigo `boardIds` e novo `boardWithPositions`).

A verificação ocorre em `EventEditorPage._manageTeam()`, usando a lista `_societies` já carregada por `_loadData()`. Um booleano `canAddExternal` é derivado ali e passado como parâmetro ao `PeopleSelectorSheet`. O parâmetro é `false` para todos os outros tipos (Som e Imagem, Diaconia, etc.) — nada muda nesses fluxos.

---

## Fluxo de uso

```
Aba Pessoas → FAB group_add → "Equipe de louvor" → instrumento
    → PeopleSelectorSheet (lista filtrada: ELO + disponibilidade)
        → [link "+ Incluir outra pessoa"] (apenas diretoria ELO)
            → lista completa de todos os usuários do app
            + banner "Todos os usuários [x]"
        → [x] no banner → volta para lista filtrada
```

O botão "Salvar" funciona normalmente em ambos os modos. Pessoas selecionadas na lista completa são salvas exatamente da mesma forma que as selecionadas pela lista filtrada.

---

## Mudanças por arquivo

### `event_editor_page.dart` — `_manageTeam()`

Após carregar as pessoas, derivar `canAddExternal`:

```dart
final eloSociety = _societies.firstWhere(
  (s) => s.name == 'ELO',
  orElse: () => SocietyModel(id: '', name: '', description: '', color: 0, userId: ''),
);
final currentUser = context.read<AppState>().user;
final canAddExternal = eloSociety.allBoardIds.contains(currentUser?.id);
```

Passar `canAddExternal` ao `PeopleSelectorSheet` apenas quando `currentStep == 'people_selector_elo'`.

### `people_selector_sheet.dart`

**Novo parâmetro:**
```dart
final bool canAddExternal; // default: false
```

**Novo estado:**
```dart
bool _showAllUsers = false;
```

**`_filterPeople()`:** quando `_showAllUsers == true`, ignorar `filterByELO` e `filterBySociety` — listar todos os usuários sem filtro (apenas aplicar `_searchQuery` se houver).

**UI — link discreto** (abaixo da lista, acima do botão "Salvar"):  
Visível quando `filterByELO && canAddExternal && !_showAllUsers`.

```dart
TextButton.icon(
  onPressed: () {
    setState(() => _showAllUsers = true);
    _filterPeople();
  },
  icon: Icon(Icons.person_add_outlined, size: 16, color: Colors.white38),
  label: Text(
    '+ Incluir outra pessoa',
    style: TextStyle(
      color: Colors.white38,
      fontSize: 13,
      decoration: TextDecoration.underline,
      decorationColor: Colors.white38,
    ),
  ),
)
```

**UI — banner de modo expandido** (acima da lista):  
Visível quando `_showAllUsers == true`.

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.05),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Row(
    children: [
      Icon(Icons.group, size: 16, color: Colors.white60),
      SizedBox(width: 8),
      Expanded(
        child: Text('Todos os usuários', style: TextStyle(color: Colors.white60, fontSize: 13)),
      ),
      IconButton(
        icon: Icon(Icons.close, size: 16, color: Colors.white60),
        onPressed: () {
          setState(() => _showAllUsers = false);
          _filterPeople();
        },
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(),
      ),
    ],
  ),
)
```

---

## O que não muda

- O modelo de dados (`EventPeople`, `eloWithInstruments`) permanece inalterado.
- O `_autoSave()` e o `updateEventDetails()` no repositório não mudam.
- Os outros tipos de seleção (Som e Imagem, Diaconia, Pregador, Dirigente) não são afetados.
- As notificações disparadas pelo Firebase Function `onServicePeopleUpdated` continuam funcionando normalmente.
