import '../../teaching_forum/models/teaching_access.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/state/app_state.dart';
import '../../../shared/utils/app_toast.dart';
import '../../../shared/widgets/glass_container.dart';
import '../models/notification_type.dart';
import '../repositories/notification_repository.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final NotificationRepository _repository = NotificationRepository();
  bool _isLoading = true;
  List<String> _disabledNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = context.read<AppState>().currentUser;
    if (user == null) return;

    try {
      final disabled = await _repository.getDisabledNotifications(user.id);
      if (mounted) {
        setState(() {
          _disabledNotifications = disabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorToast(context, 'Erro ao carregar configurações');
      }
    }
  }

  Future<void> _toggleNotification(NotificationType type, bool enabled) async {
    final appState = context.read<AppState>();
    final user = appState.currentUser;
    if (user == null) return;

    try {
      if (enabled) {
        await _repository.enableNotification(user.id, type);
      } else {
        await _repository.disableNotification(user.id, type);
      }

      // Atualizar estado local (lógica inversa)
      setState(() {
        if (enabled) {
          _disabledNotifications = _disabledNotifications
              .where((id) => id != type.id)
              .toList();
        } else {
          if (!_disabledNotifications.contains(type.id)) {
            _disabledNotifications = [..._disabledNotifications, type.id];
          }
        }
      });

      // Atualizar o UserModel no AppState com as novas preferências
      if (mounted) {
        final updatedUser = user.copyWith(
          disabledNotifications: _disabledNotifications,
        );
        // Forçar atualização do usuário no AppState
        // Nota: O AppState não tem método para atualizar diretamente,
        // mas o usuário será atualizado no próximo login ou quando o app buscar do Firestore
      }

      if (mounted) {
        showSuccessToast(
          context,
          enabled ? 'Notificação ativada' : 'Notificação desativada',
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao atualizar configuração');
      }
    }
  }

  /// Verifica se uma notificação está habilitada (lógica inversa)
  bool _isNotificationEnabled(NotificationType type) {
    return !_disabledNotifications.contains(type.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1220), Color(0xFF05070D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Gerenciar notificações',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Conteúdo
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: [
                          // Descrição
                          GlassContainer(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.notifications_active,
                                    color: theme.colorScheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Escolha quais notificações você deseja receber',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Lista de notificações
                          Text(
                            'Tipos de notificação',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 12),

                          GlassContainer(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                // Filtrar notificações, removendo eventUpdate
                                Builder(
                                  builder: (context) {
                                    final visibleTypes = NotificationType.values
                                        .where(
                                          (type) =>
                                              type !=
                                                  NotificationType
                                                      .eventUpdate &&
                                              (type !=
                                                      NotificationType
                                                          .teachingForum ||
                                                  canUseTeachingForum(
                                                    context
                                                        .read<AppState>()
                                                        .currentUser,
                                                  )),
                                        )
                                        .toList();
                                    return Column(
                                      children: [
                                        for (
                                          int i = 0;
                                          i < visibleTypes.length;
                                          i++
                                        ) ...[
                                          _buildNotificationTile(
                                            visibleTypes[i],
                                          ),
                                          if (i < visibleTypes.length - 1)
                                            const Divider(
                                              height: 1,
                                              color: Colors.white12,
                                            ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationTile(NotificationType type) {
    final theme = Theme.of(context);
    final isEnabled = _isNotificationEnabled(type);

    return SwitchListTile(
      value: isEnabled,
      onChanged: (value) => _toggleNotification(type, value),
      activeColor: theme.colorScheme.primary,
      title: Text(
        type.title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        type.description,
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }
}
