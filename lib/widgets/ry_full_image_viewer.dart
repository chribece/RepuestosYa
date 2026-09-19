import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Visor a pantalla completa para imágenes, con zoom (InteractiveViewer) y
/// cierre accesible. Soporta URLs de red y archivos locales.
///
/// Mismo patrón que el modal de evidencia de `received_quotations_page.dart`
/// (lo que ve el cliente), pero reutilizable: fondo oscuro, imagen en
/// BoxFit.contain y carga/error con feedback.
class RyFullImageViewer extends StatelessWidget {
  final ImageProvider image;
  final String? title;

  const RyFullImageViewer({super.key, required this.image, this.title});

  /// Abre el visor con una URL de red (o file://).
  static Future<void> showNetwork(
    BuildContext context,
    String url, {
    String? title,
  }) {
    return show(context, image: NetworkImage(url), title: title);
  }

  /// Abre el visor con un archivo local.
  static Future<void> showFile(
    BuildContext context,
    File file, {
    String? title,
  }) {
    return show(context, image: FileImage(file), title: title);
  }

  static Future<void> show(
    BuildContext context, {
    required ImageProvider image,
    String? title,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => RyFullImageViewer(image: image, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: SafeArea(
        child: Column(
          children: [
            // Encabezado: título opcional + cierre accesible.
            Padding(
              padding: const EdgeInsets.all(AppSpacing.spacingMd),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (title != null && title!.isNotEmpty)
                    Flexible(
                      child: Text(
                        title!,
                        style: AppTextStyles.textStyleTitle.copyWith(
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Imagen a pantalla completa con zoom y desplazamiento.
            Expanded(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                clipBehavior: Clip.none,
                child: Center(
                  child: Image(
                    image: image,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryContainer,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: Colors.white70,
                              size: 48,
                            ),
                            SizedBox(height: AppSpacing.spacingSm),
                            Text(
                              'No se pudo cargar la imagen',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.spacingSm),
          ],
        ),
      ),
    );
  }
}
