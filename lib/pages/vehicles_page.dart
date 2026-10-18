import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../services/vehiculo_service.dart';
import '../services/marca_service.dart';
import '../services/modelo_service.dart';
import '../widgets/ry_text_field.dart';
import '../widgets/ry_state_container.dart';
import '../widgets/ry_form_dialog.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import '../utils/ry_snackbar.dart';

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
          GFButton(
            onPressed: () => Navigator.pop(context, false),
            type: GFButtonType.transparent,
            color: Colors.transparent,
            textColor: AppColors.onSurfaceVariant,
            size: 48,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spacingMd,
              vertical: AppSpacing.spacingSm,
            ),
            child: Text(
              'Cancelar',
              style: AppTextStyles.textStyleButton.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          GFButton(
            onPressed: () => Navigator.pop(context, true),
            type: GFButtonType.transparent,
            color: Colors.transparent,
            textColor: AppColors.error,
            size: 48,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spacingMd,
              vertical: AppSpacing.spacingSm,
            ),
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
          mostrarSnackbarExito(context, mensaje: 'Vehículo eliminado');
        }
      } catch (e) {
        if (mounted) {
          mostrarSnackbarError(
            context,
            mensaje:
                'Error al eliminar vehículo: '
                '${ApiErrorHandler.userMessage(e)}',
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
          tooltip: 'Regresar',
          onPressed: () => context.pop(),
        ),
        title: const Text('Mis Vehículos', style: AppTextStyles.textStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primaryContainer),
            tooltip: 'Agregar vehículo',
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
                            tooltip: 'Editar vehículo',
                            onPressed: () =>
                                _mostrarFormularioVehiculo(vehiculo),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: AppColors.error,
                            ),
                            tooltip: 'Eliminar vehículo',
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
  final MarcaService? marcaService;
  final ModeloService? modeloService;
  final VehiculoService? vehiculoService;

  const VehicleFormDialog({
    super.key,
    this.vehiculo,
    required this.onSave,
    this.marcaService,
    this.modeloService,
    this.vehiculoService,
  });

  @override
  State<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _selectionFieldKey = GlobalKey<FormFieldState<int>>();
  final _vinController = TextEditingController();
  final _anioController = TextEditingController();
  final _patenteController = TextEditingController();

  late final MarcaService _marcaService = widget.marcaService ?? MarcaService();
  late final ModeloService _modeloService =
      widget.modeloService ?? ModeloService();
  late final VehiculoService _vehiculoService =
      widget.vehiculoService ?? VehiculoService();

  List<Map<String, dynamic>> _marcas = [];
  List<Map<String, dynamic>> _modelos = [];
  int? _selectedMarcaId;
  int? _selectedModeloId;
  int? _initialModeloId;
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
            _initialModeloId = int.tryParse(modeloId.toString());
            _selectedModeloId = _initialModeloId;
          }
          final marca = modelo['marcas_vehiculo'] as Map<String, dynamic>?;
          if (marca != null) {
            final marcaId = marca['id'];
            if (marcaId != null) {
              final marcaIdInt = int.tryParse(marcaId.toString());
              _selectedMarcaId = marcaIdInt;
              if (marcaIdInt != null) {
                _cargarModelos(marcaIdInt, modeloInicial: _initialModeloId);
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
      if (!mounted) return;
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
        mostrarSnackbarError(
          context,
          mensaje:
              'Error al cargar marcas: '
              '${ApiErrorHandler.userMessage(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMarcas = false);
    }
  }

  Future<void> _cargarModelos(int marcaId, {int? modeloInicial}) async {
    setState(() {
      _isLoadingModelos = true;
      _modelos = [];
      _selectedModeloId = null;
    });

    try {
      final modelos = await _modeloService.getModelosPorMarca(marcaId);
      if (!mounted) return;
      setState(() {
        _modelos = modelos;
        // A retired model stays unselected; the dropdown presents its hint.
        _selectedModeloId =
            modeloInicial != null &&
                _modeloExisteParaMarca(modelos, modeloInicial, marcaId)
            ? modeloInicial
            : null;
      });
    } catch (e) {
      AppLogger.error(
        'Error al cargar modelos',
        name: '_VehicleFormDialogState',
        error: e,
      );
      if (mounted) {
        mostrarSnackbarError(
          context,
          mensaje:
              'Error al cargar modelos: '
              '${ApiErrorHandler.userMessage(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingModelos = false);
    }
  }

  bool _modeloExisteParaMarca(
    List<Map<String, dynamic>> modelos,
    int modeloId,
    int marcaId,
  ) {
    return modelos.any((modelo) {
      final id = int.tryParse(modelo['id']?.toString() ?? '');
      final marca = modelo['marcas_vehiculo'] as Map<String, dynamic>?;
      final modeloMarcaId =
          modelo['marca_id'] ?? modelo['marcaId'] ?? marca?['id'];
      final perteneceMarca =
          modeloMarcaId == null ||
          int.tryParse(modeloMarcaId.toString()) == marcaId;
      return id == modeloId && perteneceMarca;
    });
  }

  bool get _seleccionMarcaModeloValida {
    final marcaId = _selectedMarcaId;
    final modeloId = _selectedModeloId;
    if (marcaId == null ||
        modeloId == null ||
        !_marcas.any(
          (marca) => int.tryParse(marca['id']?.toString() ?? '') == marcaId,
        )) {
      return false;
    }
    return _modeloExisteParaMarca(_modelos, modeloId, marcaId);
  }

  Future<void> _guardar() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (widget.vehiculo != null) {
          // Actualizar
          await _vehiculoService.updateVehiculo(
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
          await _vehiculoService.createVehiculo(
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
          mostrarSnackbarExito(
            context,
            mensaje: widget.vehiculo != null
                ? 'Vehículo actualizado'
                : 'Vehículo creado',
          );
        }
      } catch (e) {
        if (mounted) {
          mostrarSnackbarError(
            context,
            mensaje: ApiErrorHandler.userMessage(e),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RyFormDialog(
      title: widget.vehiculo != null ? 'Editar Vehículo' : 'Agregar Vehículo',
      content: Form(
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
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.1),
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
                      : GFDropdown<int>(
                          items: _marcas
                              .where((marca) {
                                final id = marca['id'];
                                return id != null &&
                                    int.tryParse(id.toString()) != null;
                              })
                              .map((marca) => int.parse(marca['id'].toString()))
                              .toSet() // Deduplicar
                              .map((id) {
                                final marca = _marcas.firstWhere(
                                  (m) => int.parse(m['id'].toString()) == id,
                                );
                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text(
                                    marca['nombre']?.toString() ?? '',
                                  ),
                                );
                              })
                              .toList(),
                          value:
                              _marcas.any(
                                (m) =>
                                    int.tryParse(m['id']?.toString() ?? '') ==
                                    _selectedMarcaId,
                              )
                              ? _selectedMarcaId
                              : null,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedMarcaId = value;
                              });
                              if (_selectionFieldKey.currentState?.hasError ??
                                  false) {
                                _selectionFieldKey.currentState?.validate();
                              }
                              _cargarModelos(value);
                            }
                          },
                          dropdownButtonColor: Colors.transparent,
                          dropdownColor: AppColors.surfaceContainerHigh,
                          border: BorderSide(color: Colors.transparent),
                          borderRadius: BorderRadius.circular(
                            AppRadius.radiusSm,
                          ),
                          icon: const Icon(
                            Icons.expand_more,
                            color: AppColors.onSurfaceVariant,
                          ),
                          iconEnabledColor: AppColors.onSurfaceVariant,
                          iconDisabledColor: AppColors.onSurfaceVariant,
                          isExpanded: true,
                          style: AppTextStyles.textStyleBody,
                          hint: Text(
                            'Selecciona una marca',
                            style: AppTextStyles.textStyleCaption.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          underline: const SizedBox.shrink(),
                          itemHeight: 48,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.spacingSm,
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
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.1),
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
                      : GFDropdown<int>(
                          items: _modelos
                              .where((modelo) {
                                final id = modelo['id'];
                                return id != null &&
                                    int.tryParse(id.toString()) != null;
                              })
                              .map(
                                (modelo) => int.parse(modelo['id'].toString()),
                              )
                              .toSet() // Deduplicar
                              .map((id) {
                                final modelo = _modelos.firstWhere(
                                  (m) => int.parse(m['id'].toString()) == id,
                                );
                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text(
                                    modelo['nombre']?.toString() ?? '',
                                  ),
                                );
                              })
                              .toList(),
                          value: _seleccionMarcaModeloValida
                              ? _selectedModeloId
                              : null,
                          onChanged: _selectedMarcaId == null
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedModeloId = value;
                                  });
                                  if (_selectionFieldKey
                                          .currentState
                                          ?.hasError ??
                                      false) {
                                    _selectionFieldKey.currentState?.validate();
                                  }
                                },
                          dropdownButtonColor: Colors.transparent,
                          dropdownColor: AppColors.surfaceContainerHigh,
                          border: BorderSide(color: Colors.transparent),
                          borderRadius: BorderRadius.circular(
                            AppRadius.radiusSm,
                          ),
                          icon: const Icon(
                            Icons.expand_more,
                            color: AppColors.onSurfaceVariant,
                          ),
                          iconEnabledColor: AppColors.onSurfaceVariant,
                          iconDisabledColor: AppColors.onSurfaceVariant,
                          isExpanded: true,
                          style: AppTextStyles.textStyleBody,
                          hint: Text(
                            _selectedMarcaId == null
                                ? 'Selecciona primero una marca'
                                : 'Selecciona un modelo',
                            style: AppTextStyles.textStyleCaption.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          underline: const SizedBox.shrink(),
                          itemHeight: 48,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.spacingSm,
                          ),
                        ),
                ),
              ],
            ),
            FormField<int>(
              key: _selectionFieldKey,
              validator: (_) => !_seleccionMarcaModeloValida
                  ? 'Por favor selecciona marca y modelo'
                  : null,
              builder: (field) => field.errorText == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.spacingXs),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          field.errorText!,
                          style: AppTextStyles.textStyleCaption.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            RyTextField(
              label: 'Número VIN (Chasis)',
              controller: _vinController,
              isRequired: true,
              helperText: 'Debe tener 17 caracteres',
              validator: (value) => value?.trim().length == 17
                  ? null
                  : 'Debe tener 17 caracteres',
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            RyTextField(
              label: 'Año',
              controller: _anioController,
              type: RyTextFieldType.number,
              isRequired: true,
              helperText: 'Debe estar entre 1900 y el año actual + 1',
              validator: (value) {
                final year = int.tryParse(value?.trim() ?? '');
                final latestAllowedYear = DateTime.now().year + 1;
                return year != null && year >= 1900 && year <= latestAllowedYear
                    ? null
                    : 'Debe estar entre 1900 y el año actual + 1';
              },
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            RyTextField(
              label: 'Placa (opcional)',
              controller: _patenteController,
            ),
          ],
        ),
      ),
      actions: [
        GFButton(
          onPressed: () => Navigator.pop(context),
          type: GFButtonType.transparent,
          color: Colors.transparent,
          textColor: AppColors.onSurfaceVariant,
          size: 48,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spacingMd,
            vertical: AppSpacing.spacingSm,
          ),
          child: Text(
            'Cancelar',
            style: AppTextStyles.textStyleButton.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        GFButton(
          onPressed: _guardar,
          type: GFButtonType.solid,
          color: AppColors.primaryContainer,
          textColor: AppColors.onPrimaryContainer,
          textStyle: AppTextStyles.textStyleButton.copyWith(
            color: AppColors.onPrimaryContainer,
          ),
          size: 48,
          borderShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spacingLg,
            vertical: AppSpacing.spacingSm,
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
