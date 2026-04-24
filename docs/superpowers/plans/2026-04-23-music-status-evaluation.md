# Music Status & Evaluation Flow — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar status às músicas da biblioteca, integrando-as automaticamente ao Fórum de Avaliação, e criar uma tela para a diretoria ELO definir o resultado final.

**Architecture:** Campo `status` no `MusicModel` (lazy-migrado); novo campo `musicLibraryId` no `EvaluationFormModel` vincula forms à biblioteca; criação automática de 3 forms ao adicionar/enviar música; nova `MusicDecisionPage` para diretoria; chip "Ver decisão final" no viewer de respostas do Fórum.

**Tech Stack:** Flutter + Provider + Cloud Firestore (acesso direto via `FirebaseFirestore`)

---

## Mapa de Arquivos

| Ação | Arquivo |
|---|---|
| **Criar** | `lib/src/modules/musics/models/music_status.dart` |
| **Criar** | `lib/src/modules/music_evaluations/models/music_with_evaluations.dart` |
| **Criar** | `lib/src/modules/music_evaluations/presentation/music_decision_page.dart` |
| **Criar** | `test/modules/music_status_test.dart` |
| **Modificar** | `lib/src/modules/musics/models/music.dart` |
| **Modificar** | `lib/src/modules/musics/data/musics_repository.dart` |
| **Modificar** | `lib/src/modules/musics/presentation/musics_section.dart` |
| **Modificar** | `lib/src/modules/musics/presentation/widgets/music_form_sheet.dart` |
| **Modificar** | `lib/src/modules/music_evaluations/models/evaluation_form.dart` |
| **Modificar** | `lib/src/modules/music_evaluations/data/music_evaluations_repository.dart` |
| **Modificar** | `lib/src/modules/music_evaluations/presentation/evaluation_responses_viewer_page.dart` |

---

## Task 1: MusicStatus enum

**Files:**
- Create: `lib/src/modules/musics/models/music_status.dart`
- Create: `test/modules/music_status_test.dart`

- [ ] **Step 1: Criar o arquivo do enum**

```dart
// lib/src/modules/musics/models/music_status.dart

enum MusicStatus {
  avaliar('avaliar', 'Avaliar'),
  emAvaliacao('em_avaliacao', 'Em avaliação'),
  aprovada('aprovada', 'Aprovada'),
  reprovada('reprovada', 'Reprovada');

  const MusicStatus(this.value, this.label);

  final String value;
  final String label;

  static MusicStatus fromString(String? raw) {
    if (raw == null) return MusicStatus.avaliar;
    return MusicStatus.values.firstWhere(
      (s) => s.value == raw,
      orElse: () => MusicStatus.avaliar,
    );
  }
}
```

- [ ] **Step 2: Escrever os testes**

```dart
// test/modules/music_status_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ipe_flutter/src/modules/musics/models/music_status.dart';

void main() {
  group('MusicStatus.fromString', () {
    test('retorna avaliar para null (migração lazy)', () {
      expect(MusicStatus.fromString(null), MusicStatus.avaliar);
    });

    test('retorna avaliar para string desconhecida', () {
      expect(MusicStatus.fromString('xpto'), MusicStatus.avaliar);
    });

    test('converte "em_avaliacao" corretamente', () {
      expect(MusicStatus.fromString('em_avaliacao'), MusicStatus.emAvaliacao);
    });

    test('converte "aprovada" corretamente', () {
      expect(MusicStatus.fromString('aprovada'), MusicStatus.aprovada);
    });

    test('converte "reprovada" corretamente', () {
      expect(MusicStatus.fromString('reprovada'), MusicStatus.reprovada);
    });

    test('value e label estão corretos para cada status', () {
      expect(MusicStatus.emAvaliacao.value, 'em_avaliacao');
      expect(MusicStatus.emAvaliacao.label, 'Em avaliação');
      expect(MusicStatus.aprovada.value, 'aprovada');
      expect(MusicStatus.reprovada.value, 'reprovada');
    });
  });
}
```

