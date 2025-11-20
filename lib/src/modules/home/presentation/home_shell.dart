import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user.dart';
import '../../auth/presentation/settings_page.dart';
import '../../events/presentation/agenda_section.dart';
import '../../events/presentation/planning_section.dart';
import '../../musics/presentation/musics_section.dart';
import '../../people/presentation/people_section.dart';
import '../../../shared/state/app_state.dart';
import '../../../shared/widgets/glass_container.dart';

enum HomeSection { agenda, planning, people, musics }

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late List<_HomeDestination> _destinations;
  int _currentIndex = 0;
  bool _planningHasEvents = false;
  bool _agendaHasEvents = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AppState>().currentUser;
    if (user == null) return;
    _destinations = _buildDestinations(user);
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
                                : current.section == HomeSection.people
                                ? 'Pessoas'
                                : current.section == HomeSection.musics
                                ? 'Repertório'
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
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF0D1220),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (current.section != HomeSection.musics &&
                  current.section != HomeSection.people &&
                  !(current.section == HomeSection.planning &&
                      _planningHasEvents) &&
                  !(current.section == HomeSection.agenda && _agendaHasEvents))
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        destinations: _destinations,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        colorScheme: colorScheme,
      ),
    );
  }

  String _getUserInitials(String name) {
    if (name.isEmpty) return '?';
    
    final parts = name.trim().split(' ').where((part) => part.isNotEmpty).toList();
    
    if (parts.isEmpty) return '?';
    
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    
    // Retorna primeira letra do primeiro nome e primeira letra do segundo nome
    return '${parts[0][0].toUpperCase()}${parts[1][0].toUpperCase()}';
  }

  List<_HomeDestination> _buildDestinations(UserModel user) {
    final isAdmin = user.isAdminUser;
    final isStandard = user.isStandardUser;
    
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
      // Pessoas - Todos os usuários têm acesso
      _HomeDestination(
        section: HomeSection.people,
        icon: Icons.person_rounded,
        navLabel: 'Pessoas',
        title: 'Equipe e membros',
        subtitle: 'Gerencie perfis e equipes',
        description:
            'Veja quem participa das equipes, promova líderes e acompanhe o ministério.',
        builder: (context) => PeopleSection(currentUser: user),
      ),
      // Repertório - Admin e Padrão têm acesso (apenas visualização para Padrão)
      if (isAdmin || isStandard)
        _HomeDestination(
          section: HomeSection.musics,
          icon: Icons.music_note_rounded,
          navLabel: 'Repertório',
          title: 'Biblioteca de músicas',
          subtitle: 'Organize suas músicas',
          description:
              'Gerencie letras, cifras e versões oficiais para cada evento.',
          builder: (context) => MusicsSection(isAdmin: user.isAdmin),
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
  });

  final int currentIndex;
  final List<_HomeDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 0),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
        ),
        child: OverflowBox(
          maxHeight: 100,
          child: Padding(
            padding: const EdgeInsets.only(top: 0, bottom: 30),
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
