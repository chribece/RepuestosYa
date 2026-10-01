import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/realtime_notification_service.dart';
import '../services/outbox.dart';
import '../services/sync_engine.dart';
import '../services/solicitud_repository.dart';
import '../services/solicitud_service.dart';
import '../providers/solicitudes_provider.dart';
import '../widgets/ry_part_card.dart';
import '../widgets/ry_state_container.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import '../router/route_names.dart';

class TodasSolicitudesPage extends StatefulWidget {
  const TodasSolicitudesPage({super.key, this.solicitudService});

  /// Servicio inyectable para widget tests (mismo patrón que el
  /// WarehouseDashboard): en producción se usa la instancia real.
  final SolicitudService? solicitudService;

  @override
  State<TodasSolicitudesPage> createState() => _TodasSolicitudesPageState();
}

class _TodasSolicitudesPageState extends State<TodasSolicitudesPage> {
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();
  late final SolicitudService _solicitudService =
      widget.solicitudService ?? SolicitudService();
  Timer? _refreshTimer;
  Future<List<OutboxData>>? _errorItemsFuture;

  @override
  void initState() {
    super.initState();

    // Refrescar datos del servidor al entrar si hay conexión
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SolicitudesProvider>().refreshFromServer();
      _refreshErrorItems();
    });

    // Suscribirse a notificaciones de cotizaciones para solicitudes activas
    _suscribirANotificaciones();

    // Timer para actualizar el "tiempo transcurrido" en la UI cada minuto
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) return;
      setState(() {});
      _refreshErrorItems();
    });
  }

  void _refreshErrorItems() {
    if (!mounted) return;
    setState(() {
      _errorItemsFuture = context.read<OutboxService>().itemsConError();
    });
  }

  Future<void> _retryOutboxItem(OutboxData item) async {
    final outbox = context.read<OutboxService>();
    final syncEngine = context.read<SyncEngine>();
    await outbox.reintentar(item);
    await syncEngine.procesarCola();
    if (!mounted) return;
    _refreshErrorItems();
  }

  Future<void> _discardOutboxItem(OutboxData item) async {
    final outbox = context.read<OutboxService>();
    await outbox.descartar(item);
    if (!mounted) return;
    _refreshErrorItems();
  }

  Widget _buildOutboxErrors() {
    final future = _errorItemsFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<List<OutboxData>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <OutboxData>[];
        if (items.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.spacingMd,
            AppSpacing.spacingSm,
            AppSpacing.spacingMd,
            0,
          ),
          child: Column(
            children: items.map((item) {
              final isDead = item.status == 'DEAD';
              return Card(
                color: AppColors.error.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.spacingSm),
                  child: Row(
                    children: [
                      Icon(
                        isDead ? Icons.error_outline : Icons.sync_problem,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: AppSpacing.spacingSm),
                      Expanded(
                        child: Text(
                          '${isDead ? 'Sincronización detenida' : 'Sincronización pendiente'}\n${item.lastError ?? 'Error desconocido'}',
                          style: AppTextStyles.textStyleCaption,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Reintentar',
                        onPressed: () => _retryOutboxItem(item),
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        tooltip: 'Descartar',
                        onPressed: () => _discardOutboxItem(item),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
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
    _refreshTimer?.cancel();
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
          vertical: 12,
          horizontal: AppSpacing.spacingMd,
        ),
        color: isOffline
            ? AppColors.warning.withValues(alpha: 0.15)
            : AppColors.success.withValues(alpha: 0.2),
        child: Row(
          children: [
            Icon(
              isOffline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
              size: 20,
              color: isOffline ? AppColors.warning : AppColors.success,
            ),
            const SizedBox(width: AppSpacing.spacingMd),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: isOffline ? AppColors.warning : AppColors.success,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            if (!isOffline)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'SINCRONIZAR',
                  style: AppTextStyles.textStyleCaption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Navegación compartida entre el tap de la tarjeta y la acción de swipe
  /// "Ver detalle" (misma ruta que el tap actual). No navega si la solicitud
  /// aún no se sincronizó con el servidor.
  void _abrirDetalleSolicitud(
    BuildContext context,
    SolicitudLocal solicitudLocal,
  ) {
    if (!solicitudLocal.synced) return;
    context.pushNamed(
      RouteNames.receivedQuotations,
      pathParameters: {'id': solicitudLocal.id},
      extra: {'piezaNombre': solicitudLocal.piezaNombre},
    );
  }

  /// Acción de swipe "Ver detalle" con los tokens del Design System
  /// (fondo `secondaryContainer`, texto `onSurface`, `textStyleSmall`).
  Widget _buildVerDetalleAction(VoidCallback onPressed) {
    return CustomSlidableAction(
      onPressed: (_) => onPressed(),
      backgroundColor: AppColors.secondaryContainer,
      foregroundColor: AppColors.onSurface,
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXxs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.visibility_outlined, size: 22),
          const SizedBox(height: AppSpacing.spacingXxs),
          Text(
            'Detalle',
            style: AppTextStyles.textStyleSmall.copyWith(
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// Acción de swipe "Cancelar" con los tokens del Design System (fondo
  /// `error`, texto blanco `onErrorText`, `textStyleSmall`). Se revela en el
  /// panel IZQUIERDO (deslizar el contenido hacia la DERECHA), es decir el
  /// `startActionPane` del Slidable.
  Widget _buildCancelarAction(VoidCallback onPressed) {
    return CustomSlidableAction(
      onPressed: (_) => onPressed(),
      backgroundColor: AppColors.error,
      foregroundColor: SemanticColors.colorOnErrorText,
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXxs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.close, size: 22),
          const SizedBox(height: AppSpacing.spacingXxs),
          Text(
            'Cancelar',
            style: AppTextStyles.textStyleSmall.copyWith(
              color: SemanticColors.colorOnErrorText,
            ),
          ),
        ],
      ),
    );
  }

  /// Regla de UI para ofrecer "Cancelar": la lista local no trae el conteo
  /// de cotizaciones, así que la condición usa el estado de la solicitud
  /// (pendiente/activa = aún no respondida por ningún almacén). La regla
  /// dura la valida el backend al cancelar (rechaza si ya existen
  /// cotizaciones); la app muestra el mensaje del servidor y refresca.
  bool _puedeCancelar(SolicitudLocal solicitudLocal) {
    if (!solicitudLocal.synced) return false;
    return solicitudLocal.estado == 'en_proceso' ||
        solicitudLocal.estado == 'pendiente';
  }

  /// Control visible alternativo al gesto de cancelar (accesibilidad:
  /// ninguna acción queda solo detrás del swipe). Es un menú "⋮" en la
  /// esquina de la tarjeta con el ítem "Cancelar solicitud". Sin conexión
  /// el ítem sigue presente pero al tocarlo avisa que se necesita conexión
  /// (la cancelación no se encola en el Outbox: es un cambio de estado que
  /// el servidor debe validar).
  Widget _buildCardMenu(SolicitudLocal solicitudLocal) {
    return PopupMenuButton<String>(
      tooltip: 'Opciones de la solicitud',
      icon: const Icon(Icons.more_vert, color: AppColors.onSurfaceVariant),
      onSelected: (value) {
        if (value == 'cancelar') {
          _cancelarSolicitud(solicitudLocal);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'cancelar', child: Text('Cancelar solicitud')),
      ],
    );
  }

  /// Confirmación obligatoria antes de cancelar (mismo patrón Material que
  /// "Eliminar vehículo" / "Eliminar dirección").
  Future<bool> _confirmarCancelacion(SolicitudLocal solicitudLocal) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: Text('Confirmar', style: AppTextStyles.textStyleTitle),
        content: Text(
          '¿Estás seguro de cancelar la solicitud "${solicitudLocal.piezaNombre}"?',
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'No',
              style: AppTextStyles.textStyleButton.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Sí, cancelar',
              style: AppTextStyles.textStyleButton.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmado ?? false;
  }

  /// Flujo de cancelación: confirmación → PATCH al servidor → refresco.
  /// Sin conexión NO se encola en el Outbox (decisión de la fase): se avisa
  /// que se necesita conexión. Si el servidor rechaza (p. ej. 409 porque la
  /// solicitud ya fue respondida), se muestra su mensaje tal cual y se
  /// refresca la lista para reflejar el estado real.
  Future<void> _cancelarSolicitud(SolicitudLocal solicitudLocal) async {
    final provider = context.read<SolicitudesProvider>();

    if (provider.isOffline) {
      _mostrarMensaje('Necesitas conexión para cancelar la solicitud.');
      return;
    }

    final confirmado = await _confirmarCancelacion(solicitudLocal);
    if (!confirmado || !mounted) return;

    try {
      await _solicitudService.cancelarSolicitud(solicitudLocal.id);
      if (!mounted) return;
      _mostrarMensaje('Solicitud cancelada');
      // Refrescar para reflejar el nuevo estado (la fila local se
      // re-sincroniza desde el servidor).
      unawaited(provider.refreshFromServer());
    } on ApiException catch (e) {
      if (!mounted) return;
      // Regla dura del backend (p. ej. ya respondida): mostrar el mensaje
      // del servidor y refrescar en lugar de un error genérico.
      _mostrarMensaje(e.message);
      unawaited(provider.refreshFromServer());
    } catch (e) {
      if (!mounted) return;
      _mostrarMensaje(ApiErrorHandler.userMessage(e));
    }
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
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
              _buildOutboxErrors(),
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

                            final tarjeta = RyPartCard(
                              partName: solicitudLocal.piezaNombre,
                              imageUrl: solicitudLocal.fotoUrl,
                              vehicleInfo: null,
                              description: solicitudLocal.descripcion,
                              status: estado,
                              createdAt: solicitudLocal
                                  .updatedAt, // Marca temporal del SERVIDOR
                              isSynced: solicitudLocal.synced,
                              variant: RyPartCardVariant.client,
                              onTap: () => _abrirDetalleSolicitud(
                                context,
                                solicitudLocal,
                              ),
                            );

                            // Mapeo de gestos del Slidable (regla de la fase):
                            // - deslizar a la IZQUIERDA (contenido se corre a la
                            //   izquierda → se revela el panel DERECHO) =
                            //   endActionPane = "Detalle".
                            // - deslizar a la DERECHA (contenido se corre a la
                            //   derecha → se revela el panel IZQUIERDO) =
                            //   startActionPane = "Cancelar".
                            // El swipe "Ver detalle" replica la navegación del
                            // tap. Los items sin sincronizar (Outbox pendiente)
                            // no llevan swipe, igual que su tap deshabilitado:
                            // no se puede navegar a un detalle que no existe en
                            // el servidor todavía.
                            // "Cancelar" solo se ofrece si la solicitud está
                            // activa y hay conexión (sin conexión no se encola
                            // en el Outbox; el aviso llega por el menú "⋮").
                            final puedeCancelar = _puedeCancelar(
                              solicitudLocal,
                            );
                            final tarjetaConMenu = puedeCancelar
                                ? Stack(
                                    children: [
                                      tarjeta,
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: _buildCardMenu(solicitudLocal),
                                      ),
                                    ],
                                  )
                                : tarjeta;

                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.spacingMd,
                              ),
                              child: solicitudLocal.synced
                                  ? Slidable(
                                      key: ValueKey(
                                        'solicitud-${solicitudLocal.id}',
                                      ),
                                      endActionPane: ActionPane(
                                        motion: const DrawerMotion(),
                                        extentRatio: 0.34,
                                        children: [
                                          _buildVerDetalleAction(
                                            () => _abrirDetalleSolicitud(
                                              context,
                                              solicitudLocal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      startActionPane:
                                          puedeCancelar && !isOffline
                                          ? ActionPane(
                                              motion: const DrawerMotion(),
                                              extentRatio: 0.34,
                                              children: [
                                                _buildCancelarAction(
                                                  () => _cancelarSolicitud(
                                                    solicitudLocal,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : null,
                                      child: tarjetaConMenu,
                                    )
                                  : tarjeta,
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
