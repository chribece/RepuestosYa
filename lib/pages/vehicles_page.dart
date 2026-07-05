import 'package:flutter/material.dart';
import '../services/vehiculo_service.dart';
import '../services/auth_service.dart';
import '../services/marca_service.dart';
import '../services/modelo_service.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final VehiculoService _vehiculoService = VehiculoService();
  final AuthService _authService = AuthService();
  
  List<Map<String, dynamic>> _vehiculos = [];
  bool _isLoading = false;

  // Color scheme
  static const Color primary = Color(0xFFFFB5A0);
  static const Color primaryContainer = Color(0xFFFF5722);
  static const Color onPrimaryContainer = Color(0xFF541200);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color outlineVariant = Color(0xFF5B4039);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFE4BEB4);
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF131313);
  static const Color error = Color(0xFFFF1744);

  @override
  void initState() {
    super.initState();
    _cargarVehiculos();
  }

  Future<void> _cargarVehiculos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final vehiculos = await _vehiculoService.getVehiculos();
      setState(() {
        _vehiculos = vehiculos;
      });
    } catch (e) {
      print('Error al cargar vehículos: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _eliminarVehiculo(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceContainerHigh,
        title: const Text(
          'Eliminar vehículo',
          style: TextStyle(color: onSurface),
        ),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este vehículo?',
          style: TextStyle(color: onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _vehiculoService.deleteVehiculo(id);
        _cargarVehiculos();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehículo eliminado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar vehículo: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _mostrarFormularioVehiculo([Map<String, dynamic>? vehiculo]) {
    showDialog(
      context: context,
      builder: (context) => VehicleFormDialog(
        vehiculo: vehiculo,
        onSave: () {
          _cargarVehiculos();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mis Vehículos',
          style: TextStyle(
            color: primaryContainer,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: primaryContainer),
            onPressed: () => _mostrarFormularioVehiculo(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryContainer),
            )
          : _vehiculos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_car,
                        size: 64,
                        color: onSurfaceVariant.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes vehículos registrados',
                        style: TextStyle(
                          color: onSurfaceVariant,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Agrega tu primer vehículo',
                        style: TextStyle(
                          color: onSurfaceVariant.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _vehiculos.length,
                  itemBuilder: (context, index) {
                    final vehiculo = _vehiculos[index];
                    final modelo = vehiculo['modelos_vehiculo'] as Map<String, dynamic>?;
                    final marca = modelo?['marcas_vehiculo'] as Map<String, dynamic>?;
                    final vin = vehiculo['vin'] as String? ?? '';
                    final anioRaw = vehiculo['anio'];
    final anio = anioRaw != null ? anioRaw.toString() : null;
                    final patente = vehiculo['placa'] as String?;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: outlineVariant),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: primaryContainer.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.directions_car,
                            color: primaryContainer,
                            size: 32,
                          ),
                        ),
                        title: Text(
                          marca != null && modelo != null
                              ? '${marca['nombre']} ${modelo['nombre']}'
                              : 'Vehículo',
                          style: const TextStyle(
                            color: onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (anio != null)
                              Text(
                                'Año: $anio',
                                style: TextStyle(
                                  color: onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            if (patente != null && patente.isNotEmpty)
                              Text(
                                'Patente: $patente',
                                style: TextStyle(
                                  color: onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            Text(
                              'VIN: ${vin.length > 4 ? '...${vin.substring(vin.length - 4)}' : vin}',
                              style: TextStyle(
                                color: onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: primary),
                              onPressed: () => _mostrarFormularioVehiculo(vehiculo),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: error),
                              onPressed: () => _eliminarVehiculo(vehiculo['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class VehicleFormDialog extends StatefulWidget {
  final Map<String, dynamic>? vehiculo;
  final VoidCallback onSave;

  const VehicleFormDialog({
    super.key,
    this.vehiculo,
    required this.onSave,
  });

  @override
  State<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _vinController = TextEditingController();
  final _anioController = TextEditingController();
  final _patenteController = TextEditingController();

  final MarcaService _marcaService = MarcaService();
  final ModeloService _modeloService = ModeloService();

  List<Map<String, dynamic>> _marcas = [];
  List<Map<String, dynamic>> _modelos = [];
  int? _selectedMarcaId;
  int? _selectedModeloId;
  bool _isLoadingMarcas = false;
  bool _isLoadingModelos = false;

  // Color scheme
  static const Color primary = Color(0xFFFFB5A0);
  static const Color primaryContainer = Color(0xFFFF5722);
  static const Color onPrimaryContainer = Color(0xFF541200);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color outlineVariant = Color(0xFF5B4039);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFE4BEB4);

  @override
  void initState() {
    super.initState();
    _cargarMarcas();
    
    if (widget.vehiculo != null) {
      _vinController.text = widget.vehiculo!['vin'] ?? '';
      _anioController.text = widget.vehiculo!['anio']?.toString() ?? '';
      _patenteController.text = widget.vehiculo!['placa'] ?? '';
      
      // Extraer marca y modelo del vehículo existente
      try {
        final modelo = widget.vehiculo!['modelos_vehiculo'] as Map<String, dynamic>?;
        if (modelo != null) {
          final modeloId = modelo['id'];
          if (modeloId != null) {
            _selectedModeloId = int.tryParse(modeloId.toString());
          }
          final marca = modelo['marcas_vehiculo'] as Map<String, dynamic>?;
          if (marca != null) {
            final marcaId = marca['id'];
            if (marcaId != null) {
              final marcaIdInt = int.tryParse(marcaId.toString());
              _selectedMarcaId = marcaIdInt;
              if (marcaIdInt != null) {
                _cargarModelos(marcaIdInt);
              }
            }
          }
        }
      } catch (e) {
        print('Error al extraer marca/modelo del vehículo: $e');
      }
    }
  }

  @override
  void dispose() {
    _vinController.dispose();
    _anioController.dispose();
    _patenteController.dispose();
    super.dispose();
  }

  Future<void> _cargarMarcas() async {
    setState(() {
      _isLoadingMarcas = true;
    });

    try {
      final marcas = await _marcaService.getMarcas();
      setState(() {
        _marcas = marcas;
      });
    } catch (e) {
      print('Error al cargar marcas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar marcas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingMarcas = false;
      });
    }
  }

  Future<void> _cargarModelos(int marcaId) async {
    setState(() {
      _isLoadingModelos = true;
      _modelos = [];
      _selectedModeloId = null; // Resetear modelo al cambiar marca
    });

    try {
      final modelos = await _modeloService.getModelosPorMarca(marcaId);
      setState(() {
        _modelos = modelos;
      });
    } catch (e) {
      print('Error al cargar modelos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar modelos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingModelos = false;
      });
    }
  }

  Future<void> _guardar() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedMarcaId == null || _selectedModeloId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor selecciona marca y modelo'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        final vehiculoService = VehiculoService();
        
        if (widget.vehiculo != null) {
          // Actualizar
          await vehiculoService.updateVehiculo(
            id: widget.vehiculo!['id'],
            marcaId: _selectedMarcaId,
            modeloId: _selectedModeloId,
            vin: _vinController.text.isNotEmpty ? _vinController.text : null,
            anio: _anioController.text.isNotEmpty ? _anioController.text : null,
            patente: _patenteController.text.isNotEmpty ? _patenteController.text : null,
          );
        } else {
          // Crear
          await vehiculoService.createVehiculo(
            marcaId: _selectedMarcaId!,
            modeloId: _selectedModeloId!,
            vin: _vinController.text.isNotEmpty ? _vinController.text : null,
            anio: _anioController.text.isNotEmpty ? _anioController.text : null,
            patente: _patenteController.text.isNotEmpty ? _patenteController.text : null,
          );
        }

        if (mounted) {
          Navigator.pop(context);
          widget.onSave();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.vehiculo != null ? 'Vehículo actualizado' : 'Vehículo creado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: surfaceContainerHigh,
      title: Text(
        widget.vehiculo != null ? 'Editar Vehículo' : 'Agregar Vehículo',
        style: const TextStyle(color: onSurface),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dropdown de Marca
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Marca',
                      style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: onSurfaceVariant.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: outlineVariant),
                      ),
                      child: _isLoadingMarcas
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primaryContainer,
                                  ),
                                ),
                              ),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedMarcaId,
                                isExpanded: true,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                dropdownColor: surfaceContainerHigh,
                                style: const TextStyle(color: onSurface),
                                icon: const Icon(Icons.expand_more, color: onSurfaceVariant),
                                hint: const Text(
                                  'Selecciona una marca',
                                  style: TextStyle(color: onSurfaceVariant),
                                ),
                                items: _marcas
                                    .where((marca) {
                                      final id = marca['id'];
                                      return id != null && int.tryParse(id.toString()) != null;
                                    })
                                    .map((marca) {
                                      final idInt = int.parse(marca['id'].toString());
                                      return DropdownMenuItem<int>(
                                        value: idInt,
                                        child: Text(marca['nombre']?.toString() ?? ''),
                                      );
                                    })
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedMarcaId = value;
                                    });
                                    _cargarModelos(value);
                                  }
                                },
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Dropdown de Modelo
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Modelo',
                      style: TextStyle(color: onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: onSurfaceVariant.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: outlineVariant),
                      ),
                      child: _isLoadingModelos
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: primaryContainer,
                                  ),
                                ),
                              ),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedModeloId,
                                isExpanded: true,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                dropdownColor: surfaceContainerHigh,
                                style: const TextStyle(color: onSurface),
                                icon: const Icon(Icons.expand_more, color: onSurfaceVariant),
                                hint: Text(
                                  _selectedMarcaId == null 
                                      ? 'Selecciona primero una marca'
                                      : 'Selecciona un modelo',
                                  style: const TextStyle(color: onSurfaceVariant),
                                ),
                                items: _modelos
                                    .where((modelo) {
                                      final id = modelo['id'];
                                      return id != null && int.tryParse(id.toString()) != null;
                                    })
                                    .map((modelo) {
                                      final idInt = int.parse(modelo['id'].toString());
                                      return DropdownMenuItem<int>(
                                        value: idInt,
                                        child: Text(modelo['nombre']?.toString() ?? ''),
                                      );
                                    })
                                    .toList(),
                                onChanged: _selectedMarcaId == null
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _selectedModeloId = value;
                                        });
                                      },
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _vinController,
                  style: const TextStyle(color: onSurface),
                  decoration: InputDecoration(
                    labelText: 'Número VIN (Chasis)',
                    labelStyle: const TextStyle(color: onSurfaceVariant),
                    filled: true,
                    fillColor: onSurfaceVariant.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: outlineVariant),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _anioController,
                  style: const TextStyle(color: onSurface),
                  decoration: InputDecoration(
                    labelText: 'Año',
                    labelStyle: const TextStyle(color: onSurfaceVariant),
                    filled: true,
                    fillColor: onSurfaceVariant.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: outlineVariant),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _patenteController,
                  style: const TextStyle(color: onSurface),
                  decoration: InputDecoration(
                    labelText: 'Placa (opcional)',
                    labelStyle: const TextStyle(color: onSurfaceVariant),
                    filled: true,
                    fillColor: onSurfaceVariant.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: outlineVariant),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        ElevatedButton(
          onPressed: _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryContainer,
            foregroundColor: onPrimaryContainer,
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
