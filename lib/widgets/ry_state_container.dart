import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum RyStateType { empty, error, loading, success, network }

class RyStateContainer extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final RyStateType type;
  final IconData? customIcon;
  final Color? customIconColor;
  final VoidCallback? onAction;
  final Widget? customContent;

  const RyStateContainer({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    required this.type,
    this.customIcon,
    this.customIconColor,
    this.onAction,
    this.customContent,
  });

  IconData _getIcon() {
    if (customIcon != null) return customIcon!;

    switch (type) {
      case RyStateType.empty:
        return Icons.inbox_outlined;
      case RyStateType.error:
        return Icons.error_outline;
      case RyStateType.loading:
        return Icons.hourglass_empty;
      case RyStateType.success:
        return Icons.check_circle_outline;
      case RyStateType.network:
        return Icons.wifi_off;
    }
  }

  Color _getIconColor() {
    switch (type) {
      case RyStateType.empty:
        return AppColors.primaryContainer;
      case RyStateType.error:
        return SemanticColors.colorErrorBackground;
      case RyStateType.loading:
        return AppColors.primaryContainer;
      case RyStateType.success:
        return SemanticColors.colorSuccess;
      case RyStateType.network:
        return SemanticColors.colorWarning;
    }
  }

  /// Estado vacío: ícono dentro de una tarjeta naranja sutil (76x76) para dar
  /// foco visual; el resto de tipos conserva el ícono suelto.
  Widget _buildIcon(IconData icon, Color color) {
    if (type != RyStateType.empty) return Icon(icon, size: 64, color: color);
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.10),
            blurRadius: 24,
          ),
        ],
      ),
      child: Icon(icon, size: 36, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = _getIcon();
    final iconColor = customIconColor ?? _getIconColor();

    if (type == RyStateType.loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              ),
            ),
            if (title.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.spacingMd),
              Text(
                title,
                style: AppTextStyles.textStyleBody.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.spacingXs),
              Text(
                subtitle!,
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.spacingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIcon(icon, iconColor),
            const SizedBox(height: AppSpacing.spacingLg),
            Text(
              title,
              style: AppTextStyles.textStyleTitle,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.spacingSm),
              Text(
                subtitle!,
                style: AppTextStyles.textStyleBody.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (customContent != null) ...[
              const SizedBox(height: AppSpacing.spacingMd),
              customContent!,
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.spacingLg),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
