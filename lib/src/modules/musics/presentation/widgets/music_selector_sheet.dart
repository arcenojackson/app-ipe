import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import '../../models/music.dart';
import '../../../../shared/utils/platform_utils.dart';

class MusicSelectorField extends StatelessWidget {
  const MusicSelectorField({
    super.key,
    required this.musics,
    required this.selectedId,
    required this.onSelect,
  });

  final List<MusicModel> musics;
  final String? selectedId;
  final ValueChanged<MusicModel> onSelect;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: selectedId,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Selecione uma música';
        }
        return null;
      },
      builder: (state) {
        MusicModel? music;
        if (state.value != null) {
          try {
            music = musics.firstWhere((item) => item.id == state.value);
          } catch (_) {
            music = null;
          }
        }
        final displayText = music == null
            ? 'Selecione uma música'
            : '${music.title} • ${music.artist}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () async {
                final result = await _openSelector(context);
                if (result != null) {
                  onSelect(result);
                  state.didChange(result.id);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Música',
                  suffixIcon: const Icon(Icons.search),
                  errorText: state.errorText,
                ),
                child: Text(displayText),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<MusicModel?> _openSelector(BuildContext context) async {
    final result = await showModalBottomSheet<MusicModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _MusicSelectorSheet(musics: musics, selectedId: selectedId),
    );
    return result;
  }
}

class _MusicSelectorSheet extends StatefulWidget {
  const _MusicSelectorSheet({required this.musics, required this.selectedId});

  final List<MusicModel> musics;
  final String? selectedId;

  @override
  State<_MusicSelectorSheet> createState() => _MusicSelectorSheetState();
}

class _MusicSelectorSheetState extends State<_MusicSelectorSheet> {
  late List<MusicModel> _filtered;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = List.of(widget.musics)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
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
            'Selecionar música',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Buscar',
              hintText: 'Título ou artista',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 400,
            child: _filtered.isEmpty
                ? const Center(child: Text('Nenhuma música encontrada.'))
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final music = _filtered[index];
                      final selected = widget.selectedId == music.id;
                      return ListTile(
                        leading: GestureDetector(
                          onTap: () {
                            if (music.selectedTimes.isNotEmpty) {
                              _showHistory(music);
                            }
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: music.selectedTimes.isNotEmpty
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: music.selectedTimes.isNotEmpty
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white30,
                              ),
                            ),
                            child: Text(
                              music.selectedTimes.length.toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        title: Text(music.title),
                        subtitle: Text(music.artist),
                        trailing: selected ? const Icon(Icons.check) : null,
                        onTap: () => Navigator.of(context).pop(music),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = List.of(widget.musics)
          ..sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      } else {
        _filtered = widget.musics
            .where(
              (music) =>
                  music.title.toLowerCase().contains(query) ||
                  music.artist.toLowerCase().contains(query),
            )
            .toList()
          ..sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      }
    });
  }

  void _showHistory(MusicModel music) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final androidBottomPadding = PlatformUtils.getModalBottomPadding(context);
        return Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + androidBottomPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Histórico: ${music.title}',
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 250,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: music.selectedTimes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final dateStr = music.selectedTimes[index];
                    final date = DateTime.tryParse(dateStr);
                    final formatted = date != null
                        ? DateFormat('dd/MM/yyyy').format(date)
                        : dateStr;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.event, size: 20),
                      title: Text(formatted),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
