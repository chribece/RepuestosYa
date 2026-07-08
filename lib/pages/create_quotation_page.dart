import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';

class CreateQuotationPage extends StatefulWidget {
  final Map<String, dynamic> solicitud;

  const CreateQuotationPage({
    super.key,
    required this.solicitud,
  });

  @override
  State<CreateQuotationPage> createState() => _CreateQuotationPageState();
}

class _CreateQuotationPageState extends State<CreateQuotationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _selectedCondition = 'new';
  
  File? _selectedImage;
  bool _isSubmitting = false;

  final ImagePicker _imagePicker = ImagePicker();
  final AuthService _authService = AuthService();
  // Asumiendo que extiendes o usas tu SolicitudService para insertar cotizaciones
  final SolicitudService _solicitudService = SolicitudService(); 

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
  static const Color tertiaryContainer = Color(0xFF019AD8);
  static const Color outlineVariant = Color(0xFF5B4039);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFE4BEB4);

  @override
  void dispose() {
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Lógica para seleccionar imagen desde la cámara/galería (Misma lógica que CreateRequestPage)
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery, // O ImageSource.camera según prefieras
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar la imagen: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Envío asíncrono de datos al Backend
  Future<void> _enviarCotizacion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = _authService.currentUser?.id; 
      final String solicitudId = widget.solicitud['id']?.toString() ?? '';
      String? uploadedImageUrl;

      // 1. Si el operador del almacén capturó una foto física del stock
      if (_selectedImage != null) {
        // TODO: Implementa aquí la subida al Storage Bucket de tu backend
        // tal como lo hace el cliente en create_request_page.dart para rescatar el link string.
        
        // Enlace de prueba provisional para verificar la persistencia en base de datos:
        uploadedImageUrl = "https://tu-proyecto.supabase.co/storage/v1/object/public/cotizaciones/repuesto_verificado.jpg";
      }

      // 2. Invocación asíncrona estructurada al servicio corregido
      await _solicitudService.crearCotizacion(
        solicitudId: solicitudId,
        almacenId: userId ?? '',
        precio: double.tryParse(_priceController.text) ?? 0.0,
        notas: _notesController.text.trim(),
        fotoUrl: uploadedImageUrl, // Pasamos el String limpio libre de errores multipart
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        Navigator.pop(context, true); // Cierra la pantalla y actualiza el Dashboard en tiempo real
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
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extracción dinámica segura de datos de la fila de la BD
    final String piezaNombre = widget.solicitud['pieza_nombre'] ?? 'Repuesto';
    final String descripcion = widget.solicitud['descripcion'] ?? 'Sin especificaciones técnicas';
    final String idSolicitud = widget.solicitud['id']?.toString().substring(0, double.parse(widget.solicitud['id'].toString().length.toString()) > 4 ? 4 : widget.solicitud['id'].toString().length) ?? '0000';

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          // Capas decorativas de difuminado ambiental
          Positioned(
            top: -100,
            right: -100,
            child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: primary.withOpacity(0.03))),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: secondary.withOpacity(0.03))),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildHeader(idSolicitud, piezaNombre),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 110),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCard(piezaNombre, descripcion),
                          const SizedBox(height: 24),
                          _buildPriceField(),
                          const SizedBox(height: 24),
                          _buildConditionDropdown(),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Nueva Cotización',
                style: TextStyle(color: onSurface, fontSize: 20, fontWeight: FontWeight.w600, fontFamily: 'Sora'),
              ),
              Text(
                'Solicitud #$id - $pieza',
                style: const TextStyle(color: onSurfaceVariant, fontSize: 12, fontFamily: 'Inter'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String subtitle) {
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
            child: widget.solicitud['imagen_url'] != null 
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(widget.solicitud['imagen_url'], fit: BoxFit.cover),
                  )
                : const Icon(Icons.precision_manufacturing, color: primaryContainer, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: secondaryContainer.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: secondary.withOpacity(0.2)),
                  ),
                  child: const Text(
                    'REQUERIDO',
                    style: TextStyle(color: secondary, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(color: onSurface, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Sora'),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: onSurfaceVariant, fontSize: 12, fontFamily: 'Inter'),
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

  Widget _buildPriceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Precio de Venta (USD)',
          style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          style: const TextStyle(color: Colors.white, fontSize: 22, fontFamily: 'Sora', fontWeight: FontWeight.bold),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Por favor ingresa un precio';
            if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Ingresa un monto válido';
            return null;
          },
          decoration: InputDecoration(
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('\$', style: TextStyle(color: primary, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            hintText: '0.00',
            hintStyle: TextStyle(color: onSurfaceVariant.withOpacity(0.2)),
            filled: true,
            fillColor: surfaceContainerHigh,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariant)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariant)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryContainer, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'SE APLICARÁ UNA COMISIÓN DEL 5% POR TRANSACCIÓN.',
          style: TextStyle(color: Color(0x77E4BEB4), fontSize: 10, letterSpacing: 0.5, fontFamily: 'Inter'),
        ),
      ],
    );
  }

  Widget _buildConditionDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estado del Repuesto',
          style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
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
              style: const TextStyle(color: onSurface, fontSize: 15, fontFamily: 'Inter'),
              items: const [
                DropdownMenuItem(value: 'new', child: Text('Nuevo (En caja original)')),
                DropdownMenuItem(value: 'used_a', child: Text('Usado - Grado A (Como nuevo)')),
                DropdownMenuItem(value: 'used_b', child: Text('Usado - Grado B (Funcional)')),
                DropdownMenuItem(value: 'refurbished', child: Text('Reacondicionado')),
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

  Widget _buildImageUploadArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Evidencia Visual',
          style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: secondaryContainer.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: secondaryContainer.withOpacity(0.4), width: 1.5, style: BorderStyle.solid),
            ),
            child: _selectedImage != null
                ? Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_selectedImage!, height: 150, width: double.infinity, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 8),
                      const Text('Cambiar imagen', style: TextStyle(color: secondary, fontSize: 14, fontFamily: 'Inter')),
                    ],
                  )
                : Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: secondaryContainer.withOpacity(0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.add_a_photo, color: secondary, size: 24),
                      ),
                      const SizedBox(height: 12),
                      const Text('Foto del repuesto en stock', style: TextStyle(color: onSurface, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Inter')),
                      const SizedBox(height: 2),
                      const Text('PNG, JPG hasta 10MB', style: TextStyle(color: onSurfaceVariant, fontSize: 12, fontFamily: 'Inter')),
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
          style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 4,
          style: const TextStyle(color: onSurface, fontSize: 15, fontFamily: 'Inter'),
          decoration: InputDecoration(
            hintText: 'Ej: Incluye garantía de 6 meses, entrega inmediata...',
            hintStyle: TextStyle(color: onSurfaceVariant.withOpacity(0.3)),
            filled: true,
            fillColor: surfaceContainerHigh,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariant)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariant)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryContainer)),
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
              style: TextStyle(color: onSurfaceVariant, fontSize: 12, height: 1.4, fontFamily: 'Inter'),
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
          border: const Border(top: BorderSide(color: outlineVariant, width: 1)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSubmitting
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: onPrimaryContainer)),
                      SizedBox(width: 12),
                      Text('PROCESANDO...', style: TextStyle(color: onPrimaryContainer, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Sora')),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send, color: onPrimaryContainer, size: 20),
                      SizedBox(width: 8),
                      Text('ENVIAR COTIZACIÓN', style: TextStyle(color: onPrimaryContainer, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Sora')),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}