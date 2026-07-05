import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/solicitud_service.dart';
import '../services/auth_service.dart';
import '../services/vehiculo_service.dart';
import '../services/direccion_service.dart';
import '../providers/user_role_provider.dart';

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
  final _locationController = TextEditingController(text: 'Av. Libertador 4500, Palermo, CABA');
  
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

  // Color scheme from HTML
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

  Future<void> _cargarVehiculos() async {
    setState(() {
      _isLoadingVehiculos = true;
    });

    try {
      final vehiculos = await _vehiculoService.getVehiculos();
      setState(() {
        _vehiculos = vehiculos;
        // Seleccionar la dirección principal por defecto
        if (_direcciones.isNotEmpty) {
          _selectedDireccionId = _direcciones.first['id'] as String?;
        }
      });
    } catch (e) {
      print('Error al cargar vehículos: $e');
    } finally {
      setState(() {
        _isLoadingVehiculos = false;
      });
    }
  }

  Future<void> _cargarDirecciones() async {
    setState(() {
      _isLoadingDirecciones = true;
    });

    try {
      final direcciones = await _direccionService.getDirecciones();
      setState(() {
        _direcciones = direcciones;
        // Seleccionar la dirección principal por defecto
        final direccionPrincipal = direcciones.firstWhere(
          (d) => d['es_principal'] == true,
          orElse: () => direcciones.isNotEmpty ? direcciones.first : {},
        );
        if (direccionPrincipal.isNotEmpty) {
          _selectedDireccionId = direccionPrincipal['id'] as String?;
          _locationController.text = _formatDireccion(direccionPrincipal);
        }
      });
    } catch (e) {
      print('Error al cargar direcciones: $e');
    } finally {
      setState(() {
        _isLoadingDirecciones = false;
      });
    }
  }

  String _formatDireccion(Map<String, dynamic> direccion) {
    final calle = direccion['calle'] as String? ?? '';
    final numero = direccion['numero'] as String? ?? '';
    final departamento = direccion['departamento'] as String?;
    final ciudad = direccion['ciudad'] as String? ?? '';
    final provincia = direccion['provincia'] as String? ?? '';
    
    String direccionText = '$calle $numero';
    if (departamento != null && departamento.isNotEmpty) {
      direccionText += ', Depto $departamento';
    }
    if (ciudad.isNotEmpty) {
      direccionText += ', $ciudad';
    }
    if (provincia.isNotEmpty) {
      direccionText += ', $provincia';
    }
    return direccionText;
  }

  Future<void> _pickImage() async {
    // Mostrar diálogo para elegir entre cámara y galería
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceContainerHigh,
        title: const Text(
          'Seleccionar imagen',
          style: TextStyle(color: onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: primaryContainer),
              title: const Text(
                'Cámara',
                style: TextStyle(color: onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: primaryContainer),
              title: const Text(
                'Galería',
                style: TextStyle(color: onSurface),
              ),
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
        setState(() {
          _isUploading = true;
        });

        // Simulate upload delay
        await Future.delayed(const Duration(milliseconds: 1500));

        setState(() {
          _selectedImage = File(image.path);
          _isUploading = false;
        });

        _showToast('Imagen cargada con éxito');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar imagen: $e'),
          backgroundColor: Colors.red,
        ),
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

  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        // Obtener el usuario autenticado
        final user = _authService.currentUser;
        if (user == null) {
          throw Exception('No hay usuario autenticado');
        }

        // Crear la solicitud con los datos correctos
        await _solicitudService.crearSolicitud(
          clienteId: user.id,
          vehiculoId: _selectedVehiculoId,
          piezaNombre: _piezaNombreController.text,
          descripcion: _descriptionController.text,
          fotoUrl: _selectedImage?.path, // TODO: Subir imagen a Supabase Storage
          vinBusqueda: _vinController.text.isNotEmpty ? _vinController.text : null,
          direccionEntregaId: _selectedDireccionId,
          esUrgente: false,
        );

        setState(() {
          _isSubmitting = false;
        });

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: surfaceContainerHigh,
              title: const Text(
                'Solicitud Enviada',
                style: TextStyle(color: onSurface),
              ),
              content: const Text(
                'Tu solicitud ha sido enviada a nuestra red de proveedores.',
                style: TextStyle(color: onSurfaceVariant),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(color: primaryContainer),
                  ),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isSubmitting = false;
        });

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
  }

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
              ? const Center(
                  child: CircularProgressIndicator(color: primaryContainer),
                )
              : _direcciones.isEmpty
                  ? const Text(
                      'No tienes direcciones registradas',
                      style: TextStyle(color: onSurfaceVariant),
                    )
                  : ListView.builder(
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
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Cancelar',
              style: TextStyle(color: onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

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
          style: TextStyle(
            color: primary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
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
              // Section Header
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

              // Upload Area
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
                            Text(
                              'Procesando imagen...',
                              style: TextStyle(color: primaryContainer),
                            ),
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
                                        child: Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 32,
                                        ),
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 24),

              // Nombre del repuesto
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nombre del repuesto',
                    style: TextStyle(
                      fontSize: 12,
                      color: onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _piezaNombreController,
                    style: const TextStyle(color: onSurface),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: surfaceContainerHigh,
                      hintText: 'Ej: Filtro de aceite, Disco de freno...',
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa el nombre del repuesto';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Vehicle Selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecciona tu vehículo',
                    style: TextStyle(
                      fontSize: 12,
                      color: onSurfaceVariant,
                      fontWeight: FontWeight.bold,
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
                                    final modelo = vehiculo['modelos_vehiculo'] as Map<String, dynamic>?;
                                    final marca = modelo?['marcas_vehiculo'] as Map<String, dynamic>?;
                                    final vin = vehiculo['vin'] as String? ?? '';
                                    final nombreVehiculo = marca != null && modelo != null
                                        ? '${marca['nombre']} ${modelo['nombre']}'
                                        : 'Vehículo';
                                    return DropdownMenuItem(
                                      value: vehiculo['id'] as String?,
                                      child: Text('$nombreVehiculo (VIN: ${vin.length > 4 ? '...${vin.substring(vin.length - 4)}' : vin})'),
                                    );
                                  }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedVehiculoId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor selecciona un vehículo';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description Text Area
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Descripción del repuesto',
                    style: TextStyle(
                      fontSize: 12,
                      color: onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: const TextStyle(color: onSurface),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: surfaceContainerHigh,
                      hintText: 'Ej: Amortiguador delantero derecho, marca original o equivalente de alta calidad...',
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa una descripción';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // VIN Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Código VIN (opcional)',
                    style: TextStyle(
                      fontSize: 12,
                      color: onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _vinController,
                    style: const TextStyle(color: onSurface),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: surfaceContainerHigh,
                      hintText: 'Ej: 1HGBH41JXMN109186',
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
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location Row
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
                      child: const Icon(
                        Icons.location_on,
                        color: secondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ubicación de entrega',
                            style: TextStyle(
                              fontSize: 12,
                              color: onSurfaceVariant,
                            ),
                          ),
                          Text(
                            _locationController.text,
                            style: const TextStyle(
                              fontSize: 14,
                              color: onSurface,
                              fontWeight: FontWeight.w500,
                            ),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Technical Specs / Guidance
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
                    const Icon(
                      Icons.info,
                      color: tertiaryContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Consejo Pro',
                            style: TextStyle(
                              fontSize: 18,
                              color: tertiaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Incluir el código VIN (Número de Chasis) garantiza una compatibilidad del 100% con tu motorización específica.',
                            style: TextStyle(
                              fontSize: 12,
                              color: onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100), // Space for bottom button
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              shadowColor: primaryContainer.withOpacity(0.2),
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
                      Text(
                        'BUSCAR REPUESTO',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
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
