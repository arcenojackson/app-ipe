import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/core/config/firebase_config.dart';
import 'src/core/network/api_client.dart';
import 'src/modules/auth/data/auth_repository.dart';
import 'src/modules/events/data/events_repository.dart';
import 'src/modules/musics/data/musics_repository.dart';
import 'src/modules/people/data/people_repository.dart';
import 'src/modules/elections/data/elections_repository.dart';
import 'src/modules/societies/data/societies_repository.dart';
import 'src/modules/events/data/weekly_team_assignments_repository.dart';
import 'src/modules/music_evaluations/data/music_evaluations_repository.dart';
import 'src/shared/services/pexels/pexels_client.dart';
import 'src/shared/services/session_storage.dart';
import 'src/shared/state/app_state.dart';
import 'src/modules/notifications/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge explícito (Android 15+ / avisos do Play Console)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Inicializar formato de data para português brasileiro
  await initializeDateFormatting('pt_BR', null);

  await FirebaseConfig.initialize();

  final apiClient = ApiClient();
  final storage = SessionStorage();
  final authRepository = AuthRepository(
    sessionStorage: storage,
  );
  final appState = AppState(authRepository: authRepository);
  final societiesRepository = SocietiesRepository();

  await appState.bootstrap();

  // Firebase Messaging não tem suporte web — notificações ignoradas na web
  if (!kIsWeb) {
    await NotificationService().initialize();
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<SessionStorage>.value(value: storage),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<EventsRepository>.value(
          value: EventsRepository(apiClient: apiClient),
        ),
        Provider<MusicsRepository>.value(
          value: MusicsRepository(apiClient: apiClient),
        ),
        Provider<PeopleRepository>.value(
          value: PeopleRepository(apiClient: apiClient),
        ),
        Provider<SocietiesRepository>.value(
          value: societiesRepository,
        ),
        Provider<ElectionsRepository>.value(value: ElectionsRepository()),
        Provider<WeeklyTeamAssignmentsRepository>.value(
          value: WeeklyTeamAssignmentsRepository(),
        ),
        Provider<MusicEvaluationsRepository>.value(
          value: MusicEvaluationsRepository(
            societiesRepository: societiesRepository,
          ),
        ),
        Provider<PexelsClient>.value(value: PexelsClient()),
        // Usar ChangeNotifierProvider.value mas garantir que as notificações funcionem
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          // Não usar lazy: false pois já temos a instância criada
        ),
      ],
      child: const IpeApp(),
    ),
  );
}
