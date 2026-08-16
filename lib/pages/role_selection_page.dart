import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'register_cliente_page.dart';
import 'register_almacen_page.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedRole;

  // Color scheme - Industrial Dark Theme
  static const Color background = Color(0xFF131313);
  static const Color primary = Color(0xFFFFB5A0);
  static const Color primaryContainer = Color(0xFFFF5722);
  static const Color onPrimaryContainer = Color(0xFF541200);
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFE4BEB4);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color outlineVariant = Color(0xFF5B4039);
  static const Color requiredAsterisk = Color(0xFFFF3333);

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
                const SizedBox(height: 32),
                // Role Selection Form
                _buildRoleSelectionForm(),
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
          child: const Icon(Icons.build, size: 50, color: primary),
        ),
        const SizedBox(height: 24),
        Text(
          'Cuéntanos quién eres',
          style: GoogleFonts.sora(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: onSurface,

          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Selecciona tu tipo de cuenta para continuar',
          style: GoogleFonts.sora(fontSize: 16, color: onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRoleSelectionForm() {
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
            // Role Dropdown
            _buildRoleDropdown(),
            const SizedBox(height: 24),
            // Continue Button
            _buildContinueButton(),
            const SizedBox(height: 16),
            // Back Button
            _buildBackButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Tipo de cuenta',
                style: GoogleFonts.sora(
                  fontSize: 12,
                  color: onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              TextSpan(
                text: ' *',
                style: GoogleFonts.sora(
                  fontSize: 12,
                  color: requiredAsterisk,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: InputBorder.none,
              ),
              dropdownColor: surfaceContainerHigh,
              style: GoogleFonts.sora(color: onSurface, fontSize: 16),
              icon: const Icon(Icons.expand_more, color: onSurfaceVariant),
              items: const [
                DropdownMenuItem(
                  value: 'Cliente',
                  child: Row(
                    children: [
                      Icon(Icons.person, color: primary, size: 20),
                      SizedBox(width: 12),
                      Text('Cliente'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'Almacén',
                  child: Row(
                    children: [
                      Icon(Icons.warehouse, color: primary, size: 20),
                      SizedBox(width: 12),
                      Text('Almacén'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRole = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor selecciona un tipo de cuenta';
                }
                return null;
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _handleContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: onPrimaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'CONTINUAR',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Center(
      child: TextButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: Text(
          'Volver',
          style: GoogleFonts.sora(fontSize: 16, color: onSurfaceVariant),
        ),
      ),
    );
  }

  void _handleContinue() {
    if (_formKey.currentState!.validate()) {
      if (_selectedRole == 'Cliente') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RegisterClientePage()),
        );
      } else if (_selectedRole == 'Almacén') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RegisterAlmacenPage()),
        );
      }
    }
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
            Container(width: 1, height: 16, color: outlineVariant),
            const SizedBox(width: 16),
            Row(
              children: [
                const Icon(Icons.security, size: 18, color: onSurfaceVariant),
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
            '© 2024 RepuestosYa S.A. Todos los derechos reservados.',
            style: TextStyle(fontSize: 12, color: onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
