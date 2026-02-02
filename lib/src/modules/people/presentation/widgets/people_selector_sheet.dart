import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/models/user.dart';
import '../../../events/data/events_repository.dart';
import '../../../societies/data/societies_repository.dart';
import '../../../../shared/utils/platform_utils.dart';
import '../../../../shared/utils/sort_utils.dart';

class PeopleSelectorSheet extends StatefulWidget {
  const PeopleSelectorSheet({
    super.key,
    required this.people,
    required this.selectedIds,
    this.eventDate,
    this.filterByELO = false,
    this.filterBySociety,
    this.instrument,
    this.showTalkBack = false,
    this.title,
    this.canGoBack = false,
  });

  final List<UserModel> people;
  final List<String> selectedIds;
  final DateTime? eventDate;
  final bool filterByELO;
  final String?
  filterBySociety; // Nome da sociedade para filtrar (ex: "Som e Imagem")
  final String?
  instrument; // Instrumento selecionado (ex: "Violão", "Baixo", etc.)
  final bool showTalkBack; // Se deve mostrar checkbox de Talk Back
  final String? title;
  final bool canGoBack;

  @override
  State<PeopleSelectorSheet> createState() => _PeopleSelectorSheetState();
}

class _PeopleSelectorSheetState extends State<PeopleSelectorSheet> {
  // ... (unchanged)
  late List<String> _selectedIds;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<UserModel> _filteredPeople = [];
  bool _isLoading = true;
  final Map<String, bool> _talkBackSelections = {}; // Map<userId, isTalkBack>

  @override
  void initState() {
    super.initState();
    _selectedIds = List.of(widget.selectedIds);
    _searchController.addListener(_onSearchChanged);
    _filterPeople();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterPeople();
    });
  }

  Future<void> _filterPeople() async {
    // Se não precisa filtrar por sociedade, usar filtro simples
    if (!widget.filterByELO && widget.filterBySociety == null) {
      setState(() {
        _isLoading = false;
        if (_searchQuery.isEmpty) {
          _filteredPeople = widget.people;
        } else {
          _filteredPeople = widget.people.where((person) {
            final name = person.name.toLowerCase();
            final email = person.email.toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();
        }
        // Ordenar por nome alfabeticamente (ignorando acentos)
        _filteredPeople.sort(
          (a, b) => compareNamesIgnoreAccents(a.name, b.name),
        );
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final societiesRepository = context.read<SocietiesRepository>();

      // Buscar sociedade (ELO ou outra)
      final societyName = widget.filterByELO ? 'ELO' : widget.filterBySociety!;
      final society = await societiesRepository.fetchByName(societyName);

      if (society == null) {
        setState(() {
          _isLoading = false;
          _filteredPeople = [];
        });
        return;
      }

      // Obter IDs de membros e diretoria da sociedade
      final memberIds = <String>{...society.membersIds, ...society.boardIds};

      // Filtrar pessoas que pertencem à sociedade
      var filteredPeople = widget.people
          .where((person) => memberIds.contains(person.id))
          .toList();

      // Se for ELO, aplicar filtro de disponibilidade sempre que houver data do evento
      // O filtro usa as disponibilidades que foram informadas no mês anterior
      if (widget.filterByELO && widget.eventDate != null) {
        final eventsRepository = context.read<EventsRepository>();
        final availablePeople = <UserModel>[];

        for (final person in filteredPeople) {
          try {
            final hasAvailability = await eventsRepository
                .hasAvailabilityForDate(person.id, widget.eventDate!);
            if (hasAvailability) {
              availablePeople.add(person);
            }
          } catch (e) {
            // Se houver erro ao verificar disponibilidade, não incluir o usuário
          }
        }

        filteredPeople = availablePeople;
      }

      // Aplicar filtro de busca se houver
      if (_searchQuery.isNotEmpty) {
        filteredPeople = filteredPeople.where((person) {
          final name = person.name.toLowerCase();
          final email = person.email.toLowerCase();
          return name.contains(_searchQuery) || email.contains(_searchQuery);
        }).toList();
      }

      // Ordenar por nome alfabeticamente (ignorando acentos)
      filteredPeople.sort((a, b) => compareNamesIgnoreAccents(a.name, b.name));

      setState(() {
        _isLoading = false;
        _filteredPeople = filteredPeople;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _filteredPeople = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context);
    var androidBottomPadding = PlatformUtils.getModalBottomPadding(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom + androidBottomPadding,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              if (widget.canGoBack)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop('BACK'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              Expanded(
                child: Text(
                  widget.title ?? 'Selecionar pessoas',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nome ou email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 400,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPeople.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.white38),
                        const SizedBox(height: 16),
                        Text(
                          widget.filterByELO
                              ? 'Nenhum membro da ELO com disponibilidade encontrado'
                              : widget.filterBySociety != null
                              ? 'Nenhum membro de ${widget.filterBySociety} encontrado'
                              : 'Nenhum resultado encontrado',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white60),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _filteredPeople.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final person = _filteredPeople[index];
                      final selected = _selectedIds.contains(person.id);
                      final talkBack = _talkBackSelections[person.id] ?? false;

                      return Column(
                        children: [
                          CheckboxListTile(
                            value: selected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedIds = [..._selectedIds, person.id];
                                  if (!widget.showTalkBack) {
                                    _talkBackSelections[person.id] = false;
                                  }
                                } else {
                                  _selectedIds = _selectedIds
                                      .where((id) => id != person.id)
                                      .toList();
                                  _talkBackSelections.remove(person.id);
                                }
                              });
                            },
                            title: Text(person.name),
                            subtitle: Text(person.email),
                          ),
                          if (selected &&
                              widget.showTalkBack &&
                              widget.instrument != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 72,
                                right: 16,
                                bottom: 8,
                              ),
                              child: CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                value: talkBack,
                                onChanged: (value) {
                                  setState(() {
                                    _talkBackSelections[person.id] =
                                        value ?? false;
                                  });
                                },
                                title: Text(
                                  'Talk Back',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                // Retornar dados apropriados baseado no contexto
                if (widget.showTalkBack && widget.instrument != null) {
                  // Retornar Map com userId -> Map<instrument, talkBack>
                  final result = <String, Map<String, bool>>{};
                  for (final userId in _selectedIds) {
                    result[userId] = {
                      widget.instrument!: _talkBackSelections[userId] ?? false,
                    };
                  }
                  Navigator.of(context).pop(result);
                } else {
                  Navigator.of(context).pop(_selectedIds);
                }
              },
              child: const Text('Salvar'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
