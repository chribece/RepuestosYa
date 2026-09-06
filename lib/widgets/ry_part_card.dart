import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'ry_status_badge.dart';
import 'ry_button.dart';

enum RyPartCardVariant { client, warehouse, compact }

class RyPartCard extends StatelessWidget {
  final String partName;
  final String? imageUrl;
  final String? vehicleInfo;
  final String? description;
  final String status;
  final String? price;
  final String? location;
  final DateTime createdAt;
  final RyPartCardVariant variant;
  final bool showImage;
  final bool showPrice;
  final bool showStatus;
  final bool isCompact;
  final bool isSynced;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onStatusTap;
  final VoidCallback? onQuoteTap;
  final Widget? customActions;
  final Widget? customFooter;

  const RyPartCard({
    super.key,
    required this.partName,
    this.imageUrl,
    this.vehicleInfo,
    this.description,
    required this.status,
    this.price,
    this.location,
    required this.createdAt,
    this.variant = RyPartCardVariant.client,
    this.showImage = true,
    this.showPrice = true,
    this.showStatus = true,
    this.isCompact = false,
    this.isSynced = true,
    this.onTap,
    this.onLongPress,
    this.onStatusTap,
    this.onQuoteTap,
    this.customActions,
    this.customFooter,
  });

  /// Las páginas resuelven la imagen con `solicitud['image_url'] ?? ''`, así que
  /// una cadena vacía significa "sin imagen" y no debe llegar a la red.
  bool get _hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Hace ${difference.inMinutes} min';
      }
      return 'Hace ${difference.inHours} h';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Construye el badge de estado como elemento accionable cuando
  /// `onStatusTap != null`. Garantiza área táctil ≥48×48 dp (WCAG 2.5.5)
  /// y expone `Semantics(button:, label: 'Estado: …')` para TalkBack.
  Widget _buildStatusAction() {
    return Semantics(
      button: onStatusTap != null,
      label: 'Estado: $status',
      onTap: onStatusTap,
      child: InkWell(
        onTap: onStatusTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        child: Padding(
          // padding vertical extra para asegurar 48 dp de alto cuando el
          // badge es pequeño (size small/medium mide ~24-30 dp).
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spacingXs,
            vertical: AppSpacing.spacingXs,
          ),
          child: RyStatusBadge(status: status),
        ),
      ),
    );
  }

  Widget _buildImage(double width, double height, {double? borderRadius}) {
    final bool isLocal = imageUrl?.startsWith('file://') ?? false;
    final radius = borderRadius ?? AppRadius.radiusMd;

    Widget imageWidget;
    if (isLocal) {
      final path = imageUrl!.replaceFirst('file://', '');
      imageWidget = Image.file(
        File(path),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildPlaceholder(width, height),
      );
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(width, height),
        errorWidget: (context, url, error) =>
            _buildPlaceholder(width, height, isError: true),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: imageWidget,
    );
  }

  Widget _buildPlaceholder(
    double width,
    double height, {
    bool isError = false,
  }) {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceVariant,
      child: Icon(
        isError ? Icons.broken_image : Icons.image,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveVariant = isCompact ? RyPartCardVariant.compact : variant;

    return Semantics(
      button: onTap != null,
      label:
          'Tarjeta de repuesto: $partName, estado: $status'
          '${vehicleInfo != null ? ', vehículo: $vehicleInfo' : ''}',
      onTap: onTap,
      // excludeSemantics evita que los hijos (imagen, texto, badge) se
      // anuncien por separado y dupliquen la información ya contenida en
      // el label de la tarjeta.
      excludeSemantics: true,
      child: Material(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            child: _buildContent(effectiveVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(RyPartCardVariant variant) {
    switch (variant) {
      case RyPartCardVariant.compact:
        return _buildCompactContent();
      case RyPartCardVariant.client:
        return _buildClientContent();
      case RyPartCardVariant.warehouse:
        return _buildWarehouseContent();
    }
  }

  Widget _buildCompactContent() {
    return Row(
      children: [
        if (showImage && _hasImage) ...[
          Semantics(
            image: true,
            label: 'Imagen del repuesto $partName',
            excludeSemantics: true,
            child: _buildImage(60, 60, borderRadius: AppRadius.radiusSm),
          ),
          const SizedBox(width: AppSpacing.spacingMd),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                partName,
                style: AppTextStyles.textStyleTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (vehicleInfo != null) ...[
                const SizedBox(height: AppSpacing.spacingXxs),
                Text(
                  vehicleInfo!,
                  style: AppTextStyles.textStyleCaption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (showStatus) ...[
                const SizedBox(height: AppSpacing.spacingXs),
                RyStatusBadge(status: status, size: RyStatusBadgeSize.small),
              ],
            ],
          ),
        ),
        if (customActions != null) ...[
          const SizedBox(width: AppSpacing.spacingMd),
          customActions!,
        ],
      ],
    );
  }

  Widget _buildClientContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (showImage && _hasImage) ...[
              Semantics(
                image: true,
                label: 'Imagen del repuesto $partName',
                excludeSemantics: true,
                child: _buildImage(80, 80),
              ),
              const SizedBox(width: AppSpacing.spacingMd),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partName,
                    style: AppTextStyles.textStyleTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (vehicleInfo != null) ...[
                    const SizedBox(height: AppSpacing.spacingXxs),
                    Text(vehicleInfo!, style: AppTextStyles.textStyleCaption),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.spacingSm),
          Text(
            description!,
            style: AppTextStyles.textStyleBody,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: AppSpacing.spacingSm),
        Row(
          children: [
            if (showStatus) ...[
              _buildStatusAction(),
              const SizedBox(width: AppSpacing.spacingSm),
            ],
            if (!isSynced) ...[
              const Icon(Icons.sync_problem, size: 16, color: Colors.orange),
              const SizedBox(width: AppSpacing.spacingXxs),
              Text(
                'Pendiente de envío',
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: AppSpacing.spacingSm),
            ],
            const Spacer(),
            Text(_formatDate(createdAt), style: AppTextStyles.textStyleSmall),
          ],
        ),
        if (showPrice && price != null) ...[
          const SizedBox(height: AppSpacing.spacingSm),
          Text(
            price!,
            style: AppTextStyles.textStyleTitle.copyWith(
              color: SemanticColors.colorSuccess,
            ),
          ),
        ],
        if (customFooter != null) ...[
          const SizedBox(height: AppSpacing.spacingSm),
          customFooter!,
        ],
      ],
    );
  }

  Widget _buildWarehouseContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (showImage && _hasImage) ...[
              Semantics(
                image: true,
                label: 'Imagen del repuesto $partName',
                excludeSemantics: true,
                child: _buildImage(80, 80),
              ),
              const SizedBox(width: AppSpacing.spacingMd),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partName,
                    style: AppTextStyles.textStyleTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (vehicleInfo != null) ...[
                    const SizedBox(height: AppSpacing.spacingXxs),
                    Text(vehicleInfo!, style: AppTextStyles.textStyleCaption),
                  ],
                  if (location != null) ...[
                    const SizedBox(height: AppSpacing.spacingXxs),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.spacingXxs),
                        Expanded(
                          child: Text(
                            location!,
                            style: AppTextStyles.textStyleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.spacingSm),
          Text(
            description!,
            style: AppTextStyles.textStyleBody,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: AppSpacing.spacingSm),
        Row(
          children: [
            if (showStatus) ...[
              _buildStatusAction(),
              const SizedBox(width: AppSpacing.spacingSm),
            ],
            if (!isSynced) ...[
              const Icon(Icons.sync_problem, size: 16, color: Colors.orange),
              const SizedBox(width: AppSpacing.spacingXxs),
              Text(
                'Pendiente de envío',
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: AppSpacing.spacingSm),
            ],
            const Spacer(),
            Text(_formatDate(createdAt), style: AppTextStyles.textStyleSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        if (customActions != null)
          customActions!
        else if (onQuoteTap != null)
          RyButton(
            label: 'Cotizar',
            variant: RyButtonVariant.secondary,
            size: RyButtonSize.small,
            onPressed: onQuoteTap,
          ),
        if (customFooter != null) ...[
          const SizedBox(height: AppSpacing.spacingSm),
          customFooter!,
        ],
      ],
    );
  }
}
