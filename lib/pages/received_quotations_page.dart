import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme/app_colors.dart';
import '../models/coordinacion_entrega.dart';
import '../services/coordinacion_entrega_cache.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
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
import '../utils/business_rules.dart';
import '../utils/contact_launcher.dart';
import '../router/route_names.dart';

class ReceivedQuotationsPage extends StatefulWidget {
  final String solicitudId;
  final String? piezaNombre;
  final String? fotoUrl;
  final int ofertasPendientes;

  /// Servicio inyectable para widget tests (mismo patrón que
  /// WarehouseDashboard); en producción se usa el servicio real.
  final SolicitudService? solicitudService;

  const ReceivedQuotationsPage({
    super.key,
    required this.solicitudId,
    this.piezaNombre,
    this.fotoUrl,
    this.ofertasPendientes = 0,
    this.solicitudService,
  });

  @override
  State<ReceivedQuotationsPage> createState() => _ReceivedQuotationsPageState();
}

class _ReceivedQuotationsPageState extends State<ReceivedQuotationsPage> {
  late final SolicitudService _solicitudService =
      widget.solicitudService ?? SolicitudService();

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

  // Para deep linking y para mantener imagen/ofertas actualizadas, cargamos el detalle.
  String? _piezaNombreOverride;
  String? _fotoUrlOverride;
  int? _ofertasPendientesOverride;

  @override
  void initState() {
    super.initState();
    _piezaNombreOverride = widget.piezaNombre;
    _fotoUrlOverride = widget.fotoUrl;
    _ofertasPendientesOverride = widget.ofertasPendientes;

    _cargarCotizaciones();
    _cargarDetallesSolicitudSiEsNecesario();
    // Defensivo: si Supabase no está disponible (offline, tests), la
    // suscripción falla en silencio sin romper la pantalla.
    unawaited(
      RealtimeNotificationService()
          .subscribeToCotizaciones(widget.solicitudId)
          .catchError((Object error) {
            AppLogger.error(
              'Error al suscribir a cotizaciones',
              name: 'ReceivedQuotationsPage',
              error: error,
            );
          }),
    );
  }

