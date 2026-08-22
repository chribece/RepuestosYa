import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/solicitud_service.dart';
import '../services/realtime_notification_service.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_state_container.dart';
import '../widgets/ry_status_badge.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_logger.dart';

class ReceivedQuotationsPage extends StatefulWidget {
  final String solicitudId;
  final String piezaNombre;
  final String? fotoUrl;
  final int ofertasPendientes;

  const ReceivedQuotationsPage({
    super.key,
    required this.solicitudId,
    required this.piezaNombre,
    this.fotoUrl,
    this.ofertasPendientes = 0,
  });

  @override
  State<ReceivedQuotationsPage> createState() => _ReceivedQuotationsPageState();
}

class _ReceivedQuotationsPageState extends State<ReceivedQuotationsPage> {
  final SolicitudService _solicitudService = SolicitudService();

  int _selectedTabIndex = 0;
  List<Map<String, dynamic>> _cotizaciones = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, bool> _loadingCotizaciones = {};

  @override
  void initState() {
    super.initState();
    _cargarCotizaciones();
    RealtimeNotificationService().subscribeToCotizaciones(widget.solicitudId);
  }

  @override
  void dispose() {
    RealtimeNotificationService().unsubscribe();
    super.dispose();
  }

  Future<void> _cargarCotizaciones() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cotizaciones = await _solicitudService.obtenerCotizacionesRecibidas(
        widget.solicitudId,
      );
      setState(() {
        _cotizaciones = _ordenarCotizaciones(cotizaciones, _selectedTabIndex);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar cotizaciones: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _ordenarCotizaciones(
    List<Map<String, dynamic>> cotizaciones,
    int tabIndex,
  ) {
    switch (tabIndex) {
      case 0: // Todas
        return cotizaciones;
      case 1: // Más baratas
        final sorted = List<Map<String, dynamic>>.from(cotizaciones);
        sorted.sort(
          (a, b) =>
              (a['precio_venta'] as num).compareTo(b['precio_venta'] as num),
        );
        return sorted;
      case 2: // Más cercanas (simulado por ahora)
        return cotizaciones;
      default:
        return cotizaciones;
    }
  }

  String _formatTiempoEnvio(String? createdAt) {
    if (createdAt == null) return 'Hace un momento';

    try {
      final dateTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Hace un momento';
      } else if (difference.inMinutes < 60) {
        return 'Hace ${difference.inMinutes} min';
      } else if (difference.inHours < 24) {
        return 'Hace ${difference.inHours} h';
      } else {
        return 'Hace ${difference.inDays} días';
      }
    } catch (e) {
      return 'Hace un momento';
    }
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedTabIndex = index;
      _cotizaciones = _ordenarCotizaciones(_cotizaciones, index);
    });
  }

  Future<void> _aceptarCotizacion(String cotizacionId) async {
    setState(() {
      _loadingCotizaciones[cotizacionId] = true;
    });

    try {
      AppLogger.debug(
        'Intentando aceptar cotización con ID: $cotizacionId',
        name: 'ReceivedQuotationsPage',
      );
      final response = await _solicitudService.aceptarCotizacion(cotizacionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cotización aceptada correctamente'),
            backgroundColor: AppColors.success,
          ),
        );

        final ordenId = response['ordenId'] as String?;
        if (ordenId != null) {
          Navigator.of(
            context,
          ).pushReplacementNamed('/orden-compra', arguments: ordenId);
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      AppLogger.error(
        'Error al aceptar cotización',
        name: 'ReceivedQuotationsPage',
        error: e,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aceptar cotización: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingCotizaciones[cotizacionId] = false;
        });
      }
    }
  }

  Future<void> _rechazarCotizacion(String cotizacionId) async {
    try {
      AppLogger.debug(
        'Intentando rechazar cotización con ID: $cotizacionId',
        name: 'ReceivedQuotationsPage',
      );
      await _solicitudService.rechazarCotizacion(cotizacionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cotización rechazada'),
            backgroundColor: AppColors.warning,
          ),
        );
        _cargarCotizaciones();
      }
    } catch (e) {
      AppLogger.error(
        'Error al rechazar cotización',
        name: 'ReceivedQuotationsPage',
        error: e,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al rechazar cotización: $e'),
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
      appBar: _buildTopAppBar(),
      body: Column(
        children: [
          _buildSummaryCard(),
          _buildTabsBar(),
          Expanded(
            child: _isLoading
                ? const RyStateContainer(
                    title: 'Cargando cotizaciones...',
                    type: RyStateType.loading,
                  )
                : _errorMessage != null
                ? RyStateContainer(
                    title: 'Error',
                    subtitle: _errorMessage,
                    type: RyStateType.error,
                  )
                : _cotizaciones.isEmpty
                ? const RyStateContainer(
                    title: 'Sin cotizaciones',
                    subtitle: 'Los almacenes enviarán sus ofertas pronto',
                    type: RyStateType.empty,
                  )
                : _buildQuotationsList(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('Cotizaciones', style: AppTextStyles.textStyleTitle),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.spacingMd),
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              border: Border.all(color: AppColors.outlineVariant, width: 1),
            ),
            child: widget.fotoUrl != null && widget.fotoUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                    child: Image.network(
                      widget.fotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.image_not_supported,
                          color: AppColors.onSurfaceVariant,
                          size: 32,
                        );
                      },
                    ),
                  )
                : const Icon(
                    Icons.image,
                    color: AppColors.onSurfaceVariant,
                    size: 32,
                  ),
          ),
          const SizedBox(width: AppSpacing.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.piezaNombre,
                  style: AppTextStyles.textStyleBody,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.spacingXxs),
                Text(
                  '${widget.ofertasPendientes} ofertas pendientes',
                  style: AppTextStyles.textStyleCaption.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsBar() {
    final tabs = ['Todas', 'Más baratas', 'Más cercanas'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final isSelected = _selectedTabIndex == index;

          return Expanded(
            child: InkWell(
              onTap: () => _onTabChanged(index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.spacingMd,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? AppColors.primaryContainer
                          : AppColors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.textStyleCaption.copyWith(
                    color: isSelected
                        ? AppColors.primaryContainer
                        : AppColors.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuotationsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      itemCount: _cotizaciones.length,
      itemBuilder: (context, index) {
        final cotizacion = _cotizaciones[index];
        return _buildQuotationCard(cotizacion);
      },
    );
  }

  Widget _buildQuotationCard(Map<String, dynamic> cotizacion) {
    final almacenes = cotizacion['almacenes'] as Map<String, dynamic>?;
    final almacenNombre =
        almacenes?['nombre_comercial'] ?? 'Almacén desconocido';
    final precio = (cotizacion['precio_venta'] as num?)?.toDouble() ?? 0.0;
    final tiempoEntrega =
        cotizacion['tiempo_entrega_estimado'] ?? 'No especificado';
    final fotoEvidencia = cotizacion['foto_evidencia_url'];
    final notas = cotizacion['notas_adicionales'];
    final estado = cotizacion['estado'] ?? 'pendiente';
    final createdAt = cotizacion['created_at'];

    final disponibilidad = tiempoEntrega.toLowerCase().contains('hoy')
        ? 'Disponible hoy'
        : 'Mañana';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            almacenNombre,
                            style: AppTextStyles.textStyleBody,
                          ),
                          const SizedBox(width: AppSpacing.spacingSm),
                          RyStatusBadge(
                            status: disponibilidad == 'Disponible hoy'
                                ? 'available'
                                : 'pending',
                            style: RyStatusBadgeStyle.filled,
                            size: RyStatusBadgeSize.small,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.spacingXs),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: AppColors.onSurfaceVariant,
                            size: 16,
                          ),
                          const SizedBox(width: AppSpacing.spacingXxs),
                          Text(
                            _formatTiempoEnvio(createdAt),
                            style: AppTextStyles.textStyleSmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.spacingMd),
                          const Icon(
                            Icons.schedule,
                            color: AppColors.onSurfaceVariant,
                            size: 16,
                          ),
                          const SizedBox(width: AppSpacing.spacingXxs),
                          Text(
                            tiempoEntrega,
                            style: AppTextStyles.textStyleSmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (notas != null && notas.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.spacingXs),
                        Text(
                          notas,
                          style: AppTextStyles.textStyleSmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spacingMd,
            ),
            color: AppColors.outlineVariant,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Precio Final',
                        style: AppTextStyles.textStyleSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.spacingXxs),
                      Row(
                        children: [
                          Text(
                            '\$${precio.toStringAsFixed(2)}',
                            style: AppTextStyles.textStyleHeading.copyWith(
                              color: AppColors.primaryContainer,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.spacingXxs),
                          const Icon(
                            Icons.verified,
                            color: AppColors.primaryContainer,
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingMd),
                if (estado == 'pendiente') ...[
                  if (fotoEvidencia != null && fotoEvidencia.isNotEmpty)
                    RyButton(
                      label: 'Ver foto',
                      icon: Icons.image,
                      variant: RyButtonVariant.secondary,
                      size: RyButtonSize.small,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            backgroundColor: AppColors.surface,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(
                                    AppSpacing.spacingMd,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.radiusSm,
                                    ),
                                    child: Image.network(
                                      fotoEvidencia,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.error,
                                              color: AppColors.error,
                                              size: 64,
                                            );
                                          },
                                    ),
                                  ),
                                ),
                                RyButton(
                                  label: 'Cerrar',
                                  variant: RyButtonVariant.text,
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(width: AppSpacing.spacingSm),
                  RyButton(
                    label: 'Rechazar',
                    icon: Icons.close,
                    variant: RyButtonVariant.secondary,
                    size: RyButtonSize.small,
                    onPressed: () => _rechazarCotizacion(cotizacion['id']),
                  ),
                  const SizedBox(width: AppSpacing.spacingSm),
                  RyButton(
                    label: 'Aceptar',
                    icon: Icons.check,
                    variant: RyButtonVariant.primary,
                    size: RyButtonSize.small,
                    isLoading: _loadingCotizaciones[cotizacion['id']] == true,
                    onPressed: _loadingCotizaciones[cotizacion['id']] == true
                        ? null
                        : () => _aceptarCotizacion(cotizacion['id']),
                  ),
                ] else if (estado == 'aceptada')
                  RyStatusBadge(
                    status: 'completed',
                    customLabel: 'Aceptada',
                    style: RyStatusBadgeStyle.filled,
                    size: RyStatusBadgeSize.small,
                  )
                else if (estado == 'rechazada')
                  RyStatusBadge(
                    status: 'error',
                    customLabel: 'Rechazada',
                    style: RyStatusBadgeStyle.filled,
                    size: RyStatusBadgeSize.small,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
