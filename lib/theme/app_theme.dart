import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_spacing.dart';
import 'app_radius.dart';

/// Tema de la aplicación (dark-only).
///
/// RepuestosYa es deliberadamente oscuro (coral/naranja sobre negro, estilo
/// "automotriz de garaje"). No existe paleta clara: históricamente `lightTheme`
/// era un clon de `darkTheme` con los mismos tokens (`AppColors.background =
/// #131313`, etc.), por lo que no aportaba nada funcional y se eliminó en la
/// versión 1.2.1 (ver §8.1 de `docs/DESIGN_SYSTEM.md`). Usar `theme: darkTheme`
/// en `MaterialApp`.
ThemeData get darkTheme {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Tipografía con Sora
    fontFamily: GoogleFonts.sora().fontFamily,
    textTheme: TextTheme(
      displayLarge: AppTextStyles.textStyleDisplay,
      headlineLarge: AppTextStyles.textStyleHeading,
      titleLarge: AppTextStyles.textStyleTitle,
      bodyLarge: AppTextStyles.textStyleBody,
      bodyMedium: AppTextStyles.textStyleCaption,
      bodySmall: AppTextStyles.textStyleSmall,
      labelLarge: AppTextStyles.textStyleButton,
    ),

    // Colores de superficie (mismo esquema que claro para consistencia)
    colorScheme: const ColorScheme.dark(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimaryContainer,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      secondaryContainer: AppColors.secondaryContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceContainerHighest: AppColors.surfaceContainerHigh,
      outline: AppColors.outlineVariant,
      error: AppColors.error,
      onError: Colors.white,
    ),

    // Scaffold background
    scaffoldBackgroundColor: AppColors.background,

    // AppBar theme
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.onSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTextStyles.textStyleTitle,
    ),

    // Card theme
    cardTheme: CardThemeData(
      color: AppColors.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
      ),
    ),

    // Elevated button theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spacingLg,
          vertical: AppSpacing.spacingMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        ),
        textStyle: AppTextStyles.textStyleButton,
        minimumSize: const Size(48, 48),
      ),
    ),

    // Text button theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.secondaryContainer,
        textStyle: AppTextStyles.textStyleButton,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spacingMd,
          vertical: AppSpacing.spacingSm,
        ),
        minimumSize: const Size(48, 48),
      ),
    ),

    // Outlined button theme
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.onSurface,
        side: const BorderSide(color: AppColors.outlineVariant),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spacingLg,
          vertical: AppSpacing.spacingMd,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        ),
        textStyle: AppTextStyles.textStyleButton,
        minimumSize: const Size(48, 48),
      ),
    ),

    // Input decoration theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        borderSide: const BorderSide(color: AppColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        borderSide: const BorderSide(
          color: AppColors.primaryContainer,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spacingMd,
        vertical: AppSpacing.spacingMd,
      ),
      labelStyle: AppTextStyles.textStyleCaption.copyWith(
        color: AppColors.onSurfaceVariant,
      ),
      hintStyle: AppTextStyles.textStyleCaption.copyWith(
        color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      errorStyle: AppTextStyles.textStyleSmall.copyWith(color: AppColors.error),
    ),

    // Icon theme
    iconTheme: const IconThemeData(color: AppColors.onSurface, size: 24),

    // Divider theme
    dividerTheme: const DividerThemeData(
      color: AppColors.outlineVariant,
      thickness: 1,
      space: AppSpacing.spacingMd,
    ),
  );
}
