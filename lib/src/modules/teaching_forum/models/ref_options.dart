import 'forum_logic.dart';
import 'forum_models.dart';

/// Opção do seletor de citação; [tagIds] alimenta os chips da Biblioteca.
class RefOption {
  const RefOption({required this.ref, this.isLink = false, this.tagIds = const []});

  final ForumRef ref;
  final bool isLink;
  final List<String> tagIds;
}

List<String> _strings(Object? raw) =>
    raw is List ? raw.whereType<String>().toList() : <String>[];

/// Documento da Biblioteca (`teaching_items`) como opção de citação.
/// Pastas, tipos desconhecidos e itens sem nome não viram opção.
RefOption? libraryOptionFrom(String id, Map<String, dynamic> data) {
  final type = data['type'];
  final name = data['name'];
  if ((type != 'file' && type != 'link') || name is! String || name.trim().isEmpty) {
    return null;
  }
  return RefOption(
    ref: ForumRef(kind: 'library', id: id, label: name),
    isLink: type == 'link',
    tagIds: [
      ..._strings(data['typeTags']),
      ..._strings(data['subjectTags']),
      ..._strings(data['ageTags']),
    ],
  );
}

/// Aula do Plano (`teaching_plan`) como citação "Aula N — Tema".
ForumRef? planRefFrom(String id, Map<String, dynamic> data) {
  final lesson = data['lesson'];
  final theme = data['theme'];
  if (lesson is! num || theme is! String) return null;
  return ForumRef(kind: 'plan', id: id, label: 'Aula ${lesson.toInt()} — $theme');
}

/// Todas as palavras da busca aparecem no nome (como o portal).
bool refNameMatches(String name, List<String> words) {
  if (words.isEmpty) return true;
  final normalized = normalizeForumText(name);
  return words.every(normalized.contains);
}
