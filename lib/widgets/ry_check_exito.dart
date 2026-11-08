import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Check de éxito con entrada elástica y resplandor verde que se atenúa hasta
/// un halo estático. Con "reducir movimiento" activo se muestra en su estado
/// final sin animar.
class RyCheckExito extends StatefulWidget {
  const RyCheckExito({super.key});

  @override
  State<RyCheckExito> createState() => _RyCheckExitoState();
}

class _RyCheckExitoState extends State<RyCheckExito>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  late final Animation<double> _escala = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
  );
  late final Animation<double> _resplandor = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _resplandor.value;
        return Transform.scale(
          scale: 0.6 + 0.4 * _escala.value,
          child: Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.45 - 0.27 * t),
                  blurRadius: 4 + 22 * t,
                  spreadRadius: 10 * t,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: const Icon(
        Icons.check_circle_rounded,
        color: AppColors.success,
        size: 72,
      ),
    );
  }
}
