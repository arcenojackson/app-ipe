// Copyright 2025. Fundo procedural premium: mesh gradient + grain + paletas.
//
// Algoritmos:
// - Mesh: 4–7 pontos de cor (posições pseudoaleatórias por seed). Cada ponto é
//   desenhado como círculo com RadialGradient (cor→transparente) e blend mode
//   (ex.: plus/overlay), sobre uma base escura. Transições suaves, aspecto malha.
// - Grain: muitos círculos pequenos (opacidade baixa) gravados em ui.Picture
//   uma vez por (width, height, seed). Cache em [_grainCache] (máx. 8 entradas).
//   Reutilizado a cada frame; intensidade aplicada na composição (saveLayer).
// - Paletas: generateHarmoniousPalette() deriva cores em HSL (análogas ±hueSpread,
//   sat/light por PaletteMode: calm, vibrant, night, neonSoft). Tema escuro.
//
// Performance: mesh e paleta pré-computados em ProceduralBackgroundData; grain
// só é gerado em cache miss (getOrCreateGrainPicture). Repaint apenas quando
// data/params/size mudam.
//
// Exemplo com RepaintBoundary para exportar imagem:
//   RepaintBoundary(
//     child: ProceduralBackground(
//       params: ProceduralBackgroundParams(
//         seed: 42,
//         baseColor: Colors.blue.shade900,
//         paletteMode: PaletteMode.vibrant,
//         grainEnabled: true,
//         grainIntensity: 0.4,
//         meshPointCount: 6,
//       ),
//       child: Conteudo(),
//     ),
//   )
//   // Captura: boundary.findRenderObject() as RenderRepaintBoundary; toImage(pixelRatio: 2).

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// =============================================================================
// PALETAS HARMÔNICAS
// =============================================================================

/// Modos de paleta para o fundo procedural (temas escuros, contrastes suaves).
enum PaletteMode {
  calm,
  vibrant,
  night,
  neonSoft,
}

/// Gera uma paleta harmônica a partir de uma cor base e seed.
///
/// Usa HSL: análogas (±20–40°), variações de saturação/lightness por modo.
/// Mesmo [base] + [seed] + [mode] => mesma lista de cores.
List<Color> generateHarmoniousPalette(
  Color base, {
  required int seed,
  PaletteMode mode = PaletteMode.calm,
  int colorCount = 6,
}) {
  final rnd = Random(seed);
  final hsl = HSLColor.fromColor(base);
  final h = hsl.hue;

  double hueSpread;
  double sMin;
  double sMax;
  double lMin;
  double lMax;

  switch (mode) {
    case PaletteMode.calm:
      hueSpread = 20 + rnd.nextDouble() * 20;
      sMin = 0.25;
      sMax = 0.5;
      lMin = 0.2;
      lMax = 0.4;
      break;
    case PaletteMode.vibrant:
      hueSpread = 25 + rnd.nextDouble() * 25;
      sMin = 0.45;
      sMax = 0.75;
      lMin = 0.25;
      lMax = 0.5;
      break;
    case PaletteMode.night:
      hueSpread = 10 + rnd.nextDouble() * 15;
      sMin = 0.15;
      sMax = 0.4;
      lMin = 0.12;
      lMax = 0.28;
      break;
    case PaletteMode.neonSoft:
      hueSpread = 30 + rnd.nextDouble() * 30;
      sMin = 0.35;
      sMax = 0.6;
      lMin = 0.28;
      lMax = 0.48;
      break;
  }

  final colors = <Color>[];
  for (int i = 0; i < colorCount; i++) {
    final t = colorCount > 1 ? i / (colorCount - 1) : 0.5;
    final hueOffset = (t - 0.5) * 2 * hueSpread;
    final hue = (h + hueOffset) % 360;
    final sat = (sMin + rnd.nextDouble() * (sMax - sMin)).clamp(0.0, 1.0);
    final light = (lMin + rnd.nextDouble() * (lMax - lMin)).clamp(0.0, 1.0);
    colors.add(HSLColor.fromAHSL(1.0, hue, sat, light).toColor());
  }
  return colors;
}

// =============================================================================
// PARÂMETROS E DADOS
// =============================================================================

@immutable
class ProceduralBackgroundParams {
  const ProceduralBackgroundParams({
    this.seed,
    this.baseColor,
    this.paletteMode = PaletteMode.calm,
    this.grainEnabled = true,
    this.grainIntensity = 0.4,
    this.meshPointCount = 5,
    this.meshBlendMode = BlendMode.plus,
    this.meshRadiusScale = 0.55,
    this.meshOpacity = 0.5,
    this.blobsEnabled = true,
    this.numBlobs = 5,
    this.blobOpacityMin = 0.04,
    this.blobOpacityMax = 0.16,
    this.organicIntensity = 0.35,
  });