- [ ] **Step 3: Rodar os testes**

```bash
flutter test test/modules/music_status_test.dart
```

Esperado: todos passam.

- [ ] **Step 4: Commit**

```bash
git add lib/src/modules/musics/models/music_status.dart test/modules/music_status_test.dart
git commit -m "feat(musics): adicionar enum MusicStatus com migração lazy"
```

---

## Task 2: Adicionar status ao MusicModel

**Files:**
- Modify: `lib/src/modules/musics/models/music.dart`
- Modify: `test/modules/music_status_test.dart` (adicionar testes de model)

- [ ] **Step 1: Escrever os testes do modelo antes de modificar**

Adicione este `group` ao final de `test/modules/music_status_test.dart`:

```dart
import 'package:ipe_flutter/src/modules/musics/models/music.dart';

// ... dentro de main(), após o group existente:

  group('MusicModel.fromJson — campo status', () {
    Map<String, dynamic> baseJson() => {
      'id': 'music-1',
      'title': 'Santo',
      'artist': 'Ministério Ipiranga',
      'cipher': '',
      'tone': 'C',
    };

    test('status ausente → avaliar (migração lazy)', () {
      final music = MusicModel.fromJson(baseJson());
      expect(music.status, MusicStatus.avaliar);
    });

    test('status "em_avaliacao" → emAvaliacao', () {
      final json = baseJson()..['status'] = 'em_avaliacao';
      final music = MusicModel.fromJson(json);
      expect(music.status, MusicStatus.emAvaliacao);
    });

    test('status "aprovada" → aprovada', () {
      final json = baseJson()..['status'] = 'aprovada';
      final music = MusicModel.fromJson(json);
      expect(music.status, MusicStatus.aprovada);
    });

    test('toJson inclui campo status', () {
      final music = MusicModel.fromJson(baseJson()..['status'] = 'reprovada');
      expect(music.toJson()['status'], 'reprovada');
    });
  });
```

- [ ] **Step 2: Rodar — esperar FALHA**

```bash
flutter test test/modules/music_status_test.dart
```

Esperado: erro de compilação (campo `status` não existe ainda).

- [ ] **Step 3: Modificar MusicModel**

Em `lib/src/modules/musics/models/music.dart`:

Adicionar import no topo:
```dart
import 'music_status.dart';
```

No construtor, adicionar após `this.selectedTimes = const []`:
```dart
this.status = MusicStatus.avaliar,
```

Adicionar o campo:
```dart
final MusicStatus status;
```

No `fromJson`, adicionar antes do fechamento do `return MusicModel(`:
```dart
status: MusicStatus.fromString(json['status']?.toString()),
```

No `toJson()`, adicionar:
```dart
'status': status.value,
```

No `copyWith`, adicionar parâmetro e uso:
```dart
MusicStatus? status,
// ...
status: status ?? this.status,
```

- [ ] **Step 4: Rodar os testes**

```bash
flutter test test/modules/music_status_test.dart
```

Esperado: todos passam.

- [ ] **Step 5: Verificar análise estática**

```bash
flutter analyze lib/src/modules/musics/models/music.dart
```

Esperado: sem erros.

- [ ] **Step 6: Commit**

```bash
git add lib/src/modules/musics/models/music.dart test/modules/music_status_test.dart
git commit -m "feat(musics): adicionar campo status ao MusicModel com migração lazy"
```

---

## Task 3: Adicionar musicLibraryId ao EvaluationFormModel + modelo auxiliar

**Files:**
- Modify: `lib/src/modules/music_evaluations/models/evaluation_form.dart`
- Create: `lib/src/modules/music_evaluations/models/music_with_evaluations.dart`

- [ ] **Step 1: Adicionar `musicLibraryId` ao `EvaluationFormModel`**

Em `lib/src/modules/music_evaluations/models/evaluation_form.dart`:

No construtor, adicionar após `required this.musics`:
```dart
this.musicLibraryId,
```

Adicionar o campo:
```dart
final String? musicLibraryId;
```

