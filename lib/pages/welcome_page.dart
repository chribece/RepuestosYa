import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_page.dart';
import 'role_selection_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  // Color scheme - Industrial Dark Theme
  static const Color background = Color(0xFF131313);
  static const Color primary = Color(0xFFFFB5A0);
  static const Color primaryContainer = Color(0xFFFF5722);
  static const Color onPrimaryContainer = Color(0xFF541200);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFE4BEB4);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color outlineVariant = Color(0xFF5B4039);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Container(
        decoration: const BoxDecoration(color: background),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Section
                _buildLogoSection(),
                const SizedBox(height: 48),
                // Welcome Text
                _buildWelcomeText(),
                const SizedBox(height: 64),
                // Action Buttons
                _buildActionButtons(),
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
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryContainer.withOpacity(0.15),
            border: Border.all(
              color: primaryContainer.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: const Icon(Icons.build, size: 60, color: primary),
        ),
        const SizedBox(height: 32),
        Text(
          'RepuestosYa',
          style: GoogleFonts.sora(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: onSurface,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        const Text(
          'Tu socio estratégico en\nrepuestos automotrices',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: onSurface,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'Conectamos clientes y almacenes con\nprecisión, velocidad y confianza.',
          style: TextStyle(fontSize: 16, color: onSurfaceVariant, height: 1.5),
          textAlign: TextAlign.center,
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryContainer,
              foregroundColor: onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login, size: 24),
                SizedBox(width: 12),
                Text(
                  'Iniciar sesión con cuenta RepuestosYa',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: outlineVariant, width: 1.5),
          ),
          child: OutlinedButton(
            onPressed: () {
              // Navigate to role selection for registration
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RoleSelectionPage(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: onSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide.none,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add, size: 24),
                SizedBox(width: 12),
                Text(
                  'Crear nueva cuenta',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
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
                const Icon(Icons.verified, size: 18, color: onSurfaceVariant),
                const SizedBox(width: 6),
                const Text(
                  'Certificado ISO 9001',
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Container(width: 1, height: 16, color: outlineVariant),
            const SizedBox(width: 24),
            Row(
              children: [
                const Icon(Icons.security, size: 18, color: onSurfaceVariant),
                const SizedBox(width: 6),
                const Text(
                  'SSL Secure',
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            '© 2024 RepuestosYa S.A. Todos los derechos reservados.',
            style: TextStyle(fontSize: 12, color: onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
