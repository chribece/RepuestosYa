import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:getwidget/getwidget.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../services/solicitud_service.dart';
import '../services/almacen_service.dart';
import '../services/almacen_repository.dart';
import '../services/outbox.dart';
import '../services/upload_service.dart';
import '../widgets/ry_bottom_action_bar.dart';
import '../widgets/ry_text_field.dart';
import '../widgets/ry_image_picker.dart';
import '../widgets/ry_full_image_viewer.dart';
import '../widgets/ry_part_card.dart';
import '../widgets/ry_section_card.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';

class CreateQuotationPage extends StatefulWidget {
  final Map<String, dynamic> solicitud;

  const CreateQuotationPage({super.key, required this.solicitud});

  @override
  State<CreateQuotationPage> createState() => _CreateQuotationPageState();
}

class _CreateQuotationPageState extends State<CreateQuotationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _selectedCondition = 'Nuevo (En caja original)';
  String _selectedDeliveryTime = '24-48 horas';

  File? _selectedImage;
  bool _isSubmitting = false;

  // Almacén del encargado: se carga al iniciar para mostrar la distancia real
  // almacén → punto de entrega y reutilizarlo al enviar la cotización.
  Map<String, dynamic>? _almacen;

  final SolicitudService _solicitudService = SolicitudService();
  late final AlmacenService _almacenService;

  @override
  void initState() {
    super.initState();
    _almacenService = AlmacenService(context.read<AlmacenRepository>());
    _cargarAlmacen();
  }

  Future<void> _cargarAlmacen() async {
    try {
      final almacen = await _almacenService.obtenerMiAlmacen();
      if (mounted && almacen != null) {
        setState(() => _almacen = almacen);
      }
    } catch (_) {
      // La tarjeta de logística mostrará "no disponible" y el envío volverá
      // a intentar obtener el almacén.
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String && value.trim().isNotEmpty) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Copia la imagen seleccionada a un directorio persistente para su subida
  /// diferida (Outbox), mismo patrón que `CreateRequestPage._persistOfflineImage`.
  /// Devuelve la ruta persistida, o `null` si no hay imagen.
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
      'cotizacion_${const Uuid().v4()}$extension',
    );
    final persistedImage = await image.copy(persistentPath);
    return persistedImage.path;
  }

  /// Detecta si el dispositivo está sin conexión de red.
  Future<bool> _isOffline() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    return connectivityResults.any(
      (result) => result == ConnectivityResult.none,
    );
  }

  /// Abre la imagen en pantalla completa con zoom. Soporta URL de red,
  /// rutas locales absolutas (legacy) y prefijo `file://`.
  void _openFullImage(String imagePath) {
    if (!mounted) return;
    final path = imagePath.trim();
    if (path.startsWith('file://')) {
      RyFullImageViewer.showFile(context, File(path.substring(7)));
    } else if (path.startsWith('/')) {
      RyFullImageViewer.showFile(context, File(path));
    } else {
      RyFullImageViewer.showNetwork(context, path);
    }
  }

  Future<void> _enviarCotizacion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    // Declaradas fuera del try para poder usarlas en el catch (error de red
    // a mitad de envío → diferir a Outbox).
    String solicitudId = '';
    String almacenId = '';
    String? uploadedImageUrl;

    try {
      final Map<String, dynamic> objetoInterno =
          widget.solicitud['solicitud'] is Map<String, dynamic>
          ? widget.solicitud['solicitud'] as Map<String, dynamic>
          : {};

      solicitudId =
          objetoInterno['id']?.toString() ??
          widget.solicitud['solicitud_id']?.toString() ??
          widget.solicitud['id']?.toString() ??
          '';

      if (solicitudId.isEmpty || solicitudId == 'null') {
        throw Exception(
          'El ID de la solicitud es inválido o no se encontró en el objeto.',
        );
      }

      // Obtener el almacén ANTES de subir la imagen, porque el path de
      // Storage se segmenta por dominio funcional:
      //   evidencias/cotizaciones/{almacenId}/...
      final almacen = _almacen ?? await _almacenService.obtenerMiAlmacen();
      if (almacen == null) {
        throw Exception(
          'No tienes un almacén asociado. Por favor, completa tu perfil comercial.',
        );
      }

      almacenId = almacen['id']?.toString() ?? '';
      if (almacenId.isEmpty || almacenId == 'null') {
        throw Exception('El ID del almacén es inválido o está vacío.');
      }

      final double precio = double.tryParse(_priceController.text) ?? 0.0;
      final String notas = _notesController.text.trim();

      // Modo offline: no se intenta la subida directa; todo pasa por Outbox.
      final bool offline = await _isOffline();

      bool enqueueForLater = offline;

      if (_selectedImage != null && !offline) {
        // Subida directa a Supabase Storage (mismo servicio que solicitudes).
        uploadedImageUrl = await UploadService().uploadQuotationImage(
          _selectedImage!,
          almacenId,
        );
        if (uploadedImageUrl == null || uploadedImageUrl.isEmpty) {
          // Subida online fallida (red): se difiere a Outbox en vez de
          // descartar la foto (hallazgo [10]).
          enqueueForLater = true;
        }
      }

      if (enqueueForLater) {
        await _encolarCotizacionOffline(
          solicitudId: solicitudId,
          almacenId: almacenId,
          precio: precio,
          notas: notas,
          fotoUrlAlreadyUploaded: uploadedImageUrl,
        );
        return;
      }

      // Consumo del servicio con los nombres y valores en español ya homologados
      await _solicitudService.crearCotizacion(
        solicitudId: solicitudId,
        almacenId: almacenId,
        precio: precio,
        notas: notas,
        fotoUrl: uploadedImageUrl,
        tiempoEntrega: _selectedDeliveryTime,
        estadoRepuesto: _selectedCondition,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        context.pop(true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // Errores de negocio (422/403/400/404): no se encola, se informa.
      if (e.statusCode != null && e.statusCode != 0 && e.statusCode != 504) {
        setState(() => _isSubmitting = false);
        // 422: el body trae `errors: [{ field, message }]`; mostrar el mensaje
        // específico del campo en lugar del genérico ("Algunos datos no
        // cumplen...") para que el usuario sepa exactamente qué falla.
        final fieldErrors = ApiErrorHandler.mapValidationErrors(e);
        final mensaje = fieldErrors.isNotEmpty
            ? fieldErrors.values.first
            : ApiErrorHandler.userMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar la cotización: $mensaje'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
      // Error de red en el POST (la foto ya quedó subida): diferir a Outbox.
      await _encolarCotizacionOffline(
        solicitudId: solicitudId,
        almacenId: almacenId,
        precio: double.tryParse(_priceController.text) ?? 0.0,
        notas: _notesController.text.trim(),
        fotoUrlAlreadyUploaded: uploadedImageUrl,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al procesar la cotización: '
              '${ApiErrorHandler.userMessage(e)}',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Encola la cotización en el Outbox (registro atómico Drift + Outbox) y
  /// avisa que se enviará al recuperar la conexión.
  Future<void> _encolarCotizacionOffline({
    required String solicitudId,
    required String almacenId,
    required double precio,
    required String notas,
    String? fotoUrlAlreadyUploaded,
  }) async {
    // Capturado antes de cualquier await para no usar el context a través de
    // un async gap.
    final outboxService = context.read<OutboxService>();

    // Si la subida online ya ocurrió pero el POST falló por red, se guarda la
    // URL remota en el payload y el SyncEngine no re-subirá la foto (evita
    // duplicados en Storage). En caso contrario se persiste el archivo local.
    String? persistentImagePath;
    String? fotoUrl = fotoUrlAlreadyUploaded;

    if (fotoUrl == null && _selectedImage != null) {
      persistentImagePath = await _persistOfflineImage(_selectedImage);
      if (persistentImagePath != null) {
        fotoUrl = 'file://$persistentImagePath';
      }
    }

    final payload = {
      'solicitud_id': solicitudId,
      'almacen_id': almacenId,
      'precio': precio,
      'condicion_repuesto': _selectedCondition,
      'notas': notas,
      'tiempo_entrega_estimado': _selectedDeliveryTime,
      'foto_evidencia_url': fotoUrl,
      'local_image_path': ?persistentImagePath,
    };

    try {
      await outboxService.enqueueCotizacion(
        payload: payload,
        localQuotation: (clientId) => CotizacionPendiente(
          id: clientId,
          clientId: clientId,
          solicitudId: solicitudId,
          almacenId: almacenId,
          precio: precio,
          condicion: _selectedCondition,
          fotoUrl: fotoUrl,
          notas: notas,
          tiempoEntrega: _selectedDeliveryTime,
          estado: 'pendiente',
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

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Guardado localmente'),
        content: const Text(
          'Tu cotización se ha guardado en el dispositivo. Se enviará automáticamente al recuperar la conexión.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.pop(true);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> objetoInterno =
        widget.solicitud['solicitud'] is Map<String, dynamic>
        ? widget.solicitud['solicitud'] as Map<String, dynamic>
        : {};

    final String piezaNombre =
        objetoInterno['pieza_nombre'] ??
        widget.solicitud['pieza_nombre'] ??
        'Repuesto';
    final String descripcion =
        objetoInterno['descripcion'] ??
        widget.solicitud['descripcion'] ??
        'Sin especificaciones técnicas';

    final String idSolicitud =
        widget.solicitud['solicitud_id']?.toString() ??
        widget.solicitud['id']?.toString() ??
        '0000';
    final String idCorto = idSolicitud.isNotEmpty
        ? idSolicitud.substring(
            0,
            idSolicitud.length > 4 ? 4 : idSolicitud.length,
          )
        : '0000';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.03),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.03),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(idCorto, piezaNombre),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.spacingMd,
                        AppSpacing.spacingLg,
                        AppSpacing.spacingMd,
                        110, // ajuste fino intencional: espacio para la barra de acción fija
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCard(piezaNombre, descripcion),
                          _buildAdditionalPartsSection(objetoInterno),
                          const SizedBox(height: AppSpacing.spacingLg),

                          // SECCIÓN DE ESPECIFICACIONES TÉCNICAS Y VIN
                          _buildVehicleTechnicalSheet(objetoInterno),

                          const SizedBox(height: AppSpacing.spacingXl),
                          _buildPriceField(),
                          const SizedBox(height: AppSpacing.spacingXl),
                          _buildConditionDropdown(),
                          const SizedBox(height: AppSpacing.spacingXl),
                          _buildDeliveryTimeDropdown(),
                          const SizedBox(height: AppSpacing.spacingXl),
                          _buildLogisticaDespachoSection(),
                          const SizedBox(height: AppSpacing.spacingXl),
                          _buildEvidenciaVisualSection(),
                          const SizedBox(height: AppSpacing.spacingXl),
                          _buildNotesField(),
                          const SizedBox(height: AppSpacing.spacingXl),
                          _buildImportantInfoBox(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildBottomActionButton(),
        ],
      ),
    );
  }

  Widget _buildHeader(String id, String pieza) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 28,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: AppSpacing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Nueva Cotización', style: AppTextStyles.textStyleTitle),
                Text(
                  'Solicitud #$id - $pieza',
                  style: AppTextStyles.textStyleCaption.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalPartsSection(Map<String, dynamic> solicitud) {
    final additionalPartsSummary = solicitud['descripcion_problema']
        ?.toString();
    if (RyAdditionalPartsList.parse(additionalPartsSummary).isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.spacingLg),
      child: RySectionCard(
        title: 'Repuestos adicionales solicitados',
        icon: Icons.build_outlined,
        children: [RyAdditionalPartsList(summary: additionalPartsSummary)],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String subtitle) {
    final Map<String, dynamic> objetoInterno =
        widget.solicitud['solicitud'] is Map<String, dynamic>
        ? widget.solicitud['solicitud'] as Map<String, dynamic>
        : {};

    final String? urlDeLaImagen =
        objetoInterno['foto_url'] ??
        objetoInterno['image_url'] ??
        widget.solicitud['foto_url'] ??
        widget.solicitud['image_url'];
    final bool hasImage =
        urlDeLaImagen != null && urlDeLaImagen.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Row(
        children: [
          // Foto de la solicitud: tap para ver en pantalla completa (igual o
          // mejor que la vista del cliente cuando recibe la cotización).
          Semantics(
            button: hasImage,
            label: hasImage
                ? 'Ver foto de la solicitud en pantalla completa'
                : 'Sin foto de la solicitud',
            child: GestureDetector(
              onTap: hasImage ? () => _openFullImage(urlDeLaImagen) : null,
              child: Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                      border: Border.all(
                        color: AppColors.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: hasImage
                        ? ClipRRect(
                            // ajuste fino intencional: 1px menos que el radio del borde exterior
                            borderRadius: BorderRadius.circular(
                              AppRadius.radiusSm - 1,
                            ),
                            child: urlDeLaImagen.trim().startsWith('/')
                                ? Image.file(
                                    File(urlDeLaImagen.trim()),
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.precision_manufacturing,
                                              color: AppColors.primaryContainer,
                                              size: 32,
                                            ),
                                  )
                                : Image.network(
                                    urlDeLaImagen.trim(),
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.precision_manufacturing,
                                              color: AppColors.primaryContainer,
                                              size: 32,
                                            ),
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return const Center(
                                            child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          );
                                        },
                                  ),
                          )
                        : const Icon(
                            Icons.precision_manufacturing,
                            color: AppColors.primaryContainer,
                            size: 32,
                          ),
                  ),
                  // Badge de "ver completa" para descubribilidad del tap.
                  if (hasImage)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.open_in_full,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.spacingXs,
                    vertical: 2, // ajuste fino intencional: pastilla compacta
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.radiusXs),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    'REQUERIDO',
                    style: GoogleFonts.sora(
                      textStyle: AppTextStyles.textStyleSmall,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingXxs),
                Text(
                  title,
                  style: GoogleFonts.sora(
                    textStyle: AppTextStyles.textStyleBody,
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.sora(
                    textStyle: AppTextStyles.textStyleSmall,
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
    );
  }

  Widget _buildVehicleTechnicalSheet(Map<String, dynamic> objetoInterno) {
    final Map<String, dynamic> vehiculo =
        widget.solicitud['vehiculos_cliente'] is Map<String, dynamic>
        ? widget.solicitud['vehiculos_cliente'] as Map<String, dynamic>
        : (objetoInterno['vehiculos_cliente'] is Map<String, dynamic>
              ? objetoInterno['vehiculos_cliente'] as Map<String, dynamic>
              : {});

    final Map<String, dynamic> modelo =
        vehiculo['modelos_vehiculo'] is Map<String, dynamic>
        ? vehiculo['modelos_vehiculo'] as Map<String, dynamic>
        : {};

    final Map<String, dynamic> marca =
        modelo['marcas_vehiculo'] is Map<String, dynamic>
        ? modelo['marcas_vehiculo'] as Map<String, dynamic>
        : {};

    final String marcaNombre = marca['nombre']?.toString() ?? 'No especificada';
    final String modeloNombre =
        modelo['nombre']?.toString() ?? 'No especificado';
    final String anio =
        vehiculo['año']?.toString() ??
        vehiculo['anio']?.toString() ??
        'No especificado';

    final String vin =
        widget.solicitud['vin_busqueda']?.toString() ??
        objetoInterno['vin_busqueda']?.toString() ??
        vehiculo['vin']?.toString() ??
        '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.spacingXs),
              // Flexible: el título largo desbordaba el Row en móvil angosto
              // (RenderFlex overflow).
              Flexible(
                child: Text(
                  'FICHA TÉCNICA DEL VEHÍCULO',
                  style: GoogleFonts.sora(
                    textStyle: AppTextStyles.textStyleSmall,
                    color: AppColors.primary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const Divider(
            color: AppColors.outlineVariant,
            height: AppSpacing.spacingLg,
            thickness: 1,
          ),

          Row(
            children: [
              Expanded(
                child: _buildSpecsCell('Marca', marcaNombre, Icons.apartment),
              ),
              const SizedBox(width: AppSpacing.spacingXs),
              Expanded(
                child: _buildSpecsCell(
                  'Modelo',
                  modeloNombre,
                  Icons.directions_car,
                ),
              ),
              const SizedBox(width: AppSpacing.spacingXs),
              Expanded(
                child: _buildSpecsCell('Año', anio, Icons.calendar_today),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingMd),

          Text(
            'Número de Chasis / VIN (Indispensable)',
            style: AppTextStyles.textStyleSmall.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.spacingXs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spacingSm,
              vertical: AppSpacing.spacingSm,
            ),
            decoration: BoxDecoration(
              color: AppColors.onSurface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    vin.isNotEmpty
                        ? vin.toUpperCase()
                        : 'NO ESPECIFICADO POR EL CLIENTE',
                    style: AppTextStyles.textStyleCaption.copyWith(
                      color: vin.isNotEmpty
                          ? AppColors.onSurface
                          : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                      // familia monoespaciada intencional para el VIN (sin token equivalente)
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                if (vin.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: vin.toUpperCase()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('¡VIN copiado al portapapeles!'),
                          backgroundColor: AppColors.success,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.spacingXs),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                      ),
                      child: const Icon(
                        Icons.copy,
                        color: AppColors.secondary,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsCell(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingSm),
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.onSurfaceVariant, size: 12),
              const SizedBox(width: AppSpacing.spacingXxs),
              // Flexible: labels como "Transmisión"/"Cilindraje" desbordaban
              // la celda angosta en móvil (RenderFlex overflow); se truncan
              // con ellipsis en vez de salirse.
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: AppTextStyles.textStyleCaption.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceField() {
    return RyTextField(
      label: 'Precio de Venta (USD)',
      hint: '0.00',
      controller: _priceController,
      type: RyTextFieldType.decimal,
      isRequired: true,
      prefixIcon: Icons.attach_money,
      helperText: 'SE APLICARÁ UNA COMISIÓN DEL 5% POR TRANSACCIÓN',
      // Sin helperMaxLines el InputDecorator recorta el mensaje a 1 línea
      // con ellipsis (se veía desbordado/truncado en móvil angosto).
      helperMaxLines: 2,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Ingresa el precio de venta';
        }
        final parsed = double.tryParse(value.trim());
        if (parsed == null) {
          return 'Ingresa un precio válido (ej: 15.50)';
        }
        if (parsed <= 0) {
          return 'El precio debe ser mayor a 0';
        }
        return null;
      },
    );
  }

  Widget _buildConditionDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estado del Repuesto *',
          style: AppTextStyles.textStyleCaption.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        GFDropdown<String>(
          items: const [
            DropdownMenuItem(
              value: 'Nuevo (En caja original)',
              child: Text('Nuevo (En caja original)'),
            ),
            DropdownMenuItem(
              value: 'Nuevo (Abierto)',
              child: Text('Nuevo (Abierto)'),
            ),
            DropdownMenuItem(
              value: 'Usado (Buen estado)',
              child: Text('Usado (Buen estado)'),
            ),
          ],
          value: _selectedCondition,
          onChanged: (value) {
            if (value != null) setState(() => _selectedCondition = value);
          },
          dropdownButtonColor: AppColors.surfaceContainerHigh,
          dropdownColor: AppColors.surfaceContainerHigh,
          icon: const Icon(
            Icons.expand_more,
            color: AppColors.onSurfaceVariant,
          ),
          iconEnabledColor: AppColors.onSurfaceVariant,
          iconDisabledColor: AppColors.onSurfaceVariant,
          isExpanded: true,
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurface,
          ),
          underline: const SizedBox.shrink(),
          border: const BorderSide(color: AppColors.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          itemHeight: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd),
        ),
      ],
    );
  }

  Widget _buildDeliveryTimeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tiempo de Entrega Estimado *',
          style: AppTextStyles.textStyleCaption.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        GFDropdown<String>(
          items: const [
            DropdownMenuItem(value: 'Inmediata', child: Text('Inmediata')),
            DropdownMenuItem(value: '24-48 horas', child: Text('24-48 horas')),
            DropdownMenuItem(value: '3-5 días', child: Text('3-5 días')),
            DropdownMenuItem(value: '1-2 semanas', child: Text('1-2 semanas')),
          ],
          value: _selectedDeliveryTime,
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedDeliveryTime = value);
            }
          },
          dropdownButtonColor: AppColors.surfaceContainerHigh,
          dropdownColor: AppColors.surfaceContainerHigh,
          icon: const Icon(
            Icons.expand_more,
            color: AppColors.onSurfaceVariant,
          ),
          iconEnabledColor: AppColors.onSurfaceVariant,
          iconDisabledColor: AppColors.onSurfaceVariant,
          isExpanded: true,
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurface,
          ),
          underline: const SizedBox.shrink(),
          border: const BorderSide(color: AppColors.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          itemHeight: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd),
        ),
      ],
    );
  }

  /// Sección de logística de despacho: muestra la distancia real (km) y el
  /// tiempo de despacho estimado entre el almacén y el punto de entrega del
  /// cliente, calculados con las coordenadas del snapshot de la solicitud.
  /// Es información núcleo para que el almacén valide la viabilidad operativa
  /// antes de cotizar (radio razonable, costos y tiempos de despacho).
  Widget _buildLogisticaDespachoSection() {
    final Map<String, dynamic> objetoInterno =
        widget.solicitud['solicitud'] is Map<String, dynamic>
        ? widget.solicitud['solicitud'] as Map<String, dynamic>
        : {};

    final Map<String, dynamic>? direccion =
        objetoInterno['direcciones_entrega'] is Map<String, dynamic>
        ? objetoInterno['direcciones_entrega'] as Map<String, dynamic>
        : null;

    final String direccionTexto = direccion == null
        ? 'No especificada'
        : [
                direccion['alias'],
                direccion['calle_principal'],
                direccion['calle_secundaria'],
                direccion['referencia'],
              ]
              .where((p) => p != null && p.toString().trim().isNotEmpty)
              .join(', ');

    final double? latCliente =
        _toDouble(objetoInterno['latitud_entrega']) ??
        _toDouble(direccion?['latitude']);
    final double? lonCliente =
        _toDouble(objetoInterno['longitud_entrega']) ??
        _toDouble(direccion?['longitude']);
    final double? latAlmacen = _toDouble(_almacen?['latitude']);
    final double? lonAlmacen = _toDouble(_almacen?['longitude']);

    double? distanciaKm;
    int? tiempoMin;
    if (latCliente != null &&
        lonCliente != null &&
        latAlmacen != null &&
        lonAlmacen != null) {
      final metros = Geolocator.distanceBetween(
        latAlmacen,
        lonAlmacen,
        latCliente,
        lonCliente,
      );
      distanciaKm = double.parse((metros / 1000).toStringAsFixed(1));
      // Misma heurística que el backend: preparación + traslado a 30 km/h.
      tiempoMin = (20 + (distanciaKm / 30) * 60).round();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.spacingXs),
              Text(
                'LOGÍSTICA DE DESPACHO',
                style: GoogleFonts.sora(
                  textStyle: AppTextStyles.textStyleSmall,
                  color: AppColors.primary.withValues(alpha: 0.9),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const Divider(
            color: AppColors.outlineVariant,
            height: AppSpacing.spacingLg,
            thickness: 1,
          ),
          _buildInfoRow(
            Icons.location_on_outlined,
            'Punto de entrega',
            direccionTexto,
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          Row(
            children: [
              Expanded(
                child: _buildSpecsCell(
                  'Distancia (km)',
                  distanciaKm != null ? '$distanciaKm km' : 'No disponible',
                  Icons.route_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.spacingXs),
              Expanded(
                child: _buildSpecsCell(
                  'Despacho est.',
                  tiempoMin != null ? '~$tiempoMin min' : 'No disponible',
                  Icons.schedule,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.onSurfaceVariant, size: 16),
        const SizedBox(width: AppSpacing.spacingXs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.textStyleSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Sección unificada de evidencia visual usando `RyImagePicker` (mismo
  /// widget que `CreateRequestPage`). Mantiene el label "Evidencia Visual"
  /// y el helper "Foto del repuesto en stock" del diseño original, pero
  /// delega selección/preview/eliminar al widget reutilizable.
  Widget _buildEvidenciaVisualSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Evidencia Visual',
          style: AppTextStyles.textStyleCaption.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        RyImagePicker(
          width: double.infinity,
          height: 180,
          currentFile: _selectedImage,
          onImageSelected: (file) {
            setState(() => _selectedImage = file);
          },
          onRemove: () {
            setState(() => _selectedImage = null);
          },
          // Ver la evidencia seleccionada en pantalla completa antes de enviar.
          onViewFullImage: _selectedImage != null
              ? () => _openFullImage(_selectedImage!.path)
              : null,
          customPlaceholder: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_a_photo,
                    color: AppColors.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingSm),
                Text(
                  'Foto del repuesto en stock',
                  style: AppTextStyles.textStyleCaption.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingXxs / 2),
                Text(
                  'Toca para usar la cámara o elegir de galería',
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notas Adicionales (Opcional)',
          style: AppTextStyles.textStyleCaption.copyWith(
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        TextFormField(
          controller: _notesController,
          maxLines: 4,
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurface,
          ),
          decoration: InputDecoration(
            hintText: 'Ej: Incluye garantía de 6 meses, entrega inmediata...',
            hintStyle: AppTextStyles.textStyleBody.copyWith(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            filled: true,
            fillColor: AppColors.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              borderSide: const BorderSide(color: AppColors.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              borderSide: const BorderSide(color: AppColors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              borderSide: const BorderSide(color: AppColors.primaryContainer),
            ),
            contentPadding: const EdgeInsets.all(AppSpacing.spacingMd),
          ),
        ),
      ],
    );
  }

  Widget _buildImportantInfoBox() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.spacingSm),
          Expanded(
            child: Text(
              'Al enviar esta cotización, te comprometes a mantener el stock reservado por 24 horas.',
              style: AppTextStyles.textStyleSmall.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Barra de acción fija al fondo con el componente compartido del DS:
  /// respeta el inset inferior (barra de gestos) extendiendo el fondo hasta
  /// el borde real y eleva el botón por encima del área segura.
  Widget _buildBottomActionButton() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: RyBottomActionBar(
        primaryLabel: 'ENVIAR COTIZACIÓN',
        primaryIcon: Icons.send,
        primaryLoading: _isSubmitting,
        onPrimaryPressed: _isSubmitting ? null : _enviarCotizacion,
      ),
    );
  }
}
