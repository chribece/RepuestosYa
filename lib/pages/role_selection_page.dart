import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_logo_badge.dart';
import '../router/route_names.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  String? _selectedRole;
  bool _showRoleError = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: context.pop,
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.spacingMd,
                  AppSpacing.spacingXs,
                  AppSpacing.spacingMd,
                  AppSpacing.spacingLg,
                ),
                child: Column(
                  children: [
                    _buildLogoSection(),
                    const SizedBox(height: AppSpacing.spacingLg),
                    _buildRoleSelectionForm(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        const RyLogoBadge(size: 160),
        const SizedBox(height: AppSpacing.spacingMd),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elige tu tipo de cuenta',
          style: AppTextStyles.textStyleTitle.copyWith(
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        _buildRoleCard(
          role: 'Cliente',
          description: 'Quiero encontrar y comprar repuestos',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        _buildRoleCard(
          role: 'Almacén',
          description: 'Quiero ofrecer repuestos y cotizaciones',
          icon: Icons.storefront_outlined,
        ),
        if (_showRoleError) ...[
          const SizedBox(height: AppSpacing.spacingXs),
          Text(
            'Selecciona una opción para continuar.',
            style: AppTextStyles.textStyleSmall.copyWith(
              color: SemanticColors.colorErrorText,
              letterSpacing: 0,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.spacingLg),
        _buildContinueButton(),
      ],
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    final accent = SemanticColors.colorPrimaryButton;
    final radius = BorderRadius.circular(AppRadius.radiusMd);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isSelected
            ? accent.withValues(alpha: 0.14)
            : AppColors.surfaceContainerLow,
        borderRadius: radius,
        border: Border.all(
          color: isSelected ? accent : AppColors.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: () {
            setState(() {
              _selectedRole = role;
              _showRoleError = false;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent.withValues(alpha: 0.2)
                        : AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? accent : AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role,
                        style: AppTextStyles.textStyleTitle.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.spacingXxs),
                      Text(
                        description,
                        style: AppTextStyles.textStyleCaption.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingXs),
                Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected ? accent : AppColors.outlineVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return RyButton(
      label: 'Continuar',
      trailingIcon: Icons.arrow_forward,
      variant: RyButtonVariant.primary,
      size: RyButtonSize.large,
      isFullWidth: true,
      onPressed: _handleContinue,
    );
  }

  void _handleContinue() {
    if (_selectedRole == null) {
      setState(() => _showRoleError = true);
      return;
    }

    if (_selectedRole == 'Cliente') {
      context.pushNamed(RouteNames.registerCliente);
    } else if (_selectedRole == 'Almacén') {
      context.pushNamed(RouteNames.registerAlmacen);
    }
  }
}
