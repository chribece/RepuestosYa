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
import '../utils/api_error_handler.dart';
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
  // Lista completa tal como llega del backend. Los filtros (ej. "Más
  // baratas") operan sobre esta y escriben el resultado en
  // `_cotizaciones`. Sin esto, al cambiar de un tab filtrado a "Todas"
  // se perderían las cotizaciones previamente filtradas.
  List<Map<String, dynamic>> _allCotizaciones = [];
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
        // Guardamos la lista completa original y aplicamos el filtro actual
        // para poblar `_cotizaciones`. Así, al cambiar de un tab filtrado
        // (ej. "Más baratas") a "Todas", podremos restaurar la lista completa.
        _allCotizaciones = List<Map<String, dynamic>>.from(cotizaciones);
        _cotizaciones = _ordenarCotizaciones(
          _allCotizaciones,
          _selectedTabIndex,
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = ApiErrorHandler.userMessage(e);
        _isLoading = false;
      });
    }
  }

  /// Parsea `precio_venta` que viene como String (numeric de Postgres se
  /// serializa como string en JSON) o como num. Devuelve 0.0 si no se puede
  /// interpretar. Evita el `TypeError` de `as num` cuando el valor es String.
  double _parsePrecio(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  List<Map<String, dynamic>> _ordenarCotizaciones(
    List<Map<String, dynamic>> cotizaciones,
    int tabIndex,
  ) {
    switch (tabIndex) {
      case 0: // Todas
        return cotizaciones;
      case 1: // Más baratas
        // Filtra a la(s) cotización(es) con el precio mínimo. Si hay
        // empate en el mínimo, se muestran todas las empatadas (no tiene
        // sentido ocultar una oferta igualmente barata).
        if (cotizaciones.isEmpty) return cotizaciones;
        final precios = cotizaciones
            .map((c) => _parsePrecio(c['precio_venta']))
            .toList();
        final minPrecio = precios.reduce((a, b) => a < b ? a : b);
        return cotizaciones
            .where((c) => _parsePrecio(c['precio_venta']) == minPrecio)
            .toList();
      case 2: // Más cercanas (Próximamente - tab deshabilitado)
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
      // Operamos siempre sobre la lista completa original, no sobre la
      // ya filtrada, para que el tab "Todas" restaure todas las cotizaciones.
      _cotizaciones = _ordenarCotizaciones(_allCotizaciones, index);
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
            content: Text(
              'Error al aceptar cotización: ${ApiErrorHandler.userMessage(e)}',
            ),
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
            content: Text(
              'Error al rechazar cotización: ${ApiErrorHandler.userMessage(e)}',
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
            child:
                widget.fotoUrl != null &&
                    widget.fotoUrl!.isNotEmpty &&
                    widget.fotoUrl!.startsWith('http')
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

  /// Índice del tab marcado como "Próximamente". Toca deshabilitado y
  /// muestra un badge. Se habilitará cuando `direcciones` tenga lat/lng y
  /// el backend exponga distancia Haversine entre almacén y entrega.
  static const int _kProximamenteTabIndex = 2;

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
          final isDisabled = index == _kProximamenteTabIndex;

          return Expanded(
            child: InkWell(
              onTap: isDisabled ? null : () => _onTabChanged(index),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.textStyleCaption.copyWith(
                        color: isDisabled
                            ? AppColors.onSurfaceVariant.withValues(alpha: 0.5)
                            : (isSelected
                                  ? AppColors.primaryContainer
                                  : AppColors.onSurfaceVariant),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    if (isDisabled) ...[
                      const SizedBox(width: AppSpacing.spacingXxs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.spacingXxs,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(
                            AppRadius.radiusFull,
                          ),
                        ),
                        child: Text(
                          'Próximamente',
                          style: AppTextStyles.textStyleSmall.copyWith(
                            fontSize: 9,
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
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
      itemCount: _cotizaciones.length + (_selectedTabIndex == 1 ? 1 : 0),
      itemBuilder: (context, index) {
        // Banner informativo cuando el filtro "Más baratas" está activo:
        // explica que se muestra solo la oferta más económica.
        if (_selectedTabIndex == 1 && index == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spacingMd,
              vertical: AppSpacing.spacingSm,
            ),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.savings_outlined,
                  color: AppColors.success,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.spacingSm),
                Expanded(
                  child: Text(
                    _cotizaciones.length == 1
                        ? 'Mostrando la cotización más económica'
                        : 'Mostrando ${_cotizaciones.length} cotizaciones empatadas en el precio mínimo',
                    style: AppTextStyles.textStyleSmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        final cotizacion =
            _cotizaciones[_selectedTabIndex == 1 ? index - 1 : index];
        return _buildQuotationCard(cotizacion);
      },
    );
  }

  Widget _buildQuotationCard(Map<String, dynamic> cotizacion) {
    final almacenes = cotizacion['almacenes'] as Map<String, dynamic>?;
    final almacenNombre =
        almacenes?['nombre_comercial'] ?? 'Almacén desconocido';
    final precio = _parsePrecio(cotizacion['precio_venta']);
    final tiempoEntrega =
        cotizacion['tiempo_entrega_estimado'] ?? 'No especificado';
    final fotoEvidencia = cotizacion['foto_evidencia_url'] as String?;
    final hasFoto =
        fotoEvidencia != null &&
        fotoEvidencia.isNotEmpty &&
        fotoEvidencia.startsWith('http');
    final notas = cotizacion['notas_adicionales'];
    final estado = cotizacion['estado'] ?? 'pendiente';
    final createdAt = cotizacion['created_at'];
    final cotizacionId = cotizacion['id']?.toString() ?? '';
    final isLoading = _loadingCotizaciones[cotizacionId] == true;

    final disponibilidad = tiempoEntrega.toLowerCase().contains('hoy')
        ? 'Disponible hoy'
        : 'Mañana';

    return Semantics(
      button: false,
      label:
          'Cotización de $almacenNombre, precio final \$${precio.toStringAsFixed(2)}, estado: $estado',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          border: Border.all(color: AppColors.outlineVariant, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== HEADER: almacén + badge disponibilidad =====
            Padding(
              padding: const EdgeInsets.all(AppSpacing.spacingMd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      almacenNombre,
                      style: AppTextStyles.textStyleBody.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.spacingSm),
                  RyStatusBadge(
                    status: disponibilidad == 'Disponible hoy'
                        ? 'available'
                        : 'pending',
                    style: RyStatusBadgeStyle.filled,
                    size: RyStatusBadgeSize.small,
                  ),
                  if (_selectedTabIndex == 1) ...[
                    const SizedBox(width: AppSpacing.spacingXs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.spacingXs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          AppRadius.radiusFull,
                        ),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.savings_outlined,
                            color: AppColors.success,
                            size: 12,
                          ),
                          const SizedBox(width: AppSpacing.spacingXxs),
                          Text(
                            'Más económica',
                            style: AppTextStyles.textStyleSmall.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ===== SUBTITLE: tiempo envío + tiempo entrega =====
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spacingMd,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: AppColors.onSurfaceVariant,
                    size: 14,
                  ),
                  const SizedBox(width: AppSpacing.spacingXxs),
                  Text(
                    _formatTiempoEnvio(createdAt),
                    style: AppTextStyles.textStyleSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.spacingSm),
                  const Icon(
                    Icons.schedule,
                    color: AppColors.onSurfaceVariant,
                    size: 14,
                  ),
                  const SizedBox(width: AppSpacing.spacingXxs),
                  Expanded(
                    child: Text(
                      tiempoEntrega,
                      style: AppTextStyles.textStyleSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // ===== NOTAS =====
            if (notas != null && notas.toString().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.spacingXs),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spacingMd,
                ),
                child: Text(
                  notas.toString(),
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.spacingMd),
            _buildDivider(),

            // ===== PRECIO FINAL (bloque propio) =====
            Padding(
              padding: const EdgeInsets.all(AppSpacing.spacingMd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Precio final',
                          style: AppTextStyles.textStyleCaption.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.spacingXxs),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '\$${precio.toStringAsFixed(2)}',
                              style: AppTextStyles.textStyleHeading.copyWith(
                                color: AppColors.primaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.spacingXxs),
                            const Icon(
                              Icons.verified,
                              color: AppColors.primaryContainer,
                              size: 18,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (estado != 'pendiente') ...[
                    if (estado == 'aceptada')
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
                ],
              ),
            ),

            // ===== ACCIONES (solo pendiente) =====
            if (estado == 'pendiente') ...[
              _buildDivider(),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasFoto) ...[
                      Semantics(
                        button: true,
                        label: 'Ver foto de evidencia de la cotización',
                        child: RyButton(
                          label: 'Ver foto',
                          icon: Icons.image_outlined,
                          variant: RyButtonVariant.outline,
                          size: RyButtonSize.small,
                          isFullWidth: true,
                          onPressed: () => _showEvidenciaModal(fotoEvidencia),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.spacingSm),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: 'Rechazar cotización de $almacenNombre',
                            child: RyButton(
                              label: 'Rechazar',
                              icon: Icons.close,
                              variant: RyButtonVariant.danger,
                              size: RyButtonSize.small,
                              isFullWidth: true,
                              onPressed: () =>
                                  _rechazarCotizacion(cotizacionId),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.spacingSm),
                        Expanded(
                          child: Semantics(
                            button: true,
                            label:
                                'Aceptar cotización de $almacenNombre por \$${precio.toStringAsFixed(2)}',
                            child: RyButton(
                              label: 'Aceptar',
                              icon: Icons.check,
                              variant: RyButtonVariant.primary,
                              size: RyButtonSize.small,
                              isFullWidth: true,
                              isLoading: isLoading,
                              isDisabled: isLoading,
                              onPressed: isLoading
                                  ? null
                                  : () => _aceptarCotizacion(cotizacionId),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd),
      color: AppColors.outlineVariant,
    );
  }

  /// Modal a pantalla completa para ver la evidencia con BoxFit.contain,
  /// InteractiveViewer (zoom) y cierre accesible. Reemplaza al Dialog
  /// angosto anterior que rompía la proporción de la imagen.
  void _showEvidenciaModal(String url) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.radiusLg),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.spacingMd),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Evidencia', style: AppTextStyles.textStyleTitle),
                    IconButton(
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.close, color: AppColors.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spacingMd,
                  vertical: AppSpacing.spacingSm,
                ),
                child: InteractiveViewer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return SizedBox(
                          height: 240,
                          child: Center(
                            child: CircularProgressIndicator(
                              value:
                                  progress.cumulativeBytesLoaded /
                                  (progress.expectedTotalBytes ?? 1),
                              color: AppColors.primaryContainer,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: AppColors.surfaceVariant,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  color: AppColors.onSurfaceVariant,
                                  size: 48,
                                ),
                                SizedBox(height: AppSpacing.spacingSm),
                                Text('No se pudo cargar la imagen'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.spacingMd),
            ],
          ),
        );
      },
    );
  }
}
