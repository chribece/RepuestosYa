import 'package:flutter/material.dart';

/// Estilos tipográficos del design system
class AppTextStyles {
  // Display - Para hero elements y títulos grandes
  static const textStyleDisplay = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 1.0,
  );

  // Heading - Para títulos de secciones
  static const textStyleHeading = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0.5,
  );

  // Title - Para títulos de tarjetas y modales
  static const textStyleTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.3,
  );

  // Body - Para texto de contenido principal
  static const textStyleBody = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.2,
  );

  // Caption - Para texto secundario y descripciones
  static const textStyleCaption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.1,
  );

  // Small - Para texto muy pequeño (ayudas, labels)
  static const textStyleSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 1.0,
  );

  // Button - Para texto en botones
  static const textStyleButton = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.5,
  );
}