  Future<void> _cargarDetallesSolicitudSiEsNecesario() async {
    try {
      final solicitudData = await _solicitudService.obtenerSolicitudPorId(
        widget.solicitudId,
      );
      if (mounted) {
        setState(() {
          final solicitud = Solicitud(solicitudData);
          _piezaNombreOverride = solicitud.displayPartName;
          _fotoUrlOverride = solicitud.fotoUrl ?? _fotoUrlOverride;
          _ofertasPendientesOverride = solicitud.cantidadCotizaciones;
        });
      }
    } catch (e) {
      AppLogger.error(
        'Error al cargar detalles de solicitud',
        name: 'ReceivedQuotationsPage',
        error: e,
      );
    }
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
  double _parsePrecio(dynamic value) => parsePrecioVenta(value);

  /// Parsea `distancia_km` (numeric de Postgres serializado como string o
  /// como num). Devuelve null si no está disponible.
  double? _parseDistancia(dynamic value) => parseDistanciaKm(value);

  List<Map<String, dynamic>> _ordenarCotizaciones(
    List<Map<String, dynamic>> cotizaciones,
    int tabIndex,
  ) {
    return ordenarCotizaciones(cotizaciones, tabIndex);
  }

  String _formatTiempoEnvio(String? createdAt) {
    return formatTiempoEnvio(createdAt);
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedTabIndex = index;
      // Operamos siempre sobre la lista completa original, no sobre la
      // ya filtrada, para que el tab "Todas" restaure todas las cotizaciones.
      _cotizaciones = _ordenarCotizaciones(_allCotizaciones, index);
    });
  }

  /// Asegura que el cliente tenga teléfono registrado ANTES de aceptar:
  /// los perfiles creados antes de que el registro lo exigiera pueden no
  /// tenerlo. Si falta, se solicita completarlo y se PERSISTE en el perfil
  /// antes de continuar (nunca se usan valores ficticios ni por defecto).
  /// Devuelve el teléfono utilizable, o `null` si el usuario cancela o la
  /// persistencia falla (en ese caso se bloquea la aceptación).
  Future<String?> _asegurarTelefonoCliente() async {
    final actual = AuthService().currentUser?.telefono;
    if (actual != null && actual.isNotEmpty && esTelefonoValido(actual)) {
      return actual;
    }

    if (!mounted) return null;
    // Sin TextEditingController: el diálogo se destruye con su animación de
    // salida y un controller descartado antes rompería el TextField.
    var telefono = '';
    String? errorText;

    final guardado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          title: const Text('Completa tu teléfono'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para aceptar la cotización necesitas un teléfono de '
                'contacto: el almacén ganador lo usará para coordinar el pago '
                'y la entrega de tu repuesto.',
                style: AppTextStyles.textStyleBody,
              ),
              const SizedBox(height: AppSpacing.spacingMd),
              TextField(
                keyboardType: TextInputType.phone,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Teléfono',
                  hintText: '+593 998757857',
                  prefixIcon: const Icon(Icons.phone_android),
                  errorText: errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  ),
                ),
                onChanged: (value) {
                  telefono = value.trim();
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                if (!esTelefonoValido(telefono)) {
                  setDialogState(
                    () => errorText =
                        'Ingresa un teléfono válido (mín. 9 dígitos)',
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return null;

    if (guardado != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completa tu teléfono en tu perfil para poder aceptar la cotización.',
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }

    // Persistir lo que el usuario escribió (sin valores por defecto).
    final actualizado = await ProfileService().updateProfile(
      telefono: telefono,
    );
    if (actualizado == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar tu teléfono. Verifica tu conexión e intenta nuevamente.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
    return telefono;
  }

  /// Abre el diálogo de confirmación antes de aceptar (evita doble tap y
  /// aceptaciones accidentales). Si no hay conexión, BLOQUEA la acción: la
  /// aceptación requiere confirmación 2xx del servidor y NO se encola en el
  /// Outbox (la coordinación depende de los datos que devuelve el backend).
  Future<void> _confirmarAceptacion(
    Map<String, dynamic> cotizacion,
    String almacenNombre,
    double precio,
  ) async {
    final resultados = await Connectivity().checkConnectivity();
    if (resultados.contains(ConnectivityResult.none)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay conexión a internet. La aceptación requiere confirmación '
            'del servidor; conéctate e intenta nuevamente.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Gate del teléfono: clientes sin teléfono (perfiles previos) deben
    // completarlo y persistirlo antes de continuar.
    final telefonoCliente = await _asegurarTelefonoCliente();
    if (telefonoCliente == null) return;

    if (!mounted) return;
    final repuestoNombre =
        _piezaNombreOverride ?? widget.piezaNombre ?? 'el repuesto';

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('¿Aceptar esta cotización?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResumenLinea('Almacén', almacenNombre),
            _buildResumenLinea('Repuesto', repuestoNombre),
            _buildResumenLinea(
              'Precio',
              '\$${precio.toStringAsFixed(2)}',
              destacado: true,
            ),
            const SizedBox(height: AppSpacing.spacingSm),
            const Text(
              'Al aceptar verás los datos de contacto del almacén para '
              'coordinar el pago y la entrega.',
              style: AppTextStyles.textStyleSmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;
    await _ejecutarAceptacion(cotizacion, almacenNombre, precio);
  }

  Widget _buildResumenLinea(
    String label,
    String value, {
    bool destacado = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.spacingXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: AppTextStyles.textStyleCaption.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.textStyleCaption.copyWith(
                color: destacado ? AppColors.primaryContainer : null,
                fontWeight: destacado ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutarAceptacion(
    Map<String, dynamic> cotizacion,
    String almacenNombre,
    double precio,
  ) async {
    final cotizacionId = cotizacion['id']?.toString() ?? '';
    setState(() {
      _loadingCotizaciones[cotizacionId] = true;
    });

    try {
      AppLogger.debug(
        'Intentando aceptar cotización con ID: $cotizacionId',
        name: 'ReceivedQuotationsPage',
      );
      final response = await _solicitudService.aceptarCotizacion(cotizacionId);

      // Persistir los datos de coordinación: la pantalla de contacto se puede
      // reabrir desde una solicitud ACEPTADA y funciona sin conexión.
      final datos =
          DatosCoordinacionEntrega.fromAceptacionResponse(
            response,
            cotizacionId: cotizacionId,
            solicitudId: widget.solicitudId,
          ) ??
          // Respaldo: si el backend no devolvió el bloque `almacen` (versión
          // antigua), se construye desde la tarjeta local para no depender de
          // un segundo round-trip al abrir la pantalla de coordinación.
          DatosCoordinacionEntrega.desdeTarjetaLocal(
            cotizacion,
            solicitudId: widget.solicitudId,
          );
      if (datos != null) {
        try {
          final cache = await CoordinacionEntregaCache.instancia();
          await cache.guardar(datos);
        } catch (cacheError) {
          AppLogger.error(
            'Error al guardar caché de coordinación',
            name: 'ReceivedQuotationsPage',
            error: cacheError,
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cotización aceptada correctamente'),
          backgroundColor: AppColors.success,
        ),
      );

      // pushReplacement: "atrás" no regresa a la cotización ya aceptada.
      context.pushReplacementNamed(
        RouteNames.coordinacionEntrega,
        pathParameters: {'id': widget.solicitudId},
        extra: {'datos': datos},
      );
    } on ApiException catch (e) {
      AppLogger.error(
        'Error al aceptar cotización',
        name: 'ReceivedQuotationsPage',
        error: e,
      );
      if (!mounted) return;

      if (e.statusCode == 409) {
        // Ya existe una cotización aceptada: mensaje del servidor y refresco
        // para reflejar el estado real (el botón desaparece).
        _cargarCotizaciones();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorHandler.userMessage(e)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  /// Reabre la pantalla de coordinación desde una cotización ya ACEPTADA
  /// (sin depender del flujo inmediato de aceptación).
  void _abrirCoordinacion(Map<String, dynamic> cotizacion) {
    final datos = DatosCoordinacionEntrega.fromCotizacionMap(
      cotizacion,
      solicitudId: widget.solicitudId,
    );
    context.pushNamed(
      RouteNames.coordinacionEntrega,
      pathParameters: {'id': widget.solicitudId},
      extra: {'datos': datos},
    );
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
        tooltip: 'Regresar',
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('Cotizaciones', style: AppTextStyles.textStyleTitle),
    );
  }

  Widget _buildSummaryCard() {
    final fotoUrl = _fotoUrlOverride ?? widget.fotoUrl;
    final piezaNombre =
        _piezaNombreOverride ?? widget.piezaNombre ?? 'Cargando...';
    final ofertasPendientes =
        _ofertasPendientesOverride ?? widget.ofertasPendientes;

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
                fotoUrl != null &&
                    fotoUrl.isNotEmpty &&
                    fotoUrl.startsWith('http')
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                    child: Image.network(
                      fotoUrl,
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
                  piezaNombre,
                  style: AppTextStyles.textStyleBody,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.spacingXxs),
                Text(
                  '$ofertasPendientes ofertas pendientes',
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.textStyleCaption.copyWith(
                        color: isSelected
                            ? AppColors.primaryContainer
                            : AppColors.onSurfaceVariant,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
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
        return _buildQuotationCard(
          cotizacion,
          // En el tab "Más cercanas" la lista viene ordenada por distancia:
          // solo la primera es la más cercana.
          destacarCercana: _selectedTabIndex == 2 && index == 0,
        );
      },
    );
  }

  Widget _buildQuotationCard(
    Map<String, dynamic> cotizacion, {
    bool destacarCercana = false,
  }) {
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
                  if (destacarCercana) ...[
                    const SizedBox(width: AppSpacing.spacingXs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.spacingXs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppRadius.radiusFull,
                        ),
                        border: Border.all(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.near_me_outlined,
                            color: AppColors.primaryContainer,
                            size: 12,
                          ),
                          const SizedBox(width: AppSpacing.spacingXxs),
                          Text(
                            'Más cercana',
                            style: AppTextStyles.textStyleSmall.copyWith(
                              color: AppColors.primaryContainer,
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

            // ===== DISTANCIA AL CLIENTE (radio razonable) =====
            if (_parseDistancia(cotizacion['distancia_km']) != null) ...[
              const SizedBox(height: AppSpacing.spacingXs),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spacingMd,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.route_outlined,
                      color: AppColors.onSurfaceVariant,
                      size: 14,
                    ),
                    const SizedBox(width: AppSpacing.spacingXxs),
                    Expanded(
                      child: Text(
                        'A ${_parseDistancia(cotizacion['distancia_km'])!.toStringAsFixed(1)} km de ti',
                        style: AppTextStyles.textStyleSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

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
                                'Seleccionar y aceptar cotización de $almacenNombre por \$${precio.toStringAsFixed(2)}',
                            child: RyButton(
                              label: 'Seleccionar y Aceptar',
                              icon: Icons.check,
                              variant: RyButtonVariant.primary,
                              size: RyButtonSize.small,
                              isFullWidth: true,
                              isLoading: isLoading,
                              isDisabled: isLoading,
                              onPressed: isLoading
                                  ? null
                                  : () => _confirmarAceptacion(
                                      cotizacion,
                                      almacenNombre,
                                      precio,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            // ===== REABRIR COORDINACIÓN (solo cotización GANADA) =====
            if (estado == 'aceptada') ...[
              _buildDivider(),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.spacingMd),
                child: Semantics(
                  button: true,
                  label: 'Ver datos de contacto del almacén $almacenNombre',
                  child: RyButton(
                    label: 'Ver datos de contacto del almacén',
                    icon: Icons.contact_phone_outlined,
                    variant: RyButtonVariant.outline,
                    size: RyButtonSize.small,
                    isFullWidth: true,
                    onPressed: () => _abrirCoordinacion(cotizacion),
                  ),
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
