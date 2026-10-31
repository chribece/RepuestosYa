import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class EcuadorPhonePrefix extends StatelessWidget {
  const EcuadorPhonePrefix({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Código telefónico de Ecuador, más 593',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spacingXs,
              vertical: AppSpacing.spacingXxs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              border: Border.all(color: Colors.white24),
            ),
            child: Text(
              '+593',
              style: AppTextStyles.textStyleSmall.copyWith(
                color: AppColors.onSurface,
                letterSpacing: 0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.spacingSm),
          Container(width: 1, height: 24, color: Colors.white24),
          const SizedBox(width: AppSpacing.spacingXxs),
        ],
      ),
    );
  }
}
