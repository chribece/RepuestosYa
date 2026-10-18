import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/notificacion.dart';
import '../providers/notificaciones_provider.dart';
import '../router/route_names.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/formato_fecha.dart';
import '../utils/ry_snackbar.dart';
import '../widgets/ry_state_container.dart';

class NotificacionesPage extends StatefulWidget {
  const NotificacionesPage({super.key});

  @override
  State<NotificacionesPage> createState() => _NotificacionesPageState();
}

class _NotificacionesPageState extends State<NotificacionesPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificacionesProvider>().cargarInicial();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels < AppSpacing.spacingXxl) {
      context.read<NotificacionesProvider>().cargarMas();
    }
  }

  Future<void> _marcarTodas(NotificacionesProvider provider) async {
    try {
      await provider.marcarTodasLeidas();
    } catch (_) {
      if (mounted) {
        mostrarSnackbarError(
          context,
          mensaje: 'No se pudieron marcar todas como leídas. Intenta de nuevo.',
        );
      }
    }
  }

  Future<void> _abrir(Notificacion item) async {
    final provider = context.read<NotificacionesProvider>();
    try {
      await provider.marcarLeida(item.id);
    } catch (_) {
      if (mounted) {
        mostrarSnackbarError(
          context,
          mensaje: 'No se pudo marcar la notificación como leída.',
        );
      }
      return;
    }
    if (!mounted) return;

    final idSolicitud = _payloadId(item, 'solicitud_id');
    final idOrden = _payloadId(item, 'orden_id');
    try {
      switch (item.tipo) {
        case 'solicitud_nueva':
          if (idSolicitud != null) {
            await context.pushNamed(
              RouteNames.createQuotation,
              pathParameters: {'solicitudId': idSolicitud},
            );
            return;
          }
          break;
        case 'cotizacion_recibida':
          if (idSolicitud != null) {
            await context.pushNamed(
              RouteNames.receivedQuotations,
              pathParameters: {'id': idSolicitud},
            );
            return;
          }
          break;
        case 'orden_creada':
        case 'orden_estado':
          if (idOrden != null) {
            await context.pushNamed(
              RouteNames.ordenDetalle,
              pathParameters: {'id': idOrden},
            );
            return;
          }
          if (item.tipo == 'orden_creada') {
            await context.pushNamed(RouteNames.misOrdenes);
            return;
          }
          break;
        case 'cotizacion_ganada':
          if (idOrden != null) {
            await context.pushNamed(
              RouteNames.ordenDetalleAlmacen,
              pathParameters: {'id': idOrden},
            );
            return;
          }
          await context.pushNamed(RouteNames.dashboard);
          return;
        case 'cotizacion_perdida':
        case 'cotizacion_rechazada':
          await context.pushNamed(RouteNames.dashboard);
          return;
      }
    } catch (_) {
      // A stale/malformed route must not crash the notification list.
    }

    if (mounted) {
      mostrarSnackbarInfo(
        context,
        mensaje:
            'La notificación se marcó como leída, pero no encontramos su destino.',
      );
    }
  }

  String? _payloadId(Notificacion item, String key) {
    final value = item.payload[key]?.toString();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificacionesProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Notificaciones',
          style: AppTextStyles.textStyleTitle.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: Column(
        children: [
          if (provider.unreadCount > 0)
            ListTile(
              minVerticalPadding: AppSpacing.spacingXs,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spacingMd,
              ),
              leading: const Icon(
                Icons.done_all_rounded,
                color: AppColors.primaryContainer,
              ),
              title: Text(
                'Marcar todas como leídas',
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _marcarTodas(provider),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: provider.refrescar,
              child: _buildList(provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(NotificacionesProvider provider) {
    if (provider.isLoading && provider.items.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 280,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (provider.errorMessage != null && provider.items.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 360,
            child: Center(
              child: RyStateContainer(
                title: 'No pudimos cargar tus notificaciones',
                subtitle: provider.errorMessage,
                type: RyStateType.error,
                actionLabel: 'Reintentar',
                onAction: provider.cargarInicial,
              ),
            ),
          ),
        ],
      );
    }

    if (!provider.isLoading && provider.items.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 360,
            child: RyStateContainer(
              title: 'No tienes notificaciones',
              subtitle:
                  'Cuando haya novedades sobre tus solicitudes u órdenes, aparecerán aquí.',
              type: RyStateType.empty,
            ),
          ),
        ],
      );
    }

    final itemCount = provider.items.length + 1;
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == provider.items.length) {
          return _buildFooter(provider);
        }
        final item = provider.items[index];
        return _buildItem(item);
      },
    );
  }

  Widget _buildItem(Notificacion item) {
    final noLeida = !item.estaLeida;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
      child: Material(
        color: noLeida
            ? AppColors.surfaceContainerHigh
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          onTap: () => _abrir(item),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.spacingXxs),
                  child: Semantics(
                    label: noLeida ? 'Sin leer' : 'Leída',
                    child: Icon(
                      noLeida ? Icons.circle : Icons.mark_email_read_outlined,
                      size: noLeida ? 12 : 20,
                      color: noLeida
                          ? AppColors.primaryContainer
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.titulo,
                        style: AppTextStyles.textStyleBody.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: noLeida
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      if (item.mensaje != null &&
                          item.mensaje!.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.spacingXxs),
                        Text(
                          item.mensaje!,
                          style: AppTextStyles.textStyleCaption.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.spacingXs),
                      Text(
                        formatFechaHora(item.createdAt),
                        style: AppTextStyles.textStyleSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingXs),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(NotificacionesProvider provider) {
    if (provider.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.spacingMd),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.loadMoreError != null) {
      return Center(
        child: TextButton(
          onPressed: provider.cargarMas,
          child: Text(
            provider.loadMoreError!,
            style: AppTextStyles.textStyleCaption.copyWith(
              color: AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!provider.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.spacingMd),
        child: Center(
          child: Text(
            'No hay más notificaciones',
            style: AppTextStyles.textStyleCaption.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: AppSpacing.spacingMd);
  }
}