No `fromJson`, adicionar antes do fechamento do `return EvaluationFormModel(`:
```dart
musicLibraryId: json['musicLibraryId']?.toString(),
```

No `toJson()`, adicionar:
```dart
if (musicLibraryId != null) 'musicLibraryId': musicLibraryId,
```

No `copyWith`, adicionar parâmetro e uso:
```dart
String? musicLibraryId,
// ...
musicLibraryId: musicLibraryId ?? this.musicLibraryId,
```

- [ ] **Step 2: Criar o modelo `MusicWithEvaluations`**

```dart
// lib/src/modules/music_evaluations/models/music_with_evaluations.dart

import '../../musics/models/music.dart';
import 'evaluation_form.dart';
import 'evaluation_response.dart';

class MusicWithEvaluations {
  const MusicWithEvaluations({
    required this.music,
    required this.forms,
    required this.responses,
  });

  final MusicModel music;
  final List<EvaluationFormModel> forms;
  final List<EvaluationResponseModel> responses;

  /// Respostas agrupadas por formId
  Map<String, List<EvaluationResponseModel>> get responsesByForm {
    final map = <String, List<EvaluationResponseModel>>{};
    for (final r in responses) {
      map.putIfAbsent(r.formId, () => []).add(r);
    }
    return map;
  }
}
```

- [ ] **Step 3: Verificar análise estática**

```bash
flutter analyze lib/src/modules/music_evaluations/models/
```

Esperado: sem erros.

- [ ] **Step 4: Commit**

```bash
git add lib/src/modules/music_evaluations/models/evaluation_form.dart \
        lib/src/modules/music_evaluations/models/music_with_evaluations.dart
git commit -m "feat(evaluations): adicionar musicLibraryId ao EvaluationFormModel e modelo MusicWithEvaluations"
```

---

## Task 4: Novos métodos no MusicsRepository

**Files:**
- Modify: `lib/src/modules/musics/data/musics_repository.dart`

- [ ] **Step 1: Adicionar `sendToEvaluation` e `setFinalStatus`**

Em `lib/src/modules/musics/data/musics_repository.dart`, adicionar os métodos antes do fechamento da classe:

```dart
  Future<void> sendToEvaluation(String musicId) async {
    try {
      await _firestore.collection('musics').doc(musicId).update({
        'status': MusicStatus.emAvaliacao.value,
      });
    } catch (e) {
      throw AppException(message: 'Erro ao enviar música para avaliação: $e');
    }
  }

  Future<void> setFinalStatus(String musicId, MusicStatus status) async {
    try {
      await _firestore.collection('musics').doc(musicId).update({
        'status': status.value,
      });
    } catch (e) {
      throw AppException(message: 'Erro ao definir status final: $e');
    }
  }
```

Adicionar import no topo do arquivo:
```dart
import '../models/music_status.dart';
```

- [ ] **Step 2: Verificar análise estática**

```bash
flutter analyze lib/src/modules/musics/data/musics_repository.dart
```

Esperado: sem erros.

- [ ] **Step 3: Commit**

```bash
git add lib/src/modules/musics/data/musics_repository.dart
git commit -m "feat(musics): adicionar sendToEvaluation e setFinalStatus ao MusicsRepository"
```

---

## Task 5: Novos métodos no MusicEvaluationsRepository

**Files:**
- Modify: `lib/src/modules/music_evaluations/data/music_evaluations_repository.dart`

Atenção: este repositório já tem `_societiesRepository` injetado — usá-lo diretamente.

- [ ] **Step 1: Adicionar imports necessários**

No topo de `music_evaluations_repository.dart`, verificar se estes imports existem e adicionar os ausentes:

```dart
import '../../musics/models/music.dart';
import '../../musics/models/music_status.dart';
import '../models/music_with_evaluations.dart';
```

- [ ] **Step 2: Adicionar `createFormsForMusic`**

Adicionar o método antes do fechamento da classe:

