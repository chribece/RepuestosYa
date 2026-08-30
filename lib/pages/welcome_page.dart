import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/ry_button.dart';
import '../router/route_names.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
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
                const SizedBox(height: AppSpacing.spacingXxl),
                // Welcome Text
                _buildWelcomeText(),
                const SizedBox(height: AppSpacing.spacingXxxl),
                // Action Buttons
                _buildActionButtons(),
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
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryContainer.withValues(alpha: 0.15),
            border: Border.all(
              color: AppColors.primaryContainer.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: const Icon(Icons.build, size: 60, color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.spacingXl),
        Text(
          'RepuestosYa',
          style: AppTextStyles.textStyleDisplay.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Tu socio estratégico en\nrepuestos automotrices',
          style: AppTextStyles.textStyleHeading.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        Text(
          'Conectamos clientes y almacenes con\nprecisión, velocidad y confianza.',
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        RyButton(
          label: 'Iniciar sesión con cuenta RepuestosYa',
          icon: Icons.login,
          variant: RyButtonVariant.primary,
          size: RyButtonSize.large,
          isFullWidth: true,
          onPressed: () {
            context.pushNamed(RouteNames.login);
          },
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        RyButton(
          label: 'Crear nueva cuenta',
          icon: Icons.person_add,
          variant: RyButtonVariant.outline,
          size: RyButtonSize.large,
          isFullWidth: true,
          onPressed: () {
            // Navigate to role selection for registration
            context.pushNamed(RouteNames.roleSelection);
          },
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
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.spacingXs),
                Text(
                  'Certificado ISO 9001',
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.spacingLg),
            Container(width: 1, height: 16, color: AppColors.outlineVariant),
            const SizedBox(width: AppSpacing.spacingLg),
            Row(
              children: [
                const Icon(
                  Icons.security,
                  size: 18,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.spacingXs),
                Text(
                  'SSL Secure',
                  style: AppTextStyles.textStyleSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spacingLg),
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
