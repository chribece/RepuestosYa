import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/almacen_service.dart';
import '../widgets/ry_text_field.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import 'warehouse_dashboard.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _rucController = TextEditingController();
  final TextEditingController _representanteController =
      TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _latController = TextEditingController(
    text: '0.0',
  );
  final TextEditingController _lonController = TextEditingController(
    text: '0.0',
  );

  bool _isSubmitting = false;
  final AuthService _authService = AuthService();
  final AlmacenService _almacenService = AlmacenService();

  @override
  void initState() {
    super.initState();
    // Pre-llenar el nombre del representante desde el auth
    final currentUser = _authService.currentUser;
    if (currentUser?.nombreCompleto != null) {
      _representanteController.text = currentUser!.nombreCompleto!;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _rucController.dispose();
    _representanteController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  Future<void> _completarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Obtener el ID del usuario actual
      final userId = _authService.currentUser?.id;
      if (userId == null) {
        throw Exception('No se pudo obtener el ID del usuario');
      }

      // Enviar datos del almacén al backend usando AlmacenService
      await _almacenService.crearAlmacen({
        'encargado_id': userId,
        'nombre_comercial': _nombreController.text.trim(),
        'ruc': _rucController.text.trim(),
        'representante_legal': _representanteController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'email': _authService.currentUser?.email ?? '',
        'direccion_texto': _direccionController.text.trim(),
        'latitude': double.tryParse(_latController.text) ?? 0.0,
        'longitude': double.tryParse(_lonController.text) ?? 0.0,
      });

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Perfil completado exitosamente!'),
            backgroundColor: AppColors.primaryContainer,
            duration: Duration(seconds: 3),
          ),
        );
        // Navegar al dashboard
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WarehouseDashboard()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.primary,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Completar Perfil',
          style: AppTextStyles.textStyleTitle.copyWith(
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.spacingMd),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.spacingMd),
                _buildWelcomeText(),
                const SizedBox(height: AppSpacing.spacingXl),
                _buildNombreField(),
                const SizedBox(height: AppSpacing.spacingLg),
                _buildRucField(),
                const SizedBox(height: AppSpacing.spacingLg),
                _buildRepresentanteField(),
                const SizedBox(height: AppSpacing.spacingLg),
                _buildTelefonoField(),
                const SizedBox(height: AppSpacing.spacingLg),
                _buildDireccionField(),
                const SizedBox(height: AppSpacing.spacingLg),
                Row(
                  children: [
                    Expanded(child: _buildLatField()),
                    const SizedBox(width: AppSpacing.spacingMd),
                    Expanded(child: _buildLonField()),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingXl),
                _buildCompleteButton(),
                const SizedBox(height: AppSpacing.spacingMd),
                _buildInfoBox(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¡Bienvenido!',
          style: AppTextStyles.textStyleHeading.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        Text(
          'Completa la información de tu almacén para comenzar.',
          style: AppTextStyles.textStyleBody.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildNombreField() {
    return RyTextField(
      label: 'Nombre Comercial',
      hint: 'Ej: RepuestosYa Central',
      controller: _nombreController,
      isRequired: true,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'El nombre comercial es requerido';
        }
        if (value.trim().length < 3) {
          return 'El nombre debe tener al menos 3 caracteres';
        }
        return null;
      },
    );
  }

  Widget _buildRucField() {
    return RyTextField(
      label: 'RUC',
      hint: 'Ej: 20123456789',
      controller: _rucController,
      type: RyTextFieldType.number,
      isRequired: true,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'El RUC es requerido';
        }
        if (value.trim().length != 11) {
          return 'El RUC debe tener 11 dígitos';
        }
        return null;
      },
    );
  }

  Widget _buildRepresentanteField() {
    return RyTextField(
      label: 'Representante Legal',
      hint: 'Ej: Juan Pérez',
      controller: _representanteController,
      isRequired: true,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'El representante legal es requerido';
        }
        if (value.trim().length < 3) {
          return 'El nombre debe tener al menos 3 caracteres';
        }
        return null;
      },
    );
  }

  Widget _buildTelefonoField() {
    return RyTextField(
      label: 'Teléfono',
      hint: 'Ej: 999123456',
      controller: _telefonoController,
      type: RyTextFieldType.phone,
      isRequired: true,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'El teléfono es requerido';
        }
        if (value.trim().length < 9) {
          return 'El teléfono debe tener al menos 9 dígitos';
        }
        return null;
      },
    );
  }

  Widget _buildDireccionField() {
    return RyTextField(
      label: 'Dirección',
      hint: 'Ej: Av. Principal 123, Ciudad',
      controller: _direccionController,
      maxLines: 3,
      isRequired: true,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'La dirección es requerida';
        }
        if (value.trim().length < 5) {
          return 'La dirección debe tener al menos 5 caracteres';
        }
        return null;
      },
    );
  }

  Widget _buildLatField() {
    return RyTextField(
      label: 'Latitud',
      hint: '0.0',
      controller: _latController,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d+')),
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return null; // Optional field
        }
        final lat = double.tryParse(value.trim());
        if (lat == null) {
          return 'Ingresa un número válido';
        }
        if (lat < -90 || lat > 90) {
          return 'Latitud debe estar entre -90 y 90';
        }
        return null;
      },
    );
  }

  Widget _buildLonField() {
    return RyTextField(
      label: 'Longitud',
      hint: '0.0',
      controller: _lonController,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d+')),
      ],
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return null; // Optional field
        }
        final lon = double.tryParse(value.trim());
        if (lon == null) {
          return 'Ingresa un número válido';
        }
        if (lon < -180 || lon > 180) {
          return 'Longitud debe estar entre -180 y 180';
        }
        return null;
      },
    );
  }

  Widget _buildCompleteButton() {
    // No se usa RyButton porque su estado `isLoading` sustituye la etiqueta por
    // un spinner y aquí debe conservarse el texto visible 'PROCESANDO...'.
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _completarPerfil,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryContainer,
          disabledBackgroundColor: AppColors.primaryContainer.withValues(
            alpha: 0.4,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          ),
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.spacingSm),
                  Text(
                    'PROCESANDO...',
                    style: AppTextStyles.textStyleButton.copyWith(
                      color: AppColors.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.spacingXs),
                  Text(
                    'COMPLETAR PERFIL',
                    style: AppTextStyles.textStyleButton.copyWith(
                      color: AppColors.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.spacingSm),
          Expanded(
            child: Text(
              'Las coordenadas son opcionales. Puedes actualizarlas más tarde desde tu perfil.',
              style: AppTextStyles.textStyleSmall.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
