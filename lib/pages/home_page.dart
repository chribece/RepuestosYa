import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';
import '../services/realtime_notification_service.dart';
import '../providers/solicitudes_provider.dart';
import '../widgets/ry_part_card.dart';
import '../widgets/ry_state_container.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import '../router/route_names.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  Map<String, dynamic> _estadisticas = {};
  Timer? _refreshTimer;

  final SolicitudService _solicitudService = SolicitudService();
  final AuthService _authService = AuthService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
    _suscribirANotificaciones();

    // El SolicitudesProvider ya se inicializa y sincroniza solo al ser creado en MultiProvider
    // Pero forzamos un refresco por seguridad
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SolicitudesProvider>().refreshFromServer();
    });

    // Timer para actualizar el "tiempo transcurrido" en la UI cada minuto
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _suscribirANotificaciones() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final clienteId = user.id;
        RealtimeNotificationService().subscribeToEstadoOrden(clienteId);

        // Usamos el provider para las notificaciones en lugar de llamar a red
        final solicitudes = context.read<SolicitudesProvider>().solicitudes;
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
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spacingMd,
                  vertical: AppSpacing.spacingSm,
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
                    const SizedBox(height: AppSpacing.spacingLg),
                    _buildTrendingSection(),
                    // 40 estaba a la misma distancia de 32 y 48: se toma spacingXl
                    const SizedBox(height: AppSpacing.spacingXl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
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
            onTap: () async {
              Navigator.pop(context);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryContainer,
                  ),
                ),
              );

              try {
                await _authService.signOut();
                if (context.mounted) Navigator.pop(context);
                // El router redirigirá automáticamente a welcome/login al detectar el cambio de estado.
              } catch (e) {
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error al cerrar sesión: '
                        '${ApiErrorHandler.userMessage(e)}',
                      ),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // --- APPBAR SUPERIOR ---
  Widget _buildTopAppBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.menu_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              const SizedBox(width: AppSpacing.spacingXs),
              Text(
                'RepuestosYa',
                style: AppTextStyles.textStyleTitle.copyWith(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
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
              child: const Icon(
                Icons.person,
                color: AppColors.onSurfaceVariant,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- BOTÓN PRINCIPAL DE BÚSQUEDA (HERO ELEMENT) ---
  Widget _buildNewSearchButton() {
    return Container(
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
                  style: AppTextStyles.textStyleBody.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingXxs),
                Text(
                  'Sube una foto y encuentra tu repuesto al instante',
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- FILA DE ESTADÍSTICAS (BENTO GRID) ---
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

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Solicitudes Activas',
                    value: buscandoTxt,
                    icon: Icons.history_rounded,
                    color: AppColors.primaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingSm),
                Expanded(
                  child: _buildStatCard(
                    title: 'Cotizaciones Recibidas',
                    value: cotizadasTxt,
                    icon: Icons.request_quote_rounded,
                    color: AppColors.secondaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spacingSm),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'En Proceso',
                    value: enProcesoTxt,
                    icon: Icons.pending_rounded,
                    color: AppColors.tertiaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingSm),
                Expanded(
                  child: _buildStatCard(
                    title: 'Órdenes Realizadas',
                    value:
                        (_estadisticas['ordenes_realizadas']
                            ?.toString()
                            .padLeft(2, '0') ??
                        '00'),
                    icon: Icons.shopping_cart_rounded,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
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
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.textStyleCaption.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: AppTextStyles.textStyleHeading.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.spacingXs),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
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
                    vehicleInfo: solicitudLocal.synced
                        ? 'Sincronizado'
                        : 'Pendiente de envío',
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
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildTrendingItem(
                icon: Icons.tire_repair_rounded,
                label: 'Neumáticos',
              ),
              const SizedBox(width: AppSpacing.spacingSm),
              _buildTrendingItem(
                icon: Icons.battery_charging_full_rounded,
                label: 'Baterías',
              ),
              const SizedBox(width: AppSpacing.spacingSm),
              _buildTrendingItem(
                icon: Icons.car_crash_rounded,
                label: 'Carrocería',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingItem({required IconData icon, required String label}) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(AppSpacing.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(height: AppSpacing.spacingXs),
          Text(
            label,
            style: AppTextStyles.textStyleCaption.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- BARRA DE NAVEGACIÓN INFERIOR ---
  Widget _buildBottomNavBar() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            isSelected: _selectedIndex == 0,
            onTap: () => setState(() => _selectedIndex = 0),
          ),
          _buildNavItem(
            icon: Icons.search_rounded,
            label: 'Search',
            isSelected: _selectedIndex == 1,
            onTap: () => setState(() => _selectedIndex = 1),
          ),
          _buildNavItem(
            icon: Icons.shopping_cart_rounded,
            label: 'Orders',
            isSelected: _selectedIndex == 2,
            onTap: () {
              setState(() => _selectedIndex = 2);
              context.pushNamed(RouteNames.misOrdenes);
            },
          ),
          _buildNavItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            isSelected: _selectedIndex == 3,
            onTap: () {
              context.pushNamed(RouteNames.profile);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      // Garantiza área táctil de 48×48 dp mínimo WCAG 2.5.5 (antes la
      // Column medía ~46 dp de alto y el ancho dependía del contenido).
      height: 48,
      width: 64,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primaryContainer
                  : AppColors.onSurfaceVariant,
              size: 22,
            ),
            // ajuste fino intencional: separación mínima icono/label en la barra inferior
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.textStyleSmall.copyWith(
                color: isSelected
                    ? AppColors.primaryContainer
                    : AppColors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
