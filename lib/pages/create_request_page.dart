import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import 'dart:io';
import '../models/part_catalog.dart';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';
import '../services/vehiculo_service.dart';
import '../services/direccion_service.dart';
import '../services/catalog_service.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_text_field.dart';
import '../widgets/ry_dropdown_field.dart';
import '../widgets/ry_image_picker.dart';
import '../widgets/ry_state_container.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import '../router/route_names.dart';
import '../providers/create_request_provider.dart';

class CreateRequestPage extends StatefulWidget {
  const CreateRequestPage({super.key});

  @override
  State<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends State<CreateRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController(); // Solo para mostrar

  bool _isSubmitting = false;
  Map<String, String> _fieldErrors = {};

  // Catálogo (mantener listas locales para los dropdowns)
  List<PartCategory> _categories = [];
  List<CatalogPart> _parts = [];
  bool _isLoadingCategories = false;
  bool _isLoadingParts = false;
  String? _categoryError;
  String? _partError;

  List<Map<String, dynamic>> _vehiculos = [];
  List<Map<String, dynamic>> _direcciones = [];
  bool _isLoadingVehiculos = false;
  bool _isLoadingDirecciones = false;

  final SolicitudService _solicitudService = SolicitudService();
  final AuthService _authService = AuthService();
  final VehiculoService _vehiculoService = VehiculoService();
  final DireccionService _direccionService = DireccionService();
  final CatalogService _catalogService = CatalogService();

