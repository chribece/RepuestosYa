import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Ítem de navegación del [RyNavDrawer].
class RyNavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Indica si la opción corresponde a la pantalla actual.
  final bool selected;

  const RyNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
}

/// Menú lateral del panel de almacén.
///
/// Cabecera con avatar y subtítulo dinámico (rol o nombre del
/// establecimiento), lista de opciones con fondo redondeado para la opción
/// seleccionada, y "Cerrar Sesión" separado en un contenedor de alerta.
/// Las acciones de cada ítem son responsables de cerrar el drawer.
class RyNavDrawer extends StatelessWidget {
  final String subtitle;

  /// URL de imagen (logo del establecimiento o avatar del usuario).
  final String? imageUrl;

  /// Nombre usado para derivar las iniciales cuando no hay imagen.
  final String? name;

  /// Icono de respaldo cuando no hay imagen ni iniciales.
  final IconData fallbackIcon;

  final List<RyNavItem> items;
  final VoidCallback onLogout;

  const RyNavDrawer({
    super.key,
    required this.subtitle,
    this.imageUrl,
    this.name,
    this.fallbackIcon = Icons.store,
    required this.items,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.spacingSm),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spacingXs,
                ),
                children: [for (final item in items) _buildItem(item)],
              ),
            ),
            const Divider(
              height: 1,
              indent: AppSpacing.spacingMd,
              endIndent: AppSpacing.spacingMd,
              color: AppColors.outlineVariant,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.spacingMd),
              child: _buildLogout(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.spacingLg,
        AppSpacing.spacingLg,
        AppSpacing.spacingLg,
        AppSpacing.spacingMd,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: AppSpacing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'RepuestosYa',
                  style: AppTextStyles.textStyleTitle.copyWith(
                    color: AppColors.primaryContainer,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingXxs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.textStyleCaption.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final url = imageUrl?.trim();
    final fallback = _buildAvatarFallback();
    return CircleAvatar(
      key: const ValueKey('ry-nav-drawer-avatar'),
      radius: 24,
      backgroundColor: AppColors.surfaceVariant,
      child: ClipOval(
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              )
            : fallback,
      ),
    );
  }

  Widget _buildAvatarFallback() {
    final initials = _initials(name);
    if (initials.isEmpty) {
      return Icon(fallbackIcon, color: AppColors.primaryContainer, size: 24);
    }
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      color: AppColors.primaryContainer.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: AppTextStyles.textStyleTitle.copyWith(
          color: AppColors.primaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _initials(String? value) {
    final words = (value ?? '').trim().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  Widget _buildItem(RyNavItem item) {
    final radius = BorderRadius.circular(AppRadius.radiusMd);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: item.selected
            ? AppColors.primaryContainer.withValues(alpha: 0.12)
            : AppColors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spacingMd,
              vertical: 14,
            ),
            child: Row(
              children: [
                Icon(item.icon, color: AppColors.primaryContainer),
                const SizedBox(width: AppSpacing.spacingSm),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTextStyles.textStyleBody.copyWith(
                      fontWeight: item.selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: item.selected
                          ? AppColors.primaryContainer
                          : AppColors.onSurface,
                    ),
                  ),
                ),
                if (item.selected)
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogout() {
    final radius = BorderRadius.circular(AppRadius.radiusMd);
    return Material(
      color: AppColors.error.withValues(alpha: 0.12),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onLogout,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spacingMd,
            vertical: 14,
          ),
          child: Row(
            children: [
              const Icon(Icons.logout, color: SemanticColors.colorErrorText),
              const SizedBox(width: AppSpacing.spacingSm),
              Text(
                'Cerrar Sesión',
                style: AppTextStyles.textStyleBody.copyWith(
                  color: SemanticColors.colorErrorText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
