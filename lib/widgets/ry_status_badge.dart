import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum RyStatusBadgeStyle { filled, outlined, subtle }

enum RyStatusBadgeSize { small, medium, large }

class RyStatusBadge extends StatelessWidget {
  final String status;
  final String? customLabel;
  final RyStatusBadgeStyle style;
  final RyStatusBadgeSize size;
  final Color? customColor;

  const RyStatusBadge({
    super.key,
    required this.status,
    this.customLabel,
    this.style = RyStatusBadgeStyle.filled,
    this.size = RyStatusBadgeSize.medium,
    this.customColor,
  });

  String _getLabel() {
    if (customLabel != null) return customLabel!;

    // Mapeo de estados a etiquetas legibles
    final lowerStatus = status.toLowerCase();
    switch (lowerStatus) {
      case 'pendiente':
      case 'pending':
        return 'Pendiente';
      case 'en_proceso':
      case 'in_progress':
        return 'En proceso';
      case 'completado':
      case 'completed':
        return 'Completado';
      case 'cancelado':
      case 'cancelled':
        return 'Cancelado';
      case 'rechazado':
      case 'rejected':
        return 'Rechazado';
      case 'aceptado':
      case 'accepted':
        return 'Aceptado';
      case 'enviado':
      case 'sent':
        return 'Enviado';
      case 'entregado':
      case 'delivered':
        return 'Entregado';
      case 'cotizado':
      case 'quoted':
        return 'Cotizado';
      case 'activo':
      case 'active':
        return 'Activo';
      case 'inactivo':
      case 'inactive':
        return 'Inactivo';
      case 'urgente':
      case 'urgent':
        return 'Urgente';
      case 'estandar':
      case 'standard':
        return 'Estándar';
      case 'error':
      case 'fallido':
        return 'Error';
      case 'info':
        return 'Información';
      default:
        return status;
    }
  }

  Color _getStatusColor() {
    if (customColor != null) return customColor!;

    final lowerStatus = status.toLowerCase();
    switch (lowerStatus) {
      case 'pendiente':
      case 'pending':
        return SemanticColors.colorWarning;
      case 'en_proceso':
      case 'in_progress':
        return SemanticColors.colorInfo;
      case 'completado':
      case 'completed':
      case 'entregado':
      case 'delivered':
      case 'aceptado':
      case 'accepted':
        return SemanticColors.colorSuccess;
      case 'cancelado':
      case 'cancelled':
      case 'rechazado':
      case 'rejected':
        return SemanticColors.colorErrorBackground;
      case 'enviado':
      case 'sent':
      case 'cotizado':
      case 'quoted':
        return SemanticColors.colorInfo;
      case 'activo':
      case 'active':
        return SemanticColors.colorSuccess;
      case 'inactivo':
      case 'inactive':
        return AppColors.onSurfaceVariant;
      case 'urgente':
      case 'urgent':
        return SemanticColors.colorErrorBackground;
      case 'estandar':
      case 'standard':
        return AppColors.onSurfaceVariant;
      case 'error':
      case 'fallido':
        return SemanticColors.colorErrorBackground;
      case 'info':
        return SemanticColors.colorInfo;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  Color _getBackgroundColor(BuildContext context) {
    final statusColor = _getStatusColor();
    switch (style) {
      case RyStatusBadgeStyle.filled:
        return statusColor.withValues(alpha: 0.15);
      case RyStatusBadgeStyle.outlined:
        return Colors.transparent;
      case RyStatusBadgeStyle.subtle:
        return statusColor.withValues(alpha: 0.08);
    }
  }

  Color _getTextColor() {
    // El color base del estado se usa para fondo (alpha) y borde; para el
    // texto se usan variantes más claras cuando el base no alcanza 4.5:1
    // sobre el fondo sutil del badge (caso error e info). Ver §8.4 del
    // DESIGN_SYSTEM.md.
    final lowerStatus = status.toLowerCase();
    switch (lowerStatus) {
      case 'cancelado':
      case 'cancelled':
      case 'rechazado':
      case 'rejected':
      case 'urgente':
      case 'urgent':
      case 'error':
      case 'fallido':
        return SemanticColors.colorErrorText; // #FF6B7A → AA normal
      case 'en_proceso':
      case 'in_progress':
      case 'enviado':
      case 'sent':
      case 'cotizado':
      case 'quoted':
      case 'info':
        return SemanticColors.colorInfoBadgeText; // #4DA8F5 → AA normal
      default:
        return _getStatusColor();
    }
  }

  BorderSide? _getBorderSide() {
    final statusColor = _getStatusColor();
    switch (style) {
      case RyStatusBadgeStyle.filled:
      case RyStatusBadgeStyle.subtle:
        return null;
      case RyStatusBadgeStyle.outlined:
        return BorderSide(color: statusColor);
    }
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case RyStatusBadgeSize.small:
        return AppTextStyles.textStyleSmall;
      case RyStatusBadgeSize.medium:
        return AppTextStyles.textStyleCaption;
      case RyStatusBadgeSize.large:
        return AppTextStyles.textStyleBody;
    }
  }

  double _getPadding() {
    switch (size) {
      case RyStatusBadgeSize.small:
        return AppSpacing.spacingXs;
      case RyStatusBadgeSize.medium:
        return AppSpacing.spacingSm;
      case RyStatusBadgeSize.large:
        return AppSpacing.spacingMd;
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor(context);
    final textColor = _getTextColor();
    final borderSide = _getBorderSide();
    final textStyle = _getTextStyle();
    final padding = _getPadding();
    final label = _getLabel();

    // Semantics con label "Estado: <texto>" para que TalkBack/VoiceOver
    // anuncien el rol informativo del badge en lugar de leer sólo el
    // texto aislado. excludeSemantics evita doble lectura del Text hijo.
    return Semantics(
      label: 'Estado: $label',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: padding,
          vertical: padding * 0.5,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: borderSide != null ? Border.fromBorderSide(borderSide) : null,
          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        ),
        child: Text(label, style: textStyle.copyWith(color: textColor)),
      ),
    );
  }
}
