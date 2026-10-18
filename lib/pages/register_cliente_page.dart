import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import '../utils/ecuador_mobile_phone.dart';
import '../utils/ry_snackbar.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_text_field.dart';
import '../services/auth_service.dart';
import '../router/route_names.dart';

class RegisterClientePage extends StatefulWidget {
  const RegisterClientePage({super.key});

  @override
  State<RegisterClientePage> createState() => _RegisterClientePageState();
}

class _RegisterClientePageState extends State<RegisterClientePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _telefonoController = TextEditingController();
  bool _acceptTerms = false;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _telefonoController.dispose();
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
          // El teléfono es FUNDAMENTAL: el almacén ganador lo necesita para
          // coordinar el pago y la entrega de tu repuesto.
          telefono: _telefonoController.text.trim(),
        );

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // Show success message
        mostrarSnackbarInfo(
          context,
          mensaje: '¡Cuenta creada exitosamente! Por favor verifica tu email.',
          duracion: const Duration(seconds: 3),
        );

        // Navigate back to login
        context.goNamed(RouteNames.login);
      } catch (e) {
        AppLogger.error(
          'Error al registrar cliente',
          name: 'RegisterClientePage',
          error: e,
        );

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // Show error message
        mostrarSnackbarError(
          context,
          mensaje: ApiErrorHandler.userMessage(e),
          duracion: const Duration(seconds: 3),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.spacingMd,
              AppSpacing.spacingXs,
              AppSpacing.spacingMd,
              AppSpacing.spacingLg,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Section
                _buildLogoSection(),
                const SizedBox(height: AppSpacing.spacingLg),
                // Registration Form Card
                _buildRegistrationForm(),
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
          child: const Icon(Icons.person, size: 50, color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.spacingLg),
        Text(
          'Registro de Cliente',
          style: AppTextStyles.textStyleHeading.copyWith(
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        Text(
          'Crea tu cuenta para buscar y cotizar repuestos.',
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
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name Field
            _buildNameField(),
            const SizedBox(height: AppSpacing.spacingSm),
            // Email Field
            _buildEmailField(),
            const SizedBox(height: AppSpacing.spacingSm),
            // Teléfono (obligatorio: el almacén ganador lo usa para coordinar
            // el pago y la entrega del repuesto)
            _buildTelefonoField(),
            const SizedBox(height: AppSpacing.spacingSm),
            // Password Field
            _buildPasswordField(),
            const SizedBox(height: AppSpacing.spacingSm),
            // Confirm Password Field
            _buildConfirmPasswordField(),
            const SizedBox(height: AppSpacing.spacingSm),
            // Accept Terms
            _buildAcceptTerms(),
            const SizedBox(height: AppSpacing.spacingMd),
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
      isDense: true,
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
      label: 'Correo electrónico',
      hint: 'nombre@empresa.com',
      controller: _emailController,
      type: RyTextFieldType.email,
      isDense: true,
      isRequired: true,
      prefixIcon: Icons.mail,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Por favor ingrese su correo electrónico';
        }
        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
        if (!emailRegex.hasMatch(value.trim())) {
          return 'Por favor ingrese un correo electrónico válido';
        }
        return null;
      },
    );
  }

  Widget _buildTelefonoField() {
    return RyTextField(
      label: 'Teléfono',
      hint: 'Ej: 981894367',
      controller: _telefonoController,
      type: RyTextFieldType.phone,
      isDense: true,
      keyboardType: TextInputType.phone,
      inputFormatters: ecuadorMobilePhoneInputFormatters(),
      isRequired: true,
      prefixWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.phone_android, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.spacingXs),
          Text(
            '+593',
            style: AppTextStyles.textStyleBody.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.spacingXs),
          Container(width: 1, height: 24, color: AppColors.outlineVariant),
        ],
      ),
      helperText:
          'El almacén ganador lo usará para coordinar el pago y la entrega.',
      helperStyle: AppTextStyles.textStyleCaption.copyWith(
        color: AppColors.onSurfaceVariant,
      ),
      helperMaxLines: 3,
      validator: (value) {
        return validarTelefonoMovilEcuador(value);
      },
    );
  }

  Widget _buildPasswordField() {
    return RyTextField(
      label: 'Contraseña',
      hint: '••••••••',
      controller: _passwordController,
      type: RyTextFieldType.password,
      isDense: true,
      isRequired: true,
      prefixIcon: Icons.lock,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
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
      isDense: true,
      isRequired: true,
      prefixIcon: Icons.lock_outline,
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
        const SizedBox(height: AppSpacing.spacingLg),
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
}
