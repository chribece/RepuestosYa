import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'registration_page.dart';
import 'home_page.dart';
import '../services/auth_service.dart';

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

  // Color scheme from HTML
  static const Color primary = Color(0xFFFFB5A0);
  static const Color primaryContainer = Color(0xFFFF5722);
  static const Color onPrimaryContainer = Color(0xFF541200);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color outlineVariant = Color(0xFF5B4039);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFE4BEB4);
  static const Color tertiaryContainer = Color(0xFF019AD8);
  static const Color secondaryContainer = Color(0xFF1E95F2);
  static const Color background = Color(0xFF131313);

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
        await _authService.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        setState(() {
          _isLoading = false;
        });

        // Navigate to home page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Container(
        decoration: const BoxDecoration(
          color: background,
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Section
                _buildLogoSection(),
                const SizedBox(height: 32),
                // Login Form Card
                _buildLoginForm(),
                const SizedBox(height: 32),
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
            color: primaryContainer.withOpacity(0.2),
          ),
          child: const Icon(
            Icons.build,
            size: 50,
            color: primary,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Bienvenido',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: onSurface,
            fontFamily: 'Sora',
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Performance y precisión en cada pieza.',
          style: TextStyle(
            fontSize: 16,
            color: onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Email Field
            _buildEmailField(),
            const SizedBox(height: 16),
            // Password Field
            _buildPasswordField(),
            const SizedBox(height: 16),
            // Remember Me
            _buildRememberMe(),
            const SizedBox(height: 24),
            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email corporativo / Usuario',
          style: TextStyle(
            fontSize: 12,
            color: onSurfaceVariant,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: surfaceContainerHigh,
            hintText: 'nombre@empresa.com',
            hintStyle: const TextStyle(color: onSurfaceVariant),
            prefixIcon: const Icon(Icons.mail, color: onSurfaceVariant),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: primaryContainer, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor ingrese su email';
            }
            if (!value.contains('@')) {
              return 'Por favor ingrese un email válido';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Contraseña',
              style: TextStyle(
                fontSize: 12,
                color: onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            TextButton(
              onPressed: () {
                // TODO: Implement forgot password
              },
              child: const Text(
                '¿Olvidó su clave?',
                style: TextStyle(
                  fontSize: 12,
                  color: tertiaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: surfaceContainerHigh,
            hintText: '••••••••',
            hintStyle: const TextStyle(color: onSurfaceVariant),
            prefixIcon: const Icon(Icons.lock, color: onSurfaceVariant),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: primaryContainer, width: 2),
            ),
          ),
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
          fillColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return primaryContainer;
            }
            return surfaceContainerHigh;
          }),
          checkColor: const Color(0xFFFFFFFF),
        ),
        const Text(
          'Recordar sesión en este equipo',
          style: TextStyle(
            fontSize: 14,
            color: onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryContainer,
              foregroundColor: onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(onPrimaryContainer),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'INGRESAR',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.bolt),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegistrationPage()),
              );
            },
            child: const Text(
              'Crear cuenta',
              style: TextStyle(
                fontSize: 18,
                color: secondaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                  color: onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Certificado ISO 9001',
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Container(
              width: 1,
              height: 16,
              color: outlineVariant,
            ),
            const SizedBox(width: 16),
            Row(
              children: [
                const Icon(
                  Icons.security,
                  size: 18,
                  color: onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                const Text(
                  'SSL Secure',
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            '© 2024 RepuestosYa S.A. Todos los derechos reservados. El acceso no autorizado a este sistema técnico está prohibido.',
            style: TextStyle(
              fontSize: 12,
              color: onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