```dart
  /// Cria 3 formulários (um por categoria) vinculados a uma música da biblioteca.
  Future<void> createFormsForMusic(MusicModel music) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    final eloSociety = await _societiesRepository.fetchByName('ELO');
    if (eloSociety == null) return;

    final forumUsers = eloSociety.forumUsersByCategory ?? {};
    final now = DateTime.now();

    for (final category in EvaluationCategory.values) {
      final allowedUserIds = forumUsers[category.name] ?? [];
      final evalMusic = EvaluationMusicModel(
        id: music.id,
        title: music.title,
        artist: music.artist,
        youtubeUrl: music.youtube ?? '',
        order: 0,
      );
      final docRef = _firestore.collection('music_evaluation_forms').doc();
      final form = EvaluationFormModel(
        id: docRef.id,
        title: '${music.title} – ${category.label}',
        category: category,
        createdBy: currentUserId,
        createdAt: now,
        updatedAt: now,
        allowedUserIds: allowedUserIds,
        status: EvaluationFormStatus.active,
        musics: [evalMusic],
        musicLibraryId: music.id,
      );
      await docRef.set(form.toJson());
    }
  }
```

- [ ] **Step 3: Adicionar `fetchPendingDecisions` e `countPendingDecisions`**

```dart
  /// Retorna músicas com todos os 3 forms fechados, prontas para decisão da diretoria.
  Future<List<MusicWithEvaluations>> fetchPendingDecisions() async {
    // Busca todos os forms fechados vinculados à biblioteca
    final snapshot = await _firestore
        .collection('music_evaluation_forms')
        .where('status', isEqualTo: EvaluationFormStatus.closed.name)
        .get();

    // Agrupa por musicLibraryId (ignora forms sem vínculo)
    final formsByMusicId = <String, List<EvaluationFormModel>>{};
    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      final form = EvaluationFormModel.fromJson(data);
      if (form.musicLibraryId == null) continue;
      formsByMusicId.putIfAbsent(form.musicLibraryId!, () => []).add(form);
    }

    // Mantém apenas grupos com os 3 forms (todas as categorias)
    final eligibleMusicIds = formsByMusicId.entries
        .where((e) => e.value.length >= EvaluationCategory.values.length)
        .map((e) => e.key)
        .toList();

    if (eligibleMusicIds.isEmpty) return [];

    final results = <MusicWithEvaluations>[];
    for (final musicId in eligibleMusicIds) {
      // Verifica se a música ainda está em avaliação
      final musicDoc =
          await _firestore.collection('musics').doc(musicId).get();
      if (!musicDoc.exists) continue;
      final musicData = Map<String, dynamic>.from(musicDoc.data()!);
      musicData['id'] = musicDoc.id;
      final music = MusicModel.fromJson(musicData);
      if (music.status != MusicStatus.emAvaliacao) continue;

      // Busca todas as respostas dos 3 forms
      final forms = formsByMusicId[musicId]!;
      final allResponses = <EvaluationResponseModel>[];
      for (final form in forms) {
        final responseSnap = await _firestore
            .collection('music_evaluation_forms')
            .doc(form.id)
            .collection('responses')
            .get();
        allResponses.addAll(responseSnap.docs.map((d) {
          final rData = Map<String, dynamic>.from(d.data());
          rData['id'] = d.id;
          return EvaluationResponseModel.fromJson(rData);
        }));
      }

      results.add(MusicWithEvaluations(
        music: music,
        forms: forms,
        responses: allResponses,
      ));
    }

    return results;
  }

  /// Conta músicas prontas para decisão (para badge na tela Músicas).
  Future<int> countPendingDecisions() async {
    final list = await fetchPendingDecisions();
    return list.length;
  }
```

- [ ] **Step 4: Verificar análise estática**

```bash
flutter analyze lib/src/modules/music_evaluations/data/music_evaluations_repository.dart
```

Esperado: sem erros.

- [ ] **Step 5: Commit**

```bash
git add lib/src/modules/music_evaluations/data/music_evaluations_repository.dart
git commit -m "feat(evaluations): adicionar createFormsForMusic, fetchPendingDecisions e countPendingDecisions"
```

