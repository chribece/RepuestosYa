import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
import '../utils/contact_launcher.dart';
import '../utils/ry_snackbar.dart';
import '../widgets/ry_button.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({
    super.key,
    this.vehiculoService,
    this.abrirFormularioInicial = false,
    this.marcaService,
    this.modeloService,
  });

  final VehiculoService? vehiculoService;
  final bool abrirFormularioInicial;
  final MarcaService? marcaService;
  final ModeloService? modeloService;

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  late final VehiculoService _vehiculoService =
      widget.vehiculoService ?? VehiculoService();

  List<Map<String, dynamic>> _vehiculos = [];
  bool _isLoading = false;
  bool _formularioInicialAbierto = false;

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
      if (widget.abrirFormularioInicial &&
          !_formularioInicialAbierto &&
          vehiculos.isEmpty) {
        _formularioInicialAbierto = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _mostrarFormularioVehiculo();
        });
      }
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

  Future<void> _eliminarVehiculo(Map<String, dynamic> vehiculo) async {
    final id = vehiculo['id']?.toString();
    if (id == null || id.isEmpty) return;

    final modelo = vehiculo['modelos_vehiculo'] as Map<String, dynamic>?;
    final marca = modelo?['marcas_vehiculo'] as Map<String, dynamic>?;
    final vehicleLabel = [marca?['nombre'], modelo?['nombre'], vehiculo['anio']]
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .join(' ');
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.80),
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          side: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        title: const Text(
          'Eliminar vehículo',
          style: AppTextStyles.textStyleTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vehicleLabel.isNotEmpty) ...[
              Text(
                vehicleLabel,
                style: AppTextStyles.textStyleBody.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.spacingSm),
            ],
            Text(
              '¿Estás seguro de que deseas eliminar este vehículo? '
              'Esta acción no se puede deshacer.',
              style: AppTextStyles.textStyleBody.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.spacingMd,
          AppSpacing.spacingXs,
          AppSpacing.spacingMd,
          AppSpacing.spacingMd,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.spacingSm,
                      ),
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingSm),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFFDC2626),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.spacingSm,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                      ),
                    ),
                    child: const Text(
                      'Eliminar',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
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
          mostrarSnackbarExitoSobrio(context, mensaje: 'Vehículo eliminado');
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
      barrierColor: Colors.black.withValues(alpha: 0.80),
      builder: (context) => VehicleFormDialog(
        vehiculo: vehiculo,
        vehiculoService: widget.vehiculoService,
        marcaService: widget.marcaService,
        modeloService: widget.modeloService,
        onSave: () {
          _cargarVehiculos();
        },
      ),
    );
  }

  Widget _botonAccionVehiculo({
    required IconData icon,
    required String tooltip,
    required Color colorIcono,
    required Color fondo,
    required Color borde,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borde),
            ),
            child: Icon(icon, color: colorIcono, size: 18),
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleVehiculo(Map<String, dynamic> vehiculo) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E22),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.radiusLg),
        ),
      ),
      isScrollControlled: true,
      builder: (context) => _DetalleVehiculoSheet(vehiculo: vehiculo),
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
          ? RyStateContainer(
              title: 'Sin vehículos',
              subtitle:
                  'No tienes vehículos registrados. Agrega tu primer vehículo.',
              type: RyStateType.empty,
              customIcon: Icons.directions_car_outlined,
              customIconColor: AppColors.primaryContainer.withValues(
                alpha: 0.85,
              ),
              customContent: SizedBox(
                width: double.infinity,
                child: RyButton(
                  label: 'Agregar mi primer vehículo',
                  icon: Icons.add,
                  variant: RyButtonVariant.primary,
                  size: RyButtonSize.large,
                  isFullWidth: true,
                  onPressed: () => _mostrarFormularioVehiculo(),
                ),
              ),
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
                final id = vehiculo['id']?.toString() ?? '';

                final detalleStyle = AppTextStyles.textStyleCaption.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
                  child: Material(
                    color: AppColors.surfaceContainerHigh,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                      side: BorderSide(color: AppColors.outlineVariant),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _mostrarDetalleVehiculo(vehiculo),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.spacingMd),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.radiusMd,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.directions_car,
                                    color: AppColors.primaryContainer,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.spacingMd),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        marca != null && modelo != null
                                            ? '${marca['nombre']} ${modelo['nombre']}'
                                            : 'Vehículo',
                                        style: AppTextStyles.textStyleBody
                                            .copyWith(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                      ),
                                      const SizedBox(
                                        height: AppSpacing.spacingXs,
                                      ),
                                      if (anio != null)
                                        Text('Año: $anio', style: detalleStyle),
                                      if (patente != null && patente.isNotEmpty)
                                        Text(
                                          'Placa: $patente',
                                          style: detalleStyle,
                                        ),
                                      Text(
                                        'VIN: ${vin.length >= 6 ? '...${vin.substring(vin.length - 6)}' : vin}',
                                        style: detalleStyle,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.spacingSm),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _botonAccionVehiculo(
                                      icon: Icons.edit_outlined,
                                      tooltip: 'Editar vehículo',
                                      colorIcono: Colors.white70,
                                      fondo: const Color(0xFF1E1E22),
                                      borde: Colors.white12,
                                      onPressed: () =>
                                          _mostrarFormularioVehiculo(vehiculo),
                                    ),
                                    const SizedBox(width: AppSpacing.spacingXs),
                                    _botonAccionVehiculo(
                                      icon: Icons.delete_outline,
                                      tooltip: 'Eliminar vehículo',
                                      colorIcono: const Color(0xFFEF4444),
                                      fondo: const Color(0x1AEF4444),
                                      borde: const Color(0x40EF4444),
                                      onPressed: () =>
                                          _eliminarVehiculo(vehiculo),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(
                          color: Colors.white10,
                          height: 20,
                          indent: AppSpacing.spacingMd,
                          endIndent: AppSpacing.spacingMd,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.spacingMd,
                            0,
                            AppSpacing.spacingMd,
                            AppSpacing.spacingMd,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              AppRadius.radiusMd,
                            ),
                            onTap: id.isEmpty
                                ? null
                                : () => context.push(
                                    '/request/create?vehiculoId=${Uri.encodeQueryComponent(id)}',
                                  ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.spacingXs,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                    color: AppColors.primaryContainer,
                                  ),
                                  const SizedBox(width: AppSpacing.spacingSm),
                                  Expanded(
                                    child: Text(
                                      'Solicitar repuesto para este vehículo →',
                                      style: AppTextStyles.textStyleCaption
                                          .copyWith(
                                            color: AppColors.primaryContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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

class _DetalleVehiculoSheet extends StatefulWidget {
  const _DetalleVehiculoSheet({required this.vehiculo});

  final Map<String, dynamic> vehiculo;

  @override
  State<_DetalleVehiculoSheet> createState() => _DetalleVehiculoSheetState();
}

class _DetalleVehiculoSheetState extends State<_DetalleVehiculoSheet> {
  bool _vinCopiado = false;

  Future<void> _copiarVin(String vin) async {
    await Clipboard.setData(ClipboardData(text: vin));
    if (mounted) setState(() => _vinCopiado = true);
  }

  Widget _fila(String etiqueta, String valor, {bool seleccionable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.spacingXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              etiqueta,
              style: AppTextStyles.textStyleCaption.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: seleccionable
                ? SelectableText(
                    valor,
                    style: AppTextStyles.textStyleBody.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Text(
                    valor,
                    style: AppTextStyles.textStyleBody.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehiculo = widget.vehiculo;
    final modelo = vehiculo['modelos_vehiculo'] as Map<String, dynamic>?;
    final marca = modelo?['marcas_vehiculo'] as Map<String, dynamic>?;
    final vin = (vehiculo['vin'] as String? ?? '').trim();
    final placa = (vehiculo['placa'] as String? ?? '').trim();
    final anio = vehiculo['anio']?.toString() ?? '';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.radiusLg),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E22),
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.spacingLg,
                0,
                AppSpacing.spacingLg,
                AppSpacing.spacingLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Detalle del vehículo',
                    style: AppTextStyles.textStyleTitle.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spacingMd),
                  _fila('Marca', marca?['nombre']?.toString() ?? '—'),
                  _fila('Modelo', modelo?['nombre']?.toString() ?? '—'),
                  _fila('Año', anio.isEmpty ? '—' : anio),
                  _fila('Placa', placa.isEmpty ? '—' : placa),
                  _fila('VIN', vin.isEmpty ? '—' : vin, seleccionable: true),
                  const SizedBox(height: AppSpacing.spacingMd),
                  OutlinedButton.icon(
                    onPressed: vin.isEmpty ? null : () => _copiarVin(vin),
                    icon: Icon(
                      _vinCopiado ? Icons.check_rounded : Icons.copy_rounded,
                      size: 18,
                    ),
                    label: Text(_vinCopiado ? 'VIN copiado' : 'Copiar VIN'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpcionVehiculo {
  const _OpcionVehiculo({
    required this.marcaId,
    required this.marcaNombre,
    required this.modeloId,
    required this.modeloNombre,
  });

  static const solicitud = _OpcionVehiculo(
    marcaId: 0,
    marcaNombre: '',
    modeloId: 0,
    modeloNombre: '',
  );

  final int marcaId;
  final String marcaNombre;
  final int modeloId;
  final String modeloNombre;

  bool get esSolicitud => marcaId == 0;
  String get etiqueta => '$marcaNombre • $modeloNombre';
}

ThemeData _temaFormulario(ThemeData base) {
  OutlineInputBorder borde(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        borderSide: BorderSide(color: color, width: width),
      );
  return base.copyWith(
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: AppColors.inputFill,
      labelStyle: AppTextStyles.textStyleCaption.copyWith(
        color: AppColors.textMuted,
      ),
      hintStyle: AppTextStyles.textStyleCaption.copyWith(
        color: AppColors.textMuted,
      ),
      helperStyle: AppTextStyles.textStyleCaption.copyWith(
        color: Colors.white54,
      ),
      counterStyle: AppTextStyles.textStyleSmall.copyWith(
        color: Colors.white54,
      ),
      suffixIconColor: AppColors.textMuted,
      border: borde(Colors.white12),
      enabledBorder: borde(Colors.white12),
      focusedBorder: borde(AppColors.primaryContainer, width: 2),
    ),
  );
}

Widget _campoFormulario(
  String etiqueta,
  Widget campo, {
  bool requerido = false,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: etiqueta,
              style: AppTextStyles.textStyleCaption.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            if (requerido)
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
      campo,
    ],
  );
}

String? _validarRequerido(String? value) =>
    (value?.trim() ?? '').isEmpty ? 'Este campo es obligatorio.' : null;

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
  static final RegExp _vinPattern = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');
  static const String _vinValidationMessage =
      'VIN inválido: 17 caracteres, sin I, O ni Q.';
  static final RegExp _platePattern = RegExp(r'^[A-Z]{3}-?\d{3,4}$');

  final _formKey = GlobalKey<FormState>();
  final _selectionFieldKey = GlobalKey<FormFieldState<int>>();
  final _busquedaController = TextEditingController();
  final _busquedaFocus = FocusNode();
  final _vinController = TextEditingController();
  final _patenteController = TextEditingController();

  late final MarcaService _marcaService = widget.marcaService ?? MarcaService();
  late final ModeloService _modeloService =
      widget.modeloService ?? ModeloService();
  late final VehiculoService _vehiculoService =
      widget.vehiculoService ?? VehiculoService();

  List<_OpcionVehiculo> _catalogo = [];
  _OpcionVehiculo? _seleccion;
  bool _isLoadingCatalogo = false;
  int? _anioSeleccionado;
  int? _initialMarcaId;
  int? _initialModeloId;
  int? _initialAnio;
  String _initialVin = '';
  String _initialPlaca = '';

  static const int _anioMinimo = 1900;
  int get _latestAllowedYear => DateTime.now().year + 1;
  List<int> get _anios => [
    for (var anio = _latestAllowedYear; anio >= _anioMinimo; anio--) anio,
  ];

  int? get _selectedMarcaId => _seleccion?.marcaId;
  int? get _selectedModeloId => _seleccion?.modeloId;

  String? _validarPlaca(String? value) {
    final plate = value?.trim().toUpperCase() ?? '';
    if (plate.isEmpty || _platePattern.hasMatch(plate)) return null;
    return 'Usa 3 letras y 3-4 números.';
  }

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();

    final vehiculo = widget.vehiculo;
    if (vehiculo != null) {
      _vinController.text = (vehiculo['vin'] ?? '').toString().toUpperCase();
      _anioSeleccionado = int.tryParse(vehiculo['anio']?.toString() ?? '');
      _patenteController.text = vehiculo['placa'] ?? '';
      _seleccion = _opcionDesdeVehiculo(vehiculo);
      _initialMarcaId = _selectedMarcaId;
      _initialModeloId = _selectedModeloId;
    }
    _initialAnio = _anioSeleccionado;
    _initialVin = _vinController.text;
    _initialPlaca = _patenteController.text;
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    _busquedaFocus.dispose();
    _vinController.dispose();
    _patenteController.dispose();
    super.dispose();
  }

  _OpcionVehiculo? _opcionDesdeVehiculo(Map<String, dynamic> vehiculo) {
    final modelo = vehiculo['modelos_vehiculo'] as Map<String, dynamic>?;
    final marca = modelo?['marcas_vehiculo'] as Map<String, dynamic>?;
    final marcaId = int.tryParse(marca?['id']?.toString() ?? '');
    final modeloId = int.tryParse(modelo?['id']?.toString() ?? '');
    if (marcaId == null || modeloId == null) return null;
    return _OpcionVehiculo(
      marcaId: marcaId,
      marcaNombre: marca?['nombre']?.toString() ?? '',
      modeloId: modeloId,
      modeloNombre: modelo?['nombre']?.toString() ?? '',
    );
  }

  Future<void> _cargarCatalogo() async {
    setState(() {
      _isLoadingCatalogo = true;
    });

    try {
      final marcas = await _marcaService.getMarcas();
      final grupos = await Future.wait(marcas.map(_opcionesDeMarca));
      if (!mounted) return;
      setState(() {
        _catalogo = grupos.expand((opciones) => opciones).toList()
          ..sort(
            (a, b) =>
                a.etiqueta.toLowerCase().compareTo(b.etiqueta.toLowerCase()),
          );
      });
    } catch (e) {
      AppLogger.error(
        'Error al cargar catálogo de vehículos',
        name: '_VehicleFormDialogState',
        error: e,
      );
      if (mounted) {
        mostrarSnackbarError(
          context,
          mensaje:
              'Error al cargar el catálogo: '
              '${ApiErrorHandler.userMessage(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingCatalogo = false);
    }
  }

  Future<List<_OpcionVehiculo>> _opcionesDeMarca(
    Map<String, dynamic> marca,
  ) async {
    final marcaId = int.tryParse(marca['id']?.toString() ?? '');
    if (marcaId == null) return const [];
    final modelos = await _modeloService.getModelosPorMarca(marcaId);
    final marcaNombre = marca['nombre']?.toString() ?? '';
    return [
      for (final modelo in modelos)
        if (int.tryParse(modelo['id']?.toString() ?? '') case final modeloId?)
          _OpcionVehiculo(
            marcaId: marcaId,
            marcaNombre: marcaNombre,
            modeloId: modeloId,
            modeloNombre: modelo['nombre']?.toString() ?? '',
          ),
    ];
  }

  Iterable<_OpcionVehiculo> _buscarVehiculos(String texto) {
    final tokens = texto
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty || _isLoadingCatalogo) return const [];
    final coincidencias = _catalogo
        .where((opcion) {
          final indice = '${opcion.marcaNombre} ${opcion.modeloNombre}'
              .toLowerCase();
          return tokens.every((t) => indice.contains(t));
        })
        .take(20);
    return [...coincidencias, _OpcionVehiculo.solicitud];
  }

  void _seleccionarVehiculo(_OpcionVehiculo opcion) {
    if (opcion.esSolicitud) {
      _mostrarSolicitudVehiculo();
      return;
    }
    setState(() => _seleccion = opcion);
    _busquedaController.clear();
    if (_selectionFieldKey.currentState?.hasError ?? false) {
      _selectionFieldKey.currentState?.validate();
    }
  }

  void _quitarSeleccion() {
    setState(() => _seleccion = null);
  }

  bool get _requiredFieldsValid {
    final vin = _vinController.text.trim();
    return _seleccion != null &&
        _vinPattern.hasMatch(vin) &&
        _anioSeleccionado != null;
  }

  bool get _hayCambios =>
      _selectedMarcaId != _initialMarcaId ||
      _selectedModeloId != _initialModeloId ||
      _anioSeleccionado != _initialAnio ||
      _vinController.text.trim() != _initialVin ||
      _patenteController.text.trim() != _initialPlaca;

  Future<void> _intentarCerrar() async {
    if (!_hayCambios) {
      Navigator.pop(context);
      return;
    }
    final descartar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusLg),
          side: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        title: const Text(
          '¿Descartar cambios?',
          style: AppTextStyles.textStyleTitle,
        ),
        content: Text(
          'Perderás los datos ingresados del vehículo.',
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.spacingMd,
          AppSpacing.spacingXs,
          AppSpacing.spacingMd,
          AppSpacing.spacingMd,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurfaceVariant,
                      minimumSize: const Size(0, 48),
                      side: BorderSide(color: AppColors.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                      ),
                    ),
                    child: const Text('Seguir editando'),
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingSm),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      foregroundColor: SemanticColors.colorErrorText,
                      backgroundColor: Color.alphaBlend(
                        AppColors.error.withValues(alpha: 0.32),
                        AppColors.surfaceContainerHigh,
                      ),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                      ),
                    ),
                    child: const Text('Descartar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (descartar == true && mounted) Navigator.pop(context);
  }

  void _mostrarAyudaVin() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1D),
        title: const Text('Número VIN', style: AppTextStyles.textStyleTitle),
        content: Text(
          'Lo encuentras en la matrícula del vehículo o en la base del parabrisas.',
          style: AppTextStyles.textStyleBody.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryContainer,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _mostrarSolicitudVehiculo() {
    showDialog<void>(
      context: context,
      builder: (context) => const _SolicitudVehiculoDialog(),
    );
  }

  Future<void> _guardar() async {
    if (_requiredFieldsValid && _formKey.currentState!.validate()) {
      try {
        if (widget.vehiculo != null) {
          // Actualizar
          await _vehiculoService.updateVehiculo(
            id: widget.vehiculo!['id'],
            marcaId: _selectedMarcaId,
            modeloId: _selectedModeloId,
            vin: _vinController.text.isNotEmpty ? _vinController.text : null,
            anio: _anioSeleccionado?.toString(),
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
            anio: _anioSeleccionado?.toString(),
            patente: _patenteController.text.isNotEmpty
                ? _patenteController.text
                : null,
          );
        }

        if (mounted) {
          Navigator.pop(context);
          widget.onSave();
          mostrarSnackbarExitoSobrio(
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

  Widget _buildBuscadorVehiculo() {
    final seleccion = _seleccion;
    return _campoFormulario(
      'Marca y Modelo',
      seleccion != null
          ? _buildChipSeleccion(seleccion)
          : LayoutBuilder(
              builder: (context, constraints) => Autocomplete<_OpcionVehiculo>(
                textEditingController: _busquedaController,
                focusNode: _busquedaFocus,
                displayStringForOption: (opcion) => opcion.esSolicitud
                    ? _busquedaController.text
                    : opcion.etiqueta,
                optionsBuilder: (value) => _buscarVehiculos(value.text),
                optionsViewBuilder: (context, onSelected, opciones) =>
                    _buildOpcionesVehiculo(
                      constraints.maxWidth,
                      onSelected,
                      opciones,
                    ),
                onSelected: _seleccionarVehiculo,
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) =>
                        RyTextField(
                          semanticLabel: 'Marca y Modelo',
                          hint: _isLoadingCatalogo
                              ? 'Cargando catálogo...'
                              : 'Ej: Sail, Hilux, Spark, Chevrolet...',
                          controller: controller,
                          focusNode: focusNode,
                          prefixWidget: const Icon(
                            Icons.search,
                            color: AppColors.textMuted,
                          ),
                          onSubmitted: (_) => onFieldSubmitted(),
                        ),
              ),
            ),
      requerido: true,
    );
  }

  Widget _buildChipSeleccion(_OpcionVehiculo seleccion) {
    return Container(
      padding: const EdgeInsets.only(
        left: AppSpacing.spacingMd,
        right: AppSpacing.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: AppColors.primaryContainer),
          const SizedBox(width: AppSpacing.spacingSm),
          Expanded(
            child: Text(
              seleccion.etiqueta,
              style: AppTextStyles.textStyleBody.copyWith(
                color: AppColors.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textMuted),
            tooltip: 'Cambiar marca y modelo',
            onPressed: _quitarSeleccion,
          ),
        ],
      ),
    );
  }

  Widget _buildOpcionesVehiculo(
    double ancho,
    AutocompleteOnSelected<_OpcionVehiculo> onSelected,
    Iterable<_OpcionVehiculo> opciones,
  ) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        color: const Color(0xFF1E1E22),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        child: SizedBox(
          width: ancho,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: opciones.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Colors.white12),
              itemBuilder: (context, index) {
                final opcion = opciones.elementAt(index);
                if (opcion.esSolicitud) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.add_circle_outline,
                      color: AppColors.primaryContainer,
                    ),
                    title: Text(
                      '¿No encuentras tu vehículo? Solicitar al administrador',
                      style: AppTextStyles.textStyleCaption.copyWith(
                        color: AppColors.primaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => onSelected(opcion),
                  );
                }
                return ListTile(
                  dense: true,
                  title: Text(
                    opcion.etiqueta,
                    style: AppTextStyles.textStyleBody.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  onTap: () => onSelected(opcion),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hayCambios,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _intentarCerrar();
      },
      child: Theme(
        data: _temaFormulario(Theme.of(context)),
        child: RyFormDialog(
          title: widget.vehiculo != null
              ? 'Editar Vehículo'
              : 'Agregar Vehículo',
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBuscadorVehiculo(),
                FormField<int>(
                  key: _selectionFieldKey,
                  validator: (_) => _seleccion == null
                      ? 'Por favor selecciona marca y modelo'
                      : null,
                  builder: (field) => field.errorText == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.spacingXs,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              field.errorText!,
                              style: AppTextStyles.textStyleCaption.copyWith(
                                color: SemanticColors.colorErrorText,
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                _campoFormulario(
                  'Número VIN',
                  RyTextField(
                    semanticLabel: 'Número VIN',
                    controller: _vinController,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-HJ-NPR-Z0-9a-hj-npr-z]'),
                      ),
                      LengthLimitingTextInputFormatter(17),
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) => newValue.copyWith(
                          text: newValue.text.toUpperCase(),
                          composing: TextRange.empty,
                        ),
                      ),
                    ],
                    keyboardType: TextInputType.text,
                    scrollPadding: const EdgeInsets.only(bottom: 120),
                    maxLength: 17,
                    suffixWidget: IconButton(
                      icon: const Icon(
                        Icons.info_outline,
                        color: AppColors.textMuted,
                      ),
                      tooltip: 'Ayuda: número VIN',
                      onPressed: _mostrarAyudaVin,
                    ),
                    helperText: '17 caracteres; sin I, O ni Q.',
                    helperMaxLines: 2,
                    onChanged: (_) => setState(() {}),
                    validator: (value) =>
                        _vinPattern.hasMatch(value?.trim().toUpperCase() ?? '')
                        ? null
                        : _vinValidationMessage,
                  ),
                  requerido: true,
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                _campoFormulario(
                  'Año',
                  DropdownButtonFormField<int>(
                    initialValue: _anios.contains(_anioSeleccionado)
                        ? _anioSeleccionado
                        : null,
                    isExpanded: true,
                    menuMaxHeight: 220,
                    dropdownColor: const Color(0xFF1E1E22),
                    borderRadius: BorderRadius.circular(12),
                    style: AppTextStyles.textStyleBody.copyWith(
                      color: AppColors.onSurface,
                    ),
                    icon: const Icon(
                      Icons.expand_more,
                      color: AppColors.textMuted,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Selecciona el año',
                    ),
                    items: [
                      for (final anio in _anios)
                        DropdownMenuItem<int>(
                          value: anio,
                          child: Text('$anio'),
                        ),
                    ],
                    validator: (value) => value == null
                        ? 'Selecciona el año del vehículo.'
                        : null,
                    onChanged: (value) =>
                        setState(() => _anioSeleccionado = value),
                  ),
                  requerido: true,
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                _campoFormulario(
                  'Placa (opcional)',
                  RyTextField(
                    semanticLabel: 'Placa (opcional)',
                    hint: 'Ej: PBX-1234',
                    scrollPadding: const EdgeInsets.only(bottom: 120),
                    textCapitalization: TextCapitalization.characters,
                    controller: _patenteController,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9-]'),
                      ),
                      LengthLimitingTextInputFormatter(8),
                      TextInputFormatter.withFunction(
                        (oldValue, newValue) => newValue.copyWith(
                          text: newValue.text.toUpperCase(),
                          composing: TextRange.empty,
                        ),
                      ),
                    ],
                    validator: _validarPlaca,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _intentarCerrar,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        minimumSize: const Size(0, 48),
                        side: BorderSide(color: AppColors.outlineVariant),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppRadius.radiusMd,
                          ),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.spacingSm),
                  Expanded(
                    child: RyButton(
                      label: 'Guardar',
                      variant: RyButtonVariant.primary,
                      size: RyButtonSize.small,
                      isFullWidth: true,
                      isDisabled: !_requiredFieldsValid,
                      onPressed: _requiredFieldsValid ? _guardar : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SolicitudVehiculoDialog extends StatefulWidget {
  const _SolicitudVehiculoDialog();

  @override
  State<_SolicitudVehiculoDialog> createState() =>
      _SolicitudVehiculoDialogState();
}

class _SolicitudVehiculoDialogState extends State<_SolicitudVehiculoDialog> {
  static const String _whatsAppSoporte = '0981894337';

  final _formKey = GlobalKey<FormState>();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anioController = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _marcaController.dispose();
    _modeloController.dispose();
    _anioController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _enviando = true);

    final anio = _anioController.text.trim();
    final mensaje =
        'Hola, quiero agregar un vehículo que no está en el catálogo de RepuestosYa. '
        'Marca: ${_marcaController.text.trim()}. '
        'Modelo: ${_modeloController.text.trim()}.'
        '${anio.isEmpty ? '' : ' Año: $anio.'}';
    final resultado = await ContactLauncher.launch(
      buildWhatsAppUri(_whatsAppSoporte, mensaje),
    );
    if (!mounted) return;
    setState(() => _enviando = false);

    if (resultado == ContactLaunchResult.launched) {
      Navigator.pop(context);
      mostrarSnackbarExitoSobrio(
        context,
        mensaje:
            '¡Gracias! Revisaremos tu solicitud para añadir este modelo al catálogo pronto.',
      );
    } else {
      mostrarSnackbarError(
        context,
        mensaje: 'No pudimos abrir WhatsApp. Escríbenos al $_whatsAppSoporte.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _temaFormulario(Theme.of(context)),
      child: RyFormDialog(
        title: 'Solicitar vehículo',
        backgroundColor: const Color(0xFF1A1A1D),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Indícanos el vehículo que no encuentras y lo añadiremos al catálogo.',
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.spacingMd),
              _campoFormulario(
                'Marca',
                RyTextField(
                  semanticLabel: 'Marca',
                  hint: 'Ej: Chevrolet',
                  controller: _marcaController,
                  textCapitalization: TextCapitalization.words,
                  validator: _validarRequerido,
                ),
                requerido: true,
              ),
              const SizedBox(height: AppSpacing.spacingMd),
              _campoFormulario(
                'Modelo',
                RyTextField(
                  semanticLabel: 'Modelo',
                  hint: 'Ej: Sail',
                  controller: _modeloController,
                  textCapitalization: TextCapitalization.words,
                  validator: _validarRequerido,
                ),
                requerido: true,
              ),
              const SizedBox(height: AppSpacing.spacingMd),
              _campoFormulario(
                'Año',
                RyTextField(
                  semanticLabel: 'Año',
                  hint: 'Ej: 2019',
                  type: RyTextFieldType.number,
                  controller: _anioController,
                  maxLength: 4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _enviando ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      minimumSize: const Size(0, 48),
                      side: BorderSide(color: AppColors.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingSm),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _enviando ? null : _enviar,
                    icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18),
                    label: const Text('Enviar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: const Color(0xFF131313),
                      disabledBackgroundColor: const Color(
                        0xFF25D366,
                      ).withValues(alpha: 0.5),
                      disabledForegroundColor: const Color(0xFF131313),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: AppTextStyles.textStyleButton.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                      ),
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
}
