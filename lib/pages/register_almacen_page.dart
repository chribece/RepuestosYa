import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'complete_profile_page.dart';

class RegisterAlmacenPage extends StatefulWidget {
  const RegisterAlmacenPage({super.key});

  @override
  State<RegisterAlmacenPage> createState() => _RegisterAlmacenPageState();
}

class _RegisterAlmacenPageState extends State<RegisterAlmacenPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _representanteController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSubmitting = false;
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
  static const Color requiredAsterisk = Color(0xFFFF3333);

  @override
  void dispose() {
    _representanteController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registrarAlmacen() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Registrar el usuario en Auth con rol 'almacen'
      await _authService.signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nombreCompleto: _representanteController.text.trim(),
        rol: 'almacen',
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Registro exitoso! Ahora completa tu perfil.'),
            backgroundColor: primaryContainer,
            duration: Duration(seconds: 2),
          ),
        );
        // Navegar a la página de completar perfil
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CompleteProfilePage()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
        title: Text(
          'Registrar Almacén',
          style: GoogleFonts.sora(
            color: onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,

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
                _buildWelcomeText(),
                const SizedBox(height: 32),
                _buildRepresentanteField(),
                const SizedBox(height: 24),
                _buildEmailField(),
                const SizedBox(height: 24),
                _buildPasswordField(),
                const SizedBox(height: 24),
                _buildConfirmPasswordField(),
                const SizedBox(height: 32),
                _buildRegisterButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Crear Cuenta',
          style: GoogleFonts.sora(
            color: primary,
            fontSize: 28,
            fontWeight: FontWeight.bold,

          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Regístrate para comenzar a gestionar tu almacén.',
          style: TextStyle(
            color: onSurfaceVariant,
            fontSize: 16,
            fontFamily: 'Inter',
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
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Nombre Completo',
                style: GoogleFonts.sora(
                  color: onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: ' *',
                style: GoogleFonts.sora(
                  color: requiredAsterisk,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _representanteController,
          style: GoogleFonts.sora(
            color: onSurface,
            fontSize: 16,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El nombre completo es requerido';
            }
            if (value.trim().length < 3) {
              return 'El nombre debe tener al menos 3 caracteres';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Ej: Juan Pérez',
            hintStyle: GoogleFonts.sora(color: onSurfaceVariant.withOpacity(0.3)),
            filled: true,
            fillColor: surfaceContainerLow,
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
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
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
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Email',
                style: GoogleFonts.sora(
                  color: onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: ' *',
                style: GoogleFonts.sora(
                  color: requiredAsterisk,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.sora(
            color: onSurface,
            fontSize: 16,
          ),
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
            hintStyle: GoogleFonts.sora(color: onSurfaceVariant.withOpacity(0.3)),
            filled: true,
            fillColor: surfaceContainerLow,
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
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
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
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Contraseña',
                style: GoogleFonts.sora(
                  color: onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: ' *',
                style: GoogleFonts.sora(
                  color: requiredAsterisk,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: true,
          style: GoogleFonts.sora(
            color: onSurface,
            fontSize: 16,
          ),
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
            hintStyle: GoogleFonts.sora(color: onSurfaceVariant.withOpacity(0.3)),
            filled: true,
            fillColor: surfaceContainerLow,
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
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
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
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Confirmar Contraseña',
                style: GoogleFonts.sora(
                  color: onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: ' *',
                style: GoogleFonts.sora(
                  color: requiredAsterisk,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: true,
          style: GoogleFonts.sora(
            color: onSurface,
            fontSize: 16,
          ),
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
            hintStyle: GoogleFonts.sora(color: onSurfaceVariant.withOpacity(0.3)),
            filled: true,
            fillColor: surfaceContainerLow,
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
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
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
                    'PROCESANDO...',
                    style: TextStyle(
                      color: onPrimaryContainer,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add, color: onPrimaryContainer, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'CREAR CUENTA',
                    style: TextStyle(
                      color: onPrimaryContainer,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
