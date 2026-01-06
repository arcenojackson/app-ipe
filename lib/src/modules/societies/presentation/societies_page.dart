import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/glass_container.dart';
import '../../../shared/utils/app_toast.dart';
import '../../../shared/state/app_state.dart';
import '../data/societies_repository.dart';
import '../models/society.dart';
import 'society_details_page.dart';
import 'widgets/society_form_sheet.dart';

class SocietiesPage extends StatefulWidget {
  const SocietiesPage({super.key});

  @override
  State<SocietiesPage> createState() => _SocietiesPageState();
}

class _SocietiesPageState extends State<SocietiesPage> {
  bool _isLoading = true;
  List<SocietyModel> _societies = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSocieties();
  }

  Future<void> _loadSocieties() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final societies = await context.read<SocietiesRepository>().fetchAll();
      setState(() {
        _societies = societies;
      });
    } catch (error) {
      setState(() {
        _error = 'Erro ao carregar as sociedades.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                      'Sociedades internas',
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
                child: RefreshIndicator(
                  onRefresh: _loadSocieties,
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
                          : _societies.isEmpty
                              ? ListView(
                                  physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  padding: const EdgeInsets.only(bottom: 160),
                                  children: const [
                                    SizedBox(height: 120),
                                    Icon(
                                      Icons.groups_outlined,
                                      size: 68,
                                      color: Colors.white38,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Nenhuma sociedade cadastrada.\nToque no botão + para criar uma nova.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                  itemCount: _societies.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final society = _societies[index];
                                    final isCreator = user?.id == society.userId;
                                    final isAdmin = user?.isAdmin ?? false;
                                    final canEdit = isCreator || isAdmin;

                                    return _SocietyCard(
                                      society: society,
                                      onOpen: () => _openSociety(society),
                                      onEdit: canEdit
                                          ? () => _onEditSociety(society)
                                          : null,
                                      onDelete: canEdit
                                          ? () => _onDeleteSociety(society)
                                          : null,
                                    );
                                  },
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: (user?.isAdmin ?? false)
          ? FloatingActionButton(
              onPressed: _onCreateSociety,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _onCreateSociety() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SocietyFormSheet(),
    );
    if (created == true) {
      await _loadSocieties();
    }
  }

  Future<void> _onEditSociety(SocietyModel society) async {
    final repository = context.read<SocietiesRepository>();
    final fullSociety = await repository.fetchById(society.id);
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SocietyFormSheet(society: fullSociety),
    );
    if (updated == true) {
      await _loadSocieties();
    }
  }

  Future<void> _onDeleteSociety(SocietyModel society) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir sociedade'),
        content: Text(
          'Deseja realmente excluir "${society.name}"? Esta ação não poderá ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await context.read<SocietiesRepository>().deleteSociety(society.id);
      if (mounted) {
        showSuccessToast(context, 'Sociedade "${society.name}" excluída.');
        await _loadSocieties();
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao excluir sociedade.');
      }
    }
  }

  Future<void> _openSociety(SocietyModel society) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SocietyDetailsPage(societyId: society.id),
      ),
    );
    await _loadSocieties();
  }
}

class _SocietyCard extends StatelessWidget {
  const _SocietyCard({
    required this.society,
    required this.onOpen,
    this.onEdit,
    this.onDelete,
  });

  final SocietyModel society;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onOpen,
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: Color(society.color).withOpacity(0.2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.groups,
                color: Color(society.color),
                size: 24,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    society.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    society.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                  color: onEdit == null ? Colors.white38 : null,
                ),
                IconButton(
                  tooltip: 'Excluir',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onDelete,
                  color: onDelete == null ? Colors.white38 : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

