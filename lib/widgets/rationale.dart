import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Muestra el diálogo de rationale ANTES del popup nativo de permiso
/// (cámara/GPS), tal como pide la rúbrica: el usuario entiende el uso
/// concreto antes de que el sistema pregunte.
///
/// Solo se muestra la primera vez (bandera persistida en SharedPreferences);
/// en intentos posteriores se devuelve `true` sin diálogo.
///
/// Devuelve `false` si el usuario cierra sin confirmar ("Ahora no"): en ese
/// caso el caller NO debe disparar el permiso nativo y la acción se cancela
/// sin error.
Future<bool> mostrarRationaleSiNecesario(
  BuildContext context, {
  required String clave,
  required String titulo,
  required String mensaje,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(clave) ?? false) return true;
  if (!context.mounted) return false;

  final continuar = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surfaceContainerHigh,
      title: Text(titulo, style: AppTextStyles.textStyleTitle),
      content: Text(mensaje, style: AppTextStyles.textStyleBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Ahora no'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );

  // Se marca como visto aunque se decline: el rationale no debe repetirse
  // en cada intento (solo la primera vez que se pide en el flujo).
  await prefs.setBool(clave, true);
  return continuar ?? false;
}
