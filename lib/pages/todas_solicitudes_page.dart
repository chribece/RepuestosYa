import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';
import '../services/realtime_notification_service.dart';
import '../widgets/ry_part_card.dart';
import '../widgets/ry_state_container.dart';
import '../theme/app_spacing.dart';
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
  final SolicitudService _solicitudService = SolicitudService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _solicitudes = [];
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
        _cargarMasSolicitudes();
      }
    });

    // Suscribirse a notificaciones de cotizaciones para solicitudes activas
    _suscribirANotificaciones();
  }

  Future<void> _suscribirANotificaciones() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final clienteId = user.id;
        // Usar obtenerSolicitudesCliente para obtener solo las del cliente actual
        // obtenerSolicitudesActivas() es solo para almacenes (/requests/active)
        final solicitudes = await _solicitudService.obtenerSolicitudesCliente(
          clienteId,
        );
        if (solicitudes.isNotEmpty) {
          final solicitudIds = solicitudes
              .map((s) => s['id']?.toString() ?? '')
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

  Future<void> _cargarPrimeraPagina() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final solicitudes = await _solicitudService.obtenerSolicitudesPaginadas(
          clienteId: user.id,
          page: 1,
          limit: _limitePorPagina,
        );
        setState(() {
          _solicitudes = solicitudes;
          _paginaActual = 1;
          _hayMasDatos = solicitudes.length == _limitePorPagina;
        });
      }
    } catch (e) {
      AppLogger.warning(
        'Error al cargar primera página: $e',
        name: 'TodasSolicitudes',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarMasSolicitudes() async {
    if (_cargandoMas || !_hayMasDatos) return;

    setState(() => _cargandoMas = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final siguientePagina = _paginaActual + 1;
        final nuevasSolicitudes = await _solicitudService
            .obtenerSolicitudesPaginadas(
              clienteId: user.id,
              page: siguientePagina,
              limit: _limitePorPagina,
            );

        setState(() {
          if (nuevasSolicitudes.isEmpty) {
            _hayMasDatos = false;
          } else {
            _paginaActual = siguientePagina;
            _solicitudes.addAll(nuevasSolicitudes);
            if (nuevasSolicitudes.length < _limitePorPagina) {
              _hayMasDatos = false;
            }
          }
        });
      }
    } catch (e) {
      AppLogger.warning(
        'Error al cargar más solicitudes: $e',
        name: 'TodasSolicitudes',
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
        title: Text(
          'Todas mis Solicitudes',
          style: AppTextStyles.textStyleTitle,
        ),
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        shape: const Border(
          bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      body: _isLoading
          ? const RyStateContainer(
              title: 'Cargando solicitudes...',
              type: RyStateType.loading,
            )
          : _solicitudes.isEmpty
          ? const RyStateContainer(
              title: 'Sin solicitudes',
              subtitle: 'No tienes solicitudes registradas',
              type: RyStateType.empty,
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.spacingMd),
              itemCount: _solicitudes.length + (_cargandoMas ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _solicitudes.length) {
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

                final solicitud = _solicitudes[index];
                final solicitudObj = Solicitud(solicitud);
                final estado = solicitud['estado'] as String? ?? 'en_proceso';
                final createdAt = solicitud['created_at'] as String?;
                final urlFinal =
                    solicitud['image_url'] ?? solicitud['foto_url'] ?? '';
                final piezaNombreFinal = solicitudObj.displayPartName;
                final descripcion = solicitudObj.displayDescription;

                DateTime? createdAtDate;
                if (createdAt != null) {
                  createdAtDate = DateTime.parse(createdAt);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
                  child: RyPartCard(
                    partName: piezaNombreFinal,
                    imageUrl: urlFinal,
                    vehicleInfo: descripcion,
                    status: estado,
                    createdAt: createdAtDate ?? DateTime.now(),
                    variant: RyPartCardVariant.client,
                    onTap: () {
                      context.pushNamed(
                        RouteNames.receivedQuotations,
                        pathParameters: {'id': solicitud['id'].toString()},
                        extra: {
                          'piezaNombre': piezaNombreFinal,
                          'fotoUrl': urlFinal.isNotEmpty ? urlFinal : null,
                        },
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
