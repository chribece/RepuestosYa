import 'package:flutter/material.dart';

import '../services/ubicacion_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'rationale.dart';
import 'ry_button.dart';

/// Diálogo de progreso mientras se obtiene la fijación GPS. No se puede
/// cerrar con back ni tocando fuera; solo con el pop del flujo.
void mostrarProgresoUbicacion(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.spacingLg),
          child: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: AppSpacing.spacingMd),
              Expanded(
                child: Text(
                  'Obteniendo tu ubicación…',
                  style: AppTextStyles.textStyleBody,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

const UbicacionResultado _cancelado = UbicacionResultado(
  estado: UbicacionEstado.cancelado,
  mensaje: 'Se canceló la solicitud de ubicación.',
);

/// Flujo de captura de GPS compartido (formulario de solicitud y perfil de
/// almacén) con la única vía de degradación controlada:
/// 1. Rationale previo (una sola vez, persistido) explicando el uso concreto
///    ANTES del popup nativo; si el usuario lo declina, la acción se cancela
///    sin error y sin pedir el permiso.
/// 2. Intenta la fijación GPS mostrando progreso (vía [service]).
/// 3. Si falla, ofrece opciones SEGÚN EL ESTADO:
///    - `gpsApagado` (servicio del sistema apagado) → "Activar ubicación"
///      que abre `openLocationSettings()` (interruptor del sistema).
///    - `permisoDenegadoPermanente`/`permisoDenegado` (permiso de la app) →
///      "Abrir permisos de la app" que abre `openAppSettings()`.
///    - Sin señal/timeout → solo Reintentar / manual.
///    Siempre disponible: Reintentar y "Usar dirección manual" (el backend
///    geocodifica server-side antes de aceptar el registro).
///
/// Reutiliza `UbicacionService` (toda la lógica de permisos vive allí); este
/// helper solo orquesta los diálogos de UI.
Future<UbicacionResultado> flujoUbicacionGps(
  BuildContext context,
  UbicacionService service,
) async {
  bool primeraVez = true;

  while (true) {
    if (!context.mounted) return _cancelado;

    // Rationale previo solo en la primera invocación del flujo.
    if (primeraVez) {
      primeraVez = false;
      final rationaleOk = await mostrarRationaleSiNecesario(
        context,
        clave: 'rationale_ubicacion',
        titulo: 'Permiso de ubicación',
        mensaje:
            'RepuestosYa necesita tu ubicación para registrar la dirección '
            'de entrega y calcular distancias de despacho reales entre el '
            'almacén y tu punto de recogida.',
      );
      if (!context.mounted) return _cancelado;
      if (!rationaleOk) return _cancelado;
    }

    mostrarProgresoUbicacion(context);
    final resultado = await service.obtenerUbicacion();
    if (context.mounted) {
      try {
        Navigator.of(context, rootNavigator: true).pop(); // cerrar progreso
      } catch (_) {}
    }
    if (resultado.disponible) return resultado;
    if (!context.mounted) return _cancelado;

    // Opciones según el estado real (servicio apagado vs. permiso de la app).
    final esServicioApagado = resultado.estado == UbicacionEstado.gpsApagado;
    final esPermiso =
        resultado.estado == UbicacionEstado.permisoDenegadoPermanente ||
        resultado.estado == UbicacionEstado.permisoDenegado;

    final accion = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('No pudimos obtener tu ubicación'),
        content: Text(
          resultado.mensaje ??
              'El GPS no está disponible en este momento. Reintenta o ingresa tu dirección manualmente: la verificaremos antes de continuar.',
          style: AppTextStyles.textStyleBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'manual'),
            child: const Text('Usar dirección manual'),
          ),
          if (esServicioApagado)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'ajustesSistema'),
              // Servicio del sistema apagado → interruptor de Ubicación.
              child: const Text('Activar ubicación'),
            )
          else if (esPermiso)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'ajustes'),
              // Permiso de la app bloqueado → Ajustes de la app.
              child: const Text('Abrir permisos de la app'),
            ),
          RyButton(
            label: 'Reintentar',
            variant: RyButtonVariant.primary,
            onPressed: () => Navigator.pop(dialogContext, 'reintentar'),
          ),
        ],
      ),
    );

    if (accion == 'reintentar') continue;
    if (accion == 'ajustesSistema') {
      await service.abrirAjustesSistema();
      continue; // Al volver de Ajustes del sistema se reintenta la fijación
    }
    if (accion == 'ajustes') {
      await service.abrirAjustes();
      continue; // Al volver de Ajustes de la app se reintenta la fijación
    }
    // 'manual' o diálogo cerrado: degradación controlada (el backend
    // geocodifica la dirección antes de aceptar).
    return const UbicacionResultado(
      estado: UbicacionEstado.noDisponible,
      mensaje: 'Ubicación ingresada manualmente',
    );
  }
}
