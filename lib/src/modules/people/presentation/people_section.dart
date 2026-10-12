import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/utils/app_toast.dart';
import '../../../shared/utils/sort_utils.dart';
import '../../../shared/state/app_state.dart';
import '../data/people_repository.dart';
import '../models/teaching_role_menu_option.dart';
import 'widgets/invite_person_sheet.dart';

class PeopleSection extends StatefulWidget {
  const PeopleSection({
    super.key,
    required this.currentUser,
    this.hideFloatingButton = false,
  });

  final UserModel currentUser;
  final bool hideFloatingButton;

  @override
  State<PeopleSection> createState() => _PeopleSectionState();
}

class _PeopleSectionState extends State<PeopleSection> {
  bool _isLoading = true;
  List<UserModel> _people = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Widget? _buildStatusLabel(UserModel person, ThemeData theme) {
    // Label "Demonstrativo" apenas para demo@mail.com
    if (person.email.toLowerCase() == 'demo@mail.com') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('Demonstrativo'),
      );
    }

    // Label "Admin" para todos os administradores
    if (person.isAdmin) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('Admin'),
      );
    }

    return null;
  }

  Widget? _buildTeachingRoleLabel(UserModel person, ThemeData theme) {
    final text = switch (person.teachingRole) {
      TeachingRole.teacher => 'Professor',
      TeachingRole.curator => 'Curador',
      TeachingRole.none => null,
    };
    if (text == null) return null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLimitedUser =
        widget.currentUser.isPending && !widget.currentUser.isAdmin;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadPeople,
          color: theme.colorScheme.primary,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : isLimitedUser
              ? ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 160),
                  children: [
                    const SizedBox(height: 120),
                    Icon(
                      Icons.info_outline,
                      size: 64,
                      color: theme.colorScheme.primary.withOpacity(0.8),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Você possui um acesso limitado ao app por enquanto, aguarde até que algum usuário administrador lhe dê as permissões necessárias.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                )
              : _error != null
              ? ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 160),
                  children: [
                    const SizedBox(height: 120),
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 160),
                  itemCount: _people.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final person = _people[index];
                    final statusLabel = _buildStatusLabel(person, theme);
                    final teachingLabel = _buildTeachingRoleLabel(person, theme);
                    final showMenu =
                        widget.currentUser.isAdmin &&
                        person.id != widget.currentUser.id &&
                        person.email.toLowerCase() != 'demo@mail.com';

                    return GlassContainer(
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 20,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: theme.colorScheme.primary
                                .withOpacity(0.15),
                            child: Text(
                              person.name.isNotEmpty
                                  ? person.name[0].toUpperCase()
                                  : '?',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  person.email,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Mostrar labels de status (sempre que existir)
                          if (teachingLabel != null) ...[
                            teachingLabel,
                            const SizedBox(width: 8),
                          ],
                          if (statusLabel != null) ...[
                            statusLabel,
                            const SizedBox(width: 8),
                          ],
                          // Mostrar menu apenas se for admin e não for o próprio usuário
                          if (showMenu)
                            PopupMenuButton<String>(
                              color: theme.colorScheme.surface,
                              position: PopupMenuPosition.over,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              itemBuilder: (_) {
                                final items = <PopupMenuEntry<String>>[];

                                // Se o usuário está pendente, mostrar opção de aprovar
                                if (person.isPending) {
                                  items.add(
                                    PopupMenuItem(
                                      value: 'approve',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            color: Colors.green.shade400,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Aprovar usuário',
                                            style: TextStyle(
                                              color: Colors.green.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else if (person.isAdmin) {
                                  // Se for admin, mostrar opção de remover admin
                                  items.add(
                                    PopupMenuItem(
                                      value: 'remove',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.admin_panel_settings_outlined,
                                            color: Colors.orange.shade400,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Remover administrador',
                                            style: TextStyle(
                                              color: Colors.orange.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else {
                                  // Se não for admin e não estiver pendente, mostrar opção de tornar admin
                                  items.add(
                                    PopupMenuItem(
                                      value: 'add',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.admin_panel_settings_outlined,
                                            color: theme.colorScheme.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Tornar administrador',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                // Papel de ensino (apenas para usuários aprovados)
                                if (!person.isPending) {
                                  for (final option in teachingRoleMenuOptions(
                                    person.teachingRole,
                                  )) {
                                    final isRemove =
                                        option.target == TeachingRole.none;
                                    final color = isRemove
                                        ? Colors.orange.shade400
                                        : null;
                                    items.add(
                                      PopupMenuItem(
                                        value: option.value,
                                        child: Row(
                                          children: [
                                            Icon(
                                              isRemove
                                                  ? Icons.person_remove_outlined
                                                  : Icons.school_outlined,
                                              color:
                                                  color ??
                                                  theme.colorScheme.primary,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              option.label,
                                              style: TextStyle(
                                                color: color ?? Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                }

                                // Divisor antes de excluir
                                items.add(const PopupMenuDivider());

                                // Opção de excluir
                                items.add(
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          color: Colors.red.shade300,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Excluir usuário',
                                          style: TextStyle(
                                            color: Colors.red.shade300,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );

                                return items;
                              },
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _showDeleteConfirmation(person);
                                } else if (value == 'approve') {
                                  _approveUser(person);
                                } else if (value == 'add' || value == 'remove') {
                                  _toggleAdmin(person, value == 'add');
                                } else {
                                  final role =
                                      TeachingRoleMenuOption.targetFromMenuValue(
                                        value,
                                      );
                                  if (role != null) {
                                    _setTeachingRole(person, role);
                                  }
                                }
                              },
                              child: const Icon(Icons.more_horiz_rounded),
                            )
                          // Espaço para alinhar a label quando não há menu
                          else if (statusLabel != null || teachingLabel != null)
                            const SizedBox(width: 25),
                        ],
                      ),
                    );
                  },
                ),
        ),
        // Botão de convidar apenas para Admin (quando não está escondido)
        if (widget.currentUser.isAdminUser && !widget.hideFloatingButton)
          Positioned(
            bottom: 130,
            right: 0,
            child: FloatingActionButton(
              onPressed: _onCreatePerson,
              child: const Icon(Icons.add),
            ),
          ),
      ],
    );
  }

  Future<void> _loadPeople() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final people = await context.read<PeopleRepository>().fetchAll(
        currentUser: widget.currentUser,
      );
      // Ordenar lista em ordem alfabética por nome (ignorando acentos)
      people.sort(
        (a, b) => compareNamesIgnoreAccents(a.name, b.name),
      );
      setState(() => _people = people);
    } catch (error) {
      setState(() => _error = 'Erro ao carregar os usuários.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleAdmin(UserModel user, bool isAdmin) async {
    try {
      await context.read<PeopleRepository>().toggleAdmin(
        userId: user.id,
        isAdmin: isAdmin,
      );
      if (mounted) {
        showSuccessToast(
          context,
          isAdmin
              ? '${user.name} agora é administrador.'
              : '${user.name} não é mais administrador.',
        );
        await _loadPeople();
      }
    } catch (error) {
      if (mounted) {
        final errorMessage = error.toString().contains('permission')
            ? 'Sem permissão para atualizar usuário. Verifique as regras do Firestore.'
            : 'Erro ao atualizar o usuário: ${error.toString()}';
        showErrorToast(context, errorMessage);
      }
    }
  }

  Future<void> _setTeachingRole(UserModel user, TeachingRole role) async {
    try {
      await context.read<PeopleRepository>().setTeachingRole(
        userId: user.id,
        role: role,
      );
      if (mounted) {
        showSuccessToast(
          context,
          switch (role) {
            TeachingRole.teacher => '${user.name} agora é professor.',
            TeachingRole.curator => '${user.name} agora é curador.',
            TeachingRole.none =>
              '${user.name} não faz mais parte dos professores.',
          },
        );
        await _loadPeople();
      }
    } catch (error) {
      if (mounted) {
        final errorMessage = error.toString().contains('permission')
            ? 'Sem permissão para atualizar usuário. Verifique as regras do Firestore.'
            : 'Erro ao atualizar o papel de ensino: ${error.toString()}';
        showErrorToast(context, errorMessage);
      }
    }
  }

  Future<void> _approveUser(UserModel user) async {
    try {
      await context.read<PeopleRepository>().approveUser(userId: user.id);
      if (mounted) {
        showSuccessToast(context, '${user.name} foi aprovado com sucesso.');
        await _loadPeople();
      }
    } catch (error) {
      if (mounted) {
        final errorMessage = error.toString().contains('permission')
            ? 'Sem permissão para aprovar usuário. Verifique as regras do Firestore.'
            : 'Erro ao aprovar o usuário: ${error.toString()}';
        showErrorToast(context, errorMessage);
      }
    }
  }

  Future<void> _onCreatePerson() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const InvitePersonSheet(),
    );
  }

  Future<void> _showDeleteConfirmation(UserModel user) async {
    final theme = Theme.of(context);
    final isSelf = user.id == widget.currentUser.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          isSelf ? 'Excluir sua conta?' : 'Excluir usuário?',
          style: theme.textTheme.titleLarge,
        ),
        content: Text(
          isSelf
              ? 'Tem certeza que deseja excluir sua conta? Esta ação não pode ser desfeita e você será desconectado do app.'
              : 'Tem certeza que deseja excluir o usuário "${user.name}"? Esta ação não pode ser desfeita.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade300),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteUser(user);
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    try {
      await context.read<PeopleRepository>().deleteUser(userId: user.id);

      if (mounted) {
        final isSelf = user.id == widget.currentUser.id;

        showSuccessToast(
          context,
          isSelf
              ? 'Sua conta foi excluída com sucesso.'
              : 'Usuário excluído com sucesso.',
        );

        // Se o usuário excluiu a si mesmo, fazer logout
        if (isSelf) {
          await context.read<AppState>().signOut();
        } else {
          // Recarregar a lista de usuários
          await _loadPeople();
        }
      }
    } catch (error) {
      if (mounted) {
        final errorMessage = error.toString().contains('permission')
            ? 'Sem permissão para excluir usuário. Verifique as regras do Firestore.'
            : 'Erro ao excluir o usuário: ${error.toString()}';
        showErrorToast(context, errorMessage);
      }
    }
  }
}
