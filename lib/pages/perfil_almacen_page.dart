import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/almacen_service.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_text_field.dart';
import '../widgets/ry_state_container.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_logger.dart';

class PerfilAlmacenPage extends StatefulWidget {
  const PerfilAlmacenPage({super.key});

  @override
  State<PerfilAlmacenPage> createState() => _PerfilAlmacenPageState();
}

class _PerfilAlmacenPageState extends State<PerfilAlmacenPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();

  bool _isEditing = false;
  bool _isSubmitting = false;
  bool _isLoading = true;
  Map<String, dynamic>? _almacenData;

  final AlmacenService _almacenService = AlmacenService();

  @override
  void dispose() {
    _nombreController.dispose();
    _direccionController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _cargarAlmacen() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final almacen = await _almacenService.obtenerMiAlmacen();
      AppLogger.debug(
        'DEBUG: Almacen recibido: $almacen',
        name: 'PerfilAlmacenPage',
      );
      AppLogger.debug(
        'DEBUG: Tipo de almacen: ${almacen.runtimeType}',
        name: 'PerfilAlmacenPage',
      );
      if (almacen != null) {
        AppLogger.debug(
          'DEBUG: Nombre comercial: ${almacen['nombre_comercial']}',
          name: 'PerfilAlmacenPage',
        );
        AppLogger.debug(
          'DEBUG: Dirección: ${almacen['direccion_texto']}',
          name: 'PerfilAlmacenPage',
        );
        setState(() {
          _almacenData = almacen;
          _nombreController.text = almacen['nombre_comercial'] ?? '';
          _direccionController.text = almacen['direccion_texto'] ?? '';
          _latController.text = (almacen['latitude'] ?? 0).toString();
          _lonController.text = (almacen['longitude'] ?? 0).toString();
          _isLoading = false;
        });
      } else {
        AppLogger.debug('DEBUG: Almacen es null', name: 'PerfilAlmacenPage');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error(
        'Error al cargar almacén',
        name: 'PerfilAlmacenPage',
        error: e,
      );
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar almacén: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_almacenData == null) return;

      final data = {
        'nombre_comercial': _nombreController.text.trim(),
        'direccion_texto': _direccionController.text.trim(),
        'latitude': double.tryParse(_latController.text) ?? 0.0,
        'longitude': double.tryParse(_lonController.text) ?? 0.0,
      };

      await _almacenService.actualizarAlmacen(_almacenData!['id'], data);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado correctamente'),
            backgroundColor: AppColors.success,
          ),
        );
        await _cargarAlmacen();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar perfil: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    AppLogger.debug(
      'DEBUG: PerfilAlmacenPage initState llamado',
      name: 'PerfilAlmacenPage',
    );
    _cargarAlmacen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.primary,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Perfil de Almacén', style: AppTextStyles.textStyleTitle),
        actions: [
          if (!_isLoading && _almacenData != null)
            TextButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      setState(() {
                        _isEditing = !_isEditing;
                      });
                    },
              icon: Icon(
                _isEditing ? Icons.close : Icons.edit,
                color: AppColors.primary,
                size: 20,
              ),
              label: Text(
                _isEditing ? 'Cancelar' : 'Editar',
                style: AppTextStyles.textStyleButton.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const RyStateContainer(
              title: 'Cargando perfil...',
              type: RyStateType.loading,
            )
          : _almacenData == null
          ? const RyStateContainer(
              title: 'Sin almacén',
              subtitle:
                  'No tienes un almacén registrado. Regístrate para comenzar.',
              type: RyStateType.empty,
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.spacingMd),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: AppSpacing.spacingXl),
                    _buildNombreField(),
                    const SizedBox(height: AppSpacing.spacingXl),
                    _buildDireccionField(),
                    const SizedBox(height: AppSpacing.spacingXl),
                    Row(
                      children: [
                        Expanded(child: _buildLatField()),
                        const SizedBox(width: AppSpacing.spacingMd),
                        Expanded(child: _buildLonField()),
                      ],
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: AppSpacing.spacingXxl),
                      _buildSaveButton(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final verificado = _almacenData?['verificado'] ?? false;
    final estadoAbierto = _almacenData?['estado_abierto'] ?? true;

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
            padding: const EdgeInsets.all(AppSpacing.spacingSm),
            decoration: BoxDecoration(
              color: verificado
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.radiusSm),
            ),
            child: Icon(
              verificado ? Icons.verified : Icons.pending,
              color: verificado ? AppColors.success : AppColors.warning,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verificado ? 'Almacén Verificado' : 'En Verificación',
                  style: AppTextStyles.textStyleBody.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingXxs),
                Row(
                  children: [
                    Icon(
                      estadoAbierto ? Icons.storefront : Icons.store,
                      color: estadoAbierto
                          ? AppColors.success
                          : AppColors.error,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.spacingXxs),
                    Text(
                      estadoAbierto ? 'Abierto' : 'Cerrado',
                      style: AppTextStyles.textStyleSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNombreField() {
    return RyTextField(
      label: 'Nombre Comercial',
      controller: _nombreController,
      isReadOnly: !_isEditing,
      isRequired: true,
    );
  }

  Widget _buildDireccionField() {
    return RyTextField(
      label: 'Dirección',
      controller: _direccionController,
      isReadOnly: !_isEditing,
      maxLines: 3,
      isRequired: true,
    );
  }

  Widget _buildLatField() {
    return RyTextField(
      label: 'Latitud',
      controller: _latController,
      isReadOnly: !_isEditing,
      type: RyTextFieldType.number,
    );
  }

  Widget _buildLonField() {
    return RyTextField(
      label: 'Longitud',
      controller: _lonController,
      isReadOnly: !_isEditing,
      type: RyTextFieldType.number,
    );
  }

  Widget _buildSaveButton() {
    return RyButton(
      label: 'Guardar Cambios',
      icon: Icons.save,
      variant: RyButtonVariant.primary,
      size: RyButtonSize.large,
      isFullWidth: true,
      isLoading: _isSubmitting,
      onPressed: _isSubmitting ? null : _guardarCambios,
    );
  }
}
