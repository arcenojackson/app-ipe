import 'package:flutter/foundation.dart';

import '../data/forum_repository.dart';
import '../models/forum_logic.dart';
import '../models/forum_models.dart';

class ForumEditorController extends ChangeNotifier {
  ForumEditorController({
    required this.repository,
    required this.author,
    this.editing,
  }) : selectedTags = {...?editing?.tagIds};

  final ForumRepository repository;
  final ForumAuthor author;
  final ForumTopic? editing;

  final Set<String> selectedTags;
  List<SubjectTag> tags = [];
  bool saving = false;
  String? error;

  Future<void> loadTags() async {
    try {
      tags = await repository.loadSubjectTags();
    } catch (_) {}
    notifyListeners();
  }

  /// Devolve `false` se já houver 3 assuntos marcados.
  bool toggleTag(String id) {
    if (selectedTags.remove(id)) {
      notifyListeners();
      return true;
    }
    if (selectedTags.length >= forumMaxTags) return false;
    selectedTags.add(id);
    notifyListeners();
    return true;
  }

  /// Devolve o id do tópico; `null` em erro (os campos permanecem).
  Future<String?> save(String title, String body) async {
    if (saving) return null;
    final input = ForumTopicInput(
      title: title,
      body: body,
      tagIds: selectedTags.toList(),
      refs: editing?.refs ?? const [],
    );
    final invalid = validateTopicInput(input);
    if (invalid != null) {
      error = invalid;
      notifyListeners();
      return null;
    }
    saving = true;
    error = null;
    notifyListeners();
    try {
      final id = editing == null
          ? await repository.createTopic(input, author)
          : editing!.id;
      if (editing != null) await repository.updateTopic(id, input);
      saving = false;
      notifyListeners();
      return id;
    } catch (e) {
      error = e.toString().contains('permission-denied')
          ? 'Sem permissão para esta ação.'
          : 'Não foi possível salvar. Tente de novo.';
      saving = false;
      notifyListeners();
      return null;
    }
  }
}
