import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/state/app_state.dart';
import '../../../shared/utils/app_toast.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../events/presentation/event_history_page.dart';
import '../../events/presentation/event_template_page.dart';
import '../../events/presentation/calendar_page.dart';
import '../../societies/presentation/societies_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final user = appState.currentUser;

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
                    Text(
                      'Configurações',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    // Seção de Perfil
                    if (user != null) ...[
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Perfil',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: theme.colorScheme.primary
                                      .withOpacity(0.15),
                                  child: Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : '?',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.email,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: Colors.white60),
                                      ),
                                      if (user.isAdmin) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            'Administrador',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Seção de Sociedades internas
                    Text(
                      'Sociedades internas',
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
                          ListTile(
                            leading: const Icon(
                              Icons.groups,
                              color: Colors.white70,
                            ),
                            title: const Text(
                              'Equipes e Diretorias',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Gerenciar equipes e diretorias das sociedades e ministérios',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white60,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white54,
                            ),
                            onTap: () => _navigateToSocieties(context),
                          ),
                          const Divider(height: 1, color: Colors.white12),
                          ListTile(
                            leading: const Icon(
                              Icons.calendar_month,
                              color: Colors.white70,
                            ),
                            title: const Text(
                              'Calendário anual',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Visualizar e gerenciar eventos do calendário',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white60,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white54,
                            ),
                            onTap: () => _navigateToCalendar(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Seção de Liturgias
                    Text(
                      'Liturgias',
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
                          ListTile(
                            leading: const Icon(
                              Icons.history,
                              color: Colors.white70,
                            ),
                            title: const Text(
                              'Histórico de liturgias',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Visualizar todos os eventos passados',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white60,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white54,
                            ),
                            onTap: () => _navigateToEventHistory(context),
                          ),
                          const Divider(height: 1, color: Colors.white12),
                          ListTile(
                            leading: const Icon(
                              Icons.settings_outlined,
                              color: Colors.white70,
                            ),
                            title: const Text(
                              'Templates de liturgias',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Personalizar etapas padrão dos eventos',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white60,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white54,
                            ),
                            onTap: () => _navigateToEventTemplate(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Seção de Conta
                    Text(
                      'Conta',
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
                          ListTile(
                            leading: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade300,
                            ),
                            title: Text(
                              'Excluir Conta',
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Excluir permanentemente sua conta e todos os dados',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white60,
                              ),
                            ),
                            onTap: () =>
                                _showDeleteAccountDialog(context, appState),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botão Sair
                    GlassContainer(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(
                          Icons.logout,
                          color: Colors.white70,
                        ),
                        title: const Text(
                          'Sair',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Fazer logout da sua conta',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                        onTap: () => _showSignOutDialog(context, appState),
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

  void _showDeleteAccountDialog(BuildContext context, AppState appState) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Excluir Conta', style: theme.textTheme.titleLarge),
        content: Text(
          'Tem certeza que deseja excluir sua conta? Esta ação não pode ser desfeita e todos os seus dados serão permanentemente removidos.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Fechar diálogo
              await _deleteAccount(context, appState);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade300),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, AppState appState) async {
    try {
      // Executar exclusão
      await appState.deleteAccount();

      // Aguardar um frame para garantir que o estado foi processado
      await Future.delayed(const Duration(milliseconds: 50));

      // Fechar a tela de configurações
      // O IpeApp automaticamente redirecionará para login quando isAuthenticated for false
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        final errorMessage = e.toString().contains('requires-recent-login')
            ? 'Por segurança, faça login novamente antes de excluir a conta'
            : 'Erro ao excluir conta: ${e.toString()}';
        showErrorToast(context, errorMessage);
      }
    }
  }

  Future<void> _signOut(BuildContext context, AppState appState) async {
    try {
      await appState.signOut();
      // O IpeApp automaticamente redirecionará para login quando isAuthenticated for false
      // Apenas fechar a tela de configurações
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        showErrorToast(context, 'Erro ao fazer logout: ${e.toString()}');
      }
    }
  }

  void _showSignOutDialog(BuildContext context, AppState appState) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Sair', style: theme.textTheme.titleLarge),
        content: Text(
          'Tem certeza que deseja sair?',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancelar',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _signOut(context, appState);
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  void _navigateToEventHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const EventHistoryPage(),
      ),
    );
  }

  void _navigateToEventTemplate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const EventTemplatePage(),
      ),
    );
  }

  void _navigateToCalendar(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CalendarPage(),
      ),
    );
  }

  void _navigateToSocieties(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SocietiesPage(),
      ),
    );
  }
}
