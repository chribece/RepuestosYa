import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_text_field.dart';
import '../widgets/ry_state_container.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../router/route_names.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
      context.goNamed(RouteNames.dashboard);
    } else {
      context.goNamed(RouteNames.home);
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceVariant,
          title: Text('Cerrar Sesión', style: AppTextStyles.textStyleTitle),
          content: Text(
            '¿Estás seguro de que deseas salir de la aplicación?',
            style: AppTextStyles.textStyleBody.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: AppTextStyles.textStyleButton.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _authService.signOut();
                // Router redirigirá automáticamente
              },
              child: Text(
                'Salir',
                style: AppTextStyles.textStyleButton.copyWith(
                  color: AppColors.error,
                ),
              ),
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
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: Drawer(
        child: Container(
          color: AppColors.background,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'RepuestosYa',
                      style: AppTextStyles.textStyleHeading.copyWith(
                        color: AppColors.primaryContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spacingSm),
                    Text(
                      'Menú de Opciones',
                      style: AppTextStyles.textStyleCaption.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.home,
                  color: AppColors.primaryContainer,
                ),
                title: Text('Inicio', style: AppTextStyles.textStyleBody),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToHomeBasedOnRole();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.person,
                  color: AppColors.primaryContainer,
                ),
                title: Text('Mi Perfil', style: AppTextStyles.textStyleBody),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: Text(
                  'Cerrar Sesión',
                  style: AppTextStyles.textStyleBody.copyWith(
                    color: AppColors.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutDialog();
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
              child: _isLoading
                  ? const RyStateContainer(
                      title: 'Cargando perfil...',
                      type: RyStateType.loading,
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.spacingMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.spacingLg),
                          _buildProfileHeader(user),
                          const SizedBox(height: AppSpacing.spacingXl),
                          _buildEditableFields(),
                          const SizedBox(height: AppSpacing.spacingXl),
                          _buildMenuSection(),
                          const SizedBox(height: AppSpacing.spacingXl),
                          _buildLogoutButton(),
                          const SizedBox(height: AppSpacing.spacingMd),
                          _buildFooter(),
                          const SizedBox(height: AppSpacing.spacingXxl),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
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
                  color: AppColors.primaryContainer,
                  size: 24,
                ),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              const SizedBox(width: AppSpacing.spacingXxs),
              Text('Mi Perfil', style: AppTextStyles.textStyleTitle),
            ],
          ),
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save, color: AppColors.primaryContainer),
              onPressed: _saveProfile,
            ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(User? user) {
    final displayName =
        _profile?['nombre_completo'] ?? user?.nombreCompleto ?? 'Usuario';
    final email = user?.email ?? 'Sin correo registrado';
    final roleDisplay = (user?.rol == 'almacen' || user?.rol == 'warehouse')
        ? 'Rol: Almacén / Vendedor'
        : 'Rol: Cliente';

    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryContainer, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryContainer.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.person, size: 40, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.spacingLg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName, style: AppTextStyles.textStyleHeading),
              const SizedBox(height: AppSpacing.spacingXxs),
              Text(
                email,
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.spacingXxs),
              Text(
                roleDisplay,
                style: AppTextStyles.textStyleSmall.copyWith(
                  color: AppColors.primary,
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
        Text('Información Personal', style: AppTextStyles.textStyleTitle),
        const SizedBox(height: AppSpacing.spacingMd),
        RyTextField(
          label: 'Nombre Completo',
          prefixIcon: Icons.person_outline,
          controller: _nombreController,
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        RyTextField(
          label: 'Teléfono',
          prefixIcon: Icons.phone_android_outlined,
          type: RyTextFieldType.phone,
          controller: _telefonoController,
        ),
      ],
    );
  }

  Widget _buildMenuSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.directions_car_outlined,
            title: 'Mis Vehículos',
            onTap: () {
              context.pushNamed(RouteNames.vehicles);
            },
          ),
          _buildMenuItem(
            icon: Icons.location_on_outlined,
            title: 'Mis Direcciones',
            onTap: () {
              context.pushNamed(RouteNames.addresses);
            },
          ),
          _buildMenuItem(
            icon: Icons.shopping_cart_outlined,
            title: 'Mis Órdenes',
            onTap: () {
              context.pushNamed(RouteNames.misOrdenes);
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
            padding: const EdgeInsets.all(AppSpacing.spacingSm),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          title: Text(title, style: AppTextStyles.textStyleBody),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            color: AppColors.onSurfaceVariant,
            size: 16,
          ),
          onTap: onTap,
        ),
        if (!isLast)
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spacingMd,
            ),
            color: AppColors.outlineVariant,
          ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return RyButton(
      label: 'Cerrar Sesión',
      icon: Icons.logout,
      variant: RyButtonVariant.danger,
      size: RyButtonSize.large,
      isFullWidth: true,
      onPressed: _showLogoutDialog,
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        'Versión 2.1.0 • Built for Performance',
        style: AppTextStyles.textStyleSmall.copyWith(
          color: AppColors.outlineVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
