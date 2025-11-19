import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/core/config/firebase_config.dart';
import 'src/core/network/api_client.dart';
import 'src/modules/auth/data/auth_repository.dart';
import 'src/modules/events/data/events_repository.dart';
import 'src/modules/musics/data/musics_repository.dart';
import 'src/modules/people/data/people_repository.dart';
import 'src/shared/services/session_storage.dart';
import 'src/shared/state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseConfig.initialize();

  final apiClient = ApiClient();
  final storage = SessionStorage();
  final authRepository = AuthRepository(
    sessionStorage: storage,
  );
  final appState = AppState(authRepository: authRepository);

  await appState.bootstrap();

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
        ChangeNotifierProvider<AppState>.value(value: appState),
      ],
      child: const IpeApp(),
    ),
  );
}
