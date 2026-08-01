import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';
import '../services/almacen_service.dart';

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

  final ImagePicker _imagePicker = ImagePicker();
  final AuthService _authService = AuthService();
  final SolicitudService _solicitudService = SolicitudService();
  final AlmacenService _almacenService = AlmacenService();

  // Sistema de Diseño y Paleta de Colores Industrial
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF131313);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color surfaceContainerHighest = Color(0xFF353534);
  static const Color surfaceVariant = Color(0xFF353534);

  static const Color primary = Color(0xFFFFB5A0);
  static const Color primaryContainer = Color(0xFFFF5722);
  static const Color onPrimaryContainer = Color(0xFF541200);
  static const Color secondary = Color(0xFF9ECAFF);
  static const Color secondaryContainer = Color(0xFF1E95F2);
  static const Color outlineVariant = Color(0xFF5B4039);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFE4BEB4);

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Muestra un panel para elegir entre tomar una foto con la cámara o
  // seleccionar una imagen existente de la galería.
  Future<void> _showImageSourceSelector() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Evidencia Visual',
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Sora',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: secondaryContainer.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_camera, color: secondary),
                  ),
                  title: const Text(
                    'Tomar foto',
                    style: TextStyle(
                      color: onSurface,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Usar la cámara del dispositivo',
                    style: TextStyle(
                      color: onSurfaceVariant,
                      fontFamily: 'Inter',
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: secondaryContainer.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library, color: secondary),
                  ),
                  title: const Text(
                    'Elegir de galería',
                    style: TextStyle(
                      color: onSurface,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Seleccionar una imagen ya existente',
                    style: TextStyle(
                      color: onSurfaceVariant,
                      fontFamily: 'Inter',
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_selectedImage != null)
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                    ),
                    title: const Text(
                      'Quitar imagen',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedImage = null);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera
                  ? 'No se pudo acceder a la cámara: $e'
                  : 'Error al seleccionar la imagen: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Traducción lógica segura para que coincida exactamente con la columna de Supabase
  String _getConditionDbValue(String condition) {
    switch (condition) {
      case 'new':
        return 'Nuevo (En caja original)';
      case 'used_a':
      case 'used_b':
        return 'Usado (Buen estado)'; // Unificar todos los usados a este valor
      case 'refurbished':
        return 'Nuevo (Abierto)'; // O puedes elegir 'Usado (Buen estado)' si prefieres
      default:
        return 'Nuevo (En caja original)';
    }
  }

  Future<String?> _uploadImageToSupabase(File imageFile) async {
    try {
      print('[UPLOAD] 🚀 Iniciando subida de imagen...');

      final supabase = Supabase.instance.client;

      // Verificar sesión de autenticación
      final session = supabase.auth.currentSession;
      if (session == null) {
        print('[UPLOAD] ❌ No hay sesión activa. Intentando refrescar...');
        try {
          await supabase.auth.refreshSession();
          print('[UPLOAD] ✅ Sesión refrescada');
        } catch (e) {
          print('[UPLOAD] ❌ Error al refrescar sesión: $e');
          return null;
        }
      } else {
        print('[UPLOAD] ✅ Usuario autenticado: ${session.user.id}');
      }

      // Generar nombre único
      final fileName =
          'cotizacion_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'evidencias/$fileName';
      print('[UPLOAD] 📁 FilePath: $filePath');
      print('[UPLOAD] 📦 Tamaño: ${await imageFile.length()} bytes');

      // Subir al bucket
      print('[UPLOAD] ⬆️ Subiendo imagen...');
      final response = await supabase.storage
          .from('Repuestosya')
          .upload(
            filePath,
            imageFile,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );

      print('[UPLOAD] ✅ Upload response: $response');

      // Obtener URL pública
      final publicUrl = supabase.storage
          .from('Repuestosya')
          .getPublicUrl(filePath);

      print('[UPLOAD] 🔗 URL pública: $publicUrl');

      return publicUrl;
    } catch (e, stackTrace) {
      print('[UPLOAD] ❌ ERROR DETALLADO: $e');
      print('[UPLOAD] Stack trace: $stackTrace');
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

      String? uploadedImageUrl;
      if (_selectedImage != null) {
        setState(() => _isSubmitting = true);

        uploadedImageUrl = await _uploadImageToSupabase(_selectedImage!);

        if (uploadedImageUrl == null) {
          throw Exception(
            'La subida de imagen falló. Revisa la consola de Flutter para ver el error detallado. '
            'Posibles causas: 1) Bucket no existe, 2) Políticas de INSERT faltantes, 3) Usuario no autenticado',
          );
        }
      }

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
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar la cotización: $e'),
            backgroundColor: Colors.red,
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
      backgroundColor: background,
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
                color: primary.withOpacity(0.03),
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
                color: secondary.withOpacity(0.03),
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
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 110),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCard(piezaNombre, descripcion),
                          const SizedBox(height: 16),

                          // SECCIÓN DE ESPECIFICACIONES TÉCNICAS Y VIN
                          _buildVehicleTechnicalSheet(objetoInterno),

                          const SizedBox(height: 24),
                          _buildPriceField(),
                          const SizedBox(height: 24),
                          _buildConditionDropdown(),
                          const SizedBox(height: 24),
                          _buildDeliveryTimeDropdown(),
                          const SizedBox(height: 24),
                          _buildImageUploadArea(),
                          const SizedBox(height: 24),
                          _buildNotesField(),
                          const SizedBox(height: 24),
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: outlineVariant, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: primary, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Nueva Cotización',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Sora',
                  ),
                ),
                Text(
                  'Solicitud #$id - $pieza',
                  style: const TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12,
                    fontFamily: 'Inter',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outlineVariant, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: outlineVariant, width: 1),
            ),
            child: (urlDeLaImagen != null && urlDeLaImagen.trim().isNotEmpty)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: urlDeLaImagen.trim().startsWith('/')
                        ? Image.file(
                            File(urlDeLaImagen.trim()),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.precision_manufacturing,
                                  color: primaryContainer,
                                  size: 32,
                                ),
                          )
                        : Image.network(
                            urlDeLaImagen.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.precision_manufacturing,
                                  color: primaryContainer,
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
                                    color: primary,
                                  ),
                                ),
                              );
                            },
                          ),
                  )
                : const Icon(
                    Icons.precision_manufacturing,
                    color: primaryContainer,
                    size: 32,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: secondaryContainer.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: secondary.withOpacity(0.2)),
                  ),
                  child: const Text(
                    'REQUERIDO',
                    style: TextStyle(
                      color: secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Sora',
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: onSurfaceVariant,
                    fontSize: 12,
                    fontFamily: 'Inter',
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'FICHA TÉCNICA DEL VEHÍCULO',
                style: TextStyle(
                  color: primary.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontFamily: 'Sora',
                ),
              ),
            ],
          ),
          const Divider(color: outlineVariant, height: 24, thickness: 1),

          Row(
            children: [
              Expanded(
                child: _buildSpecsCell('Marca', marcaNombre, Icons.apartment),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSpecsCell(
                  'Modelo',
                  modeloNombre,
                  Icons.directions_car,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSpecsCell('Año', anio, Icons.calendar_today),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const Text(
            'Número de Chasis / VIN (Indispensable)',
            style: TextStyle(
              color: onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: outlineVariant.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    vin.isNotEmpty
                        ? vin.toUpperCase()
                        : 'NO ESPECIFICADO POR EL CLIENTE',
                    style: TextStyle(
                      color: vin.isNotEmpty
                          ? Colors.white
                          : onSurfaceVariant.withOpacity(0.5),
                      fontSize: 14,
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
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.copy, color: secondary, size: 16),
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
      padding: const EdgeInsets.all(10),
      height: 72,
      decoration: BoxDecoration(
        color: surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: onSurfaceVariant, size: 12),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: onSurfaceVariant,
                  fontSize: 10,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'Sora',
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Precio de Venta (USD) *',
          style: TextStyle(
            color: onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          // CORRECCIÓN: "inputFormatters" está correctamente escrito
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontFamily: 'Sora',
            fontWeight: FontWeight.bold,
          ),
          validator: (value) {
            if (value == null || value.isEmpty)
              return 'Por favor ingresa un precio';
            if (double.tryParse(value) == null || double.parse(value) <= 0)
              return 'Ingresa un monto válido';
            return null;
          },
          decoration: InputDecoration(
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '\$',
                style: TextStyle(
                  color: primary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            hintText: '0.00',
            hintStyle: TextStyle(color: onSurfaceVariant.withOpacity(0.2)),
            filled: true,
            fillColor: surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryContainer, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: 16,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'SE APLICARÁ UNA COMISIÓN DEL 5% POR TRANSACCIÓN.',
          style: TextStyle(
            color: Color(0x77E4BEB4),
            fontSize: 10,
            letterSpacing: 0.5,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  Widget _buildConditionDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estado del Repuesto *',
          style: TextStyle(
            color: onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCondition,
              dropdownColor: surfaceContainerHigh,
              icon: const Icon(Icons.expand_more, color: onSurfaceVariant),
              isExpanded: true,
              style: const TextStyle(
                color: onSurface,
                fontSize: 15,
                fontFamily: 'Inter',
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
        const Text(
          'Tiempo de Entrega Estimado *',
          style: TextStyle(
            color: onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDeliveryTime,
              dropdownColor: surfaceContainerHigh,
              icon: const Icon(Icons.expand_more, color: onSurfaceVariant),
              isExpanded: true,
              style: const TextStyle(
                color: onSurface,
                fontSize: 15,
                fontFamily: 'Inter',
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
                if (value != null)
                  setState(() => _selectedDeliveryTime = value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageUploadArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Evidencia Visual',
          style: TextStyle(
            color: onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showImageSourceSelector,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: secondaryContainer.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: secondaryContainer.withOpacity(0.4),
                width: 1.5,
                style: BorderStyle.solid,
              ),
            ),
            child: _selectedImage != null
                ? Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImage!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.edit, color: secondary, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Cambiar imagen',
                            style: TextStyle(
                              color: secondary,
                              fontSize: 14,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: secondaryContainer.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_a_photo,
                          color: secondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Foto del repuesto en stock',
                        style: TextStyle(
                          color: onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Toca para usar la cámara o elegir de galería',
                        style: TextStyle(
                          color: onSurfaceVariant,
                          fontSize: 12,
                          fontFamily: 'Inter',
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
        const Text(
          'Notas Adicionales (Opcional)',
          style: TextStyle(
            color: onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 4,
          style: const TextStyle(
            color: onSurface,
            fontSize: 15,
            fontFamily: 'Inter',
          ),
          decoration: InputDecoration(
            hintText: 'Ej: Incluye garantía de 6 meses, entrega inmediata...',
            hintStyle: TextStyle(color: onSurfaceVariant.withOpacity(0.3)),
            filled: true,
            fillColor: surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryContainer),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildImportantInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceContainerHighest.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outlineVariant.withOpacity(0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info, color: primary, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Al enviar esta cotización, te comprometes a mantener el stock reservado por 24 horas.',
              style: TextStyle(
                color: onSurfaceVariant,
                fontSize: 12,
                height: 1.4,
                fontFamily: 'Inter',
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background.withOpacity(0.9),
          border: const Border(
            top: BorderSide(color: outlineVariant, width: 1),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _enviarCotizacion,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryContainer,
              disabledBackgroundColor: primaryContainer.withOpacity(0.4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: onPrimaryContainer,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'PROCESANDO...',
                        style: TextStyle(
                          color: onPrimaryContainer,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Sora',
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send, color: onPrimaryContainer, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'ENVIAR COTIZACIÓN',
                        style: TextStyle(
                          color: onPrimaryContainer,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Sora',
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
