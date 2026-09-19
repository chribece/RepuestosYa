import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_logger.dart';

enum RyImagePickerMode { single, multiple }

class RyImagePicker extends StatelessWidget {
  final String? currentImageUrl;
  final File? currentFile;
  final RyImagePickerMode mode;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool allowCamera;
  final bool allowGallery;
  final ValueChanged<File?>? onImageSelected;
  final ValueChanged<String?>? onImageUrlChanged;
  final VoidCallback? onRemove;

  /// Si se provee, muestra un botón de "ver imagen completa" sobre el preview
  /// cuando hay imagen seleccionada (para abrir un visor full-screen).
  final VoidCallback? onViewFullImage;
  final Widget? customPreview;
  final Widget? customPlaceholder;

  const RyImagePicker({
    super.key,
    this.currentImageUrl,
    this.currentFile,
    this.mode = RyImagePickerMode.single,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.allowCamera = true,
    this.allowGallery = true,
    this.onImageSelected,
    this.onImageUrlChanged,
    this.onRemove,
    this.onViewFullImage,
    this.customPreview,
    this.customPlaceholder,
  });

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    // La galería no requiere permiso explícito (Photo Picker en Android 13+ /
    // iOS 14+). La cámara sí: gestionamos los 4 estados posibles.
    if (source == ImageSource.camera) {
      final canUseCamera = await _ensureCameraPermission(context);
      if (!canUseCamera) return;
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        onImageSelected?.call(file);
      }
      // pickedFile == null: el usuario canceló la selección — flujo normal,
      // sin mensaje (solo se informa cuando el permiso fue denegado, arriba).
    } on PlatformException catch (e) {
      AppLogger.warning(
        'image_picker PlatformException: $e',
        name: 'RyImagePicker',
      );
      if (!context.mounted) return;
      _showError(
        context,
        'No se pudo acceder a la cámara o galería en este dispositivo.',
      );
    } catch (e) {
      AppLogger.error(
        'image_picker error inesperado',
        name: 'RyImagePicker',
        error: e,
      );
      if (!context.mounted) return;
      _showError(
        context,
        'Ocurrió un error al seleccionar la imagen. Inténtalo de nuevo.',
      );
    }
  }

  /// Verifica el permiso de cámara y gestiona los 4 estados:
  /// granted → true; denied → diálogo con reintento; permanentlyDenied →
  /// diálogo con "Abrir Ajustes"; restricted → mensaje informativo.
  Future<bool> _ensureCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;
    if (!context.mounted) return false;

    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      await _showSettingsDialog(context);
      return false;
    }

    if (status.isRestricted) {
      await _showRestrictedMessage(context);
      return false;
    }

    // denied (o primera solicitud): pedir el permiso.
    final requested = await Permission.camera.request();
    if (!context.mounted) return false;
    if (requested.isGranted) return true;

    if (requested.isPermanentlyDenied) {
      await _showSettingsDialog(context);
      return false;
    }

    // Negado de nuevo: ofrecer un reintento con contexto explicativo.
    if (!context.mounted) return false;
    final retry = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Permiso de cámara'),
        content: const Text(
          'RepuestosYa usa la cámara para fotografiar la pieza que necesitas '
          'o el repuesto que ofreces. ¿Quieres intentarlo de nuevo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ahora no'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );

    if (retry != true) return false;

    final secondAttempt = await Permission.camera.request();
    if (!context.mounted) return false;
    if (secondAttempt.isGranted) return true;

    if (secondAttempt.isPermanentlyDenied) {
      await _showSettingsDialog(context);
    }
    return false;
  }

  Future<void> _showSettingsDialog(BuildContext context) async {
    if (!context.mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Permiso de cámara bloqueado'),
        content: const Text(
          'El acceso a la cámara está bloqueado en los ajustes del '
          'dispositivo. Puedes habilitarlo desde Ajustes → Aplicaciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Abrir Ajustes'),
          ),
        ],
      ),
    );
    if (open == true) {
      await openAppSettings();
    }
  }

  Future<void> _showRestrictedMessage(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Cámara no disponible'),
        content: const Text(
          'El acceso a la cámara está restringido por el dispositivo o por '
          'políticas de tu organización. Puedes seguir usando fotos de la '
          'galería.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.radiusLg),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.spacingMd),
            Text('Seleccionar imagen', style: AppTextStyles.textStyleTitle),
            const SizedBox(height: AppSpacing.spacingMd),
            if (allowCamera)
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Cámara'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(context, ImageSource.camera);
                },
              ),
            if (allowGallery)
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(context, ImageSource.gallery);
                },
              ),
            const SizedBox(height: AppSpacing.spacingMd),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = currentFile != null || currentImageUrl != null;
    final effectiveWidth = width ?? 200;
    final effectiveHeight = height ?? 200;

    return Semantics(
      button: true,
      label: hasImage ? 'Imagen seleccionada' : 'Seleccionar imagen',
      onTap: () => _showPickerOptions(context),
      child: GestureDetector(
        onTap: () => _showPickerOptions(context),
        child: Container(
          width: effectiveWidth,
          height: effectiveHeight,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            border: Border.all(color: AppColors.outlineVariant, width: 1),
          ),
          child: _buildContent(effectiveWidth, effectiveHeight),
        ),
      ),
    );
  }

  Widget _buildContent(double width, double height) {
    if (customPreview != null) {
      return customPreview!;
    }

    if (currentFile != null) {
      return Stack(
        children: [
          Semantics(
            image: true,
            label: 'Imagen seleccionada',
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              child: Image.file(
                currentFile!,
                width: width,
                height: height,
                fit: fit,
              ),
            ),
          ),
          _buildRemoveButton(width, height),
          if (onViewFullImage != null) _buildFullViewButton(width, height),
        ],
      );
    }

    if (currentImageUrl != null) {
      return Stack(
        children: [
          Semantics(
            image: true,
            label: 'Imagen seleccionada',
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              child: CachedNetworkImage(
                imageUrl: currentImageUrl!,
                width: width,
                height: height,
                fit: fit,
                placeholder: (context, url) => _buildPlaceholder(width, height),
                errorWidget: (context, url, error) =>
                    _buildPlaceholder(width, height),
              ),
            ),
          ),
          _buildRemoveButton(width, height),
          if (onViewFullImage != null) _buildFullViewButton(width, height),
        ],
      );
    }

    return customPlaceholder ?? _buildPlaceholder(width, height);
  }

  Widget _buildPlaceholder(double width, double height) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 48,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Text(
            'Toca para seleccionar',
            style: AppTextStyles.textStyleCaption.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoveButton(double width, double height) {
    return Positioned(
      top: AppSpacing.spacingXxs,
      right: AppSpacing.spacingXxs,
      child: Semantics(
        button: true,
        label: 'Quitar imagen',
        enabled: onRemove != null,
        child: Material(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadius.radiusFull),
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(AppRadius.radiusFull),
            child: SizedBox(
              // 48×48 dp mínimo WCAG 2.5.5 (antes 32×32). Se reduce el
              // padding superior/derecho para que el botón siga en la
              // esquina del preview.
              width: 48,
              height: 48,
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullViewButton(double width, double height) {
    return Positioned(
      bottom: AppSpacing.spacingXxs,
      right: AppSpacing.spacingXxs,
      child: Semantics(
        button: true,
        label: 'Ver imagen completa',
        child: Material(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadius.radiusFull),
          child: InkWell(
            onTap: onViewFullImage,
            borderRadius: BorderRadius.circular(AppRadius.radiusFull),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.open_in_full, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
