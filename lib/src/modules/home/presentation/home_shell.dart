import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';

import '../../auth/models/user.dart';
import '../../auth/presentation/settings_page.dart';
import '../../events/presentation/agenda_section.dart';
import '../../events/presentation/planning_section.dart';
import '../../events/presentation/calendar_page.dart';
import '../../musics/presentation/musics_section.dart';
import '../../societies/data/societies_repository.dart';
import '../../../shared/state/app_state.dart';
import '../../../shared/utils/platform_utils.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/highlighted_button_wrapper.dart';

enum HomeSection { agenda, planning, calendar, musics }

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    this.initialSection,
    this.highlightAvailabilityButton = false,
  });

  final HomeSection? initialSection;
  final bool highlightAvailabilityButton;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late List<_HomeDestination> _destinations;
  int _currentIndex = 0;
  bool _planningHasEvents = false;
  bool _agendaHasEvents = false;
  bool _isUpdateAvailable = false;
  bool _isMinistroElo = false;
  late final Upgrader _upgrader;

  @override
  void initState() {
    super.initState();
    _upgrader = Upgrader(debugLogging: true);
    _checkForUpdates();
    _checkMinistroStatus();
  }

  Future<void> _checkMinistroStatus() async {
    final user = context.read<AppState>().currentUser;
    if (user == null) return;
    try {
      final eloSociety = await context
          .read<SocietiesRepository>()
          .fetchByName('ELO');
      if (!mounted) return;
      final isBoard = eloSociety?.allBoardIds.contains(user.id) ?? false;
      setState(() {
        _isMinistroElo = user.isAdminUser || isBoard;
      });
    } catch (_) {
      setState(() {
        _isMinistroElo = user.isAdminUser;
      });
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      await _upgrader.initialize();
      if (mounted && _upgrader.isUpdateAvailable()) {
        setState(() {
          _isUpdateAvailable = true;
        });
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AppState>().currentUser;
    if (user == null) return;
    _destinations = _buildDestinations(user);

    // Configurar índice inicial se especificado
    if (widget.initialSection != null) {
      final sectionIndex = _destinations.indexWhere(
        (dest) => dest.section == widget.initialSection,
      );
      if (sectionIndex != -1) {
        _currentIndex = sectionIndex;
      }
    }

    if (_currentIndex >= _destinations.length) {
      _currentIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AppState, UserModel?>(
      (state) => state.currentUser,
    );
    if (user == null) return const SizedBox.shrink();

    final current = _destinations[_currentIndex];
    final colorScheme = Theme.of(context).colorScheme;
    final bottomNavPadding = PlatformUtils.getBottomNavigationPadding(context);
    final hasButtonNav = PlatformUtils.hasButtonNavigation(context);

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1220), Color(0xFF05070D)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            current.section == HomeSection.planning
                                ? 'Planejar'
                                : current.section == HomeSection.calendar
                                ? 'Calendário'
                                : current.section == HomeSection.musics
                                ? 'Músicas'
                                : 'Olá, ${user.name.split(' ').first}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            current.subtitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Perfil',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        );
                      },
                      icon: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: Text(
                          _getUserInitials(user.name),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xFF0D1220),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isUpdateAvailable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: HighlightedButtonWrapper(
                    highlighted: true,
                    highlightColor: const Color(0xFF2196F3),
                    child: GestureDetector(
                      onTap: () {
                        _upgrader.sendUserToAppStore();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF2196F3), // Azul mais claro
                              Color(0xFF1976D2), // Azul mais escuro
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2196F3).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                              spreadRadius: -5,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.rocket_launch_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nova versão disponível!',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Toque para instalar as novidades',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Colors.white.withOpacity(0.9),
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (current.section != HomeSection.musics &&
                  current.section != HomeSection.calendar &&
                  !(current.section == HomeSection.planning &&
                      _planningHasEvents) &&
                  !(current.section == HomeSection.agenda &&
                      _agendaHasEvents) &&
                  current.section != HomeSection.agenda)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: GlassContainer(
                    padding: EdgeInsets.symmetric(
                      vertical:
                          (current.section == HomeSection.planning ||
                              current.section == HomeSection.agenda)
                          ? 18
                          : 28,
                      horizontal: 24,
                    ),
                    child:
                        (current.section == HomeSection.planning ||
                            current.section == HomeSection.agenda)
                        ? Text(
                            current.description ?? '',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: Colors.white70),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                current.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (current.description != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  current.description!,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              const SizedBox(height: 20),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: Padding(
                    key: ValueKey(current.section),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: current.builder(context),
                  ),
                ),
              ),
              SizedBox(height: hasButtonNav ? bottomNavPadding + 8 : 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        destinations: _destinations,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        colorScheme: colorScheme,
        bottomPadding: bottomNavPadding,
        hasButtonNavigation: hasButtonNav,
      ),
    );
  }

  String _getUserInitials(String name) {
    if (name.isEmpty) return '?';

    final parts = name
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }

    // Retorna primeira letra do primeiro nome e primeira letra do segundo nome
    return '${parts[0][0].toUpperCase()}${parts[1][0].toUpperCase()}';
  }

  List<_HomeDestination> _buildDestinations(UserModel user) {
    final isAdmin = user.isAdminUser;

    final destinations = <_HomeDestination>[
      // Agenda - Todos os usuários têm acesso
      _HomeDestination(
        section: HomeSection.agenda,
        icon: Icons.calendar_month_outlined,
        navLabel: 'Agenda',
        title: 'Sua agenda',
        subtitle: 'Fique atento aos próximos compromissos',
        description:
            'Visualize cultos, ensaios e atividades do seu ministério.',
        builder: (context) => AgendaSection(
          user: user,
          onEventsChanged: (hasEvents) {
            if (mounted) {
              setState(() {
                _agendaHasEvents = hasEvents;
              });
            }
          },
          highlightAvailabilityButton: widget.highlightAvailabilityButton,
        ),
      ),
      // Planejamento - Apenas Admin
      if (isAdmin)
        _HomeDestination(
          section: HomeSection.planning,
          icon: Icons.auto_awesome_motion,
          navLabel: 'Planejar',
          title: 'Planejamento',
          subtitle: 'Monte o roteiro dos próximos cultos',
          description:
              'Monte pautas, organize a equipe e controle cada etapa do culto.',
          builder: (context) => PlanningSection(
            user: user,
            onEventsChanged: (hasEvents) {
              if (mounted) {
                setState(() {
                  _planningHasEvents = hasEvents;
                });
              }
            },
          ),
        ),
      // Calendário - Todos os usuários têm acesso
      _HomeDestination(
        section: HomeSection.calendar,
        icon: Icons.calendar_month,
        navLabel: 'Calendário',
        title: 'Calendário anual',
        subtitle: 'Visualize e gerencie eventos do calendário',
        description: 'Visualizar e gerencie eventos do calendário',
        builder: (context) => const CalendarPage(hideHeader: true),
      ),
      // Músicas - Todos os usuários têm acesso (apenas visualização para não Admin)
      _HomeDestination(
        section: HomeSection.musics,
        icon: Icons.music_note_rounded,
        navLabel: 'Músicas',
        title: 'Biblioteca de músicas',
        subtitle: 'Organize suas músicas',
        description:
            'Gerencie letras, cifras e versões oficiais para cada evento.',
        builder: (context) => MusicsSection(
          canManage: _isMinistroElo,
        ),
      ),
    ];

    return destinations;
  }
}

