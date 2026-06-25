import 'package:flutter/material.dart';
import 'create_request_page.dart';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Color scheme from HTML
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

  @override
  void initState() {
    super.initState();
    _cargarSolicitudes();
  }

  Future<void> _cargarSolicitudes() async {
    setState(() {
      _isLoadingSolicitudes = true;
    });

    try {
      final user = _authService.currentUser;
      if (user != null) {
        final solicitudes = await _solicitudService.obtenerSolicitudesCliente(user.id);
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            // TopAppBar
            _buildTopAppBar(),
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Main Action: NUEVA BÚSQUEDA
                    _buildNewSearchButton(),
                    const SizedBox(height: 16),
                    // Stats Bento Row
                    _buildStatsRow(),
                    const SizedBox(height: 16),
                    // List: Mis Solicitudes
                    _buildRequestsSection(),
                    const SizedBox(height: 16),
                    // Recommended / Trending Section
                    _buildTrendingSection(),
                    const SizedBox(height: 80), // Space for bottom nav
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // BottomNavBar
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildTopAppBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(color: outlineVariant, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu,
                color: primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'RepuestosYa',
                style: TextStyle(
                  color: primaryContainer,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  textBaseline: TextBaseline.alphabetic,
                ),
              ),
            ],
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: surfaceVariant,
              shape: BoxShape.circle,
              border: Border.all(color: outlineVariant),
            ),
            child: Icon(
              Icons.person,
              color: onSurfaceVariant,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewSearchButton() {
    return Container(
      width: double.infinity,
      height: 192,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateRequestPage()),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: RadialGradient(
                colors: [
                  primaryContainer.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: primaryContainer.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryContainer, width: 2),
                  ),
                  child: Icon(
                    Icons.photo_camera,
                    color: primaryContainer,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'NUEVA BÚSQUEDA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sube una foto o busca por código',
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buscando',
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '03',
                      style: TextStyle(
                        color: primaryContainer,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.history,
                      color: primaryContainer,
                      size: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cotizadas',
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '12',
                      style: TextStyle(
                        color: secondaryContainer,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.request_quote,
                      color: secondaryContainer,
                      size: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mis Solicitudes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () {
                _cargarSolicitudes();
              },
              child: Text(
                'Ver todas',
                style: TextStyle(
                  color: primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingSolicitudes)
          const Center(
            child: CircularProgressIndicator(
              color: primaryContainer,
            ),
          )
        else if (_solicitudes.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: outlineVariant),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inbox,
                  size: 48,
                  color: onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No tienes solicitudes aún',
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Crea tu primera solicitud de repuesto',
                  style: TextStyle(
                    color: onSurfaceVariant.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
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
                statusColor = Colors.green;
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
              final now = DateTime.now();
              final difference = now.difference(date);
              
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

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildRequestCard(
                title: solicitud['pieza_nombre'] as String? ?? 'Repuesto',
                subtitle: solicitud['descripcion'] as String? ?? 'Sin descripción',
                status: statusText,
                statusColor: statusColor,
                quotes: '0 Cotizaciones',
                time: timeText,
                imageUrl: solicitud['foto_url'] as String? ?? 'https://via.placeholder.com/96',
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildRequestCard({
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    required String quotes,
    required String time,
    required String imageUrl,
    bool showSuccessBorder = false,
    double opacity = 1.0,
  }) {
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.image_not_supported,
                      color: onSurfaceVariant,
                      size: 32,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: statusColor.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFFB0B0B0),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long,
                            color: secondaryContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            quotes,
                            style: TextStyle(
                              color: secondaryContainer,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          color: onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lo más buscado',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildTrendingItem(
                icon: Icons.tire_repair,
                label: 'Neumáticos',
              ),
              const SizedBox(width: 16),
              _buildTrendingItem(
                icon: Icons.battery_charging_full,
                label: 'Baterías',
              ),
              const SizedBox(width: 16),
              _buildTrendingItem(
                icon: Icons.minor_crash,
                label: 'Carrocería',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingItem({
    required IconData icon,
    required String label,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: primary,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: outlineVariant, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryContainer.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.home,
            label: 'Home',
            isSelected: _selectedIndex == 0,
            onTap: () {
              setState(() {
                _selectedIndex = 0;
              });
            },
          ),
          _buildNavItem(
            icon: Icons.search,
            label: 'Search',
            isSelected: _selectedIndex == 1,
            onTap: () {
              setState(() {
                _selectedIndex = 1;
              });
            },
          ),
          _buildNavItem(
            icon: Icons.shopping_cart,
            label: 'Orders',
            isSelected: _selectedIndex == 2,
            onTap: () {
              setState(() {
                _selectedIndex = 2;
              });
            },
          ),
          _buildNavItem(
            icon: Icons.person,
            label: 'Profile',
            isSelected: _selectedIndex == 3,
            onTap: () {
              setState(() {
                _selectedIndex = 3;
              });
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
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? primaryContainer : onSurfaceVariant,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? primaryContainer : onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