---

## Task 6: MusicFormSheet — retornar MusicModel + disparar criação de forms

**Files:**
- Modify: `lib/src/modules/musics/presentation/widgets/music_form_sheet.dart`
- Modify: `lib/src/modules/musics/presentation/musics_section.dart`

- [ ] **Step 1: Alterar MusicFormSheet para retornar `MusicModel?`**

Em `music_form_sheet.dart`, localizar o método `_submit()` (linha ~422).

Trocar o bloco de criação:
```dart
// ANTES
if (widget.music == null) {
  await repository.create(music);
  if (mounted) {
    Navigator.of(context).pop(true);
    showSuccessToast(context, 'Música adicionada com sucesso!');
  }
} else {
  await repository.update(music);
  if (mounted) {
    Navigator.of(context).pop(true);
    showSuccessToast(context, 'Música atualizada com sucesso!');
  }
}
```

```dart
// DEPOIS
if (widget.music == null) {
  final created = await repository.create(
    music.copyWith(status: MusicStatus.emAvaliacao),
  );
  if (mounted) {
    Navigator.of(context).pop(created);
    showSuccessToast(context, 'Música adicionada com sucesso!');
  }
} else {
  await repository.update(music);
  if (mounted) {
    Navigator.of(context).pop(true);
    showSuccessToast(context, 'Música atualizada com sucesso!');
  }
}
```

Adicionar import no topo do arquivo:
```dart
import '../models/music_status.dart';
```

A assinatura do `showModalBottomSheet` no caller é genérica (`<bool>`), então mude para `<Object?>` em `musics_section.dart` conforme o próximo step.

- [ ] **Step 2: Atualizar `_onCreateMusic` em `musics_section.dart` para disparar criação de forms**

Localizar `_onCreateMusic()` (linha ~178) e substituir por:

```dart
  Future<void> _onCreateMusic() async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const MusicFormSheet(),
    );
    if (result is! MusicModel) return;

    // Disparar criação dos 3 forms no Fórum (fire-and-forget com tratamento de erro)
    try {
      await context
          .read<MusicEvaluationsRepository>()
          .createFormsForMusic(result);
    } catch (_) {
      if (mounted) {
        showErrorToast(
          context,
          'Música salva, mas houve um erro ao criar os formulários de avaliação.',
        );
      }
    }

    await _loadMusics();
  }
```

Adicionar imports necessários no topo de `musics_section.dart`:
```dart
import '../../music_evaluations/data/music_evaluations_repository.dart';
```

- [ ] **Step 3: Verificar análise estática**

```bash
flutter analyze lib/src/modules/musics/presentation/
```

Esperado: sem erros.

- [ ] **Step 4: Commit**

```bash
git add lib/src/modules/musics/presentation/widgets/music_form_sheet.dart \
        lib/src/modules/musics/presentation/musics_section.dart
git commit -m "feat(musics): criar 3 forms no Fórum automaticamente ao adicionar nova música"
```

---

## Task 7: MusicsSection — badge de status, botão enviar, chip diretoria

**Files:**
- Modify: `lib/src/modules/musics/presentation/musics_section.dart`

- [ ] **Step 1: Adicionar estado e imports**

No topo de `musics_section.dart`, adicionar imports que ainda não existam:
```dart
import '../../societies/data/societies_repository.dart';
import '../models/music_status.dart';
import 'music_decision_page.dart';
```

Em `_MusicsSectionState`, adicionar campos de estado após `String? _error`:
```dart
  bool _isBoardMember = false;
  int _pendingDecisionsCount = 0;
```

- [ ] **Step 2: Adicionar `_checkUserRoles` e chamá-lo no `initState`**

