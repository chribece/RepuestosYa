import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../providers/orden_compra_provider.dart';
import 'home_page.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_status_badge.dart';
import '../widgets/ry_state_container.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

class OrdenCompraPage extends StatefulWidget {
  const OrdenCompraPage({super.key});

  @override
  State<OrdenCompraPage> createState() => _OrdenCompraPageState();
}

class _OrdenCompraPageState extends State<OrdenCompraPage> {
  final bool _hasShownErrorDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ordenId = ModalRoute.of(context)?.settings.arguments as String?;
      if (ordenId != null) {
        final provider = context.read<OrdenCompraProvider>();
        provider.clearError();
        provider.cargarOrden(ordenId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<OrdenCompraProvider>(
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

          if (provider.isLoading) {
            return const RyStateContainer(
              title: 'Cargando orden...',
              type: RyStateType.loading,
            );
          }

          final orden = provider.orden;

          if (orden == null) {
            return const RyStateContainer(
              title: 'Error',
              subtitle: 'No se pudo cargar la orden',
              type: RyStateType.error,
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header verde con éxito
                Container(
                  padding: const EdgeInsets.all(AppSpacing.spacingLg),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.onSurface,
                        size: 32,
                      ),
                      const SizedBox(width: AppSpacing.spacingMd),
                      Text(
                        '¡Orden Generada con Éxito!',
                        style: AppTextStyles.textStyleTitle.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingLg),

                // Tarjeta de Estado Actual
                Container(
                  padding: const EdgeInsets.all(AppSpacing.spacingMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado Actual',
                        style: AppTextStyles.textStyleTitle,
                      ),
                      const SizedBox(height: AppSpacing.spacingSm),
                      RyStatusBadge(
                        status: orden.estado,
                        style: RyStatusBadgeStyle.filled,
                        size: RyStatusBadgeSize.large,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingLg),

                // Tarjeta de Detalles del Repuesto
                Container(
                  padding: const EdgeInsets.all(AppSpacing.spacingMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detalles del Repuesto',
                        style: AppTextStyles.textStyleTitle,
                      ),
                      const SizedBox(height: AppSpacing.spacingMd),
                      _buildDetailRow(
                        Icons.attach_money,
                        'Precio',
                        '\$${orden.precioVenta.toStringAsFixed(2)}',
                      ),
                      if (orden.condicionRepuesto != null)
                        _buildDetailRow(
                          Icons.category,
                          'Condición',
                          orden.condicionRepuesto!,
                        ),
                      if (orden.tiempoEntrega != null)
                        _buildDetailRow(
                          Icons.access_time,
                          'Tiempo de Entrega',
                          orden.tiempoEntrega!,
                        ),
                      if (orden.fechaAceptacion != null)
                        _buildDetailRow(
                          Icons.calendar_today,
                          'Fecha de Aceptación',
                          orden.fechaAceptacion!,
                        ),
                      if (orden.notasAdicionales != null &&
                          orden.notasAdicionales!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.spacingSm,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.note,
                                color: AppColors.onSurfaceVariant,
                                size: 18,
                              ),
                              const SizedBox(width: AppSpacing.spacingSm),
                              Expanded(
                                child: Text(
                                  orden.notasAdicionales!,
                                  style: AppTextStyles.textStyleBody.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (orden.fotoEvidenciaUrl != null &&
                          orden.fotoEvidenciaUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.spacingLg,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.photo_library,
                                    color: AppColors.onSurfaceVariant,
                                    size: 18,
                                  ),
                                  const SizedBox(width: AppSpacing.spacingSm),
                                  Text(
                                    'Evidencia visual del repuesto:',
                                    style: AppTextStyles.textStyleCaption
                                        .copyWith(
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.spacingSm),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.radiusSm,
                                ),
                                child: Image.network(
                                  orden.fotoEvidenciaUrl!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 200,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.radiusSm,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.broken_image,
                                            color: AppColors.onSurfaceVariant,
                                            size: 32,
                                          ),
                                          const SizedBox(
                                            height: AppSpacing.spacingSm,
                                          ),
                                          Text(
                                            'No se pudo cargar la imagen',
                                            style: AppTextStyles.textStyleSmall
                                                .copyWith(
                                                  color: AppColors
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Container(
                                          height: 150,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceVariant,
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.radiusSm,
                                            ),
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: AppColors.primaryContainer,
                                            ),
                                          ),
                                        );
                                      },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingLg),

                // Tarjeta de Proveedor
                Container(
                  padding: const EdgeInsets.all(AppSpacing.spacingMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Proveedor', style: AppTextStyles.textStyleTitle),
                      const SizedBox(height: AppSpacing.spacingMd),
                      _buildDetailRow(
                        Icons.store,
                        'Nombre',
                        orden.nombreComercialAlmacen,
                      ),
                      if (orden.direccionTextoAlmacen != null)
                        _buildDetailRow(
                          Icons.location_on,
                          'Dirección',
                          orden.direccionTextoAlmacen!,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingLg),

                // Botón Volver al Inicio
                RyButton(
                  label: 'Volver al Inicio',
                  icon: Icons.home,
                  variant: RyButtonVariant.primary,
                  size: RyButtonSize.large,
                  onPressed: () {
                    // Navegar directamente al HomePage
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const HomePage()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
      child: Row(
        children: [
          Icon(icon, color: AppColors.onSurfaceVariant, size: 20),
          const SizedBox(width: AppSpacing.spacingSm),
          Text(
            '$label: ',
            style: AppTextStyles.textStyleCaption.copyWith(
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.textStyleCaption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
