import '../../societies/models/society.dart';

/// URL base do portal web (votação em /votar/{id}, condução em /eleicoes/{id}).
/// Fica aqui, e não em AppConfig, para a lógica continuar testável sem o
/// `app_secrets.dart` (gitignorado) que AppConfig importa.
const String portalBaseUrl = String.fromEnvironment(
  'PORTAL_BASE_URL',
  defaultValue: 'https://ipe-ensino.vercel.app',
);

/// Título sugerido ao criar uma eleição.
String defaultElectionTitle(String societyName, int year) {
  final name = societyName.trim();
  return name.isEmpty
      ? 'Eleição da diretoria $year'
      : 'Eleição da diretoria $name $year';
}

/// Link que as pessoas abrem (QR) para votar.
String buildVoteLink(String electionId) => '$portalBaseUrl/votar/$electionId';

/// Link da tela web em que os diretores conduzem a eleição.
String buildConductLink(String electionId) =>
    '$portalBaseUrl/eleicoes/$electionId';

/// Sociedades em que [userId] está na diretoria (qualquer cargo): só nelas a
/// pessoa pode criar eleição. O servidor repete essa conferência.
List<SocietyModel> directorSocieties(
  List<SocietyModel> societies,
  String userId,
) =>
    societies.where((s) => s.allBoardIds.contains(userId)).toList();
