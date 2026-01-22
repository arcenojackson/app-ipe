import 'package:flutter/material.dart';

/// Widget que adiciona efeitos de destaque (pulso, brilho, contorno) a um botão
class HighlightedButtonWrapper extends StatefulWidget {
  const HighlightedButtonWrapper({
    super.key,
    required this.child,
    this.highlighted = false,
    required this.highlightColor,
  });

  final Widget child;
  final bool highlighted;
  final Color highlightColor;

  @override
  State<HighlightedButtonWrapper> createState() =>
      _HighlightedButtonWrapperState();
}

class _HighlightedButtonWrapperState extends State<HighlightedButtonWrapper>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    // Iniciar animações se highlighted for true
    if (widget.highlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pulseController.repeat(reverse: true);
          _glowController.repeat(reverse: true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(HighlightedButtonWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlighted != oldWidget.highlighted) {
      if (widget.highlighted) {
        _pulseController.repeat(reverse: true);
        _glowController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
        _glowController.stop();
        _glowController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.highlighted) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _glowAnimation]),
      builder: (context, child) {
        final glowOpacity = _glowAnimation.value;

        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              // Sombra externa pulsante
              boxShadow: [
                BoxShadow(
                  color: widget.highlightColor.withOpacity(0.7 * glowOpacity),
                  blurRadius: 35,
                  spreadRadius: 6,
                  offset: const Offset(0, 0),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.4 * glowOpacity),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Colors.white.withOpacity(0.9 * glowOpacity),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.highlightColor.withOpacity(0.6 * glowOpacity),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
