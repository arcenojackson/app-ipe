import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/firebase_config.dart';
import '../../events/presentation/event_viewer_page.dart';
import '../../events/presentation/event_editor_page.dart';
import '../../home/presentation/home_shell.dart';
import '../../../../src/app.dart';
import 'package:provider/provider.dart';
import '../../../shared/state/app_state.dart';
import '../../teaching_forum/models/teaching_access.dart';
import '../../teaching_forum/presentation/forum_topic_page.dart';
import 'teaching_notification_url.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Inicializa o serviço de notificações
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Solicitar permissões
      await _requestPermissions();

      // Configurar notificações locais
      await _initializeLocalNotifications();

      // Obter token FCM
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $_fcmToken');

      // Listener para atualização do token
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        debugPrint('FCM Token atualizado: $newToken');
        // Atualizar token no Firestore
        await _updateFcmTokenInFirestore(newToken);
      });
      
      // Salvar token inicial no Firestore
      if (_fcmToken != null) {
        await _updateFcmTokenInFirestore(_fcmToken!);
      }

      // Configurar handlers de mensagens
      _setupMessageHandlers();

      _isInitialized = true;
      debugPrint('NotificationService inicializado com sucesso');
    } catch (e) {
      debugPrint('Erro ao inicializar NotificationService: $e');
    }
  }

  /// Solicita permissões para notificações
  Future<bool> _requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('Permissão de notificação: ${settings.authorizationStatus}');
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Inicializa as notificações locais
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Configura os handlers de mensagens do Firebase
  void _setupMessageHandlers() {
    // Mensagem recebida quando o app está em foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Mensagem que abriu o app (quando estava em background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Verificar se o app foi aberto por uma notificação
    _checkInitialMessage();
  }

  /// Handler para mensagens recebidas em foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Mensagem recebida em foreground: ${message.messageId}');
    debugPrint('Título: ${message.notification?.title}');
    debugPrint('Corpo: ${message.notification?.body}');

    // Mostrar notificação local
    await _showLocalNotification(message);
  }

  /// Handler para quando o usuário toca em uma notificação que estava em background
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('App aberto por notificação: ${message.messageId}');
    _navigateFromNotification(message);
  }

  /// Verifica se o app foi aberto por uma notificação
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App iniciado por notificação: ${initialMessage.messageId}');
      // Aguardar um pouco para garantir que o app está pronto
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateFromNotification(initialMessage);
      });
    }
  }

  /// Navega para a tela apropriada baseado nos dados da notificação
  void _navigateFromNotification(RemoteMessage message) {
    final data = message.data;
    if (_handleTeachingTap(data)) return;
    final type = data['type'];
    final navigator = IpeApp.navigatorKey.currentState;
    
    if (navigator == null) {
      debugPrint('Navigator não disponível para navegação de notificação');
      return;
    }

    // Aguardar um pouco para garantir que o app está pronto
    Future.delayed(const Duration(milliseconds: 500), () {
      final currentNavigator = IpeApp.navigatorKey.currentState;
      if (currentNavigator == null) return;

      // Tipo 1: Lembrete de liturgia (diretoria) - abrir na tela Planejar
      if (type == 'event_reminder') {
        final responsibilityType = data['responsibilityType'];
        
        if (responsibilityType == 'liturgia' || responsibilityType == 'aberturaEbd') {
          final eventId = data['eventId'];
          
          if (eventId != null && eventId.isNotEmpty) {
            // Navegar para HomeShell na aba Planejar primeiro
            _navigateToHomeShellWithSection(HomeSection.planning);
            
            // Depois abrir o evento
            Future.delayed(const Duration(milliseconds: 800), () {
              final navState = IpeApp.navigatorKey.currentState;
              if (navState != null && navState.canPop()) {
                navState.push(
                  MaterialPageRoute(
                    builder: (_) => EventEditorPage(eventId: eventId),
                  ),
                );
              }
            });
          } else {
            // Sem eventId, apenas navegar para Planejar
            _navigateToHomeShellWithSection(HomeSection.planning);
          }
          return;
        }
        
        // Tipo 2: Lembrete de escalação - abrir na tela Agenda
        final eventIds = data['eventIds'];
        if (eventIds != null && eventIds.isNotEmpty) {
          // Pegar o primeiro evento (mais próximo)
          final eventIdList = eventIds.toString().split(',');
          final firstEventId = eventIdList.isNotEmpty ? eventIdList[0].trim() : null;
          
          if (firstEventId != null && firstEventId.isNotEmpty) {
            // Navegar para HomeShell na aba Agenda primeiro
            _navigateToHomeShellWithSection(HomeSection.agenda);
            
            // Depois abrir o evento
            Future.delayed(const Duration(milliseconds: 800), () {
              final navState = IpeApp.navigatorKey.currentState;
              if (navState != null && navState.canPop()) {
                navState.push(
                  MaterialPageRoute(
                    builder: (_) => EventViewerPage(eventId: firstEventId),
                  ),
                );
              }
            });
          } else {
            // Sem eventId, apenas navegar para Agenda
            _navigateToHomeShellWithSection(HomeSection.agenda);
          }
          return;
        }
      }

      // Tipo 3: Menção no chat - abrir diretamente no evento na aba Chat
      if (type == 'chat_mention') {
        final eventId = data['eventId'];
        final messageId = data['messageId'];
        if (eventId != null && eventId.isNotEmpty) {
          // Navegar para HomeShell primeiro
          _navigateToHomeShellWithSection(null);
          
          // Depois abrir o evento na aba Chat
          Future.delayed(const Duration(milliseconds: 800), () {
            final navState = IpeApp.navigatorKey.currentState;
            if (navState != null && navState.canPop()) {
              navState.push(
                MaterialPageRoute(
                  builder: (_) => EventViewerPage(
                    eventId: eventId,
                    initialTabIndex: 3, // Aba Chat
                    initialMessageId: messageId, // ID da mensagem para scrollar
                  ),
                ),
              );
            }
          });
        }
      }

      // Tipo 4: Lembrete de disponibilidade ELO - abrir na tela Agenda com destaque no botão
      if (type == 'elo_availability_reminder') {
        // Navegar para HomeShell na aba Agenda
        _navigateToHomeShellWithSection(HomeSection.agenda, highlightAvailability: true);
      }

      // Tipo 5: Inclusão em escala - abrir o evento na tela Agenda
      if (type == 'scale_inclusion') {
        final eventId = data['eventId'];
        if (eventId != null && eventId.isNotEmpty) {
          // Navegar para HomeShell na aba Agenda primeiro
          _navigateToHomeShellWithSection(HomeSection.agenda);
          
          // Depois abrir o evento
          Future.delayed(const Duration(milliseconds: 800), () {
            final navState = IpeApp.navigatorKey.currentState;
            if (navState != null && navState.canPop()) {
              navState.push(
                MaterialPageRoute(
                  builder: (_) => EventViewerPage(eventId: eventId),
                ),
              );
            }
          });
        } else {
          // Sem eventId, apenas navegar para Agenda
          _navigateToHomeShellWithSection(HomeSection.agenda);
        }
      }

      // Tipo 6: Atualização de música - abrir o evento na tela Agenda
      if (type == 'music_update') {
        final eventId = data['eventId'];
        if (eventId != null && eventId.isNotEmpty) {
          // Navegar para HomeShell na aba Agenda primeiro
          _navigateToHomeShellWithSection(HomeSection.agenda);
          
          // Depois abrir o evento
          Future.delayed(const Duration(milliseconds: 800), () {
            final navState = IpeApp.navigatorKey.currentState;
            if (navState != null && navState.canPop()) {
              navState.push(
                MaterialPageRoute(
                  builder: (_) => EventViewerPage(eventId: eventId),
                ),
              );
            }
          });
        } else {
          // Sem eventId, apenas navegar para Agenda
          _navigateToHomeShellWithSection(HomeSection.agenda);
        }
      }
    });
  }

  /// Navega para o HomeShell com uma seção específica selecionada
  void _navigateToHomeShellWithSection(HomeSection? section, {bool highlightAvailability = false}) {
    final navigator = IpeApp.navigatorKey.currentState;
    if (navigator == null) return;

    // Se já estiver na HomeShell, apenas trocar a seção usando um método diferente
    // Por enquanto, vamos substituir a rota atual
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeShell(
          initialSection: section,
          highlightAvailabilityButton: highlightAvailability,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  /// Mostra uma notificação local
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'ipe_channel',
      'IPE Notificações',
      channelDescription: 'Canal de notificações do App IPE',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Nova notificação',
      message.notification?.body ?? '',
      details,
      payload: jsonEncode(message.data),
    );
  }

  /// Avisos da plataforma pedagógica: o decisor puro escolhe entre abrir o
  /// tópico no app ou o portal no navegador. Devolve `true` se tratou o toque.
  bool _handleTeachingTap(Map<String, dynamic> data, {int attempt = 0}) {
    final type = data['type'];
    if (type != 'teaching_review' && type != 'teaching_forum') return false;
    final context = IpeApp.navigatorKey.currentContext;
    final user = context == null
        ? null
        : Provider.of<AppState>(context, listen: false).currentUser;
    // App abrindo a frio: aguarda navegação e sessão antes de decidir.
    if (type == 'teaching_forum' &&
        (context == null || user == null) &&
        attempt < 6) {
      Future.delayed(
        const Duration(milliseconds: 500),
        () => _handleTeachingTap(data, attempt: attempt + 1),
      );
      return true;
    }
    final tap = resolveTeachingTap(data, user);
    switch (tap) {
      case OpenBrowser(:final uri):
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      case OpenTopic(:final topicId):
        final viewer = forumViewerFor(user);
        final navigator = IpeApp.navigatorKey.currentState;
        if (viewer == null || navigator == null) return false;
        navigator.push(MaterialPageRoute(
          builder: (_) => ForumTopicPage(
            topicId: topicId,
            viewer: viewer,
            openPortalIfMissing: true,
          ),
        ));
        return true;
      case IgnoreTap():
        return false;
    }
  }

  /// Handler quando o usuário toca em uma notificação local
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notificação tocada: ${response.payload}');
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        _handleTeachingTap(decoded);
      }
    } catch (_) {
      // Payload antigo (não JSON): nada a fazer.
    }
  }

  /// Envia uma notificação de teste
  Future<void> sendTestNotification() async {
    try {
      // Verificar se as notificações locais foram inicializadas
      if (!_isInitialized) {
        debugPrint('NotificationService não foi inicializado. Inicializando agora...');
        await initialize();
      }

      // No iOS, verificar permissões antes de mostrar
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosPermissions = await _localNotifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );

        debugPrint('Permissões iOS para notificações locais: $iosPermissions');

        if (iosPermissions == null || iosPermissions == false) {
          debugPrint('Permissões de notificação local não foram concedidas no iOS');
          throw Exception(
              'Permissões de notificação não foram concedidas. Verifique as configurações do dispositivo.');
        }
      }

      // Criar canal para Android
      const androidDetails = AndroidNotificationDetails(
        'ipe_channel',
        'IPE Notificações',
        channelDescription: 'Canal de notificações do App IPE',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      // Configurações para iOS
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      debugPrint('Tentando mostrar notificação de teste...');

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'Notificação de Teste',
        'Esta é uma notificação de teste do App IPE! 🎉',
        details,
      );

      debugPrint('Notificação de teste exibida com sucesso');
    } catch (e) {
      debugPrint('Erro ao enviar notificação de teste: $e');
      rethrow;
    }
  }

  /// Cancela todas as notificações
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Verifica se as notificações estão habilitadas no sistema
  Future<bool> areNotificationsEnabled() async {
    final settings = await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Atualiza o FCM token no Firestore
  Future<void> _updateFcmTokenInFirestore(String token) async {
    try {
      final user = FirebaseConfig.auth.currentUser;
      if (user != null) {
        await FirebaseConfig.firestore
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
        debugPrint('FCM token salvo no Firestore para usuário ${user.uid}');
      }
    } catch (e) {
      debugPrint('Erro ao salvar FCM token no Firestore: $e');
    }
  }
}
