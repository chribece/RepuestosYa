import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/vehiculo_service.dart';
import '../services/marca_service.dart';
import '../services/modelo_service.dart';
import '../widgets/ry_text_field.dart';
import '../widgets/ry_state_container.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_logger.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final VehiculoService _vehiculoService = VehiculoService();

  List<Map<String, dynamic>> _vehiculos = [];
  bool _isLoading = false;

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
      AppLogger.error(
        'Error al cargar vehículos',
        name: '_VehiclesPageState',
        error: e,
      );
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
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text(
          'Eliminar vehículo',
          style: AppTextStyles.textStyleTitle,
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar este vehículo?',
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: AppTextStyles.textStyleButton.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Eliminar',
              style: AppTextStyles.textStyleButton.copyWith(
                color: AppColors.error,
              ),
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
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar vehículo: $e'),
              backgroundColor: AppColors.error,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mis Vehículos', style: AppTextStyles.textStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primaryContainer),
            onPressed: () => _mostrarFormularioVehiculo(),
          ),
        ],
      ),
      body: _isLoading
          ? const RyStateContainer(
              title: 'Cargando vehículos...',
              type: RyStateType.loading,
            )
          : _vehiculos.isEmpty
          ? const RyStateContainer(
              title: 'Sin vehículos',
              subtitle:
                  'No tienes vehículos registrados. Agrega tu primer vehículo.',
              type: RyStateType.empty,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.spacingMd),
              itemCount: _vehiculos.length,
              itemBuilder: (context, index) {
                final vehiculo = _vehiculos[index];
                final modelo =
                    vehiculo['modelos_vehiculo'] as Map<String, dynamic>?;
                final marca =
                    modelo?['marcas_vehiculo'] as Map<String, dynamic>?;
                final vin = vehiculo['vin'] as String? ?? '';
                final anioRaw = vehiculo['anio'];
                final anio = anioRaw?.toString();
                final patente = vehiculo['placa'] as String?;

                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
                  padding: const EdgeInsets.all(AppSpacing.spacingMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppRadius.radiusMd,
                          ),
                        ),
                        child: const Icon(
                          Icons.directions_car,
                          color: AppColors.primaryContainer,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              marca != null && modelo != null
                                  ? '${marca['nombre']} ${modelo['nombre']}'
                                  : 'Vehículo',
                              style: AppTextStyles.textStyleBody,
                            ),
                            const SizedBox(height: AppSpacing.spacingXs),
                            if (anio != null)
                              Text(
                                'Año: $anio',
                                style: AppTextStyles.textStyleCaption.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            if (patente != null && patente.isNotEmpty)
                              Text(
                                'Patente: $patente',
                                style: AppTextStyles.textStyleCaption.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            Text(
                              'VIN: ${vin.length > 4 ? '...${vin.substring(vin.length - 4)}' : vin}',
                              style: AppTextStyles.textStyleCaption.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.spacingSm),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: AppColors.primary,
                            ),
                            onPressed: () =>
                                _mostrarFormularioVehiculo(vehiculo),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: AppColors.error,
                            ),
                            onPressed: () => _eliminarVehiculo(vehiculo['id']),
                          ),
                        ],
                      ),
                    ],
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

  const VehicleFormDialog({super.key, this.vehiculo, required this.onSave});

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
        final modelo =
            widget.vehiculo!['modelos_vehiculo'] as Map<String, dynamic>?;
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
        AppLogger.error(
          'Error al extraer marca/modelo del vehículo',
          name: '_VehicleFormDialogState',
          error: e,
        );
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
      AppLogger.error(
        'Error al cargar marcas',
        name: '_VehicleFormDialogState',
        error: e,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar marcas: $e'),
            backgroundColor: AppColors.error,
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
      AppLogger.error(
        'Error al cargar modelos',
        name: '_VehicleFormDialogState',
        error: e,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar modelos: $e'),
            backgroundColor: AppColors.error,
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
            backgroundColor: AppColors.error,
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
            patente: _patenteController.text.isNotEmpty
                ? _patenteController.text
                : null,
          );
        } else {
          // Crear
          await vehiculoService.createVehiculo(
            marcaId: _selectedMarcaId!,
            modeloId: _selectedModeloId!,
            vin: _vinController.text.isNotEmpty ? _vinController.text : null,
            anio: _anioController.text.isNotEmpty ? _anioController.text : null,
            patente: _patenteController.text.isNotEmpty
                ? _patenteController.text
                : null,
          );
        }

        if (mounted) {
          Navigator.pop(context);
          widget.onSave();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.vehiculo != null
                    ? 'Vehículo actualizado'
                    : 'Vehículo creado',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerHigh,
      title: Text(
        widget.vehiculo != null ? 'Editar Vehículo' : 'Agregar Vehículo',
        style: AppTextStyles.textStyleTitle,
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
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Marca',
                            style: AppTextStyles.textStyleCaption.copyWith(
                              color: AppColors.onSurfaceVariant,
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
                    const SizedBox(height: AppSpacing.spacingSm),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: _isLoadingMarcas
                          ? const Padding(
                              padding: EdgeInsets.all(AppSpacing.spacingMd),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryContainer,
                                  ),
                                ),
                              ),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedMarcaId,
                                isExpanded: true,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.spacingSm,
                                ),
                                dropdownColor: AppColors.surfaceContainerHigh,
                                style: AppTextStyles.textStyleBody,
                                icon: const Icon(
                                  Icons.expand_more,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                hint: Text(
                                  'Selecciona una marca',
                                  style: AppTextStyles.textStyleCaption
                                      .copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                ),
                                items: _marcas
                                    .where((marca) {
                                      final id = marca['id'];
                                      return id != null &&
                                          int.tryParse(id.toString()) != null;
                                    })
                                    .map((marca) {
                                      final idInt = int.parse(
                                        marca['id'].toString(),
                                      );
                                      return DropdownMenuItem<int>(
                                        value: idInt,
                                        child: Text(
                                          marca['nombre']?.toString() ?? '',
                                        ),
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
                const SizedBox(height: AppSpacing.spacingMd),

                // Dropdown de Modelo
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Modelo',
                            style: AppTextStyles.textStyleCaption.copyWith(
                              color: AppColors.onSurfaceVariant,
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
                    const SizedBox(height: AppSpacing.spacingSm),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: _isLoadingModelos
                          ? const Padding(
                              padding: EdgeInsets.all(AppSpacing.spacingMd),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryContainer,
                                  ),
                                ),
                              ),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedModeloId,
                                isExpanded: true,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.spacingSm,
                                ),
                                dropdownColor: AppColors.surfaceContainerHigh,
                                style: AppTextStyles.textStyleBody,
                                icon: const Icon(
                                  Icons.expand_more,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                hint: Text(
                                  _selectedMarcaId == null
                                      ? 'Selecciona primero una marca'
                                      : 'Selecciona un modelo',
                                  style: AppTextStyles.textStyleCaption
                                      .copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                ),
                                items: _modelos
                                    .where((modelo) {
                                      final id = modelo['id'];
                                      return id != null &&
                                          int.tryParse(id.toString()) != null;
                                    })
                                    .map((modelo) {
                                      final idInt = int.parse(
                                        modelo['id'].toString(),
                                      );
                                      return DropdownMenuItem<int>(
                                        value: idInt,
                                        child: Text(
                                          modelo['nombre']?.toString() ?? '',
                                        ),
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
                const SizedBox(height: AppSpacing.spacingMd),
                RyTextField(
                  label: 'Número VIN (Chasis)',
                  controller: _vinController,
                  isRequired: true,
                  helperText: 'Debe tener 17 caracteres',
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                RyTextField(
                  label: 'Año',
                  controller: _anioController,
                  type: RyTextFieldType.number,
                  isRequired: true,
                  helperText: 'Debe estar entre 1900 y el año actual + 1',
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                RyTextField(
                  label: 'Placa (opcional)',
                  controller: _patenteController,
                ),
              ],
            ),
          ),
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
        ElevatedButton(
          onPressed: _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: AppColors.onPrimaryContainer,
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
