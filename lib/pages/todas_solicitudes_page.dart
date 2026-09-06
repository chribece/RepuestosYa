import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/realtime_notification_service.dart';
import '../providers/solicitudes_provider.dart';
import '../widgets/ry_part_card.dart';
import '../widgets/ry_state_container.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_logger.dart';
import '../router/route_names.dart';

class TodasSolicitudesPage extends StatefulWidget {
  const TodasSolicitudesPage({super.key});

  @override
  State<TodasSolicitudesPage> createState() => _TodasSolicitudesPageState();
}

class _TodasSolicitudesPageState extends State<TodasSolicitudesPage> {
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    // Refrescar datos del servidor al entrar si hay conexión
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SolicitudesProvider>().refreshFromServer();
    });

    // Suscribirse a notificaciones de cotizaciones para solicitudes activas
    _suscribirANotificaciones();
  }

  Future<void> _suscribirANotificaciones() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Obtenemos las solicitudes desde el provider para saber cuáles suscribir
        final provider = context.read<SolicitudesProvider>();
        final solicitudes = provider.solicitudes;
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
      AppLogger.warning(
        'Error al suscribir a notificaciones: $e',
        name: 'TodasSolicitudes',
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    RealtimeNotificationService().unsubscribeMultiple();
    super.dispose();
  }

  Widget _buildSyncBanner(SolicitudesProvider provider) {
    final lastSync = provider.lastSync;
    final isOffline = provider.isOffline;
    final now = DateTime.now();

    // Si no está offline y los datos son frescos (menos de 10 min), no mostrar banner
    final bool isDataOld =
        lastSync != null && now.difference(lastSync).inMinutes >= 10;

    // Si no hay red, SIEMPRE mostrar banner
    // Si hay red pero los datos son viejos, mostrar banner
    if (!isOffline && !isDataOld) return const SizedBox.shrink();

    String message = 'Modo sin conexión';
    if (isOffline) {
      message = 'Modo sin conexión · Usando datos locales';
    } else if (isDataOld) {
      message = 'Datos desactualizados · Sincroniza para ver cambios';
    }

    return InkWell(
      onTap: isOffline ? null : () => provider.refreshFromServer(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.spacingSm,
          horizontal: AppSpacing.spacingMd,
        ),
        color: isOffline ? Colors.amber.shade100 : Colors.green.shade100,
        child: Row(
          children: [
            Icon(
              isOffline
                  ? Icons.airplanemode_active
                  : Icons.check_circle_outline,
              size: 16,
              color: isOffline ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: AppSpacing.spacingSm),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: isOffline
                      ? Colors.orange.shade900
                      : Colors.green.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!isOffline)
              Text(
                'Sincronizar',
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: Colors.green.shade900,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'nunca';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} horas';
    return 'hace ${diff.inDays} días';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SolicitudesProvider>(
      builder: (context, provider, child) {
        final solicitudes = provider.solicitudes;
        final isLoading = provider.isLoading;
        final isOffline = provider.isOffline;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            title: Text(
              'Todas mis Solicitudes',
              style: AppTextStyles.textStyleTitle,
            ),
            actions: [
              if (provider.lastSync != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.spacingMd),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.spacingMd,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isOffline
                              ? [
                                  SemanticColors.colorSecondaryButton,
                                  AppColors.primaryContainer,
                                ]
                              : [
                                  SemanticColors.colorSuccess,
                                  AppColors.success,
                                ],
                        ),
                        borderRadius: BorderRadius.circular(
                          AppRadius.radiusFull,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (isOffline
                                        ? AppColors.primary
                                        : AppColors.success)
                                    .withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOffline
                                ? Icons.sync_rounded
                                : Icons.check_circle_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getTimeAgo(provider.lastSync),
                            style: AppTextStyles.textStyleCaption.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            iconTheme: const IconThemeData(color: AppColors.onSurface),
            shape: const Border(
              bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
            ),
          ),
          body: Column(
            children: [
              _buildSyncBanner(provider),
              Expanded(
                child: isLoading && solicitudes.isEmpty
                    ? const RyStateContainer(
                        title: 'Cargando solicitudes...',
                        type: RyStateType.loading,
                      )
                    : solicitudes.isEmpty
                    ? RyStateContainer(
                        title: 'Sin solicitudes',
                        subtitle: 'No tienes solicitudes registradas',
                        type: RyStateType.empty,
                        actionLabel: 'Sincronizar ahora',
                        onAction: () => provider.refreshFromServer(),
                      )
                    : RefreshIndicator(
                        onRefresh: () => provider.refreshFromServer(),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(AppSpacing.spacingMd),
                          itemCount: solicitudes.length,
                          itemBuilder: (context, index) {
                            final solicitudLocal = solicitudes[index];
                            final estado = solicitudLocal.estado;

                            // Mapeo a objeto Solicitud para compatibilidad si es necesario
                            // Pero aquí usamos directamente los campos de SolicitudLocal

                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.spacingMd,
                              ),
                              child: RyPartCard(
                                partName: solicitudLocal.piezaNombre,
                                imageUrl: solicitudLocal.fotoUrl,
                                vehicleInfo: solicitudLocal.synced
                                    ? 'Sincronizado'
                                    : 'Pendiente de envío',
                                description: solicitudLocal.descripcion,
                                status: estado,
                                createdAt: solicitudLocal
                                    .updatedAt, // Marca temporal del SERVIDOR
                                isSynced: solicitudLocal.synced,
                                variant: RyPartCardVariant.client,
                                onTap: () {
                                  if (solicitudLocal.synced) {
                                    context.pushNamed(
                                      RouteNames.receivedQuotations,
                                      pathParameters: {'id': solicitudLocal.id},
                                      extra: {
                                        'piezaNombre':
                                            solicitudLocal.piezaNombre,
                                      },
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
