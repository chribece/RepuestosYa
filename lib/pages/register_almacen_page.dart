import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class RegisterAlmacenPage extends StatefulWidget {
  const RegisterAlmacenPage({super.key});

  @override
  State<RegisterAlmacenPage> createState() => _RegisterAlmacenPageState();
}

class _RegisterAlmacenPageState extends State<RegisterAlmacenPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _rucController = TextEditingController();
  final TextEditingController _representanteController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _latController = TextEditingController(text: '0.0');
  final TextEditingController _lonController = TextEditingController(text: '0.0');
  
  bool _isSubmitting = false;
  final AuthService _authService = AuthService();
  
  // Backend URL - Usar el mismo que ApiClient
  static const String _baseUrl = 'http://192.168.100.2:3000/api';

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
  static const Color requiredAsterisk = Color(0xFFFF3333);

  @override
  void dispose() {
    _nombreController.dispose();
    _rucController.dispose();
    _representanteController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
      // Primero registrar el usuario en Supabase Auth con rol 'almacen'
      await _authService.signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nombreCompleto: _representanteController.text.trim(),
        rol: 'almacen',
      );

      // Obtener el ID del usuario creado
      final userId = _authService.currentUser?.id;
      if (userId == null) {
        throw Exception('No se pudo obtener el ID del usuario');
      }

      // Enviar datos del almacén al backend Node.js
      final response = await http.post(
        Uri.parse('$_baseUrl/warehouses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _authService.getToken()}',
        },
        body: jsonEncode({
          'encargado_id': userId,
          'nombre_comercial': _nombreController.text.trim(),
          'ruc': _rucController.text.trim(),
          'representante_legal': _representanteController.text.trim(),
          'telefono': _telefonoController.text.trim(),
          'email': _emailController.text.trim(),
          'direccion_texto': _direccionController.text.trim(),
          'latitude': double.tryParse(_latController.text) ?? 0.0,
          'longitude': double.tryParse(_lonController.text) ?? 0.0,
        }),
      );

      if (response.statusCode != 201) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Error al registrar almacén');
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Almacén registrado exitosamente!'),
            backgroundColor: primaryContainer,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
                _buildRucField(),
                const SizedBox(height: 24),
                _buildRepresentanteField(),
                const SizedBox(height: 24),
                _buildTelefonoField(),
                const SizedBox(height: 24),
                _buildEmailField(),
                const SizedBox(height: 24),
                _buildPasswordField(),
                const SizedBox(height: 24),
                _buildConfirmPasswordField(),
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
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Nombre Comercial',
                style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(color: requiredAsterisk, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nombreController,
          style: const TextStyle(color: onSurface, fontSize: 16, fontFamily: 'Inter'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El nombre comercial es requerido';
            }
            if (value.trim().length < 3) {
              return 'El nombre debe tener al menos 3 caracteres';
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

  Widget _buildRucField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'RUC',
                style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(color: requiredAsterisk, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _rucController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: onSurface, fontSize: 16, fontFamily: 'Inter'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El RUC es requerido';
            }
            if (value.trim().length != 11) {
              return 'El RUC debe tener 11 dígitos';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Ej: 20123456789',
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

  Widget _buildRepresentanteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Representante Legal',
                style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(color: requiredAsterisk, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _representanteController,
          style: const TextStyle(color: onSurface, fontSize: 16, fontFamily: 'Inter'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El representante legal es requerido';
            }
            if (value.trim().length < 3) {
              return 'El nombre debe tener al menos 3 caracteres';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Ej: Juan Pérez',
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

  Widget _buildTelefonoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Teléfono',
                style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(color: requiredAsterisk, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _telefonoController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: onSurface, fontSize: 16, fontFamily: 'Inter'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El teléfono es requerido';
            }
            if (value.trim().length < 9) {
              return 'El teléfono debe tener al menos 9 dígitos';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Ej: 999123456',
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

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Email',
                style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(color: requiredAsterisk, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: onSurface, fontSize: 16, fontFamily: 'Inter'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El email es requerido';
            }
            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
            if (!emailRegex.hasMatch(value.trim())) {
              return 'Por favor ingrese un email válido';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Ej: contacto@repuestosya.com',
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

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Contraseña',
                style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(color: requiredAsterisk, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: onSurface, fontSize: 16, fontFamily: 'Inter'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'La contraseña es requerida';
            }
            if (value.length < 6) {
              return 'La contraseña debe tener al menos 6 caracteres';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: '••••••••',
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

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Confirmar Contraseña',
                style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(color: requiredAsterisk, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: true,
          style: const TextStyle(color: onSurface, fontSize: 16, fontFamily: 'Inter'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Por favor confirme su contraseña';
            }
            if (value != _passwordController.text) {
              return 'Las contraseñas no coinciden';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: '••••••••',
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
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Dirección',
                style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(color: requiredAsterisk, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
            ],
          ),
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
            if (value.trim().length < 5) {
              return 'La dirección debe tener al menos 5 caracteres';
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
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Latitud',
                style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _latController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d+'))],
          style: const TextStyle(color: onSurface, fontSize: 16, fontFamily: 'Inter'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return null; // Optional field
            }
            final lat = double.tryParse(value.trim());
            if (lat == null) {
              return 'Ingresa un número válido';
            }
            if (lat < -90 || lat > 90) {
              return 'Latitud debe estar entre -90 y 90';
            }
            return null;
          },
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
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Longitud',
                style: TextStyle(color: onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _lonController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d+'))],
          style: const TextStyle(color: onSurface, fontSize: 16, fontFamily: 'Inter'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return null; // Optional field
            }
            final lon = double.tryParse(value.trim());
            if (lon == null) {
              return 'Ingresa un número válido';
            }
            if (lon < -180 || lon > 180) {
              return 'Longitud debe estar entre -180 y 180';
            }
            return null;
          },
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
