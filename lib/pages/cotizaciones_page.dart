import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/cotizacion_provider.dart';
import '../widgets/ry_state_container.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

class CotizacionesPage extends StatefulWidget {
  final String solicitudId;

  const CotizacionesPage({super.key, required this.solicitudId});

  @override
  State<CotizacionesPage> createState() => _CotizacionesPageState();
}

class _CotizacionesPageState extends State<CotizacionesPage> {
  bool _hasShownErrorDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CotizacionProvider>();
      provider.clearError();
      provider.cargarCotizaciones(widget.solicitudId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cotizaciones Recibidas'),
        backgroundColor: AppColors.tertiaryContainer,
      ),
      body: Consumer<CotizacionProvider>(
        builder: (context, provider, child) {
          // Mostrar error con SnackBar si existe
          if (provider.errorMessage != null && !_hasShownErrorDialog) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(provider.errorMessage!),
                    backgroundColor: AppColors.error,
                    duration: const Duration(seconds: 3),
                    action: SnackBarAction(
                      label: 'OK',
                      textColor: AppColors.onSurface,
                      onPressed: () {
                        provider.clearError();
                      },
                    ),
                  ),
                );
              }
            });
          }

          // Mostrar AlertDialog si la solicitud fue cerrada
          if (provider.solicitudCerrada && !_hasShownErrorDialog) {
            _hasShownErrorDialog = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('Solicitud Cerrada'),
                      content: const Text(
                        'Has rechazado todas las cotizaciones. La solicitud ha sido cerrada.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            Navigator.of(context).pop();
                          },
                          child: const Text('Volver'),
                        ),
                      ],
                    );
                  },
                );
              }
            });
          }

          // Navegar a la página de orden de compra si se aceptó una cotización
          if (provider.ordenCompraId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.pushNamed(
                  context,
                  '/orden-compra',
                  arguments: provider.ordenCompraId,
                );
              }
            });
          }

          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.cotizaciones.isEmpty) {
            return const RyStateContainer(
              title: 'No hay cotizaciones aún',
              type: RyStateType.empty,
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.cargarCotizaciones(widget.solicitudId),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.spacingMd),
              itemCount: provider.cotizaciones.length,
              itemBuilder: (context, index) {
                final cotizacion = provider.cotizaciones[index];
                final isPendiente = cotizacion.isPendiente;
                final isProcesando = provider.isCotizacionProcesando(
                  cotizacion.id,
                );

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.spacingMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre del almacén
                        Row(
                          children: [
                            const Icon(
                              Icons.store,
                              color: AppColors.tertiaryContainer,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.spacingXs),
                            Expanded(
                              child: Text(
                                cotizacion.almacen?.nombreComercial ??
                                    'Almacén desconocido',
                                style: AppTextStyles.textStyleBody.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Badge de estado
                            _buildEstadoBadge(cotizacion.estado),
                          ],
                        ),
                        const Divider(height: AppSpacing.spacingLg),

                        // Precio
                        _buildInfoRow(
                          Icons.attach_money,
                          'Precio',
                          '\$${cotizacion.precioVenta.toStringAsFixed(2)}',
                        ),

                        // Condición del repuesto
                        if (cotizacion.condicionRepuesto != null)
                          _buildInfoRow(
                            Icons.category,
                            'Condición',
                            cotizacion.condicionRepuesto!,
                          ),

                        // Tiempo de entrega
                        if (cotizacion.tiempoEntregaEstimado != null)
                          _buildInfoRow(
                            Icons.access_time,
                            'Tiempo de entrega',
                            cotizacion.tiempoEntregaEstimado!,
                          ),

                        // Notas adicionales
                        if (cotizacion.notasAdicionales != null &&
                            cotizacion.notasAdicionales!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.spacingXs,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.note,
                                  color: AppColors.onSurfaceVariant,
                                  size: 18,
                                ),
                                const SizedBox(width: AppSpacing.spacingXs),
                                Expanded(
                                  child: Text(
                                    cotizacion.notasAdicionales!,
                                    style: AppTextStyles.textStyleCaption
                                        .copyWith(
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Evidencia visual
                        if (cotizacion.fotoEvidenciaUrl != null &&
                            cotizacion.fotoEvidenciaUrl!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.spacingSm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.image,
                                      color: AppColors.onSurfaceVariant,
                                      size: 18,
                                    ),
                                    const SizedBox(width: AppSpacing.spacingXs),
                                    Text(
                                      'Evidencia visual',
                                      style: AppTextStyles.textStyleCaption
                                          .copyWith(
                                            color: AppColors.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.spacingXs),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.radiusSm,
                                  ),
                                  child: Image.network(
                                    cotizacion.fotoEvidenciaUrl!,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: double.infinity,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant,
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.radiusSm,
                                          ),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.broken_image,
                                                color:
                                                    AppColors.onSurfaceVariant,
                                                size: 40,
                                              ),
                                              const SizedBox(
                                                height: AppSpacing.spacingXs,
                                              ),
                                              Text(
                                                'Error al cargar imagen',
                                                style: AppTextStyles
                                                    .textStyleSmall
                                                    .copyWith(
                                                      color: AppColors
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Container(
                                            width: double.infinity,
                                            height: 200,
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceVariant,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.radiusSm,
                                                  ),
                                            ),
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        },
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: AppSpacing.spacingMd),

                        // Botones de acción
                        if (isPendiente)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isProcesando
                                      ? null
                                      : () {
                                          provider.aceptarCotizacion(
                                            cotizacion.id,
                                          );
                                        },
                                  icon: isProcesando
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  AppColors.onSurface,
                                                ),
                                          ),
                                        )
                                      : const Icon(Icons.check),
                                  label: Text(
                                    isProcesando ? 'Procesando...' : 'Aceptar',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: AppColors.onSurface,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.spacingSm,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.spacingSm),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isProcesando
                                      ? null
                                      : () {
                                          provider.rechazarCotizacion(
                                            cotizacion.id,
                                          );
                                        },
                                  icon: const Icon(Icons.close),
                                  label: const Text('Rechazar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: AppColors.onSurface,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.spacingSm,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Center(
                            child: Text(
                              cotizacion.isAceptada
                                  ? 'Cotización aceptada'
                                  : 'Cotización rechazada',
                              style: AppTextStyles.textStyleCaption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cotizacion.isAceptada
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.spacingXs),
      child: Row(
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant, size: 18),
          const SizedBox(width: AppSpacing.spacingXs),
          Text(
            '$label: ',
            style: AppTextStyles.textStyleCaption.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(child: Text(value, style: AppTextStyles.textStyleCaption)),
        ],
      ),
    );
  }

  Widget _buildEstadoBadge(String estado) {
    Color backgroundColor;
    Color textColor;
    String text;

    switch (estado.toLowerCase()) {
      case 'pendiente':
        backgroundColor = AppColors.warning.withValues(alpha: 0.2);
        textColor = AppColors.warning;
        text = 'Pendiente';
        break;
      case 'aceptada':
        backgroundColor = AppColors.success.withValues(alpha: 0.2);
        textColor = AppColors.success;
        text = 'Aceptada';
        break;
      case 'rechazada':
        backgroundColor = AppColors.error.withValues(alpha: 0.2);
        textColor = AppColors.error;
        text = 'Rechazada';
        break;
      default:
        backgroundColor = AppColors.onSurfaceVariant.withValues(alpha: 0.2);
        textColor = AppColors.onSurfaceVariant;
        text = estado;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spacingSm,
        vertical: AppSpacing.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      ),
      child: Text(
        text,
        style: AppTextStyles.textStyleSmall.copyWith(
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
