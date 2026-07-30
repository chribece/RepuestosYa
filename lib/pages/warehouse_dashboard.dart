import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'login_page.dart';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';
import '../services/almacen_service.dart';
import 'create_quotation_page.dart';
import 'perfil_almacen_page.dart';
import 'register_almacen_page.dart';
import 'almacen_orden_detalle_page.dart';

class WarehouseDashboard extends StatefulWidget {
  const WarehouseDashboard({super.key});

  @override
  State<WarehouseDashboard> createState() => _WarehouseDashboardState();
}

class _WarehouseDashboardState extends State<WarehouseDashboard> {
  // Configuración de Colores basada en tu JSON de Tailwind
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF131313);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color surfaceVariant = Color(0xFF353534);
  static const Color cardBackground = Color(0xFF1E1E1E);

  static const Color primaryContainer = Color(0xFFFF5722);
  static const Color onPrimaryContainer = Color(0xFF541200);
  static const Color primary = Color(0xFFFFB5A0);
  static const Color secondary = Color(0xFF9ECAFF);
  static const Color outlineVariant = Color(0xFF5B4039);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFE4BEB4);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final SolicitudService _solicitudService = SolicitudService();
  final AuthService _authService = AuthService();
  final AlmacenService _almacenService = AlmacenService();

  bool _isOpen = true;
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _solicitudes = [];
  List<Map<String, dynamic>> _cotizacionesEnviadas = [];
  bool _isLoadingSolicitudes = false;
  bool _isLoadingCotizaciones = false;
  String? _nombreAlmacen;
  String _filtroActual = 'todas';

  // Variables dinámicas para el panel de estadísticas Bento
  final int _ventasCount = 42;
  final int _vistasCount = 850;

  @override
  void initState() {
    super.initState();
    _cargarSolicitudes();
    _cargarAlmacen();
    _cargarCotizacionesEnviadas();
  }

  Future<void> _cargarAlmacen() async {
    try {
      final almacen = await _almacenService.obtenerMiAlmacen();
      if (mounted) {
        setState(() {
          _nombreAlmacen = almacen?['nombre_comercial'] ?? 'Mi Almacén';
        });
      }
    } catch (e) {
      print(
        'Error al cargar almacén: $e',
      ); // ← esto te habría mostrado el 404 de inmediato
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
          _cotizacionesEnviadas = List<Map<String, dynamic>>.from(
            cotizaciones ?? [],
          );
          _isLoadingCotizaciones = false;
        });
      }
    } catch (e) {
      print('Error al cargar cotizaciones enviadas: $e');
      if (mounted) {
        setState(() => _isLoadingCotizaciones = false);
      }
    }
  }

  // Carga asíncrona robusta con casteo seguro para evitar excepciones de tipo en Flutter
  Future<void> _cargarSolicitudes() async {
    setState(() {
      _isLoadingSolicitudes = true;
    });
    try {
      final solicitudes = await _solicitudService.obtenerSolicitudesActivas();
      print('Solicitudes cargadas: ${solicitudes?.length ?? 0}');
      for (var sol in solicitudes ?? []) {
        print('Solicitud ID: ${sol['id']}, Pieza: ${sol['pieza_nombre']}');
      }
      setState(() {
        // Mapeamos de forma segura la lista dinámica para evitar incompatibilidades de tipos
        _solicitudes = List<Map<String, dynamic>>.from(solicitudes ?? []);
        _isLoadingSolicitudes = false;
      });
    } catch (e) {
      print('Error al cargar solicitudes: $e');
      setState(() {
        _isLoadingSolicitudes = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar solicitudes: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: background,

      drawer: Drawer(
        child: Container(
          color: background,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: surfaceContainerHigh,
                  border: Border(
                    bottom: BorderSide(color: outlineVariant, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'RepuestosYa',
                      style: TextStyle(
                        color: primaryContainer,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Sora',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Panel de Control (Almacén)',
                      style: TextStyle(color: onSurfaceVariant, fontSize: 14),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.dashboard, color: primaryContainer),
                title: const Text(
                  'Panel Principal',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.send, color: primaryContainer),
                title: const Text(
                  'Cotizaciones Enviadas',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = 2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.store, color: primaryContainer),
                title: const Text(
                  'Mi Almacén',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final almacen = await _almacenService.obtenerMiAlmacen();
                  if (context.mounted) {
                    if (almacen != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PerfilAlmacenPage(),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterAlmacenPage(),
                        ),
                      );
                    }
                  }
                },
              ),
              const Divider(color: outlineVariant),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                      (route) => false,
                    );
                  }
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
              child: _selectedIndex == 0
                  ? RefreshIndicator(
                      onRefresh: _cargarSolicitudes,
                      color: primaryContainer,
                      backgroundColor: surfaceContainerHigh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Dashboard Welcome
                            Text(
                              _nombreAlmacen ?? 'Cargando...',
                              style: const TextStyle(
                                color: onSurface,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Sora',
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Gestión de inventario y pedidos en tiempo real.',
                              style: TextStyle(
                                color: onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Stats Grid (Bento Style)
                            _buildBentoStatsGrid(),
                            const SizedBox(height: 24),

                            // Section Title
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Solicitudes Cercanas',
                                  style: TextStyle(
                                    color: onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Sora',
                                  ),
                                ),
                                TextButton(
                                  onPressed: _cargarSolicitudes,
                                  child: const Text(
                                    'Ver todas',
                                    style: TextStyle(
                                      color: primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Request Cards List
                            _isLoadingSolicitudes
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: primaryContainer,
                                    ),
                                  )
                                : _solicitudes.isEmpty
                                ? Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 40,
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: outlineVariant),
                                    ),
                                    child: const Column(
                                      children: [
                                        Icon(
                                          Icons.inbox,
                                          size: 48,
                                          color: onSurfaceVariant,
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'No hay solicitudes activas',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Las nuevas peticiones de los clientes aparecerán aquí.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
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
                                          bottom: 16,
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
                      color: primaryContainer,
                      backgroundColor: surfaceContainerHigh,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section Title
                            const Text(
                              'Cotizaciones Enviadas',
                              style: TextStyle(
                                color: onSurface,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Sora',
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Historial de cotizaciones enviadas a clientes.',
                              style: TextStyle(
                                color: onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Filter Chips
                            Row(
                              children: [
                                FilterChip(
                                  label: const Text('Todas'),
                                  selected: _filtroActual == 'todas',
                                  onSelected: (selected) {
                                    setState(() {
                                      _filtroActual = 'todas';
                                    });
                                  },
                                  selectedColor: primaryContainer.withOpacity(
                                    0.2,
                                  ),
                                  checkmarkColor: primaryContainer,
                                  labelStyle: TextStyle(
                                    color: _filtroActual == 'todas'
                                        ? primaryContainer
                                        : onSurfaceVariant,
                                  ),
                                  backgroundColor: surfaceContainerLow,
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: const Text('Pendientes'),
                                  selected: _filtroActual == 'pendientes',
                                  onSelected: (selected) {
                                    setState(() {
                                      _filtroActual = 'pendientes';
                                    });
                                  },
                                  selectedColor: primaryContainer.withOpacity(
                                    0.2,
                                  ),
                                  checkmarkColor: primaryContainer,
                                  labelStyle: TextStyle(
                                    color: _filtroActual == 'pendientes'
                                        ? primaryContainer
                                        : onSurfaceVariant,
                                  ),
                                  backgroundColor: surfaceContainerLow,
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: const Text('Ganadas'),
                                  selected: _filtroActual == 'ganadas',
                                  onSelected: (selected) {
                                    setState(() {
                                      _filtroActual = 'ganadas';
                                    });
                                  },
                                  selectedColor: primaryContainer.withOpacity(
                                    0.2,
                                  ),
                                  checkmarkColor: primaryContainer,
                                  labelStyle: TextStyle(
                                    color: _filtroActual == 'ganadas'
                                        ? primaryContainer
                                        : onSurfaceVariant,
                                  ),
                                  backgroundColor: surfaceContainerLow,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Quotations List
                            _isLoadingCotizaciones
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: primaryContainer,
                                    ),
                                  )
                                : _cotizacionesEnviadas.isEmpty
                                ? Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 40,
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: outlineVariant),
                                    ),
                                    child: const Column(
                                      children: [
                                        Icon(
                                          Icons.send_outlined,
                                          size: 48,
                                          color: onSurfaceVariant,
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'No hay cotizaciones enviadas',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Las cotizaciones que envíes aparecerán aquí.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
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
                                          bottom: 16,
                                        ),
                                        child: _buildQuotationCard(cotizacion),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: outlineVariant, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: primaryContainer, size: 24),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 8),
          const Text(
            'REPUESTOSYA',
            style: TextStyle(
              color: primaryContainer,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              fontFamily: 'Sora',
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),

          // Status Toggle Simulation (Clickable)
          GestureDetector(
            onTap: () {
              setState(() {
                _isOpen = !_isOpen;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: surfaceContainerHigh,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: outlineVariant, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isOpen ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isOpen ? 'Abierto' : 'Cerrado',
                    style: const TextStyle(
                      color: onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
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

  Widget _buildBentoStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildBentoStatCard('Ventas', '$_ventasCount', Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildBentoStatCard(
            'Pendientes',
            '${_solicitudes.length}',
            primaryContainer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildBentoStatCard('Vistas', '$_vistasCount', Colors.white),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryContainer.withOpacity(0.05),
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
            style: const TextStyle(color: onSurfaceVariant, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFamily: 'JetBrains Mono',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestBentoCard({required Map<String, dynamic> solicitud}) {
    // Extracción e indexación segura de datos relacionales anidados (Vehículos)
    final String title = solicitud['pieza_nombre'] ?? 'Repuesto Desconocido';

    // Armar el subtítulo dinámico con datos de la marca, modelo y año del vehículo
    final vehiculo = solicitud['vehiculos_cliente'];
    final modelo = vehiculo != null ? vehiculo['modelos_vehiculo'] : null;
    final marca = modelo != null ? modelo['marcas_vehiculo'] : null;

    String detallesVehiculo = 'Vehículo no especificado';
    if (marca != null && modelo != null) {
      detallesVehiculo =
          '${marca['nombre'] ?? ''} ${modelo['nombre'] ?? ''} • ${vehiculo['año'] ?? ''}';
    }

    final String subtitle =
        (solicitud['descripcion'] != null &&
            solicitud['descripcion'].toString().trim().isNotEmpty)
        ? solicitud['descripcion']
        : detallesVehiculo;

    final String distance = '2.8 km';

    // Calcular tiempo real desde created_at
    final createdAt = solicitud['created_at'];
    final String time = _formatTiempo(createdAt);

    // Validamos el tag correcto desde la columna 'es_urgente' del backend en Node
    final String? tagType = solicitud['es_urgente'] == true
        ? 'URGENTE'
        : 'ESTÁNDAR';

    // Extraer cantidad de cotizaciones (lazy loading)
    final cotizaciones = solicitud['cotizaciones'];
    final int cantidadCotizaciones =
        (cotizaciones is List && cotizaciones.isNotEmpty)
        ? (cotizaciones.first['count'] ?? 0)
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outlineVariant, width: 1),
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
                    Text(
                      title,
                      style: const TextStyle(
                        color: onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Sora',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: onSurfaceVariant,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (tagType != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tagType == 'URGENTE'
                        ? primary.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: tagType == 'URGENTE'
                          ? primary.withOpacity(0.3)
                          : Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    tagType,
                    style: TextStyle(
                      color: tagType == 'URGENTE' ? primary : Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on, color: secondary, size: 18),
              const SizedBox(width: 4),
              Text(
                distance,
                style: const TextStyle(
                  color: secondary,
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(width: 24),
              const Icon(Icons.schedule, color: onSurfaceVariant, size: 18),
              const SizedBox(width: 4),
              Text(
                time,
                style: const TextStyle(
                  color: onSurfaceVariant,
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Badge de cotizaciones
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cantidadCotizaciones > 0
                  ? primaryContainer.withOpacity(0.1)
                  : surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: cantidadCotizaciones > 0
                    ? primaryContainer.withOpacity(0.3)
                    : outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cantidadCotizaciones > 0
                      ? Icons.receipt_long
                      : Icons.receipt_long_outlined,
                  size: 16,
                  color: cantidadCotizaciones > 0
                      ? primaryContainer
                      : onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  cantidadCotizaciones > 0
                      ? '$cantidadCotizaciones cotización${cantidadCotizaciones == 1 ? '' : 'es'}'
                      : 'Sin cotizaciones aún',
                  style: TextStyle(
                    color: cantidadCotizaciones > 0
                        ? primaryContainer
                        : onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: cantidadCotizaciones > 0
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                final bool? vueltaConExito = await Navigator.push<bool>(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        CreateQuotationPage(solicitud: solicitud),
                    transitionDuration: const Duration(milliseconds: 250),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1.0, 0.0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          );
                        },
                  ),
                );

                if (vueltaConExito == true && mounted) {
                  _cargarSolicitudes();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Cotización enviada exitosamente!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryContainer,
                foregroundColor: onPrimaryContainer,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'COTIZAR',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Sora',
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

    // Extract ordenId from ordenes_compra relation
    final ordenesCompra = cotizacion['ordenes_compra'] as Map<String, dynamic>?;
    final String? ordenId = ordenesCompra?['id'] as String?;

    // Apply filter
    if (_filtroActual == 'pendientes' && estado != 'pendiente') {
      return const SizedBox.shrink();
    }
    if (_filtroActual == 'ganadas' && estado != 'aceptada') {
      return const SizedBox.shrink();
    }

    // Color según estado
    Color estadoColor;
    String estadoText;
    switch (estado) {
      case 'aceptada':
        estadoColor = Colors.green;
        estadoText = 'GANADA';
        break;
      case 'rechazada':
        estadoColor = Colors.red;
        estadoText = 'RECHAZADA';
        break;
      default:
        estadoColor = Colors.orange;
        estadoText = 'PENDIENTE';
    }

    final cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: estado == 'aceptada'
              ? Colors.green.withOpacity(0.3)
              : outlineVariant,
          width: 1,
        ),
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
                    Text(
                      piezaNombre,
                      style: const TextStyle(
                        color: onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Sora',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cliente: $clienteNombre',
                      style: const TextStyle(
                        color: onSurfaceVariant,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: estadoColor.withOpacity(0.3)),
                ),
                child: Text(
                  estadoText,
                  style: TextStyle(
                    color: estadoColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.attach_money, color: primaryContainer, size: 18),
              const SizedBox(width: 4),
              Text(
                '\$${precio.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: primaryContainer,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 24),
              Icon(Icons.access_time, color: onSurfaceVariant, size: 18),
              const SizedBox(width: 4),
              Text(
                _formatTiempo(createdAt),
                style: const TextStyle(color: onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
          if (tiempoEntrega != 'No especificado') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, color: onSurfaceVariant, size: 18),
                const SizedBox(width: 4),
                Text(
                  'Entrega: $tiempoEntrega',
                  style: const TextStyle(color: onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ],
          if (estado == 'aceptada' && ordenId != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.arrow_forward, color: primaryContainer, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Ver orden de compra',
                  style: TextStyle(
                    color: primaryContainer,
                    fontSize: 12,
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AlmacenOrdenDetallePage(ordenId: ordenId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: cardContent,
      );
    }

    return cardContent;
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: surfaceContainerHigh,
        border: Border(top: BorderSide(color: outlineVariant, width: 1)),
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
          if (context.mounted) {
            if (almacen != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PerfilAlmacenPage(),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RegisterAlmacenPage(),
                ),
              );
            }
          }
        }
      },
      child: Container(
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? primaryContainer : onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? primaryContainer : onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
