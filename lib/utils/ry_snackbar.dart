import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Tipos de notificación estilizada.
enum RySnackbarTipo { exito, error, advertencia, info }

const Color _fondoSnackbar = Color(0xFF18181B);
const Color _acentoExito = Color(0xFF22C55E);
const Color _acentoError = Color(0xFFEF4444);
const Color _acentoAviso = Color(0xFFF59E0B);
const Color _acentoInfo = Color(0xFF38BDF8);
const Color _acentoSinConexion = Color(0xFFEF4444);

/// Muestra un SnackBar estilizado con el diseño oscuro unificado.
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
  if (tipo == RySnackbarTipo.exito) {
    return mostrarSnackbarExito(
      context,
      titulo: titulo,
      mensaje: mensaje,
      duracion: duracion,
      accion: accion,
    );
  }
  final (Color acento, IconData icono, String tituloDefault) = switch (tipo) {
    RySnackbarTipo.exito => (
      _acentoExito,
      Icons.check_circle_outline_rounded,
      'Éxito',
    ),
    RySnackbarTipo.error => (
      _acentoError,
      Icons.error_outline_rounded,
      'Error',
    ),
    RySnackbarTipo.advertencia => (
      _acentoAviso,
      Icons.warning_amber_rounded,
      'Aviso',
    ),
    RySnackbarTipo.info => (
      _acentoInfo,
      Icons.info_outline_rounded,
      'Información',
    ),
  };
  _mostrarRySnackbar(
    context,
    acento: acento,
    icono: icono,
    titulo: titulo ?? tituloDefault,
    mensaje: mensaje,
    duracion: duracion,
    accion: accion,
  );
}

/// Éxito flotante con el diseño oscuro unificado. Es el estilo único de
/// TODOS los mensajes de éxito (incluido [mostrarSnackbarExitoSobrio]).
void mostrarSnackbarExito(
  BuildContext context, {
  String? titulo,
  required String mensaje,
  Duration duracion = const Duration(seconds: 3),
  SnackBarAction? accion,
}) {
  _mostrarRySnackbar(
    context,
    acento: _acentoExito,
    icono: Icons.check_circle_outline_rounded,
    titulo: titulo,
    mensaje: mensaje,
    duracion: duracion,
    accion: accion,
  );
}

/// Alias de [mostrarSnackbarExito]: mismo estilo global de éxito.
void mostrarSnackbarExitoSobrio(
  BuildContext context, {
  String? titulo,
  required String mensaje,
  Duration duracion = const Duration(seconds: 3),
}) {
  mostrarSnackbarExito(
    context,
    titulo: titulo,
    mensaje: mensaje,
    duracion: duracion,
  );
}

/// Notificación informativa flotante con el diseño oscuro unificado.
void mostrarSnackbarInfoSobrio(
  BuildContext context, {
  required String mensaje,
  Duration duracion = const Duration(seconds: 3),
}) {
  _mostrarRySnackbar(
    context,
    acento: _acentoInfo,
    icono: Icons.info_outline_rounded,
    mensaje: mensaje,
    duracion: duracion,
  );
}

/// Aviso flotante oscuro con acento ámbar. Reemplaza al SnackBar actual para
/// que los avisos no se apilen.
void mostrarSnackbarAvisoSobrio(
  BuildContext context, {
  required String mensaje,
  Duration duracion = const Duration(seconds: 3),
}) {
  _mostrarRySnackbar(
    context,
    acento: _acentoAviso,
    icono: Icons.warning_amber_rounded,
    mensaje: mensaje,
    duracion: duracion,
  );
}

/// Aviso de conexión con el mismo diseño oscuro unificado (acento cian).
/// Mensaje corto, máximo 2 líneas.
void mostrarSnackbarSinConexion(
  BuildContext context, {
  required String mensaje,
  Duration duracion = const Duration(seconds: 3),
}) {
  _mostrarRySnackbar(
    context,
    acento: _acentoSinConexion,
    icono: Icons.wifi_off_rounded,
    mensaje: mensaje,
    duracion: duracion,
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

/// Builder único: fondo oscuro elevado, borde de 1px con el acento, ícono
/// dentro de un contenedor 34x34 tintado y botón de cierre discreto.
void _mostrarRySnackbar(
  BuildContext context, {
  required Color acento,
  required IconData icono,
  String? titulo,
  required String mensaje,
  required Duration duracion,
  SnackBarAction? accion,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _fondoSnackbar,
        elevation: 0,
        duration: duracion,
        showCloseIcon: true,
        closeIconColor: Colors.white54,
        margin: const EdgeInsets.all(AppSpacing.spacingMd),
        padding: const EdgeInsets.all(AppSpacing.spacingSm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: acento.withValues(alpha: 0.35)),
        ),
        content: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: acento.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              ),
              child: Icon(icono, color: acento, size: 20),
            ),
            const SizedBox(width: AppSpacing.spacingSm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (titulo != null) ...[
                    Text(
                      titulo,
                      style: AppTextStyles.textStyleBody.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spacingXxs),
                  ],
                  Text(
                    mensaje,
                    maxLines: 2,
                    style: AppTextStyles.textStyleCaption.copyWith(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: accion,
      ),
    );
}
