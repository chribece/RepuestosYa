import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/almacen_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/upload_service.dart';
import '../providers/profile_image_provider.dart';
import '../utils/ecuador_mobile_phone.dart';
import '../utils/ry_snackbar.dart';
import '../widgets/ry_text_field.dart';
import '../widgets/ry_state_container.dart';
import '../widgets/ry_notification_bell.dart';
import '../widgets/client_bottom_navigation_bar.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../router/route_names.dart';

typedef ProfileImagePicker = Future<XFile?> Function(ImageSource source);
typedef ProfileImageUploader =
    Future<String?> Function(
      File imageFile,
      String userId, {
      required bool isWarehouse,
    });

class ProfilePage extends StatefulWidget {
  final ProfileService? profileService;
  final AlmacenService? warehouseService;
  final ProfileImagePicker? imagePicker;
  final ProfileImageUploader? imageUploader;

  const ProfilePage({
    super.key,
    this.profileService,
    this.warehouseService,
    this.imagePicker,
    this.imageUploader,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Llave global indispensable para abrir de manera segura el menú hamburguesa
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Validación del formulario de edición (teléfono obligatorio).
  final _formKey = GlobalKey<FormState>();

  final AuthService _authService = AuthService();
  late final ProfileService _profileService =
      widget.profileService ?? ProfileService();
  late final AlmacenService _warehouseService =
      widget.warehouseService ?? AlmacenService();
  late final ProfileImagePicker _imagePicker =
      widget.imagePicker ?? _pickImageFromDevice;
  late final ProfileImageUploader _imageUploader =
      widget.imageUploader ?? UploadService().uploadProfileImage;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _warehouseData;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isAvatarUploading = false;
  File? _avatarFile;

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
    final profileImageProvider = context.read<ProfileImageProvider?>();
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
          _telefonoController.text = _normalizarTelefonoPerfil(
            profileData['telefono'],
          );
        });
        if (user.rol != 'almacen' && user.rol != 'warehouse') {
          profileImageProvider?.setImageUrl(
            profileData['avatar_url']?.toString(),
            userId: user.id,
          );
        }
      }
      if (user.rol == 'almacen' || user.rol == 'warehouse') {
        try {
          final warehouseData = await _warehouseService.obtenerMiAlmacen();
          if (mounted && warehouseData != null) {
            setState(() => _warehouseData = warehouseData);
            profileImageProvider?.setImageUrl(
              warehouseData['logo_url']?.toString(),
              userId: user.id,
            );
          }
        } catch (_) {
          // La edición del perfil sigue disponible aunque falle la carga
          // opcional del logo del almacén.
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _normalizarTelefonoPerfil(dynamic value) {
    var phone = value?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
    if (phone.startsWith('593')) {
      phone = phone.substring(3);
    }
    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }
    return phone;
  }

  Future<XFile?> _pickImageFromDevice(ImageSource source) {
    return ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );
  }

  Future<void> _showAvatarSourcePicker({required bool isWarehouse}) async {
    if (_isAvatarUploading) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.radiusLg),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.spacingMd),
            Text(
              isWarehouse ? 'Actualizar logo comercial' : 'Actualizar foto',
              style: AppTextStyles.textStyleTitle,
            ),
            const SizedBox(height: AppSpacing.spacingSm),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.spacingSm),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final selected = await _imagePicker(source);
      if (selected == null || !mounted) return;
      final imageFile = File(selected.path);
      setState(() => _avatarFile = imageFile);
      await _uploadAvatar(imageFile, isWarehouse: isWarehouse);
    } catch (_) {
      if (mounted) {
        mostrarSnackbarError(
          context,
          mensaje: 'No se pudo seleccionar la imagen. Inténtalo de nuevo.',
        );
      }
    }
  }

  Future<void> _uploadAvatar(
    File imageFile, {
    required bool isWarehouse,
  }) async {
    final profileImageProvider = context.read<ProfileImageProvider?>();
    final user = _authService.currentUser;
    if (user == null) {
      mostrarSnackbarError(
        context,
        mensaje: 'Inicia sesión para actualizar tu imagen.',
      );
      return;
    }

    setState(() => _isAvatarUploading = true);
    try {
      final imageUrl = await _imageUploader(
        imageFile,
        user.id,
        isWarehouse: isWarehouse,
      );
      if (imageUrl == null || imageUrl.isEmpty) {
        throw StateError('No se pudo subir la imagen');
      }

      final Map<String, dynamic>? updated;
      if (isWarehouse) {
        var warehouseId = _warehouseData?['id']?.toString();
        if (warehouseId == null || warehouseId.isEmpty) {
          final warehouseData = await _warehouseService.obtenerMiAlmacen();
          warehouseId = warehouseData?['id']?.toString();
        }
        if (warehouseId == null || warehouseId.isEmpty) {
          throw StateError('No se encontró el almacén del usuario');
        }
        updated = await _warehouseService.actualizarAlmacen(warehouseId, {
          'logo_url': imageUrl,
        });
      } else {
        updated = await _profileService.updateProfile(avatarUrl: imageUrl);
      }
      if (!mounted) return;
      if (updated == null) {
        throw StateError('No se pudo guardar la imagen');
      }

      setState(() {
        if (isWarehouse) {
          _warehouseData = {
            ...?_warehouseData,
            ...?updated,
            'logo_url': imageUrl,
          };
        } else {
          _profile = {...?_profile, ...?updated, 'avatar_url': imageUrl};
        }
      });
      profileImageProvider?.setImageUrl(imageUrl, userId: user.id);
      mostrarSnackbarExitoSobrio(
        context,
        mensaje: isWarehouse
            ? 'Logo comercial actualizado'
            : 'Foto de perfil actualizada',
      );
    } catch (_) {
      if (mounted) {
        mostrarSnackbarError(
          context,
          mensaje: isWarehouse
              ? 'No se pudo actualizar el logo comercial.'
              : 'No se pudo actualizar la foto de perfil.',
        );
      }
    } finally {
      if (mounted) setState(() => _isAvatarUploading = false);
    }
  }

  Future<void> _saveProfile() async {
    // El teléfono es obligatorio: sin él el almacén ganador no puede
    // coordinar el pago y la entrega (se exige también al aceptar).
    final form = _formKey.currentState;
    if (form == null || !form.validate() || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final nombreCompleto = _nombreController.text.trim();
    final telefono = _telefonoController.text.trim();
    try {
      final updated = await _profileService.updateProfile(
        nombreCompleto: nombreCompleto,
        telefono: telefono,
      );

      if (!mounted) return;

      if (updated != null) {
        setState(() {
          _profile = {
            ...?_profile,
            'nombre_completo': nombreCompleto,
            'telefono': telefono,
          };
        });
        mostrarSnackbarExitoSobrio(
          context,
          mensaje: 'Perfil actualizado correctamente',
        );
      } else {
        mostrarSnackbarError(context, mensaje: 'Error al actualizar el perfil');
      }
    } catch (_) {
      if (mounted) {
        mostrarSnackbarError(context, mensaje: 'Error al actualizar el perfil');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
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
                  color: SemanticColors.colorErrorText,
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
                leading: const Icon(
                  Icons.logout_rounded,
                  color: SemanticColors.colorErrorText,
                ),
                title: Text(
                  'Cerrar sesión',
                  style: AppTextStyles.textStyleBody.copyWith(
                    color: SemanticColors.colorErrorText,
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
                          _buildFooter(),
                          const SizedBox(height: AppSpacing.spacingXxl),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ClientBottomNavigationBar(currentIndex: 3),
    );
  }

  Widget _buildTopAppBar() {
    return Container(
      key: const ValueKey('profile-top-app-bar'),
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RyNotificationBell(),
              if (!_isLoading)
                IconButton(
                  tooltip: _isSaving ? 'Guardando cambios' : 'Guardar cambios',
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryContainer,
                          ),
                        )
                      : const Icon(
                          Icons.save_rounded,
                          color: AppColors.primaryContainer,
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(User? user) {
    final displayName =
        _profile?['nombre_completo'] ?? user?.nombreCompleto ?? 'Usuario';
    final email = user?.email ?? 'Sin correo registrado';
    final isWarehouse = user?.rol == 'almacen' || user?.rol == 'warehouse';
    final roleDisplay = isWarehouse
        ? 'Rol: Almacén / Vendedor'
        : 'Rol: Cliente';
    final avatarTooltip = isWarehouse
        ? 'Actualizar logo comercial'
        : 'Actualizar foto de perfil';
    final avatarUrl = isWarehouse
        ? (_warehouseData?['logo_url']?.toString())
        : (_profile?['avatar_url']?.toString());

    return Row(
      children: [
        Semantics(
          button: true,
          label: avatarTooltip,
          child: Tooltip(
            message: avatarTooltip,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isAvatarUploading
                    ? null
                    : () => _showAvatarSourcePicker(isWarehouse: isWarehouse),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primaryContainer,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryContainer.withValues(
                                alpha: 0.2,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _buildAvatarImage(
                            isWarehouse: isWarehouse,
                            imageUrl: avatarUrl,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.background,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: AppColors.onPrimaryContainer,
                            size: 14,
                          ),
                        ),
                      ),
                      if (_isAvatarUploading)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.background.withValues(
                                alpha: 0.55,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(AppSpacing.spacingXl),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryContainer,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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

  Widget _buildAvatarImage({
    required bool isWarehouse,
    required String? imageUrl,
  }) {
    if (_avatarFile != null) {
      return Image.file(
        _avatarFile!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildAvatarPlaceholder(isWarehouse),
      );
    }
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildAvatarPlaceholder(isWarehouse),
      );
    }
    return _buildAvatarPlaceholder(isWarehouse);
  }

  Widget _buildAvatarPlaceholder(bool isWarehouse) {
    return Center(
      child: Icon(
        isWarehouse ? Icons.storefront_rounded : Icons.person_rounded,
        size: 40,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildEditableFields() {
    return Form(
      key: _formKey,
      child: Column(
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
            hint: 'Ej: 981894367',
            type: RyTextFieldType.phone,
            controller: _telefonoController,
            keyboardType: TextInputType.phone,
            inputFormatters: ecuadorMobilePhoneInputFormatters(),
            isRequired: true,
            prefixWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.phone_android,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.spacingXs),
                Text(
                  '+593',
                  style: AppTextStyles.textStyleBody.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingXs),
                Container(
                  width: 1,
                  height: 24,
                  color: AppColors.outlineVariant,
                ),
              ],
            ),
            helperText: '9 dígitos, sin el 0 inicial.',
            helperStyle: AppTextStyles.textStyleCaption.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            helperMaxLines: 3,
            validator: validarTelefonoMovilEcuador,
          ),
        ],
      ),
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
          ),
          _buildMenuItem(
            icon: Icons.logout_rounded,
            title: 'Cerrar sesión',
            foregroundColor: SemanticColors.colorErrorText,
            onTap: _showLogoutDialog,
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
    Color? foregroundColor,
  }) {
    final itemColor = foregroundColor ?? AppColors.primary;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(AppSpacing.spacingSm),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              ),
              child: Icon(icon, color: itemColor),
            ),
            title: Text(
              title,
              style: AppTextStyles.textStyleBody.copyWith(color: itemColor),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.onSurfaceVariant,
              size: 16,
            ),
            onTap: onTap,
          ),
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

  Widget _buildFooter() {
    return Center(
      child: Text(
        'Versión 2.1.0 • Built by VCore Tech',
        style: AppTextStyles.textStyleSmall.copyWith(
          color: AppColors.outlineVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
