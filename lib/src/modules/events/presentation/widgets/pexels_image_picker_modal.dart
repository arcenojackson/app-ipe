import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/services/pexels/pexels_client.dart';
import '../../../../shared/services/pexels/pexels_models.dart';

/// Chips de sugestão de tags para busca (opcional).
const List<String> kPexelsSuggestedTags = [
  'abstract',
  'gradient',
  'texture',
  'bokeh',
  'minimal',
  'mesh',
];

/// Modal "Buscar imagem" que exibe grid de fotos Pexels com busca e infinite scroll.
/// Retorna [PexelsPhoto] ao selecionar uma imagem; fecha e volta para a modal anterior.
class PexelsImagePickerModal extends StatefulWidget {
  const PexelsImagePickerModal({super.key});

  @override
  State<PexelsImagePickerModal> createState() => _PexelsImagePickerModalState();
}

class _PexelsImagePickerModalState extends State<PexelsImagePickerModal> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<PexelsPhoto> _photos = [];
  int _page = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String _query = 'abstract';
  CancelToken? _cancelToken;
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _searchController.text = _query;
    _scrollController.addListener(_onScroll);
    _search();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _cancelToken?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final s = _scrollController;
    if (!s.hasClients || _loadingMore || _loading || _error != null) return;
    final extent = s.position.maxScrollExtent - 120;
    if (s.offset >= extent) _loadMore();
  }

  void _debouncedSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      final q = _searchController.text.trim();
      if (q.isEmpty) return;
      if (q == _query) return;
      setState(() {
        _query = q;
        _page = 1;
        _photos.clear();
        _error = null;
      });
      _search();
    });
  }

  Future<void> _search() async {
    if (_loading) return;
    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = context.read<PexelsClient>();
      if (!client.hasApiKey) {
        setState(() {
          _error = 'PEXELS_API_KEY não configurada.';
          _loading = false;
        });
        return;
      }
      final response = await client.search(
        query: _query,
        orientation: 'portrait',
        perPage: 30,
        page: _page,
        cancelToken: _cancelToken,
      );
      if (!mounted) return;
      setState(() {
        if (_page == 1) _photos.clear();
        _photos.addAll(response.photos);
        _loading = false;
        _loadingMore = false;
      });
    } on PexelsCancelException {
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('PexelsException: ', '');
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading) return;
    final client = context.read<PexelsClient>();
    if (!client.hasApiKey) return;
    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    setState(() => _loadingMore = true);
    try {
      final response = await client.search(
        query: _query,
        orientation: 'portrait',
        perPage: 30,
        page: _page + 1,
        cancelToken: _cancelToken,
      );
      if (!mounted) return;
      setState(() {
        _page = _page + 1;
        _photos.addAll(response.photos);
        _loadingMore = false;
      });
    } on PexelsCancelException {
      if (mounted) setState(() => _loadingMore = false);
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onPhotoTap(PexelsPhoto photo) {
    Navigator.of(context).pop(photo);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Buscar imagem',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Digite tags (ex: abstract, gradient, texture)',
                hintStyle: TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.white70),
                  onPressed: () {
                    final q = _searchController.text.trim();
                    if (q.isEmpty) return;
                    _debounceTimer?.cancel();
                    setState(() {
                      _query = q;
                      _page = 1;
                      _photos.clear();
                      _error = null;
                    });
                    _search();
                  },
                ),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => _debouncedSearch(),
              onSubmitted: (v) {
                final q = v.trim();
                if (q.isEmpty) return;
                _debounceTimer?.cancel();
                setState(() {
                  _query = q;
                  _page = 1;
                  _photos.clear();
                  _error = null;
                });
                _search();
              },
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: kPexelsSuggestedTags.map((tag) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(tag, style: const TextStyle(color: Colors.white70)),
                    backgroundColor: Colors.white12,
                    selected: _query == tag,
                    onSelected: (selected) {
                      if (!selected) return;
                      _searchController.text = tag;
                      setState(() {
                        _query = tag;
                        _page = 1;
                        _photos.clear();
                        _error = null;
                      });
                      _search();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() => _error = null);
                _search();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }
    if (_loading && _photos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_photos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhuma foto encontrada. Tente outros termos.',
            style: TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: _photos.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _photos.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final photo = _photos[index];
        final url = photo.src.tiny ?? photo.src.small ?? photo.imageUrl;
        if (url.isEmpty) return const SizedBox.shrink();
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onPhotoTap(photo),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                placeholder: (_, __) => Container(
                  color: Colors.white12,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.white12,
                  child: const Icon(Icons.broken_image, color: Colors.white38),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
