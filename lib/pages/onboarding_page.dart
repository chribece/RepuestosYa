import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/onboarding_provider.dart';
import '../router/route_names.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_state_container.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OnboardingProvider>().load();
    });
  }

  Future<void> _openVehiclePage({bool desdeOnboarding = false}) async {
    await context.push(
      desdeOnboarding
          ? '/profile/vehicles?source=onboarding'
          : '/profile/vehicles',
    );
    if (mounted) {
      await context.read<OnboardingProvider>().load();
    }
  }

  Future<void> _openRequestPage() async {
    await context.push('/request/create?source=onboarding');
    if (mounted) {
      await context.read<OnboardingProvider>().load();
    }
  }

  Future<void> _skip() async {
    await context.read<OnboardingProvider>().skip();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, onboarding, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: _buildBody(onboarding),
        );
      },
    );
  }

  Widget _buildBody(OnboardingProvider onboarding) {
    if (onboarding.isLoading && !onboarding.isInitialized) {
      return const RyStateContainer(
        title: 'Cargando tu progreso...',
        type: RyStateType.loading,
      );
    }

    if (onboarding.errorMessage != null) {
      return RyStateContainer(
        title: 'No pudimos cargar tu progreso',
        subtitle: onboarding.errorMessage,
        type: RyStateType.error,
        actionLabel: 'Reintentar',
        onAction: () => onboarding.load(),
      );
    }

    final requestStepComplete = onboarding.hasVehicle && onboarding.hasRequest;
    final vehicleStepActive = !onboarding.hasVehicle;
    final requestStepActive = onboarding.hasVehicle && !requestStepComplete;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.spacingMd,
          24.0,
          AppSpacing.spacingMd,
          AppSpacing.spacingLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tu camino al repuesto ideal',
              style: AppTextStyles.textStyleHeading.copyWith(
                color: AppColors.onSurface,
                fontSize: 24,
                height: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.spacingSm),
            Text(
              'Completa estos tres pasos para hacer tu primera solicitud.',
              style: AppTextStyles.textStyleBody.copyWith(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            _buildTimelineStep(
              number: 1,
              icon: Icons.directions_car_outlined,
              title: 'Registrar tu vehículo',
              description: onboarding.hasVehicle
                  ? 'Tu vehículo ya está registrado.'
                  : 'Agrega los datos de tu vehículo para encontrar repuestos compatibles.',
              isActive: vehicleStepActive,
              isCompleted: onboarding.hasVehicle,
              action: vehicleStepActive
                  ? RyButton(
                      label: 'Registrar vehículo',
                      trailingIcon: Icons.arrow_forward,
                      variant: RyButtonVariant.primary,
                      size: RyButtonSize.large,
                      isFullWidth: true,
                      onPressed: () => _openVehiclePage(desdeOnboarding: true),
                    )
                  : onboarding.hasVehicle
                  ? RyButton(
                      label: 'Ver mi vehículo',
                      variant: RyButtonVariant.outline,
                      size: RyButtonSize.large,
                      isFullWidth: true,
                      onPressed: _openVehiclePage,
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.spacingSm),
            _buildTimelineStep(
              number: 2,
              icon: Icons.receipt_long_outlined,
              title: 'Crear tu primera solicitud',
              description: requestStepComplete
                  ? 'Ya creaste tu primera solicitud.'
                  : requestStepActive
                  ? 'Cuéntanos qué repuesto necesitas y recibe cotizaciones.'
                  : 'Disponible al completar el paso anterior.',
              isActive: requestStepActive,
              isCompleted: requestStepComplete,
              action: requestStepActive
                  ? RyButton(
                      label: 'Crear solicitud',
                      variant: RyButtonVariant.primary,
                      size: RyButtonSize.large,
                      isFullWidth: true,
                      onPressed: _openRequestPage,
                      customChild: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'Crear solicitud',
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.textStyleButton.copyWith(
                                color: SemanticColors.colorOnPrimaryButton,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward,
                            size: 20,
                            color: SemanticColors.colorOnPrimaryButton,
                          ),
                        ],
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.spacingSm),
            Semantics(
              container: true,
              liveRegion: true,
              label: onboarding.isComplete
                  ? 'Paso 3 · Recibe cotizaciones. Ya completaste tu primera solicitud.'
                  : 'Paso 3 · Recibe cotizaciones. Completa los pasos anteriores para terminar.',
              child: _buildTimelineStep(
                number: 3,
                icon: Icons.mail_outline_rounded,
                title: 'Recibe cotizaciones',
                description:
                    'Compara precios y disponibilidad de almacenes cerca de ti.',
                isActive: false,
                isCompleted: onboarding.isComplete,
              ),
            ),
            if (!onboarding.isComplete) ...[
              const SizedBox(height: AppSpacing.spacingXs),
              OutlinedButton(
                onPressed: _skip,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  foregroundColor: AppColors.textMuted,
                  side: BorderSide(
                    color: AppColors.outlineVariant.withValues(alpha: 0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  ),
                ),
                child: Text(
                  onboarding.hasVehicle ? 'Ir al inicio' : 'Saltar por ahora',
                  style: AppTextStyles.textStyleButton.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
            if (onboarding.isComplete) ...[
              const SizedBox(height: AppSpacing.spacingLg),
              RyButton(
                label: 'Ir al inicio',
                icon: Icons.home_outlined,
                variant: RyButtonVariant.primary,
                size: RyButtonSize.large,
                isFullWidth: true,
                onPressed: () => context.goNamed(RouteNames.home),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required int number,
    required IconData icon,
    required String title,
    required String description,
    required bool isActive,
    required bool isCompleted,
    Widget? action,
  }) {
    final accent = isCompleted
        ? AppColors.success
        : isActive
        ? AppColors.primaryContainer
        : Colors.white38;
    final foreground = isActive || isCompleted
        ? AppColors.onSurface
        : AppColors.onSurfaceVariant.withValues(alpha: 0.72);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.all(isActive ? AppSpacing.spacingMd : 14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppColors.primaryContainer.withValues(alpha: 0.45)
              : isCompleted
              ? const Color(0xFF22C55E).withValues(alpha: 0.35)
              : AppColors.outlineVariant.withValues(alpha: 0.35),
          width: isActive ? 1.2 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primaryContainer.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isCompleted || isActive
                      ? accent.withValues(alpha: isActive ? 0.15 : 0.12)
                      : const Color(0xFF1E1E22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      isCompleted ? Icons.check : icon,
                      size: 16,
                      color: accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Paso $number',
                      style: AppTextStyles.textStyleSmall.copyWith(
                        color: accent,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(
            height: isActive ? AppSpacing.spacingMd : AppSpacing.spacingSm,
          ),
          Text(
            title,
            style:
                (isActive
                        ? AppTextStyles.textStyleTitle
                        : AppTextStyles.textStyleBody)
                    .copyWith(color: foreground, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.spacingXxs),
          Text(
            description,
            style: AppTextStyles.textStyleCaption.copyWith(
              color: isActive
                  ? AppColors.onSurfaceVariant
                  : AppColors.onSurfaceVariant.withValues(alpha: 0.68),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.spacingMd),
            action,
          ],
        ],
      ),
    );
  }
}
