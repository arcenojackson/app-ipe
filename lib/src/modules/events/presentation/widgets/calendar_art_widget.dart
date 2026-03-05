import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/background_generator.dart';
import '../../../../shared/widgets/background_image_with_overlay.dart';
import '../../../../shared/services/pexels/pexels_models.dart';
import '../../models/calendar_art_template.dart';
import '../../models/calendar_event.dart';
import 'calendar_art_template_sheet.dart';

/// Dimensões lógicas da arte (com pixelRatio 2 na captura → 1080x1080 px).
const double kCalendarArtWidth = 540;
const double kCalendarArtHeight = 540;

/// Widget que desenha a "arte" do calendário do mês para exportar como imagem.
/// Deve ser envolvido em [RepaintBoundary] para captura.
class CalendarArtWidget extends StatelessWidget {
  const CalendarArtWidget({
    super.key,
    required this.month,
    required this.year,
    required this.events,
    this.eventsForList,
    required this.template,
    required this.categoryColors,
    this.appPrimaryColor = const Color(0xFF2F4F2F),
    this.backgroundType = ArtBackgroundType.colors,
    this.pexelsPhoto,
    this.overlayIntensity = 0.5,
    this.blurAmount = 0.65,
  });

  final int month;
  final int year;

  /// Eventos para bolinhas nos dias e legenda (pode incluir serviços).
  final List<CalendarEventModel> events;

  /// Eventos só para a lista; se null, usa [events] (só da collection events, sem cultos/EBD/reuniões).
  final List<CalendarEventModel>? eventsForList;
  final CalendarArtTemplate template;
  final Map<String, Color> categoryColors;
  final Color appPrimaryColor;
  final ArtBackgroundType backgroundType;
  final PexelsPhoto? pexelsPhoto;

  /// Intensidade do overlay (0–1) quando o fundo é imagem Pexels.
  final double overlayIntensity;

  /// Intensidade do blur (0–1) quando o fundo é imagem Pexels.
  final double blurAmount;

  @override
  Widget build(BuildContext context) {
    final isLight = template.colorScheme == CalendarArtColorScheme.light;
    final textColor = isLight
        ? const Color(0xFF1a1a1a)
        : const Color(0xFFf5f5f5);
    final secondaryColor = isLight
        ? const Color(0xFF555555)
        : const Color(0xFFb0b0b0);

    final monthName = DateFormat('MMMM', 'pt_BR').format(DateTime(year, month));
    final title = template.titleText?.isNotEmpty == true
        ? template.titleText!
        : 'IPE – ${_capitalize(monthName)} $year';

    final baseColor = template.gradientColor != null
        ? Color(template.gradientColor!)
        : const Color(0xFF1a237e);
    final seed =
        (template.gradientColor ?? 0xFF1a237e) * 31 + year * 12 + month;

    final content = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: template.eventsLayout == CalendarArtEventsLayout.listAbove
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _EventsListCompact(
                          events: eventsForList ?? events,
                          categoryColors: categoryColors,
                          textColor: textColor,
                          secondaryColor: secondaryColor,
                          monthLabel: _capitalize(monthName),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ColorLegend(
                        events: events,
                        categoryColors: categoryColors,
                        textColor: secondaryColor,
                      ),
                      const SizedBox(height: 4),
                      _CalendarGrid(
                        month: month,
                        year: year,
                        events: events,
                        template: template,
                        categoryColors: categoryColors,
                        textColor: textColor,
                        secondaryColor: secondaryColor,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CalendarGrid(
                        month: month,
                        year: year,
                        events: events,
                        template: template,
                        categoryColors: categoryColors,
                        textColor: textColor,
                        secondaryColor: secondaryColor,
                      ),
                      Transform.translate(
                        offset: const Offset(0, -4),
                        child: _ColorLegend(
                          events: events,
                          categoryColors: categoryColors,
                          textColor: secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _EventsListCompact(
                          events: eventsForList ?? events,
                          categoryColors: categoryColors,
                          textColor: textColor,
                          secondaryColor: secondaryColor,
                          monthLabel: _capitalize(monthName),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Center(
            child: _buildLogo(template.logoImageUrl, template.logoDisplaySize),
          ),
        ],
      ),
    );

    // Com imagem Pexels: fundo com overlay adaptativo (blur + gradiente + vignette) + conteúdo.
    if (backgroundType == ArtBackgroundType.image && pexelsPhoto != null) {
      return SizedBox(
        width: kCalendarArtWidth,
        height: kCalendarArtHeight,
        child: BackgroundImageWithOverlay(
          imageUrl: pexelsPhoto!.imageUrl,
          overlayIntensity: overlayIntensity,
          blurAmount: blurAmount,
          enableBlur: true,
          autoContrast: true,
          enableVignette: true,
          child: content,
        ),
      );
    }

    // Sem imagem ou fundo procedural: Stack clássico (fundo + conteúdo).
    Widget background;
    if (backgroundType == ArtBackgroundType.image) {
      background = Container(
        color: const Color(0xFF1A1F2E),
        child: Center(
          child: Text(
            'Selecione uma imagem',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ),
      );
    } else {
      background = ProceduralBackground(
        params: ProceduralBackgroundParams(
          seed: seed,
          baseColor: baseColor,
          paletteMode: PaletteMode.calm,
          grainEnabled: true,
          grainIntensity: 0.4,
          meshPointCount: 5,
        ),
      );
    }

    return SizedBox(
      width: kCalendarArtWidth,
      height: kCalendarArtHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: background),
          Positioned.fill(child: content),
        ],
      ),
    );
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }

