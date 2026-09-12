import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/onboarding_provider.dart';
import '../theme/app_spacing.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_section_card.dart';
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
    await context.push('/request/create');
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
          appBar: AppBar(
            title: const Text('Comienza con RepuestosYa'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.spacingXs),
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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Completa estos pasos para hacer tu primera solicitud.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.spacingLg),
            RySectionCard(
              title: 'Paso 1 · Registra tu vehículo',
              icon: Icons.directions_car_outlined,
              children: [
                Text(
                  onboarding.hasVehicle
                      ? 'Tu vehículo ya está registrado.'
                      : 'Agrega los datos de tu vehículo para encontrar repuestos compatibles.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                RyButton(
                  label: onboarding.hasVehicle
                      ? 'Ver mis vehículos'
                      : 'Registrar vehículo',
                  trailingIcon: Icons.arrow_forward,
                  isFullWidth: true,
                  onPressed: _openVehiclePage,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            RySectionCard(
              title: 'Paso 2 · Crea tu primera solicitud',
              icon: Icons.receipt_long_outlined,
              children: [
                Text(
                  onboarding.hasRequest
                      ? 'Ya tienes una solicitud creada.'
                      : 'Cuéntanos qué repuesto necesitas y recibe cotizaciones.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                RyButton(
                  label: onboarding.hasRequest
                      ? 'Crear otra solicitud'
                      : 'Crear solicitud',
                  trailingIcon: Icons.arrow_forward,
                  isFullWidth: true,
                  onPressed: _openRequestPage,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            Semantics(
              container: true,
              liveRegion: true,
              label: onboarding.isComplete
                  ? 'Paso 3 · Listo. Ya completaste tu primera solicitud.'
                  : 'Paso 3 · Listo. Completa los pasos anteriores para terminar.',
              child: onboarding.isComplete
                  ? const RyStateContainer(
                      title: 'Listo',
                      subtitle: 'Ya completaste tu primera solicitud.',
                      type: RyStateType.success,
                    )
                  : const RyStateContainer(
                      title: 'Paso 3 · Listo',
                      subtitle: 'Completa los pasos anteriores para terminar.',
                      type: RyStateType.empty,
                    ),
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            RyButton(
              label: 'Omitir por ahora',
              variant: RyButtonVariant.outline,
              isFullWidth: true,
              onPressed: _skip,
            ),
          ],
        ),
      ),
    );
  }
}
