import 'package:flutter/material.dart';

class WarehouseDashboard extends StatefulWidget {
  const WarehouseDashboard({super.key});

  @override
  State<WarehouseDashboard> createState() => _WarehouseDashboardState();
}

class _WarehouseDashboardState extends State<WarehouseDashboard> {
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
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);

  bool _isOpen = true;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            _buildHeader(),
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Dashboard Welcome
                    _buildWelcomeSection(),
                    const SizedBox(height: 16),
                    // Stats Grid (Bento Style)
                    _buildStatsGrid(),
                    const SizedBox(height: 16),
                    // Section Title
                    _buildSectionTitle(),
                    const SizedBox(height: 16),
                    // Request Cards List
                    _buildRequestCards(),
                    const SizedBox(height: 16),
                    // Atmospheric Visual Element
                    _buildSystemStatus(),
                    const SizedBox(height: 80), // Space for bottom nav
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Navigation Bar
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildHeader() {
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
          Row(
            children: [
              // Status Chip
              InkWell(
                onTap: () {
                  setState(() {
                    _isOpen = !_isOpen;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: outlineVariant),
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
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Profile Avatar
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
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Almacén Central',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Gestión de inventario y pedidos en tiempo real.',
          style: TextStyle(
            color: onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: primaryContainer.withOpacity(0.1),
                  blurRadius: 15,
                ),
              ],
            ),
            height: 112,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ventas',
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '42',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: primaryContainer.withOpacity(0.1),
                  blurRadius: 15,
                ),
              ],
            ),
            height: 112,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pendientes',
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '12',
                  style: TextStyle(
                    color: primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: primaryContainer.withOpacity(0.1),
                  blurRadius: 15,
                ),
              ],
            ),
            height: 112,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vistas',
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '850',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Solicitudes Cercanas',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextButton(
          onPressed: () {},
          child: Text(
            'Ver todas',
            style: TextStyle(
              color: primary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCards() {
    return Column(
      children: [
        _buildRequestCard(
          title: 'Amortiguadores Delanteros',
          subtitle: 'Toyota Hilux 2022 • Gas',
          distance: '2.4 km',
          time: 'Hace 5 min',
          badge: 'Compatible',
          badgeColor: Colors.green,
        ),
        const SizedBox(height: 16),
        _buildRequestCard(
          title: 'Kit de Embrague',
          subtitle: 'Ford Ranger 2019 • 3.2 Diesel',
          distance: '4.8 km',
          time: 'Hace 12 min',
          badge: null,
        ),
        const SizedBox(height: 16),
        _buildRequestCard(
          title: 'Pastillas de Freno',
          subtitle: 'Honda CR-V 2021 • Cerámica',
          distance: '0.9 km',
          time: 'Hace 2 min',
          badge: 'Urgente',
          badgeColor: primary,
        ),
      ],
    );
  }

  Widget _buildRequestCard({
    required String title,
    required String subtitle,
    required String distance,
    required String time,
    String? badge,
    Color? badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor?.withOpacity(0.1) ?? Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: badgeColor?.withOpacity(0.3) ?? Colors.transparent,
                    ),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    distance,
                    style: TextStyle(
                      color: secondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryContainer,
                foregroundColor: onPrimaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
                shadowColor: primaryContainer.withOpacity(0.3),
              ),
              child: Text(
                'COTIZAR',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Container(
      height: 128,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            surfaceContainerHigh.withOpacity(0.5),
            background,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 16,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estado del Sistema',
                  style: TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Red Operativa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
