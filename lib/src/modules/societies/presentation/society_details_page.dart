import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user.dart';
import '../../people/data/people_repository.dart';
import '../../people/presentation/widgets/people_selector_sheet.dart';
import '../../../shared/utils/app_toast.dart';
import '../../../shared/state/app_state.dart';
import '../data/societies_repository.dart';
import '../models/society.dart';

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
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;
  int _currentTabIndex = 0;
  SocietyModel? _society;
  List<UserModel> _people = const [];
  List<String> _selectedMembers = const [];
  List<String> _selectedBoard = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_currentTabIndex != _tabController.index) {
      setState(() {
        _currentTabIndex = _tabController.index;
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
          tabs: const [
            Tab(text: 'Diretoria'),
            Tab(text: 'Membros'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : society == null
              ? const Center(child: Text('Sociedade não encontrada.'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBoardTab(),
                    _buildMembersTab(),
                  ],
                ),
      floatingActionButton: _canEdit
          ? (_currentTabIndex == 0
              ? FloatingActionButton(
                  onPressed: _manageBoard,
                  child: const Icon(Icons.group_add),
                )
              : FloatingActionButton(
                  onPressed: _manageMembers,
                  child: const Icon(Icons.group_add),
                ))
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
    final members = _people
        .where((user) => _selectedMembers.contains(user.id))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: members
            .map(
              (user) => InputChip(
                label: Text(user.name),
                avatar: CircleAvatar(
                  child: Text(user.name.isNotEmpty ? user.name[0] : '?'),
                ),
                onDeleted: _canEdit
                    ? () => setState(() {
                          _selectedMembers =
                              List.of(_selectedMembers)..remove(user.id);
                        })
                    : null,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBoardTab() {
    if (_selectedBoard.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.admin_panel_settings_outlined,
                  size: 64, color: Colors.white38),
              SizedBox(height: 16),
              Text('Nenhum membro da diretoria atribuído à sociedade.'),
            ],
          ),
        ),
      );
    }
    final board = _people
        .where((user) => _selectedBoard.contains(user.id))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: board
            .map(
              (user) => InputChip(
                label: Text(user.name),
                avatar: CircleAvatar(
                  child: Text(user.name.isNotEmpty ? user.name[0] : '?'),
                ),
                onDeleted: _canEdit
                    ? () => setState(() {
                          _selectedBoard = List.of(_selectedBoard)..remove(user.id);
                        })
                    : null,
              ),
            )
            .toList(),
      ),
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
        _selectedBoard = List.of(society.boardIds);
        _people = people;
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
      builder: (_) => PeopleSelectorSheet(
        people: _people,
        selectedIds: _selectedMembers,
      ),
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

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PeopleSelectorSheet(
        people: _people,
        selectedIds: _selectedBoard,
      ),
    );
    if (result != null) {
      setState(() => _selectedBoard = result);
    }
  }

  Future<void> _save() async {
    if (!_canEdit) {
      showErrorToast(context, 'Você não tem permissão para editar esta sociedade.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final repository = context.read<SocietiesRepository>();
      await repository.updateMembers(
        id: widget.societyId,
        membersIds: _selectedMembers,
      );
      await repository.updateBoard(
        id: widget.societyId,
        boardIds: _selectedBoard,
      );
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
}

