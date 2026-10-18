import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Tipos de notificación estilizada (awesome_snackbar_content).
enum RySnackbarTipo { exito, error, advertencia, info }

/// Muestra un SnackBar estilizado con `awesome_snackbar_content`, usando los
/// tokens semánticos del design system (fondo transparente + floating, como
/// documenta el paquete).
///
/// - [titulo] es opcional: si no se pasa se usa el título por defecto del
///   tipo (Éxito / Error / Aviso / Información).
/// - [mensaje] conserva el texto COMPLETO (los lectores de pantalla y los
///   tests ven el texto real; el recorte visual de líneas lo aplica el widget).
/// - Reemplaza al SnackBar actual para evitar encolado de notificaciones.
void mostrarSnackbarRy(
  BuildContext context, {
  RySnackbarTipo tipo = RySnackbarTipo.info,
  String? titulo,
  required String mensaje,
  Duration duracion = const Duration(seconds: 3),
  SnackBarAction? accion,
}) {
  final (
    ContentType contentType,
    Color color,
    String tituloDefault,
  ) = switch (tipo) {
    RySnackbarTipo.exito => (
      ContentType.success,
      SemanticColors.colorSuccess,
      'Éxito',
    ),
    RySnackbarTipo.error => (
      ContentType.failure,
      SemanticColors.colorErrorBackground,
      'Error',
    ),
    RySnackbarTipo.advertencia => (
      ContentType.warning,
      SemanticColors.colorWarning,
      'Aviso',
    ),
    RySnackbarTipo.info => (
      ContentType.help,
      SemanticColors.colorInfo,
      'Información',
    ),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        duration: duracion,
        content: AwesomeSnackbarContent(
          title: titulo ?? tituloDefault,
          message: mensaje,
          contentType: contentType,
          color: color,
          inMaterialBanner: false,
        ),
        action: accion,
      ),
    );
}

/// Atajo: notificación de éxito.
void mostrarSnackbarExito(
  BuildContext context, {
  String? titulo,
  required String mensaje,
  Duration duracion = const Duration(seconds: 3),
  SnackBarAction? accion,
}) {
  mostrarSnackbarRy(
    context,
    tipo: RySnackbarTipo.exito,
    titulo: titulo,
    mensaje: mensaje,
    duracion: duracion,
    accion: accion,
  );
}

/// Atajo: notificación de error.
void mostrarSnackbarError(
  BuildContext context, {
  String? titulo,
  required String mensaje,
  Duration duracion = const Duration(seconds: 3),
  SnackBarAction? accion,
}) {
  mostrarSnackbarRy(
    context,
    tipo: RySnackbarTipo.error,
    titulo: titulo,
    mensaje: mensaje,
    duracion: duracion,
    accion: accion,
  );
}

/// Atajo: notificación de advertencia.
void mostrarSnackbarAdvertencia(
  BuildContext context, {
  String? titulo,
  required String mensaje,
  Duration duracion = const Duration(seconds: 3),
  SnackBarAction? accion,
}) {
  mostrarSnackbarRy(
    context,
    tipo: RySnackbarTipo.advertencia,
    titulo: titulo,
    mensaje: mensaje,
    duracion: duracion,
    accion: accion,
  );
}

/// Atajo: notificación informativa.
void mostrarSnackbarInfo(
  BuildContext context, {
  String? titulo,
  required String mensaje,
  Duration duracion = const Duration(seconds: 3),
  SnackBarAction? accion,
}) {
  mostrarSnackbarRy(
    context,
    tipo: RySnackbarTipo.info,
    titulo: titulo,
    mensaje: mensaje,
    duracion: duracion,
    accion: accion,
  );
}
