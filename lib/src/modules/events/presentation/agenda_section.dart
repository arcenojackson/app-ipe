import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user.dart';
import '../../../shared/widgets/glass_container.dart';
import '../data/events_repository.dart';
import '../models/event.dart';
import 'event_viewer_page.dart';

class AgendaSection extends StatefulWidget {
  const AgendaSection({
    super.key,
    required this.user,
    this.onEventsChanged,
  });

  final UserModel user;
  final ValueChanged<bool>? onEventsChanged;

  @override
  State<AgendaSection> createState() => _AgendaSectionState();
}

class _AgendaSectionState extends State<AgendaSection> {
  final _dateFormat = DateFormat('dd/MM/yyyy');
  bool _isLoading = true;
  List<EventModel> _events = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
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
                const SizedBox(height: 120),
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
              children: const [
                SizedBox(height: 120),
                Icon(Icons.event_busy, size: 72, color: Colors.white38),
                SizedBox(height: 16),
                Text(
                  'Nada marcado por aqui.\nQue tal aproveitar para ensaiar algo novo?',
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120),
              itemCount: _events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final event = _events[index];
                return _EventCard(
                  event: event,
                  subtitle:
                      '${event.start}h · ${_dateFormat.format(event.date)}',
                  onTap: () => _openEvent(event),
                );
              },
            ),
    );
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final events = await context.read<EventsRepository>().fetchServicesForUser(
        widget.user.id,
      );
      setState(() {
        _events = events;
      });
      // Notificar o HomeShell sobre o estado dos eventos
      widget.onEventsChanged?.call(events.isNotEmpty);
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
