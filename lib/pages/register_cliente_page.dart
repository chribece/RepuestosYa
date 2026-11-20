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
import '../widgets/ry_text_field.dart';
import '../services/auth_service.dart';
import '../router/route_names.dart';

enum _Fortaleza { debil, media, fuerte }

_Fortaleza _fortalezaDe(String clave) {
  if (clave.length < 6) return _Fortaleza.debil;
  if (clave.length >= 8 &&
      RegExp(r'\d').hasMatch(clave) &&
      RegExp(r'[A-Za-z]').hasMatch(clave)) {
    return _Fortaleza.fuerte;
  }
  return _Fortaleza.media;
}

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
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();
  final _registrarKey = GlobalKey();
  static const _scrollPadding = EdgeInsets.only(bottom: 160);
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

  ColorScheme get _cs => Theme.of(context).colorScheme;

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
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
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

  TextStyle get _estiloLegal =>
      AppTextStyles.textStyleCaption.copyWith(color: _cs.onSurfaceVariant);

  Widget _tituloLegal(String texto) => Padding(
    padding: const EdgeInsets.only(
      top: AppSpacing.spacingMd,
      bottom: AppSpacing.spacingXs,
    ),
    child: Text(
      texto,
      style: _estiloLegal.copyWith(
        color: _cs.onSurface,
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

  void _volver() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(RouteNames.roleSelection);
    }
  }

  void _mostrarTerminos() {
    final scroll = ScrollController();
    showDialog<void>(
      context: context,
      barrierColor: _cs.scrim.withValues(alpha: 0.85),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          side: BorderSide(color: AppColors.outlineVariant),
        ),
        title: Text(
          'Términos y condiciones de uso',
          style: AppTextStyles.textStyleTitle.copyWith(color: _cs.onSurface),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.sizeOf(dialogContext).height * 0.5,
          child: Stack(
            children: [
              Scrollbar(
                controller: scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: scroll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      _vinetaLegal(
                        'Virus o daños en los sistemas del Usuario.',
                      ),
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
                      _vinetaLegal(
                        'Los almacenes verificados envían propuestas.',
                      ),
                      _vinetaLegal('El cliente elige la opción que prefiera.'),
                      _vinetaLegal(
                        'Los pagos no se realizan a través de RepuestosYa. El cliente y el almacén coordinan el pago y la entrega de forma directa.',
                      ),
                      _vinetaLegal(
                        'Existe un chat interno para coordinar detalles.',
                      ),
                      _vinetaLegal(
                        'El almacén puede cancelar una orden si no puede despacharla, notificando al cliente.',
                      ),
                      _vinetaLegal(
                        'El cliente podrá calificar al almacén una vez finalizada la transacción.',
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _cs.surfaceContainerLow.withValues(alpha: 0),
                          _cs.surfaceContainerLow,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _cs.onSurfaceVariant),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _cs.primaryContainer,
              foregroundColor: _cs.onPrimaryContainer,
              textStyle: AppTextStyles.textStyleButton.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () {
              setState(() => _acceptTerms = true);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Leer y aceptar'),
          ),
        ],
      ),
    ).whenComplete(scroll.dispose);
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
      backgroundColor: _cs.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: _cs.surface,
        elevation: 0,
        leading: Semantics(
          label: 'Volver',
          button: true,
          child: IconButton(
            onPressed: _volver,
            icon: Icon(Icons.arrow_back, color: _cs.onSurface),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_buildRegistrationForm()],
          ),
        ),
      ),
    );
  }

  Widget _buildCabecera() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Registro de Cliente',
          textAlign: TextAlign.center,
          style: AppTextStyles.textStyleTitle.copyWith(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: _cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Crea tu cuenta para buscar y cotizar repuestos',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.textStyleBody.copyWith(
            fontSize: 13.5,
            color: _cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // Inputs del formulario: fondo de input, borde de reposo ≥3:1 y foco naranja.
  ThemeData _temaFormulario(BuildContext context) {
    final base = Theme.of(context);
    OutlineInputBorder borde(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          borderSide: BorderSide(color: color, width: width),
        );
    return base.copyWith(
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        hintStyle: AppTextStyles.textStyleCaption.copyWith(
          color: base.colorScheme.onSurfaceVariant,
        ),
        border: borde(AppColors.controlBorder),
        enabledBorder: borde(AppColors.controlBorder),
        focusedBorder: borde(base.colorScheme.primaryContainer, width: 1.5),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 28),
          decoration: BoxDecoration(
            color: _cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            border: Border.all(
              color: _cs.primaryContainer.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _cs.primaryContainer.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 38, 16, 16),
          child: Theme(
            data: _temaFormulario(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _buildCabecera()),
                  const SizedBox(height: 16),
                  _buildNameField(),
                  const SizedBox(height: 12),
                  _buildEmailField(),
                  const SizedBox(height: 12),
                  // Teléfono (obligatorio: el almacén ganador lo usa para coordinar
                  // el pago y la entrega del repuesto)
                  _buildTelefonoField(),
                  const SizedBox(height: 12),
                  _buildPasswordField(),
                  if (_passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildFortaleza(),
                  ],
                  const SizedBox(height: 12),
                  _buildConfirmPasswordField(),
                  const SizedBox(height: 12),
                  _buildAcceptTerms(),
                  const SizedBox(height: AppSpacing.spacingMd),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(child: _buildAvatar()),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _cs.surfaceContainerLow,
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _cs.primaryContainer.withValues(alpha: 0.16),
          border: Border.all(color: _cs.primaryContainer, width: 1.5),
        ),
        child: Icon(
          Icons.person_outline_rounded,
          size: 28,
          color: _cs.primaryContainer,
        ),
      ),
    );
  }

  Widget _buildFortaleza() {
    final (texto, color, activos) = switch (_fortalezaDe(
      _passwordController.text,
    )) {
      _Fortaleza.debil => ('Débil', SemanticColors.colorErrorText, 1),
      _Fortaleza.media => ('Media', AppColors.warning, 2),
      _Fortaleza.fuerte => ('Fuerte', AppColors.success, 3),
    };
    return Semantics(
      excludeSemantics: true,
      label: 'Fortaleza de la contraseña: $texto',
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 3.5,
                      decoration: BoxDecoration(
                        color: i < activos
                            ? color
                            : _cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            texto,
            style: AppTextStyles.textStyleSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return RyTextField(
      label: 'Nombre completo',
      hint: 'Juan Pérez',
      controller: _nameController,
      focusNode: _nameFocusNode,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocusNode),
      scrollPadding: _scrollPadding,
      type: RyTextFieldType.text,
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
      focusNode: _emailFocusNode,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => FocusScope.of(context).requestFocus(_phoneFocusNode),
      scrollPadding: _scrollPadding,
      type: RyTextFieldType.email,
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

  int get _digitosTelefono => _telefonoController.text.length;

  // Ayuda del teléfono: guía cuando está vacío y contador n/9 mientras escribe.
  String get _textoContadorTelefono => _digitosTelefono == 0
      ? '9 dígitos sin el 0 inicial'
      : '$_digitosTelefono/$ecuadorMobilePhoneLength dígitos';

  TextStyle get _estiloContadorTelefono =>
      AppTextStyles.textStyleCaption.copyWith(
        fontSize: 12,
        color: _digitosTelefono == ecuadorMobilePhoneLength
            ? _cs.primaryContainer
            : _cs.onSurfaceVariant,
      );

  Widget _prefijoTelefono() => Semantics(
    label: 'Código telefónico de Ecuador, más 593',
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spacingXs,
        vertical: AppSpacing.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: _cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
        border: Border.all(color: AppColors.controlBorder),
      ),
      child: Text(
        '+593',
        style: AppTextStyles.textStyleSmall.copyWith(
          color: _cs.onSurface,
          letterSpacing: 0,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _buildTelefonoField() {
    return RyTextField(
      label: 'Teléfono',
      hint: 'Ej: 981894367',
      controller: _telefonoController,
      focusNode: _phoneFocusNode,
      type: RyTextFieldType.phone,
      keyboardType: TextInputType.number,
      inputFormatters: ecuadorMobilePhoneInputFormatters(),
      textInputAction: TextInputAction.next,
      onSubmitted: (_) =>
          FocusScope.of(context).requestFocus(_passwordFocusNode),
      scrollPadding: _scrollPadding,
      prefixWidget: _prefijoTelefono(),
      helperText: _textoContadorTelefono,
      helperStyle: _estiloContadorTelefono,
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
      textInputAction: TextInputAction.next,
      onSubmitted: (_) =>
          FocusScope.of(context).requestFocus(_confirmFocusNode),
      scrollPadding: _scrollPadding,
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
      textInputAction: TextInputAction.done,
      onSubmitted: (_) {
        FocusScope.of(context).unfocus();
        if (_puedeRegistrar && !_isLoading) _handleRegistration();
      },
      scrollPadding: _scrollPadding,
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
          side: BorderSide(color: AppColors.controlBorder, width: 1.8),
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return _cs.primaryContainer;
            }
            return AppColors.transparent;
          }),
          checkColor: _cs.onPrimaryContainer,
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
                  color: _cs.onSurfaceVariant,
                ),
                children: [
                  const TextSpan(text: 'Acepto los '),
                  TextSpan(
                    text: 'términos de uso',
                    recognizer: _tapTerminos,
                    style: AppTextStyles.textStyleCaption.copyWith(
                      color: _cs.primaryContainer,
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
            variant: RyButtonVariant.primary,
            size: RyButtonSize.large,
            isFullWidth: true,
            isLoading: _isLoading,
            isDisabled: !_puedeRegistrar,
            onPressed: _handleRegistration,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: RichText(
            textAlign: TextAlign.center,
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
              style: AppTextStyles.textStyleButton.copyWith(
                color: _cs.onSurfaceVariant,
              ),
              children: [
                const TextSpan(text: '¿Ya tienes cuenta? '),
                TextSpan(
                  text: 'Inicia sesión',
                  recognizer: _tapLogin,
                  style: TextStyle(
                    color: _cs.tertiaryContainer,
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
