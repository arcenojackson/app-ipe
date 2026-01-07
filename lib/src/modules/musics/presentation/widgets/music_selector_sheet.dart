import 'package:flutter/material.dart';

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
    _filtered = widget.musics;
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
                        leading: Icon(
                          Icons.music_note,
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : null,
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
        _filtered = widget.musics;
      } else {
        _filtered = widget.musics
            .where(
              (music) =>
                  music.title.toLowerCase().contains(query) ||
                  music.artist.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }
}