  @override
  void initState() {
    super.initState();
    _cargarVehiculos();
    _cargarDirecciones();
    _cargarCategorias();

    // Restaurar categoría/repuestos si ya hay una seleccionada en el provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CreateRequestProvider>();
      if (provider.selectedCategoryId != null) {
        _cargarRepuestos(provider.selectedCategoryId!);
      }
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  // ========== CARGAR DATOS ==========

  Future<void> _cargarVehiculos() async {
    setState(() => _isLoadingVehiculos = true);
    try {
      final vehiculos = await _vehiculoService.getVehiculos();
      if (!mounted) return;

      // Deduplicar por ID
      final Map<String, Map<String, dynamic>> uniqueVehiculos = {};
      for (var v in vehiculos) {
        if (v['id'] != null) {
          uniqueVehiculos[v['id'].toString()] = v;
        }
      }

      setState(() {
        _vehiculos = uniqueVehiculos.values.toList();
      });
    } catch (e) {
      AppLogger.warning('Error al cargar vehículos: $e', name: 'CreateRequest');
    } finally {
      if (mounted) setState(() => _isLoadingVehiculos = false);
    }
  }

  Future<void> _cargarCategorias() async {
    setState(() {
      _isLoadingCategories = true;
      _categoryError = null;
    });
    try {
      final categories = await _catalogService.getPartCategories();
      if (!mounted) return;

      // Deduplicar por ID
      final Map<String, PartCategory> uniqueCategories = {};
      for (var cat in categories) {
        uniqueCategories[cat.id] = cat;
      }

      setState(() {
        _categories = uniqueCategories.values.toList();
      });
    } catch (e) {
      AppLogger.error('Error al cargar categorías: $e', name: 'CreateRequest');
      if (mounted) {
        setState(() {
          _categoryError = 'Error al cargar categorías';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _cargarRepuestos(String categoryId) async {
    setState(() {
      _isLoadingParts = true;
      _partError = null;
      _parts = [];
    });
    try {
      final parts = await _catalogService.getParts(categoryId: categoryId);
      if (!mounted) return;

      // Deduplicar por ID
      final Map<String, CatalogPart> uniqueParts = {};
      for (var part in parts) {
        uniqueParts[part.id] = part;
      }

      setState(() {
        _parts = uniqueParts.values.toList();
      });
    } catch (e) {
      AppLogger.error('Error al cargar repuestos: $e', name: 'CreateRequest');
      if (mounted) {
        setState(() {
          _partError = 'Error al cargar repuestos';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingParts = false);
    }
  }

  Future<void> _cargarDirecciones() async {
    setState(() => _isLoadingDirecciones = true);
    try {
      final direcciones = await _direccionService.getDirecciones();
      if (!mounted) return;

      // Deduplicar por ID
      final Map<String, Map<String, dynamic>> uniqueDirecciones = {};
      for (var d in direcciones) {
        if (d['id'] != null) {
          uniqueDirecciones[d['id'].toString()] = d;
        }
      }

      setState(() {
        _direcciones = uniqueDirecciones.values.toList();
        final provider = context.read<CreateRequestProvider>();

        // Seleccionar la dirección principal (si existe) o la primera,
        // pero solo si el provider no tiene una ya seleccionada.
        if (direcciones.isNotEmpty) {
          final principal = direcciones.firstWhere(
            (d) => d['es_principal'] == true,
            orElse: () => direcciones.first,
          );

          if (provider.selectedDireccionId == null) {
            provider.updateDireccion(principal['id'] as String?);
          }

          // Actualizar controlador de texto con la dirección actual del provider (o la principal)
          final currentId = provider.selectedDireccionId ?? principal['id'];
          final currentDir = direcciones.firstWhere(
            (d) => d['id'] == currentId,
            orElse: () => principal,
          );
          _locationController.text = _formatDireccion(currentDir);
        }
      });
    } catch (e) {
      AppLogger.warning(
        'Error al cargar direcciones: $e',
        name: 'CreateRequest.Direcciones',
      );
    } finally {
      if (mounted) setState(() => _isLoadingDirecciones = false);
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
            const Icon(Icons.check_circle, color: SemanticColors.colorSuccess),
            const SizedBox(width: AppSpacing.spacingSm),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.textStyleBody.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceContainerHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusFull),
          side: const BorderSide(color: SemanticColors.colorSuccess),
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
                                if (context.mounted) {
                                  context
                                      .read<CreateRequestProvider>()
                                      .updateDireccion(nueva['id'] as String?);
                                  setState(() {
                                    _locationController.text = _formatDireccion(
                                      nueva,
                                    );
                                  });
                                }
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
                              direccion['id'] ==
                              context
                                  .read<CreateRequestProvider>()
                                  .selectedDireccionId;
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
                              context
                                  .read<CreateRequestProvider>()
                                  .updateDireccion(direccion['id'] as String?);
                              setState(() {
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
    // 1. Limpiar errores previos
    setState(() => _fieldErrors = {});

    // 2. Validar campos del formulario (incluye autovalidate)
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<CreateRequestProvider>();

    // 3. Validaciones contextuales manuales (para dropdowns/estado no gestionado por Form)
    bool hasManualErrors = false;
    if (provider.selectedCategoryId == null) {
      setState(
        () => _categoryError =
            'Debes seleccionar una categoría para filtrar los repuestos.',
      );
      hasManualErrors = true;
    }
    if (provider.selectedPartId == null) {
      setState(() => _partError = 'Debes seleccionar un repuesto de la lista.');
      hasManualErrors = true;
    }
    if (provider.selectedVehiculoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debes seleccionar un vehículo para asegurar la compatibilidad.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      hasManualErrors = true;
    }
    if (provider.selectedDireccionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indica dónde deseas recibir el repuesto.'),
          backgroundColor: AppColors.warning,
        ),
      );
      hasManualErrors = true;
    }

    if (hasManualErrors) return;

    setState(() => _isSubmitting = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado');

      // Subir imagen
      String? fotoUrl;
      if (provider.selectedImage != null) {
        fotoUrl = await _uploadImageToSupabase(
          provider.selectedImage!,
          user.id,
        );
        if (fotoUrl == null || fotoUrl.isEmpty) {
          setState(() => _isSubmitting = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No se pudo subir la imagen. Verifica tu conexión.',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      // Crear solicitud
      await _solicitudService.crearSolicitud(
        clienteId: user.id,
        vehiculoId: provider.selectedVehiculoId!,
        piezaNombre: provider.piezaNombre,
        descripcion: provider.descripcion,
        fotoUrl: fotoUrl,
        direccionEntregaId: provider.selectedDireccionId!,
        esUrgente: provider.selectedPrioridad == 'urgente',
        categoriaId: provider.selectedCategoryId!,
        repuestoId: provider.selectedPartId!,
        repuestoNombreSnapshot: provider.partNameSnapshot!,
        descripcionProblema: provider.descripcion,
      );

      if (!mounted) return;

      // Éxito: limpiar provider y navegar
      provider.clear();
      setState(() => _isSubmitting = false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          title: const Text('¡Solicitud Enviada!'),
          content: const Text(
            'Tu solicitud ha sido enviada. Te notificaremos cuando recibas ofertas.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        // Mapeo de errores 422 del backend
        _fieldErrors = ApiErrorHandler.mapValidationErrors(e);
      });

      if (_fieldErrors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiErrorHandler.userMessage(e, context: ApiErrorContext.session),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ========== BUILD ==========

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CreateRequestProvider>();

    // Reconstruir objetos seleccionados desde las listas actuales por ID
    PartCategory? selectedCategory;
    if (provider.selectedCategoryId != null && _categories.isNotEmpty) {
      final matches = _categories.where(
        (c) => c.id == provider.selectedCategoryId,
      );
      if (matches.isNotEmpty) {
        selectedCategory = matches.first;
      } else {
        // La categoría guardada ya no está en la lista (ej: eliminada del catálogo)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'La categoría seleccionada ya no está disponible. Selecciona una nueva.',
                ),
              ),
            );
            provider.setSelectedCategoryId(null);
          }
        });
      }
    }

    CatalogPart? selectedPart;
    if (provider.selectedPartId != null && _parts.isNotEmpty) {
      final matches = _parts.where((p) => p.id == provider.selectedPartId);
      if (matches.isNotEmpty) {
        selectedPart = matches.first;
      } else {
        // El repuesto guardado ya no está en la lista
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'El repuesto seleccionado ya no está disponible. Selecciona uno nuevo.',
                ),
              ),
            );
            provider.setSelectedPartId(null, null);
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerHigh,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: Text('Crear Solicitud', style: AppTextStyles.textStyleHeading),
        actions: [
          InkWell(
            onTap: () {
              context.pushNamed(RouteNames.profile);
            },
            borderRadius: BorderRadius.circular(AppRadius.radiusXl),
            child: Container(
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
                  const SizedBox(height: AppSpacing.spacingXxs),
                  Text(
                    '¿Qué repuesto necesitas?',
                    style: AppTextStyles.textStyleDisplay,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.spacingXl),
              _buildImageSection(provider),
              const SizedBox(height: AppSpacing.spacingXl),
              RyDropdownField<PartCategory>(
                label: 'Categoría de repuesto',
                hint: 'Selecciona una categoría',
                isRequired: true,
                items: _categories,
                value: selectedCategory,
                isLoading: _isLoadingCategories,
                errorText: _categoryError ?? _fieldErrors['categoria_id'],
                itemLabelBuilder: (c) => c.nombre,
                onChanged: (val) {
                  provider.setSelectedCategoryId(val?.id);
                  setState(() {
                    _categoryError = null;
                    _parts = []; // Limpiar repuestos locales mientras carga
                  });
                  if (val != null) {
                    _cargarRepuestos(val.id);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.spacingMd),
              RyDropdownField<CatalogPart>(
                label: 'Repuesto',
                hint: provider.selectedCategoryId == null
                    ? 'Selecciona primero una categoría'
                    : 'Selecciona el repuesto',
                isRequired: true,
                items: _parts,
                value: selectedPart,
                enabled: provider.selectedCategoryId != null,
                isLoading: _isLoadingParts,
                errorText: _partError ?? _fieldErrors['repuesto_id'],
                itemLabelBuilder: (p) => p.nombre,
                onChanged: (val) {
                  provider.setSelectedPartId(val?.id, val?.nombre);
                  setState(() => _partError = null);
                },
              ),
              const SizedBox(height: AppSpacing.spacingMd),
              _buildVehicleDropdown(provider),
              const SizedBox(height: AppSpacing.spacingMd),
              RyTextField(
                label: 'Detalles adicionales',
                initialValue: provider.descripcion,
                hint:
                    'Ej: Amortiguador delantero derecho, marca original o equivalente de alta calidad...',
                maxLines: 4,
                isRequired: true,
                errorText: _fieldErrors['descripcion'],
                onChanged: provider.updateDescripcion,
                validator: (v) {
                  // Regla derivada del contrato: la descripción ayuda a identificar el repuesto específico.
                  // Se aplica una restricción de negocio de mínimo 10 caracteres.
                  if (v == null || v.trim().isEmpty) {
                    return 'Por favor ingresa detalles adicionales para ayudar a identificar tu repuesto.';
                  }
                  if (v.trim().length < 10) {
                    return 'La descripción es muy corta. Ingresa al menos 10 caracteres (ej: marca, lado, color).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.spacingMd),
              _buildPrioritySection(provider),
              const SizedBox(height: AppSpacing.spacingMd),
              _buildLocationSection(provider),
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

  Widget _buildImageSection(CreateRequestProvider provider) {
    return RyImagePicker(
      width: double.infinity,
      height: 200,
      currentFile: provider.selectedImage,
      onImageSelected: (file) async {
        provider.updateImage(file);
        _showToast('Imagen cargada con éxito');
      },
      onRemove: () {
        provider.updateImage(null);
      },
    );
  }

  Widget _buildVehicleDropdown(CreateRequestProvider provider) {
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
            border: Border.all(
              color: (_fieldErrors.containsKey('vehiculo_id'))
                  ? AppColors.error
                  : AppColors.outlineVariant,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              initialValue: (_isLoadingVehiculos ||
                      !_vehiculos.any(
                        (v) =>
                            v['id']?.toString() == provider.selectedVehiculoId,
                      ))
                  ? null
                  : provider.selectedVehiculoId,
              autovalidateMode: AutovalidateMode.onUserInteraction,
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
                  : _vehiculos
                        .map((vehiculo) => vehiculo['id']?.toString())
                        .where((id) => id != null)
                        .toSet() // Deduplicar IDs
                        .map((id) {
                          final vehiculo = _vehiculos.firstWhere(
                            (v) => v['id']?.toString() == id,
                          );
                          final modelo =
                              vehiculo['modelos_vehiculo']
                                  as Map<String, dynamic>?;
                          final marca =
                              modelo?['marcas_vehiculo']
                                  as Map<String, dynamic>?;
                          final vin = vehiculo['vin'] as String? ?? '';
                          final nombre = marca != null && modelo != null
                              ? '${marca['nombre']} ${modelo['nombre']}'
                              : 'Vehículo';
                          return DropdownMenuItem(
                            value: id,
                            child: Text(
                              '$nombre (VIN: ${vin.length > 4 ? '...${vin.substring(vin.length - 4)}' : vin})',
                            ),
                          );
                        })
                        .toList(),
              onChanged: provider.updateVehiculo,
              validator: (v) {
                // Regla derivada del contrato: vehiculo_id es obligatorio (FK)
                if (v == null || v.isEmpty) {
                  return 'Debes seleccionar un vehículo de tu garaje para filtrar repuestos compatibles.';
                }
                return null;
              },
            ),
          ),
        ),
        if (_fieldErrors.containsKey('vehiculo_id'))
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              _fieldErrors['vehiculo_id']!,
              style: AppTextStyles.textStyleSmall.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPrioritySection(CreateRequestProvider provider) {
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
          groupValue: provider.selectedPrioridad,
          onChanged: (value) {
            if (value != null) provider.updatePrioridad(value);
          },
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

  Widget _buildLocationSection(CreateRequestProvider provider) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        border: Border.all(
          color: _fieldErrors.containsKey('direccion_entrega_id')
              ? AppColors.error
              : AppColors.outlineVariant.withValues(alpha: 0.3),
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
                    color: AppColors.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_fieldErrors.containsKey('direccion_entrega_id'))
                  Text(
                    _fieldErrors['direccion_entrega_id']!,
                    style: AppTextStyles.textStyleSmall.copyWith(
                      color: AppColors.error,
                    ),
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
}