Adicionar método em `_MusicsSectionState`:
```dart
  Future<void> _checkUserRoles() async {
    final user = context.read<AppState>().currentUser;
    if (user == null) return;
    try {
      final eloSociety = await context
          .read<SocietiesRepository>()
          .fetchByName('ELO');
      if (!mounted) return;
      final isBoard = eloSociety?.allBoardIds.contains(user.id) ?? false;
      if (!isBoard) return;
      final count = await context
          .read<MusicEvaluationsRepository>()
          .countPendingDecisions();
      if (!mounted) return;
      setState(() {
        _isBoardMember = true;
        _pendingDecisionsCount = count;
      });
    } catch (_) {}
  }
```

Adicionar import de `AppState`:
```dart
import '../../../shared/state/app_state.dart';
```

No `initState`, chamar após `_loadMusics()`:
```dart
    _checkUserRoles();
```

- [ ] **Step 3: Adicionar chip "Aguardando decisão" ao `build`**

Localizar o widget `Column` raiz do `build`. Adicionar o chip entre o `GlassContainer` da busca e o `Expanded` da lista:

```dart
        if (_isBoardMember && _pendingDecisionsCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MusicDecisionPage(),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pending_actions,
                      color: Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Aguardando decisão ($_pendingDecisionsCount)',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.amber,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
```

- [ ] **Step 4: Adicionar badge de status ao `_MusicCard`**

Em `_MusicCard.build`, após o bloco de categorias (`if (music.category.isNotEmpty)`), adicionar o badge:

```dart
                  const SizedBox(height: 8),
                  _StatusBadge(status: music.status),
```

Adicionar o widget privado `_StatusBadge` ao final do arquivo (antes do fechamento de `}` do arquivo):

```dart
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final MusicStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      MusicStatus.avaliar => (Colors.amber, Icons.star_outline),
      MusicStatus.emAvaliacao => (Colors.blue, Icons.hourglass_top),
      MusicStatus.aprovada => (Colors.green, Icons.check_circle_outline),
      MusicStatus.reprovada => (Colors.red, Icons.cancel_outlined),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          status.label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Adicionar botão "Enviar para avaliação" ao `_MusicCard`**

Em `_MusicCard`, adicionar parâmetro no construtor:
```dart
required this.canManage,
// já existe — apenas verificar
```

Na área de ações do card (onde ficam os botões de editar/excluir), adicionar o botão de envio **antes** dos botões de edição, condicionado a `canManage && music.status == MusicStatus.avaliar`:

```dart
            if (canManage && music.status == MusicStatus.avaliar)
              IconButton(
                tooltip: 'Enviar para avaliação',
                icon: const Icon(Icons.send_outlined, size: 20),
                onPressed: onSendToEvaluation,
              ),
```

Adicionar o callback `onSendToEvaluation` ao `_MusicCard`:
```dart
  final VoidCallback onSendToEvaluation;
```

No construtor:
```dart
required this.onSendToEvaluation,
```

No `itemBuilder` de `_MusicsSectionState`, passar o callback:
```dart
                          return _MusicCard(
                            music: music,
                            canManage: widget.canManage,
                            onOpen: () => _openMusic(music),
                            onEdit: () => _onEditMusic(music),
                            onDelete: () => _onDeleteMusic(music),
                            onSendToEvaluation: () => _onSendToEvaluation(music),
                          );
```

Adicionar o método `_onSendToEvaluation` em `_MusicsSectionState`:
```dart
  Future<void> _onSendToEvaluation(MusicModel music) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enviar para avaliação'),
        content: Text(
          'Deseja enviar "${music.title}" para o Fórum de Avaliação?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final repo = context.read<MusicsRepository>();
      await repo.sendToEvaluation(music.id);
      await context
          .read<MusicEvaluationsRepository>()
          .createFormsForMusic(music.copyWith(status: MusicStatus.emAvaliacao));
      if (mounted) {
        showSuccessToast(context, '"${music.title}" enviada para avaliação.');
        await _loadMusics();
      }
    } catch (_) {
      if (mounted) {
        showErrorToast(context, 'Erro ao enviar para avaliação.');
      }
    }
  }
