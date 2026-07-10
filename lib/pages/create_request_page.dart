import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';
import '../services/vehiculo_service.dart';
import '../services/direccion_service.dart';

class CreateRequestPage extends StatefulWidget {
  const CreateRequestPage({super.key});

  @override
  State<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends State<CreateRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _piezaNombreController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vinController = TextEditingController();
  final _locationController = TextEditingController(); // Solo para mostrar

  File? _selectedImage;
  bool _isUploading = false;
  bool _isSubmitting = false;

  String? _selectedVehiculoId;
  String? _selectedDireccionId;
  List<Map<String, dynamic>> _vehiculos = [];
  List<Map<String, dynamic>> _direcciones = [];
  bool _isLoadingVehiculos = false;
  bool _isLoadingDirecciones = false;

  final ImagePicker _imagePicker = ImagePicker();
  final SolicitudService _solicitudService = SolicitudService();
  final AuthService _authService = AuthService();
  final VehiculoService _vehiculoService = VehiculoService();
  final DireccionService _direccionService = DireccionService();

  // Colores
  static const Color primary = Color(0xFFFFB5A0);
  static const Color primaryContainer = Color(0xFFFF5722);
  static const Color onPrimaryContainer = Color(0xFF541200);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color outlineVariant = Color(0xFF5B4039);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFE4BEB4);
  static const Color tertiaryContainer = Color(0xFF019AD8);
  static const Color secondaryContainer = Color(0xFF1E95F2);
  static const Color background = Color(0xFF131313);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color requiredAsterisk = Color(0xFFFF3333);

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
    _vinController.dispose();
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
      print('Error al cargar vehículos: $e');
    } finally {
      setState(() => _isLoadingVehiculos = false);
    }
  }

  Future<void> _cargarDirecciones() async {
    setState(() => _isLoadingDirecciones = true);
    try {
      final direcciones = await _direccionService.getDirecciones();
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
        } else {
          _selectedDireccionId = null;
          _locationController.text = 'Selecciona o agrega una dirección';
        }
      });
    } catch (e) {
      print('Error al cargar direcciones: $e');
    } finally {
      setState(() => _isLoadingDirecciones = false);
    }
  }

  String _formatDireccion(Map<String, dynamic> direccion) {
    final alias = direccion['alias'] as String? ?? '';
    final callePrincipal = direccion['callePrincipal'] as String? ?? '';
    final calleSecundaria = direccion['calleSecundaria'] as String? ?? '';
    final referencia = direccion['referencia'] as String? ?? '';

    String texto = '';
    if (alias.isNotEmpty) texto += '$alias: ';
    texto += callePrincipal;
    if (calleSecundaria.isNotEmpty) texto += ' y $calleSecundaria';
    if (referencia.isNotEmpty) texto += ' ($referencia)';
    return texto.isEmpty ? 'Dirección sin nombre' : texto;
  }

  // ========== IMAGEN ==========

  Future<void> _pickImage() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceContainerHigh,
        title: const Text('Seleccionar imagen', style: TextStyle(color: onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: primaryContainer),
              title: const Text('Cámara', style: TextStyle(color: onSurface)),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: primaryContainer),
              title: const Text('Galería', style: TextStyle(color: onSurface)),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image != null) {
        setState(() => _isUploading = true);
        await Future.delayed(const Duration(milliseconds: 1500)); // Simular subida
        setState(() {
          _selectedImage = File(image.path);
          _isUploading = false;
        });
        _showToast('Imagen cargada con éxito');
      }
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar imagen: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: primaryContainer),
            const SizedBox(width: 8),
            Text(message, style: const TextStyle(color: onSurface)),
          ],
        ),
        backgroundColor: surfaceContainerHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
          side: const BorderSide(color: primaryContainer),
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

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Agregar nueva dirección',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: aliasController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Alias (ej: Casa, Taller)',
                      labelStyle: TextStyle(color: onSurfaceVariant),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryContainer),
                      ),
                    ),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? 'Ingresa un alias' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: callePrincipalController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Calle principal',
                      labelStyle: TextStyle(color: onSurfaceVariant),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryContainer),
                      ),
                    ),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? 'Ingresa la calle principal' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: calleSecundariaController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Calle secundaria (opcional)',
                      labelStyle: TextStyle(color: onSurfaceVariant),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryContainer),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: referenciaController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Referencia (opcional)',
                      labelStyle: TextStyle(color: onSurfaceVariant),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryContainer),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar', style: TextStyle(color: onSurfaceVariant)),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              try {
                                final nueva = await _direccionService.createDireccion(
                                  alias: aliasController.text.trim(),
                                  callePrincipal: callePrincipalController.text.trim(),
                                  calleSecundaria: calleSecundariaController.text.trim(),
                                  referencia: referenciaController.text.trim(),
                                );
                                // Cerrar modal con éxito
                                Navigator.pop(context, true);
                                // Recargar lista y seleccionar la nueva dirección
                                await _cargarDirecciones();
                                // Forzar selección de la nueva (por si no es principal)
                                setState(() {
                                  _selectedDireccionId = nueva['id'] as String?;
                                  _locationController.text = _formatDireccion(nueva);
                                });
                                _showToast('Dirección agregada correctamente');
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error al guardar dirección: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryContainer,
                            foregroundColor: onPrimaryContainer,
                          ),
                          child: const Text('Guardar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
        backgroundColor: surfaceContainerHigh,
        title: const Text(
          'Seleccionar dirección de entrega',
          style: TextStyle(color: onSurface),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _isLoadingDirecciones
              ? const Center(child: CircularProgressIndicator(color: primaryContainer))
              : _direcciones.isEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'No tienes direcciones registradas',
                          style: TextStyle(color: onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _agregarDireccion();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar dirección'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryContainer,
                            foregroundColor: onPrimaryContainer,
                          ),
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
                              final isSelected = direccion['id'] == _selectedDireccionId;
                              return ListTile(
                                title: Text(
                                  _formatDireccion(direccion),
                                  style: const TextStyle(color: onSurface),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle, color: primaryContainer)
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedDireccionId = direccion['id'] as String?;
                                    _locationController.text = _formatDireccion(direccion);
                                  });
                                  Navigator.pop(context);
                                  _showToast('Dirección actualizada');
                                },
                              );
                            },
                          ),
                        ),
                        const Divider(color: outlineVariant),
                        ListTile(
                          leading: const Icon(Icons.add_circle, color: primaryContainer),
                          title: const Text(
                            'Agregar nueva dirección',
                            style: TextStyle(color: primaryContainer),
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
            child: const Text(
              'Cancelar',
              style: TextStyle(color: onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  // ========== ENVÍO DEL FORMULARIO ==========

  Future<void> _handleSubmit() async {
    // Validar campos del formulario
    if (!_formKey.currentState!.validate()) return;

    // Validar vehículo
    if (_selectedVehiculoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar un vehículo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validar dirección
    if (_selectedDireccionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar una dirección de entrega'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado');

      // TODO: Subir imagen a Supabase Storage y obtener URL pública
      String? fotoUrl;
      if (_selectedImage != null) {
        // fotoUrl = await _uploadImageToStorage(_selectedImage!);
        fotoUrl = _selectedImage!.path; // Placeholder
      }

      await _solicitudService.crearSolicitud(
        clienteId: user.id,
        vehiculoId: _selectedVehiculoId!,
        piezaNombre: _piezaNombreController.text,
        descripcion: _descriptionController.text,
        fotoUrl: fotoUrl,
        vinBusqueda: _vinController.text.isNotEmpty ? _vinController.text : null,
        direccionEntregaId: _selectedDireccionId!,
        esUrgente: false,
      );

      setState(() => _isSubmitting = false);

      if (mounted) {
        // Diálogo de éxito
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: surfaceContainerHigh,
            title: const Text(
              '¡Solicitud Enviada!',
              style: TextStyle(color: onSurface),
            ),
            content: const Text(
              'Tu solicitud ha sido enviada a nuestra red de proveedores. '
              'Te notificaremos cuando reciban ofertas.',
              style: TextStyle(color: onSurfaceVariant),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar diálogo
                  Navigator.pop(context); // Volver a Home
                },
                child: const Text('OK', style: TextStyle(color: primaryContainer)),
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ========== BUILD ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: surfaceContainerHigh,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Crear Solicitud',
          style: TextStyle(color: primary, fontSize: 22, fontWeight: FontWeight.w600),
        ),
        actions: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: outlineVariant),
            ),
            child: const ClipOval(
              child: Icon(Icons.person, color: onSurfaceVariant),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NUEVA BÚSQUEDA',
                    style: TextStyle(
                      fontSize: 12,
                      color: onSurfaceVariant,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '¿Qué pieza necesitas?',
                    style: TextStyle(
                      fontSize: 24,
                      color: onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Imagen
              GestureDetector(
                onTap: _isUploading ? null : _pickImage,
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryContainer,
                      width: 2,
                      style: _selectedImage == null ? BorderStyle.solid : BorderStyle.none,
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: _isUploading
                      ? const Column(
                          children: [
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                valueColor: AlwaysStoppedAnimation<Color>(primaryContainer),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text('Procesando imagen...', style: TextStyle(color: primaryContainer)),
                          ],
                        )
                      : _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  Image.file(
                                    _selectedImage!,
                                    width: double.infinity,
                                    height: 128,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.4),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.edit, color: Colors.white, size: 32),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: primaryContainer.withOpacity(0.1),
                                  ),
                                  child: const Icon(
                                    Icons.photo_camera,
                                    size: 32,
                                    color: primaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Subir foto del repuesto o VIN',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Formatos aceptados: JPG, PNG • Max 10MB',
                                  style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 24),

              // Nombre del repuesto
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
              const SizedBox(height: 16),

              // Vehículo
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Selecciona tu vehículo',
                          style: TextStyle(fontSize: 12, color: onSurfaceVariant, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: ' *',
                          style: TextStyle(fontSize: 12, color: requiredAsterisk, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: outlineVariant),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButtonFormField<String>(
                        value: _selectedVehiculoId,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: InputBorder.none,
                        ),
                        dropdownColor: surfaceContainerHigh,
                        style: const TextStyle(color: onSurface),
                        icon: const Icon(Icons.expand_more, color: onSurfaceVariant),
                        items: _isLoadingVehiculos
                            ? [const DropdownMenuItem(value: null, child: Text('Cargando vehículos...'))]
                            : _vehiculos.isEmpty
                                ? [const DropdownMenuItem(value: null, child: Text('No hay vehículos registrados'))]
                                : _vehiculos.map((vehiculo) {
                                    final modelo = vehiculo['modelos_vehiculo'] as Map<String, dynamic>?;
                                    final marca = modelo?['marcas_vehiculo'] as Map<String, dynamic>?;
                                    final vin = vehiculo['vin'] as String? ?? '';
                                    final nombre = marca != null && modelo != null
                                        ? '${marca['nombre']} ${modelo['nombre']}'
                                        : 'Vehículo';
                                    return DropdownMenuItem(
                                      value: vehiculo['id'] as String?,
                                      child: Text('$nombre (VIN: ${vin.length > 4 ? '...${vin.substring(vin.length - 4)}' : vin})'),
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
              ),
              const SizedBox(height: 16),

              // Descripción
              _buildTextField(
                label: 'Descripción del repuesto',
                controller: _descriptionController,
                hint: 'Ej: Amortiguador delantero derecho, marca original o equivalente de alta calidad...',
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
              const SizedBox(height: 16),

              // VIN opcional
              _buildTextField(
                label: 'Código VIN (opcional)',
                controller: _vinController,
                hint: 'Ej: 1HGBH41JXMN109186',
                validator: null,
              ),
              const SizedBox(height: 16),

              // Ubicación de entrega
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: outlineVariant.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: secondaryContainer.withOpacity(0.2),
                      ),
                      child: const Icon(Icons.location_on, color: secondaryContainer),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ubicación de entrega',
                            style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                          ),
                          Text(
                            _locationController.text,
                            style: const TextStyle(fontSize: 14, color: onSurface, fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _changeLocation,
                      child: const Text(
                        'Cambiar',
                        style: TextStyle(fontSize: 12, color: secondaryContainer, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Consejo Pro
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surfaceContainerLow.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info, color: tertiaryContainer, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Consejo Pro',
                            style: TextStyle(fontSize: 18, color: tertiaryContainer, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Incluir el código VIN (Número de Chasis) garantiza una compatibilidad del 100% con tu motorización específica.',
                            style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background.withOpacity(0.8),
          border: Border(top: BorderSide(color: outlineVariant)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryContainer,
              foregroundColor: onPrimaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(onPrimaryContainer),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search),
                      SizedBox(width: 8),
                      Text('BUSCAR REPUESTO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // Widget helper para campos de texto
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool isRequired = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label,
                style: const TextStyle(fontSize: 12, color: onSurfaceVariant, fontWeight: FontWeight.bold),
              ),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(fontSize: 12, color: requiredAsterisk, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: surfaceContainerHigh,
            hintText: hint,
            hintStyle: const TextStyle(color: onSurfaceVariant),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: primaryContainer, width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}