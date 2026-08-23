import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'role_selection_page.dart';
import 'home_page.dart';
import 'warehouse_dashboard.dart';
import 'complete_profile_page.dart';
import '../services/auth_service.dart';
import '../services/almacen_service.dart';
import '../utils/app_logger.dart';
import '../providers/user_role_provider.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_text_field.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

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
  final AuthService _authService = AuthService();
  final AlmacenService _almacenService = AlmacenService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

        // Cargar el rol del usuario desde la base de datos
        final userRoleProvider = Provider.of<UserRoleProvider>(
          context,
          listen: false,
        );
        await userRoleProvider.loadUserRole(user.id);

        // Verificar si se obtuvo el rol correctamente
        if (userRoleProvider.isUnknown) {
          throw Exception(
            'No se pudo determinar el rol del usuario. Contacte al administrador.',
          );
        }

        if (!mounted) return;

        // Navegar según el rol del usuario con animación suave.
        // Para rol almacen, validar primero que exista el perfil comercial
        // (GET /warehouse/my-warehouse). Si responde 404, redirigir a
        // CompleteProfilePage en lugar de WarehouseDashboard para evitar
        // que se disparen /requests/active y /quotations/my-quotations
        // contra un usuario sin almacén (que devuelven 404).
        if (userRoleProvider.isCliente) {
          setState(() => _isLoading = false);
          _navigateTo(const HomePage());
        } else if (userRoleProvider.isAlmacen) {
          try {
            final hasProfile = await _almacenService.hasWarehouseProfile();
            if (!mounted) return;
            setState(() => _isLoading = false);
            if (hasProfile) {
              _navigateTo(const WarehouseDashboard());
            } else {
              AppLogger.info(
                'Almacén sin perfil comercial. Redirigiendo a CompleteProfilePage.',
                name: 'LoginPage',
              );
              _navigateTo(const CompleteProfilePage());
            }
          } catch (e) {
            // Error distinto de 404 (401/403/500/timeout/red): mostrar al
            // usuario en lugar de adivinar. No redirige al dashboard.
            if (!mounted) return;
            setState(() => _isLoading = false);
            AppLogger.error(
              'Error al validar perfil de almacén post-login',
              name: 'LoginPage',
              error: e,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No se pudo verificar tu perfil de almacén: $e'),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } else if (userRoleProvider.isAdmin) {
          // Para admin, también navegar al dashboard de almacén por ahora
          setState(() => _isLoading = false);
          _navigateTo(const WarehouseDashboard());
        } else {
          setState(() => _isLoading = false);
        }
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // Mostrar mensaje de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Reemplaza la pantalla actual con fade transition (250 ms), patrón
  /// usado para todas las navegaciones post-login.
  void _navigateTo(Widget page) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
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
            const SizedBox(height: AppSpacing.spacingMd),
            _buildRememberMe(),
            const SizedBox(height: AppSpacing.spacingLg),
            _buildActionButtons(),
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RoleSelectionPage(),
                ),
              );
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