```

- [ ] **Step 6: Verificar análise estática**

```bash
flutter analyze lib/src/modules/musics/presentation/musics_section.dart
```

Esperado: sem erros.

- [ ] **Step 7: Commit**

```bash
git add lib/src/modules/musics/presentation/musics_section.dart
git commit -m "feat(musics): badge de status, botão enviar para avaliação e chip de decisão pendente"
```

---

## Task 8: MusicDecisionPage

**Files:**
- Create: `lib/src/modules/music_evaluations/presentation/music_decision_page.dart`

- [ ] **Step 1: Criar a página**

```dart
// lib/src/modules/music_evaluations/presentation/music_decision_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/state/app_state.dart';
import '../../../shared/utils/app_toast.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../musics/data/musics_repository.dart';
import '../../musics/models/music_status.dart';
import '../data/music_evaluations_repository.dart';
import '../models/evaluation_category.dart';
import '../models/music_with_evaluations.dart';

class MusicDecisionPage extends StatefulWidget {
  const MusicDecisionPage({super.key});

  @override
  State<MusicDecisionPage> createState() => _MusicDecisionPageState();
}

class _MusicDecisionPageState extends State<MusicDecisionPage> {
  bool _isLoading = true;
  List<MusicWithEvaluations> _pending = [];

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    try {
      final list = await context
          .read<MusicEvaluationsRepository>()
          .fetchPendingDecisions();
      setState(() => _pending = list);
    } catch (_) {
      if (mounted) {
        showErrorToast(context, 'Erro ao carregar músicas pendentes.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _decide(MusicWithEvaluations item, MusicStatus status) async {
    final label = status == MusicStatus.aprovada ? 'aprovar' : 'reprovar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirmar decisão'),
        content: Text('Deseja $label "${item.music.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(label[0].toUpperCase() + label.substring(1)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await context
          .read<MusicsRepository>()
          .setFinalStatus(item.music.id, status);
      if (mounted) {
        final verb = status == MusicStatus.aprovada ? 'aprovada' : 'reprovada';
        showSuccessToast(context, '"${item.music.title}" $verb.');
        await _loadPending();
      }
    } catch (_) {
      if (mounted) showErrorToast(context, 'Erro ao registrar decisão.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aguardando decisão')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pending.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.white38),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma música\naguardando decisão.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _pending.length,
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (context, index) =>
                  _MusicDecisionCard(item: _pending[index], onDecide: _decide),
            ),
    );
  }
}

class _MusicDecisionCard extends StatelessWidget {
  const _MusicDecisionCard({required this.item, required this.onDecide});