class _HomeDestination {
  _HomeDestination({
    required this.section,
    required this.icon,
    required this.navLabel,
    required this.title,
    required this.subtitle,
    required this.builder,
    this.description,
  });

  final HomeSection section;
  final IconData icon;
  final String navLabel;
  final String title;
  final String subtitle;
  final String? description;
  final Widget Function(BuildContext) builder;
}

class _CustomBottomNavigationBar extends StatelessWidget {
  const _CustomBottomNavigationBar({
    required this.currentIndex,
    required this.destinations,
    required this.onDestinationSelected,
    required this.colorScheme,
    required this.bottomPadding,
    required this.hasButtonNavigation,
  });

  final int currentIndex;
  final List<_HomeDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final ColorScheme colorScheme;
  final double bottomPadding;
  final bool hasButtonNavigation;

  @override
  Widget build(BuildContext context) {
    // Ajusta a altura e padding baseado no tipo de navegação
    // Para navegação de 3 botões, precisamos de mais espaço na parte inferior
    final baseHeight = 100.0;
    final bottomPaddingValue = hasButtonNavigation
        ? bottomPadding.clamp(0.0, 48.0) // Limita o padding máximo
        : 30.0; // Padding padrão para navegação por gestos

    final totalHeight =
        baseHeight + (hasButtonNavigation ? bottomPaddingValue : 0);

    return Transform.translate(
      offset: const Offset(0, 0),
      child: Container(
        height: totalHeight,
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
        ),
        child: OverflowBox(
          maxHeight: totalHeight,
          child: Padding(
            padding: EdgeInsets.only(
              top: 0,
              bottom: hasButtonNavigation ? bottomPaddingValue : 30,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                destinations.length,
                (index) => _CustomNavItem(
                  destination: destinations[index],
                  isSelected: index == currentIndex,
                  onTap: () => onDestinationSelected(index),
                  colorScheme: colorScheme,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomNavItem extends StatelessWidget {
  const _CustomNavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  final _HomeDestination destination;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment(0, 0),
          clipBehavior: Clip.none,
          children: [
            // Círculo verde que engloba o container
            if (isSelected)
              Positioned(
                top: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            // Container com ícone e texto
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(
                  destination.icon,
                  size: 28,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.6),
                ),
                Text(
                  destination.navLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
