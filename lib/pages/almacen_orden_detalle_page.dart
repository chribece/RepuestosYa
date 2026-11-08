import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/orden_compra.dart';
import '../services/orden_compra_service.dart';
import '../utils/api_error_handler.dart';
import '../utils/business_rules.dart';
import '../utils/contact_launcher.dart';
import '../widgets/ry_bottom_action_bar.dart';
import '../widgets/ry_status_badge.dart';
import '../widgets/ry_state_container.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/formato_fecha.dart';
import '../utils/ry_snackbar.dart';

class AlmacenOrdenDetallePage extends StatefulWidget {
  final String ordenId;

  const AlmacenOrdenDetallePage({super.key, required this.ordenId});

  @override
  State<AlmacenOrdenDetallePage> createState() =>
      _AlmacenOrdenDetallePageState();
}

class _AlmacenOrdenDetallePageState extends State<AlmacenOrdenDetallePage> {
  final OrdenCompraService _ordenService = OrdenCompraService();
  OrdenCompra? _orden;
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
          _orden = orden;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        mostrarSnackbarError(
          context,
          mensaje:
              'Error al cargar la orden: ${ApiErrorHandler.userMessage(e)}',
        );
      }
    }
  }

  Future<void> _actualizarEstado(String nuevoEstado) async {
    setState(() => _isUpdating = true);
    try {
      await _ordenService.actualizarEstadoOrden(widget.ordenId, nuevoEstado);
      if (mounted) {
        mostrarSnackbarExito(
          context,
          mensaje: 'Estado actualizado exitosamente',
        );
        setState(() => _isUpdating = false);
        await _cargarOrden();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        mostrarSnackbarError(
          context,
          mensaje:
              'Error al actualizar el estado: '
              '${ApiErrorHandler.userMessage(e)}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orden = _orden;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryContainer),
          tooltip: 'Regresar',
          onPressed: () => context.pop(),
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
          : orden == null
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
                  _buildCabecera(orden),
                  const SizedBox(height: AppSpacing.spacingLg),
                  _buildTarjetaCliente(orden),
                  const SizedBox(height: AppSpacing.spacingLg),
                  _buildTarjetaDetalles(orden),
                  const SizedBox(height: AppSpacing.spacingXl),
                ],
              ),
            ),
      bottomNavigationBar: orden == null ? null : _buildActionBar(orden),
    );
  }

  /// Cabecera: estado grande, número de orden amigable y, en una fila discreta,
  /// el número de solicitud (en lugar de los UUID completos).
  Widget _buildCabecera(OrdenCompra orden) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(
        children: [
          RyStatusBadge(
            status: orden.estado,
            style: RyStatusBadgeStyle.filled,
            size: RyStatusBadgeSize.large,
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          Text(
            'Orden ${formatearNumeroOrden(orden.id)}',
            style: AppTextStyles.textStyleTitle.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.spacingXxs),
          Text(
            'Solicitud ${formatearNumeroOrden(orden.solicitudId)}',
            style: AppTextStyles.textStyleSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Datos que el bodeguero necesita antes de confirmar: quién recibe, cómo
  /// contactarlo y adónde entregar. Teléfono y dirección se formatean igual
  /// que en el panel de cotizaciones ganadas.
  Widget _buildTarjetaCliente(OrdenCompra orden) {
    final telefono = orden.clienteTelefono;
    final direccion = orden.direccionEntrega;
    return _buildTarjeta(
      titulo: 'Cliente y entrega',
      icono: Icons.local_shipping_outlined,
      hijos: [
        _buildFilaRecibo(
          'Cliente',
          capitalizarNombre(orden.clienteNombre ?? 'No disponible'),
        ),
        _buildFilaRecibo(
          'Teléfono',
          telefono == null || telefono.trim().isEmpty
              ? 'No registrado'
              : formatearTelefonoParaMostrar(telefono),
        ),
        _buildFilaRecibo(
          'Dirección',
          direccion == null ? 'No registrada' : capitalizarNombre(direccion),
        ),
      ],
    );
  }

  /// Detalle de la orden en formato recibo: etiqueta a la izquierda y valor
  /// alineado a la derecha, precio con dos decimales.
  Widget _buildTarjetaDetalles(OrdenCompra orden) {
    final condicion = orden.condicionRepuesto;
    final tiempoEntrega = orden.tiempoEntrega;
    final notas = orden.notasAdicionales;
    final fotoUrl = orden.fotoEvidenciaUrl;
    return _buildTarjeta(
      titulo: 'Detalles',
      icono: Icons.receipt_long,
      hijos: [
        _buildFilaRecibo('Precio', '\$${orden.precioVenta.toStringAsFixed(2)}'),
        if (condicion != null) _buildFilaRecibo('Condición', condicion),
        if (tiempoEntrega != null)
          _buildFilaRecibo('Tiempo de entrega', tiempoEntrega),
        _buildFilaRecibo(
          'Fecha de creación',
          formatFechaHora(orden.createdAt.toIso8601String()),
        ),
        if (notas != null && notas.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.spacingXs),
          Text(
            'Notas adicionales',
            style: AppTextStyles.textStyleSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.spacingXxs),
          Text(notas, style: AppTextStyles.textStyleCaption),
        ],
        if (fotoUrl != null && fotoUrl.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.spacingMd),
          _buildFotoEvidencia(fotoUrl),
        ],
      ],
    );
  }

  /// Barra de acción inferior (componente compartido del DS): las acciones
  /// condicionales de la orden pasan de estar al final del scroll (quedaban
  /// ocultas bajo la barra de gestos) a una barra fija que respeta el inset.
  Widget? _buildActionBar(OrdenCompra orden) {
    final estado = orden.estado;
    if (estado == 'pendiente' || estado == 'pendiente_pago') {
      return RyBottomActionBar(
        primaryLabel: 'Marcar como Confirmada',
        primaryIcon: Icons.check_circle,
        primaryLoading: _isUpdating,
        onPrimaryPressed: _isUpdating
            ? null
            : () => _actualizarEstado('confirmada'),
      );
    }
    if (estado == 'confirmada') {
      return RyBottomActionBar(
        primaryLabel: 'Marcar como Entregada',
        primaryIcon: Icons.local_shipping,
        primaryLoading: _isUpdating,
        onPrimaryPressed: _isUpdating
            ? null
            : () => _actualizarEstado('entregada'),
      );
    }
    return null;
  }

  Widget _buildTarjeta({
    required String titulo,
    required IconData icono,
    required List<Widget> hijos,
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
              Icon(icono, color: AppColors.primaryContainer, size: 20),
              const SizedBox(width: AppSpacing.spacingSm),
              Text(
                titulo,
                style: AppTextStyles.textStyleBody.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          ...hijos,
        ],
      ),
    );
  }

  /// Fila tipo recibo: etiqueta a la izquierda, valor alineado a la derecha.
  Widget _buildFilaRecibo(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: AppTextStyles.textStyleCaption.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.spacingSm),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: AppTextStyles.textStyleCaption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFotoEvidencia(String fotoUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto de evidencia',
          style: AppTextStyles.textStyleSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
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
}
