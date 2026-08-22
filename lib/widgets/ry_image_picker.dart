import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

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
    this.customPreview,
    this.customPlaceholder,
  });

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 85);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      onImageSelected?.call(file);
    }
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
                  _pickImage(ImageSource.camera);
                },
              ),
            if (allowGallery)
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
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
}
