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
import '../widgets/ecuador_phone_prefix.dart';
import '../widgets/ry_text_field.dart';
import '../services/auth_service.dart';
import '../router/route_names.dart';

class _BorradorRegistroAlmacen {
  String nombre = '';
  String correo = '';
  String telefono = '';

  void limpiar() {
    nombre = '';
    correo = '';
    telefono = '';
  }
}

// Sobrevive a la navegación dentro de la sesión de la app. Las contraseñas no
// se guardan aquí.
final _borradorAlmacen = _BorradorRegistroAlmacen();

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
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();
  final _registrarKey = GlobalKey();
  double _keyboardInset = 0;

  List<TextEditingController> get _camposObligatorios => [
    _representanteController,
    _emailController,
    _telefonoController,
    _passwordController,
    _confirmPasswordController,
  ];

  bool get _puedeRegistrar =>
      _camposObligatorios.every((c) => c.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    _representanteController.text = _borradorAlmacen.nombre;
    _emailController.text = _borradorAlmacen.correo;
    _telefonoController.text = _borradorAlmacen.telefono;
    for (final c in _camposObligatorios) {
      c.addListener(_actualizarEstado);
    }
    _representanteController.addListener(_guardarBorrador);
    _emailController.addListener(_guardarBorrador);
    _telefonoController.addListener(_guardarBorrador);
    _passwordFocusNode.addListener(_alEnfocarContrasena);
    _confirmFocusNode.addListener(_alEnfocarContrasena);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset > _keyboardInset && _hayFocusEnContrasena) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _mostrarBotonSobreTeclado(),
      );
    }
    _keyboardInset = inset;
  }

  @override
  void dispose() {
    _representanteController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _telefonoController.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  void _actualizarEstado() => setState(() {});

  void _guardarBorrador() {
    _borradorAlmacen
      ..nombre = _representanteController.text
      ..correo = _emailController.text
      ..telefono = _telefonoController.text;
  }

  bool get _hayFocusEnContrasena =>
      _passwordFocusNode.hasFocus || _confirmFocusNode.hasFocus;

  void _alEnfocarContrasena() {
    if (_hayFocusEnContrasena) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _mostrarBotonSobreTeclado(),
      );
    }
  }

  void _mostrarBotonSobreTeclado() {
    final contexto = _registrarKey.currentContext;
    if (contexto == null) return;
    Scrollable.ensureVisible(
      contexto,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: 1.0,
    );
  }

  void _validarAntesDeRegistrar() {
    _formKey.currentState?.validate();
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
        _borradorAlmacen.limpiar();
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
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) {
                final fade = (AppSpacing.spacingLg / rect.height).clamp(
                  0.0,
                  0.5,
                );
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                  ],
                  stops: [0, fade, 1],
                ).createShader(rect);
              },
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spacingMd,
                  vertical: AppSpacing.spacingLg,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        (constraints.maxHeight - 2 * AppSpacing.spacingLg)
                            .clamp(0.0, double.infinity),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildWelcomeText(),
                            const SizedBox(height: AppSpacing.spacingLg),
                            _buildFormCard(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
      label: 'Nombre del local o responsable',
      hint: 'Ej: Repuestos Don Juan',
      controller: _representanteController,
      type: RyTextFieldType.text,
      isDense: true,
      prefixIcon: Icons.person_outline,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Ingresa el nombre del responsable o establecimiento.';
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
      prefixWidget: const EcuadorPhonePrefix(),
      helperText: '9 dígitos sin el 0 inicial',
      helperStyle: AppTextStyles.textStyleCaption.copyWith(
        color: AppColors.onSurfaceVariant,
      ),
      helperMaxLines: 1,
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
      focusNode: _passwordFocusNode,
      type: RyTextFieldType.password,
      isDense: true,
      prefixIcon: Icons.lock_outline,
      helperText: 'Mínimo 6 caracteres.',
      helperStyle: AppTextStyles.textStyleCaption.copyWith(
        color: AppColors.onSurfaceVariant,
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
    );
  }

  Widget _buildConfirmPasswordField() {
    return RyTextField(
      label: 'Confirmar contraseña',
      hint: '••••••••',
      controller: _confirmPasswordController,
      focusNode: _confirmFocusNode,
      type: RyTextFieldType.password,
      isDense: true,
      prefixIcon: Icons.lock_outline,
      helperText: 'Debe coincidir con la contraseña anterior.',
      helperStyle: AppTextStyles.textStyleCaption.copyWith(
        color: AppColors.onSurfaceVariant,
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
    );
  }

  Widget _buildRegisterButton() {
    final puedeRegistrar = _puedeRegistrar;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: puedeRegistrar || _isSubmitting ? null : _validarAntesDeRegistrar,
      child: RyButton(
        key: _registrarKey,
        label: 'Continuar',
        trailingIcon: Icons.arrow_forward,
        variant: RyButtonVariant.primary,
        size: RyButtonSize.large,
        isFullWidth: true,
        isLoading: _isSubmitting,
        isDisabled: !puedeRegistrar,
        onPressed: _registrarAlmacen,
      ),
    );
  }
}
