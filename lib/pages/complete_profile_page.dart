import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/almacen_service.dart';
import '../services/almacen_repository.dart';
import '../services/geocoding_service.dart';
import '../services/ubicacion_service.dart';
import '../widgets/ry_text_field.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_location_picker.dart';
import '../widgets/flujo_ubicacion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../router/route_names.dart';

/// Formulario de registro/completado del perfil de almacén.
///
/// La ubicación se define con el selector visual embebido (Opción A):
/// - Mapa interactivo con pin arrastrable (long-press) y tap-to-move,
///   etiquetado "Ubicación del Almacén", + botón "Usar mi ubicación actual".
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
  final TextEditingController _representanteController =
      TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();

  late final UbicacionService _ubicacionService =
      widget.ubicacionService ?? UbicacionService();
  late final GeocodingService _geocodingService =
      widget.geocodingService ?? GeocodingService();

  // Ubicación del almacén (se guarda internamente, sin inputs visibles).
  double? _lat;
  double? _lng;
  bool get _ubicacionFijada => _lat != null && _lng != null;

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

  @override
  void initState() {
    super.initState();
    _almacenService = AlmacenService(context.read<AlmacenRepository>());
    _direccionController.addListener(_onDireccionCambio);
    // Pre-llenar el nombre del representante desde el auth
    final currentUser = _authService.currentUser;
    if (currentUser?.nombreCompleto != null) {
      _representanteController.text = currentUser!.nombreCompleto!;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nombreController.dispose();
    _rucController.dispose();
    _representanteController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
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
    final resultado =
        await _geocodingService.reverseGeocode(lat: lat, lng: lng);
    if (!mounted || seq != _autocompletarSeq) return;

    setState(() {
      _autocompletando = false;
      if (resultado == null) return; // degradación: el usuario escribe
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
    if (!_ubicacionFijada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubica tu almacén en el mapa antes de continuar.'),
          backgroundColor: AppColors.warning,
        ),
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

      // Enviar datos del almacén al backend usando AlmacenService
      await _almacenService.crearAlmacen({
        'encargado_id': userId,
        'nombre_comercial': _nombreController.text.trim(),
        'ruc': _rucController.text.trim(),
        'representante_legal': _representanteController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'email': _authService.currentUser?.email ?? '',
        'direccion_texto': _direccionController.text.trim(),
        'latitude': _lat,
        'longitude': _lng,
      });

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Perfil completado exitosamente!'),
            backgroundColor: AppColors.primaryContainer,
            duration: Duration(seconds: 3),
          ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ApiErrorHandler.userMessage(e)),
              backgroundColor: AppColors.error,
            ),
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
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancelar',
                style: AppTextStyles.textStyleButton.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
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
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.spacingMd),
                  _buildWelcomeText(),
                  const SizedBox(height: AppSpacing.spacingXl),
                  _buildNombreField(),
                  const SizedBox(height: AppSpacing.spacingLg),
                  _buildRucField(),
                  const SizedBox(height: AppSpacing.spacingLg),
                  _buildRepresentanteField(),
                  const SizedBox(height: AppSpacing.spacingLg),
                  _buildTelefonoField(),
                  const SizedBox(height: AppSpacing.spacingLg),
                  // Ubicación: mapa embebido (reemplaza a lat/lng).
                  _buildUbicacionAlmacen(),
                  const SizedBox(height: AppSpacing.spacingLg),
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
          'Completa la información de tu almacén para comenzar.',
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildNombreField() {
    return RyTextField(
      label: 'Nombre Comercial',
      hint: 'Ej: RepuestosYa Central',
      controller: _nombreController,
      isRequired: true,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'El nombre comercial es requerido';
        }
        if (value.trim().length < 3) {
          return 'El nombre debe tener al menos 3 caracteres';
        }
        return null;
      },
    );
  }

  Widget _buildRucField() {
    return RyTextField(
      label: 'RUC',
      hint: 'Ej: 1712345678001',
      controller: _rucController,
      type: RyTextFieldType.number,
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
    );
  }

  Widget _buildRepresentanteField() {
    return RyTextField(
      label: 'Representante Legal',
      hint: 'Ej: Juan Pérez',
      controller: _representanteController,
      isRequired: true,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'El representante legal es requerido';
        }
        if (value.trim().length < 3) {
          return 'El nombre debe tener al menos 3 caracteres';
        }
        return null;
      },
    );
  }

  Widget _buildTelefonoField() {
    return RyTextField(
      label: 'Teléfono',
      hint: 'Ej: 999123456',
      controller: _telefonoController,
      type: RyTextFieldType.phone,
      isRequired: true,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'El teléfono es requerido';
        }
        if (value.trim().length < 9) {
          return 'El teléfono debe tener al menos 9 dígitos';
        }
        return null;
      },
    );
  }

  /// Selector de ubicación embebido: mapa con pin arrastrable + botón GPS.
  /// Las coordenadas se guardan internamente al mover el pin; sin inputs de
  /// latitud/longitud visibles.
  Widget _buildUbicacionAlmacen() {
    final pin = _ubicacionFijada
        ? LatLng(_lat!, _lng!)
        : _centroInicialQuito;

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
          Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                size: 18,
                color: AppColors.primaryContainer,
              ),
              const SizedBox(width: AppSpacing.spacingXs),
              Text(
                'Ubicación del Almacén',
                style: AppTextStyles.textStyleSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
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
          RyButton(
            label: 'Usar mi ubicación actual',
            icon: Icons.my_location,
            variant: RyButtonVariant.primary,
            isFullWidth: true,
            onPressed: _usarUbicacionActual,
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
    return RyTextField(
      label: 'Dirección',
      hint: 'Ej: Av. Principal 123, Ciudad',
      controller: _direccionController,
      maxLines: 3,
      isRequired: true,
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
    );
  }

  Widget _buildCompleteButton() {
    // No se usa RyButton porque su estado `isLoading` sustituye la etiqueta por
    // un spinner y aquí debe conservarse el texto visible 'PROCESANDO...'.
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _completarPerfil,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryContainer,
          disabledBackgroundColor: AppColors.primaryContainer.withValues(
            alpha: 0.4,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          ),
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
