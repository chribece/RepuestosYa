import 'package:flutter/material.dart';

/// Colores primitivos del design system
class AppColors {
  // Colores Primarios
  static const primary = Color(0xFFFFB5A7);
  static const primaryContainer = Color(0xFFFF5722);
  static const onPrimaryContainer = Color(0xFF541200);

  // Colores de Superficie
  static const background = Color(0xFF131313);
  static const surface = Color(0xFF131313);
  static const surfaceContainerLow = Color(0xFF1C1B1B);
  static const surfaceContainerHigh = Color(0xFF2A2A2A);
  static const surfaceVariant = Color(0xFF353534);

  // Colores de Texto
  static const onSurface = Color(0xFFE5E2E1);
  static const onSurfaceVariant = Color(0xFFE4BEB4);

  // Colores Secundarios
  static const secondary = Color(0xFF9ECAFF);
  static const secondaryContainer = Color(0xFF1E95F2);
  static const tertiaryContainer = Color(0xFF019AD8);

  // Colores de Estado
  // `error` se usa como fondo (botón danger, snackbar, badge filled bg con
  // alpha) junto a texto blanco: #C62828 con blanco = 5.62:1 (AA normal),
  // frente al 3.85:1 (sólo AA large) del #FF1744 original. Para texto de
  // error sobre fondo oscuro usar `SemanticColors.colorErrorText` (#FF6B7A).
  static const error = Color(0xFFC62828);
  static const success = Color(0xFF00C853);
  static const warning = Color(0xFFFFAB00);

  // Colores de Borde
  static const outlineVariant = Color(0xFF5B4039);

  // Asterisco requerido
  static const requiredAsterisk = Color(0xFFFF3333);

  // Transparente (sin color)
  static const transparent = Color(0x00000000);
}

/// Colores semánticos del design system
class SemanticColors {
  // Fondo/Texto
  static const colorBackground = AppColors.background;
  static const colorSurface = AppColors.surface;
  static const colorOnSurface = AppColors.onSurface;
  static const colorOnSurfaceVariant = AppColors.onSurfaceVariant;

  // Botón/Texto
  static const colorPrimaryButton = AppColors.primaryContainer;
  static const colorOnPrimaryButton = AppColors.onPrimaryContainer;
  static const colorSecondaryButton = AppColors.secondaryContainer;
  // Texto sobre botón secundario (#1E95F2): onSurface daba 2.46:1 (FAIL);
  // onPrimaryContainer (#541200) da 4.53:1 (AA normal).
  static const colorOnSecondaryButton = AppColors.onPrimaryContainer;

  // Error/Texto
  static const colorErrorBackground = AppColors.error;
  static const colorOnErrorText = Colors.white;
  // Texto de error sobre fondo oscuro (input error, badge error filled).
  // #FF6B7A sobre #1C1B1B = 6.25:1 (AA normal) vs. 4.47:1 del #FF1744.
  static const colorErrorText = Color(0xFFFF6B7A);

  // Texto de badge "info" sobre fondo sutil (#1E95F2 alpha 0.15 sobre
  // surfaceContainerLow): #4DA8F5 da 5.53:1 (AA normal) vs. 4.46:1.
  static const colorInfoBadgeText = Color(0xFF4DA8F5);

  // Estados
  static const colorSuccess = AppColors.success;
  static const colorWarning = AppColors.warning;
  static const colorInfo = AppColors.secondaryContainer;
}
