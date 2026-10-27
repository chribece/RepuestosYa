import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/part_catalog.dart';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';
import '../services/vehiculo_service.dart';
import '../services/direccion_service.dart';
import '../services/catalog_service.dart';
import '../services/ubicacion_service.dart';
import '../services/solicitud_repository.dart';
import '../services/outbox.dart';
import '../services/upload_service.dart';
import '../providers/solicitudes_provider.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_bottom_action_bar.dart';
import '../widgets/ry_text_field.dart';
import '../widgets/ry_dropdown_field.dart';
import '../widgets/flujo_ubicacion.dart';
import '../widgets/ry_image_picker.dart';
import '../widgets/nueva_direccion_sheet.dart';
import '../widgets/ry_state_container.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import '../utils/business_rules.dart';
import '../utils/ry_snackbar.dart';
import '../router/route_names.dart';
import '../providers/create_request_provider.dart';

class CreateRequestPage extends StatefulWidget {
  const CreateRequestPage({
    super.key,
    this.solicitudService,
    this.vehiculoService,
    this.direccionService,
    this.catalogService,
    this.ubicacionService,
    this.isOnboardingFlow = false,
    this.initialCategoryId,
  });

  /// Servicios inyectables para widget tests (Fase 2 de docs/TESTING.md):
  /// en producción se usan las instancias reales.
  final SolicitudService? solicitudService;
  final VehiculoService? vehiculoService;
  final DireccionService? direccionService;
  final CatalogService? catalogService;
  final UbicacionService? ubicacionService;
  final bool isOnboardingFlow;
  final String? initialCategoryId;

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
  final Map<String, List<CatalogPart>> _partsByCategoryId = {};
  final Set<String> _loadingAdditionalParts = {};
  final Set<String> _expandedAdditionalParts = {};
  final Map<String, String> _additionalCategoryErrors = {};
  final Map<String, String> _additionalPartErrors = {};
  bool _isLoadingCategories = false;
  bool _isLoadingParts = false;
  String? _categoryError;
  String? _partError;

  List<Map<String, dynamic>> _vehiculos = [];
  List<Map<String, dynamic>> _direcciones = [];
  bool _isLoadingVehiculos = false;
  bool _isLoadingDirecciones = false;

  late final SolicitudService _solicitudService =
      widget.solicitudService ?? SolicitudService();
  final AuthService _authService = AuthService();
  late final VehiculoService _vehiculoService =
      widget.vehiculoService ?? VehiculoService();
  late final DireccionService _direccionService =
      widget.direccionService ?? DireccionService();
  late final CatalogService _catalogService =
      widget.catalogService ?? CatalogService();
  late final UbicacionService _ubicacionService =
      widget.ubicacionService ?? UbicacionService();

  // Coordenadas GPS capturadas para la dirección seleccionada (se limpian al
  // cambiar de dirección; viajan al payload/Outbox si la dirección no las
  // tenía registradas).
  double? _gpsLat;
  double? _gpsLng;

