import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Fundo com imagem + overlay escuro adaptativo para garantir legibilidade de texto.
///
/// Ordem das camadas na [Stack] (de baixo para cima):
/// 1. Imagem de fundo (CachedNetworkImage)
/// 2. [Opcional] Blur (BackdropFilter dentro de ClipRect para evitar overflow)
/// 3. Overlay em gradiente vertical (preto semitransparente)
/// 4. [Opcional] Vignette (gradiente radial nas bordas)
/// 5. Conteúdo (child)
///
/// Uso típico: capas de app, stories, arte de calendário sobre foto.
class BackgroundImageWithOverlay extends StatelessWidget {
  const BackgroundImageWithOverlay({
    super.key,
    required this.imageUrl,
    required this.child,
    this.overlayIntensity = 0.65,
    this.enableBlur = true,
    this.autoContrast = true,
    this.enableVignette = true,
    /// Intensidade do blur 0–1 (0 = sem blur, 1 = sigma 12). Usado para [blurSigmaX]/[blurSigmaY] quando não fornecidos.
    this.blurAmount = 0.65,
    this.blurSigmaX,
    this.blurSigmaY,
    this.placeholder,
    this.errorWidget,
  });

  /// URL da imagem de fundo.
  final String imageUrl;

  /// Conteúdo sobre o fundo (texto, calendário, etc.).
  final Widget child;

  /// Intensidade do overlay escuro (0.0 = mais claro, 1.0 = mais escuro).
  /// Interpola entre: top 0.35–0.55, bottom 0.50–0.70 de opacidade do preto (cores da imagem aparecem mais).
  /// Valores típicos: 0.4–0.65 para equilíbrio entre legibilidade e destaque da foto.
  final double overlayIntensity;

  /// Se true, aplica desfoque suave entre a imagem e o overlay (reduz ruído e melhora leitura).
  final bool enableBlur;

  /// Se true, usa overlay mais forte por padrão (recomendado para tema escuro e máxima legibilidade).
  final bool autoContrast;

  /// Se true, aplica leve escurecimento nas bordas (vignette) para foco no centro.
  final bool enableVignette;

  /// Intensidade do blur 0–1 (0 = desligado, 1 = máximo). Ignorado se [blurSigmaX]/[blurSigmaY] forem fornecidos.
  final double blurAmount;

  /// Sigma do blur horizontal. Se null, usa [blurAmount] * 12 (máx. 12).
  final double? blurSigmaX;

  /// Sigma do blur vertical. Se null, usa [blurAmount] * 12.
  final double? blurSigmaY;

  /// Widget exibido enquanto a imagem carrega.
  final Widget? placeholder;

  /// Widget exibido em caso de erro de carregamento.
  final Widget? errorWidget;

  /// Opacidade do gradiente no topo (interpolada por [overlayIntensity] e [autoContrast]).
  /// Faixa mais suave (0.35–0.55) para as cores da imagem aparecerem mais.
  static double _topOpacity(double intensity, bool autoContrast) {
    final base = 0.35 + (0.55 - 0.35) * intensity.clamp(0.0, 1.0);
    return autoContrast ? (base + 0.06).clamp(0.0, 1.0) : base;
  }

  /// Opacidade do gradiente na base (mais escuro para ancorar o conteúdo, mas ainda leve).
  static double _bottomOpacity(double intensity, bool autoContrast) {
    final base = 0.50 + (0.70 - 0.50) * intensity.clamp(0.0, 1.0);
    return autoContrast ? (base + 0.04).clamp(0.0, 1.0) : base;
  }

  @override
  Widget build(BuildContext context) {
    final topOp = _topOpacity(overlayIntensity, autoContrast);
    final bottomOp = _bottomOpacity(overlayIntensity, autoContrast);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camada 1: imagem de fundo
        Positioned.fill(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (_, __) =>
                placeholder ??
                Container(
                  color: const Color(0xFF1A1F2E),
                  child: const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            errorWidget: (_, __, ___) =>
                errorWidget ??
                Container(
                  color: const Color(0xFF1A1F2E),
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white38, size: 48),
                  ),
                ),
          ),
        ),

        // Camada 2: blur opcional (entre imagem e overlay para não desfocar o texto)
        if (enableBlur && (blurSigmaX != null ? blurSigmaX! : blurAmount * 12) > 0)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: (blurSigmaX ?? blurAmount * 12).clamp(0.0, 12.0),
                  sigmaY: (blurSigmaY ?? blurAmount * 12).clamp(0.0, 12.0),
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(color: Colors.transparent),
                ),
              ),
            ),
          ),

        // Camada 3: overlay em gradiente vertical (escurece de cima para baixo)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: topOp),
                  Colors.black.withValues(alpha: bottomOp),
                ],
              ),
            ),
          ),
        ),

        // Camada 4: vignette opcional (escurece bordas, centro mais legível)
        if (enableVignette)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.18),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),
          ),

        // Camada 5: conteúdo (texto, calendário, etc.)
        Positioned.fill(child: child),
      ],
    );
  }
}
