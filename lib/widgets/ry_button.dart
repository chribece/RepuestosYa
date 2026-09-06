import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum RyButtonVariant { primary, secondary, outline, text, danger }

enum RyButtonSize { small, medium, large }

class RyButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final RyButtonVariant variant;
  final RyButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final bool isFullWidth;
  final VoidCallback? onPressed;
  final Widget? customChild;

  const RyButton({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    this.variant = RyButtonVariant.primary,
    this.size = RyButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.isFullWidth = false,
    this.onPressed,
    this.customChild,
  });

  double _getHeight() {
    switch (size) {
      case RyButtonSize.small:
        return 48.0; // 48 dp mínimos WCAG 2.5.5 (era 40)
      case RyButtonSize.medium:
        return 48.0;
      case RyButtonSize.large:
        return 56.0;
    }
  }

  Color _getBackgroundColor(BuildContext context) {
    switch (variant) {
      case RyButtonVariant.primary:
        return SemanticColors.colorPrimaryButton;
      case RyButtonVariant.secondary:
        return SemanticColors.colorSecondaryButton;
      case RyButtonVariant.outline:
        return Colors.transparent;
      case RyButtonVariant.text:
        return Colors.transparent;
      case RyButtonVariant.danger:
        return SemanticColors.colorErrorBackground;
    }
  }

  Color _getForegroundColor(BuildContext context) {
    switch (variant) {
      case RyButtonVariant.primary:
        return SemanticColors.colorOnPrimaryButton;
      case RyButtonVariant.secondary:
        return SemanticColors.colorOnSecondaryButton;
      case RyButtonVariant.outline:
        return SemanticColors.colorOnSurface;
      case RyButtonVariant.text:
        return SemanticColors.colorOnSurface;
      case RyButtonVariant.danger:
        return SemanticColors.colorOnErrorText;
    }
  }

  Color _getDisabledBackgroundColor(BuildContext context) {
    switch (variant) {
      case RyButtonVariant.primary:
      case RyButtonVariant.secondary:
      case RyButtonVariant.danger:
        return AppColors.surfaceVariant;
      case RyButtonVariant.outline:
      case RyButtonVariant.text:
        return Colors.transparent;
    }
  }

  Color _getDisabledForegroundColor(BuildContext context) {
    return AppColors.onSurfaceVariant.withValues(alpha: 0.5);
  }

  BorderSide? _getBorderSide(BuildContext context) {
    switch (variant) {
      case RyButtonVariant.outline:
        return const BorderSide(color: AppColors.outlineVariant);
      case RyButtonVariant.primary:
      case RyButtonVariant.secondary:
      case RyButtonVariant.text:
      case RyButtonVariant.danger:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEffectiveDisabled = isDisabled || isLoading;
    final backgroundColor = isEffectiveDisabled
        ? _getDisabledBackgroundColor(context)
        : _getBackgroundColor(context);
    final foregroundColor = isEffectiveDisabled
        ? _getDisabledForegroundColor(context)
        : _getForegroundColor(context);
    final borderSide = _getBorderSide(context);

    Widget content;
    if (isLoading) {
      content = SizedBox(
        height: _getHeight() * 0.5,
        width: _getHeight() * 0.5,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    } else if (customChild != null) {
      content = customChild!;
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: AppSpacing.spacingSm),
          ],
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.textStyleButton.copyWith(
                color: foregroundColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: AppSpacing.spacingSm),
            Icon(trailingIcon, size: 20),
          ],
        ],
      );
    }

    return Semantics(
      button: true,
      enabled: !isEffectiveDisabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        child: InkWell(
          onTap: isEffectiveDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          splashColor: foregroundColor.withValues(alpha: 0.1),
          highlightColor: foregroundColor.withValues(alpha: 0.05),
          child: Container(
            height: _getHeight(),
            width: isFullWidth ? double.infinity : null,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spacingLg,
            ),
            decoration: BoxDecoration(
              border: borderSide != null
                  ? Border.fromBorderSide(borderSide)
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            ),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}