  @override
  void initState() {
    super.initState();
    _cargarVehiculos();
    _cargarDirecciones();
    _cargarCategorias();

    // Restaurar categoría/repuestos si ya hay una seleccionada en el provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CreateRequestProvider>();
      final initialCategoryId = widget.initialCategoryId;
      if (initialCategoryId != null && initialCategoryId.isNotEmpty) {
        provider.prepareNewRequestForCategory(initialCategoryId);
      }
      if (provider.selectedCategoryId != null) {
        _cargarRepuestos(provider.selectedCategoryId!);
      }
      final additionalParts = provider.additionalParts;
      final firstIncomplete = additionalParts
          .where((part) => part.repuestoId == null)
          .firstOrNull;
      if (firstIncomplete != null && mounted) {
        setState(() => _expandedAdditionalParts.add(firstIncomplete.id));
      }
      for (final additionalPart in additionalParts) {
        _cargarRepuestosAdicional(additionalPart);
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
    if (_vehiculos.isEmpty) {
      setState(() => _isLoadingVehiculos = true);
    }
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
        _isLoadingVehiculos = false;
      });
    } catch (e) {
      AppLogger.warning(
        'Error red al cargar vehículos, intentando local...',
        name: 'CreateRequest',
      );

      // INTENTO CARGA LOCAL
      try {
        if (!mounted) return;
        final repository = context.read<SolicitudRepository>();
        final localVehiculos = await repository.obtenerVehiculosLocal();
        if (localVehiculos.isNotEmpty) {
          if (mounted) {
            setState(() {
              _vehiculos = localVehiculos;
              _isLoadingVehiculos = false;
            });
          }
          return;
        }
      } catch (localError) {
        AppLogger.error('Error carga local vehículos: $localError');
      }
      if (mounted) setState(() => _isLoadingVehiculos = false);
    }
  }

  Future<void> _cargarCategorias() async {
    final connectivity = await Connectivity().checkConnectivity();
    final bool isOffline = connectivity.contains(ConnectivityResult.none);
    if (!mounted) return;

    // 1. Si estamos offline, ir directo a la base local para evitar esperas
    if (isOffline) {
      AppLogger.info(
        'Offline: Cargando categorías desde caché local',
        name: 'CreateRequest',
      );
      try {
        final repository = context.read<SolicitudRepository>();
        final localCategories = await repository.obtenerCategoriasLocal();
        if (mounted && localCategories.isNotEmpty) {
          setState(() {
            _categories = localCategories;
            _isLoadingCategories = false;
            _categoryError = null;
          });
          return;
        }
      } catch (e) {
        AppLogger.error('Error cargando categorías locales: $e');
      }
    }

    // 2. Si hay red o la base local estaba vacía, intentar servidor
    if (_categories.isEmpty) {
      setState(() {
        _isLoadingCategories = true;
        _categoryError = null;
      });
    }

    try {
      final categories = await _catalogService.getPartCategories();
      if (!mounted) return;

      final Map<String, PartCategory> uniqueCategories = {};
      for (var cat in categories) {
        uniqueCategories[cat.id] = cat;
      }

      setState(() {
        _categories = uniqueCategories.values.toList();
        _isLoadingCategories = false;
        _categoryError = null;
      });

      // Guardar en caché para la próxima vez que estemos offline
      final repository = context.read<SolicitudRepository>();
      await repository.guardarCategorias(_categories);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          if (_categories.isEmpty) {
            _categoryError = 'Error al cargar categorías';
          }
        });
      }
    }
  }

  Future<List<CatalogPart>> _obtenerRepuestos(String categoryId) async {
    final cachedParts = _partsByCategoryId[categoryId];
    if (cachedParts != null) return cachedParts;

    final connectivity = await Connectivity().checkConnectivity();
    final bool isOffline = connectivity.contains(ConnectivityResult.none);
    if (!mounted) return [];

    if (isOffline) {
      AppLogger.info(
        'Offline: Cargando repuestos desde caché local',
        name: 'CreateRequest',
      );
      try {
        final repository = context.read<SolicitudRepository>();
        final localParts = await repository.obtenerRepuestosLocal(categoryId);
        if (localParts.isNotEmpty) {
          _partsByCategoryId[categoryId] = localParts;
          return localParts;
        }
      } catch (e) {
        AppLogger.error('Error cargando repuestos locales: $e');
      }
    }

    final parts = await _catalogService.getParts(categoryId: categoryId);
    if (!mounted) return [];

    final uniqueParts = <String, CatalogPart>{};
    for (final part in parts) {
      uniqueParts[part.id] = part;
    }
    final result = uniqueParts.values.toList();
    _partsByCategoryId[categoryId] = result;

    final repository = context.read<SolicitudRepository>();
    await repository.guardarRepuestos(categoryId, result);
    return result;
  }

  Future<void> _cargarRepuestos(String categoryId) async {
    setState(() {
      _isLoadingParts = true;
      _partError = null;
    });

    try {
      final parts = await _obtenerRepuestos(categoryId);
      if (!mounted) return;
      setState(() {
        _parts = parts;
        _isLoadingParts = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingParts = false;
          if (_parts.isEmpty) {
            _partError = 'Sin datos offline para esta categoría';
          }
        });
      }
    }
  }

  Future<void> _cargarRepuestosAdicional(
    AdditionalRequestPart additionalPart,
  ) async {
    final categoryId = additionalPart.categoriaId;
    if (categoryId == null || _partsByCategoryId.containsKey(categoryId)) {
      return;
    }

    setState(() {
      _loadingAdditionalParts.add(additionalPart.id);
      _additionalPartErrors.remove(additionalPart.id);
    });

    try {
      await _obtenerRepuestos(categoryId);
      if (!mounted) return;
      setState(() => _loadingAdditionalParts.remove(additionalPart.id));
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingAdditionalParts.remove(additionalPart.id);
          _additionalPartErrors[additionalPart.id] =
              'No se pudieron cargar los repuestos.';
        });
      }
    }
  }

  Future<void> _cargarDirecciones() async {
    if (_direcciones.isEmpty) {
      setState(() => _isLoadingDirecciones = true);
    }
    try {
      final direcciones = await _direccionService.getDirecciones();
      _procesarDirecciones(direcciones);
      if (mounted) setState(() => _isLoadingDirecciones = false);
    } catch (e) {
      AppLogger.warning(
        'Error red al cargar direcciones, intentando local...',
        name: 'CreateRequest.Direcciones',
      );

      // INTENTO CARGA LOCAL
      try {
        if (!mounted) return;
        final repository = context.read<SolicitudRepository>();
        final localDirecciones = await repository.obtenerDireccionesLocal();
        if (localDirecciones.isNotEmpty) {
          _procesarDirecciones(localDirecciones);
          if (mounted) setState(() => _isLoadingDirecciones = false);
          return;
        }
      } catch (localError) {
        AppLogger.error('Error carga local direcciones: $localError');
      }
      if (mounted) setState(() => _isLoadingDirecciones = false);
    }
  }

  void _procesarDirecciones(List<Map<String, dynamic>> direcciones) {
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

      if (direcciones.isNotEmpty) {
        final principal = direcciones.firstWhere(
          (d) => d['es_principal'] == true,
          orElse: () => direcciones.first,
        );

        if (provider.selectedDireccionId == null) {
          provider.updateDireccion(principal['id'] as String?);
        }

        final currentId = provider.selectedDireccionId ?? principal['id'];
        final currentDir = direcciones.firstWhere(
          (d) => d['id'] == currentId,
          orElse: () => principal,
        );
        _locationController.text = _formatDireccion(currentDir);

        // Ubicación: la coordenada GPS capturada pertenece a otra dirección;
        // se descarta al cambiar de selección.
        _gpsLat = null;
        _gpsLng = null;
        provider.setUbicacionResuelta(_tieneCoordenadas(currentDir));
      }
    });
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

  // ========== UBICACIÓN / GPS (obligatoria) ==========

  Map<String, dynamic>? _direccionSeleccionada(CreateRequestProvider provider) {
    for (final d in _direcciones) {
      if (d['id']?.toString() == provider.selectedDireccionId) return d;
    }
    return null;
  }

  bool _tieneCoordenadas(Map<String, dynamic>? direccion) {
    return direccionTieneCoordenadas(direccion);
  }

  /// Flujo de captura de GPS compartido (helper `flujo_ubicacion.dart`):
  /// progreso → Reintentar / Abrir Ajustes / Usar dirección manual.
  /// Toda la lógica de permisos vive en `UbicacionService`.
  Future<UbicacionResultado> _flujoUbicacionGps({
    bool mostrarSnackbarSiNoDisponible = false,
  }) => flujoUbicacionGps(
    context,
    _ubicacionService,
    mostrarSnackbarSiNoDisponible: mostrarSnackbarSiNoDisponible,
  );

  // ========== IMAGEN ==========

  void _showToast(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceContainerHigh,
          duration: const Duration(seconds: 2),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            side: BorderSide(color: AppColors.success.withValues(alpha: 0.4)),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.spacingSm),
              Expanded(
                child: Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.textStyleCaption.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ========== AGREGAR NUEVA DIRECCIÓN ==========

  void _agregarDireccion() async {
    final nueva = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.radiusXl),
        ),
      ),
      // El sheet reutiliza el flujo de GPS/diálogos del formulario principal
      // (resolverUbicacion → _flujoUbicacionGps → UbicacionService) y el
      // selector visual de mapa (RyLocationMapPicker).
      builder: (sheetContext) => NuevaDireccionSheet(
        direccionService: _direccionService,
        resolverUbicacion: () =>
            _flujoUbicacionGps(mostrarSnackbarSiNoDisponible: true),
      ),
    );

    if (nueva == null || !mounted) return;

    // Recargar lista y seleccionar la nueva dirección
    await _cargarDirecciones();
    if (!mounted) return;
    context.read<CreateRequestProvider>().updateDireccion(
      nueva['id'] as String?,
    );
    setState(() {
      _locationController.text = _formatDireccion(nueva);
    });
    _showToast('Dirección agregada correctamente');
  }

  // ========== AGREGAR VEHÍCULO ==========

  Future<void> _agregarVehiculo() async {
    final previousIds = _vehiculos
        .map((vehiculo) => vehiculo['id']?.toString())
        .whereType<String>()
        .toSet();

    await context.push('/profile/vehicles');
    if (!mounted) return;

    await _cargarVehiculos();
    if (!mounted) return;

    final provider = context.read<CreateRequestProvider>();
    final nuevoVehiculo = _vehiculos.cast<Map<String, dynamic>?>().firstWhere(
      (vehiculo) =>
          vehiculo != null && !previousIds.contains(vehiculo['id']?.toString()),
      orElse: () => _vehiculos.length == 1 ? _vehiculos.first : null,
    );
    final nuevoVehiculoId = nuevoVehiculo?['id']?.toString();
    if (nuevoVehiculoId != null) {
      provider.updateVehiculo(nuevoVehiculoId);
    }
  }

  Future<void> _mostrarVehiculoRequerido() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Registra un vehículo'),
        content: const Text(
          'Necesitas registrar al menos un vehículo para crear una solicitud compatible.',
        ),
        actions: [
          RyButton(
            label: 'Ahora no',
            variant: RyButtonVariant.text,
            onPressed: () => Navigator.pop(dialogContext),
          ),
          RyButton(
            label: 'Agregar vehículo',
            icon: Icons.add,
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _agregarVehiculo();
            },
          ),
        ],
      ),
    );
  }

  // ========== CAMBIAR DIRECCIÓN (diálogo) ==========

  void _changeLocation() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final media = MediaQuery.of(dialogContext);
        final emptyStateHeight = (media.size.height * 0.3)
            .clamp(120.0, 240.0)
            .toDouble();

        return Dialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          insetPadding: const EdgeInsets.all(AppSpacing.spacingMd),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: media.size.height * 0.86,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spacingMd,
                vertical: AppSpacing.spacingSm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.spacingSm,
                    ),
                    child: Text(
                      'Seleccionar dirección de entrega',
                      style: AppTextStyles.textStyleTitle.copyWith(
                        fontSize: 18,
                        color: AppColors.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Divider(color: AppColors.outlineVariant),
                  Flexible(
                    fit: FlexFit.loose,
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.spacingXs,
                          vertical: AppSpacing.spacingSm,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: _isLoadingDirecciones
                              ? const SizedBox(
                                  height: 160,
                                  child: Center(
                                    child: RyStateContainer(
                                      title: 'Cargando direcciones...',
                                      type: RyStateType.loading,
                                    ),
                                  ),
                                )
                              : _direcciones.isEmpty
                              ? SizedBox(
                                  height: emptyStateHeight,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.primaryContainer
                                                .withValues(alpha: 0.12),
                                          ),
                                          child: const Icon(
                                            Icons.location_on_outlined,
                                            size: 32,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: AppSpacing.spacingMd,
                                        ),
                                        Text(
                                          'Aún no tienes direcciones',
                                          style: AppTextStyles.textStyleTitle
                                              .copyWith(
                                                color: AppColors.onSurface,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(
                                          height: AppSpacing.spacingXs,
                                        ),
                                        Text(
                                          'Agrega una dirección para recibir tus repuestos.',
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.textStyleBody
                                              .copyWith(
                                                color:
                                                    AppColors.onSurfaceVariant,
                                              ),
                                        ),
                                        const SizedBox(
                                          height: AppSpacing.spacingLg,
                                        ),
                                        SizedBox(
                                          width: double.infinity,
                                          child: RyButton(
                                            label: 'Agregar dirección',
                                            icon: Icons.add,
                                            variant: RyButtonVariant.primary,
                                            size: RyButtonSize.large,
                                            isFullWidth: true,
                                            onPressed: () {
                                              Navigator.pop(dialogContext);
                                              _agregarDireccion();
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ..._direcciones.map((direccion) {
                                      final isSelected =
                                          direccion['id'] ==
                                          dialogContext
                                              .read<CreateRequestProvider>()
                                              .selectedDireccionId;
                                      return ListTile(
                                        title: Text(
                                          _formatDireccion(direccion),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.textStyleBody,
                                        ),
                                        trailing: isSelected
                                            ? const Icon(
                                                Icons.check_circle,
                                                color:
                                                    AppColors.primaryContainer,
                                              )
                                            : null,
                                        onTap: () async {
                                          final provider = dialogContext
                                              .read<CreateRequestProvider>();
                                          provider.updateDireccion(
                                            direccion['id'] as String?,
                                          );
                                          _gpsLat = null;
                                          _gpsLng = null;
                                          if (_tieneCoordenadas(direccion)) {
                                            provider.setUbicacionResuelta(true);
                                          } else {
                                            final ubicacion =
                                                await _flujoUbicacionGps();
                                            if (!mounted) return;
                                            if (ubicacion.disponible) {
                                              _gpsLat = ubicacion.latitude;
                                              _gpsLng = ubicacion.longitude;
                                            }
                                            provider.setUbicacionResuelta(true);
                                          }
                                          if (!mounted ||
                                              !dialogContext.mounted) {
                                            return;
                                          }
                                          setState(() {
                                            _locationController.text =
                                                _formatDireccion(direccion);
                                          });
                                          Navigator.pop(dialogContext);
                                          _showToast('Dirección actualizada');
                                        },
                                      );
                                    }),
                                    const Divider(
                                      color: AppColors.outlineVariant,
                                    ),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.add_circle,
                                        color: AppColors.primaryContainer,
                                      ),
                                      title: Text(
                                        'Agregar nueva dirección',
                                        style: AppTextStyles.textStyleBody
                                            .copyWith(
                                              color: AppColors.primaryContainer,
                                            ),
                                      ),
                                      onTap: () {
                                        Navigator.pop(dialogContext);
                                        _agregarDireccion();
                                      },
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  const Divider(color: AppColors.outlineVariant),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(88, 48),
                        foregroundColor: AppColors.onSurfaceVariant,
                      ),
                      child: Text(
                        'Cancelar',
                        style: AppTextStyles.textStyleButton.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ========== ENVÍO DEL FORMULARIO ==========

  Future<String?> _persistOfflineImage(File? image) async {
    if (image == null) return null;

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final imagesDirectory = Directory(
      p.join(documentsDirectory.path, 'repuestosya_pending_images'),
    );
    await imagesDirectory.create(recursive: true);

    final extension = p.extension(image.path);
    final persistentPath = p.join(
      imagesDirectory.path,
      'solicitud_${const Uuid().v4()}$extension',
    );
    final persistedImage = await image.copy(persistentPath);
    return persistedImage.path;
  }

  /// Encola la solicitud en el Outbox (registro atómico Drift + Outbox) con
  /// la imagen persistida a disco, si la hay. Compartido por el modo sin
  /// conexión y por el fallo de subida online de la imagen: en ambos casos la
  /// solicitud NUNCA se bloquea por la imagen — queda pendiente y el
  /// SyncEngine la sube al reconectar.
  Future<void> _encolarSolicitudOffline({
    required String userId,
    required String? persistentImagePath,
    required String descripcionProblema,
  }) async {
    final provider = context.read<CreateRequestProvider>();
    final outboxService = context.read<OutboxService>();

    final payload = {
      'cliente_id': userId,
      'vehiculo_id': provider.selectedVehiculoId!,
      'pieza_nombre': provider.piezaNombre,
      'descripcion': provider.descripcion,
      'direccion_entrega_id': provider.selectedDireccionId!,
      'es_urgente': provider.selectedPrioridad == 'urgente',
      'categoria_id': provider.selectedCategoryId!,
      'repuesto_id': provider.selectedPartId!,
      'repuesto_nombre_snapshot': provider.partNameSnapshot!,
      'descripcion_problema': descripcionProblema,
      'local_image_path': persistentImagePath,
      // Coordenadas GPS capturadas offline (opcionales): si no vienen,
      // el backend geocodifica la dirección al sincronizar.
      if (_gpsLat != null && _gpsLng != null) 'latitude': _gpsLat,
      if (_gpsLat != null && _gpsLng != null) 'longitude': _gpsLng,
      if (_gpsLat != null && _gpsLng != null) 'coordenadas_fuente': 'gps',
    };

    // Outbox y solicitud local se guardan atómicamente.
    try {
      await outboxService.enqueueSolicitud(
        payload: payload,
        localRequest: (clientId) => SolicitudLocal(
          id: clientId,
          clientId: clientId,
          vehiculoId: provider.selectedVehiculoId!,
          piezaNombre: provider.piezaNombre,
          categoriaId: provider.selectedCategoryId,
          repuestoId: provider.selectedPartId,
          estado: 'pendiente',
          descripcion: provider.descripcion,
          fotoUrl: persistentImagePath == null
              ? null
              : 'file://$persistentImagePath',
          // Columnas dedicadas de coordenadas (además del payload JSON).
          latitude: _gpsLat,
          longitude: _gpsLng,
          locationSource: _gpsLat != null ? 'gps' : null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          synced: false,
        ),
      );
    } catch (_) {
      if (persistentImagePath != null) {
        try {
          await File(persistentImagePath).delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Diálogo de confirmación de guardado local, compartido por el modo sin
  /// conexión y por el fallo de subida online de la imagen.
  void _mostrarDialogoGuardadoLocal() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Guardado localmente'),
        content: const Text(
          'Tu solicitud se ha guardado en el dispositivo. Se enviará automáticamente al recuperar la conexión.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
      if (!_isLoadingVehiculos && _vehiculos.isEmpty) {
        await _mostrarVehiculoRequerido();
      } else {
        mostrarSnackbarAdvertencia(
          context,
          mensaje:
              'Debes seleccionar un vehículo para asegurar la compatibilidad.',
        );
      }
      hasManualErrors = true;
    }
    if (!mounted) return;
    if (provider.selectedDireccionId == null) {
      mostrarSnackbarAdvertencia(
        context,
        mensaje: 'Indica dónde deseas recibir el repuesto.',
      );
      hasManualErrors = true;
    }

    for (final additionalPart in provider.additionalParts) {
      if (additionalPart.categoriaId == null) {
        _additionalCategoryErrors[additionalPart.id] =
            'Selecciona una categoría.';
        hasManualErrors = true;
      }
      if (additionalPart.repuestoId == null) {
        _additionalPartErrors[additionalPart.id] = 'Selecciona un repuesto.';
        hasManualErrors = true;
      }
    }
    if (provider.additionalParts.isNotEmpty) {
      setState(() {});
    }

    if (hasManualErrors) return;

    // 4. UBICACIÓN OBLIGATORIA: la dirección seleccionada debe tener
    //    coordenadas verificables. Si aún no las tiene (registro legacy o
    //    creada sin GPS), se capturan del dispositivo con el flujo de
    //    reintento/Ajustes. Si el GPS está inoperable, se degrada a la
    //    dirección manual y el backend la geocodifica server-side antes de
    //    aceptar el registro — nunca se guarda una solicitud sin coordenadas.
    final direccionSeleccionada = _direccionSeleccionada(provider);
    final direccionConCoordenadas = _tieneCoordenadas(direccionSeleccionada);

    if (!direccionConCoordenadas) {
      final ubicacion = await _flujoUbicacionGps();
      if (!mounted) return;
      // El usuario declinó el rationale previo: la acción se cancela sin
      // error (no se dispara el permiso nativo ni se envía).
      if (ubicacion.estado == UbicacionEstado.cancelado) return;
      if (ubicacion.disponible) {
        _gpsLat = ubicacion.latitude;
        _gpsLng = ubicacion.longitude;
      }
      // GPS ok o manual → la ubicación queda resuelta (el backend
      // geocodifica la dirección si hace falta).
      provider.setUbicacionResuelta(true);
    }

    final descripcionProblema = _buildDescripcionProblema(provider);
    setState(() => _isSubmitting = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado');

      final connectivityResults = await Connectivity().checkConnectivity();
      final isOffline = connectivityResults.any(
        (result) => result == ConnectivityResult.none,
      );

      if (isOffline) {
        // MODO SIN CONEXIÓN
        if (!mounted) return;
        final persistentImagePath = await _persistOfflineImage(
          provider.selectedImage,
        );
        await _encolarSolicitudOffline(
          userId: user.id,
          persistentImagePath: persistentImagePath,
          descripcionProblema: descripcionProblema,
        );

        if (!mounted) return;
        _gpsLat = null;
        _gpsLng = null;
        provider.clear();
        setState(() => _isSubmitting = false);

        if (mounted) {
          _mostrarDialogoGuardadoLocal();
        }
        return;
      }

      // MODO ONLINE (existente)
      // Subir imagen
      String? fotoUrl;
      if (provider.selectedImage != null) {
        fotoUrl = await UploadService().uploadRequestImage(
          provider.selectedImage!,
          user.id,
        );
        if (fotoUrl == null || fotoUrl.isEmpty) {
          // La subida online falló: NO se aborta la solicitud (hallazgo [10]).
          // Se persiste la imagen y se difiere a Outbox — mismo camino que el
          // modo sin conexión — y el SyncEngine reintenta al reconectar.
          if (!mounted) return;
          final persistentImagePath = await _persistOfflineImage(
            provider.selectedImage,
          );
          await _encolarSolicitudOffline(
            userId: user.id,
            persistentImagePath: persistentImagePath,
            descripcionProblema: descripcionProblema,
          );

          if (!mounted) return;
          _gpsLat = null;
          _gpsLng = null;
          provider.clear();
          setState(() => _isSubmitting = false);

          if (mounted) {
            _mostrarDialogoGuardadoLocal();
          }
          return;
        }
      }

      // Crear solicitud (con coordenadas GPS si se capturaron; si no, el
      // backend geocodifica la dirección server-side — degradación controlada)
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
        descripcionProblema: descripcionProblema,
        latitude: _gpsLat,
        longitude: _gpsLng,
        coordenadasFuente: 'gps',
      );

      if (!mounted) return;

      // Éxito: limpiar provider y navegar
      _gpsLat = null;
      _gpsLng = null;
      provider.clear();
      setState(() => _isSubmitting = false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer.withValues(alpha: 0.14),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 36,
                  color: AppColors.primaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.spacingMd),
              Text(
                '¡Solicitud enviada con éxito!',
                style: AppTextStyles.textStyleTitle.copyWith(
                  color: AppColors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            'Los almacenes ya están revisando lo que necesitas. '
            'Te notificaremos en cuanto recibas las primeras cotizaciones.',
            style: AppTextStyles.textStyleBody.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            RyButton(
              label: widget.isOnboardingFlow
                  ? 'Continuar'
                  : 'Ver mis solicitudes',
              trailingIcon: Icons.arrow_forward,
              variant: RyButtonVariant.primary,
              size: RyButtonSize.medium,
              onPressed: () {
                Navigator.pop(dialogContext);
                if (widget.isOnboardingFlow) {
                  context.pop();
                } else {
                  context.goNamed(RouteNames.solicitudes);
                }
              },
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
        mostrarSnackbarError(
          context,
          mensaje: ApiErrorHandler.userMessage(
            e,
            context: ApiErrorContext.session,
          ),
        );
      }
    }
  }

  String _buildDescripcionProblema(CreateRequestProvider provider) {
    final partes = provider.additionalParts
        .map(
          (p) => (
            categoria: p.categoriaNombre ?? p.categoriaId,
            repuesto: p.repuestoNombreSnapshot ?? p.repuestoId,
            cantidad: p.cantidad,
            detalle: p.descripcionProblema,
          ),
        )
        .toList();
    return buildDescripcionProblema(provider.descripcion, partes);
  }

  // ========== COMPONENTES UI ==========

  Widget _buildOfflineBanner(bool isOffline) {
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: AppSpacing.spacingMd,
      ),
      color: AppColors.warning.withValues(alpha: 0.15),
      margin: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 20,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.spacingMd),
          Expanded(
            child: Text(
              'Modo sin conexión · Las solicitudes se guardarán localmente',
              style: AppTextStyles.textStyleCaption.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CreateRequestProvider>();
    final syncProvider = context.watch<SolicitudesProvider>();

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
            mostrarSnackbarInfo(
              context,
              mensaje:
                  'La categoría seleccionada ya no está disponible. Selecciona una nueva.',
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
            mostrarSnackbarInfo(
              context,
              mensaje:
                  'El repuesto seleccionado ya no está disponible. Selecciona uno nuevo.',
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
          tooltip: 'Regresar',
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
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOfflineBanner(syncProvider.isOffline),
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
              _buildVehicleDropdown(provider),
              const SizedBox(height: AppSpacing.spacingXl),
              _buildImageSection(provider),
              const SizedBox(height: AppSpacing.spacingLg),
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
              RyTextField(
                label: 'Detalles adicionales',
                initialValue: provider.descripcion,
                hint:
                    'Lado izquierdo/derecho, amperaje, número de pines o tamaño.',
                // El máximo permite todos los wraps con fuentes fallback y no
                // altera la altura si el texto real ocupa menos líneas.
                hintMaxLines: 8,
                helperText:
                    'Ej: Amortiguador delantero derecho, marca original o equivalente de alta calidad',
                helperMaxLines: 4,
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
              _buildAdditionalPartsSection(provider),
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
      bottomNavigationBar: RyBottomActionBar(
        primaryLabel: 'BUSCAR REPUESTO',
        primaryIcon: Icons.search,
        primaryLoading: _isSubmitting,
        primaryDisabled: !provider.ubicacionResuelta,
        onPrimaryPressed: provider.ubicacionResuelta ? _handleSubmit : null,
      ),
    );
  }

  void _startAdditionalPart(CreateRequestProvider provider) {
    final additionalPart = provider.addAdditionalPart();
    if (!mounted) return;
    setState(() {
      _expandedAdditionalParts
        ..clear()
        ..add(additionalPart.id);
    });
  }

  void _addAdditionalPartToList(AdditionalRequestPart additionalPart) {
    final hasCategory = additionalPart.categoriaId != null;
    final hasPart = additionalPart.repuestoId != null;
    if (!hasCategory || !hasPart) {
      setState(() {
        if (!hasCategory) {
          _additionalCategoryErrors[additionalPart.id] =
              'Selecciona una categoría.';
        }
        if (!hasPart) {
          _additionalPartErrors[additionalPart.id] = 'Selecciona un repuesto.';
        }
      });
      return;
    }

    setState(() => _expandedAdditionalParts.remove(additionalPart.id));
  }

  Widget _buildAdditionalPartsSection(CreateRequestProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.add_box_outlined,
              size: 20,
              color: AppColors.primaryContainer,
            ),
            const SizedBox(width: AppSpacing.spacingSm),
            Expanded(
              child: Text(
                'Repuestos adicionales',
                style: AppTextStyles.textStyleTitle.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spacingXxs),
        Text(
          'Agrega otros repuestos o accesorios que necesitas para el mismo vehículo.',
          style: AppTextStyles.textStyleCaption.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        if (provider.additionalParts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.spacingMd),
          ...provider.additionalParts.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
              child: _buildAdditionalPartCard(provider, entry.value, entry.key),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.spacingXs),
        RyButton(
          label: 'Agregar otro repuesto',
          icon: Icons.add,
          variant: RyButtonVariant.outline,
          isFullWidth: true,
          onPressed: () => _startAdditionalPart(provider),
        ),
      ],
    );
  }

  Widget _buildAdditionalPartCard(
    CreateRequestProvider provider,
    AdditionalRequestPart additionalPart,
    int index,
  ) {
    final selectedCategory = _categories
        .where((category) => category.id == additionalPart.categoriaId)
        .firstOrNull;
    final parts = additionalPart.categoriaId == null
        ? const <CatalogPart>[]
        : _partsByCategoryId[additionalPart.categoriaId!] ??
              const <CatalogPart>[];
    final selectedPart = parts
        .where((part) => part.id == additionalPart.repuestoId)
        .firstOrNull;
    final isLoading = _loadingAdditionalParts.contains(additionalPart.id);
    final isExpanded = _expandedAdditionalParts.contains(additionalPart.id);

    if (!isExpanded) {
      return _buildCollapsedAdditionalPartCard(provider, additionalPart, index);
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nuevo repuesto',
                  style: AppTextStyles.textStyleTitle.copyWith(
                    color: AppColors.onSurface,
                    fontSize: 16,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Eliminar repuesto adicional ${index + 1}',
                child: IconButton(
                  tooltip: 'Eliminar repuesto adicional',
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.error,
                  onPressed: () {
                    _additionalCategoryErrors.remove(additionalPart.id);
                    _additionalPartErrors.remove(additionalPart.id);
                    provider.removeAdditionalPart(additionalPart.id);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingXs),
          RyDropdownField<PartCategory>(
            label: 'Categoría',
            hint: 'Selecciona una categoría',
            isRequired: true,
            items: _categories,
            value: selectedCategory,
            isLoading: _isLoadingCategories,
            errorText: _additionalCategoryErrors[additionalPart.id],
            itemLabelBuilder: (category) => category.nombre,
            onChanged: (category) {
              provider.updateAdditionalCategory(
                additionalPart.id,
                category?.id,
                category?.nombre,
              );
              setState(() {
                _additionalCategoryErrors.remove(additionalPart.id);
                _additionalPartErrors.remove(additionalPart.id);
              });
              if (category != null) {
                _cargarRepuestosAdicional(additionalPart);
              }
            },
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          RyDropdownField<CatalogPart>(
            label: 'Repuesto',
            hint: additionalPart.categoriaId == null
                ? 'Selecciona primero una categoría'
                : 'Selecciona el repuesto',
            isRequired: true,
            items: parts,
            value: selectedPart,
            enabled: additionalPart.categoriaId != null,
            isLoading: isLoading,
            errorText: _additionalPartErrors[additionalPart.id],
            itemLabelBuilder: (part) => part.nombre,
            onChanged: (part) {
              provider.updateAdditionalPart(
                additionalPart.id,
                part?.id,
                part?.nombre,
              );
              setState(() => _additionalPartErrors.remove(additionalPart.id));
            },
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          RyTextField(
            label: 'Detalles adicionales (opcional)',
            initialValue: additionalPart.descripcionProblema,
            maxLines: 3,
            onChanged: (value) =>
                provider.updateAdditionalDescription(additionalPart.id, value),
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          RyTextField(
            label: 'Cantidad',
            initialValue: additionalPart.cantidad.toString(),
            type: RyTextFieldType.number,
            keyboardType: TextInputType.number,
            onChanged: (value) => provider.updateAdditionalQuantity(
              additionalPart.id,
              int.tryParse(value) ?? 1,
            ),
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          RyButton(
            label: 'Agregar a la lista',
            icon: Icons.check,
            variant: RyButtonVariant.outline,
            isFullWidth: true,
            onPressed: () => _addAdditionalPartToList(additionalPart),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedAdditionalPartCard(
    CreateRequestProvider provider,
    AdditionalRequestPart additionalPart,
    int index,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spacingSm,
        vertical: AppSpacing.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            additionalPart.repuestoId == null
                ? Icons.pending_outlined
                : Icons.check_circle_outline,
            color: additionalPart.repuestoId == null
                ? AppColors.onSurfaceVariant
                : AppColors.success,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  additionalPart.repuestoNombreSnapshot ??
                      'Pendiente de elegir',
                  style: AppTextStyles.textStyleBody,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Cantidad: ${additionalPart.cantidad}',
                  style: AppTextStyles.textStyleCaption.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Editar repuesto adicional ${index + 1}',
            child: IconButton(
              tooltip: 'Editar repuesto adicional',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                setState(() {
                  _expandedAdditionalParts
                    ..clear()
                    ..add(additionalPart.id);
                });
              },
            ),
          ),
          Semantics(
            button: true,
            label: 'Eliminar repuesto adicional ${index + 1}',
            child: IconButton(
              tooltip: 'Eliminar repuesto adicional',
              icon: const Icon(Icons.delete_outline),
              color: AppColors.error,
              onPressed: () {
                _additionalCategoryErrors.remove(additionalPart.id);
                _additionalPartErrors.remove(additionalPart.id);
                provider.removeAdditionalPart(additionalPart.id);
              },
            ),
          ),
        ],
      ),
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
              initialValue:
                  (_isLoadingVehiculos ||
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
              // isExpanded: el dropdown ocupa el ancho del campo y el item
              // seleccionado se ajusta (sin él, el botón mide según el item
              // más ancho y desbordaba el campo en móvil angosto).
              isExpanded: true,
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
                              // En móvil angosto el item largo desbordaba el
                              // campo (RenderFlex overflow de 128px): se
                              // trunca con ellipsis en una línea.
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
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
        if (!_isLoadingVehiculos && _vehiculos.isEmpty) ...[
          const SizedBox(height: AppSpacing.spacingSm),
          RyButton(
            label: 'Agregar vehículo',
            icon: Icons.add,
            variant: RyButtonVariant.outline,
            isFullWidth: true,
            onPressed: _agregarVehiculo,
          ),
        ],
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
                const SizedBox(height: 2),
                _buildUbicacionStatus(provider),
                if (_fieldErrors.containsKey('direccion_entrega_id'))
                  Text(
                    _fieldErrors['direccion_entrega_id']!,
                    style: AppTextStyles.textStyleSmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                if (_fieldErrors.containsKey('ubicacion'))
                  Text(
                    _fieldErrors['ubicacion']!,
                    style: AppTextStyles.textStyleSmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.spacingXs),
          IconButton(
            tooltip: 'Cambiar ubicación',
            onPressed: _changeLocation,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(48),
              backgroundColor: AppColors.primaryContainer.withValues(
                alpha: 0.12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              ),
            ),
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildUbicacionStatus(CreateRequestProvider provider) {
    final direccion = _direccionSeleccionada(provider);
    final tieneCoordenadas = _tieneCoordenadas(direccion);

    if (tieneCoordenadas) {
      final fuente = direccion?['coordenadas_fuente']?.toString();
      final texto = fuente == 'manual'
          ? 'Ubicación verificada por dirección'
          : 'Ubicación verificada por GPS';
      return Row(
        children: [
          const Icon(
            Icons.verified,
            size: 14,
            color: SemanticColors.colorSuccess,
          ),
          const SizedBox(width: 4),
          // Flexible: el mensaje se recorta antes de desbordar el Row en
          // anchos reducidos (hallazgo de widget tests, Fase 2).
          Flexible(
            child: Text(
              texto,
              style: AppTextStyles.textStyleSmall.copyWith(
                color: SemanticColors.colorSuccess,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(
          Icons.location_searching,
          size: 14,
          color: AppColors.warning,
        ),
        const SizedBox(width: AppSpacing.spacingXxs),
        Flexible(
          child: Text(
            'Pendiente de verificar',
            style: AppTextStyles.textStyleSmall.copyWith(
              color: AppColors.warning,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
}
