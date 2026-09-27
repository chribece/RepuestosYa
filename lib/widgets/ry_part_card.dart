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

class RyAdditionalPart {
  final String name;
  final String quantity;
  final String? detail;

  const RyAdditionalPart({
    required this.name,
    required this.quantity,
    this.detail,
  });
}

class RyAdditionalPartsList extends StatelessWidget {
  final String? summary;

  const RyAdditionalPartsList({super.key, required this.summary});

  static const _summaryHeaders = [
    'Repuestos adicionales:',
    'Piezas adicionales solicitadas:',
  ];

  static List<RyAdditionalPart> parse(String? value) {
    if (value == null || value.trim().isEmpty) return const [];

    final lines = value.split('\n');
    final parts = <RyAdditionalPart>[];
    RyAdditionalPart? currentPart;
    String? currentDetail;
    var readingParts = false;
    final partPattern = RegExp(
      r'^\d+\.\s*Categoría:\s*(.*?)\s*\|\s*Repuesto:\s*(.*?)\s*\|\s*Cantidad:\s*(.*?)\s*$',
    );

    void saveCurrentPart() {
      if (currentPart != null) {
        parts.add(
          RyAdditionalPart(
            name: currentPart!.name,
            quantity: currentPart!.quantity,
            detail: currentDetail,
          ),
        );
      }
      currentPart = null;
      currentDetail = null;
    }

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (_summaryHeaders.contains(line)) {
        saveCurrentPart();
        readingParts = true;
        continue;
      }
      if (!readingParts) continue;

      final match = partPattern.firstMatch(line);
      if (match != null) {
        saveCurrentPart();
        currentPart = RyAdditionalPart(
          name: match.group(2)!.trim(),
          quantity: match.group(3)!.trim(),
        );
      } else if (line.startsWith('Detalle:') && currentPart != null) {
        currentDetail = line.substring('Detalle:'.length).trim();
      }
    }
    saveCurrentPart();
    return parts;
  }

  static String mainDescription(String? value) {
    if (value == null) return '';
    final lines = value.split('\n');
    final headerIndex = lines.indexWhere(_summaryHeaders.contains);
    if (headerIndex < 0) return value.trim();
    return lines.take(headerIndex).join('\n').trim();
  }

  @override
  Widget build(BuildContext context) {
    final parts = parse(summary);
    if (parts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repuestos adicionales',
          style: AppTextStyles.textStyleCaption.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        ...parts.map(
          (part) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.spacingXs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.build_outlined,
                    size: 18,
                    color: AppColors.primaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingXs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${part.name} (Cant: ${part.quantity})',
                        style: AppTextStyles.textStyleBody.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (part.detail != null && part.detail!.isNotEmpty)
                        Text(
                          part.detail!,
                          style: AppTextStyles.textStyleCaption.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class RyPartCard extends StatelessWidget {
  final String partName;
  final String? imageUrl;
  final String? vehicleInfo;
  final String? description;
  final String? additionalPartsSummary;
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
    this.additionalPartsSummary,
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

  Widget _buildImage(
    double width,
    double height, {
    double? borderRadius,
    required double devicePixelRatio,
  }) {
    final bool isLocal = imageUrl?.startsWith('file://') ?? false;
    final radius = borderRadius ?? AppRadius.radiusMd;

    // Fase 7: decodificar el thumbnail al tamaño real en pantalla
    // (cacheWidth/cacheHeight) en lugar de la resolución completa de la
    // foto — evita el pico del raster thread al subir imágenes gigantes a
    // la GPU solo para mostrarlas en 60-80 dp.
    final cacheWidth = (width * devicePixelRatio).round();
    final cacheHeight = (height * devicePixelRatio).round();

    Widget imageWidget;
    if (isLocal) {
      final path = imageUrl!.replaceFirst('file://', '');
      imageWidget = Image.file(
        File(path),
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildPlaceholder(width, height),
      );
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        // cached_network_image usa memCacheWidth/Height (decodificación a
        // thumbnail) en lugar de cacheWidth/Height de Image.
        memCacheWidth: cacheWidth,
        memCacheHeight: cacheHeight,
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
    // DPR del dispositivo para decodificar thumbnails al tamaño real de
    // pantalla (cacheWidth/cacheHeight) en lugar de la resolución completa.
    final double dpr = MediaQuery.devicePixelRatioOf(context);

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
            child: _buildContent(effectiveVariant, dpr),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(RyPartCardVariant variant, double dpr) {
    switch (variant) {
      case RyPartCardVariant.compact:
        return _buildCompactContent(dpr);
      case RyPartCardVariant.client:
        return _buildClientContent(dpr);
      case RyPartCardVariant.warehouse:
        return _buildWarehouseContent(dpr);
    }
  }

  Widget _buildCompactContent(double dpr) {
    return Row(
      children: [
        if (showImage && _hasImage) ...[
          Semantics(
            image: true,
            label: 'Imagen del repuesto $partName',
            excludeSemantics: true,
            child: _buildImage(
              60,
              60,
              borderRadius: AppRadius.radiusSm,
              devicePixelRatio: dpr,
            ),
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

  Widget _buildDescriptionContent() {
    final summary = additionalPartsSummary ?? description;
    final String? mainDescription = additionalPartsSummary == null
        ? RyAdditionalPartsList.mainDescription(description)
        : description;
    final hasMainDescription =
        mainDescription != null && mainDescription.trim().isNotEmpty;
    final hasAdditionalParts = RyAdditionalPartsList.parse(summary).isNotEmpty;

    if (!hasMainDescription && !hasAdditionalParts) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasMainDescription)
          Text(
            mainDescription,
            style: AppTextStyles.textStyleBody,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (hasAdditionalParts) ...[
          if (hasMainDescription) const SizedBox(height: AppSpacing.spacingSm),
          RyAdditionalPartsList(summary: summary),
        ],
      ],
    );
  }

  Widget _buildClientContent(double dpr) {
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
                child: _buildImage(80, 80, devicePixelRatio: dpr),
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
        if ((description != null && description!.trim().isNotEmpty) ||
            RyAdditionalPartsList.parse(
              additionalPartsSummary ?? description,
            ).isNotEmpty) ...[
          const SizedBox(height: AppSpacing.spacingSm),
          _buildDescriptionContent(),
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
            Text(
              _formatDate(createdAt),
              style: AppTextStyles.textStyleSmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
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

  Widget _buildWarehouseContent(double dpr) {
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
                child: _buildImage(80, 80, devicePixelRatio: dpr),
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
        if ((description != null && description!.trim().isNotEmpty) ||
            RyAdditionalPartsList.parse(
              additionalPartsSummary ?? description,
            ).isNotEmpty) ...[
          const SizedBox(height: AppSpacing.spacingSm),
          _buildDescriptionContent(),
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
            Text(
              _formatDate(createdAt),
              style: AppTextStyles.textStyleSmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
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
