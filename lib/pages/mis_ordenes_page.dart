import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_state_container.dart';
import '../widgets/ry_status_badge.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_logger.dart';
import '../router/route_names.dart';

class MisOrdenesPage extends StatefulWidget {
  const MisOrdenesPage({super.key});

  @override
  State<MisOrdenesPage> createState() => _MisOrdenesPageState();
}

class _MisOrdenesPageState extends State<MisOrdenesPage> {
  final ScrollController _scrollController = ScrollController();
  final SolicitudService _solicitudService = SolicitudService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _ordenes = [];
  bool _isLoading = false;
  bool _cargandoMas = false;
  bool _hayMasDatos = true;
  int _paginaActual = 1;
  final int _limitePorPagina = 10;

  @override
  void initState() {
    super.initState();
    _cargarPrimeraPagina();

    // Listener para detectar el scroll infinito
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.85) {
        _cargarMasOrdenes();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarPrimeraPagina() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final ordenes = await _solicitudService.obtenerMisOrdenes(
          page: 1,
          limit: _limitePorPagina,
        );
        setState(() {
          _ordenes = ordenes;
          _paginaActual = 1;
          _hayMasDatos = ordenes.length == _limitePorPagina;
        });
      }
    } catch (e) {
      AppLogger.error(
        'Error al cargar primera página',
        name: 'MisOrdenesPage',
        error: e,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarMasOrdenes() async {
    if (_cargandoMas || !_hayMasDatos) return;

    setState(() => _cargandoMas = true);
    try {
      final siguientePagina = _paginaActual + 1;
      final nuevasOrdenes = await _solicitudService.obtenerMisOrdenes(
        page: siguientePagina,
        limit: _limitePorPagina,
      );

      setState(() {
        if (nuevasOrdenes.isEmpty) {
          _hayMasDatos = false;
        } else {
          _paginaActual = siguientePagina;
          _ordenes.addAll(nuevasOrdenes);
          if (nuevasOrdenes.length < _limitePorPagina) {
            _hayMasDatos = false;
          }
        }
      });
    } catch (e) {
      AppLogger.error(
        'Error al cargar más órdenes',
        name: 'MisOrdenesPage',
        error: e,
      );
    } finally {
      setState(() => _cargandoMas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Mis Órdenes', style: AppTextStyles.textStyleTitle),
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        shape: const Border(
          bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      body: _isLoading
          ? const RyStateContainer(
              title: 'Cargando órdenes...',
              type: RyStateType.loading,
            )
          : _ordenes.isEmpty
          ? const RyStateContainer(
              title: 'Sin órdenes',
              subtitle: 'No tienes órdenes registradas',
              type: RyStateType.empty,
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.spacingMd),
              itemCount: _ordenes.length + (_cargandoMas ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _ordenes.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppSpacing.spacingMd,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  );
                }

                final orden = _ordenes[index];
                final estado = orden['estado'] as String? ?? 'pendiente';
                final createdAt = orden['created_at'] as String?;

                DateTime? createdAtDate;
                if (createdAt != null) {
                  createdAtDate = DateTime.parse(createdAt);
                }

                final cotizacion =
                    orden['cotizaciones'] as Map<String, dynamic>?;
                final solicitud =
                    orden['solicitudes_repuesto'] as Map<String, dynamic>?;
                final almacen =
                    cotizacion?['almacenes'] as Map<String, dynamic>?;

                final precio =
                    cotizacion?['precio_venta']?.toString() ?? '0.00';
                final piezaNombre =
                    solicitud?['repuesto_nombre_snapshot'] ??
                    solicitud?['pieza_nombre'] as String? ??
                    'Repuesto';
                final almacenNombre =
                    almacen?['nombre_comercial'] as String? ?? 'Almacén';

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
                  child: _buildOrdenCard(
                    ordenId: orden['id'].toString(),
                    title: piezaNombre,
                    almacen: almacenNombre,
                    precio: precio,
                    status: estado,
                    createdAt: createdAtDate,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildOrdenCard({
    required String ordenId,
    required String title,
    required String almacen,
    required String precio,
    required String status,
    DateTime? createdAt,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: AppTextStyles.textStyleBody)),
              RyStatusBadge(
                status: status,
                style: RyStatusBadgeStyle.filled,
                size: RyStatusBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Row(
            children: [
              const Icon(
                Icons.store,
                color: AppColors.onSurfaceVariant,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.spacingXxs),
              Text(
                almacen,
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingXxs),
          Row(
            children: [
              const Icon(
                Icons.attach_money,
                color: AppColors.onSurfaceVariant,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.spacingXxs),
              Text(
                '\$$precio',
                style: AppTextStyles.textStyleBody.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (createdAt != null)
                Text(
                  _formatTime(createdAt),
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              RyButton(
                label: 'Ver Detalles',
                variant: RyButtonVariant.primary,
                size: RyButtonSize.small,
                onPressed: () {
                  context.pushNamed(
                    RouteNames.ordenDetalle,
                    pathParameters: {'id': ordenId},
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inHours < 1) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else {
      return 'Hace ${difference.inDays} días';
    }
  }
}
