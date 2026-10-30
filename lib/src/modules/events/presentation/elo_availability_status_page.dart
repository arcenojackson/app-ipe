import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/utils/sort_utils.dart';
import '../../../shared/utils/app_toast.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/config/firebase_config.dart';
import '../../auth/models/user.dart';
import '../../people/data/people_repository.dart';
import '../../societies/data/societies_repository.dart';
import '../data/events_repository.dart';

class EloAvailabilityStatusPage extends StatefulWidget {
  const EloAvailabilityStatusPage({super.key});

  @override
  State<EloAvailabilityStatusPage> createState() =>
      _EloAvailabilityStatusPageState();
}

class _EloAvailabilityStatusPageState
    extends State<EloAvailabilityStatusPage> {
  bool _isLoading = true;
  bool _isSendingNotifications = false;
  List<_MemberAvailabilityStatus> _members = [];
  String? _error;
  DateTime? _nextMonth;

  @override
  void initState() {
    super.initState();
    _loadMembersAvailability();
  }

  Future<void> _loadMembersAvailability() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Calcular o mês seguinte
      final now = DateTime.now();
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      setState(() {
        _nextMonth = nextMonth;
      });

      // Buscar sociedade ELO
      final societiesRepository = context.read<SocietiesRepository>();
      final eloSociety = await societiesRepository.fetchByName('ELO');

      if (eloSociety == null) {
        setState(() {
          _error = 'Sociedade ELO não encontrada';
          _isLoading = false;
        });
        return;
      }

      // Buscar todos os membros da ELO
      final peopleRepository = context.read<PeopleRepository>();
      final allUsers = await peopleRepository.fetchAll();
      
      // Filtrar apenas membros da ELO (membersIds)
      final eloMembers = allUsers
          .where((user) => eloSociety.membersIds.contains(user.id))
          .toList();

      // Buscar disponibilidades de cada membro
      final eventsRepository = context.read<EventsRepository>();
      final membersWithStatus = <_MemberAvailabilityStatus>[];

      for (final member in eloMembers) {
        try {
          // Buscar disponibilidades do membro
          final availability = await eventsRepository
              .fetchWorshipTeamAvailability(member.id);

          // Verificar se tem disponibilidade para o mês seguinte
          // Se tem pelo menos um dia selecionado no mês seguinte, consideramos como respondida
          final hasResponded = availability.isNotEmpty;

          membersWithStatus.add(
            _MemberAvailabilityStatus(
              member: member,
              hasResponded: hasResponded,
              availableDates: availability,
            ),
          );
        } catch (e) {
          // Se houver erro ao buscar disponibilidade, considerar como não respondida
          membersWithStatus.add(
            _MemberAvailabilityStatus(
              member: member,
              hasResponded: false,
              availableDates: [],
            ),
          );
        }
      }

      // Ordenar alfabeticamente por nome (ignorando acentos e case)
      membersWithStatus.sort((a, b) {
        return compareNamesIgnoreAccents(a.member.name, b.member.name);
      });

      setState(() {
        _members = membersWithStatus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar disponibilidades: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String _getMonthName(DateTime date) {
    return DateFormat('MMMM/yyyy', 'pt_BR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthName = _nextMonth != null ? _getMonthName(_nextMonth!) : '';

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status de Disponibilidades',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (monthName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Mês de referência: $monthName',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white60,
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
              // Botão para enviar notificações
              if (!_isLoading && _error == null && _members.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildSendNotificationsButton(context, theme),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: Colors.red.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _error!,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: Colors.white70,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: _loadMembersAvailability,
                                    child: const Text('Tentar novamente'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _members.isEmpty
                            ? Center(
                                child: Text(
                                  'Nenhum membro da ELO encontrado',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                itemCount: _members.length,
                                itemBuilder: (context, index) {
                                  final memberStatus = _members[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: GlassContainer(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          // Avatar
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: theme
                                                .colorScheme.primary
                                                .withOpacity(0.15),
                                            child: Text(
                                              _getInitials(memberStatus.member.name),
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          // Nome e status
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  memberStatus.member.name,
                                                  style: theme.textTheme
                                                      .titleMedium?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      memberStatus.hasResponded
                                                          ? Icons.check_circle
                                                          : Icons
                                                              .cancel_outlined,
                                                      size: 16,
                                                      color:
                                                          memberStatus.hasResponded
                                                              ? Colors.green
                                                              : Colors.orange,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      memberStatus.hasResponded
                                                          ? 'Disponibilidade respondida'
                                                          : 'Disponibilidade não respondida',
                                                      style: theme.textTheme
                                                          .bodySmall?.copyWith(
                                                        color:
                                                            memberStatus.hasResponded
                                                                ? Colors.green
                                                                : Colors.orange,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (memberStatus.hasResponded &&
                                                    memberStatus
                                                        .availableDates.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${memberStatus.availableDates.length} dia(s) disponível(is)',
                                                    style: theme.textTheme
                                                        .bodySmall?.copyWith(
                                                      color: Colors.white60,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildSendNotificationsButton(BuildContext context, ThemeData theme) {
    final membersNotResponded = _members
        .where((m) => !m.hasResponded)
        .map((m) => m.member.id)
        .toList();

    if (membersNotResponded.isEmpty) {
      return const SizedBox.shrink();
    }

    return GlassContainer(
      padding: EdgeInsets.zero,
      child: ElevatedButton.icon(
        onPressed: _isSendingNotifications
            ? null
            : () => _sendNotificationsToNonResponded(context, membersNotResponded),
        icon: _isSendingNotifications
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.notifications_active),
        label: Text(
          _isSendingNotifications
              ? 'Enviando notificações...'
              : 'Enviar lembrete (${membersNotResponded.length} membro${membersNotResponded.length > 1 ? 's' : ''})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Future<void> _sendNotificationsToNonResponded(
    BuildContext context,
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) {
      showErrorToast(context, 'Nenhum membro sem resposta encontrado');
      return;
    }

    // Confirmar ação
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          'Enviar Lembretes',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'Deseja enviar notificações push para ${userIds.length} membro${userIds.length > 1 ? 's' : ''} que ainda não informaram suas disponibilidades?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSendingNotifications = true;
    });

    try {
      // Obter token de autenticação do Firebase
      final user = FirebaseConfig.auth.currentUser;
      if (user == null) {
        if (mounted) {
          showErrorToast(context, 'Usuário não autenticado');
        }
        return;
      }

      final idToken = await user.getIdToken();

      // Calcular o nome do mês seguinte
      final now = DateTime.now();
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final monthName = DateFormat('MMMM', 'pt_BR').format(nextMonth);

      // URL da Cloud Function HTTP
      // Formato: https://{region}-{project-id}.cloudfunctions.net/{function-name}
      final functionUrl = AppEnvironment.cloudFunctionUrl(
        'sendEloAvailabilityReminder',
      );

      // Fazer requisição HTTP POST para a Cloud Function
      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'userIds': userIds,
          'monthName': monthName,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        final sent = responseData['sent'] as int? ?? userIds.length;
        final failed = responseData['failed'] as int? ?? 0;

        if (mounted) {
          if (failed == 0) {
            showSuccessToast(
              context,
              'Notificações enviadas com sucesso para $sent membro${sent > 1 ? 's' : ''}!',
            );
          } else {
            showSuccessToast(
              context,
              'Notificações enviadas: $sent sucesso, $failed falha${failed > 1 ? 's' : ''}',
            );
          }
        }
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMessage =
            errorData['error']?.toString() ?? 'Erro ao enviar notificações';
        if (mounted) {
          showErrorToast(context, errorMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(
          context,
          'Erro ao enviar notificações: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingNotifications = false;
        });
      }
    }
  }
}

class _MemberAvailabilityStatus {
  final UserModel member;
  final bool hasResponded;
  final List<DateTime> availableDates;

  _MemberAvailabilityStatus({
    required this.member,
    required this.hasResponded,
    required this.availableDates,
  });
}
