import 'package:flutter/gestures.dart';
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
  late final TapGestureRecognizer _tapTerminos = TapGestureRecognizer()
    ..onTap = _mostrarTerminos;
  late final TapGestureRecognizer _tapLogin = TapGestureRecognizer()
    ..onTap = _irALogin;
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();
  final _registrarKey = GlobalKey();
  double _keyboardInset = 0;

  List<TextEditingController> get _camposObligatorios => [
    _nameController,
    _emailController,
    _telefonoController,
    _passwordController,
    _confirmPasswordController,
  ];

  bool get _puedeRegistrar =>
      _acceptTerms &&
      _camposObligatorios.every((c) => c.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    for (final c in _camposObligatorios) {
      c.addListener(_actualizarEstado);
    }
    _passwordFocusNode.addListener(_alEnfocarContrasena);
    _confirmFocusNode.addListener(_alEnfocarContrasena);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Al aparecer el teclado con un campo de contraseña enfocado, desplaza el
    // scroll para que el botón Registrarse quede sobre el teclado.
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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _telefonoController.dispose();
    _tapTerminos.dispose();
    _tapLogin.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  void _actualizarEstado() => setState(() {});

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
    if (!_acceptTerms) {
      mostrarSnackbarError(
        context,
        mensaje: 'Debes aceptar los términos y condiciones para continuar.',
      );
      return;
    }
    _formKey.currentState?.validate();
  }

  TextStyle get _estiloLegal => AppTextStyles.textStyleCaption.copyWith(
    color: AppColors.onSurfaceVariant,
  );

  Widget _tituloLegal(String texto) => Padding(
    padding: const EdgeInsets.only(
      top: AppSpacing.spacingMd,
      bottom: AppSpacing.spacingXs,
    ),
    child: Text(
      texto,
      style: _estiloLegal.copyWith(
        color: AppColors.onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _parrafoLegal(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.spacingXs),
    child: Text(texto, style: _estiloLegal),
  );

  Widget _vinetaLegal(String texto) => Padding(
    padding: const EdgeInsets.only(
      left: AppSpacing.spacingXs,
      bottom: AppSpacing.spacingXxs,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('•  ', style: _estiloLegal),
        Expanded(child: Text(texto, style: _estiloLegal)),
      ],
    ),
  );

  void _irALogin() => context.goNamed(RouteNames.login);

  void _mostrarTerminos() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: Text(
          'Términos y condiciones de uso',
          style: AppTextStyles.textStyleTitle.copyWith(
            color: AppColors.onSurface,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TÉRMINOS Y CONDICIONES DE USO – RepuestosYa',
                style: _estiloLegal.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _parrafoLegal('Última actualización: Noviembre 2026'),
              _parrafoLegal(
                'Al utilizar la plataforma RepuestosYa, el Usuario acepta estos Términos y Condiciones.',
              ),
              _tituloLegal('1. Condiciones de uso'),
              _parrafoLegal('El Usuario se compromete a:'),
              _vinetaLegal(
                'Utilizar la plataforma de forma lícita y respetuosa.',
              ),
              _vinetaLegal(
                'No enviar mensajes falsos, difamatorios, insultantes, abusivos, pornográficos o que dañen a terceros.',
              ),
              _vinetaLegal(
                'Garantizar la veracidad de los datos personales que proporcione.',
              ),
              _vinetaLegal(
                'Ser responsable de toda la actividad realizada desde su cuenta.',
              ),
              _parrafoLegal(
                'Queda prohibido recabar datos con fines publicitarios, enviar publicidad no autorizada o publicar contenidos ilícitos, discriminatorios, violentos, falsos o que vulneren derechos de terceros.',
              ),
              _tituloLegal('2. Propiedad intelectual'),
              _parrafoLegal(
                'Todos los contenidos de la plataforma (textos, imágenes, logos, software, interfaces, etc.) son propiedad de RepuestosYa. El uso de la plataforma no otorga ningún derecho de explotación sobre dichos contenidos ni sobre las marcas de RepuestosYa.',
              ),
              _tituloLegal('3. Limitación de responsabilidad'),
              _parrafoLegal('RepuestosYa no será responsable por:'),
              _vinetaLegal(
                'Fallos de acceso o falta de exactitud de los contenidos.',
              ),
              _vinetaLegal('Virus o daños en los sistemas del Usuario.'),
              _vinetaLegal(
                'Incumplimientos legales o de las políticas de la plataforma.',
              ),
              _vinetaLegal(
                'Información o sitios externos a los que se pueda acceder desde la plataforma.',
              ),
              _tituloLegal('4. Enlaces de terceros'),
              _parrafoLegal(
                'Los enlaces a sitios de terceros se incluyen solo con fines informativos. RepuestosYa no controla ni se responsabiliza por su contenido ni por los daños que puedan derivarse de su uso.',
              ),
              _tituloLegal('5. Validación de cuentas (solo Almacenes)'),
              _parrafoLegal(
                'Para crear una cuenta como Almacén (proveedor) podrá requerirse una verificación de autenticidad que puede demorar hasta 48 horas. Una vez aprobada, se habilitarán las funcionalidades correspondientes.',
              ),
              _tituloLegal('6. Funcionamiento del Marketplace'),
              _parrafoLegal(
                'RepuestosYa es un marketplace de repuestos automotrices que conecta a clientes con almacenes.',
              ),
              _vinetaLegal('El cliente solicita un repuesto.'),
              _vinetaLegal('Los almacenes verificados envían propuestas.'),
              _vinetaLegal('El cliente elige la opción que prefiera.'),
              _vinetaLegal(
                'Los pagos no se realizan a través de RepuestosYa. El cliente y el almacén coordinan el pago y la entrega de forma directa.',
              ),
              _vinetaLegal('Existe un chat interno para coordinar detalles.'),
              _vinetaLegal(
                'El almacén puede cancelar una orden si no puede despacharla, notificando al cliente.',
              ),
              _vinetaLegal(
                'El cliente podrá calificar al almacén una vez finalizada la transacción.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryContainer,
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
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
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) {
                // Desvanece solo el borde superior (24 px): el avatar se
                // esfuma al subir en vez de cortarse contra el techo.
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
          },
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
      focusNode: _confirmFocusNode,
      type: RyTextFieldType.password,
      isDense: true,
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
            child: RichText(
              textScaler: MediaQuery.textScalerOf(context),
              text: TextSpan(
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                children: [
                  const TextSpan(text: 'Acepto los '),
                  TextSpan(
                    text: 'términos y condiciones de uso',
                    recognizer: _tapTerminos,
                    style: AppTextStyles.textStyleCaption.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _puedeRegistrar || _isLoading
              ? null
              : _validarAntesDeRegistrar,
          child: RyButton(
            key: _registrarKey,
            label: 'Registrarse',
            trailingIcon: Icons.person_add,
            variant: RyButtonVariant.primary,
            size: RyButtonSize.large,
            isFullWidth: true,
            isLoading: _isLoading,
            isDisabled: !_puedeRegistrar,
            onPressed: _handleRegistration,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingLg),
        Center(
          child: RichText(
            textAlign: TextAlign.center,
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
              style: AppTextStyles.textStyleButton.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              children: [
                const TextSpan(text: '¿Ya tienes cuenta? '),
                TextSpan(
                  text: 'Inicia sesión',
                  recognizer: _tapLogin,
                  style: TextStyle(
                    color: AppColors.primaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
