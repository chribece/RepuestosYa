import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/onboarding_provider.dart';
import '../router/route_names.dart';
import '../theme/app_colors.dart';
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

  Future<void> _openVehiclePage() async {
    await context.push('/profile/vehicles');
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
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            title: const Text(
              'Comienza con RepuestosYa',
              style: AppTextStyles.textStyleCaption,
              maxLines: 2,
              overflow: TextOverflow.visible,
              softWrap: true,
            ),
            actions: onboarding.isComplete
                ? const []
                : [
                    Padding(
                      padding: const EdgeInsets.only(
                        right: AppSpacing.spacingXs,
                      ),
                      child: RyButton(
                        label: 'Omitir',
                        variant: RyButtonVariant.outline,
                        size: RyButtonSize.small,
                        onPressed: _skip,
                      ),
                    ),
                  ],
          ),
          body: _buildBody(onboarding),
        );
      },
    );
  }

  Widget _buildBody(OnboardingProvider onboarding) {
    if (onboarding.isLoading) {
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
          AppSpacing.spacingLg,
          AppSpacing.spacingMd,
          AppSpacing.spacingXl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tu camino para encontrar el repuesto ideal',
              style: AppTextStyles.textStyleHeading.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.spacingSm),
            Text(
              'Completa estos tres pasos para hacer tu primera solicitud.',
              style: AppTextStyles.textStyleBody.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.spacingLg),
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
                      trailingIcon: Icons.arrow_forward,
                      variant: RyButtonVariant.primary,
                      size: RyButtonSize.large,
                      isFullWidth: true,
                      onPressed: _openRequestPage,
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.spacingSm),
            Semantics(
              container: true,
              liveRegion: true,
              label: onboarding.isComplete
                  ? 'Paso 3 · Listo. Ya completaste tu primera solicitud.'
                  : 'Paso 3 · Listo. Completa los pasos anteriores para terminar.',
              child: _buildTimelineStep(
                number: 3,
                icon: Icons.check,
                title: 'Listo / Finalizar',
                description: onboarding.isComplete
                    ? 'Ya completaste el proceso.'
                    : 'Se completará al crear tu primera solicitud.',
                isActive: false,
                isCompleted: onboarding.isComplete,
              ),
            ),
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
        : AppColors.onSurfaceVariant.withValues(alpha: 0.6);
    final foreground = isActive || isCompleted
        ? AppColors.onSurface
        : AppColors.onSurfaceVariant.withValues(alpha: 0.72);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.all(
        isActive ? AppSpacing.spacingLg : AppSpacing.spacingMd,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.surfaceContainerLow
            : AppColors.surfaceContainerLow.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppColors.primaryContainer.withValues(alpha: 0.65)
              : isCompleted
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spacingSm,
                  vertical: AppSpacing.spacingXxs,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isActive ? 0.16 : 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: accent),
                    const SizedBox(width: AppSpacing.spacingXxs),
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
              const Spacer(),
              if (isCompleted)
                Icon(Icons.check_circle, color: accent, size: 20),
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
