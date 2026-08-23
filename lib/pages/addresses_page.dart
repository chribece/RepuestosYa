import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/direccion_service.dart';
import '../utils/api_error_handler.dart';
import '../widgets/ry_text_field.dart';
import '../widgets/ry_state_container.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  final DireccionService _direccionService = DireccionService();

  List<Map<String, dynamic>> _direcciones = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarDirecciones();
  }

  Future<void> _cargarDirecciones() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final direcciones = await _direccionService.getDirecciones();
      setState(() {
        _direcciones = direcciones;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar direcciones: '
              '${ApiErrorHandler.userMessage(e)}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _mostrarFormulario([Map<String, dynamic>? direccion]) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => AddressDialog(direccion: direccion),
    );

    if (resultado == true) {
      _cargarDirecciones();
    }
  }

  Future<void> _eliminarDireccion(String id) async {
    try {
      await _direccionService.deleteDireccion(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dirección eliminada correctamente')),
        );
      }
      _cargarDirecciones();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al eliminar dirección: '
              '${ApiErrorHandler.userMessage(e)}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis Direcciones de Entrega'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
      ),
      body: _isLoading
          ? const RyStateContainer(
              title: 'Cargando direcciones...',
              type: RyStateType.loading,
            )
          : _direcciones.isEmpty
          ? const RyStateContainer(
              title: 'Sin direcciones',
              subtitle:
                  'No tienes direcciones registradas. Agrega tu primera dirección.',
              type: RyStateType.empty,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.spacingMd),
              itemCount: _direcciones.length,
              itemBuilder: (context, index) {
                final direccion = _direcciones[index];

                // Mapeo seguro con tipos explícitos usando snake_case de Supabase
                final id = direccion['id'] as String;
                final alias = direccion['alias'] as String? ?? 'Dirección';
                final callePrincipal =
                    direccion['calle_principal'] as String? ?? '';
                final calleSecundaria =
                    direccion['calle_secundaria'] as String? ?? '';
                final referencia = direccion['referencia'] as String? ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
                  padding: const EdgeInsets.all(AppSpacing.spacingMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.radiusLg),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(alias, style: AppTextStyles.textStyleBody),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: AppColors.primary,
                                ),
                                onPressed: () => _mostrarFormulario(direccion),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: AppColors.error,
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor:
                                          AppColors.surfaceContainerHigh,
                                      title: const Text(
                                        'Confirmar',
                                        style: AppTextStyles.textStyleTitle,
                                      ),
                                      content: Text(
                                        '¿Estás seguro de eliminar esta dirección?',
                                        style: AppTextStyles.textStyleBody
                                            .copyWith(
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text(
                                            'Cancelar',
                                            style: AppTextStyles.textStyleButton
                                                .copyWith(
                                                  color: AppColors
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _eliminarDireccion(id);
                                          },
                                          child: Text(
                                            'Eliminar',
                                            style: AppTextStyles.textStyleButton
                                                .copyWith(
                                                  color: AppColors.error,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.spacingSm),
                      Text(
                        'Principal: $callePrincipal',
                        style: AppTextStyles.textStyleCaption.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      if (calleSecundaria.isNotEmpty)
                        Text(
                          'Secundaria: $calleSecundaria',
                          style: AppTextStyles.textStyleCaption.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      if (referencia.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.spacingXxs),
                        Text(
                          'Ref: $referencia',
                          style: AppTextStyles.textStyleSmall.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddressDialog extends StatefulWidget {
  final Map<String, dynamic>? direccion;

  const AddressDialog({super.key, this.direccion});

  @override
  State<AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<AddressDialog> {
  final _formKey = GlobalKey<FormState>();
  final DireccionService _direccionService = DireccionService();

  late TextEditingController _aliasController;
  late TextEditingController _callePrincipalController;
  late TextEditingController _calleSecundariaController;
  late TextEditingController _referenciaController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Asignación correcta desde las nuevas llaves en la base de datos
    _aliasController = TextEditingController(
      text: widget.direccion?['alias'] ?? '',
    );
    _callePrincipalController = TextEditingController(
      text: widget.direccion?['calle_principal'] ?? '',
    );
    _calleSecundariaController = TextEditingController(
      text: widget.direccion?['calle_secundaria'] ?? '',
    );
    _referenciaController = TextEditingController(
      text: widget.direccion?['referencia'] ?? '',
    );
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _callePrincipalController.dispose();
    _calleSecundariaController.dispose();
    _referenciaController.dispose();
    super.dispose();
  }

  void _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.direccion == null) {
        // Crear dirección consumiendo el servicio estructurado camelCase
        await _direccionService.createDireccion(
          alias: _aliasController.text.trim(),
          callePrincipal: _callePrincipalController.text.trim(),
          calleSecundaria: _calleSecundariaController.text.trim(),
          referencia: _referenciaController.text.trim(),
        );
      } else {
        // Actualizar dirección pasando el ID correspondiente
        await _direccionService.updateDireccion(
          id: widget.direccion!['id'],
          alias: _aliasController.text.trim().isEmpty
              ? null
              : _aliasController.text.trim(),
          callePrincipal: _callePrincipalController.text.trim().isEmpty
              ? null
              : _callePrincipalController.text.trim(),
          calleSecundaria: _calleSecundariaController.text.trim().isEmpty
              ? null
              : _calleSecundariaController.text.trim(),
          referencia: _referenciaController.text.trim().isEmpty
              ? null
              : _referenciaController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar la dirección: '
              '${ApiErrorHandler.userMessage(e)}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerHigh,
      title: Text(
        widget.direccion == null ? 'Agregar Dirección' : 'Editar Dirección',
        style: AppTextStyles.textStyleTitle,
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RyTextField(
                  label: 'Alias (Ej. Casa, Trabajo)',
                  controller: _aliasController,
                  isRequired: true,
                  helperText: 'Mínimo 2 caracteres',
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                RyTextField(
                  label: 'Calle Principal',
                  controller: _callePrincipalController,
                  isRequired: true,
                  helperText: 'Mínimo 5 caracteres',
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                RyTextField(
                  label: 'Calle Secundaria (Opcional)',
                  controller: _calleSecundariaController,
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                RyTextField(
                  label: 'Referencia / Indicaciones (Opcional)',
                  controller: _referenciaController,
                  maxLines: 2,
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
          onPressed: _isSaving ? null : _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: AppColors.onPrimaryContainer,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.onSurface,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
