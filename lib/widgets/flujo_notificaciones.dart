import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/realtime_notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_logger.dart';
import 'rationale.dart';

/// Solicita el permiso de notificaciones DENTRO del flujo autenticado
/// (home del cliente / dashboard del almacén), nunca en el arranque global.
///
/// - Si el permiso ya está concedido, no molesta (ni rationale ni popup
///   nativo): devuelve sin hacer nada.
/// - Si no, muestra el rationale previo la primera vez (bandera persistida)
///   y, solo si el usuario lo acepta, dispara el popup nativo del sistema.
/// - Después del popup nativo gestiona los estados restantes, con el mismo
///   patrón que `RyImagePicker._ensureCameraPermission`:
///   - `permanentlyDenied` (o un rechazo en iOS, donde es definitivo) →
///     diálogo "Notificaciones bloqueadas" + `openAppSettings()`.
///   - `denied` en Android → diálogo de reintento con contexto explicativo;
///     un segundo rechazo deriva a Ajustes (Android 11+ auto-denegará las
///     siguientes solicitudes).
///   - `restricted` → mensaje informativo.
/// - Es fire-and-forget: no bloquea las suscripciones realtime ni la carga
///   de las pantallas, y NUNCA lanza — cualquier fallo de plataforma se
///   registra y se degrada en silencio (las listas in-app no dependen del
///   permiso de notificaciones).
///
/// [mensaje] es específico del rol: el cliente justifica las cotizaciones y
/// el estado de su orden; el almacén, las nuevas solicitudes y las órdenes
/// ganadas (ver `home_page.dart` y `warehouse_dashboard.dart`).
///
/// [requestPermiso] es inyectable para tests; por defecto usa el servicio
/// real (`RealtimeNotificationService.requestPermissions`).
Future<void> solicitarPermisoNotificaciones(
  BuildContext context, {
  required String mensaje,
  String titulo = 'Permiso de notificaciones',
  Future<PermissionStatus> Function()? requestPermiso,
}) async {
  try {
    final statusInicial = await Permission.notification.status;
    if (statusInicial.isGranted || statusInicial.isProvisional) return;
    if (!context.mounted) return;

    final rationaleOk = await mostrarRationaleSiNecesario(
      context,
      clave: 'rationale_notificaciones',
      titulo: titulo,
      mensaje: mensaje,
    );
    if (!context.mounted || !rationaleOk) return;

    final solicitar =
        requestPermiso ?? RealtimeNotificationService().requestPermissions;

    final resultado = await solicitar();
    if (!context.mounted) return;
    if (resultado.isGranted || resultado.isProvisional) return;

    if (resultado.isRestricted) {
      await _mostrarMensajeRestringido(context);
      return;
    }

    // En iOS un rechazo es definitivo: el sistema no vuelve a mostrar el
    // diálogo; la única vía es Ajustes. En Android, permanentemente denegado
    // tampoco permite reintento nativo.
    if (Platform.isIOS || resultado.isPermanentlyDenied) {
      await _mostrarDialogoAjustes(context);
      return;
    }

    // Android: un rechazo puede ser accidental; ofrecer un reintento con
    // contexto explicativo antes de mandar a Ajustes.
    if (!context.mounted) return;
    final retry = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Permiso de notificaciones'),
        content: const Text(
          'RepuestosYa te avisa cuando hay novedades en tus solicitudes y '
          'órdenes. ¿Quieres intentarlo de nuevo?',
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
    if (retry != true) return;
    if (!context.mounted) return;

    final segundoIntento = await solicitar();
    if (!context.mounted) return;
    if (segundoIntento.isGranted || segundoIntento.isProvisional) return;

    // Segundo rechazo en Android 11+: el sistema auto-denegará las
    // siguientes solicitudes; la única vía para conceder es Ajustes.
    await _mostrarDialogoAjustes(context);
  } catch (e) {
    AppLogger.error(
      'Error al solicitar permiso de notificaciones',
      name: 'FlujoNotificaciones',
      error: e,
    );
  }
}

Future<void> _mostrarDialogoAjustes(BuildContext context) async {
  if (!context.mounted) return;
  final open = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surfaceContainerHigh,
      title: const Text('Notificaciones bloqueadas'),
      content: const Text(
        'Las notificaciones están bloqueadas en los ajustes del dispositivo. '
        'Puedes habilitarlas desde Ajustes → Aplicaciones.',
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

Future<void> _mostrarMensajeRestringido(BuildContext context) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surfaceContainerHigh,
      title: const Text('Notificaciones no disponibles'),
      content: const Text(
        'Las notificaciones están restringidas por el dispositivo o por '
        'políticas de tu organización. Puedes seguir usando la app y verás '
        'las novedades en tus listas.',
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
