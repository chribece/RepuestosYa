import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/almacen_service.dart';
import '../services/almacen_repository.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import '../providers/user_role_provider.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_text_field.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../router/route_names.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  // Mensaje de error de inicio de sesión mostrado dentro del formulario,
  // debajo del campo contraseña. Se limpia automáticamente cuando el usuario
  // edita correo o contraseña.
  String? _loginError;
  final AuthService _authService = AuthService();
  late final AlmacenService _almacenService;

  @override
  void initState() {
    super.initState();
    _almacenService = AlmacenService(context.read<AlmacenRepository>());
    // Limpiar el error de login en cuanto el usuario toque cualquier campo.
    _emailController.addListener(_clearLoginError);
    _passwordController.addListener(_clearLoginError);
  }

  @override
  void dispose() {
    _emailController.removeListener(_clearLoginError);
    _passwordController.removeListener(_clearLoginError);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearLoginError() {
    if (_loginError != null) {
      setState(() => _loginError = null);
    }
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Iniciar sesión
        await _authService.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Obtener el ID del usuario autenticado
        final user = _authService.currentUser;
        if (user == null) {
          throw Exception('No se pudo obtener el usuario autenticado');
        }

        if (!mounted) return;

        // Cargar el rol del usuario en el provider inmediatamente desde la respuesta de login
        final userRoleProvider = Provider.of<UserRoleProvider>(
          context,
          listen: false,
        );
        userRoleProvider.setRoleFromString(user.rol);

        // Si por alguna razón el rol en el token es nulo o unknown, intentamos cargar desde API
        if (userRoleProvider.isUnknown) {
          await userRoleProvider.loadUserRole(user.id);
        }

        // Verificar si se obtuvo el rol correctamente
        if (userRoleProvider.isUnknown) {
          throw Exception(
            'No se pudo determinar el rol del usuario. Contacte al administrador.',
          );
        }

        if (!mounted) return;

        // Con GoRouter + refreshListenable, el router detectará el cambio de estado
        // y redirigirá automáticamente según el rol.
        // Solo necesitamos manejar el caso de CompleteProfilePage para almacenes.

        if (userRoleProvider.isAlmacen) {
          try {
            final hasProfile = await _almacenService.hasWarehouseProfile();
            if (!mounted) return;
            setState(() => _isLoading = false);
            if (!hasProfile) {
              AppLogger.info(
                'Almacén sin perfil comercial. Redirigiendo a CompleteProfilePage.',
                name: 'LoginPage',
              );
              context.goNamed(RouteNames.completeProfile);
              return;
            }
          } catch (e) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            AppLogger.error(
              'Error al validar perfil de almacén post-login',
              name: 'LoginPage',
              error: e,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No se pudo verificar tu perfil de almacén: '
                  '${ApiErrorHandler.userMessage(e)}',
                ),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 4),
              ),
            );
            return;
          }
        }

        setState(() => _isLoading = false);
        // Si no es un caso especial, dejamos que el redirect global actúe
        // o forzamos la navegación a Home si no hay redirect pendiente.
        final String? from = GoRouterState.of(
          context,
        ).uri.queryParameters['from'];
        if (from != null && from != '/welcome') {
          context.go(from);
        } else {
          // El redirect global se encargará
        }
      } catch (e) {
        if (!mounted) return;

        // Traducir el error con contexto de Login: un 401 aquí significa
        // credenciales inválidas, no sesión expirada.
        final friendly = ApiErrorHandler.userMessage(
          e,
          context: ApiErrorContext.auth,
        );
        AppLogger.error(
          'Error en inicio de sesión',
          name: 'LoginPage',
          error: e,
        );
        setState(() {
          _isLoading = false;
          _loginError = friendly;
        });
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
                _buildLogoSection(),
                const SizedBox(height: AppSpacing.spacingXl),
                _buildLoginForm(),
                const SizedBox(height: AppSpacing.spacingXl),
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
          child: Icon(Icons.build, size: 50, color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.spacingLg),
        Text('Bienvenido', style: AppTextStyles.textStyleHeading),
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

  Widget _buildLoginForm() {
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
            _buildEmailField(),
            const SizedBox(height: AppSpacing.spacingMd),
            _buildPasswordField(),
            if (_loginError != null) ...[
              const SizedBox(height: AppSpacing.spacingSm),
              _buildLoginError(),
            ],
            const SizedBox(height: AppSpacing.spacingMd),
            _buildRememberMe(),
            const SizedBox(height: AppSpacing.spacingLg),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// Mensaje de error de inicio de sesión, dentro del formulario y debajo del
  /// campo contraseña. Usa `Semantics(liveRegion: true)` para que los lectores
  /// de pantalla anuncien el error automáticamente cuando aparece.
  Widget _buildLoginError() {
    return Semantics(
      liveRegion: true,
      label: 'Error de inicio de sesión: $_loginError',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXxs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              size: 18,
              color: SemanticColors.colorErrorText,
            ),
            const SizedBox(width: AppSpacing.spacingXs),
            Expanded(
              child: Text(
                _loginError!,
                style: AppTextStyles.textStyleCaption.copyWith(
                  color: SemanticColors.colorErrorText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return RyTextField(
      label: 'Email corporativo / Usuario',
      hint: 'nombre@empresa.com',
      type: RyTextFieldType.email,
      prefixIcon: Icons.mail,
      controller: _emailController,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor ingrese su email';
        }
        if (!value.contains('@')) {
          return 'Por favor ingrese un email válido';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Contraseña',
              style: AppTextStyles.textStyleSmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: () {
                // TODO: Implement forgot password
              },
              child: Text(
                '¿Olvidó su clave?',
                style: AppTextStyles.textStyleSmall.copyWith(
                  color: AppColors.tertiaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        RyTextField(
          hint: '••••••••',
          type: RyTextFieldType.password,
          prefixIcon: Icons.lock,
          controller: _passwordController,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor ingrese su contraseña';
            }
            if (value.length < 6) {
              return 'La contraseña debe tener al menos 6 caracteres';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildRememberMe() {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: (value) {
            setState(() {
              _rememberMe = value ?? false;
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
        Text(
          'Recordar sesión en este equipo',
          style: AppTextStyles.textStyleCaption.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        RyButton(
          label: 'INGRESAR',
          icon: Icons.bolt,
          variant: RyButtonVariant.primary,
          size: RyButtonSize.large,
          isLoading: _isLoading,
          isFullWidth: true,
          onPressed: _handleLogin,
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        Center(
          child: RyButton(
            label: '¿Aún no tienes cuenta? Regístrate',
            variant: RyButtonVariant.text,
            onPressed: () {
              context.pushNamed(RouteNames.roleSelection);
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
                Icon(
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
                Icon(
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
            '© 2026 VCore Tech S.A. Todos los derechos reservados.',
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
