import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/services/pexels/pexels_models.dart';
import '../../../shared/utils/app_toast.dart';
import '../../societies/data/societies_repository.dart';
import '../../societies/models/society.dart';
import '../data/events_repository.dart';
import '../models/calendar_art_template.dart';
import '../models/calendar_event.dart';
import 'widgets/calendar_art_template_sheet.dart' show ArtBackgroundType, CalendarArtTemplateSheet;
import 'widgets/calendar_art_widget.dart';

/// Tela para gerar e compartilhar a arte do calendário do mês.
class CalendarArtPage extends StatefulWidget {
  const CalendarArtPage({
    super.key,
    this.initialMonth,
    this.initialCategories = const [],
  });

  final DateTime? initialMonth;
  final List<String> initialCategories;

  @override
  State<CalendarArtPage> createState() => _CalendarArtPageState();
}

class _CalendarArtPageState extends State<CalendarArtPage> {
  late DateTime _selectedMonth;
  List<String> _selectedCategories = [];
  List<SocietyModel> _societies = [];
  /// Todos os eventos do mês (calendário + serviços) para bolinhas e legenda.
  List<CalendarEventModel> _events = [];
  /// Apenas eventos da collection events (sem cultos/EBD/reuniões) para a lista.
  List<CalendarEventModel> _eventsForList = [];
  Map<String, Color> _categoryColors = {};
  CalendarArtTemplate _template = const CalendarArtTemplate();
  String? _societyTemplateName;
  bool _useSocietyTemplate = false;
  ArtBackgroundType _backgroundType = ArtBackgroundType.colors;
  PexelsPhoto? _selectedPexelsPhoto;
  double _overlayIntensity = 0.5;
  double _blurAmount = 0.65;
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _error;
  final GlobalKey _artKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialMonth ?? DateTime.now();
    _selectedCategories = List.from(widget.initialCategories);
    _loadSocieties().then((_) => _loadData());
  }

  Future<void> _loadSocieties() async {
    try {
      final repo = context.read<SocietiesRepository>();
      final list = await repo.fetchAll();
      final colors = <String, Color>{};
      for (final s in list) {
        colors[s.name] = Color(s.color);
      }
      if (mounted) {
        setState(() {
          _societies = list;
          _categoryColors = {...colors, 'Geral': Theme.of(context).colorScheme.primary};
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final eventsRepo = context.read<EventsRepository>();
      final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      // Eventos + serviços no mês (para bolinhas nos dias e legenda)
      final allInMonth = await eventsRepo.fetchAllEventsForCalendarInRange(start, end);
      List<CalendarEventModel> filtered = allInMonth;
      if (_selectedCategories.isNotEmpty) {
        filtered = allInMonth.where((e) => _selectedCategories.contains(e.category)).toList();
      }
      filtered.sort(CalendarEventModel.compareByDateAndTime);
      // Lista de eventos: apenas da collection events (sem cultos/EBD/reuniões)
      final listOnly = filtered.where((e) => e.sourceCollection != 'services').toList();

      CalendarArtTemplate template = const CalendarArtTemplate();
      String? societyTemplateName;
      bool useSocietyTemplate = false;
      final societyNames = _selectedCategories.where((c) => c != 'Geral').toList();
      if (societyNames.length == 1) {
        SocietyModel? society;
        for (final s in _societies) {
          if (s.name == societyNames.first) {
            society = s;
            break;
          }
        }
        if (society != null && society.calendarArtTemplate != null) {
          template = society.calendarArtTemplate!;
          societyTemplateName = society.name;
          useSocietyTemplate = true;
        }
      }

      if (mounted) {
        setState(() {
          _events = filtered;
          _eventsForList = listOnly;
          if (useSocietyTemplate) {
            _template = template;
            _societyTemplateName = societyTemplateName;
            _useSocietyTemplate = true;
          } else {
            _societyTemplateName = null;
            _useSocietyTemplate = false;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _selectMonthYear() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(now.year - 1, 1),
      lastDate: DateTime(now.year + 2, 12),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && mounted) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
      await _loadData();
    }
  }

  void _showCategoryFilter() async {
    final temp = List<String>.from(_selectedCategories);
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CategoryFilterSheet(
        societies: _societies,
        selected: temp,
        categoryColors: _categoryColors,
      ),
    );
    if (result != null && mounted) {
      setState(() => _selectedCategories = result);
      await _loadData();
    }
  }

  void _showCustomizeTemplate() async {
    final result = await showModalBottomSheet<CalendarArtTemplate>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => CalendarArtTemplateSheet(
        template: _template,
        categoryColors: _categoryColors,
        backgroundType: _backgroundType,
        selectedPexelsPhoto: _selectedPexelsPhoto,
        overlayIntensity: _overlayIntensity,
        blurAmount: _blurAmount,
        onBackgroundTypeChanged: (v) {
          if (mounted) {
            setState(() {
              _backgroundType = v;
              if (v == ArtBackgroundType.colors) _selectedPexelsPhoto = null;
            });
          }
        },
        onPexelsPhotoSelected: (photo) {
          if (mounted) {
            setState(() => _selectedPexelsPhoto = photo);
          }
        },
        onOverlayIntensityChanged: (v) {
          if (mounted) {
            setState(() => _overlayIntensity = v);
          }
        },
        onBlurAmountChanged: (v) {
          if (mounted) {
            setState(() => _blurAmount = v);
          }
        },
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _template = result;
        _useSocietyTemplate = false;
        _societyTemplateName = null;
      });
    }
  }

  Future<void> _generateAndShare() async {
    setState(() => _isGenerating = true);
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = _artKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) showErrorToast(context, 'Preview não disponível. Tente novamente.');
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) showErrorToast(context, 'Falha ao gerar imagem.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final monthName = DateFormat('MMMM', 'pt_BR').format(_selectedMonth);
      final name = 'ipe_calendario_${_slug(monthName)}_${_selectedMonth.year}.png';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      Rect? shareOrigin;
      final shareBox = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      if (shareBox != null && shareBox.hasSize) {
        shareOrigin = shareBox.localToGlobal(Offset.zero) & shareBox.size;
      } else if (mounted) {
        final size = MediaQuery.of(context).size;
        shareOrigin = Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: 1,
          height: 1,
        );
      }
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Calendário ${_capitalize(monthName)} ${_selectedMonth.year}',
        sharePositionOrigin: shareOrigin,
      );
      if (mounted) showSuccessToast(context, 'Compartilhe pelo app escolhido.');
    } catch (e) {
      if (mounted) showErrorToast(context, 'Erro ao gerar: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  static String _slug(String s) {
    const map = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ã': 'a', 'õ': 'o', 'ç': 'c'};
    var r = s.toLowerCase();
    for (final e in map.entries) {
      r = r.replaceAll(e.key, e.value);
    }
    return r.replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'pt_BR').format(_selectedMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerar arte do mês'),
        actions: [
          if (_societyTemplateName != null && _useSocietyTemplate)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Chip(
                  label: Text('Template: $_societyTemplateName'),
                  onDeleted: () => setState(() {
                    _useSocietyTemplate = false;
                    _societyTemplateName = null;
                  }),
                ),
              ),
            ),
        ],
      ),
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
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectMonthYear,
                        icon: const Icon(Icons.calendar_month),
                        label: Text(_capitalize(monthLabel)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _showCategoryFilter,
                      icon: const Icon(Icons.filter_list),
                      label: Text(_selectedCategories.isEmpty ? 'Todos' : '${_selectedCategories.length} cat.'),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _loadData, child: const Text('Tentar novamente')),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            RepaintBoundary(
                              key: _artKey,
                              child: CalendarArtWidget(
                                month: _selectedMonth.month,
                                year: _selectedMonth.year,
                                events: _events,
                                eventsForList: _eventsForList,
                                template: _template,
                                categoryColors: _categoryColors,
                                appPrimaryColor: Theme.of(context).colorScheme.primary,
                                backgroundType: _backgroundType,
                                pexelsPhoto: _selectedPexelsPhoto,
                                overlayIntensity: _overlayIntensity,
                                blurAmount: _blurAmount,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Material(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  onTap: _showCustomizeTemplate,
                                  borderRadius: BorderRadius.circular(20),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(Icons.edit, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: FilledButton.icon(
                            key: _shareButtonKey,
                            onPressed: _isGenerating ? null : _generateAndShare,
                            icon: _isGenerating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.share),
                            label: const Text('Compartilhar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFilterSheet extends StatefulWidget {
  const _CategoryFilterSheet({
    required this.societies,
    required this.selected,
    required this.categoryColors,
  });

  final List<SocietyModel> societies;
  final List<String> selected;
  final Map<String, Color> categoryColors;

  @override
  State<_CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<_CategoryFilterSheet> {
  late List<String> _temp;

  @override
  void initState() {
    super.initState();
    _temp = List.from(widget.selected);
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
            padding: const EdgeInsets.all(16),
            child: Text(
              'Filtrar por categoria',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text('Todos'),
                  trailing: Radio<bool>(
                    value: true,
                    groupValue: _temp.isEmpty,
                    onChanged: (_) => setState(() => _temp = []),
                  ),
                  onTap: () => setState(() => _temp = []),
                ),
                ListTile(
                  leading: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.categoryColors['Geral'] ?? Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: const Text('Geral'),
                  trailing: Checkbox(
                    value: _temp.contains('Geral'),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _temp.add('Geral');
                        } else {
                          _temp.remove('Geral');
                        }
                      });
                    },
                  ),
                  onTap: () {
                    setState(() {
                      if (_temp.contains('Geral')) {
                        _temp.remove('Geral');
                      } else {
                        _temp.add('Geral');
                      }
                    });
                  },
                ),
                ...widget.societies.map((s) {
                  final selected = _temp.contains(s.name);
                  return ListTile(
                    leading: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(s.color),
                      ),
                    ),
                    title: Text(s.name),
                    trailing: Checkbox(
                      value: selected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _temp.add(s.name);
                          } else {
                            _temp.remove(s.name);
                          }
                        });
                      },
                    ),
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _temp.remove(s.name);
                        } else {
                          _temp.add(s.name);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_temp),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

