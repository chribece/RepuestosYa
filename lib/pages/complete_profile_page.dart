import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/almacen_service.dart';
import '../services/almacen_repository.dart';
import '../services/geocoding_service.dart';
import '../services/ubicacion_service.dart';
import '../services/upload_service.dart';
import '../providers/profile_image_provider.dart';
import '../widgets/ry_text_field.dart';
import '../widgets/ry_location_picker.dart';
import '../widgets/ry_dropdown_field.dart';
import '../widgets/ry_image_picker.dart';
import '../widgets/ecuador_phone_prefix.dart';
import '../widgets/flujo_ubicacion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/ecuador_mobile_phone.dart';
import '../utils/ry_snackbar.dart';
import '../router/route_names.dart';

/// Formulario de registro/completado del perfil del establecimiento.
///
/// La ubicación se define con el selector visual embebido (Opción A):
/// - Mapa interactivo con pin arrastrable (long-press) y tap-to-move,
///   etiquetado "Ubicación del Establecimiento", + botón "Usar mi ubicación actual".
/// - Al mover el pin o usar el GPS se hace reverse geocoding (Nominatim) y la
///   "Dirección" se presurtiene automáticamente si está vacía (o no fue
///   editada por el usuario).
/// - Las coordenadas se guardan internamente en el estado al mover el pin;
///   NO hay inputs de latitud/longitud visibles.
class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({
    super.key,
    this.ubicacionService,
    this.geocodingService,
  });

  /// Inyectables para tests; por defecto servicios reales.
  final UbicacionService? ubicacionService;
  final GeocodingService? geocodingService;

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _rucController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _representanteController =
      TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _ciudadController = TextEditingController();
  File? _logoFile;
  String _tipoEstablecimiento = 'matriz';
  bool _ciudadEditadaPorUsuario = false;

  late final UbicacionService _ubicacionService =
      widget.ubicacionService ?? UbicacionService();
  late final GeocodingService _geocodingService =
      widget.geocodingService ?? GeocodingService();

  // Ubicación del establecimiento (se guarda internamente, sin inputs visibles).
  double? _lat;
  double? _lng;
  bool get _ubicacionFijada => _lat != null && _lng != null;
  bool get _ubicacionValida =>
      _ubicacionFijada &&
      _lat!.isFinite &&
      _lng!.isFinite &&
      _lat! >= -90 &&
      _lat! <= 90 &&
      _lng! >= -180 &&
      _lng! <= 180 &&
      !(_lat == 0 && _lng == 0);

  // Autocompletado de la Dirección desde el mapa (reverse geocoding).
  Timer? _debounceTimer;
  int _autocompletarSeq = 0;
  bool _aplicandoAutocompletado = false;
  bool _direccionEditadaPorUsuario = false;
  bool _direccionAutocompletada = false;
  bool _autocompletando = false;

  bool _isSubmitting = false;
  bool _isConfirmingExit = false;
  Map<String, String> _fieldErrors = {};
  final AuthService _authService = AuthService();
  late final AlmacenService _almacenService;

  // Centro inicial del mapa: núcleo urbano de Quito (alcance actual).
  static const LatLng _centroInicialQuito = LatLng(-0.2201, -78.5128);

  bool get _telefonoRegistrado =>
      tieneTelefonoMovilEcuador(_authService.currentUser?.telefono);

  @override
  void initState() {
    super.initState();
    _almacenService = AlmacenService(context.read<AlmacenRepository>());
    _direccionController.addListener(_onDireccionCambio);
    // Pre-llenar el nombre del representante desde el auth
    final currentUser = _authService.currentUser;
    _emailController.text = currentUser?.email ?? '';
    if (currentUser?.nombreCompleto != null) {
      _representanteController.text = currentUser!.nombreCompleto!;
    }
    // Pre-llenar el teléfono capturado en el registro (coordinación de
    // entrega): el usuario no debe volver a escribirlo.
    final telefonoRegistrado = currentUser?.telefono;
    if (telefonoRegistrado != null && telefonoRegistrado.isNotEmpty) {
      _telefonoController.text = telefonoRegistrado;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nombreController.dispose();
    _rucController.dispose();
    _emailController.dispose();
    _representanteController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _ciudadController.dispose();
    super.dispose();
  }

  void _onDireccionCambio() {
    if (_aplicandoAutocompletado) return;
    if (_direccionController.text.isEmpty) {
      // Borró el autocompletado: vuelve a permitir autocompletar.
      _direccionEditadaPorUsuario = false;
      _direccionAutocompletada = false;
    } else {
      _direccionEditadaPorUsuario = true;
      _direccionAutocompletada = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _usarUbicacionActual() async {
    // Flujo compartido: progreso → Reintentar / Abrir Ajustes / manual.
    final resultado = await flujoUbicacionGps(context, _ubicacionService);
    if (!mounted) return;
    if (resultado.disponible) {
      setState(() {
        _lat = resultado.latitude;
        _lng = resultado.longitude;
      });
      _solicitarAutocompletadoDireccion(
        resultado.latitude!,
        resultado.longitude!,
      );
    }
    // Si el GPS no resuelve: el usuario escribe la dirección (el backend la
    // geocodifica al registrar el almacén).
  }

  /// Debounce del reverse geocoding: al arrastrar el pin se disparan muchos
  /// eventos; solo se consulta tras 700ms de reposo (respetando el límite de
  /// uso de Nominatim).
  void _solicitarAutocompletadoDireccion(double lat, double lng) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 700),
      () => _autocompletarDireccion(lat, lng),
    );
  }

  Future<void> _autocompletarDireccion(double lat, double lng) async {
    final seq = ++_autocompletarSeq;
    if (mounted) setState(() => _autocompletando = true);
    final resultado = await _geocodingService.reverseGeocode(
      lat: lat,
      lng: lng,
    );
    if (!mounted || seq != _autocompletarSeq) return;

    setState(() {
      _autocompletando = false;
      if (resultado == null) return; // degradación: el usuario escribe
      if (!_ciudadEditadaPorUsuario && resultado.ciudad != null) {
        _ciudadController.text = resultado.ciudad!;
      }
      if (_direccionEditadaPorUsuario) return;

      final partes = <String>[
        if (resultado.callePrincipal != null &&
            resultado.callePrincipal!.isNotEmpty)
          resultado.callePrincipal!,
        if (resultado.referencia != null && resultado.referencia!.isNotEmpty)
          resultado.referencia!,
      ];
      final texto = partes.join(', ');
      if (texto.isEmpty) return;

      _aplicandoAutocompletado = true;
      _direccionController.text = texto;
      _aplicandoAutocompletado = false;
      _direccionAutocompletada = true;
    });
  }

  void _moverPin(LatLng latLng) {
    setState(() {
      _lat = latLng.latitude;
      _lng = latLng.longitude;
    });
    // Reverse geocoding en vivo (debounced) para presurtir la Dirección.
    _solicitarAutocompletadoDireccion(latLng.latitude, latLng.longitude);
  }

  Future<void> _completarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    // La ubicación en el mapa es obligatoria para un almacén comercial.
    if (!_ubicacionValida) {
      mostrarSnackbarAdvertencia(
        context,
        mensaje: 'Selecciona una ubicación GPS válida antes de continuar.',
      );
      return;
    }

    setState(() => _fieldErrors = {});

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Obtener el ID del usuario actual
      final userId = _authService.currentUser?.id;
      if (userId == null) {
        throw Exception('No se pudo obtener el ID del usuario');
      }

      String? logoUrl;
      if (_logoFile != null) {
        logoUrl = await UploadService().uploadProfileImage(
          _logoFile!,
          userId,
          isWarehouse: true,
        );
        if (logoUrl == null || logoUrl.isEmpty) {
          throw StateError('No se pudo subir el logo del establecimiento');
        }
      }

      // Enviar datos del almacén al backend usando AlmacenService
      final almacenCreado = await _almacenService.crearAlmacen({
        'encargado_id': userId,
        'nombre_comercial': _nombreController.text.trim(),
        'tipo_establecimiento': _tipoEstablecimiento,
        'logo_url': logoUrl,
        'ruc': _rucController.text.trim(),
        'representante_legal': _representanteController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'email': _emailController.text.trim(),
        'direccion_texto': _direccionController.text.trim(),
        'city': _ciudadController.text.trim(),
        'latitude': _lat,
        'longitude': _lng,
      });
      final telefonoGuardado =
          almacenCreado['telefono']?.toString() ??
          _telefonoController.text.trim();
      _authService.updateCurrentUserPhone(telefonoGuardado);
      if (mounted) {
        context.read<ProfileImageProvider?>()?.setImageUrl(
          logoUrl,
          userId: userId,
        );
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        mostrarSnackbarExitoSobrio(
          context,
          mensaje: '¡Perfil completado exitosamente!',
          duracion: const Duration(seconds: 3),
        );
        // Navegar al dashboard
        context.goNamed(RouteNames.dashboard);
      }
    } catch (e) {
      if (mounted) {
        final validationErrors = ApiErrorHandler.mapValidationErrors(e);
        setState(() {
          _isSubmitting = false;
          _fieldErrors = validationErrors;
        });
        if (validationErrors.isEmpty) {
          mostrarSnackbarError(
            context,
            mensaje: ApiErrorHandler.userMessage(e),
          );
        }
      }
    }
  }

  /// Intercepta el intento de retroceder (botón atrás del AppBar o gesto del
  /// sistema). Como esta pantalla es un gate obligatorio sin pantalla anterior
  /// válida, se ofrece cerrar sesión con confirmación; el router redirige a
  /// /welcome automáticamente al emitirse el AuthState con usuario nulo.
  Future<void> _confirmarSalida() async {
    if (_isSubmitting || _isConfirmingExit) return;
    _isConfirmingExit = true;
    try {
      final salir = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          title: Text(
            'Salir del registro',
            style: AppTextStyles.textStyleTitle,
          ),
          content: Text(
            'Tu perfil de almacén aún no está completo. Si sales, tu sesión '
            'se cerrará y deberás iniciar sesión nuevamente.',
            style: AppTextStyles.textStyleBody.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          actions: [
            GFButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              type: GFButtonType.transparent,
              color: Colors.transparent,
              textColor: AppColors.primary,
              size: 48,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spacingMd,
                vertical: AppSpacing.spacingSm,
              ),
              child: Text(
                'Cancelar',
                style: AppTextStyles.textStyleButton.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
            GFButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              type: GFButtonType.transparent,
              color: Colors.transparent,
              textColor: AppColors.error,
              size: 48,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spacingMd,
                vertical: AppSpacing.spacingSm,
              ),
              child: Text(
                'Cerrar sesión',
                style: AppTextStyles.textStyleButton.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      );

      if (salir == true && mounted) {
        await _authService.signOut();
      }
    } finally {
      _isConfirmingExit = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // /complete-profile se alcanza siempre con context.goNamed(...), que
      // reemplaza el stack completo de navegación: no existe una pantalla
      // anterior válida a la que volver (login, dashboard y perfil de almacén
      // redirigen de nuevo aquí cuando el perfil no existe). El botón atrás
      // y el gesto del sistema se interceptan para ofrecer la única salida
      // coherente: cerrar sesión.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmarSalida();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 28,
            ),
            tooltip: 'Salir',
            onPressed: _confirmarSalida,
          ),
          title: Text(
            'Completar Perfil',
            style: AppTextStyles.textStyleTitle.copyWith(
              color: AppColors.onSurface,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.spacingLg,
              AppSpacing.spacingMd,
              AppSpacing.spacingLg,
              AppSpacing.spacingXl,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeText(),
                  const SizedBox(height: AppSpacing.spacingLg),
                  _buildSectionHeading(
                    'Datos del negocio',
                    Icons.storefront_outlined,
                  ),
                  const SizedBox(height: AppSpacing.spacingSm),
                  _buildNombreField(),
                  const SizedBox(height: AppSpacing.spacingMd),
                  _buildLogoField(),
                  const SizedBox(height: AppSpacing.spacingMd),
                  _buildTipoEstablecimientoField(),
                  const SizedBox(height: AppSpacing.spacingMd),
                  _buildRucField(),
                  const SizedBox(height: AppSpacing.spacingLg),
                  _buildSectionHeading(
                    'Datos de contacto',
                    Icons.contact_phone_outlined,
                  ),
                  const SizedBox(height: AppSpacing.spacingSm),
                  _buildEmailField(),
                  const SizedBox(height: AppSpacing.spacingMd),
                  _buildRepresentanteField(),
                  if (!_telefonoRegistrado) ...[
                    const SizedBox(height: AppSpacing.spacingMd),
                    _buildTelefonoField(),
                  ],
                  const SizedBox(height: AppSpacing.spacingLg),
                  _buildSectionHeading(
                    'Ubicación y cobertura',
                    Icons.location_on_outlined,
                  ),
                  const SizedBox(height: AppSpacing.spacingSm),
                  _buildCiudadField(),
                  const SizedBox(height: AppSpacing.spacingMd),
                  _buildUbicacionAlmacen(),
                  const SizedBox(height: AppSpacing.spacingMd),
                  _buildDireccionField(),
                  const SizedBox(height: AppSpacing.spacingXl),
                  _buildCompleteButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeading(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: AppSpacing.spacingSm),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.textStyleTitle.copyWith(
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledField(
    String label,
    Widget field, {
    bool isRequired = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            style: AppTextStyles.textStyleSmall.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
            children: [
              if (isRequired)
                TextSpan(
                  text: ' *',
                  style: const TextStyle(color: AppColors.requiredAsterisk),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXxs),
        field,
      ],
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¡Bienvenido!',
          style: AppTextStyles.textStyleHeading.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        Text(
          'Completa la información de tu establecimiento para comenzar.',
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildNombreField() {
    return _buildLabeledField(
      'Nombre del Establecimiento',
      RyTextField(
        semanticLabel: 'Nombre del Establecimiento',
        hint: 'Ej: RepuestosYa Central',
        controller: _nombreController,
        isDense: true,
        isRequired: true,
        prefixIcon: Icons.storefront_outlined,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'El nombre del establecimiento es requerido';
          }
          if (value.trim().length < 3) {
            return 'El nombre debe tener al menos 3 caracteres';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildTipoEstablecimientoField() {
    return RyDropdownField<String>(
      label: 'Tipo de Establecimiento',
      value: _tipoEstablecimiento,
      items: const ['matriz', 'sucursal'],
      itemLabelBuilder: (tipo) => switch (tipo) {
        'matriz' => 'Matriz',
        'sucursal' => 'Sucursal',
        _ => tipo,
      },
      onChanged: (tipo) {
        if (tipo != null) setState(() => _tipoEstablecimiento = tipo);
      },
      isRequired: true,
    );
  }

  Widget _buildLogoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Logo del Establecimiento (opcional)',
          style: AppTextStyles.textStyleSmall.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        Row(
          children: [
            RyImagePicker(
              currentFile: _logoFile,
              width: 112,
              height: 112,
              maxImageWidth: 1200,
              maxImageHeight: 1200,
              allowCamera: true,
              allowGallery: true,
              onImageSelected: (file) => setState(() => _logoFile = file),
              onRemove: () => setState(() => _logoFile = null),
              customPlaceholder: const Icon(
                Icons.storefront_outlined,
                size: 42,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.spacingMd),
            Expanded(
              child: Text(
                'Elige una imagen clara para identificar tu negocio.',
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

  Widget _buildCiudadField() {
    return _buildLabeledField(
      'Ciudad',
      RyTextField(
        semanticLabel: 'Ciudad del establecimiento',
        hint: 'Ej: Quito',
        controller: _ciudadController,
        isDense: true,
        isRequired: true,
        prefixIcon: Icons.location_city_outlined,
        errorText: _fieldErrors['city'],
        onChanged: (_) => _ciudadEditadaPorUsuario = true,
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
    );
  }

  Widget _buildRucField() {
    return _buildLabeledField(
      'RUC',
      RyTextField(
        semanticLabel: 'RUC',
        hint: 'Ej: 1712345678001',
        controller: _rucController,
        type: RyTextFieldType.number,
        isDense: true,
        isRequired: true,
        maxLength: 13,
        prefixIcon: Icons.badge_outlined,
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
    );
  }

  Widget _buildRepresentanteField() {
    return _buildLabeledField(
      'Representante Legal',
      RyTextField(
        semanticLabel: 'Representante Legal',
        hint: 'Ej: Juan Pérez',
        controller: _representanteController,
        isDense: true,
        isRequired: true,
        prefixIcon: Icons.person_outline,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'El representante legal es requerido';
          }
          if (value.trim().length < 3) {
            return 'El nombre debe tener al menos 3 caracteres';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildEmailField() {
    return _buildLabeledField(
      'Correo electrónico',
      RyTextField(
        semanticLabel: 'Correo electrónico de la cuenta Google',
        controller: _emailController,
        isDense: true,
        isReadOnly: true,
        prefixIcon: Icons.mail_outline,
        helperText: 'Correo asociado a tu cuenta.',
        helperStyle: AppTextStyles.textStyleCaption.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
      isRequired: false,
    );
  }

  Widget _buildTelefonoField() {
    return _buildLabeledField(
      'Teléfono',
      RyTextField(
        semanticLabel: 'Teléfono',
        hint: 'Ej: 981894367',
        controller: _telefonoController,
        type: RyTextFieldType.phone,
        isDense: true,
        keyboardType: TextInputType.phone,
        inputFormatters: ecuadorMobilePhoneInputFormatters(),
        isRequired: true,
        prefixWidget: const EcuadorPhonePrefix(),
        helperText: '9 dígitos sin el 0 inicial',
        helperStyle: AppTextStyles.textStyleCaption.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
        helperMaxLines: 1,
        validator: (value) {
          return validarTelefonoMovilEcuador(value);
        },
      ),
    );
  }

  /// Selector de ubicación embebido: mapa con pin arrastrable + botón GPS.
  /// Las coordenadas se guardan internamente al mover el pin; sin inputs de
  /// latitud/longitud visibles.
  Widget _buildUbicacionAlmacen() {
    final pin = _ubicacionFijada ? LatLng(_lat!, _lng!) : _centroInicialQuito;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.spacingXs,
            runSpacing: AppSpacing.spacingXs,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.storefront_outlined,
                    size: 18,
                    color: AppColors.primaryContainer,
                  ),
                  const SizedBox(width: AppSpacing.spacingXs),
                  Text(
                    'Ubicación del Establecimiento',
                    style: AppTextStyles.textStyleSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (_ubicacionFijada)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.spacingXs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified,
                        color: SemanticColors.colorSuccess,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ubicación fijada',
                        style: AppTextStyles.textStyleSmall.copyWith(
                          color: SemanticColors.colorSuccess,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          RyLocationMapPicker(
            initialPosition: pin,
            height: 220,
            // Sin pin fantasma: el marcador aparece cuando el usuario toca el
            // mapa o cuando el GPS/GPS fija la posición (showPin). Al resolver
            // el GPS, el picker recentra la cámara en el punto automáticamente.
            showPin: _ubicacionFijada,
            // Al mover el pin se guardan las coordenadas internamente y se
            // dispara el reverse geocoding (debounced) para presurtir la
            // Dirección. NO se pide al usuario interactuar con números.
            onChanged: _moverPin,
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _usarUbicacionActual,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                backgroundColor: AppColors.surfaceContainerHigh,
                side: BorderSide(
                  color: AppColors.primaryContainer.withValues(alpha: 0.65),
                ),
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spacingMd,
                  vertical: AppSpacing.spacingSm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                ),
                textStyle: AppTextStyles.textStyleButton,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.my_location),
                  const SizedBox(width: AppSpacing.spacingXs),
                  const Flexible(
                    child: Text(
                      'Usar mi ubicación actual',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_autocompletando || _direccionAutocompletada) ...[
            const SizedBox(height: AppSpacing.spacingXs),
            Row(
              children: [
                _autocompletando
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.edit_location_alt_outlined,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                const SizedBox(width: AppSpacing.spacingXs),
                Expanded(
                  child: Text(
                    _autocompletando
                        ? 'Obteniendo la dirección desde el mapa…'
                        : 'Dirección autocompletada desde el mapa. Revisa y corrige.',
                    style: AppTextStyles.textStyleSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDireccionField() {
    return _buildLabeledField(
      'Dirección',
      RyTextField(
        semanticLabel: 'Dirección',
        hint: 'Ej: De Los Jaribues, Marianitas',
        controller: _direccionController,
        maxLines: 2,
        hintMaxLines: 2,
        isDense: true,
        isRequired: true,
        prefixIcon: Icons.location_on_outlined,
        errorText: _fieldErrors['direccion_texto'],
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
    );
  }

  Widget _buildCompleteButton() {
    // No se usa RyButton porque su estado `isLoading` sustituye la etiqueta por
    // un spinner y aquí debe conservarse el texto visible 'PROCESANDO...'.
    // GFButton mantiene el patrón con un `child` custom (spinner + label).
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: GFButton(
        onPressed: _isSubmitting ? null : _completarPerfil,
        type: GFButtonType.solid,
        color: AppColors.primaryContainer,
        textColor: AppColors.onPrimaryContainer,
        disabledColor: AppColors.primaryContainer.withValues(alpha: 0.4),
        disabledTextColor: AppColors.onPrimaryContainer,
        elevation: 0,
        size: 56,
        borderShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.spacingSm),
                  Text(
                    'PROCESANDO...',
                    style: AppTextStyles.textStyleButton.copyWith(
                      color: AppColors.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.spacingXs),
                  Text(
                    'COMPLETAR PERFIL',
                    style: AppTextStyles.textStyleButton.copyWith(
                      color: AppColors.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
