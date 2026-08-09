import 'package:flutter/material.dart';
import 'dart:io';
import 'create_request_page.dart';
import 'profile_page.dart';
import 'register_almacen_page.dart';
import 'perfil_almacen_page.dart';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';
import '../services/almacen_service.dart';
import '../services/realtime_notification_service.dart';
import 'todas_solicitudes_page.dart';
import 'login_page.dart';
import 'package:provider/provider.dart';
import '../providers/user_role_provider.dart';
import 'received_quotations_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Color scheme from HTML / Design System
  static const Color primary = Color(0xFFFFB5A0);
  static const Color primaryContainer = Color(0xFFFF5722);
  static const Color onPrimaryContainer = Color(0xFF541200);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color outlineVariant = Color(0xFF5B4039);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFE4BEB4);
  static const Color tertiaryContainer = Color(0xFF019AD8);
  static const Color secondaryContainer = Color(0xFF1E95F2);
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF131313);
  static const Color surfaceVariant = Color(0xFF353534);
  static const Color secondary = Color(0xFF9ECAFF);

  int _selectedIndex = 0;
  List<Map<String, dynamic>> _solicitudes = [];
  bool _isLoadingSolicitudes = false;

  final SolicitudService _solicitudService = SolicitudService();
  final AuthService _authService = AuthService();
  final AlmacenService _almacenService = AlmacenService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _cargarSolicitudes();
    _suscribirANotificaciones();
  }

  Future<void> _suscribirANotificaciones() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final clienteId = user.id;
        RealtimeNotificationService().subscribeToEstadoOrden(clienteId);

        final solicitudes = await _solicitudService.obtenerSolicitudesActivas();
        if (solicitudes != null && solicitudes.isNotEmpty) {
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
      print('Error al suscribir a notificaciones: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cargarSolicitudes();
  }

  Future<void> _cargarSolicitudes() async {
    setState(() {
      _isLoadingSolicitudes = true;
    });

    try {
      final user = _authService.currentUser;
      if (user != null) {
        final solicitudes = await _solicitudService.obtenerSolicitudesPaginadas(
          clienteId: user.id,
          page: 1,
          limit: 20,
        );
        setState(() {
          _solicitudes = solicitudes;
        });
      }
    } catch (e) {
      print('Error al cargar solicitudes: $e');
    } finally {
      setState(() {
        _isLoadingSolicitudes = false;
      });
    }
  }

  @override
  void dispose() {
    RealtimeNotificationService().unsubscribe();
    RealtimeNotificationService().unsubscribeMultiple();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: background,
      drawer: _buildNavigationDrawer(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildNewSearchButton(),
                    const SizedBox(height: 20),
                    _buildStatsRow(),
                    const SizedBox(height: 24),
                    _buildRequestsSection(),
                    const SizedBox(height: 24),
                    _buildTrendingSection(),
                    const SizedBox(height: 40),
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
      backgroundColor: background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: surfaceContainerHigh,
              border: Border(bottom: BorderSide(color: outlineVariant, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'RepuestosYa',
                  style: TextStyle(
                    color: primaryContainer,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Menú de Opciones',
                  style: TextStyle(color: onSurfaceVariant, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_rounded, color: primary),
            title: const Text('Inicio', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.person_rounded, color: primary),
            title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart_outlined, color: primary),
            title: const Text('Mis Órdenes', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Próximamente: Lista de órdenes de compra'), duration: Duration(seconds: 2)),
              );
            },
          ),
          const Divider(color: outlineVariant, height: 32),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
            onTap: () async {
              Navigator.pop(context);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(color: primaryContainer),
                ),
              );

              try {
                await _authService.signOut();
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al cerrar sesión: $e'), backgroundColor: Colors.red),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: outlineVariant, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: primary, size: 24),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              const SizedBox(width: 8),
              Text(
                'RepuestosYa',
                style: TextStyle(
                  color: primaryContainer,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: surfaceVariant,
                shape: BoxShape.circle,
                border: Border.all(color: outlineVariant),
              ),
              child: const Icon(Icons.person, color: onSurfaceVariant, size: 22),
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
        color: surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryContainer.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryContainer.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateRequestPage()),
            );
            _cargarSolicitudes();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.8,
                colors: [primaryContainer.withOpacity(0.15), Colors.transparent],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: primaryContainer.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryContainer, width: 2),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    color: primaryContainer,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'NUEVA BÚSQUEDA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sube una foto y encuentra tu repuesto al instante',
                  style: TextStyle(color: onSurfaceVariant, fontSize: 12),
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
    final int buscandoCount = _solicitudes.where((s) => s['estado'] == 'en_proceso').length;
    final int cotizadasCount = _solicitudes.where((s) => s['estado'] == 'completado').length;

    final String buscandoTxt = buscandoCount.toString().padLeft(2, '0');
    final String cotizadasTxt = cotizadasCount.toString().padLeft(2, '0');

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Buscando',
            value: buscandoTxt,
            icon: Icons.history_rounded,
            color: primaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Cotizadas',
            value: cotizadasTxt,
            icon: Icons.request_quote_rounded,
            color: secondaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w800),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mis Solicitudes',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TodasSolicitudesPage()),
                ).then((_) => _cargarSolicitudes());
              },
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
              child: const Text(
                'Ver todas',
                style: TextStyle(color: primary, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingSolicitudes)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(color: primaryContainer),
            ),
          )
        else if (_solicitudes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: outlineVariant),
            ),
            child: Column(
              children: [
                const Icon(Icons.inbox_rounded, size: 42, color: onSurfaceVariant),
                const SizedBox(height: 12),
                const Text('No tienes solicitudes aún', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Crea tu primera solicitud de repuesto', style: TextStyle(color: onSurfaceVariant, fontSize: 13)),
              ],
            ),
          )
        else
          ..._solicitudes.take(3).map((solicitud) {
            final estado = solicitud['estado'] as String? ?? 'en_proceso';
            Color statusColor;
            String statusText;

            switch (estado) {
              case 'en_proceso':
                statusColor = primaryContainer;
                statusText = 'En Proceso';
                break;
              case 'completado':
                statusColor = Colors.greenAccent;
                statusText = 'Completado';
                break;
              case 'expirado':
                statusColor = onSurfaceVariant;
                statusText = 'Expirado';
                break;
              default:
                statusColor = primaryContainer;
                statusText = estado;
            }

            final createdAt = solicitud['created_at'] as String?;
            String timeText = 'Reciente';
            if (createdAt != null) {
              final date = DateTime.parse(createdAt);
              final difference = DateTime.now().difference(date);
              if (difference.inHours < 1) {
                timeText = 'Hace ${difference.inMinutes} min';
              } else if (difference.inHours < 24) {
                timeText = 'Hace ${difference.inHours}h';
              } else {
                timeText = 'Hace ${difference.inDays}d';
              }
            }

            final int cantidadCotizaciones = solicitud['cotizaciones_count'] ??
                (solicitud['cotizaciones'] != null ? (solicitud['cotizaciones'] as List).length : 0);

            final String quotesText = cantidadCotizaciones == 1 ? '1 Cotización nueva' : '$cantidadCotizaciones Cotizaciones';
            final String urlFinal = solicitud['image_url'] ?? solicitud['foto_url'] ?? '';
            final String piezaNombreFinal = solicitud['pieza_nombre'] as String? ?? 'Repuesto';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ReceivedQuotationsPage(
                        solicitudId: solicitud['id'].toString(),
                        piezaNombre: piezaNombreFinal,
                      ),
                    ),
                  );
                },
                child: _buildRequestCard(
                  title: piezaNombreFinal,
                  subtitle: solicitud['descripcion'] as String? ?? 'Sin descripción',
                  status: statusText,
                  statusColor: statusColor,
                  quotes: quotesText,
                  tieneCotizaciones: cantidadCotizaciones > 0,
                  time: timeText,
                  imageUrl: urlFinal,
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRequestCard({
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required String quotes,
    required bool tieneCotizaciones,
    required String time,
    required String imageUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tieneCotizaciones ? primaryContainer : outlineVariant,
          width: tieneCotizaciones ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl.isEmpty
                  ? const Icon(Icons.image_not_supported_rounded, color: onSurfaceVariant, size: 28)
                  : (imageUrl.startsWith('http')
                      ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.error, color: onSurfaceVariant))
                      : Image.file(File(imageUrl), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.error, color: onSurfaceVariant))),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: onSurfaceVariant, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, color: tieneCotizaciones ? primaryContainer : secondaryContainer, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          quotes,
                          style: TextStyle(color: tieneCotizaciones ? primaryContainer : secondaryContainer, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(time, style: const TextStyle(color: onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SECCIÓN DE TENDENCIAS ---
  Widget _buildTrendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lo más buscado',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildTrendingItem(icon: Icons.tire_repair_rounded, label: 'Neumáticos'),
              const SizedBox(width: 12),
              _buildTrendingItem(icon: Icons.battery_charging_full_rounded, label: 'Baterías'),
              const SizedBox(width: 12),
              _buildTrendingItem(icon: Icons.car_crash_rounded, label: 'Carrocería'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingItem({required IconData icon, required String label}) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: primary, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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
        color: surfaceContainerHigh,
        border: Border(top: BorderSide(color: outlineVariant, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(icon: Icons.home_rounded, label: 'Home', isSelected: _selectedIndex == 0, onTap: () => setState(() => _selectedIndex = 0)),
          _buildNavItem(icon: Icons.search_rounded, label: 'Search', isSelected: _selectedIndex == 1, onTap: () => setState(() => _selectedIndex = 1)),
          _buildNavItem(icon: Icons.shopping_cart_rounded, label: 'Orders', isSelected: _selectedIndex == 2, onTap: () => setState(() => _selectedIndex = 2)),
          _buildNavItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            isSelected: _selectedIndex == 3,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? primaryContainer : onSurfaceVariant, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: isSelected ? primaryContainer : onSurfaceVariant, fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400),
          ),
        ],
      ),
    );
  }
}