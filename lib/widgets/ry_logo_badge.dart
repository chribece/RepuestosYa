import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class RyLogoBadge extends StatelessWidget {
  const RyLogoBadge({super.key, this.size = 130});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppColors.background,
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.2),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset(
          'assets/images/logo-sinfondo.png',
          fit: BoxFit.contain,
          semanticLabel: 'Logo de RepuestosYa',
        ),
      ),
    );
  }
}
