import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../services/solicitud_service.dart';
import '../widgets/ry_state_container.dart';
import '../widgets/warehouse_request_card.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/ry_snackbar.dart';
import '../router/route_names.dart';

/// Listado completo de solicitudes disponibles del almacén ("Ver todas" del
/// panel principal). Sin el límite de vista previa del Home: carga todo el
/// feed que devuelve el backend, ordenado de más nueva a más antigua.
class WarehouseRequestsPage extends StatefulWidget {
  const WarehouseRequestsPage({super.key, this.solicitudService});

  /// Servicio inyectable para widget tests (mismo patrón que el dashboard).
  final SolicitudService? solicitudService;

  @override
  State<WarehouseRequestsPage> createState() => _WarehouseRequestsPageState();
}

class _WarehouseRequestsPageState extends State<WarehouseRequestsPage> {
  late final SolicitudService _solicitudService =
      widget.solicitudService ?? SolicitudService();

  List<Map<String, dynamic>> _solicitudes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final solicitudes = await _solicitudService.obtenerSolicitudesActivas();
      if (!mounted) return;
      setState(() {
        _solicitudes = List<Map<String, dynamic>>.from(solicitudes);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = ApiErrorHandler.userMessage(e);
      });
    }
  }

  Future<void> _abrirCotizacion(Map<String, dynamic> solicitud) async {
    final bool? vueltaConExito = await context.pushNamed<bool>(
      RouteNames.createQuotation,
      pathParameters: {'solicitudId': solicitud['id'].toString()},
      extra: {'solicitud': solicitud},
    );

    if (vueltaConExito == true && mounted) {
      _cargar();
      mostrarSnackbarExito(
        context,
        mensaje: '¡Cotización enviada exitosamente!',
        duracion: const Duration(seconds: 2),
      );
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const RyStateContainer(
        title: 'Cargando solicitudes...',
        type: RyStateType.loading,
      );
    }
    if (_error != null) {
      return RyStateContainer(
        title: 'No se pudieron cargar las solicitudes',
        subtitle: _error,
        type: RyStateType.error,
      );
    }
    if (_solicitudes.isEmpty) {
      return const RyStateContainer(
        title: 'Sin solicitudes',
        subtitle:
            'No hay solicitudes activas. Las nuevas peticiones de los clientes aparecerán aquí.',
        type: RyStateType.empty,
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      itemCount: _solicitudes.length,
      itemBuilder: (context, index) {
        final solicitud = _solicitudes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
          child: WarehouseRequestCard(
            solicitud: solicitud,
            onCotizar: () => _abrirCotizacion(solicitud),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryContainer),
          tooltip: 'Regresar',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Solicitudes Disponibles',
          style: AppTextStyles.textStyleTitle,
        ),
      ),
      body: _isLoading && _solicitudes.isEmpty
          ? _buildBody()
          : RefreshIndicator(
              onRefresh: _cargar,
              color: AppColors.primaryContainer,
              backgroundColor: AppColors.surfaceContainerHigh,
              child: _buildBody(),
            ),
    );
  }
}
