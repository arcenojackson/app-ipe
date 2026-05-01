import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user.dart';
import '../../societies/data/societies_repository.dart';
import '../../societies/models/society.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/highlighted_button_wrapper.dart';
import '../data/events_repository.dart';
import '../models/event.dart';
import 'event_viewer_page.dart';
import 'worship_team_availability_modal.dart';

class AgendaSection extends StatefulWidget {
  const AgendaSection({
    super.key,
    required this.user,
    this.onEventsChanged,
    this.highlightAvailabilityButton = false,
  });

  final UserModel user;
  final ValueChanged<bool>? onEventsChanged;
  final bool highlightAvailabilityButton;

  @override
  State<AgendaSection> createState() => _AgendaSectionState();
}

class _AgendaSectionState extends State<AgendaSection> {
  final _dateFormat = DateFormat('dd/MM/yyyy');
  bool _isLoading = true;
  List<EventModel> _events = const [];
  String? _error;
  bool _isELOMember = false;
  bool _shouldHighlightAvailability = false;

  @override
  void initState() {
    super.initState();
    _shouldHighlightAvailability = widget.highlightAvailabilityButton;
    _loadEvents();
    _checkELOMembership();
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowAvailabilityButton = _shouldShowAvailabilityButton();

    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: Theme.of(context).colorScheme.primary,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                if (shouldShowAvailabilityButton) ...[
                  const SizedBox(height: 20),
                  _AvailabilityButton(
                    onTap: () => _openAvailabilityModal(context),
                    highlighted: _shouldHighlightAvailability,
                  ),
                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 20),
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            )
          : _events.isEmpty
          ? ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                if (shouldShowAvailabilityButton) ...[
                  const SizedBox(height: 20),
                  _AvailabilityButton(
                    onTap: () => _openAvailabilityModal(context),
                    highlighted: _shouldHighlightAvailability,
                  ),
                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 20),
                const Icon(Icons.event_busy, size: 72, color: Colors.white38),
                const SizedBox(height: 16),
                const Text(
                  'Nada marcado por aqui.\nQue tal aproveitar para ensaiar algo novo?',
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                if (shouldShowAvailabilityButton) ...[
                  const SizedBox(height: 20),
                  _AvailabilityButton(
                    onTap: () => _openAvailabilityModal(context),
                    highlighted: _shouldHighlightAvailability,
                  ),
                  const SizedBox(height: 20),
                ],
                ...List.generate(_events.length, (index) {
                  final event = _events[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < _events.length - 1 ? 16 : 0,
                    ),
                    child: _EventCard(
                      event: event,
                      subtitle:
                          '${event.start}h · ${_dateFormat.format(event.date)}',
                      onTap: () => _openEvent(event),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  /// Verifica se o usuário é membro da sociedade ELO
  Future<void> _checkELOMembership() async {
    try {
      final societiesRepository = context.read<SocietiesRepository>();
      final eloSociety = await societiesRepository.fetchByName('ELO');

      if (eloSociety != null) {
        final isMember =
            eloSociety.membersIds.contains(widget.user.id) ||
            eloSociety.boardIds.contains(widget.user.id);
        if (mounted) {
          setState(() {
            _isELOMember = isMember;
          });
        }
      }
    } catch (e) {
      // Em caso de erro, não exibir o botão
      if (mounted) {
        setState(() {
          _isELOMember = false;
        });
      }
    }
  }

  /// Verifica se a data atual está entre os dias 05 e 28 do mês
  /// E se o usuário é membro da sociedade ELO
  bool _shouldShowAvailabilityButton() {
    if (!_isELOMember) return false;

    final now = DateTime.now();
    return now.day >= 1;
  }

  Future<void> _openAvailabilityModal(BuildContext context) async {
    // Remover destaque após abrir o modal
    if (_shouldHighlightAvailability) {
      setState(() {
        _shouldHighlightAvailability = false;
      });
    }

    SocietyModel? eloSociety;
    try {
      final societiesRepository = context.read<SocietiesRepository>();
      eloSociety = await societiesRepository.fetchByName('ELO');
    } catch (_) {
      // Ignorar erro - modal funciona sem contador
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WorshipTeamAvailabilityModal(
        userId: widget.user.id,
        eloSociety: eloSociety,
      ),
    );
  }

  /// Verifica se a data é igual ou maior que hoje
  bool _isDateTodayOrAfter(DateTime date) {
    final now = DateTime.now();
    final eventDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    return !eventDate.isBefore(today);
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final allEvents = await context
          .read<EventsRepository>()
          .fetchServicesForUser(widget.user.id);
      // Filtrar apenas eventos futuros ou de hoje (data >= hoje)
      final futureEvents = allEvents
          .where((event) => _isDateTodayOrAfter(event.date))
          .toList();
      // Ordenar por data crescente (mais próximo primeiro)
      futureEvents.sort((a, b) => a.date.compareTo(b.date));

      setState(() {
        _events = futureEvents;
      });
      // Notificar o HomeShell sobre o estado dos eventos
      widget.onEventsChanged?.call(futureEvents.isNotEmpty);

      // Atualizar verificação de membresia ELO ao recarregar
      await _checkELOMembership();
    } catch (error) {
      setState(() => _error = 'Erro ao carregar seus serviços.');
      widget.onEventsChanged?.call(false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openEvent(EventModel event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventViewerPage(eventId: event.id)),
    );
    await _loadEvents();
    // Notificar após carregar
    widget.onEventsChanged?.call(_events.isNotEmpty);
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.subtitle,
    required this.onTap,
  });

  final EventModel event;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 22),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityButton extends StatefulWidget {
  const _AvailabilityButton({required this.onTap, this.highlighted = false});

  final VoidCallback onTap;
  final bool highlighted;

  @override
  State<_AvailabilityButton> createState() => _AvailabilityButtonState();
}

class _AvailabilityButtonState extends State<_AvailabilityButton> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final button = GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.3),
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
                Icons.music_note,
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
                    'Informar disponibilidade',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Defina sua disponibilidade para o próximo mês',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
    );

    return HighlightedButtonWrapper(
      highlighted: widget.highlighted,
      highlightColor: colorScheme.primary,
      child: button,
    );
  }
}
