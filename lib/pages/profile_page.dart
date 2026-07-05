import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'vehicles_page.dart';
import 'addresses_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Color scheme from HTML
  static const Color primary = Color(0xFFFFB5A0);
  static const Color primaryContainer = Color(0xFFFF5722);
  static const Color onPrimaryContainer = Color(0xFF541200);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color outlineVariant = Color(0xFF5B4039);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFE4BEB4);
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF131313);
  static const Color surfaceVariant = Color(0xFF353534);
  static const Color secondary = Color(0xFF9ECAFF);
  static const Color secondaryContainer = Color(0xFF1E95F2);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color error = Color(0xFFFF1744);
  static const Color dividerColor = Color(0xFF333333);
  static const Color cardBackground = Color(0xFF1E1E1E);

  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _authService.currentUser;
      if (user != null) {
        final profile = await _profileService.getUserProfile(user.id);
        setState(() {
          _profile = profile;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showLogoutDialog() {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Cerrar Sesión',
            style: TextStyle(
              color: onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            '¿Estás seguro de que quieres cerrar sesión?',
            style: TextStyle(
              color: onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: onSurfaceVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _handleLogout();
              },
              child: Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: error,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

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
                    // Profile Header
                    _buildProfileHeader(user),
                    const SizedBox(height: 24),
                    // Menu Section
                    _buildMenuSection(),
                    const SizedBox(height: 24),
                    // Logout Button
                    _buildLogoutButton(),
                    const SizedBox(height: 16),
                    // Footer
                    _buildFooter(),
                    const SizedBox(height: 80), // Space for bottom nav
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.menu,
                    color: primary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Mi Perfil',
                style: TextStyle(
                  color: primaryContainer,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
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
              border: Border.all(color: primaryContainer, width: 2),
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

  Widget _buildProfileHeader(User? user) {
    return Column(
      children: [
        // Avatar with glow effect
        Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: primaryContainer.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Stack(
              children: [
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color: surfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryContainer, width: 4),
                  ),
                  child: Icon(
                    Icons.person,
                    color: primaryContainer,
                    size: 72,
                  ),
                ),
                // Edit button
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryContainer,
                      shape: BoxShape.circle,
                      border: Border.all(color: surface, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.edit,
                      color: onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Name
        Text(
          user?.nombreCompleto ?? 'Usuario',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        // Email and phone
        Text(
          '${user?.email ?? ''} • +54 11 4567-8901',
          style: TextStyle(
            color: const Color(0xFFB0B0B0),
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: secondaryContainer.withOpacity(0.1),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: secondaryContainer.withOpacity(0.2)),
          ),
          child: Text(
            'Miembro Platinum',
            style: TextStyle(
              color: secondaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection() {
    return Column(
      children: [
        // Main menu items
        _buildMenuCard([
          _buildMenuItem(
            icon: Icons.directions_car,
            label: 'Mis Vehículos',
          ),
          _buildMenuItem(
            icon: Icons.location_on,
            label: 'Direcciones',
          ),
          _buildMenuItem(
            icon: Icons.payments,
            label: 'Métodos de Pago',
          ),
          _buildMenuItem(
            icon: Icons.help,
            label: 'Centro de Ayuda',
          ),
        ]),
        const SizedBox(height: 8),
        // Settings
        _buildMenuCard([
          _buildMenuItem(
            icon: Icons.settings,
            label: 'Configuración',
          ),
        ]),
      ],
    );
  }

  Widget _buildMenuCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dividerColor),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            if (label == 'Mis Vehículos') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VehiclesPage()),
              );
            } else if (label == 'Direcciones') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddressesPage()),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: const Color(0xFFB0B0B0),
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: outlineVariant,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        // Divider (except for last item)
        if (label != 'Configuración')
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: dividerColor,
          ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: error,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: error.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showLogoutDialog,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      'Versión 2.1.0 • Built for Performance',
      style: TextStyle(
        color: outlineVariant,
        fontSize: 12,
      ),
      textAlign: TextAlign.center,
    );
  }
}
