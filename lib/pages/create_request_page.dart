import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import 'dart:io';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';
import '../services/vehiculo_service.dart';
import '../services/direccion_service.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_text_field.dart';
import '../widgets/ry_image_picker.dart';
import '../widgets/ry_state_container.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_logger.dart';

class CreateRequestPage extends StatefulWidget {
  const CreateRequestPage({super.key});

  @override
  State<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends State<CreateRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _piezaNombreController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController(); // Solo para mostrar

  File? _selectedImage;
  bool _isSubmitting = false;

  String? _selectedVehiculoId;
  String? _selectedDireccionId;
  String? _selectedPrioridad = 'estándar'; // 'urgente' o 'estándar'
  List<Map<String, dynamic>> _vehiculos = [];
  List<Map<String, dynamic>> _direcciones = [];
  bool _isLoadingVehiculos = false;
  bool _isLoadingDirecciones = false;

  final SolicitudService _solicitudService = SolicitudService();
  final AuthService _authService = AuthService();
  final VehiculoService _vehiculoService = VehiculoService();
  final DireccionService _direccionService = DireccionService();

  @override
  void initState() {
    super.initState();
    _cargarVehiculos();
    _cargarDirecciones();
  }

  @override
  void dispose() {
    _piezaNombreController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ========== CARGAR DATOS ==========

  Future<void> _cargarVehiculos() async {
    setState(() => _isLoadingVehiculos = true);
    try {
      final vehiculos = await _vehiculoService.getVehiculos();
      setState(() {
        _vehiculos = vehiculos;
      });
    } catch (e) {
      AppLogger.warning('Error al cargar vehículos: $e', name: 'CreateRequest');
    } finally {
      setState(() => _isLoadingVehiculos = false);
    }
  }

  Future<void> _cargarDirecciones() async {
    setState(() => _isLoadingDirecciones = true);
    try {
      AppLogger.debug(
        'Iniciando carga de direcciones...',
        name: 'CreateRequest.Direcciones',
      );
      final direcciones = await _direccionService.getDirecciones();
      AppLogger.debug(
        'Direcciones cargadas: ${direcciones.length}',
        name: 'CreateRequest.Direcciones',
      );

      setState(() {
        _direcciones = direcciones;
        // Seleccionar la dirección principal (si existe) o la primera
        if (direcciones.isNotEmpty) {
          final principal = direcciones.firstWhere(
            (d) => d['es_principal'] == true,
            orElse: () => direcciones.first,
          );
          _selectedDireccionId = principal['id'] as String?;
          _locationController.text = _formatDireccion(principal);
          AppLogger.debug(
            'Dirección seleccionada: $_selectedDireccionId',
            name: 'CreateRequest.Direcciones',
          );
        } else {
          _selectedDireccionId = null;
          _locationController.text = 'Selecciona o agrega una dirección';
          AppLogger.debug(
            'No hay direcciones disponibles',
            name: 'CreateRequest.Direcciones',
          );
        }
      });
    } catch (e) {
      AppLogger.warning(
        'Error al cargar direcciones: $e',
        name: 'CreateRequest.Direcciones',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar direcciones: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingDirecciones = false);
    }
  }

  String _formatDireccion(Map<String, dynamic> direccion) {
    final alias = direccion['alias'] as String? ?? '';
    final callePrincipal = direccion['calle_principal'] as String? ?? '';
    final calleSecundaria = direccion['calle_secundaria'] as String? ?? '';
    final referencia = direccion['referencia'] as String? ?? '';

    String texto = '';
    if (alias.isNotEmpty) texto += '$alias: ';
    texto += callePrincipal;
    if (calleSecundaria.isNotEmpty) texto += ' y $calleSecundaria';
    if (referencia.isNotEmpty) texto += ' ($referencia)';
    return texto.isEmpty ? 'Dirección sin nombre' : texto;
  }

  // ========== IMAGEN ==========

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.primaryContainer),
            const SizedBox(width: AppSpacing.spacingSm),
            Text(message, style: AppTextStyles.textStyleBody),
          ],
        ),
        backgroundColor: AppColors.surfaceContainerHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusFull),
          side: const BorderSide(color: AppColors.primaryContainer),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ========== AGREGAR NUEVA DIRECCIÓN ==========

  void _agregarDireccion() async {
    final aliasController = TextEditingController();
    final callePrincipalController = TextEditingController();
    final calleSecundariaController = TextEditingController();
    final referenciaController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.radiusXl),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: AppSpacing.spacingMd,
            right: AppSpacing.spacingMd,
            top: AppSpacing.spacingMd,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agregar nueva dirección',
                    style: AppTextStyles.textStyleTitle.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spacingMd),
                  RyTextField(
                    label: 'Alias (ej: Casa, Taller)',
                    controller: aliasController,
                    isRequired: true,
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Ingresa un alias'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.spacingSm),
                  RyTextField(
                    label: 'Calle principal',
                    controller: callePrincipalController,
                    isRequired: true,
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Ingresa la calle principal'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.spacingSm),
                  RyTextField(
                    label: 'Calle secundaria (opcional)',
                    controller: calleSecundariaController,
                  ),
                  const SizedBox(height: AppSpacing.spacingSm),
                  RyTextField(
                    label: 'Referencia (opcional)',
                    controller: referenciaController,
                  ),
                  const SizedBox(height: AppSpacing.spacingLg),
                  Row(
                    children: [
                      Expanded(
                        child: RyButton(
                          label: 'Cancelar',
                          variant: RyButtonVariant.text,
                          onPressed: () => Navigator.pop(context, false),
                        ),
                      ),
                      Expanded(
                        child: RyButton(
                          label: 'Guardar',
                          variant: RyButtonVariant.primary,
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              try {
                                final nueva = await _direccionService
                                    .createDireccion(
                                      alias: aliasController.text.trim(),
                                      callePrincipal: callePrincipalController
                                          .text
                                          .trim(),
                                      calleSecundaria: calleSecundariaController
                                          .text
                                          .trim(),
                                      referencia: referenciaController.text
                                          .trim(),
                                    );
                                // Cerrar modal con éxito
                                if (!context.mounted) return;
                                Navigator.pop(context, true);
                                // Recargar lista y seleccionar la nueva dirección
                                await _cargarDirecciones();
                                // Forzar selección de la nueva (por si no es principal)
                                setState(() {
                                  _selectedDireccionId = nueva['id'] as String?;
                                  _locationController.text = _formatDireccion(
                                    nueva,
                                  );
                                });
                                _showToast('Dirección agregada correctamente');
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Error al guardar dirección: $e',
                                    ),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.spacingSm),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ========== CAMBIAR DIRECCIÓN (diálogo) ==========

  void _changeLocation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: Text(
          'Seleccionar dirección de entrega',
          style: AppTextStyles.textStyleTitle,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _isLoadingDirecciones
              ? const RyStateContainer(
                  title: 'Cargando direcciones...',
                  type: RyStateType.loading,
                )
              : _direcciones.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No tienes direcciones registradas',
                      style: AppTextStyles.textStyleBody.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spacingMd),
                    RyButton(
                      label: 'Agregar dirección',
                      icon: Icons.add,
                      variant: RyButtonVariant.primary,
                      onPressed: () {
                        Navigator.pop(context);
                        _agregarDireccion();
                      },
                    ),
                  ],
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _direcciones.length,
                        itemBuilder: (context, index) {
                          final direccion = _direcciones[index];
                          final isSelected =
                              direccion['id'] == _selectedDireccionId;
                          return ListTile(
                            title: Text(
                              _formatDireccion(direccion),
                              style: AppTextStyles.textStyleBody,
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle,
                                    color: AppColors.primaryContainer,
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedDireccionId =
                                    direccion['id'] as String?;
                                _locationController.text = _formatDireccion(
                                  direccion,
                                );
                              });
                              Navigator.pop(context);
                              _showToast('Dirección actualizada');
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(color: AppColors.outlineVariant),
                    ListTile(
                      leading: const Icon(
                        Icons.add_circle,
                        color: AppColors.primaryContainer,
                      ),
                      title: Text(
                        'Agregar nueva dirección',
                        style: AppTextStyles.textStyleBody.copyWith(
                          color: AppColors.primaryContainer,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _agregarDireccion();
                      },
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: AppTextStyles.textStyleButton.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== ENVÍO DEL FORMULARIO ==========

  /// Sube una imagen al bucket `Repuestosya` (mismo bucket/carpeta base que
  /// usa el flujo de cotizaciones) bajo la ruta:
  /// `evidencias/solicitudes/{clienteId}/solicitud_{timestamp}.jpg`
  ///
  /// Devuelve la URL pública del archivo, o `null` si la subida falla.
  /// Sigue el mismo patrón que [CreateQuotationPage._uploadImageToSupabase]:
  /// verifica/refresca sesión, sube con `contentType: image/jpeg` y obtiene
  /// la URL pública con `getPublicUrl`.
  Future<String?> _uploadImageToSupabase(
    File imageFile,
    String clienteId,
  ) async {
    try {
      AppLogger.debug(
        '[UPLOAD] Iniciando subida de imagen de solicitud...',
        name: 'CreateRequestPage',
      );

      final supabase = Supabase.instance.client;

      // Verificar sesión de autenticación (mismo patrón que cotizaciones)
      final session = supabase.auth.currentSession;
      if (session == null) {
        AppLogger.warning(
          '[UPLOAD] No hay sesión activa. Intentando refrescar...',
          name: 'CreateRequestPage',
        );
        try {
          await supabase.auth.refreshSession();
          AppLogger.info(
            '[UPLOAD] Sesión refrescada',
            name: 'CreateRequestPage',
          );
        } catch (e) {
          AppLogger.error(
            '[UPLOAD] Error al refrescar sesión',
            name: 'CreateRequestPage',
            error: e,
          );
          return null;
        }
      }

      // Generar nombre único y ruta por dominio funcional
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'solicitud_$timestamp.jpg';
      final filePath = 'evidencias/solicitudes/$clienteId/$fileName';
      AppLogger.debug(
        '[UPLOAD] FilePath: $filePath (${await imageFile.length()} bytes)',
        name: 'CreateRequestPage',
      );

      // Subir al bucket `Repuestosya` (mismo bucket que cotizaciones)
      await supabase.storage
          .from('Repuestosya')
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );

      // Obtener URL pública (mismo patrón que cotizaciones)
      final publicUrl = supabase.storage
          .from('Repuestosya')
          .getPublicUrl(filePath);

      AppLogger.info(
        '[UPLOAD] URL pública: $publicUrl',
        name: 'CreateRequestPage',
      );

      return publicUrl;
    } catch (e, stackTrace) {
      AppLogger.error(
        '[UPLOAD] Error al subir imagen de solicitud',
        name: 'CreateRequestPage',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _handleSubmit() async {
    // Validar campos del formulario
    if (!_formKey.currentState!.validate()) return;

    // Validar vehículo
    if (_selectedVehiculoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar un vehículo'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Validar dirección
    if (_selectedDireccionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar una dirección de entrega'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado');

      // Subir imagen a Supabase Storage ANTES de crear la solicitud.
      // Si la subida falla, NO se crea la solicitud: se informa al usuario.
      String? fotoUrl;
      if (_selectedImage != null) {
        fotoUrl = await _uploadImageToSupabase(_selectedImage!, user.id);
        if (fotoUrl == null || fotoUrl.isEmpty) {
          setState(() => _isSubmitting = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No se pudo subir la imagen. Verifica tu conexión e inténtalo de nuevo.',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      await _solicitudService.crearSolicitud(
        clienteId: user.id,
        vehiculoId: _selectedVehiculoId!,
        piezaNombre: _piezaNombreController.text,
        descripcion: _descriptionController.text,
        fotoUrl: fotoUrl,
        direccionEntregaId: _selectedDireccionId!,
        esUrgente: _selectedPrioridad == 'urgente',
      );

      setState(() => _isSubmitting = false);

      if (mounted) {
        // Diálogo de éxito
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surfaceContainerHigh,
            title: Text(
              '¡Solicitud Enviada!',
              style: AppTextStyles.textStyleTitle.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            content: Text(
              'Tu solicitud ha sido enviada a nuestra red de proveedores. '
              'Te notificaremos cuando reciban ofertas.',
              style: AppTextStyles.textStyleBody.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar diálogo
                  Navigator.pop(context); // Volver a Home
                },
                child: Text(
                  'OK',
                  style: AppTextStyles.textStyleButton.copyWith(
                    color: AppColors.primaryContainer,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar solicitud: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ========== BUILD ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerHigh,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Crear Solicitud', style: AppTextStyles.textStyleHeading),
        actions: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: AppSpacing.spacingMd),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: const ClipOval(
              child: Icon(Icons.person, color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NUEVA BÚSQUEDA',
                    style: AppTextStyles.textStyleSmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppSpacing.spacingXxs),
                  Text(
                    '¿Qué pieza necesitas?',
                    style: AppTextStyles.textStyleDisplay,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.spacingXl),
              _buildImageSection(),
              const SizedBox(height: AppSpacing.spacingXl),
              _buildTextField(
                label: 'Nombre del repuesto',
                controller: _piezaNombreController,
                hint: 'Ej: Filtro de aceite, Disco de freno...',
                isRequired: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Ingresa el nombre del repuesto';
                  }
                  if (v.trim().length < 3) {
                    return 'El nombre debe tener al menos 3 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.spacingMd),
              _buildVehicleDropdown(),
              const SizedBox(height: AppSpacing.spacingMd),
              _buildTextField(
                label: 'Descripción del repuesto',
                controller: _descriptionController,
                hint:
                    'Ej: Amortiguador delantero derecho, marca original o equivalente de alta calidad...',
                maxLines: 4,
                isRequired: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Ingresa una descripción';
                  }
                  if (v.trim().length < 10) {
                    return 'La descripción debe tener al menos 10 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.spacingMd),
              _buildPrioritySection(),
              const SizedBox(height: AppSpacing.spacingMd),
              _buildLocationSection(),
              const SizedBox(height: AppSpacing.spacingXl),
              _buildProTip(),
              const SizedBox(height: AppSpacing.spacingXxl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildImageSection() {
    return RyImagePicker(
      width: double.infinity,
      height: 200,
      currentFile: _selectedImage,
      onImageSelected: (file) async {
        setState(() => _selectedImage = file);
        _showToast('Imagen cargada con éxito');
      },
      onRemove: () {
        setState(() => _selectedImage = null);
      },
    );
  }

  Widget _buildVehicleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Selecciona tu vehículo',
                style: AppTextStyles.textStyleSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: ' *',
                style: AppTextStyles.textStyleSmall.copyWith(
                  color: AppColors.requiredAsterisk,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedVehiculoId,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.spacingMd,
                  vertical: AppSpacing.spacingSm,
                ),
                border: InputBorder.none,
              ),
              dropdownColor: AppColors.surfaceContainerHigh,
              style: AppTextStyles.textStyleBody,
              icon: const Icon(
                Icons.expand_more,
                color: AppColors.onSurfaceVariant,
              ),
              items: _isLoadingVehiculos
                  ? [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Cargando vehículos...'),
                      ),
                    ]
                  : _vehiculos.isEmpty
                  ? [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('No hay vehículos registrados'),
                      ),
                    ]
                  : _vehiculos.map((vehiculo) {
                      final modelo =
                          vehiculo['modelos_vehiculo'] as Map<String, dynamic>?;
                      final marca =
                          modelo?['marcas_vehiculo'] as Map<String, dynamic>?;
                      final vin = vehiculo['vin'] as String? ?? '';
                      final nombre = marca != null && modelo != null
                          ? '${marca['nombre']} ${modelo['nombre']}'
                          : 'Vehículo';
                      return DropdownMenuItem(
                        value: vehiculo['id'] as String?,
                        child: Text(
                          '$nombre (VIN: ${vin.length > 4 ? '...${vin.substring(vin.length - 4)}' : vin})',
                        ),
                      );
                    }).toList(),
              onChanged: (value) => setState(() => _selectedVehiculoId = value),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Selecciona un vehículo';
                }
                return null;
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrioritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prioridad de la solicitud',
          style: AppTextStyles.textStyleSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        RadioGroup<String>(
          groupValue: _selectedPrioridad,
          onChanged: (value) => setState(() => _selectedPrioridad = value),
          child: Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: Text(
                    'Estándar',
                    style: AppTextStyles.textStyleCaption,
                  ),
                  value: 'estándar',
                  activeColor: AppColors.primaryContainer,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: Text('Urgente', style: AppTextStyles.textStyleCaption),
                  value: 'urgente',
                  activeColor: AppColors.error,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondaryContainer.withValues(alpha: 0.2),
            ),
            child: const Icon(
              Icons.location_on,
              color: AppColors.secondaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ubicación de entrega',
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  _locationController.text,
                  style: AppTextStyles.textStyleCaption.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          RyButton(
            label: 'Cambiar',
            variant: RyButtonVariant.text,
            size: RyButtonSize.small,
            onPressed: _changeLocation,
          ),
        ],
      ),
    );
  }

  Widget _buildProTip() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, color: AppColors.tertiaryContainer, size: 20),
          const SizedBox(width: AppSpacing.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consejo Pro',
                  style: AppTextStyles.textStyleTitle.copyWith(
                    color: AppColors.tertiaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingXxs),
                Text(
                  'Incluir el código VIN (Número de Chasis) garantiza una compatibilidad del 100% con tu motorización específica.',
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.8),
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: RyButton(
        label: 'BUSCAR REPUESTO',
        icon: Icons.search,
        variant: RyButtonVariant.primary,
        size: RyButtonSize.large,
        isLoading: _isSubmitting,
        isFullWidth: true,
        onPressed: _handleSubmit,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool isRequired = false,
    String? Function(String?)? validator,
  }) {
    return RyTextField(
      label: label,
      hint: hint,
      controller: controller,
      maxLines: maxLines,
      validator: validator,
    );
  }
}
