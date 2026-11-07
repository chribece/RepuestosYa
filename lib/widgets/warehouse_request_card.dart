import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/solicitud_service.dart';
import '../utils/business_rules.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import 'ry_button.dart';
import 'ry_part_card.dart';

/// Tarjeta de una solicitud disponible para el almacén. La comparten el
/// panel principal (vista previa) y la lista completa de solicitudes.
class WarehouseRequestCard extends StatelessWidget {
  const WarehouseRequestCard({
    super.key,
    required this.solicitud,
    required this.onCotizar,
  });

  final Map<String, dynamic> solicitud;
  final VoidCallback onCotizar;

  @override
  Widget build(BuildContext context) {
    // Extracción e indexación segura de datos relacionales anidados (Vehículos)
    final solicitudObj = Solicitud(solicitud);
    final String title = solicitudObj.displayPartName;

    // Extraer nombre del cliente
    final profiles = solicitud['profiles'] as Map<String, dynamic>?;
    final String clienteNombre =
        profiles?['nombre_completo'] ?? 'Cliente desconocido';

    // Armar el subtítulo dinámico con datos de la marca, modelo y año del vehículo
    final vehiculo = solicitud['vehiculos_cliente'];
    final modelo = vehiculo != null ? vehiculo['modelos_vehiculo'] : null;
    final marca = modelo != null ? modelo['marcas_vehiculo'] : null;

    String detallesVehiculo = 'Vehículo no especificado';
    if (marca != null && modelo != null) {
      // Solo se unen los datos no vacíos: así el separador " • " no queda
      // colgando al final si el año (último dato) no existe.
      final partes = [
        '${marca['nombre'] ?? ''} ${modelo['nombre'] ?? ''}'.trim(),
        '${vehiculo['año'] ?? ''}'.trim(),
      ].where((p) => p.isNotEmpty);
      final texto = partes.join(' • ');
      if (texto.isNotEmpty) detallesVehiculo = texto;
    }

    final String? distance = formatearDistanciaKm(solicitud['distancia_km']);

    // Calcular tiempo real desde created_at
    final createdAt = solicitud['created_at'];

    // Validamos el tag correcto desde la columna 'es_urgente' del backend en Node
    final bool esUrgente = solicitud['es_urgente'] == true;

    // Extraer cantidad de cotizaciones (lazy loading)
    final cotizaciones = solicitud['cotizaciones'];
    final int cantidadCotizaciones =
        (cotizaciones is List && cotizaciones.isNotEmpty)
        ? (cotizaciones.first['count'] ?? 0)
        : 0;

    final String imageUrl =
        solicitud['image_url'] ?? solicitud['foto_url'] ?? '';

    return RyPartCard(
      partName: title,
      imageUrl: imageUrl,
      vehicleInfo: detallesVehiculo,
      description: 'Cliente: $clienteNombre',
      additionalPartsSummary: solicitudObj.descripcionProblema,
      location: distance,
      status: esUrgente ? 'urgente' : 'estandar',
      createdAt: DateTime.tryParse('$createdAt') ?? DateTime.now(),
      variant: RyPartCardVariant.warehouse,
      showPrice: false,
      showStatus: false,
      customActions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (esUrgente) ...[
                _buildUrgencyChip(),
                const SizedBox(width: AppSpacing.spacingSm),
              ],
              Flexible(child: _buildQuotationsCountChip(cantidadCotizaciones)),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          RyButton(
            label: 'COTIZAR',
            variant: RyButtonVariant.primary,
            size: RyButtonSize.small,
            isFullWidth: true,
            horizontalPadding: AppSpacing.spacingMd,
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: onCotizar,
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencyChip() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spacingSm,
        vertical: AppSpacing.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bolt_rounded,
            size: 14,
            color: AppColors.primaryContainer,
          ),
          const SizedBox(width: AppSpacing.spacingXxs),
          Text(
            'Urgente',
            style: AppTextStyles.textStyleSmall.copyWith(
              color: AppColors.primaryContainer,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  /// Chip informativo con el número de cotizaciones recibidas por la solicitud.
  Widget _buildQuotationsCountChip(int cantidadCotizaciones) {
    final bool tieneCotizaciones = cantidadCotizaciones > 0;
    final Color accent = tieneCotizaciones
        ? AppColors.primaryContainer
        : AppColors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spacingSm,
        vertical: AppSpacing.spacingXs,
      ),
      decoration: BoxDecoration(
        color: tieneCotizaciones
            ? AppColors.primaryContainer.withValues(alpha: 0.1)
            : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        border: Border.all(
          color: tieneCotizaciones
              ? AppColors.primaryContainer.withValues(alpha: 0.3)
              : AppColors.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tieneCotizaciones
                ? Icons.receipt_long
                : Icons.receipt_long_outlined,
            size: 16,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.spacingXs),
          Flexible(
            child: Text(
              tieneCotizaciones
                  ? '$cantidadCotizaciones cotización${cantidadCotizaciones == 1 ? '' : 'es'}'
                  : 'Sin cotizaciones aún',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.textStyleSmall.copyWith(
                color: accent,
                fontWeight: tieneCotizaciones
                    ? FontWeight.w600
                    : FontWeight.normal,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
