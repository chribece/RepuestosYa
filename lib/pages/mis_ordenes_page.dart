import 'package:flutter/material.dart';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';
import 'orden_compra_page.dart';

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

  // Estilos y colores idénticos a tu HomePage
  static const Color background = Color(0xFF131313);
  static const Color primaryContainer = Color(0xFFFF5722);
  static const Color outlineVariant = Color(0xFF5B4039);
  static const Color onSurfaceVariant = Color(0xFFE4BEB4);
  static const Color secondaryContainer = Color(0xFF1E95F2);
  static const Color surfaceVariant = Color(0xFF353534);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);

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
      print('Error al cargar primera página: $e');
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
      print('Error al cargar más órdenes: $e');
    } finally {
      setState(() => _cargandoMas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        title: const Text(
          'Mis Órdenes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const Border(
          bottom: BorderSide(color: outlineVariant, width: 1),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryContainer),
            )
          : _ordenes.isEmpty
          ? const Center(
              child: Text(
                'No tienes órdenes registradas',
                style: TextStyle(color: onSurfaceVariant),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _ordenes.length + (_cargandoMas ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _ordenes.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(color: primaryContainer),
                    ),
                  );
                }

                final orden = _ordenes[index];
                final estado = orden['estado'] as String? ?? 'pendiente';
                Color statusColor = primaryContainer;
                String statusText = estado;

                switch (estado) {
                  case 'pendiente':
                    statusColor = primaryContainer;
                    statusText = 'Pendiente';
                    break;
                  case 'en_proceso':
                    statusColor = secondaryContainer;
                    statusText = 'En Proceso';
                    break;
                  case 'completado':
                    statusColor = Colors.green;
                    statusText = 'Completado';
                    break;
                  case 'cancelado':
                    statusColor = Colors.red;
                    statusText = 'Cancelado';
                    break;
                }

                final createdAt = orden['created_at'] as String?;
                String timeText = 'Reciente';
                if (createdAt != null) {
                  final date = DateTime.parse(createdAt);
                  final difference = DateTime.now().difference(date);
                  if (difference.inHours < 1) {
                    timeText = 'Hace ${difference.inMinutes} min';
                  } else if (difference.inHours < 24) {
                    timeText = 'Hace ${difference.inHours}h';
                  } else if (difference.inDays == 1) {
                    timeText = 'Ayer';
                  } else {
                    timeText = 'Hace ${difference.inDays} días';
                  }
                }

                // Obtener datos de la cotización y solicitud
                final cotizacion =
                    orden['cotizaciones'] as Map<String, dynamic>?;
                final solicitud =
                    orden['solicitudes_repuesto'] as Map<String, dynamic>?;
                final almacen =
                    cotizacion?['almacenes'] as Map<String, dynamic>?;

                final precio =
                    cotizacion?['precio_venta']?.toString() ?? '0.00';
                final piezaNombre =
                    solicitud?['pieza_nombre'] as String? ?? 'Repuesto';
                final almacenNombre =
                    almacen?['nombre_comercial'] as String? ?? 'Almacén';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildOrdenCard(
                    ordenId: orden['id'].toString(),
                    title: piezaNombre,
                    almacen: almacenNombre,
                    precio: precio,
                    status: statusText,
                    statusColor: statusColor,
                    time: timeText,
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
    required Color statusColor,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.store, color: onSurfaceVariant, size: 16),
              const SizedBox(width: 4),
              Text(
                almacen,
                style: const TextStyle(color: onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.attach_money, color: onSurfaceVariant, size: 16),
              const SizedBox(width: 4),
              Text(
                '\$$precio',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                time,
                style: const TextStyle(color: onSurfaceVariant, fontSize: 12),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrdenCompraPage(),
                      settings: RouteSettings(arguments: ordenId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryContainer,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Ver Detalles',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
