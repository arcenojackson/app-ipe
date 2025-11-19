import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/utils/app_toast.dart';
import '../data/people_repository.dart';
import 'widgets/invite_person_sheet.dart';

class PeopleSection extends StatefulWidget {
  const PeopleSection({super.key, required this.currentUser});

  final UserModel currentUser;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadPeople,
          color: theme.colorScheme.primary,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 160),
                  children: [
                    const SizedBox(height: 120),
                    Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
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
                    return GlassContainer(
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 20,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: theme.colorScheme.primary.withOpacity(
                              0.15,
                            ),
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
                          if (widget.currentUser.isAdmin)
                            PopupMenuButton<String>(
                              color: theme.colorScheme.surface,
                              position: PopupMenuPosition.over,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: person.isAdmin ? 'remove' : 'add',
                                  child: Text(
                                    person.isAdmin
                                        ? 'Remover administrador'
                                        : 'Tornar administrador',
                                  ),
                                ),
                              ],
                              onSelected: (value) =>
                                  _toggleAdmin(person, value == 'add'),
                              child: const Icon(Icons.more_horiz_rounded),
                            )
                          else if (person.isAdmin)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text('Admin'),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
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
      final people = await context.read<PeopleRepository>().fetchAll();
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

  Future<void> _onCreatePerson() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const InvitePersonSheet(),
    );
  }
}