  final int? seed;
  final Color? baseColor;
  final PaletteMode paletteMode;
  final bool grainEnabled;
  final double grainIntensity;
  final int meshPointCount;
  final BlendMode meshBlendMode;
  final double meshRadiusScale;
  final double meshOpacity;
  /// Formas orgânicas (curvas/sombras) por cima do mesh.
  final bool blobsEnabled;
  final int numBlobs;
  final double blobOpacityMin;
  final double blobOpacityMax;
  final double organicIntensity;

  ProceduralBackgroundParams copyWith({
    int? seed,
    Color? baseColor,
    PaletteMode? paletteMode,
    bool? grainEnabled,
    double? grainIntensity,
    int? meshPointCount,
    BlendMode? meshBlendMode,
    double? meshRadiusScale,
    double? meshOpacity,
    bool? blobsEnabled,
    int? numBlobs,
    double? blobOpacityMin,
    double? blobOpacityMax,
    double? organicIntensity,
  }) {
    return ProceduralBackgroundParams(
      seed: seed ?? this.seed,
      baseColor: baseColor ?? this.baseColor,
      paletteMode: paletteMode ?? this.paletteMode,
      grainEnabled: grainEnabled ?? this.grainEnabled,
      grainIntensity: grainIntensity ?? this.grainIntensity,
      meshPointCount: meshPointCount ?? this.meshPointCount,
      meshBlendMode: meshBlendMode ?? this.meshBlendMode,
      meshRadiusScale: meshRadiusScale ?? this.meshRadiusScale,
      meshOpacity: meshOpacity ?? this.meshOpacity,
      blobsEnabled: blobsEnabled ?? this.blobsEnabled,
      numBlobs: numBlobs ?? this.numBlobs,
      blobOpacityMin: blobOpacityMin ?? this.blobOpacityMin,
      blobOpacityMax: blobOpacityMax ?? this.blobOpacityMax,
      organicIntensity: organicIntensity ?? this.organicIntensity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProceduralBackgroundParams &&
          runtimeType == other.runtimeType &&
          seed == other.seed &&
          baseColor == other.baseColor &&
          paletteMode == other.paletteMode &&
          grainEnabled == other.grainEnabled &&
          grainIntensity == other.grainIntensity &&
          meshPointCount == other.meshPointCount &&
          meshBlendMode == other.meshBlendMode &&
          meshRadiusScale == other.meshRadiusScale &&
          meshOpacity == other.meshOpacity &&
          blobsEnabled == other.blobsEnabled &&
          numBlobs == other.numBlobs &&
          blobOpacityMin == other.blobOpacityMin &&
          blobOpacityMax == other.blobOpacityMax &&
          organicIntensity == other.organicIntensity;

  @override
  int get hashCode => Object.hash(
        seed,
        baseColor,
        paletteMode,
        grainEnabled,
        grainIntensity,
        meshPointCount,
        meshBlendMode,
        meshRadiusScale,
        meshOpacity,
        blobsEnabled,
        numBlobs,
        blobOpacityMin,
        blobOpacityMax,
        organicIntensity,
      );
}

/// Um ponto do mesh: posição normalizada (0–1) e cor.
class MeshPoint {
  const MeshPoint({required this.position, required this.color});
  final Offset position;
  final Color color;
}

class _BlobShape {
  const _BlobShape(this.path, this.paint);
  final Path path;
  final Paint paint;
}

/// Dados pré-computados do fundo (mesh + blobs + referência ao grain em cache).
class ProceduralBackgroundData {
  ProceduralBackgroundData({
    required this.baseColor,
    required this.meshPoints,
    required this.palette,
    required this.size,
    required this.params,
    this.grainPicture,
    this.blobShapes = const [],
  });

  final Color baseColor;
  final List<MeshPoint> meshPoints;
  final List<Color> palette;
  final Size size;
  final ProceduralBackgroundParams params;
  final ui.Picture? grainPicture;
  final List<_BlobShape> blobShapes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProceduralBackgroundData &&
          baseColor == other.baseColor &&
          size == other.size &&
          params == other.params &&
          grainPicture == other.grainPicture;

  @override
  int get hashCode => Object.hash(baseColor, size, params, grainPicture);
}

// =============================================================================
// GRAIN CACHE (ui.Picture por size + seed)
// =============================================================================

const int _kMaxGrainCacheEntries = 8;

class _GrainCacheEntry {
  _GrainCacheEntry(this.key, this.picture);
  final int key;
  final ui.Picture picture;
}

final List<_GrainCacheEntry> _grainCache = [];
int _grainCacheKey(double w, double h, int seed) =>
    Object.hash((w * 2).round(), (h * 2).round(), seed);

/// Retorna um [ui.Picture] de grain reutilizável para o tamanho e seed dados.
/// Cache limitado a [_kMaxGrainCacheEntries]; mesma seed + size => mesmo output.
ui.Picture getOrCreateGrainPicture(double width, double height, int seed) {
  final key = _grainCacheKey(width, height, seed);
  for (final e in _grainCache) {
    if (e.key == key) return e.picture;
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rnd = Random(seed);
  final count = (width * height * 0.025).round().clamp(2000, 35000);
  final baseOpacity = 0.12;

  for (int i = 0; i < count; i++) {
    final x = rnd.nextDouble() * width;
    final y = rnd.nextDouble() * height;
    final opacity = baseOpacity * (0.5 + rnd.nextDouble());
    canvas.drawCircle(
      Offset(x, y),
      0.6,
      Paint()
        ..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill,
    );
  }

  final picture = recorder.endRecording();

  if (_grainCache.length >= _kMaxGrainCacheEntries) {
    _grainCache.removeAt(0);
  }
  _grainCache.add(_GrainCacheEntry(key, picture));
  return picture;
}

// =============================================================================
// GERAÇÃO DE DADOS (mesh points + palette)
// =============================================================================

ProceduralBackgroundData generateProceduralBackgroundData({
  required ProceduralBackgroundParams params,
  required double width,
  required double height,
}) {
  final seed = params.seed ?? DateTime.now().millisecondsSinceEpoch;
  final baseColor = params.baseColor ?? const Color(0xFF1a237e);
  final rnd = Random(seed);

  final palette = generateHarmoniousPalette(
    baseColor,
    seed: seed + 1,
    mode: params.paletteMode,
    colorCount: 7,
  );

  final count = params.meshPointCount.clamp(4, 7);
  final meshPoints = <MeshPoint>[];

  for (int i = 0; i < count; i++) {
    final rx = 0.15 + rnd.nextDouble() * 0.7;
    final ry = 0.15 + rnd.nextDouble() * 0.7;
    meshPoints.add(MeshPoint(
      position: Offset(rx, ry),
      color: palette[i % palette.length],
    ));
  }

  ui.Picture? grainPicture;
  if (params.grainEnabled) {
    grainPicture = getOrCreateGrainPicture(width, height, seed + 2);
  }

  final blobShapes = <_BlobShape>[];
  if (params.blobsEnabled) {
    final blobRnd = Random(seed + 3);
    final numBlobs = params.numBlobs.clamp(1, 12);
    final hsl = HSLColor.fromColor(baseColor);
    for (int i = 0; i < numBlobs; i++) {
      final cx = width * (0.1 + blobRnd.nextDouble() * 0.8);
      final cy = height * (0.1 + blobRnd.nextDouble() * 0.8);
      final rx = width * (0.15 + blobRnd.nextDouble() * 0.35);
      final ry = height * (0.15 + blobRnd.nextDouble() * 0.35);
      final path = _createOrganicBlobPath(
        rnd: blobRnd,
        cx: cx,
        cy: cy,
        rx: rx,
        ry: ry,
        intensity: params.organicIntensity,
      );
      final hueShift = (blobRnd.nextDouble() - 0.5) * 50;
      final sat = (hsl.saturation + (blobRnd.nextDouble() - 0.5) * 0.2).clamp(0.2, 0.8);
      final lightness = (hsl.lightness + (blobRnd.nextDouble() - 0.5) * 0.2).clamp(0.2, 0.5);
      final opacity = (params.blobOpacityMin +
              blobRnd.nextDouble() * (params.blobOpacityMax - params.blobOpacityMin))
          .clamp(0.02, 0.5);
      final blobColor = HSLColor.fromAHSL(
        opacity,
        (hsl.hue + hueShift) % 360,
        sat,
        lightness,
      ).toColor();
      blobShapes.add(_BlobShape(path, Paint()..color = blobColor..style = PaintingStyle.fill));
    }
  }

  return ProceduralBackgroundData(
    baseColor: baseColor,
    meshPoints: meshPoints,
    palette: palette,
    size: Size(width, height),
    params: params,
    grainPicture: grainPicture,
    blobShapes: blobShapes,
  );
}

Path _createOrganicBlobPath({
  required Random rnd,
  required double cx,
  required double cy,
  required double rx,
  required double ry,
  required double intensity,
}) {
  const numPoints = 10;
  final points = <Offset>[];
  for (int i = 0; i < numPoints; i++) {
    final angle = (i / numPoints) * 2 * pi + (rnd.nextDouble() - 0.5) * intensity;
    final rScale = (0.7 + rnd.nextDouble() * 0.6) * intensity + (1 - intensity);
    points.add(Offset(
      cx + rx * rScale * cos(angle),
      cy + ry * rScale * sin(angle),
    ));
  }
  final path = Path();
  path.moveTo(points[0].dx, points[0].dy);
  for (int i = 1; i <= points.length; i++) {
    final p0 = points[(i - 1) % points.length];
    final p1 = points[i % points.length];
    final pPrev = points[(i - 2 + points.length) % points.length];
    final pNext = points[(i + 1) % points.length];
    final tension = 0.25;
    final cp1 = p0 + (p1 - pPrev) * tension;
    final cp2 = p1 - (pNext - p0) * tension;
    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
  }
  path.close();
  return path;
}

// =============================================================================
// MESH GRADIENT LAYER PAINTER
// =============================================================================

/// Desenha a camada de mesh gradient: base + círculos com RadialGradient e blend.
class MeshGradientLayerPainter extends CustomPainter {
  MeshGradientLayerPainter({required this.data});

  final ProceduralBackgroundData data;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final maxSide = max(size.width, size.height);
    final radius = maxSide * data.params.meshRadiusScale;

    final baseColor = data.palette.isNotEmpty
        ? data.palette.first
        : data.baseColor;
    final darkest = Color.lerp(baseColor, Colors.black, 0.5) ?? baseColor;
    canvas.drawRect(
      rect,
      Paint()..color = darkest,
    );

    for (final point in data.meshPoints) {
      final center = Offset(
        point.position.dx * size.width,
        point.position.dy * size.height,
      );
      final shader = ui.Gradient.radial(
        center,
        radius,
        [
          point.color.withOpacity(data.params.meshOpacity),
          point.color.withOpacity(0.0),
        ],
        [0.0, 1.0],
      );
      canvas.saveLayer(rect, Paint()..blendMode = data.params.meshBlendMode);
      canvas.drawCircle(center, radius, Paint()..shader = shader);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant MeshGradientLayerPainter old) =>
      data != old.data;
}

// =============================================================================
// PROCEDURAL BACKGROUND PAINTER (compõe mesh + grain)
// =============================================================================

class ProceduralBackgroundPainter extends CustomPainter {
  ProceduralBackgroundPainter({
    required this.data,
    this.animation,
  }) : super(repaint: animation);

  final ProceduralBackgroundData data;
  final Animation<double>? animation;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.save();
    canvas.clipRect(rect);

    final meshPainter = MeshGradientLayerPainter(data: data);
    meshPainter.paint(canvas, size);

    for (final shape in data.blobShapes) {
      canvas.drawPath(shape.path, shape.paint);
    }

    if (data.params.grainEnabled &&
        data.grainPicture != null &&
        data.params.grainIntensity > 0) {
      final intensity = data.params.grainIntensity.clamp(0.0, 1.0);
      canvas.saveLayer(rect, Paint()..color = Colors.white.withOpacity(intensity));
      canvas.drawPicture(data.grainPicture!);
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ProceduralBackgroundPainter old) =>
      data != old.data || animation != old.animation;
}

// =============================================================================
// WIDGET
// =============================================================================

class ProceduralBackground extends StatefulWidget {
  const ProceduralBackground({
    super.key,
    this.params = const ProceduralBackgroundParams(),
    this.child,
    this.animation,
  });

  final ProceduralBackgroundParams params;
  final Widget? child;
  final Animation<double>? animation;

  @override
  State<ProceduralBackground> createState() => _ProceduralBackgroundState();
}

class _ProceduralBackgroundState extends State<ProceduralBackground> {
  ProceduralBackgroundData? _cachedData;
  Size? _lastSize;
  ProceduralBackgroundParams? _lastParams;

  ProceduralBackgroundData _getOrCreateData(double width, double height) {
    final size = Size(width, height);
    if (_cachedData != null &&
        _lastSize == size &&
        _lastParams == widget.params) {
      return _cachedData!;
    }
    _lastSize = size;
    _lastParams = widget.params;
    _cachedData = generateProceduralBackgroundData(
      params: widget.params,
      width: width,
      height: height,
    );
    return _cachedData!;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w <= 0 || h <= 0) {
          return widget.child ?? const SizedBox.shrink();
        }
        final data = _getOrCreateData(w, h);
        return ClipRect(
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: ProceduralBackgroundPainter(
                  data: data,
                  animation: widget.animation,
                ),
                size: Size(w, h),
              ),
              if (widget.child != null) widget.child!,
            ],
          ),
        );
      },
    );
  }
}
