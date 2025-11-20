import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'modules/auth/presentation/login_page.dart';
import 'modules/home/presentation/home_shell.dart';
import 'shared/state/app_state.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/splash_page.dart';

class IpeApp extends StatelessWidget {
  const IpeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return MaterialApp(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          // Usar key baseado no estado de autenticação para forçar reconstrução
          key: ValueKey('app-${appState.isAuthenticated}'),
          home: _buildHome(appState),
        );
      },
    );
  }

  Widget _buildHome(AppState state) {
    if (state.isBootstrapping) {
      return const SplashPage();
    }
    if (!state.isAuthenticated) {
      return const LoginPage();
    }
    return const HomeShell();
  }
}
