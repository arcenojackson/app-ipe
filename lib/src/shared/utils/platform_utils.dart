import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Utilitário para detectar informações sobre a plataforma e navegação do sistema
class PlatformUtils {
  /// Verifica se o app está rodando no Android
  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Verifica se o app está rodando no iOS
  static bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Obtém o tipo de navegação do sistema Android
  /// Retorna:
  /// - 'buttons' se usar navegação de 3 botões
  /// - 'gesture' se usar navegação por gestos
  /// - 'unknown' se não for possível determinar
  static String getAndroidNavigationType(BuildContext context) {
    if (!isAndroid) return 'unknown';

    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;

    // Se há padding inferior significativo, provavelmente é navegação de botões
    // Navegação por gestos geralmente tem padding menor ou zero
    // Navegação de 3 botões geralmente tem padding entre 0 e ~48 pixels
    if (bottomPadding > 0) {
      // Valores típicos:
      // - Navegação de 3 botões: ~0-48px (dependendo do dispositivo)
      // - Navegação por gestos: ~0-16px (barra de gestos fina)
      if (bottomPadding >= 16) {
        return 'buttons'; // Provavelmente navegação de 3 botões
      } else {
        return 'gesture'; // Provavelmente navegação por gestos
      }
    }

    // Se não há padding, pode ser navegação por gestos ou dispositivo antigo
    return 'gesture';
  }

  /// Obtém o padding inferior necessário para evitar sobreposição com navegação do sistema
  static double getBottomNavigationPadding(BuildContext context) {
    if (isIOS) {
      // iOS geralmente não precisa de padding extra para a barra de navegação
      // mas pode precisar considerar a safe area
      return MediaQuery.of(context).padding.bottom;
    }

    if (isAndroid) {
      final navType = getAndroidNavigationType(context);
      final mediaQuery = MediaQuery.of(context);
      final bottomPadding = mediaQuery.padding.bottom;

      // Para navegação de 3 botões, precisamos adicionar padding extra
      // para evitar que os botões do sistema cubram a barra de navegação do app
      if (navType == 'buttons' && bottomPadding > 0) {
        // Retorna o padding do sistema + um pequeno espaço extra para segurança
        return bottomPadding + 8;
      }

      // Para navegação por gestos, geralmente não precisa de muito padding extra
      // mas ainda precisamos considerar a safe area
      return bottomPadding > 0 ? bottomPadding : 0;
    }

    return 0;
  }

  /// Verifica se o dispositivo usa navegação de 3 botões no Android
  static bool hasButtonNavigation(BuildContext context) {
    if (!isAndroid) return false;
    return getAndroidNavigationType(context) == 'buttons';
  }

  /// Verifica se o dispositivo usa navegação por gestos no Android
  static bool hasGestureNavigation(BuildContext context) {
    if (!isAndroid) return false;
    return getAndroidNavigationType(context) == 'gesture';
  }

  /// Obtém o padding inferior extra para modais no Android
  /// Retorna um valor maior para Android para evitar sobreposição com navegação do sistema
  static double getModalBottomPadding(BuildContext context) {
    if (isAndroid) {
      // No Android, sempre adiciona padding extra para modais
      // independente do tipo de navegação
      final mediaQuery = MediaQuery.of(context);
      final bottomPadding = mediaQuery.padding.bottom;
      // Adiciona padding extra mínimo de 24px + padding do sistema
      return (bottomPadding > 0 ? bottomPadding : 0) + 24;
    }
    // iOS não precisa de padding extra
    return 0;
  }

  /// Wrapper para showModalBottomSheet que adiciona padding inferior extra no Android
  /// Use esta função em vez de showModalBottomSheet diretamente
  static Future<T?> showModalBottomSheetAndroid<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = false,
    bool useRootNavigator = false,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    Color? barrierColor,
    bool useSafeArea = false,
    String? barrierLabel,
    AnimationController? transitionAnimationController,
    Offset? anchorPoint,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      barrierColor: barrierColor,
      useSafeArea: useSafeArea,
      barrierLabel: barrierLabel,
      transitionAnimationController: transitionAnimationController,
      anchorPoint: anchorPoint,
      builder: (context) {
        final modalContent = builder(context);
        final androidPadding = getModalBottomPadding(context);

        // Se for Android e tiver padding extra, envolve o conteúdo com padding
        if (isAndroid && androidPadding > 0) {
          return Padding(
            padding: EdgeInsets.only(bottom: androidPadding),
            child: modalContent,
          );
        }

        return modalContent;
      },
    );
  }
}
