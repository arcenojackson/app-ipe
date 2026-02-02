import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user.dart';
import '../../people/data/people_repository.dart';
import '../../people/presentation/widgets/people_selector_sheet.dart';
import '../../../shared/utils/app_toast.dart';
import '../../../shared/utils/sort_utils.dart';
import '../../../shared/state/app_state.dart';
import '../data/societies_repository.dart';
import '../data/society_chat_repository.dart';
import '../models/society.dart';
import 'society_chat_page.dart';

class _CustomFABLocation extends FloatingActionButtonLocation {
  final double offset;

  const _CustomFABLocation({this.offset = 16});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX =
        scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.floatingActionButtonSize.width -
        16;
    final double fabY =
        scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        offset;
    return Offset(fabX, fabY);
  }
}

class SocietyDetailsPage extends StatefulWidget {
  const SocietyDetailsPage({super.key, required this.societyId});

  final String societyId;

  @override
  State<SocietyDetailsPage> createState() => _SocietyDetailsPageState();
}

class _SocietyDetailsPageState extends State<SocietyDetailsPage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  bool _isLoading = true;
  bool _isSaving = false;
  int _currentTabIndex = 0;
  SocietyModel? _society;
  List<UserModel> _people = const [];
  List<String> _selectedMembers = const [];
  List<String> _selectedBoard = const [];
  Map<String, List<String>> _boardWithPositions =
      const {}; // Map<position, List<userId>>
  Map<String, List<String>> _forumUsersByCategory =
      const {}; // Map<category, List<userId>>
  final SocietyChatRepository _chatRepository = SocietyChatRepository();

  // Hard-coded: ELO é a única sociedade que tem a aba Fórum
  static const String _eloSocietyName = 'ELO';

  @override
  void initState() {
    super.initState();
    // Inicializar com 2 tabs por padrão (será atualizado após carregar dados se for ELO)
    _tabController = TabController(length: 2, vsync: this);
    _tabController!.addListener(_onTabChanged);
    _loadData();
  }

  bool get _isELOSociety {
    return _society?.name == _eloSocietyName;
  }

  bool get _canSeeForumTab {
    if (!_isELOSociety) return false;
    final user = context.read<AppState>().currentUser;
    if (user == null || _society == null) return false;
    // Apenas usuários que estão na Diretoria da ELO podem ver a aba Fórum
    // (Admin não tem acesso automático)
    return _society!.allBoardIds.contains(user.id);
  }

  void _updateTabControllerIfNeeded() {
    final shouldHaveForumTab = _isELOSociety && _canSeeForumTab;
    final currentTabCount = _tabController?.length ?? 2;
    final targetTabCount = shouldHaveForumTab ? 3 : 2;

    if (currentTabCount != targetTabCount) {
      final oldIndex = _tabController?.index ?? 0;
      _tabController?.removeListener(_onTabChanged);
      _tabController?.dispose();
      _tabController = TabController(
        length: targetTabCount,
        vsync: this,
        initialIndex: oldIndex < targetTabCount ? oldIndex : 0,
      );
      _tabController!.addListener(_onTabChanged);
      _currentTabIndex = _tabController!.index;
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController != null && _currentTabIndex != _tabController!.index) {
      setState(() {
        _currentTabIndex = _tabController!.index;
      });
    }
  }

  bool get _canEdit {
    final user = context.read<AppState>().currentUser;
    if (user == null || _society == null) return false;
    return user.isAdmin || user.id == _society!.userId;
  }

  @override
  Widget build(BuildContext context) {
    final society = _society;
    final title = society == null ? 'Sociedade' : society.name;
    final canSeeForum = _canSeeForumTab;

    // Atualizar TabController se necessário (após dados carregados)
    if (!_isLoading && society != null) {
      _updateTabControllerIfNeeded();
    }

    if (_tabController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_canEdit)
            TextButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Salvar'),
              onPressed: (_isSaving || !_canEdit) ? null : _save,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorColor: society != null
              ? Color(society.color)
              : const Color(0xFF4CAF50),
          labelColor: society != null
              ? Color(society.color)
              : const Color(0xFF4CAF50),
          unselectedLabelColor: Colors.white,
          tabs: _tabController!.length == 3
              ? [
                  const Tab(text: 'Diretoria'),
                  const Tab(text: 'Membros'),
                  const Tab(text: 'Fórum'),
                ]
              : [const Tab(text: 'Diretoria'), const Tab(text: 'Membros')],
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : society == null
              ? const Center(child: Text('Sociedade não encontrada.'))
              : TabBarView(
                  controller: _tabController,
                  children: _tabController!.length == 3
                      ? [_buildBoardTab(), _buildMembersTab(), _buildForumTab()]
                      : [_buildBoardTab(), _buildMembersTab()],
                ),
          // Botão de chat flutuante - acima do botão +
          if (society != null && society.allBoardIds.isNotEmpty)
            Builder(
              builder: (context) {
                final user = context.read<AppState>().currentUser;
                // Botão só aparece se o usuário estiver na lista da Diretoria
                final isInBoard =
                    user != null && society.allBoardIds.contains(user.id);

                if (!isInBoard) return const SizedBox.shrink();

                return Positioned(
                  bottom: _canEdit
                      ? 150
                      : 100, // Espaçamento ajustado do botão +
                  right: 16,
                  child: StreamBuilder<int>(
                    stream: _chatRepository.getUnreadMessageCount(
                      widget.societyId,
                    ),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      final hasUnread = unreadCount > 0;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          FloatingActionButton(
                            heroTag: 'chat',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SocietyChatPage(
                                    societyId: widget.societyId,
                                    society: society,
                                  ),
                                ),
                              );
                            },
                            child: const Icon(Icons.chat),
                          ),
                          if (hasUnread)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.fromBorderSide(
                                    BorderSide(
                                      color: Color(0xFF0D1220),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: _canEdit
          ? (_currentTabIndex == 0
                ? FloatingActionButton(
                    heroTag: 'add',
                    onPressed: _manageBoard,
                    child: const Icon(Icons.group_add),
                  )
                : _currentTabIndex == 1
                ? FloatingActionButton(
                    heroTag: 'add',
                    onPressed: _manageMembers,
                    child: const Icon(Icons.group_add),
                  )
                : canSeeForum && _currentTabIndex == 2
                ? FloatingActionButton(
                    heroTag: 'add',
                    onPressed: _manageForum,
                    child: const Icon(Icons.people),
                  )
                : null)
          : null,
      floatingActionButtonLocation: const _CustomFABLocation(offset: 80),
    );
  }

  Widget _buildMembersTab() {
    if (_selectedMembers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.white38),
              SizedBox(height: 16),
              Text('Nenhum membro atribuído à sociedade.'),
            ],
          ),
        ),
      );
    }
    final members =
        _people.where((user) => _selectedMembers.contains(user.id)).toList()
          ..sort((a, b) => compareNamesIgnoreAccents(a.name, b.name));

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: members.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: Colors.white.withOpacity(0.1)),
      itemBuilder: (context, index) {
        final user = members[index];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  user.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                ),
              ),
              if (_canEdit)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => setState(() {
                    _selectedMembers = List.of(_selectedMembers)
                      ..remove(user.id);
                  }),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBoardTab() {
    // Se não tiver posições e não tiver boardIds, mostrar mensagem vazia
    if (_boardWithPositions.isEmpty && _selectedBoard.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 64,
                color: Colors.white38,
              ),
              SizedBox(height: 16),
              Text('Nenhum membro da diretoria atribuído à sociedade.'),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exibir seções por cargo (formato novo)
          if (_boardWithPositions.isNotEmpty) ...[
            ...BoardPosition.values.map((position) {
              // Buscar por label em minúsculo (formato esperado)
              final positionKey = position.label.toLowerCase();
              final userIds =
                  _boardWithPositions[positionKey] ??
                  _boardWithPositions[position.name] ??
                  _boardWithPositions[position.label] ??
                  [];
              if (userIds.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildPositionSection(position.label, userIds),
              );
            }),
          ],
          // Exibir usuários sem cargo (formato antigo - compatibilidade)
          if (_boardWithPositions.isEmpty && _selectedBoard.isNotEmpty) ...[
            _buildPositionSection('Diretoria', _selectedBoard),
          ],
        ],
      ),
    );
  }

  Widget _buildPositionSection(String title, List<String> userIds) {
    final people = _people.where((user) => userIds.contains(user.id)).toList()
      ..sort((a, b) => compareNamesIgnoreAccents(a.name, b.name));

    if (people.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: people
              .map(
                (user) => InputChip(
                  label: Text(user.name),
                  avatar: CircleAvatar(
                    child: Text(user.name.isNotEmpty ? user.name[0] : '?'),
                  ),
                  onDeleted: _canEdit
                      ? () {
                          setState(() {
                            // Remover do boardIds
                            _selectedBoard = List.of(_selectedBoard)
                              ..remove(user.id);
                            // Remover do boardWithPositions
                            _boardWithPositions =
                                Map<String, List<String>>.from(
                                  _boardWithPositions.map(
                                    (key, value) => MapEntry(
                                      key,
                                      List<String>.from(value)..remove(user.id),
                                    ),
                                  ),
                                )..removeWhere((key, value) => value.isEmpty);
                          });
                        }
                      : null,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final societiesRepository = context.read<SocietiesRepository>();
      final peopleRepository = context.read<PeopleRepository>();

      // Carregar sociedade primeiro (obrigatório)
      final society = await societiesRepository.fetchById(widget.societyId);

      // Carregar pessoas de forma independente
      List<UserModel> people = const [];
      try {
        people = await peopleRepository.fetchAll();
      } catch (e) {
        // Não mostrar erro ao usuário - apenas usar lista vazia
      }

      setState(() {
        _society = society;
        _selectedMembers = List.of(society.membersIds);
        // Usar allBoardIds para compatibilidade com formato antigo
        _selectedBoard = List.of(society.allBoardIds);
        // Se tiver posições, usar; senão, criar mapa vazio
        _boardWithPositions = society.boardWithPositions.isNotEmpty
            ? Map<String, List<String>>.from(
                society.boardWithPositions.map(
                  (key, value) => MapEntry(key, List<String>.from(value)),
                ),
              )
            : {};
        // Carregar forumUsersByCategory
        _forumUsersByCategory = society.forumUsersByCategory != null
            ? Map<String, List<String>>.from(
                society.forumUsersByCategory!.map(
                  (key, value) => MapEntry(key, List<String>.from(value)),
                ),
              )
            : {};
        _people = people;
        // Atualizar TabController após carregar dados se for ELO
        _updateTabControllerIfNeeded();
      });
    } catch (e) {
      setState(() {
        _society = null;
      });
      if (mounted) {
        showErrorToast(context, 'Erro ao carregar sociedade: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _manageMembers() async {
    // Recarregar usuários da collection users antes de abrir a modal
    try {
      final peopleRepository = context.read<PeopleRepository>();
      final people = await peopleRepository.fetchAll();
      setState(() {
        _people = people;
      });
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao carregar usuários: ${e.toString()}');
      }
      return;
    }

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          PeopleSelectorSheet(people: _people, selectedIds: _selectedMembers),
    );
    if (result != null) {
      setState(() => _selectedMembers = result);
    }
  }

  Future<void> _manageBoard() async {
    // Recarregar usuários da collection users antes de abrir a modal
    try {
      final peopleRepository = context.read<PeopleRepository>();
      final people = await peopleRepository.fetchAll();
      setState(() {
        _people = people;
      });
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao carregar usuários: ${e.toString()}');
      }
      return;
    }

    // Primeiro, mostrar modal para selecionar o cargo
    final selectedPosition = await showModalBottomSheet<BoardPosition?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BoardPositionSelectorSheet(),
    );

    if (selectedPosition == null) {
      return; // Usuário cancelou
    }

    // Depois, mostrar modal para selecionar o usuário
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PeopleSelectorSheet(
        people: _people,
        selectedIds: const [], // Não pré-selecionar ninguém
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Adicionar o usuário selecionado na lista do cargo escolhido
      setState(() {
        final userId = result.first;
        // Remover o usuário de outros cargos se já estiver em algum
        _boardWithPositions = Map<String, List<String>>.from(
          _boardWithPositions.map(
            (key, value) =>
                MapEntry(key, List<String>.from(value)..remove(userId)),
          ),
        )..removeWhere((key, value) => value.isEmpty);

        // Adicionar o usuário ao cargo selecionado
        // Usar o label do cargo em minúsculo como chave (ex: 'presidente', 'vice', 'secretario(a)', 'tesoureiro(a)')
        final positionKey = selectedPosition.label.toLowerCase();
        final currentList = _boardWithPositions[positionKey] ?? [];
        if (!currentList.contains(userId)) {
          final newList = List<String>.from(currentList)..add(userId);
          _boardWithPositions = Map<String, List<String>>.from(
            _boardWithPositions,
          )..[positionKey] = newList;
        }

        // Atualizar _selectedBoard para compatibilidade
        if (!_selectedBoard.contains(userId)) {
          _selectedBoard = List.of(_selectedBoard)..add(userId);
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_canEdit) {
      showErrorToast(
        context,
        'Você não tem permissão para editar esta sociedade.',
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final repository = context.read<SocietiesRepository>();
      await repository.updateMembers(
        id: widget.societyId,
        membersIds: _selectedMembers,
      );

      // Se tiver posições, salvar no formato novo; senão, usar formato antigo
      if (_boardWithPositions.isNotEmpty) {
        await repository.updateBoardWithPositions(
          id: widget.societyId,
          boardWithPositions: _boardWithPositions,
        );
      } else if (_selectedBoard.isNotEmpty) {
        await repository.updateBoard(
          id: widget.societyId,
          boardIds: _selectedBoard,
        );
      }

      // Salvar forumUsersByCategory se for ELO
      if (_society?.name == 'ELO' && _forumUsersByCategory.isNotEmpty) {
        await repository.updateForumUsersByCategory(
          id: widget.societyId,
          forumUsersByCategory: _forumUsersByCategory,
        );
      }

      if (mounted) {
        showSuccessToast(context, 'Sociedade atualizada com sucesso!');
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao salvar alterações: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildForumTab() {
    if (_society?.name != 'ELO') {
      return const Center(
        child: Text('Esta funcionalidade é apenas para a sociedade ELO.'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Usuários do Fórum por Categoria',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gerencie os usuários que podem avaliar músicas em cada categoria',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          _buildForumCategorySection('theological', 'Coerência Teológica'),
          const SizedBox(height: 24),
          _buildForumCategorySection(
            'congregational',
            'Coerência Congregacional',
          ),
          const SizedBox(height: 24),
          _buildForumCategorySection('musical', 'Coerência Musical'),
        ],
      ),
    );
  }

  Widget _buildForumCategorySection(String categoryKey, String categoryLabel) {
    final userIds = _forumUsersByCategory[categoryKey] ?? [];
    final users = _people.where((user) => userIds.contains(user.id)).toList()
      ..sort((a, b) => compareNamesIgnoreAccents(a.name, b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              categoryLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Gerenciar'),
              onPressed: () => _manageForumCategory(categoryKey, categoryLabel),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (users.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Nenhum usuário adicionado',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white60),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: users
                .map(
                  (user) => InputChip(
                    label: Text(user.name),
                    avatar: CircleAvatar(
                      child: Text(user.name.isNotEmpty ? user.name[0] : '?'),
                    ),
                    onDeleted: _canEdit
                        ? () {
                            setState(() {
                              final currentList =
                                  _forumUsersByCategory[categoryKey] ?? [];
                              _forumUsersByCategory =
                                  Map<String, List<String>>.from(
                                      _forumUsersByCategory,
                                    )
                                    ..[categoryKey] = List<String>.from(
                                      currentList,
                                    )
                                    ..[categoryKey]!.remove(user.id);
                            });
                          }
                        : null,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Future<void> _manageForumCategory(
    String categoryKey,
    String categoryLabel,
  ) async {
    // Recarregar usuários
    try {
      final peopleRepository = context.read<PeopleRepository>();
      final people = await peopleRepository.fetchAll();
      setState(() {
        _people = people;
      });
    } catch (e) {
      if (mounted) {
        showErrorToast(context, 'Erro ao carregar usuários: ${e.toString()}');
      }
      return;
    }

    final currentUserIds = _forumUsersByCategory[categoryKey] ?? [];
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          PeopleSelectorSheet(people: _people, selectedIds: currentUserIds),
    );

    if (result != null) {
      setState(() {
        _forumUsersByCategory = Map<String, List<String>>.from(
          _forumUsersByCategory,
        )..[categoryKey] = result;
      });
    }
  }

  Future<void> _manageForum() async {
    // Mostrar diálogo para selecionar categoria
    final selectedCategory = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecionar categoria'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Coerência Teológica'),
              onTap: () => Navigator.of(context).pop('theological'),
            ),
            ListTile(
              title: const Text('Coerência Congregacional'),
              onTap: () => Navigator.of(context).pop('congregational'),
            ),
            ListTile(
              title: const Text('Coerência Musical'),
              onTap: () => Navigator.of(context).pop('musical'),
            ),
          ],
        ),
      ),
    );

    if (selectedCategory != null) {
      final categoryLabels = {
        'theological': 'Coerência Teológica',
        'congregational': 'Coerência Congregacional',
        'musical': 'Coerência Musical',
      };
      await _manageForumCategory(
        selectedCategory,
        categoryLabels[selectedCategory]!,
      );
    }
  }
}

class _BoardPositionSelectorSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1220),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Selecionar cargo',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              ...BoardPosition.values.map((position) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(position),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              position.label,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.white54,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
