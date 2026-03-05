import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/config/firebase_config.dart';
import 'modules/auth/presentation/login_page.dart';
import 'modules/home/presentation/home_shell.dart';
import 'shared/state/app_state.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/splash_page.dart';

class IpeApp extends StatelessWidget {
  const IpeApp({super.key});

  // GlobalKey para permitir navegação de qualquer lugar do app
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AppHome(),
    );
  }
}

// Widget que gerencia a navegação baseada no estado de autenticação
class _AppHome extends StatefulWidget {
  const _AppHome();

  @override
  State<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<_AppHome> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Renovar o token ao voltar do background para evitar "permission-denied"
      // em leituras do Firestore (ex.: tela Agenda) quando o app ficou fechado por um tempo.
      FirebaseConfig.auth.currentUser?.getIdToken(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        // Construir a tela baseada no estado com uma key única
        // Isso força o Flutter a destruir e recriar o widget quando o estado muda
        final authKey = '${appState.isBootstrapping}-${appState.isAuthenticated}';
        
        if (appState.isBootstrapping) {
          return SplashPage(key: ValueKey('splash-$authKey'));
        }
        if (!appState.isAuthenticated) {
          return LoginPage(key: ValueKey('login-$authKey'));
        }
        return HomeShell(key: ValueKey('home-$authKey'));
      },
    );
  }
}
