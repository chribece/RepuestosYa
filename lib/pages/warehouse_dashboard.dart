import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme/app_colors.dart';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';
import '../services/almacen_service.dart';
import '../services/almacen_repository.dart';
import '../services/realtime_notification_service.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_part_card.dart';
import '../widgets/ry_state_container.dart';
import '../widgets/ry_status_badge.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import '../router/route_names.dart';

class WarehouseDashboard extends StatefulWidget {
  const WarehouseDashboard({super.key});

  @override
  State<WarehouseDashboard> createState() => _WarehouseDashboardState();
}

/// Estado de la validación del perfil comercial al entrar al dashboard.
enum _ProfileCheckState { validating, needsProfile, error, ready }

class _WarehouseDashboardState extends State<WarehouseDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SolicitudService _solicitudService = SolicitudService();
  final AuthService _authService = AuthService();
  late final AlmacenService _almacenService;

  static const String _logName = 'WarehouseDashboard';
  static const String _filterLogName = 'WarehouseDashboard.Filter';

  /// Intervalo de verificación del estado de aprobación mientras el almacén
  /// no esté aprobado. Se detiene automáticamente al pasar a `approved`.
  static const Duration _approvalPollInterval = Duration(seconds: 10);

  Timer? _approvalTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Estado de conectividad del dashboard: permite detectar la transición
  /// offline → online y recargar automáticamente el feed de solicitudes.
  bool _isOffline = false;

  bool _isOpen = true;
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _solicitudes = [];
  List<Map<String, dynamic>> _cotizacionesEnviadas = [];
  bool _isLoadingSolicitudes = false;
  bool _isLoadingCotizaciones = false;
  String? _nombreAlmacen;
  Map<String, dynamic>? _almacenData;
  String _filtroActual = 'todas';

  /// Estado de la validación del perfil comercial al entrar al dashboard.
  /// Evita llamar a /requests/active y /quotations/my-quotations hasta
  /// confirmar que existe el almacén.
  _ProfileCheckState _profileCheck = _ProfileCheckState.validating;
  String? _profileCheckError;

  bool get _isApproved => _almacenData?['verification_status'] == 'approved';
  bool get _isPending =>
      _almacenData?['verification_status'] == 'pending' ||
      _almacenData?['verification_status'] == null;
  bool get _isRejected => _almacenData?['verification_status'] == 'rejected';
  String? get _rejectionReason => _almacenData?['rejection_reason'];

  // Variables dinámicas para el panel de estadísticas Bento
  final int _ventasCount = 0;
  final int _vistasCount = 0;

  @override
  void initState() {
    super.initState();
    _almacenService = AlmacenService(context.read<AlmacenRepository>());
    _validateAndLoad();
    _initConnectivityWatcher();
  }

  /// Escucha los cambios de conectividad. Al volver la conexión (offline →
  /// online) muestra un aviso y recarga automáticamente el perfil, las
  /// solicitudes y las cotizaciones — sin necesidad de salir de la pantalla,
  /// entrar al listado ni cerrar/abrir sesión. Al perderla, avisa que se
  /// muestran los datos disponibles.
  void _initConnectivityWatcher() {
    Connectivity().checkConnectivity().then((results) {
      if (mounted) _isOffline = results.contains(ConnectivityResult.none);
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (!mounted) return;

      final isOffline = results.contains(ConnectivityResult.none);
      final wasOffline = _isOffline;
      _isOffline = isOffline;

      if (wasOffline && !isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '¡Has vuelto a tener conexión! Actualizando solicitudes...',
            ),
            backgroundColor: AppColors.primaryContainer,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _validateAndLoad();
      } else if (!wasOffline && isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Sin conexión. Se muestran los datos disponibles.',
            ),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  /// Pide confirmación antes de cerrar la sesión (consistente con el Home del
  /// cliente y el perfil); el router redirige solo a /welcome tras el signOut.
  void _confirmarCierreSesion() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: Text('Cerrar Sesión', style: AppTextStyles.textStyleTitle),
        content: Text(
          '¿Estás seguro de que deseas salir de la aplicación?',
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancelar',
              style: AppTextStyles.textStyleButton.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _authService.signOut();
            },
            child: Text(
              'Salir',
              style: AppTextStyles.textStyleButton.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Validación centralizada: primero confirma que existe el perfil de
  /// almacén (GET /warehouse/my-warehouse). Solo si existe (200) procede a
  /// cargar solicitudes, datos del almacén y cotizaciones. Si responde 404
  /// redirige a CompleteProfilePage. Si hay otro error, lo muestra.
  Future<void> _validateAndLoad() async {
    try {
      final hasProfile = await _almacenService.hasWarehouseProfile();
      if (!mounted) return;
      if (hasProfile) {
        setState(() => _profileCheck = _ProfileCheckState.ready);
        await _cargarAlmacen();
        await _cargarSolicitudes();
        await _cargarCotizacionesEnviadas();
        _startApprovalWatcherIfPending();
      } else {
        AppLogger.info(
          'WarehouseDashboard: perfil de almacén no existe (404). '
          'Redirigiendo a CompleteProfilePage.',
          name: _logName,
        );
        setState(() => _profileCheck = _ProfileCheckState.needsProfile);
        context.goNamed(RouteNames.completeProfile);
      }
    } catch (e) {
      AppLogger.error(
        'WarehouseDashboard: error al validar perfil de almacén',
        name: _logName,
        error: e,
      );
      if (!mounted) return;
      setState(() {
        _profileCheck = _ProfileCheckState.error;
        _profileCheckError = ApiErrorHandler.userMessage(e);
      });
    }
  }

  Future<void> _cargarAlmacen() async {
    try {
      final almacen = await _almacenService.obtenerMiAlmacen();
      if (mounted) {
        setState(() {
          _almacenData = almacen;
          _nombreAlmacen = almacen?['nombre_comercial'] ?? 'Mi Almacén';
          _isOpen = almacen?['estado_abierto'] ?? true;
        });
        if (almacen != null && almacen['id'] != null) {
          final almacenId = almacen['id'].toString();
          await RealtimeNotificationService().subscribeToOrdenes(almacenId);
          if (_isApproved) {
            await RealtimeNotificationService().subscribeToNuevasSolicitudes();
          }
        }
      }
    } catch (e) {
      // ← esto te habría mostrado el 404 de inmediato
      AppLogger.error('Error al cargar almacén', name: _logName, error: e);
      if (mounted) {
        setState(() {
          _nombreAlmacen = 'Mi Almacén';
        });
      }
    }
  }

  Future<void> _cargarCotizacionesEnviadas() async {
    setState(() => _isLoadingCotizaciones = true);
    try {
      final cotizaciones = await _solicitudService.obtenerMisCotizaciones();
      if (mounted) {
        setState(() {
          _cotizacionesEnviadas = List<Map<String, dynamic>>.from(cotizaciones);
          _isLoadingCotizaciones = false;
        });
      }
    } catch (e) {
      AppLogger.error(
        'Error al cargar cotizaciones enviadas',
        name: _logName,
        error: e,
      );
      if (mounted) {
        setState(() => _isLoadingCotizaciones = false);
      }
    }
  }

  // Carga asíncrona robusta con casteo seguro para evitar excepciones de tipo en Flutter
  Future<void> _cargarSolicitudes() async {
    if (!_isApproved) {
      setState(() {
        _solicitudes = [];
        _isLoadingSolicitudes = false;
      });
      return;
    }

    setState(() {
      _isLoadingSolicitudes = true;
    });
    try {
      final solicitudes = await _solicitudService.obtenerSolicitudesActivas();
      AppLogger.debug(
        'Solicitudes cargadas: ${solicitudes.length}',
        name: _logName,
      );
      for (var sol in solicitudes) {
        AppLogger.debug(
          'Solicitud ID: ${sol['id']}, Pieza: ${sol['pieza_nombre']}',
          name: _logName,
        );
      }
      setState(() {
        // Mapeamos de forma segura la lista dinámica para evitar incompatibilidades de tipos
        _solicitudes = List<Map<String, dynamic>>.from(solicitudes);
        _isLoadingSolicitudes = false;
      });
    } catch (e) {
      AppLogger.error('Error al cargar solicitudes', name: _logName, error: e);
      setState(() {
        _isLoadingSolicitudes = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar solicitudes: ${ApiErrorHandler.userMessage(e)}',
            ),
          ),
        );
      }
    }
  }

  /// Mientras el almacén no esté aprobado, verifica periódicamente el estado
  /// de verificación (GET /warehouse/my-warehouse). Cuando el admin aprueba
  /// desde el panel, el dashboard se actualiza solo: activa el feed de
  /// solicitudes, la suscripción realtime de nuevas solicitudes y muestra un
  /// aviso — sin salir de la pantalla ni cerrar/abrir sesión.
  void _startApprovalWatcherIfPending() {
    if (_isApproved) return;
    _approvalTimer ??= Timer.periodic(_approvalPollInterval, (_) {
      if (mounted) _checkApprovalStatus();
    });
  }

  Future<void> _checkApprovalStatus() async {
    if (_profileCheck != _ProfileCheckState.ready) return;

    try {
      final almacen = await _almacenService.obtenerMiAlmacen();
      if (!mounted || almacen == null) return;

      final wasApproved = _isApproved;
      setState(() {
        _almacenData = almacen;
        _nombreAlmacen =
            almacen['nombre_comercial']?.toString() ?? _nombreAlmacen;
        _isOpen = almacen['estado_abierto'] ?? _isOpen;
      });

      if (_isApproved && !wasApproved) {
        _approvalTimer?.cancel();
        _approvalTimer = null;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '¡Tu almacén ha sido aprobado! Ya puedes ver y responder solicitudes.',
            ),
            backgroundColor: AppColors.primaryContainer,
            behavior: SnackBarBehavior.floating,
          ),
        );

        await _cargarSolicitudes();
        await _cargarCotizacionesEnviadas();

        final almacenId = almacen['id']?.toString();
        if (almacenId != null) {
          await RealtimeNotificationService().subscribeToNuevasSolicitudes();
        }
      }
    } catch (e) {
      AppLogger.warning('Fallo el chequeo de aprobación: $e', name: _logName);
    }
  }

  @override
  void dispose() {
    _approvalTimer?.cancel();
    _approvalTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    RealtimeNotificationService().unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,

      drawer: Drawer(
        child: Container(
          color: AppColors.background,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'RepuestosYa',
                      style: AppTextStyles.textStyleHeading.copyWith(
                        color: AppColors.primaryContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spacingSm),
                    Text(
                      'Panel de Control (Almacén)',
                      style: AppTextStyles.textStyleCaption.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.dashboard,
                  color: AppColors.primaryContainer,
                ),
                title: Text(
                  'Panel Principal',
                  style: AppTextStyles.textStyleBody,
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = 0);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.send,
                  color: AppColors.primaryContainer,
                ),
                title: Text(
                  'Cotizaciones Enviadas',
                  style: AppTextStyles.textStyleBody,
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = 2);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.store,
                  color: AppColors.primaryContainer,
                ),
                title: Text('Mi Almacén', style: AppTextStyles.textStyleBody),
                onTap: () async {
                  Navigator.pop(context);
                  final almacen = await _almacenService.obtenerMiAlmacen();
                  if (context.mounted) {
                    if (almacen != null) {
                      context.pushNamed(RouteNames.profileAlmacen);
                    } else {
                      context.pushNamed(RouteNames.registerAlmacen);
                    }
                  }
                },
              ),
              const Divider(color: AppColors.outlineVariant),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: Text(
                  'Cerrar Sesión',
                  style: AppTextStyles.textStyleBody.copyWith(
                    color: AppColors.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmarCierreSesion();
                },
              ),
            ],
          ),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(),
            Expanded(
              child: switch (_profileCheck) {
                _ProfileCheckState.validating => const RyStateContainer(
                  title: 'Verificando perfil de almacén...',
                  type: RyStateType.loading,
                ),
                _ProfileCheckState.error => RyStateContainer(
                  title: 'No se pudo verificar tu perfil de almacén',
                  subtitle: _profileCheckError,
                  type: RyStateType.error,
                ),
                _ProfileCheckState.needsProfile =>
                  // Redirección gestionada en _validateAndLoad; estado
                  // intermedio para no renderizar el dashboard.
                  const RyStateContainer(
                    title: 'Redirigiendo a completar perfil...',
                    type: RyStateType.loading,
                  ),
                _ProfileCheckState.ready =>
                  _selectedIndex == 0
                      ? RefreshIndicator(
                          onRefresh: () async {
                            await _validateAndLoad();
                          },
                          color: AppColors.primaryContainer,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.spacingMd,
                              vertical: AppSpacing.spacingLg,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nombreAlmacen ?? 'Cargando...',
                                  style: AppTextStyles.textStyleHeading,
                                ),
                                const SizedBox(height: AppSpacing.spacingXxs),
                                Text(
                                  'Gestión de inventario y pedidos en tiempo real.',
                                  style: AppTextStyles.textStyleCaption
                                      .copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.spacingLg),
                                if (_isPending) _buildVerificationBanner(),
                                if (_isRejected) _buildRejectedBanner(),
                                const SizedBox(height: AppSpacing.spacingXl),
                                _buildBentoStatsGrid(),
                                const SizedBox(height: AppSpacing.spacingXl),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Solicitudes Disponibles',
                                      style: AppTextStyles.textStyleTitle,
                                    ),
                                    RyButton(
                                      label: 'Ver todas',
                                      variant: RyButtonVariant.text,
                                      size: RyButtonSize.small,
                                      onPressed: _isApproved
                                          ? _cargarSolicitudes
                                          : null,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.spacingMd),
                                !_isApproved
                                    ? RyStateContainer(
                                        title: _isPending
                                            ? 'En Verificación'
                                            : 'Almacén Rechazado',
                                        subtitle: _isPending
                                            ? 'Tu cuenta está en proceso de revisión. Podrás ver solicitudes una vez seas aprobado.'
                                            : 'Tu registro ha sido rechazado. ${_rejectionReason ?? "Contacta a soporte para más información."}',
                                        type: _isPending
                                            ? RyStateType.loading
                                            : RyStateType.error,
                                      )
                                    : _isLoadingSolicitudes
                                    ? const RyStateContainer(
                                        title: 'Cargando solicitudes...',
                                        type: RyStateType.loading,
                                      )
                                    : _solicitudes.isEmpty
                                    ? const RyStateContainer(
                                        title: 'Sin solicitudes',
                                        subtitle:
                                            'No hay solicitudes activas. Las nuevas peticiones de los clientes aparecerán aquí.',
                                        type: RyStateType.empty,
                                      )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: _solicitudes.length,
                                        itemBuilder: (context, index) {
                                          final solicitud = _solicitudes[index];
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: AppSpacing.spacingMd,
                                            ),
                                            child: _buildRequestBentoCard(
                                              solicitud: solicitud,
                                            ),
                                          );
                                        },
                                      ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _cargarCotizacionesEnviadas,
                          color: AppColors.primaryContainer,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.spacingMd,
                              vertical: AppSpacing.spacingLg,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cotizaciones Enviadas',
                                  style: AppTextStyles.textStyleHeading,
                                ),
                                const SizedBox(height: AppSpacing.spacingXxs),
                                Text(
                                  'Historial de cotizaciones enviadas a clientes.',
                                  style: AppTextStyles.textStyleCaption
                                      .copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.spacingXl),
                                _buildFilterChips(),
                                const SizedBox(height: AppSpacing.spacingMd),
                                _isLoadingCotizaciones
                                    ? const RyStateContainer(
                                        title: 'Cargando cotizaciones...',
                                        type: RyStateType.loading,
                                      )
                                    : _cotizacionesEnviadas.isEmpty
                                    ? const RyStateContainer(
                                        title: 'Sin cotizaciones',
                                        subtitle:
                                            'Las cotizaciones que envíes aparecerán aquí.',
                                        type: RyStateType.empty,
                                      )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: _cotizacionesEnviadas.length,
                                        itemBuilder: (context, index) {
                                          final cotizacion =
                                              _cotizacionesEnviadas[index];
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: AppSpacing.spacingMd,
                                            ),
                                            child: _buildQuotationCard(
                                              cotizacion,
                                            ),
                                          );
                                        },
                                      ),
                              ],
                            ),
                          ),
                        ),
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildTopAppBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.menu,
              color: AppColors.primaryContainer,
              size: 24,
            ),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: AppSpacing.spacingSm),
          Text(
            'REPUESTOSYA',
            style: AppTextStyles.textStyleHeading.copyWith(
              color: AppColors.primaryContainer,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (_isApproved)
            GestureDetector(
              onTap: () async {
                final newStatus = !_isOpen;
                setState(() => _isOpen = newStatus);

                try {
                  final almacenId = _almacenData?['id']?.toString();
                  if (almacenId != null) {
                    await _almacenService.actualizarAlmacen(almacenId, {
                      'estado_abierto': newStatus,
                    });
                  }
                } catch (e) {
                  AppLogger.error(
                    'Error al actualizar estado operativo',
                    name: _logName,
                    error: e,
                  );
                  if (mounted) {
                    setState(() => _isOpen = !newStatus);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ApiErrorHandler.userMessage(e)),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spacingSm,
                  vertical: AppSpacing.spacingXs - 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                  border: Border.all(color: AppColors.outlineVariant, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isOpen ? AppColors.success : AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spacingSm),
                    Text(
                      _isOpen ? 'Abierto' : 'Cerrado',
                      style: AppTextStyles.textStyleSmall.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primaryContainer),
          const SizedBox(width: AppSpacing.spacingMd),
          Expanded(
            child: Text(
              'Tu almacén está en verificación. Un administrador revisará tu información antes de habilitarte para recibir solicitudes.',
              style: AppTextStyles.textStyleSmall.copyWith(
                color: AppColors.primaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error),
              const SizedBox(width: AppSpacing.spacingMd),
              Expanded(
                child: Text(
                  'Tu almacén ha sido rechazado.',
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (_rejectionReason != null) ...[
            const SizedBox(height: AppSpacing.spacingSm),
            Text(
              'Motivo: $_rejectionReason',
              style: AppTextStyles.textStyleSmall.copyWith(
                color: AppColors.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.spacingSm),
          Text(
            'Revisa los datos ingresados o comunícate con soporte.',
            style: AppTextStyles.textStyleSmall.copyWith(
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildBentoStatCard(
            'Ventas',
            '$_ventasCount',
            AppColors.onSurface,
          ),
        ),
        const SizedBox(width: AppSpacing.spacingSm),
        Expanded(
          child: _buildBentoStatCard(
            'Pendientes',
            '${_solicitudes.length}',
            AppColors.primaryContainer,
          ),
        ),
        const SizedBox(width: AppSpacing.spacingSm),
        Expanded(
          child: _buildBentoStatCard(
            'Vistas',
            '$_vistasCount',
            AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  String _formatTiempo(String? createdAt) {
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

  Widget _buildBentoStatCard(String label, String value, Color valueColor) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.05),
            blurRadius: 15,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.textStyleSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            // fontFamily monoespaciado intencional para métricas numéricas (sin token equivalente)
            style: AppTextStyles.textStyleHeading.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
              fontFamily: 'JetBrains Mono',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        FilterChip(
          label: const Text('Todas'),
          selected: _filtroActual == 'todas',
          onSelected: (selected) {
            setState(() {
              _filtroActual = 'todas';
            });
          },
          selectedColor: AppColors.primaryContainer.withValues(alpha: 0.2),
          checkmarkColor: AppColors.primaryContainer,
          labelStyle: AppTextStyles.textStyleCaption.copyWith(
            color: _filtroActual == 'todas'
                ? AppColors.primaryContainer
                : AppColors.onSurfaceVariant,
          ),
          backgroundColor: AppColors.surfaceContainerLow,
        ),
        const SizedBox(width: AppSpacing.spacingSm),
        FilterChip(
          label: const Text('Pendientes'),
          selected: _filtroActual == 'pendientes',
          onSelected: (selected) {
            setState(() {
              _filtroActual = 'pendientes';
            });
          },
          selectedColor: AppColors.primaryContainer.withValues(alpha: 0.2),
          checkmarkColor: AppColors.primaryContainer,
          labelStyle: AppTextStyles.textStyleCaption.copyWith(
            color: _filtroActual == 'pendientes'
                ? AppColors.primaryContainer
                : AppColors.onSurfaceVariant,
          ),
          backgroundColor: AppColors.surfaceContainerLow,
        ),
        const SizedBox(width: AppSpacing.spacingSm),
        FilterChip(
          label: const Text('Ganadas'),
          selected: _filtroActual == 'ganadas',
          onSelected: (selected) {
            setState(() {
              _filtroActual = 'ganadas';
            });
          },
          selectedColor: AppColors.primaryContainer.withValues(alpha: 0.2),
          checkmarkColor: AppColors.primaryContainer,
          labelStyle: AppTextStyles.textStyleCaption.copyWith(
            color: _filtroActual == 'ganadas'
                ? AppColors.primaryContainer
                : AppColors.onSurfaceVariant,
          ),
          backgroundColor: AppColors.surfaceContainerLow,
        ),
        const SizedBox(width: AppSpacing.spacingSm),
        FilterChip(
          label: const Text('Rechazadas'),
          selected: _filtroActual == 'rechazadas',
          onSelected: (selected) {
            setState(() {
              _filtroActual = 'rechazadas';
            });
          },
          selectedColor: AppColors.error.withValues(alpha: 0.2),
          checkmarkColor: AppColors.error,
          labelStyle: AppTextStyles.textStyleCaption.copyWith(
            color: _filtroActual == 'rechazadas'
                ? AppColors.error
                : AppColors.onSurfaceVariant,
          ),
          backgroundColor: AppColors.surfaceContainerLow,
        ),
      ],
    );
  }

  Widget _buildRequestBentoCard({required Map<String, dynamic> solicitud}) {
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
      detallesVehiculo =
          '${marca['nombre'] ?? ''} ${modelo['nombre'] ?? ''} • ${vehiculo['año'] ?? ''}';
    }

    final String subtitle = (solicitudObj.displayDescription.trim().isNotEmpty)
        ? solicitudObj.displayDescription
        : detallesVehiculo;

    // TODO(geo): la distancia es un placeholder hasta que exista geolocalización
    // de almacén y dirección de entrega.
    const String distance = '2.8 km';

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
      vehicleInfo: subtitle,
      description: 'Cliente: $clienteNombre',
      location: distance,
      status: esUrgente ? 'urgente' : 'estandar',
      createdAt: DateTime.tryParse('$createdAt') ?? DateTime.now(),
      variant: RyPartCardVariant.warehouse,
      showPrice: false,
      customActions: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuotationsCountChip(cantidadCotizaciones),
          const SizedBox(height: AppSpacing.spacingMd),
          RyButton(
            label: 'COTIZAR',
            variant: RyButtonVariant.primary,
            isFullWidth: true,
            onPressed: () => _abrirCotizacion(solicitud),
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
          Text(
            tieneCotizaciones
                ? '$cantidadCotizaciones cotización${cantidadCotizaciones == 1 ? '' : 'es'}'
                : 'Sin cotizaciones aún',
            style: AppTextStyles.textStyleSmall.copyWith(
              color: accent,
              fontWeight: tieneCotizaciones
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirCotizacion(Map<String, dynamic> solicitud) async {
    final bool? vueltaConExito = await context.pushNamed<bool>(
      RouteNames.createQuotation,
      pathParameters: {'solicitudId': solicitud['id'].toString()},
      extra: {'solicitud': solicitud},
    );

    if (vueltaConExito == true && mounted) {
      _cargarSolicitudes();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cotización enviada exitosamente!'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildQuotationCard(Map<String, dynamic> cotizacion) {
    final solicitud =
        cotizacion['solicitudes_repuesto'] as Map<String, dynamic>?;
    final piezaNombre = solicitud?['pieza_nombre'] ?? 'Repuesto desconocido';

    String clienteNombre = 'Cliente desconocido';
    if (solicitud != null) {
      final profiles = solicitud['profiles'] as Map<String, dynamic>?;
      clienteNombre = profiles?['nombre_completo'] ?? 'Cliente desconocido';
    }

    final precio = (cotizacion['precio_venta'] as num?)?.toDouble() ?? 0.0;
    final estado = cotizacion['estado'] ?? 'pendiente';
    final createdAt = cotizacion['created_at'];
    final tiempoEntrega =
        cotizacion['tiempo_entrega_estimado'] ?? 'No especificado';

    // Extract ordenId and estado from ordenes_compra relation
    final ordenesCompra = cotizacion['ordenes_compra'] as Map<String, dynamic>?;
    final String? ordenId = ordenesCompra?['id'] as String?;
    final String? ordenEstado = ordenesCompra?['estado'] as String?;

    // Apply filter
    AppLogger.debug(
      'Filtro actual: $_filtroActual, Estado cotización: $estado, Estado orden: $ordenEstado',
      name: _filterLogName,
    );

    if (_filtroActual == 'pendientes' && estado != 'pendiente') {
      AppLogger.debug(
        'Filtrando cotización (no es pendiente)',
        name: _filterLogName,
      );
      return const SizedBox.shrink();
    }
    if (_filtroActual == 'ganadas') {
      // Solo mostrar cotizaciones aceptadas con estados de orden específicos
      if (estado != 'aceptada') {
        AppLogger.debug(
          'Filtrando cotización (no es aceptada)',
          name: _filterLogName,
        );
        return const SizedBox.shrink();
      }
      // Verificar que el estado de la orden sea uno de los permitidos
      if (ordenEstado == null ||
          ![
            'confirmada',
            'pendiente_pago',
            'entregada',
          ].contains(ordenEstado)) {
        AppLogger.debug(
          'Filtrando cotización (estado de orden no válido: $ordenEstado)',
          name: _filterLogName,
        );
        return const SizedBox.shrink();
      }
      AppLogger.debug(
        'Mostrando cotización ganada (estado orden: $ordenEstado)',
        name: _filterLogName,
      );
    }
    if (_filtroActual == 'rechazadas' && estado != 'rechazada') {
      AppLogger.debug(
        'Filtrando cotización (no es rechazada)',
        name: _filterLogName,
      );
      return const SizedBox.shrink();
    }

    // Determinar estado para RyStatusBadge
    String statusBadge;
    String statusLabel;
    if (estado == 'aceptada' && ordenEstado != null) {
      switch (ordenEstado) {
        case 'pendiente_pago':
          statusBadge = 'pending';
          statusLabel = 'PENDIENTE DE PAGO';
          break;
        case 'confirmada':
          statusBadge = 'info';
          statusLabel = 'CONFIRMADA';
          break;
        case 'entregada':
          statusBadge = 'completed';
          statusLabel = 'ENTREGADA';
          break;
        case 'cancelada':
          statusBadge = 'error';
          statusLabel = 'CANCELADA';
          break;
        default:
          statusBadge = 'completed';
          statusLabel = 'GANADA';
      }
    } else {
      switch (estado) {
        case 'aceptada':
          statusBadge = 'completed';
          statusLabel = 'GANADA';
          break;
        case 'rechazada':
          statusBadge = 'error';
          statusLabel = 'RECHAZADA';
          break;
        default:
          statusBadge = 'pending';
          statusLabel = 'PENDIENTE';
      }
    }

    final cardContent = Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(piezaNombre, style: AppTextStyles.textStyleTitle),
                    const SizedBox(height: AppSpacing.spacingXxs),
                    Text(
                      'Cliente: $clienteNombre',
                      style: AppTextStyles.textStyleSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.spacingSm),
              RyStatusBadge(
                status: statusBadge,
                customLabel: statusLabel,
                style: RyStatusBadgeStyle.filled,
                size: RyStatusBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          Row(
            children: [
              const Icon(
                Icons.attach_money,
                color: AppColors.primaryContainer,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.spacingXxs),
              Text(
                '\$${precio.toStringAsFixed(2)}',
                style: AppTextStyles.textStyleBody.copyWith(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: AppSpacing.spacingLg),
              const Icon(
                Icons.access_time,
                color: AppColors.onSurfaceVariant,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.spacingXxs),
              Text(
                _formatTiempo(createdAt),
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (tiempoEntrega != 'No especificado') ...[
            const SizedBox(height: AppSpacing.spacingXs),
            Row(
              children: [
                const Icon(
                  Icons.schedule,
                  color: AppColors.onSurfaceVariant,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.spacingXxs),
                Text(
                  'Entrega: $tiempoEntrega',
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          if (estado == 'aceptada' && ordenId != null) ...[
            const SizedBox(height: AppSpacing.spacingSm),
            Row(
              children: [
                const Icon(
                  Icons.arrow_forward,
                  color: AppColors.primaryContainer,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.spacingXxs),
                Text(
                  'Ver orden de compra',
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.primaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    // Wrap in InkWell if accepted and has ordenId
    if (estado == 'aceptada' && ordenId != null) {
      return InkWell(
        onTap: () {
          context.pushNamed(
            RouteNames.ordenDetalleAlmacen,
            pathParameters: {'id': ordenId},
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        child: cardContent,
      );
    }

    return cardContent;
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBottomNavItem(Icons.home, 'Home', 0),
          _buildBottomNavItem(Icons.send, 'Cotizaciones', 2),
          _buildBottomNavItem(Icons.store, 'Mi Almacén', 3),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, String label, int index) {
    final bool isActive = _selectedIndex == index;
    return InkWell(
      onTap: () async {
        setState(() {
          _selectedIndex = index;
        });
        if (index == 3) {
          final almacen = await _almacenService.obtenerMiAlmacen();
          if (!mounted) return;
          if (almacen != null) {
            context.pushNamed(RouteNames.profileAlmacen);
          } else {
            context.pushNamed(RouteNames.registerAlmacen);
          }
        }
      },
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingSm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive
                  ? AppColors.primaryContainer
                  : AppColors.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: AppSpacing.spacingXxs),
            Text(
              label,
              style: AppTextStyles.textStyleSmall.copyWith(
                color: isActive
                    ? AppColors.primaryContainer
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
