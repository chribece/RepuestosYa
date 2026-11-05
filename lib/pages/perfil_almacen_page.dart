import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/almacen_service.dart';
import '../services/almacen_repository.dart';
import '../services/auth_service.dart';
import '../services/geocoding_service.dart';
import '../services/ubicacion_service.dart';
import '../services/upload_service.dart';
import '../providers/profile_image_provider.dart';
import '../widgets/flujo_ubicacion.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_image_picker.dart';
import '../widgets/ry_text_field.dart';
import '../widgets/ry_dropdown_field.dart';
import '../widgets/ry_state_container.dart';
import '../widgets/ry_status_badge.dart';
import '../widgets/ry_section_card.dart';
import '../widgets/ry_nav_drawer.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import '../utils/contact_launcher.dart';
import '../utils/ry_snackbar.dart';
import '../router/route_names.dart';

class PerfilAlmacenPage extends StatefulWidget {
  /// Servicios inyectables para tests (mismo patrón que WarehouseDashboard);
  /// en producción se usan los servicios reales.
  final UbicacionService? ubicacionService;
  final GeocodingService? geocodingService;
  final AlmacenService? almacenService;

  const PerfilAlmacenPage({
    super.key,
    this.ubicacionService,
    this.geocodingService,
    this.almacenService,
  });

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
  final TextEditingController _ciudadController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();
  String _tipoEstablecimiento = 'matriz';

  bool _isEditing = false;
  bool _isSubmitting = false;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, String> _fieldErrors = {};
  Map<String, dynamic>? _almacenData;
  File? _logoFile;
  bool _removeLogo = false;

  late final AlmacenService _almacenService =
      widget.almacenService ??
      AlmacenService(context.read<AlmacenRepository>());
  final AuthService _authService = AuthService();
  late final UbicacionService _ubicacionService =
      widget.ubicacionService ?? UbicacionService();
  late final GeocodingService _geocodingService =
      widget.geocodingService ?? GeocodingService();

  @override
  void initState() {
    super.initState();
    _cargarAlmacen();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _rucController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _ciudadController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  double? _parseCoordinate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    final coordinate = double.tryParse(normalized);
    return coordinate != null && coordinate.isFinite ? coordinate : null;
  }

  bool _validWarehouseCoordinates(double? latitude, double? longitude) {
    return latitude != null &&
        longitude != null &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        !(latitude == 0 && longitude == 0);
  }

  void _setCoordinateControllers(
    dynamic latitudeValue,
    dynamic longitudeValue,
  ) {
    final latitude = double.tryParse(latitudeValue?.toString() ?? '');
    final longitude = double.tryParse(longitudeValue?.toString() ?? '');
    if (_validWarehouseCoordinates(latitude, longitude)) {
      _latController.text = latitude.toString();
      _lonController.text = longitude.toString();
    } else {
      _latController.clear();
      _lonController.clear();
    }
  }

