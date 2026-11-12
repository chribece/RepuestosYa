import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_logo_badge.dart';
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.spacingMd,
              AppSpacing.spacingXs,
              AppSpacing.spacingMd,
              AppSpacing.spacingMd,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Section
                _buildLogoSection(),
                const SizedBox(height: AppSpacing.spacingLg),
                // Welcome Text
                _buildWelcomeText(),
                const SizedBox(height: AppSpacing.spacingLg),
                // Action Buttons
                _buildActionButtons(),
                const SizedBox(height: AppSpacing.spacingMd),
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryContainer.withValues(alpha: 0.35),
                blurRadius: 60,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const RyLogoBadge(size: 180),
        ),
        const SizedBox(height: AppSpacing.spacingMd),
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
          'El ecosistema inteligente de repuestos automotrices.',
          style: AppTextStyles.textStyleHeading.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        _buildDescription(),
      ],
    );
  }

  Widget _buildDescription() {
    final bodyStyle = AppTextStyles.textStyleBody.copyWith(
      color: AppColors.onSurfaceVariant,
      height: 1.5,
    );
    final highlightStyle = bodyStyle.copyWith(
      color: AppColors.primaryContainer,
      fontWeight: FontWeight.bold,
    );
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: bodyStyle,
        children: [
          const TextSpan(text: 'Encuentra el '),
          TextSpan(text: 'repuesto exacto', style: highlightStyle),
          const TextSpan(text: ' en minutos, o '),
          TextSpan(text: 'conecta tu almacén', style: highlightStyle),
          const TextSpan(text: ' con miles de clientes en tiempo real.'),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        RyButton(
          label: 'Iniciar sesión',
          icon: Icons.person_outline,
          variant: RyButtonVariant.primary,
          size: RyButtonSize.large,
          isFullWidth: true,
          onPressed: () {
            context.pushNamed(RouteNames.login);
          },
        ),
        const SizedBox(height: AppSpacing.spacingSm),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingSm),
          child: Text(
            '© 2026 VCore Tech S.A. Todos los derechos reservados.',
            style: AppTextStyles.textStyleSmall.copyWith(
              color: Colors.white54,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
