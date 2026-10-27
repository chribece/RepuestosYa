import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/part_catalog.dart';
import '../theme/app_colors.dart';
import '../services/catalog_service.dart';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';
import '../services/realtime_notification_service.dart';
import '../providers/create_request_provider.dart';
import '../providers/solicitudes_provider.dart';
import '../providers/profile_image_provider.dart';
import '../widgets/client_bottom_navigation_bar.dart';
import '../widgets/ry_part_card.dart';
import '../widgets/ry_state_container.dart';
import '../widgets/ry_notification_bell.dart';
import '../widgets/flujo_notificaciones.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import '../utils/ry_snackbar.dart';
import '../router/route_names.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.catalogService});

  final CatalogService? catalogService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentMetricPage = 0;
  final PageController _metricPageController = PageController(
    initialPage: 0,
    keepPage: false,
  );
  int _currentTrendingCategoryPage = 0;
  final PageController _trendingCategoryPageController = PageController(
    initialPage: 0,
    keepPage: false,
  );
  Map<String, dynamic> _estadisticas = {};
  Timer? _refreshTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Estado de conectividad previo para detectar la transición offline →
  /// online y avisar/recargar solo cuando realmente vuelve la red.
  bool _wasOffline = false;

  List<PartCategory> _trendingCategories = [];
  bool _isLoadingTrendingCategories = true;

  late final CatalogService _catalogService =
      widget.catalogService ?? CatalogService();
  final SolicitudService _solicitudService = SolicitudService();
  final AuthService _authService = AuthService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
    _cargarCategoriasTrending();
    _suscribirANotificaciones();
    _initConnectivityWatcher();

    // El SolicitudesProvider ya se inicializa y sincroniza solo al ser creado en MultiProvider
    // Pero forzamos un refresco por seguridad
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SolicitudesProvider>().refreshFromServer();
      if (_authService.currentUser != null) {
        final profileImageProvider = context.read<ProfileImageProvider?>();
        if (profileImageProvider != null) {
          unawaited(profileImageProvider.loadForCurrentUser());
        }
      }
    });

    // Timer para actualizar el "tiempo transcurrido" en la UI cada minuto
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _cargarCategoriasTrending() async {
    var categories = <PartCategory>[];
    try {
      categories = await _catalogService.getPartCategories();
    } catch (error) {
      AppLogger.warning(
        'No se pudieron cargar las categorías populares: $error',
        name: 'HomePage',
      );
    }

    if (!mounted) return;
    setState(() {
      _trendingCategories = categories
          .where((category) => category.id.isNotEmpty)
          .toList(growable: false);
      _isLoadingTrendingCategories = false;
    });
  }

  IconData _iconForTrendingCategory(PartCategory category) {
    final categoryKey = '${category.slug} ${category.nombre}'.toLowerCase();
    if (categoryKey.contains('elect')) {
      return Icons.battery_charging_full_rounded;
    }
    if (categoryKey.contains('filtro')) {
      return Icons.filter_alt_rounded;
    }
    if (categoryKey.contains('motor')) {
      return Icons.settings_rounded;
    }
    if (categoryKey.contains('carrocer')) {
      return Icons.car_crash_rounded;
    }
    if (categoryKey.contains('freno')) {
      return Icons.build_rounded;
    }
    if (categoryKey.contains('suspension')) {
      return Icons.tune_rounded;
    }
    if (categoryKey.contains('lubricante') || categoryKey.contains('fluido')) {
      return Icons.opacity_rounded;
    }
    if (categoryKey.contains('transmision')) {
      return Icons.sync_alt_rounded;
    }
    return Icons.category_outlined;
  }

  void _openTrendingCategory(PartCategory category) {
    context.read<CreateRequestProvider>().prepareNewRequestForCategory(
      category.id,
    );
    context.pushNamed(
      RouteNames.createRequest,
      queryParameters: {'categoryId': category.id},
    );
  }

  /// Escucha los cambios de conectividad. Al volver la red (offline → online)
  /// avisa con un SnackBar y recarga automáticamente "Mis Solicitudes" y las
  /// estadísticas — sin salir de la pantalla ni entrar al listado. Al perderla
  /// avisa que se muestran los datos disponibles.
  void _initConnectivityWatcher() {
    Connectivity().checkConnectivity().then((results) {
      if (mounted) _wasOffline = results.contains(ConnectivityResult.none);
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (!mounted) return;

      final isOffline = results.contains(ConnectivityResult.none);
      final wasOffline = _wasOffline;
      _wasOffline = isOffline;

      if (wasOffline && !isOffline) {
        mostrarSnackbarInfo(
          context,
          mensaje: '¡Has vuelto a tener conexión! Actualizando solicitudes...',
        );
        context.read<SolicitudesProvider>().refreshFromServer();
        _cargarEstadisticas();
      } else if (!wasOffline && isOffline) {
        mostrarSnackbarAdvertencia(
          context,
          mensaje: 'Sin conexión. Se muestran los datos disponibles.',
        );
      }
    });
  }

  Future<void> _suscribirANotificaciones() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Leer el provider ANTES de cualquier await (el uso del contexto a
        // través de un async gap está prohibido por el linter).
        final solicitudesProvider = context.read<SolicitudesProvider>();

        // Permiso de notificaciones dentro del flujo autenticado:
        // fire-and-forget (no bloquea las suscripciones y nunca lanza).
        // Mensaje específico del rol cliente: cotizaciones y estado de orden.
        unawaited(
          solicitarPermisoNotificaciones(
            context,
            mensaje:
                'RepuestosYa te avisa al instante cuando un almacén responde '
                'tu solicitud con una cotización o cuando cambia el estado de '
                'tu orden de compra. ¿Permites las notificaciones?',
          ),
        );

        final clienteId = user.id;
        RealtimeNotificationService().subscribeToEstadoOrden(clienteId);

        // Usamos el provider para las notificaciones en lugar de llamar a red
        final solicitudes = solicitudesProvider.solicitudes;
        if (solicitudes.isNotEmpty) {
          final solicitudIds = solicitudes
              .map((s) => s.id)
              .where((id) => id.isNotEmpty)
              .toList();
          if (solicitudIds.isNotEmpty) {
            await RealtimeNotificationService().subscribeToAllMyRequests(
              solicitudIds,
            );
          }
        }
      }
    } catch (e) {
      AppLogger.error(
        'Error al suscribir a notificaciones',
        name: 'HomePage',
        error: e,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    try {
      final estadisticas = await _solicitudService.obtenerEstadisticasCliente();
      setState(() {
        _estadisticas = estadisticas;
      });
    } catch (e) {
      AppLogger.error(
        'Error al cargar estadísticas',
        name: 'HomePage',
        error: e,
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _metricPageController.dispose();
    _trendingCategoryPageController.dispose();
    RealtimeNotificationService().unsubscribe();
    RealtimeNotificationService().unsubscribeMultiple();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: _buildNavigationDrawer(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('home-main-scroll'),
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.spacingMd,
                  AppSpacing.spacingSm,
                  AppSpacing.spacingMd,
                  100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.spacingSm),
                    _buildNewSearchButton(),
                    const SizedBox(height: AppSpacing.spacingLg),
                    _buildStatsRow(),
                    const SizedBox(height: AppSpacing.spacingLg),
                    _buildRequestsSection(),
                    const SizedBox(height: AppSpacing.spacingXl),
                    _buildTrendingSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ClientBottomNavigationBar(currentIndex: 0),
    );
  }

  // --- DRAWER MODERNO Y LIMPIO ---
  Widget _buildNavigationDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              border: Border(
                bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
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
                const SizedBox(height: AppSpacing.spacingXs),
                Text(
                  'Menú de Opciones',
                  style: AppTextStyles.textStyleCaption.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_rounded, color: AppColors.primary),
            title: Text(
              'Inicio',
              style: AppTextStyles.textStyleBody.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.person_rounded, color: AppColors.primary),
            title: Text(
              'Mi Perfil',
              style: AppTextStyles.textStyleBody.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              context.pushNamed(RouteNames.profile);
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.shopping_cart_outlined,
              color: AppColors.primary,
            ),
            title: Text(
              'Mis Órdenes',
              style: AppTextStyles.textStyleBody.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              context.pushNamed(RouteNames.misOrdenes);
            },
          ),
          const Divider(
            color: AppColors.outlineVariant,
            height: AppSpacing.spacingXl,
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: Text(
              'Cerrar Sesión',
              style: AppTextStyles.textStyleBody.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              _confirmarCierreSesion();
            },
          ),
        ],
      ),
    );
  }

  /// Pide confirmación antes de cerrar la sesión (evita cierres accidentales).
  /// Al confirmar, ejecuta el cierre con indicador de progreso; el router
  /// redirige solo a /welcome al detectar el cambio de estado de auth.
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
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _cerrarSesionConFeedback();
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

  /// Ejecuta el cierre de sesión mostrando un indicador de progreso mientras
  /// se limpia la sesión (token, almacenamiento seguro y DB local).
  Future<void> _cerrarSesionConFeedback() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryContainer),
      ),
    );

    try {
      await _authService.signOut();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        mostrarSnackbarError(
          context,
          mensaje: 'Error al cerrar sesión: ${ApiErrorHandler.userMessage(e)}',
        );
      }
    }
  }

  // --- APPBAR SUPERIOR ---
  Widget _buildTopAppBar() {
    final profileImageUrl = context.watch<ProfileImageProvider?>()?.imageUrl;
    return Container(
      key: const ValueKey('home-top-app-bar'),
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            tooltip: 'Abrir menú',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: AppSpacing.spacingXs),
          Expanded(
            child: Text(
              'RepuestosYa',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.textStyleTitle.copyWith(
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.spacingXs),
          const RyNotificationBell(),
          const SizedBox(width: AppSpacing.spacingXxs),
          InkWell(
            onTap: () {
              context.pushNamed(RouteNames.profile);
            },
            borderRadius: BorderRadius.circular(AppRadius.radiusXl),
            child: Container(
              // 48×48 dp mínimo WCAG 2.5.5 (antes 40×40).
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: CircleAvatar(
                key: const ValueKey('home-profile-avatar'),
                radius: 24,
                backgroundColor: AppColors.surfaceVariant,
                child: ClipOval(
                  child: profileImageUrl != null && profileImageUrl.isNotEmpty
                      ? Image.network(
                          profileImageUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildHomeAvatarFallback(),
                        )
                      : _buildHomeAvatarFallback(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeAvatarFallback() {
    return const SizedBox(
      width: 48,
      height: 48,
      child: Icon(
        Icons.person_rounded,
        color: AppColors.onSurfaceVariant,
        size: 24,
      ),
    );
  }

  // --- BOTÓN PRINCIPAL DE BÚSQUEDA (HERO ELEMENT) ---
  Widget _buildNewSearchButton() {
    return Container(
      key: const ValueKey('hero-search-card'),
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: () async {
            await context.pushNamed(RouteNames.createRequest);
            if (mounted) {
              await context.read<SolicitudesProvider>().refreshFromServer();
              await _cargarEstadisticas();
            }
          },
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.radiusLg),
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [
                  AppColors.primaryContainer.withValues(alpha: 0.15),
                  AppColors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryContainer,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    color: AppColors.primaryContainer,
                    size: 38,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                Text(
                  'NUEVA BÚSQUEDA',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.textStyleBody.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingXxs),
                Padding(
                  // Cuando el subtítulo hace wrap (móvil angosto), el Text
                  // ocupa todo el ancho disponible y, sin padding propio, sus
                  // líneas quedan alineadas al borde izquierdo de la tarjeta.
                  // Este padding + textAlign.center mantienen el texto
                  // centrado y separado de los bordes en cualquier ancho.
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.spacingLg,
                  ),
                  child: Text(
                    'Sube una foto y encuentra tu repuesto al instante',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.textStyleSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- MÉTRICAS COMPACTAS DESLIZABLES ---
  Widget _buildStatsRow() {
    return Consumer<SolicitudesProvider>(
      builder: (context, provider, child) {
        final solicitudes = provider.solicitudes;

        // Usar estadísticas del backend si están disponibles, si no usar cálculo local
        final int buscandoCount =
            _estadisticas['solicitudes_activas'] ??
            solicitudes
                .where(
                  (s) => s.estado == 'en_proceso' || s.estado == 'pendiente',
                )
                .length;
        final int cotizadasCount = _estadisticas['cotizaciones_recibidas'] ?? 0;
        final int enProcesoCount =
            _estadisticas['solicitudes_en_proceso'] ??
            solicitudes
                .where(
                  (s) => s.estado == 'en_proceso' || s.estado == 'pendiente',
                )
                .length;

        final String buscandoTxt = buscandoCount.toString().padLeft(2, '0');
        final String cotizadasTxt = cotizadasCount.toString().padLeft(2, '0');
        final String enProcesoTxt = enProcesoCount.toString().padLeft(2, '0');
        final metrics =
            <({String title, String value, IconData icon, Color color})>[
              (
                title: 'Solicitudes Activas',
                value: buscandoTxt,
                icon: Icons.history_rounded,
                color: AppColors.primaryContainer,
              ),
              (
                title: 'Cotizaciones Recibidas',
                value: cotizadasTxt,
                icon: Icons.request_quote_rounded,
                color: AppColors.secondaryContainer,
              ),
              (
                title: 'En Proceso',
                value: enProcesoTxt,
                icon: Icons.pending_rounded,
                color: AppColors.tertiaryContainer,
              ),
              (
                title: 'Órdenes Realizadas',
                value:
                    (_estadisticas['ordenes_realizadas']?.toString().padLeft(
                      2,
                      '0',
                    ) ??
                    '00'),
                icon: Icons.shopping_cart_rounded,
                color: AppColors.success,
              ),
            ];
        final cardsPerPage = MediaQuery.sizeOf(context).width >= 720 ? 4 : 2;
        final pageCount = (metrics.length + cardsPerPage - 1) ~/ cardsPerPage;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 96,
              child: PageView.builder(
                key: const ValueKey('home-stats-carousel'),
                controller: _metricPageController,
                padEnds: false,
                physics: const BouncingScrollPhysics(
                  parent: PageScrollPhysics(),
                ),
                itemCount: pageCount,
                onPageChanged: (index) {
                  setState(() => _currentMetricPage = index);
                },
                itemBuilder: (context, index) {
                  final pageMetrics = metrics
                      .skip(index * cardsPerPage)
                      .take(cardsPerPage)
                      .toList(growable: false);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (
                        var metricIndex = 0;
                        metricIndex < pageMetrics.length;
                        metricIndex++
                      ) ...[
                        if (metricIndex > 0)
                          const SizedBox(width: AppSpacing.spacingSm),
                        Expanded(
                          child: _buildStatCard(
                            title: pageMetrics[metricIndex].title,
                            value: pageMetrics[metricIndex].value,
                            icon: pageMetrics[metricIndex].icon,
                            color: pageMetrics[metricIndex].color,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            if (pageCount > 1) ...[
              const SizedBox(height: AppSpacing.spacingXs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pageCount,
                  (index) => AnimatedContainer(
                    key: ValueKey('home-stats-dot-$index'),
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == _currentMetricPage ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: index == _currentMetricPage
                          ? AppColors.primaryContainer
                          : AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      key: ValueKey('stat-card-$title'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spacingMd,
        vertical: AppSpacing.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingXxs),
                Text(
                  value,
                  style: AppTextStyles.textStyleTitle.copyWith(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.spacingXs),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ],
      ),
    );
  }

  // --- SECCIÓN DE SOLICITUDES ---
  Widget _buildRequestsSection() {
    return Consumer<SolicitudesProvider>(
      builder: (context, provider, child) {
        final solicitudes = provider.solicitudes;
        final isLoading = provider.isLoading;
        final isOffline = provider.isOffline;
        final lastSync = provider.lastSync;
        final now = DateTime.now();

        // Lógica de banner (igual que en TodasSolicitudesPage)
        final bool isDataOld =
            lastSync != null && now.difference(lastSync).inMinutes >= 10;
        final bool showBanner = isOffline || isDataOld;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mis Solicitudes',
                  style: AppTextStyles.textStyleTitle.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    context.pushNamed(RouteNames.solicitudes);
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.spacingXs,
                      vertical: AppSpacing.spacingXxs,
                    ),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  child: Text(
                    'Ver todas',
                    style: AppTextStyles.textStyleCaption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (showBanner) ...[
              const SizedBox(height: AppSpacing.spacingSm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                child: InkWell(
                  onTap: isOffline ? null : () => provider.refreshFromServer(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: AppSpacing.spacingMd,
                    ),
                    color: isOffline
                        ? AppColors.warning.withValues(alpha: 0.15)
                        : AppColors.success.withValues(alpha: 0.15),
                    child: Row(
                      children: [
                        Icon(
                          isOffline
                              ? Icons.cloud_off_rounded
                              : Icons.cloud_done_rounded,
                          size: 16,
                          color: isOffline
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                        const SizedBox(width: AppSpacing.spacingMd),
                        Expanded(
                          child: Text(
                            isOffline
                                ? 'Modo sin conexión'
                                : 'Datos desactualizados',
                            style: AppTextStyles.textStyleCaption.copyWith(
                              color: isOffline
                                  ? AppColors.warning
                                  : AppColors.success,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (!isOffline)
                          Text(
                            'SINCRONIZAR',
                            style: AppTextStyles.textStyleCaption.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.5,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.spacingMd),
            if (isLoading && solicitudes.isEmpty)
              const RyStateContainer(
                title: 'Cargando solicitudes...',
                type: RyStateType.loading,
              )
            else if (solicitudes.isEmpty)
              const RyStateContainer(
                title: 'Sin solicitudes',
                subtitle: 'Crea tu primera solicitud de repuesto',
                type: RyStateType.empty,
              )
            else
              ...solicitudes.take(3).map((solicitudLocal) {
                final estado = solicitudLocal.estado;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
                  child: RyPartCard(
                    partName: solicitudLocal.piezaNombre,
                    imageUrl: solicitudLocal.fotoUrl,
                    vehicleInfo: null,
                    description: solicitudLocal.descripcion,
                    status: estado,
                    createdAt: solicitudLocal.updatedAt,
                    isSynced: solicitudLocal.synced,
                    variant: RyPartCardVariant.client,
                    onTap: () {
                      if (solicitudLocal.synced) {
                        context.pushNamed(
                          RouteNames.receivedQuotations,
                          pathParameters: {'id': solicitudLocal.id},
                          extra: {
                            'piezaNombre': solicitudLocal.piezaNombre,
                            'fotoUrl': solicitudLocal.fotoUrl,
                          },
                        );
                      }
                    },
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // --- SECCIÓN DE TENDENCIAS ---
  Widget _buildTrendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lo más buscado',
          style: AppTextStyles.textStyleTitle.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        if (_isLoadingTrendingCategories)
          const SizedBox(
            height: 96,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryContainer,
                ),
              ),
            ),
          )
        else if (_trendingCategories.isEmpty)
          SizedBox(
            height: 96,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Categorías no disponibles',
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cardsPerPage = constraints.maxWidth >= 720 ? 4 : 2;
              final pageCount =
                  (_trendingCategories.length + cardsPerPage - 1) ~/
                  cardsPerPage;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 96,
                    child: PageView.builder(
                      key: const ValueKey('home-trending-categories'),
                      controller: _trendingCategoryPageController,
                      padEnds: false,
                      physics: const BouncingScrollPhysics(
                        parent: PageScrollPhysics(),
                      ),
                      itemCount: pageCount,
                      onPageChanged: (index) {
                        setState(() => _currentTrendingCategoryPage = index);
                      },
                      itemBuilder: (context, pageIndex) {
                        final pageCategories = _trendingCategories
                            .skip(pageIndex * cardsPerPage)
                            .take(cardsPerPage)
                            .toList(growable: false);
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (
                              var categoryIndex = 0;
                              categoryIndex < pageCategories.length;
                              categoryIndex++
                            ) ...[
                              if (categoryIndex > 0)
                                const SizedBox(width: AppSpacing.spacingSm),
                              Expanded(
                                child: _buildTrendingItem(
                                  icon: _iconForTrendingCategory(
                                    pageCategories[categoryIndex],
                                  ),
                                  label: pageCategories[categoryIndex].nombre,
                                  onTap: () => _openTrendingCategory(
                                    pageCategories[categoryIndex],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  if (pageCount > 1) ...[
                    const SizedBox(height: AppSpacing.spacingXs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        pageCount,
                        (index) => AnimatedContainer(
                          key: ValueKey('home-trending-dot-$index'),
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: index == _currentTrendingCategoryPage ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: index == _currentTrendingCategoryPage
                                ? AppColors.primaryContainer
                                : AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildTrendingItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      key: ValueKey('home-trending-item-$label'),
      color: AppColors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.spacingSm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: 26),
              const SizedBox(height: AppSpacing.spacingXs),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: AppColors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
