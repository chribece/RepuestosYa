import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/ry_button.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(color: AppColors.background),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.spacingLg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Section
                _buildLogoSection(),
                const SizedBox(height: AppSpacing.spacingXl),
                // Role Selection Form
                _buildRoleSelectionForm(),
                const SizedBox(height: AppSpacing.spacingXl),
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
            color: AppColors.primaryContainer.withValues(alpha: 0.2),
          ),
          child: const Icon(Icons.build, size: 50, color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.spacingLg),
        Text(
          'Cuéntanos quién eres',
          style: AppTextStyles.textStyleHeading.copyWith(
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        Text(
          'Selecciona tu tipo de cuenta para continuar',
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRoleSelectionForm() {
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
            // Role Dropdown
            _buildRoleDropdown(),
            const SizedBox(height: AppSpacing.spacingLg),
            // Continue Button
            _buildContinueButton(),
            const SizedBox(height: AppSpacing.spacingMd),
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
                style: AppTextStyles.textStyleSmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: ' *',
                style: AppTextStyles.textStyleSmall.copyWith(
                  color: AppColors.requiredAsterisk,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.radiusSm),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.spacingMd,
                  vertical: AppSpacing.spacingSm,
                ),
                border: InputBorder.none,
              ),
              dropdownColor: AppColors.surfaceContainerHigh,
              style: AppTextStyles.textStyleBody.copyWith(
                color: AppColors.onSurface,
              ),
              icon: const Icon(
                Icons.expand_more,
                color: AppColors.onSurfaceVariant,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Cliente',
                  child: Row(
                    children: [
                      Icon(Icons.person, color: AppColors.primary, size: 20),
                      SizedBox(width: AppSpacing.spacingSm),
                      Text('Cliente'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'Almacén',
                  child: Row(
                    children: [
                      Icon(Icons.warehouse, color: AppColors.primary, size: 20),
                      SizedBox(width: AppSpacing.spacingSm),
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
    return RyButton(
      label: 'CONTINUAR',
      trailingIcon: Icons.arrow_forward,
      variant: RyButtonVariant.primary,
      size: RyButtonSize.large,
      isFullWidth: true,
      onPressed: _handleContinue,
    );
  }

  Widget _buildBackButton() {
    return Center(
      child: RyButton(
        label: 'Volver',
        variant: RyButtonVariant.text,
        onPressed: () {
          Navigator.pop(context);
        },
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
                const Icon(
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
                const Icon(
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
            '© 2024 RepuestosYa S.A. Todos los derechos reservados.',
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
