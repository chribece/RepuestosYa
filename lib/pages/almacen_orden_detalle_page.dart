import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/orden_compra_service.dart';
import '../utils/api_error_handler.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_status_badge.dart';
import '../widgets/ry_state_container.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

class AlmacenOrdenDetallePage extends StatefulWidget {
  final String ordenId;

  const AlmacenOrdenDetallePage({super.key, required this.ordenId});

  @override
  State<AlmacenOrdenDetallePage> createState() =>
      _AlmacenOrdenDetallePageState();
}

class _AlmacenOrdenDetallePageState extends State<AlmacenOrdenDetallePage> {
  final OrdenCompraService _ordenService = OrdenCompraService();
  Map<String, dynamic>? _orden;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _cargarOrden();
  }

  Future<void> _cargarOrden() async {
    setState(() => _isLoading = true);
    try {
      final orden = await _ordenService.getOrdenDetalle(widget.ordenId);
      if (mounted) {
        setState(() {
          _orden = orden.toJson();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar la orden: ${ApiErrorHandler.userMessage(e)}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _actualizarEstado(String nuevoEstado) async {
    setState(() => _isUpdating = true);
    try {
      await _ordenService.actualizarEstadoOrden(widget.ordenId, nuevoEstado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Estado actualizado exitosamente'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() => _isUpdating = false);
        await _cargarOrden();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al actualizar el estado: '
              '${ApiErrorHandler.userMessage(e)}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryContainer),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detalle de Orden',
          style: AppTextStyles.textStyleTitle,
        ),
      ),
      body: _isLoading
          ? const RyStateContainer(
              title: 'Cargando orden...',
              type: RyStateType.loading,
            )
          : _orden == null
          ? const RyStateContainer(
              title: 'Error',
              subtitle: 'No se pudo cargar la orden',
              type: RyStateType.error,
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado Badge Grande
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.spacingLg),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                      border: Border.all(
                        color: AppColors.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        RyStatusBadge(
                          status: _orden?['estado'] ?? 'desconocido',
                          style: RyStatusBadgeStyle.filled,
                          size: RyStatusBadgeSize.large,
                        ),
                        const SizedBox(height: AppSpacing.spacingMd),
                        Text(
                          'ID: ${widget.ordenId}',
                          style: AppTextStyles.textStyleSmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spacingLg),

                  // Información del Almacén
                  _buildInfoCard(
                    title: 'Almacén',
                    icon: Icons.store,
                    content:
                        _orden?['almacenes']?['nombre_comercial'] ??
                        'No disponible',
                  ),
                  const SizedBox(height: AppSpacing.spacingLg),

                  // Información de la Solicitud
                  _buildInfoCard(
                    title: 'ID de Solicitud',
                    icon: Icons.description,
                    content: _orden?['solicitud_id'] ?? 'No disponible',
                  ),
                  const SizedBox(height: AppSpacing.spacingLg),

                  // Detalles de la orden
                  if (_orden?['detalles'] != null) ...[
                    _buildDetallesCard(_orden?['detalles']),
                    const SizedBox(height: AppSpacing.spacingLg),
                  ],

                  // Fechas
                  _buildInfoCard(
                    title: 'Creada',
                    icon: Icons.calendar_today,
                    content: _formatFecha(_orden?['created_at']),
                  ),
                  const SizedBox(height: AppSpacing.spacingLg),

                  // Botones de acción condicionales
                  if (_orden?['estado'] == 'pendiente' ||
                      _orden?['estado'] == 'pendiente_pago')
                    RyButton(
                      label: 'Marcar como Confirmada',
                      icon: Icons.check_circle,
                      variant: RyButtonVariant.primary,
                      size: RyButtonSize.large,
                      isLoading: _isUpdating,
                      onPressed: _isUpdating
                          ? null
                          : () => _actualizarEstado('confirmada'),
                    ),
                  if (_orden?['estado'] == 'confirmada')
                    RyButton(
                      label: 'Marcar como Entregada',
                      icon: Icons.local_shipping,
                      variant: RyButtonVariant.primary,
                      size: RyButtonSize.large,
                      isLoading: _isUpdating,
                      onPressed: _isUpdating
                          ? null
                          : () => _actualizarEstado('entregada'),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Container(
      width: double.infinity,
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
              Icon(icon, color: AppColors.primaryContainer, size: 20),
              const SizedBox(width: AppSpacing.spacingSm),
              Text(
                title,
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Text(content, style: AppTextStyles.textStyleBody),
        ],
      ),
    );
  }

  Widget _buildDetallesCard(dynamic detalles) {
    if (detalles == null) return const SizedBox.shrink();

    final Map<String, dynamic> detallesMap = detalles is Map<String, dynamic>
        ? detalles
        : {};

    final precio = detallesMap['precio_venta'];
    final condicion = detallesMap['condicion_repuesto'];
    final tiempoEntrega = detallesMap['tiempo_entrega_estimado'];
    final notas = detallesMap['notas_adicionales'];
    final fotoUrl = detallesMap['foto_evidencia_url'];

    return Container(
      width: double.infinity,
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
              const Icon(
                Icons.list,
                color: AppColors.primaryContainer,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.spacingSm),
              Text(
                'Detalles',
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          if (precio != null) ...[
            _buildDetalleRow(
              icon: Icons.attach_money,
              label: 'Precio',
              value: '\$${precio.toString()}',
            ),
            const SizedBox(height: AppSpacing.spacingMd),
          ],
          if (condicion != null) ...[
            _buildDetalleRow(
              icon: Icons.check_circle,
              label: 'Condición',
              value: condicion.toString(),
            ),
            const SizedBox(height: AppSpacing.spacingMd),
          ],
          if (tiempoEntrega != null) ...[
            _buildDetalleRow(
              icon: Icons.access_time,
              label: 'Tiempo de entrega',
              value: tiempoEntrega.toString(),
            ),
            const SizedBox(height: AppSpacing.spacingMd),
          ],
          if (notas != null && notas.toString().isNotEmpty) ...[
            _buildDetalleRow(
              icon: Icons.note,
              label: 'Notas adicionales',
              value: notas.toString(),
            ),
            const SizedBox(height: AppSpacing.spacingMd),
          ],
          if (fotoUrl != null && fotoUrl.toString().isNotEmpty)
            _buildFotoEvidencia(fotoUrl.toString()),
        ],
      ),
    );
  }

  Widget _buildDetalleRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryContainer, size: 18),
        const SizedBox(width: AppSpacing.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.textStyleSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.spacingXxs),
              Text(
                value,
                style: AppTextStyles.textStyleCaption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFotoEvidencia(String fotoUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.image,
              color: AppColors.primaryContainer,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.spacingMd),
            Text(
              'Foto de evidencia',
              style: AppTextStyles.textStyleSmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
            border: Border.all(color: AppColors.outlineVariant, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
            child: CachedNetworkImage(
              imageUrl: fotoUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryContainer,
                ),
              ),
              errorWidget: (context, url, error) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      color: AppColors.onSurfaceVariant,
                      size: 32,
                    ),
                    const SizedBox(height: AppSpacing.spacingSm),
                    Text(
                      'No se pudo cargar la imagen',
                      style: AppTextStyles.textStyleSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatFecha(String? fecha) {
    if (fecha == null) return 'No disponible';
    try {
      final dateTime = DateTime.parse(fecha);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'No disponible';
    }
  }
}
