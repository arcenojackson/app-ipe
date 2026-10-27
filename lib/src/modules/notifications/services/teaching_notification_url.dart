import '../../auth/models/user.dart';
import '../../teaching_forum/models/teaching_access.dart';

const String _teachingPortalHost = 'ipe-ensino.vercel.app';

/// Endereço do portal de ensino a abrir quando a notificação é de curadoria.
///
/// Só devolve um endereço `https` do host do portal; qualquer outro valor
/// (outro host, http, esquema estranho, dado ausente) resulta em `null`, para
/// que uma notificação nunca abra um endereço arbitrário.
Uri? teachingPortalUriFromData(Map<String, dynamic> data) {
  if (data['type'] != 'teaching_review') return null;
  return _portalUri(data);
}

Uri? _portalUri(Map<String, dynamic> data) {
  final raw = data['url'];
  if (raw is! String || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (uri.scheme != 'https' || uri.host != _teachingPortalHost) return null;
  if (uri.userInfo.isNotEmpty) return null;
  return uri;
}

final _topicIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// Id do tópico de um aviso de resposta do Fórum, ou `null` se não for um.
String? teachingForumTopicIdFromData(Map<String, dynamic> data) {
  if (data['type'] != 'teaching_forum') return null;
  final id = data['topicId'];
  if (id is! String || !_topicIdPattern.hasMatch(id)) return null;
  return id;
}

/// O que fazer ao tocar num aviso da plataforma pedagógica.
sealed class TeachingTap {
  const TeachingTap();
}

/// Abrir o tópico dentro do app.
class OpenTopic extends TeachingTap {
  const OpenTopic(this.topicId);
  final String topicId;
}

/// Abrir o portal no navegador.
class OpenBrowser extends TeachingTap {
  const OpenBrowser(this.uri);
  final Uri uri;
}

/// Não é um aviso desta plataforma (ou é inválido): seguir o fluxo normal.
class IgnoreTap extends TeachingTap {
  const IgnoreTap();
}

TeachingTap resolveTeachingTap(Map<String, dynamic> data, UserModel? user) {
  final review = teachingPortalUriFromData(data);
  if (review != null) return OpenBrowser(review);
  if (data['type'] != 'teaching_forum') return const IgnoreTap();
  final topicId = teachingForumTopicIdFromData(data);
  if (topicId != null && canUseTeachingForum(user)) return OpenTopic(topicId);
  final portal = _portalUri(data);
  return portal == null ? const IgnoreTap() : OpenBrowser(portal);
}
