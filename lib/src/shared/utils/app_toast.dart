import 'package:flutter/material.dart';

/// Cores do app
const _primaryGreen = Color(0xFF2F4F2F); // Verde principal
const _errorRed = Color(0xFFFF5470); // Vermelho de erro

/// Mostra um toast de sucesso no topo da tela, vindo da direita
void showSuccessToast(BuildContext context, String message) {
  _showCustomToast(
    context: context,
    message: message,
    backgroundColor: _primaryGreen,
    icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
  );
}

/// Mostra um toast de erro no topo da tela, vindo da direita
void showErrorToast(BuildContext context, String message) {
  _showCustomToast(
    context: context,
    message: message,
    backgroundColor: _errorRed,
    icon: const Icon(Icons.error, color: Colors.white, size: 20),
  );
}

void _showCustomToast({
  required BuildContext context,
  required String message,
  required Color backgroundColor,
  required Widget icon,
}) {
  // Verificar se o contexto ainda está válido
  if (!context.mounted) return;
  
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  
  late OverlayEntry overlayEntry;
  
  overlayEntry = OverlayEntry(
    builder: (context) => _CustomToast(
      message: message,
      backgroundColor: backgroundColor,
      icon: icon,
      onDismiss: () {
        // Verificar se o overlay ainda está montado e se o contexto é válido
        final currentOverlay = Overlay.maybeOf(context);
        if (overlayEntry.mounted && currentOverlay != null) {
          try {
            overlayEntry.remove();
          } catch (e) {
            // Ignorar erro se o overlay já foi removido
          }
        }
      },
    ),
  );

  overlay.insert(overlayEntry);

  // Remove automaticamente após 3 segundos
  Future.delayed(const Duration(seconds: 3), () {
    // Verificar se o contexto ainda está válido antes de remover
    if (!context.mounted) return;
    final currentOverlay = Overlay.maybeOf(context);
    if (overlayEntry.mounted && currentOverlay != null) {
      try {
        overlayEntry.remove();
      } catch (e) {
        // Ignorar erro se o overlay já foi removido
      }
    }
  });
}

class _CustomToast extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Widget icon;
  final VoidCallback onDismiss;

  const _CustomToast({
    required this.message,
    required this.backgroundColor,
    required this.icon,
    required this.onDismiss,
  });

  @override
  State<_CustomToast> createState() => _CustomToastState();
}

class _CustomToastState extends State<_CustomToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Começa da direita
      end: Offset.zero, // Termina na posição final
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    // Inicia a animação de saída antes de remover
    Future.delayed(const Duration(seconds: 2, milliseconds: 700), () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            widget.onDismiss();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.icon,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