  String? _validateCoordinatePair(String? _) {
    if (!_isEditing) return null;
    final latitudeText = _latController.text.trim();
    final longitudeText = _lonController.text.trim();
    if (latitudeText.isEmpty && longitudeText.isEmpty) return null;

    final latitude = _parseCoordinate(latitudeText);
    final longitude = _parseCoordinate(longitudeText);
    if (latitude == null || longitude == null) {
      return 'Ingresa latitud y longitud juntas';
    }
    if (!_validWarehouseCoordinates(latitude, longitude)) {
      return 'Las coordenadas deben ser válidas y no pueden ser 0, 0';
    }
    return null;
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
          _ciudadController.text = almacen['city']?.toString() ?? '';
          _tipoEstablecimiento =
              almacen['tipo_establecimiento']?.toString() ?? 'matriz';
          _setCoordinateControllers(almacen['latitude'], almacen['longitude']);
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
      mostrarSnackbarError(context, mensaje: 'Error: ID del almacén no válido');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final data = <String, dynamic>{
        'nombre_comercial': _nombreController.text.trim(),
        'ruc': _rucController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'direccion_texto': _direccionController.text.trim(),
        'city': _ciudadController.text.trim(),
        'tipo_establecimiento': _tipoEstablecimiento,
      };
      final latitude = _parseCoordinate(_latController.text);
      final longitude = _parseCoordinate(_lonController.text);
      if (_validWarehouseCoordinates(latitude, longitude)) {
        data['latitude'] = latitude;
        data['longitude'] = longitude;
      }

      if (_logoFile != null) {
        final userId = _authService.currentUser?.id;
        if (userId == null) {
          throw StateError('No se pudo identificar al usuario del logo');
        }
        final logoUrl = await UploadService().uploadProfileImage(
          _logoFile!,
          userId,
          isWarehouse: true,
        );
        if (logoUrl == null || logoUrl.isEmpty) {
          throw StateError('No se pudo subir el logo del establecimiento');
        }
        data['logo_url'] = logoUrl;
      } else if (_removeLogo) {
        data['logo_url'] = null;
      }

      AppLogger.debug(
        'Enviando PUT /warehouses/$almacenId con data: $data',
        name: 'PerfilAlmacenPage',
      );

      await _almacenService.actualizarAlmacen(almacenId, data);

      if (!mounted) return;
      if (data.containsKey('logo_url')) {
        final userId = _authService.currentUser?.id;
        if (userId != null) {
          context.read<ProfileImageProvider?>()?.setImageUrl(
            data['logo_url']?.toString(),
            userId: userId,
          );
        }
      }
      setState(() {
        _isSubmitting = false;
        _isEditing = false;
        _logoFile = null;
        _removeLogo = false;
      });
      mostrarSnackbarExito(
        context,
        mensaje: 'Perfil actualizado correctamente',
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
        mostrarSnackbarError(
          context,
          mensaje:
              'Error al actualizar perfil: ${ApiErrorHandler.userMessage(e)}',
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
      _ciudadController.text = _almacenData!['city']?.toString() ?? '';
      _tipoEstablecimiento =
          _almacenData!['tipo_establecimiento']?.toString() ?? 'matriz';
      _logoFile = null;
      _removeLogo = false;
      _setCoordinateControllers(
        _almacenData!['latitude'],
        _almacenData!['longitude'],
      );
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
                            const SizedBox(height: AppSpacing.spacingLg),
                            _buildLogoSection(),
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
    final nombre = _almacenData?['nombre_comercial']?.toString();
    return RyNavDrawer(
      subtitle: nombre != null && nombre.isNotEmpty
          ? 'Panel de Almacén · $nombre'
          : 'Panel de Almacén',
      imageUrl: _almacenData?['logo_url']?.toString(),
      items: [
        // Panel Principal → WarehouseDashboard (tab solicitudes)
        RyNavItem(
          icon: Icons.dashboard,
          label: 'Panel Principal',
          onTap: () {
            Navigator.pop(context);
            context.goNamed(RouteNames.dashboard);
          },
        ),
        // Cotizaciones Enviadas → WarehouseDashboard (tab cotizaciones)
        RyNavItem(
          icon: Icons.send,
          label: 'Cotizaciones Enviadas',
          onTap: () {
            Navigator.pop(context);
            context.goNamed(RouteNames.dashboard);
          },
        ),
        // Mi Establecimiento → PerfilAlmacenPage (página actual)
        RyNavItem(
          icon: Icons.store,
          label: 'Mi Establecimiento',
          selected: true,
          onTap: () => Navigator.pop(context),
        ),
      ],
      onLogout: () {
        Navigator.pop(context);
        _showLogoutDialog();
      },
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
                  tooltip: 'Abrir menú',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              const SizedBox(width: AppSpacing.spacingXxs),
              Text('Mi Establecimiento', style: AppTextStyles.textStyleTitle),
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
          'Establecimiento $nombreComercial, encargado: $representanteLegal, '
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

  Widget _buildLogoSection() {
    final logoUrl = _removeLogo ? null : _almacenData?['logo_url']?.toString();
    return RySectionCard(
      title: 'Logo del Establecimiento',
      icon: Icons.storefront_outlined,
      children: [
        Row(
          children: [
            if (_isEditing)
              RyImagePicker(
                currentImageUrl: logoUrl,
                currentFile: _logoFile,
                width: 112,
                height: 112,
                maxImageWidth: 1200,
                maxImageHeight: 1200,
                onImageSelected: (file) {
                  setState(() {
                    _logoFile = file;
                    _removeLogo = false;
                  });
                },
                onRemove: () {
                  setState(() {
                    _logoFile = null;
                    _removeLogo = true;
                  });
                },
                customPlaceholder: _buildLogoPlaceholder('Añadir logo'),
              )
            else
              _buildReadOnlyLogoPreview(logoUrl),
            const SizedBox(width: AppSpacing.spacingMd),
            Expanded(
              child: Text(
                _isEditing
                    ? 'Selecciona una imagen para representar tu establecimiento. Se guardará al confirmar los cambios.'
                    : logoUrl == null || logoUrl.isEmpty
                    ? 'Aún no has agregado un logo.'
                    : 'Identidad visual del establecimiento.',
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogoPlaceholder(String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.storefront_outlined,
          size: 36,
          color: AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.spacingXxs),
        Text(
          label,
          style: AppTextStyles.textStyleSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyLogoPreview(String? logoUrl) {
    return Container(
      width: 112,
      height: 112,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: logoUrl == null || logoUrl.isEmpty
          ? _buildLogoPlaceholder('Sin logo')
          : CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => _buildLogoPlaceholder(''),
              errorWidget: (_, _, _) => _buildLogoPlaceholder('Sin logo'),
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
          label: 'Nombre del Establecimiento',
          prefixIcon: Icons.store_outlined,
          controller: _nombreController,
          isReadOnly: !_isEditing,
          isRequired: true,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El nombre del establecimiento es requerido';
            }
            if (value.trim().length < 3) {
              return 'Debe tener al menos 3 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        RyDropdownField<String>(
          label: 'Tipo de Establecimiento',
          value: _tipoEstablecimiento,
          items: const ['matriz', 'sucursal'],
          itemLabelBuilder: (tipo) =>
              tipo == 'sucursal' ? 'Sucursal' : 'Matriz',
          onChanged: (tipo) {
            if (tipo != null) setState(() => _tipoEstablecimiento = tipo);
          },
          isRequired: true,
          enabled: _isEditing,
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
          label: 'Ciudad',
          prefixIcon: Icons.location_city_outlined,
          controller: _ciudadController,
          isReadOnly: !_isEditing,
          isRequired: true,
          errorText: _fieldErrors['city'],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'La ciudad es obligatoria';
            }
            if (value.trim().length < 2) {
              return 'Ingresa una ciudad válida';
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
            // Mínimo 9 dígitos (Ecuador) y máximo 15 (E.164 internacional):
            // coincide con el CHECK `^[0-9]{9,}$` de la tabla y con la
            // normalización que hace el backend (solo dígitos).
            if (!esTelefonoValido(value)) {
              return 'Ingresa un teléfono válido (mín. 9 dígitos)';
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

  /// Usa la ubicación actual del dispositivo (mismo flujo GPS que la
  /// dirección de una solicitud): fija lat/lng y autocompleta la dirección
  /// con reverse geocoding si aún no hay texto.
  Future<void> _usarUbicacionActual() async {
    final resultado = await flujoUbicacionGps(context, _ubicacionService);
    if (!mounted) return;
    if (!resultado.disponible) return; // el flujo ya mostró su aviso

    final lat = resultado.latitude;
    final lng = resultado.longitude;
    if (lat == null || lng == null) return;
    if (!_validWarehouseCoordinates(lat, lng)) {
      mostrarSnackbarAdvertencia(
        context,
        mensaje: 'El GPS devolvió una ubicación no válida. Inténtalo otra vez.',
      );
      return;
    }

    setState(() {
      _latController.text = lat.toStringAsFixed(6);
      _lonController.text = lng.toStringAsFixed(6);
    });

    // Autocompletar la dirección solo si está vacía (no pisar lo escrito).
    if (_direccionController.text.trim().isEmpty) {
      try {
        final geocode = await _geocodingService.reverseGeocode(
          lat: lat,
          lng: lng,
        );
        if (!mounted || geocode == null) return;
        final partes = <String>[
          if (geocode.callePrincipal != null &&
              geocode.callePrincipal!.isNotEmpty)
            geocode.callePrincipal!,
          if (geocode.referencia != null && geocode.referencia!.isNotEmpty)
            geocode.referencia!,
        ];
        if (partes.isNotEmpty) {
          setState(() => _direccionController.text = partes.join(', '));
        }
      } catch (e) {
        AppLogger.error(
          'Error al geocodificar ubicación del almacén',
          name: 'PerfilAlmacenPage',
          error: e,
        );
        // Degradación: el usuario puede escribir la dirección a mano.
      }
    }
  }

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
                validator: _validateCoordinatePair,
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
                validator: _validateCoordinatePair,
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
        if (_isEditing) ...[
          const SizedBox(height: AppSpacing.spacingSm),
          Semantics(
            button: true,
            label: 'Usar mi ubicación actual para el almacén',
            child: RyButton(
              label: 'Usar mi ubicación actual',
              icon: Icons.my_location,
              variant: RyButtonVariant.outline,
              size: RyButtonSize.small,
              isFullWidth: true,
              onPressed: _usarUbicacionActual,
            ),
          ),
        ],
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
