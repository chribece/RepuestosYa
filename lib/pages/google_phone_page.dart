import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/user_role_provider.dart';
import '../router/route_names.dart';
import '../services/almacen_repository.dart';
import '../services/almacen_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/api_error_handler.dart';
import '../utils/ecuador_mobile_phone.dart';
import '../utils/ry_snackbar.dart';
import '../widgets/ry_button.dart';
import '../widgets/ry_text_field.dart';

class GooglePhonePage extends StatefulWidget {
  const GooglePhonePage({super.key});

  @override
  State<GooglePhonePage> createState() => _GooglePhonePageState();
}

class _GooglePhonePageState extends State<GooglePhonePage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _authService = AuthService();
  final _profileService = ProfileService();
  late final AlmacenService _almacenService;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _almacenService = AlmacenService(context.read<AlmacenRepository>());
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _savePhone() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final phone = _phoneController.text.trim();
      final profile = await _profileService.updatePhone(phone);
      final savedPhone = profile?['telefono']?.toString();
      if (savedPhone == null || savedPhone.isEmpty) {
        throw const ApiException('No se pudo guardar el número de teléfono.');
      }

      _authService.updateCurrentUserPhone(savedPhone);
      if (!mounted) return;

      final role = context.read<UserRoleProvider>().currentRole;
      if (role == UserRole.almacen) {
        final hasWarehouseProfile = await _almacenService.hasWarehouseProfile();
        if (!mounted) return;
        context.goNamed(
          hasWarehouseProfile
              ? RouteNames.dashboard
              : RouteNames.completeProfile,
        );
      } else if (role == UserRole.cliente) {
        context.goNamed(RouteNames.home);
      } else if (role == UserRole.admin) {
        context.goNamed(RouteNames.dashboard);
      } else {
        throw const ApiException(
          'No se pudo determinar tu tipo de cuenta. Vuelve a iniciar sesión.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      mostrarSnackbarError(
        context,
        mensaje: ApiErrorHandler.userMessage(
          error,
          context: ApiErrorContext.auth,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minHeight = (constraints.maxHeight - AppSpacing.spacingXl * 2)
                .clamp(0.0, constraints.maxHeight);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.spacingXl),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: _buildPhoneCard(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPhoneCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spacingLg),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(color: Colors.white24),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.phone_iphone_rounded,
              size: 44,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            Text(
              'Un último paso',
              textAlign: TextAlign.center,
              style: AppTextStyles.textStyleHeading.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.spacingXs),
            Text(
              'Agrega tu celular de contacto para recibir cotizaciones y '
              'alertas sobre tus repuestos.',
              textAlign: TextAlign.center,
              style: AppTextStyles.textStyleBody.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.spacingLg),
            RyTextField(
              label: 'Número celular',
              hint: '0991234567',
              type: RyTextFieldType.phone,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: ecuadorLocalMobilePhoneInputFormatters(),
              prefixIcon: Icons.phone_outlined,
              isRequired: true,
              validator: validarTelefonoLocalEcuador,
              helperText: 'Ingresa 10 dígitos comenzando con 09.',
              helperStyle: AppTextStyles.textStyleCaption.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.spacingLg),
            RyButton(
              label: 'Guardar y continuar',
              icon: Icons.check,
              variant: RyButtonVariant.primary,
              size: RyButtonSize.large,
              isLoading: _isSaving,
              isFullWidth: true,
              onPressed: _savePhone,
            ),
          ],
        ),
      ),
    );
  }
}
