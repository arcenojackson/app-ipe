import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/models/user.dart';
import '../../../events/data/events_repository.dart';
import '../../../societies/data/societies_repository.dart';
import '../../../../shared/utils/platform_utils.dart';

class PeopleSelectorSheet extends StatefulWidget {
  const PeopleSelectorSheet({
    super.key,
    required this.people,
    required this.selectedIds,
    this.eventDate,
    this.filterByELO = false,
  });

  final List<UserModel> people;
  final List<String> selectedIds;
  final DateTime? eventDate;
  final bool filterByELO;

  @override
  State<PeopleSelectorSheet> createState() => _PeopleSelectorSheetState();
}

class _PeopleSelectorSheetState extends State<PeopleSelectorSheet> {
  late List<String> _selectedIds;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<UserModel> _filteredPeople = [];
  bool _isLoading = true;

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
    if (!widget.filterByELO || widget.eventDate == null) {
      // Se não precisa filtrar por ELO, usar filtro simples
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
        // Ordenar por nome alfabeticamente
        _filteredPeople.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Buscar sociedade ELO
      final societiesRepository = context.read<SocietiesRepository>();
      final eloSociety = await societiesRepository.fetchByName('ELO');

      if (eloSociety == null) {
        setState(() {
          _isLoading = false;
          _filteredPeople = [];
        });
        return;
      }

      // Obter IDs de membros e diretoria da ELO
      final eloMemberIds = <String>{
        ...eloSociety.membersIds,
        ...eloSociety.boardIds,
      };

      // Filtrar pessoas que pertencem à ELO
      var eloPeople = widget.people
          .where((person) => eloMemberIds.contains(person.id))
          .toList();

      // Filtrar por disponibilidade se houver data do evento
      if (widget.eventDate != null) {
        final eventsRepository = context.read<EventsRepository>();
        final availablePeople = <UserModel>[];

        for (final person in eloPeople) {
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

        eloPeople = availablePeople;
      }

      // Aplicar filtro de busca se houver
      if (_searchQuery.isNotEmpty) {
        eloPeople = eloPeople.where((person) {
          final name = person.name.toLowerCase();
          final email = person.email.toLowerCase();
          return name.contains(_searchQuery) || email.contains(_searchQuery);
        }).toList();
      }

      // Ordenar por nome alfabeticamente
      eloPeople.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      setState(() {
        _isLoading = false;
        _filteredPeople = eloPeople;
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
    final mediaQuery = MediaQuery.of(context);
    final androidBottomPadding = PlatformUtils.getModalBottomPadding(context);

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
          Text(
            'Selecionar pessoas',
            style: Theme.of(context).textTheme.titleLarge,
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
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedIds = [..._selectedIds, person.id];
                            } else {
                              _selectedIds = _selectedIds
                                  .where((id) => id != person.id)
                                  .toList();
                            }
                          });
                        },
                        title: Text(person.name),
                        subtitle: Text(person.email),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_selectedIds),
              child: const Text('Salvar'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
