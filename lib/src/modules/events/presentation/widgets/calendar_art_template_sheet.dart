import 'package:flutter/material.dart';

import '../../../../shared/services/pexels/pexels_models.dart';
import '../../models/calendar_art_template.dart';
import 'pexels_image_picker_modal.dart';

/// Tipo de fundo na arte: cores (procedural) ou imagem (Pexels).
enum ArtBackgroundType { colors, image }

/// Sheet para editar as opções do template da arte do calendário.
/// Usado na tela "Gerar arte do mês" e na configuração por sociedade.
/// Quando [backgroundType], [selectedPexelsPhoto] e callbacks são fornecidos,
/// exibe o seletor Cores/Imagem e o fluxo "Buscar imagem".
class CalendarArtTemplateSheet extends StatefulWidget {
  const CalendarArtTemplateSheet({
    super.key,
    required this.template,
    this.categoryColors = const {},
    this.backgroundType,
    this.selectedPexelsPhoto,
    this.overlayIntensity = 0.5,
    this.blurAmount = 0.65,
    this.onBackgroundTypeChanged,
    this.onPexelsPhotoSelected,
    this.onOverlayIntensityChanged,
    this.onBlurAmountChanged,
  });

  final CalendarArtTemplate template;
  final Map<String, Color> categoryColors;
  final ArtBackgroundType? backgroundType;
  final PexelsPhoto? selectedPexelsPhoto;
  /// Intensidade do overlay (0–1) quando fundo é Imagem.
  final double overlayIntensity;
  /// Intensidade do blur (0–1) quando fundo é Imagem.
  final double blurAmount;
  final void Function(ArtBackgroundType)? onBackgroundTypeChanged;
  final void Function(PexelsPhoto?)? onPexelsPhotoSelected;
  final void Function(double)? onOverlayIntensityChanged;
  final void Function(double)? onBlurAmountChanged;

  @override
  State<CalendarArtTemplateSheet> createState() => _CalendarArtTemplateSheetState();
}

class _CalendarArtTemplateSheetState extends State<CalendarArtTemplateSheet> {
  late CalendarArtTemplate _t;
  late TextEditingController _titleController;
  late TextEditingController _logoUrlController;
  late ArtBackgroundType _backgroundType;
  PexelsPhoto? _pickedPhoto;
  late double _localOverlayIntensity;
  late double _localBlurAmount;

  bool get _hasImageFlow =>
      widget.backgroundType != null &&
      widget.onBackgroundTypeChanged != null &&
      widget.onPexelsPhotoSelected != null;

  bool get _canAdjustOverlay =>
      _hasImageFlow &&
      _backgroundType == ArtBackgroundType.image &&
      widget.onOverlayIntensityChanged != null;