  final MusicWithEvaluations item;
  final Future<void> Function(MusicWithEvaluations, MusicStatus) onDecide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Monta lista de respostas enriquecidas com a categoria do form correspondente
    final enrichedResponses = <({String userName, EvaluationCategory category, int rating, String? comment})>[];
    for (final form in item.forms) {
      final formResponses = item.responses.where((r) => r.formId == form.id);
      for (final r in formResponses) {
        enrichedResponses.add((
          userName: r.userName,
          category: form.category,
          rating: r.rating,
          comment: r.comment,
        ));
      }
    }

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.music.title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (item.music.artist.isNotEmpty)
            Text(
              item.music.artist,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.white60),
            ),
          const SizedBox(height: 16),

          // Carrossel de respostas
          if (enrichedResponses.isNotEmpty)
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: enrichedResponses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final r = enrichedResponses[i];
                  final categoryColor = switch (r.category) {
                    EvaluationCategory.theological => Colors.purple,
                    EvaluationCategory.congregational => Colors.teal,
                    EvaluationCategory.musical => Colors.orange,
                  };
                  return Container(
                    width: 200,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: categoryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                r.category.label,
                                style: TextStyle(
                                  color: categoryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          r.userName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(
                            5,
                            (si) => Icon(
                              si < r.rating ? Icons.star : Icons.star_outline,
                              size: 14,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        if (r.comment != null && r.comment!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              r.comment!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),

          // Botões de decisão
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onDecide(item, MusicStatus.reprovada),
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text(
                    'Reprovar',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onDecide(item, MusicStatus.aprovada),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Aprovar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verificar análise estática**

```bash
flutter analyze lib/src/modules/music_evaluations/presentation/music_decision_page.dart
```

Esperado: sem erros.

- [ ] **Step 3: Commit**

```bash
git add lib/src/modules/music_evaluations/presentation/music_decision_page.dart
git commit -m "feat(evaluations): criar MusicDecisionPage para diretoria ELO definir resultado final"
```

---

## Task 9: Fórum — chip "Ver decisão final" no viewer de respostas

**Files:**
- Modify: `lib/src/modules/music_evaluations/presentation/evaluation_responses_viewer_page.dart`

A diretoria, ao ver as respostas de um form vinculado à biblioteca (`musicLibraryId != null`) e com status `closed`, vê um chip que navega para `MusicDecisionPage`.

- [ ] **Step 1: Adicionar import**

Em `evaluation_responses_viewer_page.dart`, adicionar:
```dart
import 'music_decision_page.dart';
```

- [ ] **Step 2: Verificar se usuário é diretoria no `_loadData`**

O estado já carrega `_currentUser`. Adicionar campo booleano:
```dart
  bool _isBoardMember = false;
```

No `_loadData`, após carregar `_form` e respostas, adicionar:
```dart
      final isBoardMember = await repository.isELOBoardMember(user);
      setState(() {
        // ... campos existentes ...
        _isBoardMember = isBoardMember;
      });
```

Atualizar o `setState` existente dentro de `_loadData` para incluir `_isBoardMember`:
```dart
      setState(() {
        _form = form;
        _allResponses = allResponses;
        _currentUser = user;
        _isBoardMember = isBoardMember;
        _isLoading = false;
      });
```

- [ ] **Step 3: Adicionar chip no `build`**

No método `build`, localize onde `_form` é renderizado (após o AppBar). Adicionar o chip condicional logo após o bloco de "Total de respostas" (`GlassContainer` com o total):

```dart
          // Chip "Ver decisão final" — visível para diretoria quando form fechado e vinculado à biblioteca
          if (_isBoardMember &&
              _form!.status == EvaluationFormStatus.closed &&
              _form!.musicLibraryId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MusicDecisionPage(),
                  ),
                ),
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.pending_actions,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Ver decisão final desta música',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.amber,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
```

- [ ] **Step 4: Verificar análise estática**

```bash
flutter analyze lib/src/modules/music_evaluations/presentation/evaluation_responses_viewer_page.dart
```

Esperado: sem erros.

- [ ] **Step 5: Verificar análise estática geral**

```bash
flutter analyze lib/
```

Esperado: sem erros (apenas warnings de `withOpacity` que já existiam antes).

- [ ] **Step 6: Commit final**

```bash
git add lib/src/modules/music_evaluations/presentation/evaluation_responses_viewer_page.dart
git commit -m "feat(evaluations): adicionar chip 'Ver decisão final' no viewer de respostas para diretoria ELO"
```

---

## Checklist de verificação manual pós-implementação

- [ ] Ministro adiciona música → badge "Em avaliação" aparece no card; 3 forms criados no Fórum
- [ ] Usuário comum não vê botão + nem botão "Enviar para avaliação"
- [ ] Música existente com status "Avaliar" → ministro vê ícone de envio; ao confirmar, status muda e forms são criados
- [ ] Fórum: avaliadores das 3 categorias completam respostas → forms fecham automaticamente
- [ ] Diretoria ELO: chip "Aguardando decisão (N)" aparece na tela Músicas quando N > 0
- [ ] `MusicDecisionPage`: mostra carrossel com todas as respostas; aprovar/reprovar atualiza status
- [ ] Fórum → viewer de respostas de form fechado vinculado → chip "Ver decisão final" visível para diretoria
- [ ] Usuários sem permissão de diretoria não veem os chips/botões de decisão
- [ ] Músicas existentes sem campo `status` no Firestore continuam funcionando (status = "Avaliar")
