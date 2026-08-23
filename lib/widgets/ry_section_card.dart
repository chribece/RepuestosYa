import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Tarjeta contenedora de sección con título, icono y contenido delegado.
///
/// Se usa en pantallas que agrupan campos o información en bloques visuales
/// con un encabezado consistente (icono + título). Extraída del helper
/// `_buildSectionCard` de `perfil_almacen_page.dart` para reutilización
/// en cualquier pantalla que necesite agrupar contenido.
///
/// **Patrón visual que resuelve:** tarjeta con `surfaceContainerHigh` +
/// `outlineVariant` + `radiusLg`, encabezado con icono + título, y cuerpo
/// de contenido delegado. Aparece en Perfil Almacén, Perfil Cliente,
/// Detalle Orden, Dashboard.
class RySectionCard extends StatelessWidget {
  /// Título de la sección mostrado junto al icono.
  final String title;

  /// Icono que acompaña el título. Si es `null`, solo se muestra el título.
  final IconData? icon;

  /// Contenido de la sección (campos, texto, widgets arbitrarios).
  final List<Widget> children;

  /// Color del icono. Por defecto usa `AppColors.primaryContainer`.
  final Color? iconColor;

  const RySectionCard({
    super.key,
    required this.title,
    this.icon,
    required this.children,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Sección: $title',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          border: Border.all(color: AppColors.outlineVariant, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: iconColor ?? AppColors.primaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.spacingSm),
                ],
                Text(title, style: AppTextStyles.textStyleTitle),
              ],
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            ...children,
          ],
        ),
      ),
    );
  }
}
