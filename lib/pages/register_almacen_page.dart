import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/almacen_service.dart';
import '../services/auth_service.dart';

class RegisterAlmacenPage extends StatefulWidget {
  const RegisterAlmacenPage({super.key});

  @override
  State<RegisterAlmacenPage> createState() => _RegisterAlmacenPageState();
}

class _RegisterAlmacenPageState extends State<RegisterAlmacenPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _latController = TextEditingController(text: '0.0');
  final TextEditingController _lonController = TextEditingController(text: '0.0');
  
  bool _isSubmitting = false;
  final AlmacenService _almacenService = AlmacenService();
  final AuthService _authService = AuthService();

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

  Future<void> _registrarAlmacen() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = _authService.currentUser?.id;
      if (userId == null) {
        throw Exception('No hay usuario autenticado');
      }

      final data = {
        'encargado_id': userId,
        'nombre_comercial': _nombreController.text.trim(),
        'direccion_texto': _direccionController.text.trim(),
        'latitude': double.tryParse(_latController.text) ?? 0.0,
        'longitude': double.tryParse(_lonController.text) ?? 0.0,
      };

      await _almacenService.crearAlmacen(data);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar almacén: $e'),
            backgroundColor: Colors.red,
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
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Registrar Almacén',
          style: TextStyle(
            color: onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Sora',
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
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
                const SizedBox(height: 32),
                _buildRegisterButton(),
                const SizedBox(height: 16),
                _buildInfoBox(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNombreField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nombre Comercial *',
          style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nombreController,
          style: const TextStyle(color: onSurface, fontSize: 16, fontFamily: 'Inter'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El nombre comercial es requerido';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Ej: RepuestosYa Central',
            hintStyle: TextStyle(color: onSurfaceVariant.withOpacity(0.3)),
            filled: true,
            fillColor: surfaceContainerLow,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariant)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariant)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryContainer, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
          'Dirección *',
          style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _direccionController,
          maxLines: 3,
          style: const TextStyle(color: onSurface, fontSize: 16, fontFamily: 'Inter'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'La dirección es requerida';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Ej: Av. Principal 123, Ciudad',
            hintStyle: TextStyle(color: onSurfaceVariant.withOpacity(0.3)),
            filled: true,
            fillColor: surfaceContainerLow,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariant)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariant)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryContainer, width: 1.5)),
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
          style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _latController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d+'))],
          style: const TextStyle(color: onSurface, fontSize: 16, fontFamily: 'Inter'),
          decoration: InputDecoration(
            hintText: '0.0',
            hintStyle: TextStyle(color: onSurfaceVariant.withOpacity(0.3)),
            filled: true,
            fillColor: surfaceContainerLow,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariant)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariant)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryContainer, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
          style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _lonController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d+'))],
          style: const TextStyle(color: onSurface, fontSize: 16, fontFamily: 'Inter'),
          decoration: InputDecoration(
            hintText: '0.0',
            hintStyle: TextStyle(color: onSurfaceVariant.withOpacity(0.3)),
            filled: true,
            fillColor: surfaceContainerLow,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariant)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outlineVariant)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryContainer, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _registrarAlmacen,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          disabledBackgroundColor: primaryContainer.withOpacity(0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSubmitting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: onPrimaryContainer)),
                  SizedBox(width: 12),
                  Text('PROCESANDO...', style: TextStyle(color: onPrimaryContainer, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Sora')),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store, color: onPrimaryContainer, size: 20),
                  SizedBox(width: 8),
                  Text('REGISTRAR MI ALMACÉN', style: TextStyle(color: onPrimaryContainer, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Sora')),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceContainerHigh.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outlineVariant.withOpacity(0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: primary, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Las coordenadas son opcionales. Puedes actualizarlas más tarde desde tu perfil.',
              style: TextStyle(color: onSurfaceVariant, fontSize: 12, height: 1.4, fontFamily: 'Inter'),
            ),
          ),
        ],
      ),
    );
  }
}
