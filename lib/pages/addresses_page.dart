import 'package:flutter/material.dart';
import '../services/direccion_service.dart';
import '../services/auth_service.dart';

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  final DireccionService _direccionService = DireccionService();
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _direcciones = [];
  bool _isLoading = false;

  // Color scheme idéntico al de tu diseño original
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
  static const Color requiredAsterisk = Color(0xFFFF3333);

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
            content: Text('Error al cargar direcciones: $e'),
            backgroundColor: error,
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
            content: Text('Error al eliminar dirección: $e'),
            backgroundColor: error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Mis Direcciones de Entrega'),
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryContainer),
            )
          : _direcciones.isEmpty
          ? Center(
              child: Text(
                'No tienes direcciones registradas',
                style: TextStyle(color: onSurfaceVariant, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
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

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      alias,
                      style: const TextStyle(
                        color: onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Principal: $callePrincipal',
                            style: const TextStyle(color: onSurfaceVariant),
                          ),
                          if (calleSecundaria.isNotEmpty)
                            Text(
                              'Secundaria: $calleSecundaria',
                              style: const TextStyle(color: onSurfaceVariant),
                            ),
                          if (referencia.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Ref: $referencia',
                              style: TextStyle(
                                color: primary.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: primary),
                          onPressed: () => _mostrarFormulario(direccion),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: error),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: surfaceContainerHigh,
                                title: const Text(
                                  'Confirmar',
                                  style: TextStyle(color: onSurface),
                                ),
                                content: const Text(
                                  '¿Estás seguro de eliminar esta dirección?',
                                  style: TextStyle(color: onSurfaceVariant),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      'Cancelar',
                                      style: TextStyle(color: onSurfaceVariant),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _eliminarDireccion(id);
                                    },
                                    child: const Text(
                                      'Eliminar',
                                      style: TextStyle(color: error),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: primaryContainer,
        foregroundColor: onPrimaryContainer,
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
            content: Text('Error al guardar la dirección: $e'),
            backgroundColor: _AddressesPageState.error,
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
      backgroundColor: _AddressesPageState.surfaceContainerHigh,
      title: Text(
        widget.direccion == null ? 'Agregar Dirección' : 'Editar Dirección',
        style: const TextStyle(color: _AddressesPageState.onSurface),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Input Alias
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Alias (Ej. Casa, Trabajo)',
                            style: TextStyle(
                              color: _AddressesPageState.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text: ' *',
                            style: TextStyle(
                              color: _AddressesPageState.requiredAsterisk,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _aliasController,
                      style: const TextStyle(
                        color: _AddressesPageState.onSurface,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _AddressesPageState.onSurfaceVariant
                            .withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: _AddressesPageState.outlineVariant,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'El alias es obligatorio';
                        }
                        if (v.trim().length < 2) {
                          return 'El alias debe tener al menos 2 caracteres';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Input Calle Principal
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Calle Principal',
                            style: TextStyle(
                              color: _AddressesPageState.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text: ' *',
                            style: TextStyle(
                              color: _AddressesPageState.requiredAsterisk,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _callePrincipalController,
                      style: const TextStyle(
                        color: _AddressesPageState.onSurface,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _AddressesPageState.onSurfaceVariant
                            .withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: _AddressesPageState.outlineVariant,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'La calle principal es obligatoria';
                        }
                        if (v.trim().length < 5) {
                          return 'La calle debe tener al menos 5 caracteres';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Input Calle Secundaria
                TextFormField(
                  controller: _calleSecundariaController,
                  style: const TextStyle(color: _AddressesPageState.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Calle Secundaria (Opcional)',
                    labelStyle: const TextStyle(
                      color: _AddressesPageState.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: _AddressesPageState.onSurfaceVariant.withOpacity(
                      0.1,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: _AddressesPageState.outlineVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Input Referencia
                TextFormField(
                  controller: _referenciaController,
                  maxLines: 2,
                  style: const TextStyle(color: _AddressesPageState.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Referencia / Indicaciones (Opcional)',
                    labelStyle: const TextStyle(
                      color: _AddressesPageState.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: _AddressesPageState.onSurfaceVariant.withOpacity(
                      0.1,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: _AddressesPageState.outlineVariant,
                      ),
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
            style: TextStyle(color: _AddressesPageState.onSurfaceVariant),
          ),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: _AddressesPageState.primaryContainer,
            foregroundColor: _AddressesPageState.onPrimaryContainer,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
