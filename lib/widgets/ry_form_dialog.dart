import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Responsive dialog shell shared by compact forms with fixed actions.
class RyFormDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final Color backgroundColor;

  const RyFormDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.backgroundColor = AppColors.surfaceContainerHigh,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = math.max(
      0.0,
      media.size.height -
          media.viewInsets.bottom -
          media.viewPadding.vertical -
          AppSpacing.spacingXl,
    );

    return Dialog(
      backgroundColor: backgroundColor,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spacingMd,
        vertical: AppSpacing.spacingMd,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
      ),
      child: ConstrainedBox(
        key: const ValueKey('ry-form-dialog-panel'),
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.spacingLg,
                AppSpacing.spacingMd,
                AppSpacing.spacingLg,
                AppSpacing.spacingSm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: AppTextStyles.textStyleTitle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                key: const ValueKey('ry-form-dialog-scroll'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spacingLg,
                  vertical: AppSpacing.spacingSm,
                ),
                child: content,
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.spacingMd,
                  AppSpacing.spacingXs,
                  AppSpacing.spacingMd,
                  AppSpacing.spacingSm,
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.spacingXs,
                  runSpacing: AppSpacing.spacingXs,
                  children: actions,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
