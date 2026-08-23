import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_text_field.dart';
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
            backgroundColor: AppColors.primaryContainer,
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
      AppLogger.error(
        'Error al registrar almacén',
        name: 'RegisterAlmacenPage',
        error: e,
      );
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiErrorHandler.userMessage(e)),
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
        title: Text(
          'Registrar Almacén',
          style: AppTextStyles.textStyleTitle.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.spacingMd),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.spacingMd),
                _buildWelcomeText(),
                const SizedBox(height: AppSpacing.spacingXl),
                _buildRepresentanteField(),
                const SizedBox(height: AppSpacing.spacingLg),
                _buildEmailField(),
                const SizedBox(height: AppSpacing.spacingLg),
                _buildPasswordField(),
                const SizedBox(height: AppSpacing.spacingLg),
                _buildConfirmPasswordField(),
                const SizedBox(height: AppSpacing.spacingXl),
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
          style: AppTextStyles.textStyleHeading.copyWith(
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        Text(
          'Regístrate para comenzar a gestionar tu almacén.',
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildRepresentanteField() {
    return RyTextField(
      label: 'Nombre Completo',
      hint: 'Ej: Juan Pérez',
      controller: _representanteController,
      type: RyTextFieldType.text,
      isRequired: true,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'El nombre completo es requerido';
        }
        if (value.trim().length < 3) {
          return 'El nombre debe tener al menos 3 caracteres';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return RyTextField(
      label: 'Email',
      hint: 'Ej: contacto@repuestosya.com',
      controller: _emailController,
      type: RyTextFieldType.email,
      isRequired: true,
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
    );
  }

  Widget _buildPasswordField() {
    return RyTextField(
      label: 'Contraseña',
      hint: '••••••••',
      controller: _passwordController,
      type: RyTextFieldType.password,
      isRequired: true,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'La contraseña es requerida';
        }
        if (value.length < 6) {
          return 'La contraseña debe tener al menos 6 caracteres';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return RyTextField(
      label: 'Confirmar Contraseña',
      hint: '••••••••',
      controller: _confirmPasswordController,
      type: RyTextFieldType.password,
      isRequired: true,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Por favor confirme su contraseña';
        }
        if (value != _passwordController.text) {
          return 'Las contraseñas no coinciden';
        }
        return null;
      },
    );
  }

  Widget _buildRegisterButton() {
    return RyButton(
      label: _isSubmitting ? 'PROCESANDO...' : 'CREAR CUENTA',
      icon: Icons.person_add,
      variant: RyButtonVariant.primary,
      size: RyButtonSize.large,
      isFullWidth: true,
      isLoading: _isSubmitting,
      onPressed: _registrarAlmacen,
    );
  }
}