  @override
  void initState() {
    super.initState();
    _t = widget.template;
    _titleController = TextEditingController(text: widget.template.titleText ?? '');
    _logoUrlController = TextEditingController(text: widget.template.logoImageUrl ?? '');
    _backgroundType = widget.backgroundType ?? ArtBackgroundType.colors;
    _pickedPhoto = widget.selectedPexelsPhoto;
    _localOverlayIntensity = widget.overlayIntensity.clamp(0.0, 1.0);
    _localBlurAmount = widget.blurAmount.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(CalendarArtTemplateSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overlayIntensity != widget.overlayIntensity) {
      _localOverlayIntensity = widget.overlayIntensity.clamp(0.0, 1.0);
    }
    if (oldWidget.blurAmount != widget.blurAmount) {
      _localBlurAmount = widget.blurAmount.clamp(0.0, 1.0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  Future<void> _openBuscarImagem() async {
    final photo = await showModalBottomSheet<PexelsPhoto>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.85,
        child: PexelsImagePickerModal(),
      ),
    );
    if (photo != null && mounted) {
      setState(() => _pickedPhoto = photo);
      widget.onPexelsPhotoSelected?.call(photo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Personalizar arte',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
            ),
            if (_hasImageFlow) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Fundo',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<ArtBackgroundType>(
                  segments: const [
                    ButtonSegment(value: ArtBackgroundType.colors, label: Text('Cores'), icon: Icon(Icons.palette_outlined)),
                    ButtonSegment(value: ArtBackgroundType.image, label: Text('Imagem'), icon: Icon(Icons.image_outlined)),
                  ],
                  selected: {_backgroundType},
                  onSelectionChanged: (Set<ArtBackgroundType> selected) {
                    final v = selected.first;
                    setState(() {
                      _backgroundType = v;
                      if (v == ArtBackgroundType.colors) _pickedPhoto = null;
                    });
                    widget.onBackgroundTypeChanged?.call(v);
                    if (v == ArtBackgroundType.colors) widget.onPexelsPhotoSelected?.call(null);
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) return Theme.of(context).colorScheme.primary;
                      return Colors.white12;
                    }),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
                  ),
                ),
              ),
              if (_backgroundType == ArtBackgroundType.image) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      if (_pickedPhoto != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _pickedPhoto!.src.tiny ?? _pickedPhoto!.imageUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              color: Colors.white12,
                              child: const Icon(Icons.image_not_supported, color: Colors.white38),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Imagem selecionada',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ] else
                        const Expanded(
                          child: Text(
                            'Nenhuma imagem selecionada',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                      FilledButton.tonalIcon(
                        onPressed: _openBuscarImagem,
                        icon: const Icon(Icons.search, size: 20),
                        label: const Text('Buscar imagem'),
                      ),
                    ],
                  ),
                ),
              ],
              if (_backgroundType == ArtBackgroundType.colors) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Cor do fundo',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: kCalendarArtGradientColorOptions.map((colorValue) {
                      final isSelected = _t.gradientColor == colorValue ||
                          (_t.gradientColor == null &&
                              colorValue == kCalendarArtGradientColorOptions.first);
                      return GestureDetector(
                        onTap: () => setState(() => _t = _t.copyWith(gradientColor: colorValue)),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(colorValue),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.white24,
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
            if (!_hasImageFlow) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Cor do fundo',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: kCalendarArtGradientColorOptions.map((colorValue) {
                    final isSelected = _t.gradientColor == colorValue ||
                        (_t.gradientColor == null &&
                            colorValue == kCalendarArtGradientColorOptions.first);
                    return GestureDetector(
                      onTap: () => setState(() => _t = _t.copyWith(gradientColor: colorValue)),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(colorValue),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.white24,
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            if (_canAdjustOverlay) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '+ Claro',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: _localOverlayIntensity,
                        min: 0,
                        max: 1,
                        divisions: 20,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: (v) {
                          setState(() => _localOverlayIntensity = v);
                          widget.onOverlayIntensityChanged?.call(v);
                        },
                      ),
                    ),
                    Text(
                      '+ Escuro',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onBlurAmountChanged != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Sem blur',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                      ),
                      Expanded(
                        child: Slider(
                          value: _localBlurAmount,
                          min: 0,
                          max: 1,
                          divisions: 20,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: (v) {
                            setState(() => _localBlurAmount = v);
                            widget.onBlurAmountChanged?.call(v);
                          },
                        ),
                      ),
                      Text(
                        'Máximo',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Layout dos eventos', style: TextStyle(color: Colors.white70)),
              subtitle: DropdownButton<CalendarArtEventsLayout>(
                value: _t.eventsLayout,
                dropdownColor: const Color(0xFF1A1F2E),
                isExpanded: true,
                items: CalendarArtEventsLayout.values
                    .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
                    .toList(),
                onChanged: (v) => v != null ? setState(() => _t = _t.copyWith(eventsLayout: v)) : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Título (opcional)',
                  border: OutlineInputBorder(),
                ),
                controller: _titleController,
                onChanged: (v) => setState(() => _t = _t.copyWith(titleText: v.isEmpty ? null : v)),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'URL da logo (opcional)',
                  hintText: 'https://...',
                  helperText: 'Substitui a logo do app no rodapé da arte.',
                  border: OutlineInputBorder(),
                ),
                controller: _logoUrlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                onChanged: (v) => setState(() => _t = _t.copyWith(logoImageUrl: v.trim().isEmpty ? null : v.trim())),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tamanho da logo',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<LogoDisplaySize>(
                    segments: LogoDisplaySize.values
                        .map((e) => ButtonSegment(value: e, label: Text(e.label)))
                        .toList(),
                    selected: {_t.logoDisplaySize},
                    onSelectionChanged: (Set<LogoDisplaySize> selected) {
                      final v = selected.first;
                      setState(() => _t = _t.copyWith(logoDisplaySize: v));
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Theme.of(context).colorScheme.primary;
                        }
                        return Colors.white12;
                      }),
                      foregroundColor: WidgetStateProperty.all(Colors.white),
                    ),
                  ),
                  Text(
                    'Útil quando a imagem por URL fica pequena.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed: () {
                  final title = _titleController.text.trim();
                  final logoUrl = _logoUrlController.text.trim();
                  Navigator.of(context).pop(_t.copyWith(
                    titleText: title.isEmpty ? null : title,
                    logoImageUrl: logoUrl.isEmpty ? null : logoUrl,
                  ));
                },
                child: const Text('Aplicar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