  static Widget _buildLogo(String? logoImageUrl, LogoDisplaySize logoDisplaySize) {
    final height = logoDisplaySize.height;
    if (logoImageUrl != null && logoImageUrl.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: logoImageUrl.trim(),
        height: height,
        fit: BoxFit.contain,
        placeholder: (_, __) => SizedBox(height: height, width: height),
        errorWidget: (_, __, ___) => Image.asset(
          'assets/images/logo.png',
          height: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }
    return Image.asset(
      'assets/images/logo.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.year,
    required this.events,
    required this.template,
    required this.categoryColors,
    required this.textColor,
    required this.secondaryColor,
  });

  final int month;
  final int year;
  final List<CalendarEventModel> events;
  final CalendarArtTemplate template;
  final Map<String, Color> categoryColors;
  final Color textColor;
  final Color secondaryColor;

  List<CalendarEventModel> _eventsForDay(int day) {
    return events
        .where(
          (CalendarEventModel e) =>
              e.date.year == year && e.date.month == month && e.date.day == day,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0).day;
    final startWeekday = first.weekday % 7;
    const weekdays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: weekdays
              .map(
                (d) => Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: secondaryColor, fontSize: 10),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        Table(
          border: null,
          children: [
            for (int row = 0; row < 6; row++)
              TableRow(
                children: List.generate(7, (col) {
                  final dayIndex = row * 7 + col - startWeekday + 1;
                  if (dayIndex < 1 || dayIndex > lastDay) {
                    return const SizedBox(
                      height: 22,
                      child: Center(child: Text('')),
                    );
                  }
                  final dayEvents = _eventsForDay(dayIndex);
                  final hasEvents = dayEvents.isNotEmpty;
                  return Container(
                    height: 22,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayIndex',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 10,
                            fontWeight: hasEvents
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (hasEvents) ...[
                          const SizedBox(height: 1),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: dayEvents.take(3).map((
                                CalendarEventModel e,
                              ) {
                                final color =
                                    categoryColors[e.category] ??
                                    const Color(0xFF2F4F2F);
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ),
          ],
        ),
      ],
    );
  }
}

class _ColorLegend extends StatelessWidget {
  const _ColorLegend({
    required this.events,
    required this.categoryColors,
    required this.textColor,
  });

  final List<CalendarEventModel> events;
  final Map<String, Color> categoryColors;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final categories = events.map((e) => e.category).toSet().toList()..sort();
    if (categories.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 2,
      alignment: WrapAlignment.start,
      children: categories.map((cat) {
        final color = categoryColors[cat] ?? const Color(0xFF2F4F2F);
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 4),
              Text(cat, style: TextStyle(color: textColor, fontSize: 11)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _EventsListCompact extends StatelessWidget {
  const _EventsListCompact({
    required this.events,
    required this.categoryColors,
    required this.textColor,
    required this.secondaryColor,
    required this.monthLabel,
  });

  final List<CalendarEventModel> events;
  final Map<String, Color> categoryColors;
  final Color textColor;
  final Color secondaryColor;
  final String monthLabel;

  Widget _buildEventItem(CalendarEventModel e) {
    final color = categoryColors[e.category] ?? const Color(0xFF2F4F2F);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${e.date.day}/${e.date.month}',
                  style: TextStyle(color: secondaryColor, fontSize: 11),
                ),
                Text(
                  e.name,
                  style: TextStyle(color: textColor, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<CalendarEventModel>.from(events)
      ..sort(CalendarEventModel.compareByDateAndTime);
    final items = sorted.take(20).toList();
    final mid = (items.length / 2).ceil();
    final left = items.sublist(0, mid);
    final right = items.sublist(mid);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Eventos de $monthLabel',
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: left.map(_buildEventItem).toList(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: right.map(_buildEventItem).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
