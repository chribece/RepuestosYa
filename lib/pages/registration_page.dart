import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_text_field.dart';
import '../services/auth_service.dart';
import '../router/route_names.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _acceptTerms = false;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleRegistration() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _authService.signUpWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          nombreCompleto: _nameController.text.trim(),
        );

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '¡Cuenta creada exitosamente! Por favor verifica tu email.',
            ),
            backgroundColor: AppColors.primaryContainer,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate back to login
        context.goNamed(RouteNames.login);
      } catch (e) {
        AppLogger.error(
          'Error al registrar usuario',
          name: 'RegistrationPage',
          error: e,
        );

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiErrorHandler.userMessage(e)),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(color: AppColors.background),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Section
                _buildLogoSection(),
                const SizedBox(height: AppSpacing.spacingXl),
                // Registration Form Card
                _buildRegistrationForm(),
                const SizedBox(height: AppSpacing.spacingXl),
                // Footer
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryContainer.withValues(alpha: 0.2),
          ),
          child: const Icon(Icons.build, size: 50, color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.spacingLg),
        Text(
          'Crear Cuenta',
          style: AppTextStyles.textStyleHeading.copyWith(
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        Text(
          'Performance y precisión en cada pieza.',
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppSpacing.spacingLg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name Field
            _buildNameField(),
            const SizedBox(height: AppSpacing.spacingMd),
            // Email Field
            _buildEmailField(),
            const SizedBox(height: AppSpacing.spacingMd),
            // Password Field
            _buildPasswordField(),
            const SizedBox(height: AppSpacing.spacingMd),
            // Confirm Password Field
            _buildConfirmPasswordField(),
            const SizedBox(height: AppSpacing.spacingMd),
            // Accept Terms
            _buildAcceptTerms(),
            const SizedBox(height: AppSpacing.spacingLg),
            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return RyTextField(
      label: 'Nombre completo',
      hint: 'Juan Pérez',
      controller: _nameController,
      type: RyTextFieldType.text,
      isRequired: true,
      prefixIcon: Icons.person,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Por favor ingrese su nombre completo';
        }
        if (value.trim().length < 2) {
          return 'El nombre debe tener al menos 2 caracteres';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return RyTextField(
      label: 'Email corporativo / Usuario',
      hint: 'nombre@empresa.com',
      controller: _emailController,
      type: RyTextFieldType.email,
      isRequired: true,
      prefixIcon: Icons.mail,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Por favor ingrese su email';
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
      prefixIcon: Icons.lock,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor ingrese su contraseña';
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
      label: 'Confirmar contraseña',
      hint: '••••••••',
      controller: _confirmPasswordController,
      type: RyTextFieldType.password,
      isRequired: true,
      prefixIcon: Icons.lock_outline,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor confirme su contraseña';
        }
        if (value != _passwordController.text) {
          return 'Las contraseñas no coinciden';
        }
        return null;
      },
    );
  }

  Widget _buildAcceptTerms() {
    return Row(
      children: [
        Checkbox(
          value: _acceptTerms,
          onChanged: (value) {
            setState(() {
              _acceptTerms = value ?? false;
            });
          },
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryContainer;
            }
            return AppColors.surfaceContainerHigh;
          }),
          checkColor: AppColors.onPrimaryContainer,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _acceptTerms = !_acceptTerms;
              });
            },
            child: Text(
              'Acepto los términos y condiciones de uso',
              style: AppTextStyles.textStyleCaption.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        RyButton(
          label: 'REGISTRARSE',
          trailingIcon: Icons.person_add,
          variant: RyButtonVariant.primary,
          size: RyButtonSize.large,
          isFullWidth: true,
          isLoading: _isLoading,
          onPressed: _handleRegistration,
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        Center(
          child: RyButton(
            label: '¿Ya tienes cuenta? Inicia sesión',
            variant: RyButtonVariant.text,
            onPressed: () {
              context.goNamed(RouteNames.login);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.verified,
                  size: 18,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.spacingXxs),
                Text(
                  'Certificado ISO 9001',
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.spacingMd),
            Container(width: 1, height: 16, color: AppColors.outlineVariant),
            const SizedBox(width: AppSpacing.spacingMd),
            Row(
              children: [
                const Icon(
                  Icons.security,
                  size: 18,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.spacingXxs),
                Text(
                  'SSL Secure',
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXl),
          child: Text(
            '© 2024 RepuestosYa S.A. Todos los derechos reservados. El acceso no autorizado a este sistema técnico está prohibido.',
            style: AppTextStyles.textStyleSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
