const String _teachingPortalHost = 'ipe-ensino.vercel.app';

/// Endereço do portal de ensino a abrir quando a notificação é de curadoria.
///
/// Só devolve um endereço `https` do host do portal; qualquer outro valor
/// (outro host, http, esquema estranho, dado ausente) resulta em `null`, para
/// que uma notificação nunca abra um endereço arbitrário.
Uri? teachingPortalUriFromData(Map<String, dynamic> data) {
  if (data['type'] != 'teaching_review') return null;
  final raw = data['url'];
  if (raw is! String || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (uri.scheme != 'https' || uri.host != _teachingPortalHost) return null;
  if (uri.userInfo.isNotEmpty) return null;
  return uri;
}
