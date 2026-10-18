import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
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
  final TextEditingController _telefonoController = TextEditingController();

  bool _isSubmitting = false;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _representanteController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _telefonoController.dispose();
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
        // Teléfono de contacto del almacén (se prellena en el perfil).
        telefono: _telefonoController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        mostrarSnackbarInfo(
          context,
          mensaje: '¡Registro exitoso! Ahora completa tu perfil.',
          duracion: const Duration(seconds: 2),
        );
        // Navegar a la página de completar perfil
        context.goNamed(RouteNames.completeProfile);
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
        mostrarSnackbarError(context, mensaje: ApiErrorHandler.userMessage(e));
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
          tooltip: 'Regresar',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Registro de Almacén',
          style: AppTextStyles.textStyleTitle.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.spacingMd,
            AppSpacing.spacingSm,
            AppSpacing.spacingMd,
            AppSpacing.spacingLg,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeText(),
                const SizedBox(height: AppSpacing.spacingLg),
                _buildRepresentanteField(),
                const SizedBox(height: AppSpacing.spacingMd),
                _buildEmailField(),
                const SizedBox(height: AppSpacing.spacingMd),
                _buildTelefonoField(),
                const SizedBox(height: AppSpacing.spacingMd),
                _buildPasswordField(),
                const SizedBox(height: AppSpacing.spacingMd),
                _buildConfirmPasswordField(),
                const SizedBox(height: AppSpacing.spacingLg),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryContainer.withValues(alpha: 0.16),
            border: Border.all(
              color: AppColors.primaryContainer.withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            Icons.storefront,
            size: 42,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        Text(
          'Ingresa tus datos básicos para comenzar el registro de tu establecimiento.',
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRepresentanteField() {
    return RyTextField(
      label: 'Nombre completo',
      hint: 'Ej: Juan Pérez',
      controller: _representanteController,
      type: RyTextFieldType.text,
      isDense: true,
      isRequired: true,
      prefixIcon: Icons.person_outline,
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
      label: 'Correo electrónico',
      hint: 'Ej: contacto@repuestosya.com',
      controller: _emailController,
      type: RyTextFieldType.email,
      isDense: true,
      isRequired: true,
      prefixIcon: Icons.mail_outline,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'El correo electrónico es requerido';
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
      helperText: 'Número de contacto para coordinar solicitudes.',
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
      prefixIcon: Icons.lock_outline,
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
