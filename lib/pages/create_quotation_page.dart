import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../services/solicitud_service.dart';
import '../services/almacen_service.dart';
import '../services/almacen_repository.dart';
import '../widgets/ry_text_field.dart';
import '../widgets/ry_image_picker.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';

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

  final SolicitudService _solicitudService = SolicitudService();
  late final AlmacenService _almacenService;

  @override
  void initState() {
    super.initState();
    _almacenService = AlmacenService(context.read<AlmacenRepository>());
  }

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Sube una imagen al bucket `Repuestosya` bajo la ruta:
  /// `evidencias/cotizaciones/{almacenId}/cotizacion_{timestamp}.jpg`
  ///
  /// Devuelve la URL pública del archivo, o `null` si la subida falla.
  /// Patrón unificado con `CreateRequestPage._uploadImageToSupabase`:
  /// mismo bucket, misma carpeta base `evidencias/`, separación por dominio
  /// (`solicitudes/{clienteId}/...` para solicitudes,
  /// `cotizaciones/{almacenId}/...` para cotizaciones).
  Future<String?> _uploadImageToSupabase(
    File imageFile,
    String almacenId,
  ) async {
    try {
      AppLogger.debug(
        '[UPLOAD] Iniciando subida de imagen de cotización...',
        name: 'CreateQuotationPage',
      );

      final supabase = Supabase.instance.client;

      // Verificar sesión de autenticación
      final session = supabase.auth.currentSession;
      if (session == null) {
        AppLogger.warning(
          '[UPLOAD] No hay sesión activa. Intentando refrescar...',
          name: 'CreateQuotationPage',
        );
        try {
          await supabase.auth.refreshSession();
          AppLogger.info(
            '[UPLOAD] Sesión refrescada',
            name: 'CreateQuotationPage',
          );
        } catch (e) {
          AppLogger.error(
            '[UPLOAD] Error al refrescar sesión',
            name: 'CreateQuotationPage',
            error: e,
          );
          return null;
        }
      }

      // Generar nombre único y ruta por dominio funcional.
      // Patrón unificado con solicitudes:
      //   solicitudes  -> evidencias/solicitudes/{clienteId}/solicitud_{ts}.jpg
      //   cotizaciones -> evidencias/cotizaciones/{almacenId}/cotizacion_{ts}.jpg
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'cotizacion_$timestamp.jpg';
      final filePath = 'evidencias/cotizaciones/$almacenId/$fileName';
      AppLogger.debug(
        '[UPLOAD] FilePath: $filePath (${await imageFile.length()} bytes)',
        name: 'CreateQuotationPage',
      );

      // Subir al bucket `Repuestosya` (mismo bucket que solicitudes)
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

      // Obtener URL pública (mismo patrón que solicitudes)
      final publicUrl = supabase.storage
          .from('Repuestosya')
          .getPublicUrl(filePath);

      AppLogger.info(
        '[UPLOAD] URL pública: $publicUrl',
        name: 'CreateQuotationPage',
      );

      return publicUrl;
    } catch (e, stackTrace) {
      AppLogger.error(
        '[UPLOAD] Error al subir imagen de cotización',
        name: 'CreateQuotationPage',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _enviarCotizacion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final Map<String, dynamic> objetoInterno =
          widget.solicitud['solicitud'] is Map<String, dynamic>
          ? widget.solicitud['solicitud'] as Map<String, dynamic>
          : {};

      final String solicitudId =
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
      // Storage ahora se segmenta por dominio funcional:
      //   evidencias/cotizaciones/{almacenId}/cotizacion_{timestamp}.jpg
      final almacen = await _almacenService.obtenerMiAlmacen();
      if (almacen == null) {
        throw Exception(
          'No tienes un almacén asociado. Por favor, completa tu perfil comercial.',
        );
      }

      final String almacenId = almacen['id']?.toString() ?? '';
      if (almacenId.isEmpty || almacenId == 'null') {
        throw Exception('El ID del almacén es inválido o está vacío.');
      }

      // Subir imagen (si hay) usando el path unificado por dominio.
      // Si la subida falla, no se crea la cotización: se informa al usuario
      // (mismo patrón que CreateRequestPage._handleSubmit).
      String? uploadedImageUrl;
      if (_selectedImage != null) {
        uploadedImageUrl = await _uploadImageToSupabase(
          _selectedImage!,
          almacenId,
        );

        if (uploadedImageUrl == null || uploadedImageUrl.isEmpty) {
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
          setState(() => _isSubmitting = false);
          return;
        }
      }

      // Consumo del servicio con los nombres y valores en español ya homologados
      await _solicitudService.crearCotizacion(
        solicitudId: solicitudId,
        almacenId: almacenId,
        precio: double.tryParse(_priceController.text) ?? 0.0,
        notas: _notesController.text
            .trim(), // CORRECCIÓN: "notas" en lugar de "notes"
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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              border: Border.all(color: AppColors.outlineVariant, width: 1),
            ),
            child: (urlDeLaImagen != null && urlDeLaImagen.trim().isNotEmpty)
                ? ClipRRect(
                    // ajuste fino intencional: 1px menos que el radio del borde exterior
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm - 1),
                    child: urlDeLaImagen.trim().startsWith('/')
                        ? Image.file(
                            File(urlDeLaImagen.trim()),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.precision_manufacturing,
                                  color: AppColors.primaryContainer,
                                  size: 32,
                                ),
                          )
                        : Image.network(
                            urlDeLaImagen.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.precision_manufacturing,
                                  color: AppColors.primaryContainer,
                                  size: 32,
                                ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
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
              Text(
                'FICHA TÉCNICA DEL VEHÍCULO',
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
              Text(
                label,
                style: AppTextStyles.textStyleSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCondition,
              dropdownColor: AppColors.surfaceContainerHigh,
              icon: const Icon(
                Icons.expand_more,
                color: AppColors.onSurfaceVariant,
              ),
              isExpanded: true,
              style: AppTextStyles.textStyleBody.copyWith(
                color: AppColors.onSurface,
              ),
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
              onChanged: (value) {
                if (value != null) setState(() => _selectedCondition = value);
              },
            ),
          ),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDeliveryTime,
              dropdownColor: AppColors.surfaceContainerHigh,
              icon: const Icon(
                Icons.expand_more,
                color: AppColors.onSurfaceVariant,
              ),
              isExpanded: true,
              style: AppTextStyles.textStyleBody.copyWith(
                color: AppColors.onSurface,
              ),
              items: const [
                DropdownMenuItem(value: 'Inmediata', child: Text('Inmediata')),
                DropdownMenuItem(
                  value: '24-48 horas',
                  child: Text('24-48 horas'),
                ),
                DropdownMenuItem(value: '3-5 días', child: Text('3-5 días')),
                DropdownMenuItem(
                  value: '1-2 semanas',
                  child: Text('1-2 semanas'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedDeliveryTime = value);
                }
              },
            ),
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

  Widget _buildBottomActionButton() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.9),
          border: const Border(
            top: BorderSide(color: AppColors.outlineVariant, width: 1),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _enviarCotizacion,
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
                        Icons.send,
                        color: AppColors.onPrimaryContainer,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.spacingXs),
                      Text(
                        'ENVIAR COTIZACIÓN',
                        style: AppTextStyles.textStyleButton.copyWith(
                          color: AppColors.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
