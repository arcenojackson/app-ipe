import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../shared/state/app_state.dart';
import '../../../shared/utils/app_toast.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../auth/models/user.dart';
import '../../societies/data/societies_repository.dart';
import '../data/music_evaluations_repository.dart';
import '../models/evaluation_category.dart';
import '../models/evaluation_form.dart';
import 'evaluation_form_editor_page.dart';
import 'evaluation_form_viewer_page.dart';
import 'evaluation_responses_viewer_page.dart';
import 'widgets/category_description_card.dart';

class EvaluationsListPage extends StatefulWidget {
  const EvaluationsListPage({super.key});

  @override
  State<EvaluationsListPage> createState() => _EvaluationsListPageState();
}

class _EvaluationsListPageState extends State<EvaluationsListPage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  bool _isLoading = true;
  Map<EvaluationCategory, List<EvaluationFormModel>> _formsByCategory = {};
  List<EvaluationCategory> _availableCategories = [];
  UserModel? _currentUser;
  bool _canViewResponses = false;
  Set<String> _respondedFormIds =
      {}; // IDs dos formulários que o usuário já respondeu
  Map<String, int> _responseCountsByFormId =
      {}; // Número de respostas por formulário (apenas para diretoria)

  @override
  void initState() {
    super.initState();
    // Inicializar com um valor padrão
    _tabController = TabController(length: 1, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final appState = context.read<AppState>();
      final user = appState.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      final repository = context.read<MusicEvaluationsRepository>();

      // Verificar se pode visualizar respostas
      final canView = await repository.canViewResponses(user);
      setState(() {
        _canViewResponses = canView;
      });

      // Determinar categorias disponíveis
      final availableCategories = <EvaluationCategory>[];
      try {
        for (final category in EvaluationCategory.values) {
          final canAccess = await repository.canAccessCategory(user, category);
          if (canAccess) {
            availableCategories.add(category);
          }
        }
      } catch (e) {
        // Se houver erro ao verificar permissões, mostrar erro e sair
        if (mounted) {
          showErrorToast(
            context,
            'Erro ao verificar permissões: ${e.toString()}',
          );
          Navigator.of(context).pop();
        }
        setState(() => _isLoading = false);
        return;
      }

      if (availableCategories.isEmpty) {
        if (mounted) {
          showErrorToast(
            context,
            'Você não tem permissão para acessar nenhuma categoria. Verifique se você está vinculado a alguma categoria do Fórum na sociedade ELO.',
          );
          Navigator.of(context).pop();
        }
        setState(() => _isLoading = false);
        return;
      }

      // Atualizar TabController com número de categorias
      _tabController?.dispose();
      _tabController = TabController(
        length: availableCategories.length,
        vsync: this,
      );

      // Carregar formulários por categoria
      final formsByCategory = <EvaluationCategory, List<EvaluationFormModel>>{};
      for (final category in availableCategories) {
        final forms = await repository.fetchFormsByCategory(user.id, category);
        formsByCategory[category] = forms;
      }

      // Verificar quais formulários o usuário já respondeu
      final respondedFormIds = <String>{};
      final responseCountsByFormId = <String, int>{};

      for (final forms in formsByCategory.values) {
        for (final form in forms) {
          try {
            final userResponses = await repository.fetchUserResponsesForForm(
              form.id,
              user.id,
            );
            // Verificar se o usuário respondeu todas as músicas do formulário
            if (form.musics.isNotEmpty && userResponses.isNotEmpty) {
              final musicIds = form.musics.map((m) => m.id).toSet();
              final respondedMusicIds = userResponses
                  .map((r) => r.musicId)
                  .toSet();
              // Se o usuário respondeu todas as músicas, marcar como respondido
              if (musicIds.every((id) => respondedMusicIds.contains(id))) {
                respondedFormIds.add(form.id);
              }
            }

            // Se o usuário pode ver respostas (diretoria), buscar o número total de respostas
            if (_canViewResponses) {
              try {
                final allResponses = await repository.fetchAllResponsesForForm(
                  form.id,
                );
                responseCountsByFormId[form.id] = allResponses.length;
              } catch (e) {
                // Em caso de erro, definir como 0
                responseCountsByFormId[form.id] = 0;
              }
            }
          } catch (e) {
            // Em caso de erro, não marcar como respondido
          }
        }
      }

      setState(() {
        _currentUser = user;
        _availableCategories = availableCategories;
        _formsByCategory = formsByCategory;
        _respondedFormIds = respondedFormIds;
        _responseCountsByFormId = responseCountsByFormId;
        _isLoading = false;
      });
    } catch (e) {
      // Exibir erro no console para facilitar cópia do link do índice
      print('❌ Erro ao carregar formulários:');
      print(e.toString());
      print('');

      if (mounted) {
        showErrorToast(
          context,
          'Erro ao carregar formulários: ${e.toString()}',
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    await _loadData();
  }

  Future<void> _createForm(EvaluationCategory category) async {
    final result = await Navigator.of(context).push<EvaluationFormModel?>(
      MaterialPageRoute(
        builder: (_) =>
            const EvaluationFormEditorPage(), // Novo formulário não precisa de categoria
      ),
    );

    if (result != null) {
      await _refresh();
    }
  }

  Future<void> _viewForm(EvaluationFormModel form) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EvaluationFormViewerPage(formId: form.id),
      ),
    );
    // Recarregar dados quando voltar para atualizar o indicador de resposta
    if (mounted) {
      await _refresh();
    }
  }

  void _viewResponses(EvaluationFormModel form) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EvaluationResponsesViewerPage(formId: form.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Avaliação de Músicas')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_availableCategories.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Avaliação de Músicas')),
        body: const Center(
          child: Text('Você não tem permissão para acessar nenhuma categoria.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avaliação de Músicas'),
        bottom: _availableCategories.length > 1 && _tabController != null
            ? TabBar(
                controller: _tabController!,
                isScrollable: _availableCategories.length > 3,
                tabs: _availableCategories
                    .map((cat) => Tab(text: cat.label))
                    .toList(),
              )
            : null,
      ),
      body: _availableCategories.length > 1 && _tabController != null
          ? TabBarView(
              controller: _tabController!,
              children: _availableCategories
                  .map((category) => _buildCategoryTab(category))
                  .toList(),
            )
          : _availableCategories.isNotEmpty
          ? _buildCategoryTab(_availableCategories.first)
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton:
          _currentUser != null && _tabController != null && _canViewResponses
          ? FloatingActionButton(
              onPressed: () {
                if (_tabController == null || _availableCategories.isEmpty)
                  return;
                final category = _availableCategories.length > 1
                    ? _availableCategories[_tabController!.index]
                    : _availableCategories.first;
                _createForm(category);
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildCategoryTab(EvaluationCategory category) {
    final forms = _formsByCategory[category] ?? [];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Card com texto descritivo da categoria
          CategoryDescriptionCard(category: category),
          const SizedBox(height: 24),

          // Lista de formulários
          if (forms.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 64,
                      color: Colors.white38,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum formulário encontrado',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                    ),
                    if (_canViewResponses) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Toque no botão + para criar um novo formulário',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            ...forms.map((form) => _buildFormCard(form, category)),
        ],
      ),
    );
  }

  Future<bool> _canDeleteForm(EvaluationFormModel form) async {
    if (_currentUser == null) return false;

    // Apenas membros da diretoria ELO podem excluir
    try {
      final societiesRepository = context.read<SocietiesRepository>();
      final eloSociety = await societiesRepository.fetchByName('ELO');
      if (eloSociety != null) {
        return eloSociety.allBoardIds.contains(_currentUser!.id);
      }
    } catch (e) {
      // Em caso de erro, não permitir exclusão
    }

    return false;
  }

  Future<void> _deleteForm(EvaluationFormModel form) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir formulário'),
        content: Text(
          'Tem certeza que deseja excluir o formulário "${form.title}"? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repository = context.read<MusicEvaluationsRepository>();
      await repository.deleteForm(form.id);
      if (mounted) {
        showSuccessToast(context, 'Formulário excluído com sucesso!');
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao excluir formulário: ${e.toString()}');
      }
    }
  }

  Future<bool> _isUserLinkedToCategory(EvaluationCategory category) async {
    if (_currentUser == null) return false;

    // Verificar se o usuário está vinculado à categoria específica no Fórum
    // (não apenas se é da diretoria)
    try {
      final societiesRepository = context.read<SocietiesRepository>();
      final eloSociety = await societiesRepository.fetchByName('ELO');
      if (eloSociety == null) return false;

      final categoryUsers =
          eloSociety.forumUsersByCategory?[category.name] ?? [];
      return categoryUsers.contains(_currentUser!.id);
    } catch (e) {
      return false;
    }
  }

  Widget _buildFormCard(EvaluationFormModel form, EvaluationCategory category) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
    final hasResponded = _respondedFormIds.contains(form.id);
    final responseCount = _responseCountsByFormId[form.id] ?? 0;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      form.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (form.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        form.description!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Tag de status (Ativo/Fechado) - acima
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(form.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getStatusColor(form.status),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      form.status.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _getStatusColor(form.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Tag Respondido - abaixo
                  if (hasResponded) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Respondido',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.white60),
              const SizedBox(width: 4),
              Text(
                dateFormat.format(form.createdAt),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_canViewResponses)
                TextButton.icon(
                  icon: const Icon(Icons.analytics),
                  label: Text(
                    'Ver respostas${responseCount > 0 ? ' ($responseCount)' : ''}',
                  ),
                  onPressed: () => _viewResponses(form),
                ),
              if (_canViewResponses) const SizedBox(width: 8),
              FutureBuilder<bool>(
                future: _isUserLinkedToCategory(category),
                builder: (context, snapshot) {
                  // Só mostrar o botão se o usuário estiver vinculado à categoria E o formulário não estiver fechado
                  if (snapshot.data == true &&
                      form.status != EvaluationFormStatus.closed) {
                    return TextButton.icon(
                      icon: const Icon(Icons.visibility),
                      label: const Text('Abrir'),
                      onPressed: () => _viewForm(form),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(width: 8),
              FutureBuilder<bool>(
                future: _canDeleteForm(form),
                builder: (context, snapshot) {
                  if (snapshot.data == true) {
                    return IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteForm(form),
                      tooltip: 'Excluir formulário',
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(EvaluationFormStatus status) {
    switch (status) {
      case EvaluationFormStatus.draft:
        return Colors.orange;
      case EvaluationFormStatus.active:
        return Colors.green;
      case EvaluationFormStatus.closed:
        return Colors.grey;
    }
  }
}
