import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/almacen_service.dart';
import '../services/almacen_repository.dart';
import '../services/auth_service.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_text_field.dart';
import '../widgets/ry_state_container.dart';
import '../widgets/ry_status_badge.dart';
import '../widgets/ry_section_card.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import '../router/route_names.dart';

class PerfilAlmacenPage extends StatefulWidget {
  const PerfilAlmacenPage({super.key});

  @override
  State<PerfilAlmacenPage> createState() => _PerfilAlmacenPageState();
}

class _PerfilAlmacenPageState extends State<PerfilAlmacenPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _rucController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();

  bool _isEditing = false;
  bool _isSubmitting = false;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, String> _fieldErrors = {};
  Map<String, dynamic>? _almacenData;

  late final AlmacenService _almacenService;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _almacenService = AlmacenService(context.read<AlmacenRepository>());
    _cargarAlmacen();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _rucController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _cargarAlmacen() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final almacen = await _almacenService.obtenerMiAlmacen();
      if (!mounted) return;
      if (almacen != null) {
        setState(() {
          _almacenData = almacen;
          _nombreController.text = almacen['nombre_comercial'] ?? '';
          _rucController.text = almacen['ruc'] ?? '';
          _telefonoController.text = almacen['telefono'] ?? '';
          _direccionController.text = almacen['direccion_texto'] ?? '';
          _latController.text = (almacen['latitude'] ?? 0).toString();
          _lonController.text = (almacen['longitude'] ?? 0).toString();
          _isLoading = false;
        });
      } else {
        // No hay almacén: redirigir a CompleteProfilePage
        setState(() => _isLoading = false);
        AppLogger.info(
          'PerfilAlmacenPage: sin almacén, redirigiendo a CompleteProfilePage',
          name: 'PerfilAlmacenPage',
        );
        if (mounted) {
          context.goNamed(RouteNames.completeProfile);
        }
      }
    } catch (e) {
      AppLogger.error(
        'Error al cargar almacén',
        name: 'PerfilAlmacenPage',
        error: e,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorHandler.userMessage(e);
      });
    }
  }

  Future<void> _guardarCambios() async {
    setState(() => _fieldErrors = {});
    AppLogger.debug('Iniciando _guardarCambios...', name: 'PerfilAlmacenPage');

    if (!_formKey.currentState!.validate()) {
      AppLogger.warning(
        'Validación del formulario falló. No se enviará la actualización.',
        name: 'PerfilAlmacenPage',
      );
      return;
    }

    if (_almacenData == null) {
      AppLogger.warning(
        '_almacenData es null. No se puede actualizar.',
        name: 'PerfilAlmacenPage',
      );
      return;
    }

    final almacenId = _almacenData!['id']?.toString() ?? '';
    AppLogger.debug(
      'Almacen ID: $almacenId, '
      'telefono: ${_telefonoController.text.trim()}, '
      'nombre: ${_nombreController.text.trim()}',
      name: 'PerfilAlmacenPage',
    );

    if (almacenId.isEmpty) {
      AppLogger.error('ID del almacén está vacío', name: 'PerfilAlmacenPage');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: ID del almacén no válido'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final data = <String, dynamic>{
        'nombre_comercial': _nombreController.text.trim(),
        'ruc': _rucController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'direccion_texto': _direccionController.text.trim(),
        'latitude': double.tryParse(_latController.text) ?? 0.0,
        'longitude': double.tryParse(_lonController.text) ?? 0.0,
      };

      AppLogger.debug(
        'Enviando PUT /warehouses/$almacenId con data: $data',
        name: 'PerfilAlmacenPage',
      );

      await _almacenService.actualizarAlmacen(almacenId, data);

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado correctamente'),
          backgroundColor: AppColors.success,
        ),
      );
      await _cargarAlmacen();
    } catch (e) {
      AppLogger.error(
        'Error al actualizar perfil de almacén',
        name: 'PerfilAlmacenPage',
        error: e,
      );
      if (!mounted) return;
      final validationErrors = ApiErrorHandler.mapValidationErrors(e);
      setState(() {
        _isSubmitting = false;
        _fieldErrors = validationErrors;
      });
      if (validationErrors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al actualizar perfil: ${ApiErrorHandler.userMessage(e)}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _cancelarEdicion() {
    // Restaurar valores originales
    if (_almacenData != null) {
      _nombreController.text = _almacenData!['nombre_comercial'] ?? '';
      _rucController.text = _almacenData!['ruc'] ?? '';
      _telefonoController.text = _almacenData!['telefono'] ?? '';
      _direccionController.text = _almacenData!['direccion_texto'] ?? '';
      _latController.text = (_almacenData!['latitude'] ?? 0).toString();
      _lonController.text = (_almacenData!['longitude'] ?? 0).toString();
    }
    setState(() => _isEditing = false);
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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(),
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
                  : _errorMessage != null
                  ? RyStateContainer(
                      title: 'Error al cargar el perfil',
                      subtitle: _errorMessage,
                      type: RyStateType.error,
                    )
                  : _almacenData == null
                  ? const RyStateContainer(
                      title: 'Sin almacén',
                      subtitle:
                          'No tienes un almacén registrado. Regístrate para comenzar.',
                      type: RyStateType.empty,
                    )
                  : _isSubmitting
                  ? const RyStateContainer(
                      title: 'Guardando cambios...',
                      type: RyStateType.loading,
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.spacingMd),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.spacingLg),
                            _buildHeader(),
                            const SizedBox(height: AppSpacing.spacingXl),
                            _buildContactSection(),
                            const SizedBox(height: AppSpacing.spacingXl),
                            _buildLocationSection(),
                            const SizedBox(height: AppSpacing.spacingXl),
                            _buildActionsSection(),
                            // Ocultar "Cerrar Sesión" durante la edición
                            // para que no compita con Guardar/Cancelar.
                            if (!_isEditing) ...[
                              const SizedBox(height: AppSpacing.spacingXl),
                              _buildLogoutButton(),
                            ],
                            const SizedBox(height: AppSpacing.spacingMd),
                            _buildFooter(),
                            const SizedBox(height: AppSpacing.spacingXxl),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== DRAWER ==========

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              border: Border(
                bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
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
                  'Panel de Control (Almacén)',
                  style: AppTextStyles.textStyleCaption.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Panel Principal → WarehouseDashboard (tab solicitudes)
          ListTile(
            leading: const Icon(
              Icons.dashboard,
              color: AppColors.primaryContainer,
            ),
            title: Text('Panel Principal', style: AppTextStyles.textStyleBody),
            onTap: () {
              Navigator.pop(context);
              context.goNamed(RouteNames.dashboard);
            },
          ),
          // Cotizaciones Enviadas → WarehouseDashboard (tab cotizaciones)
          ListTile(
            leading: const Icon(Icons.send, color: AppColors.primaryContainer),
            title: Text(
              'Cotizaciones Enviadas',
              style: AppTextStyles.textStyleBody,
            ),
            onTap: () {
              Navigator.pop(context);
              context.goNamed(RouteNames.dashboard);
            },
          ),
          // Mi Almacén → PerfilAlmacenPage (página actual)
          ListTile(
            leading: const Icon(Icons.store, color: AppColors.primaryContainer),
            title: Text('Mi Almacén', style: AppTextStyles.textStyleBody),
            onTap: () => Navigator.pop(context),
          ),
          const Divider(color: AppColors.outlineVariant),
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
    );
  }

  // ========== TOP APP BAR ==========

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
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(
                    Icons.menu,
                    color: AppColors.primaryContainer,
                    size: 24,
                  ),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              const SizedBox(width: AppSpacing.spacingXxs),
              Text('Mi Almacén', style: AppTextStyles.textStyleTitle),
            ],
          ),
          if (!_isLoading && _almacenData != null)
            Semantics(
              button: true,
              label: _isEditing ? 'Cancelar edición' : 'Editar perfil',
              child: TextButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        if (_isEditing) {
                          _cancelarEdicion();
                        } else {
                          setState(() => _isEditing = true);
                        }
                      },
                icon: Icon(
                  _isEditing ? Icons.close : Icons.edit,
                  color: _isEditing ? AppColors.error : AppColors.primary,
                  size: 20,
                ),
                label: Text(
                  _isEditing ? 'Cancelar' : 'Editar',
                  style: AppTextStyles.textStyleButton.copyWith(
                    color: _isEditing ? AppColors.error : AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ========== HEADER ==========

  Widget _buildHeader() {
    final nombreComercial = _almacenData?['nombre_comercial'] ?? 'Almacén';
    final representanteLegal =
        _almacenData?['representante_legal'] ??
        _authService.currentUser?.nombreCompleto ??
        'Sin encargado';
    final verificationStatus =
        _almacenData?['verification_status'] ?? 'pending';
    final verificado = verificationStatus == 'approved';
    final estadoAbierto = _almacenData?['estado_abierto'] ?? true;

    String statusBadge;
    String statusLabel;
    switch (verificationStatus) {
      case 'approved':
        statusBadge = 'completed';
        statusLabel = 'Aprobado';
        break;
      case 'rejected':
        statusBadge = 'error';
        statusLabel = 'Rechazado';
        break;
      default:
        statusBadge = 'pending';
        statusLabel = 'En verificación';
    }

    return Semantics(
      label:
          'Almacén $nombreComercial, encargado: $representanteLegal, '
          'estado: $statusLabel, '
          '${estadoAbierto ? "abierto" : "cerrado"}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + nombre + encargado
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryContainer,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryContainer.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.store,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.spacingLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreComercial,
                      style: AppTextStyles.textStyleHeading,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.spacingXxs),
                    Text(
                      'Encargado: $representanteLegal',
                      style: AppTextStyles.textStyleCaption.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          // Badges de estado
          Wrap(
            spacing: AppSpacing.spacingSm,
            runSpacing: AppSpacing.spacingXs,
            children: [
              Semantics(
                label: 'Estado de verificación: $statusLabel',
                child: RyStatusBadge(
                  status: statusBadge,
                  customLabel: statusLabel,
                  style: RyStatusBadgeStyle.filled,
                  size: RyStatusBadgeSize.small,
                ),
              ),
              if (verificado)
                Semantics(
                  label: estadoAbierto
                      ? 'Estado del almacén: abierto'
                      : 'Estado del almacén: cerrado',
                  child: RyStatusBadge(
                    status: estadoAbierto ? 'available' : 'error',
                    customLabel: estadoAbierto ? 'Abierto' : 'Cerrado',
                    style: RyStatusBadgeStyle.filled,
                    size: RyStatusBadgeSize.small,
                  ),
                ),
            ],
          ),
          if (verificationStatus == 'rejected') ...[
            const SizedBox(height: AppSpacing.spacingMd),
            Container(
              padding: const EdgeInsets.all(AppSpacing.spacingMd),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Motivo del rechazo: ${_almacenData?['rejection_reason'] ?? "Revisa los datos ingresados o comunícate con soporte."}',
                style: AppTextStyles.textStyleSmall.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========== SECCIÓN: INFORMACIÓN DE CONTACTO ==========

  Widget _buildContactSection() {
    return RySectionCard(
      title: 'Información de Contacto',
      icon: Icons.contact_phone_outlined,
      children: [
        RyTextField(
          label: 'Nombre Comercial',
          prefixIcon: Icons.store_outlined,
          controller: _nombreController,
          isReadOnly: !_isEditing,
          isRequired: true,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El nombre comercial es requerido';
            }
            if (value.trim().length < 3) {
              return 'Debe tener al menos 3 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        RyTextField(
          label: 'RUC',
          prefixIcon: Icons.badge_outlined,
          controller: _rucController,
          type: RyTextFieldType.number,
          isReadOnly: !_isEditing,
          isRequired: true,
          maxLength: 13,
          errorText: _fieldErrors['ruc'],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El RUC es requerido';
            }
            if (value.trim().length != 13) {
              return 'El RUC debe tener exactamente 13 dígitos';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        RyTextField(
          label: 'Teléfono',
          prefixIcon: Icons.phone_android_outlined,
          type: RyTextFieldType.phone,
          controller: _telefonoController,
          isReadOnly: !_isEditing,
          isRequired: true,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El teléfono es requerido';
            }
            final trimmed = value.trim();
            // Acepta dígitos, +, espacios y guiones (patrón consistente
            // con el resto de la app que usa RyTextFieldType.phone)
            final phoneRegex = RegExp(r'^[0-9+\-\s()]{7,20}$');
            if (!phoneRegex.hasMatch(trimmed)) {
              return 'Ingresa un teléfono válido (mín. 7 dígitos)';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        RyTextField(
          label: 'Dirección',
          prefixIcon: Icons.location_on_outlined,
          controller: _direccionController,
          isReadOnly: !_isEditing,
          maxLines: 3,
          isRequired: true,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'La dirección es requerida';
            }
            if (value.trim().length < 5) {
              return 'La dirección debe tener al menos 5 caracteres';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ========== SECCIÓN: UBICACIÓN ==========

  Widget _buildLocationSection() {
    return RySectionCard(
      title: 'Ubicación',
      icon: Icons.map_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: RyTextField(
                label: 'Latitud',
                prefixIcon: Icons.my_location,
                controller: _latController,
                isReadOnly: !_isEditing,
                type: RyTextFieldType.decimal,
              ),
            ),
            const SizedBox(width: AppSpacing.spacingMd),
            Expanded(
              child: RyTextField(
                label: 'Longitud',
                prefixIcon: Icons.explore,
                controller: _lonController,
                isReadOnly: !_isEditing,
                type: RyTextFieldType.decimal,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        Text(
          'Coordenadas GPS del almacén. Edítalas si la ubicación no es precisa.',
          style: AppTextStyles.textStyleSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ========== SECCIÓN: ACCIONES ==========

  Widget _buildActionsSection() {
    if (!_isEditing) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'Guardar cambios del perfil de almacén',
          child: RyButton(
            label: 'Guardar Cambios',
            icon: Icons.save,
            variant: RyButtonVariant.primary,
            size: RyButtonSize.large,
            isFullWidth: true,
            isLoading: _isSubmitting,
            isDisabled: _isSubmitting,
            onPressed: _isSubmitting ? null : _guardarCambios,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        Semantics(
          button: true,
          label: 'Cancelar edición del perfil',
          child: RyButton(
            label: 'Cancelar',
            icon: Icons.close,
            variant: RyButtonVariant.outline,
            size: RyButtonSize.large,
            isFullWidth: true,
            onPressed: _cancelarEdicion,
          ),
        ),
      ],
    );
  }

  // ========== LOGOUT ==========

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

  // ========== FOOTER ==========

  Widget _buildFooter() {
    return Center(
      child: Text(
        'Versión 2.1.0',
        style: AppTextStyles.textStyleSmall.copyWith(
          color: AppColors.outlineVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
