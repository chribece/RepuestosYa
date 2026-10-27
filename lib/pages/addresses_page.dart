import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../services/direccion_service.dart';
import '../services/geocoding_service.dart';
import '../services/ubicacion_service.dart';
import '../utils/api_error_handler.dart';
import '../utils/ry_snackbar.dart';
import '../widgets/flujo_ubicacion.dart';
import '../widgets/ry_text_field.dart';
import '../widgets/ry_state_container.dart';
import '../widgets/ry_form_dialog.dart';
import '../widgets/nueva_direccion_sheet.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../widgets/ry_button.dart';

class AddressesPage extends StatefulWidget {
  final DireccionService? direccionService;
  final UbicacionService? ubicacionService;
  final GeocodingService? geocodingService;
  final Future<UbicacionResultado> Function()? resolverUbicacion;

  const AddressesPage({
    super.key,
    this.direccionService,
    this.ubicacionService,
    this.geocodingService,
    this.resolverUbicacion,
  });

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  late final DireccionService _direccionService =
      widget.direccionService ?? DireccionService();
  late final UbicacionService _ubicacionService =
      widget.ubicacionService ?? UbicacionService();

  List<Map<String, dynamic>> _direcciones = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarDirecciones();
  }

  Future<void> _cargarDirecciones() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final direcciones = await _direccionService.getDirecciones();
      setState(() {
        _direcciones = direcciones;
      });
    } catch (e) {
      if (mounted) {
        mostrarSnackbarError(
          context,
          mensaje:
              'Error al cargar direcciones: '
              '${ApiErrorHandler.userMessage(e)}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<UbicacionResultado> _resolverUbicacion() =>
      widget.resolverUbicacion?.call() ??
      flujoUbicacionGps(
        context,
        _ubicacionService,
        mostrarSnackbarSiNoDisponible: true,
      );

  void _mostrarFormulario([Map<String, dynamic>? direccion]) async {
    final resultado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.radiusXl),
        ),
      ),
      builder: (_) => NuevaDireccionSheet(
        direccion: direccion,
        direccionService: _direccionService,
        resolverUbicacion: _resolverUbicacion,
        geocodingService: widget.geocodingService,
      ),
    );

    if (resultado != null && mounted) _cargarDirecciones();
  }

  Future<void> _eliminarDireccion(String id) async {
    try {
      await _direccionService.deleteDireccion(id);
      if (mounted) {
        mostrarSnackbarExitoSobrio(
          context,
          mensaje: 'Dirección eliminada correctamente',
        );
      }
      if (mounted) _cargarDirecciones();
    } catch (e) {
      if (mounted) {
        mostrarSnackbarError(
          context,
          mensaje:
              'Error al eliminar dirección: '
              '${ApiErrorHandler.userMessage(e)}',
        );
      }
    }
  }

  Future<void> _confirmarEliminarDireccion(
    Map<String, dynamic> direccion,
  ) async {
    final id = direccion['id']?.toString();
    if (id == null || id.isEmpty) return;
    final alias = direccion['alias']?.toString().trim();
    final aliasVisible = alias == null || alias.isEmpty ? 'Dirección' : alias;
    final colorDestructivo = Color.alphaBlend(
      AppColors.error.withValues(alpha: 0.32),
      AppColors.surfaceContainerHigh,
    );

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          side: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        title: const Text(
          'Eliminar dirección',
          style: AppTextStyles.textStyleTitle,
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar la dirección '
          "'$aliasVisible'? Esta acción no se puede deshacer.",
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.spacingMd,
          AppSpacing.spacingXs,
          AppSpacing.spacingMd,
          AppSpacing.spacingMd,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.spacingSm,
                      ),
                      side: BorderSide(color: AppColors.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingSm),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: TextButton.styleFrom(
                      foregroundColor: SemanticColors.colorErrorText,
                      backgroundColor: colorDestructivo,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.spacingSm,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                      ),
                    ),
                    child: const Text('Eliminar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await _eliminarDireccion(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis Direcciones de Entrega'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Regresar',
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const RyStateContainer(
              title: 'Cargando direcciones...',
              type: RyStateType.loading,
            )
          : _direcciones.isEmpty
          ? const RyStateContainer(
              title: 'Sin direcciones',
              subtitle:
                  'No tienes direcciones registradas. Agrega tu primera dirección.',
              type: RyStateType.empty,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.spacingMd,
                AppSpacing.spacingMd,
                AppSpacing.spacingMd,
                AppSpacing.spacingXxxl +
                    AppSpacing.spacingXl +
                    AppSpacing.spacingXs,
              ),
              itemCount: _direcciones.length,
              itemBuilder: (context, index) {
                final direccion = _direcciones[index];

                final alias = direccion['alias'] as String? ?? 'Dirección';
                final ciudad = direccion['ciudad'] as String? ?? '';
                final callePrincipal =
                    direccion['calle_principal'] as String? ?? '';
                final calleSecundaria =
                    direccion['calle_secundaria'] as String? ?? '';
                final referencia = direccion['referencia'] as String? ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
                  padding: const EdgeInsets.all(AppSpacing.spacingMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(alias, style: AppTextStyles.textStyleBody),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  color: AppColors.primary,
                                ),
                                tooltip: 'Editar dirección',
                                onPressed: () => _mostrarFormulario(direccion),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: SemanticColors.colorErrorText,
                                ),
                                tooltip: 'Eliminar dirección',
                                onPressed: () =>
                                    _confirmarEliminarDireccion(direccion),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.spacingSm),
                      Text(
                        'Principal: $callePrincipal',
                        style: AppTextStyles.textStyleCaption.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      if (ciudad.isNotEmpty)
                        Text(
                          'Ciudad: $ciudad',
                          style: AppTextStyles.textStyleCaption.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      if (calleSecundaria.isNotEmpty)
                        Text(
                          'Secundaria: $calleSecundaria',
                          style: AppTextStyles.textStyleCaption.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      if (referencia.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.spacingXxs),
                        Text(
                          'Ref: $referencia',
                          style: AppTextStyles.textStyleSmall.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddressDialog extends StatefulWidget {
  final Map<String, dynamic>? direccion;
  final DireccionService? direccionService;
  final UbicacionService? ubicacionService;
  final GeocodingService? geocodingService;
  final Future<UbicacionResultado> Function()? resolverUbicacion;

  const AddressDialog({
    super.key,
    this.direccion,
    this.direccionService,
    this.ubicacionService,
    this.geocodingService,
    this.resolverUbicacion,
  });

  @override
  State<AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<AddressDialog> {
  final _formKey = GlobalKey<FormState>();
  late final DireccionService _direccionService =
      widget.direccionService ?? DireccionService();
  late final UbicacionService _ubicacionService =
      widget.ubicacionService ?? UbicacionService();
  late final GeocodingService _geocodingService =
      widget.geocodingService ?? GeocodingService();
  late final Future<UbicacionResultado> Function() _resolverUbicacion =
      widget.resolverUbicacion ??
      () => flujoUbicacionGps(context, _ubicacionService);

  late TextEditingController _aliasController;
  late TextEditingController _ciudadController;
  late TextEditingController _callePrincipalController;
  late TextEditingController _calleSecundariaController;
  late TextEditingController _referenciaController;

  bool _isSaving = false;
  bool _isLocating = false;
  bool _aplicandoAutocompletado = false;
  bool _ciudadEditadaPorUsuario = false;
  bool _calleEditadaPorUsuario = false;
  bool _calleSecundariaEditadaPorUsuario = false;
  bool _referenciaEditadaPorUsuario = false;
  bool _capturoGpsEnEstaEdicion = false;
  String? _gpsStatus;
  String? _coordenadasFuente;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();

    // Asignación correcta desde las nuevas llaves en la base de datos
    _aliasController = TextEditingController(
      text: widget.direccion?['alias'] ?? '',
    );
    _ciudadController = TextEditingController(
      text:
          GeocodingService.ciudadEcuadorValida(
            widget.direccion?['ciudad']?.toString(),
          ) ??
          '',
    );
    _callePrincipalController = TextEditingController(
      text: widget.direccion?['calle_principal'] ?? '',
    );
    _calleSecundariaController = TextEditingController(
      text: widget.direccion?['calle_secundaria'] ?? '',
    );
    _referenciaController = TextEditingController(
      text: widget.direccion?['referencia'] ?? '',
    );
    _latitude = double.tryParse(
      widget.direccion?['latitude']?.toString() ?? '',
    );
    _longitude = double.tryParse(
      widget.direccion?['longitude']?.toString() ?? '',
    );
    _coordenadasFuente = widget.direccion?['coordenadas_fuente']?.toString();
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _ciudadController.dispose();
    _callePrincipalController.dispose();
    _calleSecundariaController.dispose();
    _referenciaController.dispose();
    super.dispose();
  }

  Future<void> _usarUbicacionActual() async {
    if (_isLocating || _isSaving) return;
    setState(() => _isLocating = true);

    try {
      final ubicacion = await _resolverUbicacion();
      if (!mounted) return;
      if (!ubicacion.disponible) {
        if (ubicacion.estado != UbicacionEstado.cancelado) {
          setState(
            () => _gpsStatus = 'Puedes escribir la dirección manualmente.',
          );
        }
        return;
      }

      final latitude = ubicacion.latitude!;
      final longitude = ubicacion.longitude!;
      final reverse = await _geocodingService.reverseGeocode(
        lat: latitude,
        lng: longitude,
      );
      if (!mounted) return;

      setState(() {
        _latitude = latitude;
        _longitude = longitude;
        _coordenadasFuente = 'gps';
        _capturoGpsEnEstaEdicion = true;
        _gpsStatus = 'Ubicación actual capturada.';
        _aplicandoAutocompletado = true;
        final ciudad = GeocodingService.ciudadEcuadorValida(reverse?.ciudad);
        if (!_ciudadEditadaPorUsuario && ciudad != null) {
          _ciudadController.text = ciudad;
        }
        if (!_calleEditadaPorUsuario &&
            reverse?.callePrincipal?.trim().isNotEmpty == true) {
          _callePrincipalController.text = reverse!.callePrincipal!.trim();
        }
        if (!_referenciaEditadaPorUsuario &&
            reverse?.referencia?.trim().isNotEmpty == true) {
          _referenciaController.text = reverse!.referencia!.trim();
        }
        _aplicandoAutocompletado = false;
      });
    } catch (_) {
      if (mounted) {
        mostrarSnackbarError(
          context,
          mensaje: 'No se pudo obtener la ubicación. Puedes escribirla.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final conservarCoordenadasExistentes =
          widget.direccion != null &&
          !_ciudadEditadaPorUsuario &&
          !_calleEditadaPorUsuario &&
          !_calleSecundariaEditadaPorUsuario &&
          !_referenciaEditadaPorUsuario &&
          _latitude != null &&
          _longitude != null;
      final enviarCoordenadas =
          _capturoGpsEnEstaEdicion || conservarCoordenadasExistentes;
      final latitude = enviarCoordenadas ? _latitude : null;
      final longitude = enviarCoordenadas ? _longitude : null;
      final coordenadasFuente = _capturoGpsEnEstaEdicion
          ? 'gps'
          : _coordenadasFuente;

      if (widget.direccion == null) {
        // Crear dirección consumiendo el servicio estructurado camelCase
        await _direccionService.createDireccion(
          alias: _aliasController.text.trim(),
          ciudad: _ciudadController.text.trim(),
          callePrincipal: _callePrincipalController.text.trim(),
          calleSecundaria: _calleSecundariaController.text.trim(),
          referencia: _referenciaController.text.trim(),
          latitude: latitude,
          longitude: longitude,
          coordenadasFuente: coordenadasFuente,
        );
      } else {
        // Actualizar dirección pasando el ID correspondiente
        await _direccionService.updateDireccion(
          id: widget.direccion!['id'],
          alias: _aliasController.text.trim().isEmpty
              ? null
              : _aliasController.text.trim(),
          ciudad: _ciudadController.text.trim().isEmpty
              ? null
              : _ciudadController.text.trim(),
          callePrincipal: _callePrincipalController.text.trim().isEmpty
              ? null
              : _callePrincipalController.text.trim(),
          calleSecundaria: _calleSecundariaController.text.trim().isEmpty
              ? null
              : _calleSecundariaController.text.trim(),
          referencia: _referenciaController.text.trim().isEmpty
              ? null
              : _referenciaController.text.trim(),
          latitude: latitude,
          longitude: longitude,
          coordenadasFuente: coordenadasFuente,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        mostrarSnackbarError(
          context,
          mensaje:
              'Error al guardar la dirección: '
              '${ApiErrorHandler.userMessage(e)}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RyFormDialog(
      title: widget.direccion == null
          ? 'Agregar Dirección'
          : 'Editar Dirección',
      backgroundColor: const Color(0xFF1E1E1E),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGpsSection(),
            const SizedBox(height: AppSpacing.spacingMd),
            RyTextField(
              label: 'Alias (Ej. Casa, Trabajo)',
              controller: _aliasController,
              isRequired: true,
              helperText: 'Mínimo 2 caracteres',
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return 'El alias debe tener al menos 2 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            RyTextField(
              label: 'Ciudad',
              controller: _ciudadController,
              isRequired: true,
              hint: 'Ej: Quito',
              helperText: 'Si GPS no la detecta, ingrésala manualmente.',
              onChanged: (_) {
                if (!_aplicandoAutocompletado) {
                  _ciudadEditadaPorUsuario = true;
                }
              },
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'La ciudad es obligatoria'
                  : null,
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            RyTextField(
              label: 'Calle Principal',
              controller: _callePrincipalController,
              isRequired: true,
              helperText: 'Mínimo 5 caracteres',
              onChanged: (_) {
                if (!_aplicandoAutocompletado) {
                  _calleEditadaPorUsuario = true;
                }
              },
              validator: (value) {
                if (value == null || value.trim().length < 5) {
                  return 'La calle principal debe tener al menos 5 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            RyTextField(
              label: 'Calle Secundaria (Opcional)',
              controller: _calleSecundariaController,
              onChanged: (_) {
                if (!_aplicandoAutocompletado) {
                  _calleSecundariaEditadaPorUsuario = true;
                }
              },
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            RyTextField(
              label: 'Referencia / Indicaciones (Opcional)',
              controller: _referenciaController,
              maxLines: 2,
              onChanged: (_) {
                if (!_aplicandoAutocompletado) {
                  _referenciaEditadaPorUsuario = true;
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              Expanded(
                child: RyButton(
                  label: 'Cancelar',
                  variant: RyButtonVariant.outline,
                  size: RyButtonSize.small,
                  isFullWidth: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: AppSpacing.spacingSm),
              Expanded(
                child: RyButton(
                  label: 'Guardar',
                  variant: RyButtonVariant.primary,
                  size: RyButtonSize.small,
                  isFullWidth: true,
                  isLoading: _isSaving,
                  isDisabled: _isSaving,
                  onPressed: _isSaving ? null : _guardar,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGpsSection() {
    final hasLocation = _latitude != null && _longitude != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.my_location_rounded,
                color: AppColors.primaryContainer,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.spacingXs),
              Text('Ubicación (GPS)', style: AppTextStyles.textStyleBody),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingXs),
          Text(
            _gpsStatus ??
                (hasLocation
                    ? 'Ubicación registrada. Puedes actualizarla.'
                    : 'Completa la dirección con tu ubicación actual.'),
            style: AppTextStyles.textStyleSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          RyButton(
            label: 'Mi ubicación actual',
            icon: Icons.my_location_rounded,
            variant: RyButtonVariant.primary,
            size: RyButtonSize.small,
            isFullWidth: true,
            horizontalPadding: AppSpacing.spacingMd,
            isLoading: _isLocating,
            isDisabled: _isLocating || _isSaving,
            onPressed: _isLocating || _isSaving ? null : _usarUbicacionActual,
          ),
        ],
      ),
    );
  }
}
