import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'vehicles_page.dart';
import 'addresses_page.dart';
import 'warehouse_dashboard.dart'; // Importación indispensable para la redirección de almacén

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
  static const Color dividerColor = Color(0xFF2C2C2C);

  // Llave global indispensable para abrir de manera segura el menú hamburguesa
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

  Map<String, dynamic>? _profile;
  bool _isLoading = false;

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    final user = _authService.currentUser;
    if (user != null) {
      final profileData = await _profileService.getUserProfile(user.id);
      if (profileData != null && mounted) {
        setState(() {
          _profile = profileData;
          _nombreController.text = profileData['nombre_completo'] ?? '';
          _telefonoController.text = profileData['telefono'] ?? '';
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    final updated = await _profileService.updateProfile(
      nombreCompleto: _nombreController.text.trim(),
      telefono: _telefonoController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );
        _loadProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al actualizar el perfil')),
        );
      }
    }
  }

  // Función inteligente para redireccionar dinámicamente según el Rol del usuario
  void _navigateToHomeBasedOnRole() {
    final user = _authService.currentUser;
    
    if (user?.rol == 'almacen' || user?.rol == 'warehouse') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WarehouseDashboard()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: surfaceVariant,
          title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.white)),
          content: const Text(
            '¿Estás seguro de que deseas salir de la aplicación?',
            style: TextStyle(color: onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: primary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Cierra el modal dialog
                await _authService.signOut();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
              child: const Text('Salir', style: TextStyle(color: error)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      key: _scaffoldKey, // Vinculación de la llave limpia para el menú
      backgroundColor: background,
      
      // MENÚ LATERAL (DRAWER) CON REDIRECCIÓN INTELIGENTE
      drawer: Drawer(
        child: Container(
          color: background,
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
                leading: const Icon(Icons.home, color: primaryContainer),
                title: const Text('Inicio', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context); // Cierra el menú lateral visualmente
                  _navigateToHomeBasedOnRole(); // Llama a la redirección dinámica por rol
                },
              ),
              ListTile(
                leading: const Icon(Icons.person, color: primaryContainer),
                title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context); // Solo cierra el drawer porque ya está aquí
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context); // Cierra el drawer lateral
                  _showLogoutDialog(); // Llama a tu función nativa de confirmación
                },
              ),
            ],
          ),
        ),
      ),
      
      body: SafeArea(
        child: Column(
          children: [
            // TopAppBar
            _buildTopAppBar(),
            // Main Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: primaryContainer))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          // Profile Header
                          _buildProfileHeader(user),
                          const SizedBox(height: 24),
                          // Form Fields
                          _buildEditableFields(),
                          const SizedBox(height: 24),
                          // Menu Section (SÓLO PARA CLIENTES)
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
      decoration: const BoxDecoration(
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
              IconButton(
                icon: const Icon(
                  Icons.menu,
                  color: primaryContainer,
                  size: 24,
                ),
                onPressed: () {
                  // Abre de manera segura el Drawer lateral de esta pantalla
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              const SizedBox(width: 4),
              const Text(
                'Mi Perfil',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save, color: primaryContainer),
              onPressed: _saveProfile,
            ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(User? user) {
    final displayName = _profile?['nombre_completo'] ?? user?.nombreCompleto ?? 'Usuario';
    final email = user?.email ?? 'Sin correo registrado';
    final roleDisplay = (user?.rol == 'almacen' || user?.rol == 'warehouse') ? 'Rol: Almacén / Vendedor' : 'Rol: Cliente';

    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: surfaceContainerHigh,
            shape: BoxShape.circle,
            border: Border.all(color: primaryContainer, width: 2),
            boxShadow: [
              BoxShadow(
                color: primaryContainer.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.person,
            size: 40,
            color: primary,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(
                  color: onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                roleDisplay,
                style: const TextStyle(
                  color: primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Información Personal',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _nombreController,
          label: 'Nombre Completo',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _telefonoController,
          label: 'Teléfono',
          icon: Icons.phone_android_outlined,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: onSurfaceVariant),
        prefixIcon: Icon(icon, color: primaryContainer),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryContainer, width: 2),
        ),
        filled: true,
        fillColor: surfaceContainerLow,
      ),
    );
  }

  Widget _buildMenuSection() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineVariant, width: 1),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.directions_car_outlined,
            title: 'Mis Vehículos',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VehiclesPage()),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.location_on_outlined,
            title: 'Mis Direcciones',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddressesPage()),
              );
            },
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: primary),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            color: onSurfaceVariant,
            size: 16,
          ),
          onTap: onTap,
        ),
        if (!isLast)
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
          child: const Row(
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
    return const Center(
      child: Text(
        'Versión 2.1.0 • Built for Performance',
        style: TextStyle(
          color: outlineVariant,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}