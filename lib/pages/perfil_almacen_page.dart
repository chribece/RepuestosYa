import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/almacen_service.dart';

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

  // Sistema de Diseño Industrial
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF131313);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color outlineVariant = Color(0xFF5B4039);
  static const Color primary = Color(0xFFFFB5A0);
  static const Color primaryContainer = Color(0xFFFF5722);
  static const Color onPrimaryContainer = Color(0xFF541200);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFE4BEB4);

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
      print('DEBUG: Almacen recibido: $almacen');
      print('DEBUG: Tipo de almacen: ${almacen.runtimeType}');
      if (almacen != null) {
        print('DEBUG: Nombre comercial: ${almacen['nombre_comercial']}');
        print('DEBUG: Dirección: ${almacen['direccion_texto']}');
        setState(() {
          _almacenData = almacen;
          _nombreController.text = almacen['nombre_comercial'] ?? '';
          _direccionController.text = almacen['direccion_texto'] ?? '';
          _latController.text = (almacen['latitude'] ?? 0).toString();
          _lonController.text = (almacen['longitude'] ?? 0).toString();
          _isLoading = false;
        });
      } else {
        print('DEBUG: Almacen es null');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('DEBUG: Error al cargar almacén: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar almacén: $e'),
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.green,
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    print('DEBUG: PerfilAlmacenPage initState llamado');
    _cargarAlmacen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Perfil de Almacén',
          style: TextStyle(
            color: onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Sora',
          ),
        ),
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
                color: primary,
                size: 20,
              ),
              label: Text(
                _isEditing ? 'Cancelar' : 'Editar',
                style: const TextStyle(
                  color: primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryContainer),
            )
          : _almacenData == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.store, color: onSurfaceVariant, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'No tienes un almacén registrado',
                    style: TextStyle(
                      color: onSurface,
                      fontSize: 18,
                      fontFamily: 'Sora',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Regístrate para comenzar',
                    style: TextStyle(
                      color: onSurfaceVariant,
                      fontSize: 14,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 24),
                    _buildNombreField(),
                    const SizedBox(height: 24),
                    _buildDireccionField(),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _buildLatField()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildLonField()),
                      ],
                    ),
                    if (_isEditing) ...[
                      const SizedBox(height: 32),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outlineVariant, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: verificado
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              verificado ? Icons.verified : Icons.pending,
              color: verificado ? Colors.green : Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verificado ? 'Almacén Verificado' : 'En Verificación',
                  style: const TextStyle(
                    color: onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Sora',
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      estadoAbierto ? Icons.storefront : Icons.store,
                      color: estadoAbierto ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      estadoAbierto ? 'Abierto' : 'Cerrado',
                      style: TextStyle(
                        color: onSurfaceVariant,
                        fontSize: 12,
                        fontFamily: 'Inter',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nombre Comercial',
          style: TextStyle(
            color: onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nombreController,
          enabled: _isEditing,
          style: const TextStyle(
            color: onSurface,
            fontSize: 16,
            fontFamily: 'Inter',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El nombre comercial es requerido';
            }
            return null;
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: _isEditing
                ? surfaceContainerLow
                : surfaceContainerLow.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryContainer, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: outlineVariant.withOpacity(0.3)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDireccionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dirección',
          style: TextStyle(
            color: onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _direccionController,
          enabled: _isEditing,
          maxLines: 3,
          style: const TextStyle(
            color: onSurface,
            fontSize: 16,
            fontFamily: 'Inter',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'La dirección es requerida';
            }
            return null;
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: _isEditing
                ? surfaceContainerLow
                : surfaceContainerLow.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryContainer, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: outlineVariant.withOpacity(0.3)),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildLatField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Latitud',
          style: TextStyle(
            color: onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _latController,
          enabled: _isEditing,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d+')),
          ],
          style: const TextStyle(
            color: onSurface,
            fontSize: 16,
            fontFamily: 'Inter',
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: _isEditing
                ? surfaceContainerLow
                : surfaceContainerLow.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryContainer, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: outlineVariant.withOpacity(0.3)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Longitud',
          style: TextStyle(
            color: onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _lonController,
          enabled: _isEditing,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d+')),
          ],
          style: const TextStyle(
            color: onSurface,
            fontSize: 16,
            fontFamily: 'Inter',
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: _isEditing
                ? surfaceContainerLow
                : surfaceContainerLow.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryContainer, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: outlineVariant.withOpacity(0.3)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _guardarCambios,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          disabledBackgroundColor: primaryContainer.withOpacity(0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: onPrimaryContainer,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'GUARDANDO...',
                    style: TextStyle(
                      color: onPrimaryContainer,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Sora',
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, color: onPrimaryContainer, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'GUARDAR CAMBIOS',
                    style: TextStyle(
                      color: onPrimaryContainer,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Sora',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
