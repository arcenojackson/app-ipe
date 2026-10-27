import 'forum_models.dart';

const forumTitleMin = 3;
const forumTitleMax = 120;
const forumBodyMax = 5000;
const forumMaxTags = 3;
const forumMaxRefs = 3;
const forumMaxTokenLength = 20;
const forumMaxTokens = 150;

class ForumViewer {
  const ForumViewer({
    required this.uid,
    this.isCurator = false,
    this.isAdmin = false,
  });
  final String uid;
  final bool isCurator;
  final bool isAdmin;
  bool get isModerator => isCurator || isAdmin;
}

class TopicPermissions {
  const TopicPermissions({
    required this.canEdit,
    required this.canDelete,
    required this.canPin,
    required this.canLock,
    required this.canComment,
    required this.visibleBody,
  });
  final bool canEdit, canDelete, canPin, canLock, canComment, visibleBody;
}

TopicPermissions topicPermissions(ForumTopic t, ForumViewer v) {
  final author = t.authorUid == v.uid;
  final mod = v.isModerator;
  return TopicPermissions(
    canEdit: author && !t.deleted,
    canDelete: !t.deleted && (author || mod),
    canPin: mod && !t.deleted,
    canLock: mod && !t.deleted,
    canComment: !t.locked && !t.deleted,
    visibleBody: !t.deleted || author || mod,
  );
}

class CommentPermissions {
  const CommentPermissions({
    required this.canReply,
    required this.canVote,
    required this.canEdit,
    required this.canDelete,
  });
  final bool canReply, canVote, canEdit, canDelete;
}

CommentPermissions commentPermissions(
  ForumComment c,
  ForumTopic t,
  ForumViewer v,
) {
  final author = c.authorUid == v.uid;
  final open = !t.locked && !t.deleted && !c.deleted;
  return CommentPermissions(
    canReply: open && c.depth < forumMaxDepth,
    canVote: open && !author,
    canEdit: author && !c.deleted,
    canDelete: !c.deleted && (author || v.isModerator),
  );
}

class CommentNode {
  CommentNode(this.comment);
  final ForumComment comment;
  final List<CommentNode> children = [];
}

/// Aninha por `parentId`, ordena por data; órfãos vão para a raiz.
List<CommentNode> buildCommentTree(List<ForumComment> comments) {
  final sorted = [...comments]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final nodes = {for (final c in sorted) c.id: CommentNode(c)};
  final roots = <CommentNode>[];
  for (final c in sorted) {
    final parent = c.parentId == null ? null : nodes[c.parentId];
    (parent == null ? roots : parent.children).add(nodes[c.id]!);
  }
  return roots;
}

String? _validateBody(String body, int refCount) {
  final size = body.trim().length;
  if (size < 1 || size > forumBodyMax) {
    return 'A mensagem deve ter de 1 a $forumBodyMax caracteres.';
  }
  if (refCount > forumMaxRefs) return 'Cite no máximo $forumMaxRefs itens.';
  return null;
}

String? validateTopicInput(ForumTopicInput input) {
  final size = input.title.trim().length;
  if (size < forumTitleMin || size > forumTitleMax) {
    return 'O título deve ter de $forumTitleMin a $forumTitleMax caracteres.';
  }
  if (input.tagIds.length > forumMaxTags) {
    return 'Escolha no máximo $forumMaxTags assuntos.';
  }
  return _validateBody(input.body, input.refs.length);
}

String? validateCommentInput(ForumCommentInput input) =>
    _validateBody(input.body, input.refs.length);

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'é': 'e', 'è': 'e',
  'ê': 'e', 'ë': 'e', 'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ó': 'o',
  'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ú': 'u', 'ù': 'u', 'û': 'u',
  'ü': 'u', 'ç': 'c', 'ñ': 'n',
};

String normalizeForumText(String text) {
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    out.write(_accents[ch] ?? ch);
  }
  return out.toString();
}

final _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

List<String> searchWords(String text) => normalizeForumText(text)
    .split(_nonWord)
    .where((w) => w.length >= 2)
    .toList();

/// Prefixos (2 a 20 letras) de cada palavra, iguais aos do portal.
List<String> searchTokens(String text) {
  final tokens = <String>{};
  for (final word in searchWords(text)) {
    final longest = word.length < forumMaxTokenLength
        ? word.length
        : forumMaxTokenLength;
    for (var length = 2; length <= longest; length++) {
      if (tokens.length >= forumMaxTokens) return tokens.toList();
      tokens.add(word.substring(0, length));
    }
  }
  return tokens.toList();
}

class TopicQuerySpec {
  const TopicQuerySpec({this.tagId, this.token, this.words = const []});
  final String? tagId;
  final String? token;
  final List<String> words;
}

TopicQuerySpec topicQueryFrom({String? tagId, String? search}) {
  final words = searchWords(search ?? '');
  final tag = (tagId == null || tagId.isEmpty) ? null : tagId;
  if (tag != null && words.isNotEmpty) {
    throw ArgumentError('Use assunto ou busca, não os dois juntos.');
  }
  var longest = '';
  for (final w in words) {
    if (w.length > longest.length) longest = w;
  }
  return TopicQuerySpec(
    tagId: tag,
    token: longest.isEmpty
        ? null
        : longest.substring(
            0, longest.length < forumMaxTokenLength ? longest.length : forumMaxTokenLength),
    words: words,
  );
}

/// Todas as palavras da busca são prefixo de alguma palavra do título.
bool forumTitleMatches(String title, List<String> words) {
  if (words.isEmpty) return true;
  final titleWords = searchWords(title);
  return words.every((w) => titleWords.any((t) => t.startsWith(w)));
}

class LinkSegment {
  const LinkSegment(this.value, {required this.isLink});
  final String value;
  final bool isLink;
  @override
  bool operator ==(Object other) =>
      other is LinkSegment && other.value == value && other.isLink == isLink;
  @override
  int get hashCode => Object.hash(value, isLink);
  @override
  String toString() => 'LinkSegment($value, $isLink)';
}

final _urlPattern = RegExp(r'''https?://[^\s<>"']+''');
final _trailing = RegExp(r'[.,;:!?)\]]+$');

/// Só http(s) vira link; todo o resto continua texto.
List<LinkSegment> linkify(String text) {
  final parts = <LinkSegment>[];
  var last = 0;
  for (final m in _urlPattern.allMatches(text)) {
    final url = m.group(0)!.replaceAll(_trailing, '');
    if (m.start > last) {
      parts.add(LinkSegment(text.substring(last, m.start), isLink: false));
    }
    parts.add(LinkSegment(url, isLink: true));
    last = m.start + url.length;
  }
  if (last < text.length) {
    parts.add(LinkSegment(text.substring(last), isLink: false));
  }
  return parts;
}
