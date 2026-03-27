import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../../app.dart';
import '../../../shared/state/app_state.dart';
import '../../../shared/utils/app_toast.dart';
import '../../../shared/widgets/glass_container.dart';
import 'package:ipe_flutter/src/modules/holyrics/presentation/holyrics_settings_screen.dart';
import '../../events/presentation/event_history_page.dart';
import '../../events/presentation/event_template_page.dart';
import '../../events/presentation/calendar_page.dart';
import '../../events/presentation/weekly_team_assignments_page.dart';
import '../../people/presentation/people_section.dart';
import '../../people/presentation/widgets/invite_person_sheet.dart';
import '../../societies/presentation/societies_page.dart';
import '../../notifications/presentation/notification_settings_page.dart';
import '../../music_evaluations/presentation/evaluations_list_page.dart';
import '../../events/presentation/elo_availability_status_page.dart';
import '../../societies/data/societies_repository.dart';
import '../../societies/presentation/elo_roles_config_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isEditingName = false;
  final TextEditingController _nameController = TextEditingController();
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'Versão ${packageInfo.version}';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';

    final words = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';

    if (words.length == 1) {
      return words[0][0].toUpperCase();
    }

    // Pegar as primeiras duas iniciais
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

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
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: theme.colorScheme.primary
                                  .withOpacity(0.15),
                              child: Text(
                                _getInitials(
                                  _isEditingName
                                      ? _nameController.text
                                      : user.name,
                                ),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _isEditingName
                                            ? TextField(
                                                controller: _nameController,
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                decoration: InputDecoration(
                                                  filled: true,
                                                  fillColor: Colors.white
                                                      .withOpacity(0.1),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 12,
                                                      ),
                                                  suffixIcon:
                                                      _nameController
                                                          .text
                                                          .isNotEmpty
                                                      ? IconButton(
                                                          icon: const Icon(
                                                            Icons.close,
                                                            color:
                                                                Colors.white70,
                                                            size: 20,
                                                          ),
                                                          onPressed: () {
                                                            setState(() {
                                                              _nameController
                                                                  .clear();
                                                            });
                                                          },
                                                        )
                                                      : null,
                                                ),
                                                onChanged: (value) {
                                                  setState(() {});
                                                },
                                              )
                                            : Text(
                                                user.name,
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: Icon(
                                          _isEditingName
                                              ? Icons.save
                                              : Icons.edit,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                        onPressed: _isEditingName
                                            ? () => _saveUserName(
                                                context,
                                                appState,
                                              )
                                            : () {
                                                setState(() {
                                                  _isEditingName = true;
                                                  _nameController.text =
                                                      user.name;
                                                });
                                              },
                                        tooltip: _isEditingName
                                            ? 'Salvar'
                                            : 'Editar nome',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.email,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white60,
                                    ),
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
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Administrador',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.colorScheme.primary,
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
                              Icons.person_rounded,
                              color: Colors.white70,
                            ),
                            title: const Text(
                              'Pessoas',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Gerenciar perfis',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white60,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white54,
                            ),
                            onTap: () => _navigateToPeople(context),
                          ),
                          const Divider(height: 1, color: Colors.white12),
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
                              'Gerenciar diretorias e membros das sociedades/equipes',
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
                              'Gerenciar eventos',
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
                          if (user?.isAdmin == true) ...[
                            const Divider(height: 1, color: Colors.white12),
                            ListTile(
                              leading: const Icon(
                                Icons.assignment,
                                color: Colors.white70,
                              ),
                              title: const Text(
                                'Responsáveis semanais',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                'Gerenciar responsabilidades de cada semana',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white60,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Colors.white54,
                              ),
                              onTap: () =>
                                  _navigateToWeeklyAssignments(context),
                            ),
                          ],
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

                    // Seção de Equipe de Louvor
                    Builder(
                      builder: (context) {
                        final appState = context.watch<AppState>();
                        final user = appState.currentUser;
                        if (user == null) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Equipe de Louvor',
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
                                  // Opção "Avaliação de Músicas" - condicional
                                  FutureBuilder<bool>(
                                    future: _canAccessEvaluations(
                                      context,
                                      user,
                                    ),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData &&
                                          snapshot.data == true) {
                                        return Column(
                                          children: [
                                            ListTile(
                                              leading: const Icon(
                                                Icons.rate_review,
                                                color: Colors.white70,
                                              ),
                                              title: const Text(
                                                'Avaliação de Músicas',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              subtitle: Text(
                                                'Avaliar músicas por coerência teológica, congregacional e musical',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: Colors.white60,
                                                    ),
                                              ),
                                              trailing: const Icon(
                                                Icons.chevron_right,
                                                color: Colors.white54,
                                              ),
                                              onTap: () =>
                                                  _navigateToEvaluations(
                                                    context,
                                                  ),
                                            ),
                                            const Divider(
                                              height: 1,
                                              color: Colors.white12,
                                            ),
                                          ],
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                  // Opção "Vocais e Ministros" - para quem pode editar ELO
                                  FutureBuilder<bool>(
                                    future: _canEditElo(context, user),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData &&
                                          snapshot.data == true) {
                                        return Column(
                                          children: [
                                            ListTile(
                                              leading: const Icon(
                                                Icons.music_note,
                                                color: Colors.white70,
                                              ),
                                              title: const Text(
                                                'Vocais e Ministros',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              subtitle: Text(
                                                'Definir quem são vocais e ministros na equipe de louvor',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: Colors.white60,
                                                    ),
                                              ),
                                              trailing: const Icon(
                                                Icons.chevron_right,
                                                color: Colors.white54,
                                              ),
                                              onTap: () =>
                                                  _navigateToEloRolesConfig(
                                                    context,
                                                  ),
                                            ),
                                            const Divider(
                                              height: 1,
                                              color: Colors.white12,
                                            ),
                                          ],
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                  // Opção "Status de Disponibilidades" - sempre visível
                                  ListTile(
                                    leading: const Icon(
                                      Icons.calendar_today,
                                      color: Colors.white70,
                                    ),
                                    title: const Text(
                                      'Status de Disponibilidades',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Visualizar disponibilidades dos membros da ELO para o próximo mês',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.white60),
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white54,
                                    ),
                                    onTap: () =>
                                        _navigateToAvailabilityStatus(context),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    ),

                    // Seção de Integrações (Holyrics) - penúltima seção
                    Text(
                      'Integrações',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassContainer(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(
                          Icons.settings_input_component,
                          color: Colors.white70,
                        ),
                        title: const Text(
                          'Holyrics',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Configurar integração local com Holyrics',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HolyricsSettingsScreen(),
                            ),
                          );
                        },
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
                            leading: const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white70,
                            ),
                            title: const Text(
                              'Gerenciar notificações',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Configure quais notificações você deseja receber',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white60,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white54,
                            ),
                            onTap: () =>
                                _navigateToNotificationSettings(context),
                          ),
                          const Divider(height: 1, color: Colors.white12),
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
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        _appVersion,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white38,
                        ),
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
      // Fazer logout primeiro
      await appState.signOut();

      // Fechar a tela de configurações antes de navegar
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Usar o navigatorKey global para limpar toda a pilha de navegação
      // Isso garante que voltemos para a tela inicial (LoginPage)
      final navigator = IpeApp.navigatorKey.currentState;
      if (navigator != null) {
        // Limpar toda a pilha de navegação
        navigator.popUntil((route) => route.isFirst);
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
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EventHistoryPage()));
  }

  void _navigateToEventTemplate(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EventTemplatePage()));
  }

  void _navigateToCalendar(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CalendarPage()));
  }

  void _navigateToPeople(BuildContext context) {
    final user = context.read<AppState>().currentUser;
    if (user == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
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
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                            'Pessoas',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PeopleSection(
                      currentUser: user,
                      hideFloatingButton: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: (user.isAdminUser)
              ? FloatingActionButton(
                  onPressed: () => _showInvitePersonSheet(context, user),
                  child: const Icon(Icons.add),
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _showInvitePersonSheet(BuildContext context, user) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const InvitePersonSheet(),
    );
    // Recarregar a lista se uma pessoa foi criada
    if (created == true && context.mounted) {
      // O PeopleSection usa RefreshIndicator, então podemos forçar um refresh
      // Mas como não temos acesso direto, vamos apenas fechar e reabrir se necessário
      // Na prática, o usuário pode fazer pull-to-refresh
    }
  }

  void _navigateToSocieties(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SocietiesPage()));
  }

  void _navigateToNotificationSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationSettingsPage()));
  }

  void _navigateToWeeklyAssignments(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WeeklyTeamAssignmentsPage()),
    );
  }

  Future<bool> _canEditElo(BuildContext context, user) async {
    try {
      final societiesRepository = context.read<SocietiesRepository>();
      final eloSociety = await societiesRepository.fetchByName('ELO');
      if (eloSociety == null) return false;
      return user.isAdmin || user.id == eloSociety.userId;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _canAccessEvaluations(BuildContext context, user) async {
    try {
      final societiesRepository = context.read<SocietiesRepository>();

      // Buscar a sociedade ELO
      final eloSociety = await societiesRepository.fetchByName('ELO');
      if (eloSociety == null) {
        return false;
      }

      // Verificar se o usuário é da diretoria ELO (sempre pode acessar)
      if (eloSociety.allBoardIds.contains(user.id)) {
        return true;
      }

      // Verificar se o usuário está vinculado a alguma categoria do Fórum
      final forumUsersByCategory = eloSociety.forumUsersByCategory;
      if (forumUsersByCategory == null || forumUsersByCategory.isEmpty) {
        return false;
      }

      // Verificar se o usuário está em pelo menos uma categoria
      for (final categoryUsers in forumUsersByCategory.values) {
        if (categoryUsers.contains(user.id)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  void _navigateToEvaluations(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EvaluationsListPage()));
  }

  void _navigateToAvailabilityStatus(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EloAvailabilityStatusPage()),
    );
  }

  void _navigateToEloRolesConfig(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EloRolesConfigPage()));
  }

  Future<void> _saveUserName(BuildContext context, AppState appState) async {
    final newName = _nameController.text.trim();

    if (newName.isEmpty) {
      showErrorToast(context, 'O nome não pode estar vazio');
      return;
    }

    try {
      await appState.updateUserName(newName);
      setState(() {
        _isEditingName = false;
      });
      if (context.mounted) {
        showSuccessToast(context, 'Nome atualizado com sucesso');
      }
    } catch (e) {
      if (context.mounted) {
        showErrorToast(context, 'Erro ao atualizar nome: ${e.toString()}');
      }
    }
  }
}
