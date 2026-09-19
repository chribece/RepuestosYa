import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import 'outbox.dart';
import 'solicitud_repository.dart';
import 'solicitud_service.dart';
import 'upload_service.dart';

/// LWW (Last-Write-Wins) Strategy:
///
/// `updatedAt` es el timestamp de referencia para LWW. Actualmente no se
/// ejecuta resolución de conflictos porque no existe edición concurrente de
/// usuarios sobre una misma solicitud.
///
/// La cola no tiene todavía una idempotency-key reconocida por el backend. Si
/// la app se cierra después del CREATE remoto y antes de borrar Outbox, podría
/// repetirse la operación al reanudar. La mitigación futura es enviar
/// `clientId` como idempotency-key y deduplicarlo en backend.
///
/// Disparadores de procesamiento (para no depender SOLO del evento de
/// conectividad, que es poco fiable en algunos OEMs/Android):
///   1. 2 s tras el arranque.
///   2. Evento de conectividad (offline → online).
///   3. Timer periódico: reintenta la cola aunque el evento de conectividad
///      no dispare (p. ej. algunos dispositivos no emiten el cambio al salir
///      del modo avión).
///   4. Reanudación de la app (AppLifecycleListener).
///
/// Estados: los errores transitorios pasan por `FAILED`; el quinto intento
/// de un error de NEGOCIO pasa a `DEAD` (reintento/descarte manual). Los
/// errores de RED nunca marcan `DEAD`: son transitorios y se reintentan con
/// el timer periódico hasta que la conexión real vuelva.
class SyncEngine {
  final OutboxService _outbox;
  final SolicitudRepository _repository;
  final SolicitudService _solicitudService = SolicitudService();

  /// Intervalo del reintento periódico de la cola (respaldo del evento de
  /// conectividad, que falla en algunos dispositivos al salir del modo avión).
  static const Duration _retryInterval = Duration(seconds: 15);

  bool _isProcessing = false;
  final Set<String> _syncingItems = {};

  SyncEngine(this._outbox, this._repository) {
    _init();
  }

  void _init() {
    // Esperar un momento antes de procesar por primera vez para dejar que el sistema inicie
    Future.delayed(const Duration(seconds: 2), () {
      procesarCola();
    });

    Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        AppLogger.info(
          'Conexión recuperada, procesando cola Outbox',
          name: 'SyncEngine',
        );
        procesarCola();
      }
    });

    // Respaldo periódico: garantiza el envío aunque el evento de conectividad
    // no dispare (p. ej. al desactivar modo avión en ciertos dispositivos).
    // Sin referencia: el Timer queda vivo en el event loop mientras la app corre.
    Timer.periodic(_retryInterval, (_) {
      procesarCola();
    });

    // Reintentar también al volver a primer plano la app. Sin referencia: el
    // listener queda registrado en WidgetsBinding (lo mantiene vivo).
    AppLifecycleListener(
      onResume: () {
        AppLogger.info(
          'App reanudada, procesando cola Outbox',
          name: 'SyncEngine',
        );
        procesarCola();
      },
    );
  }

  Future<void> procesarCola() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      AppLogger.debug(
        'SyncEngine: Iniciando procesamiento de cola...',
        name: 'SyncEngine',
      );
      final pendientes = await _outbox.pendientes();
      AppLogger.debug(
        'SyncEngine: ${pendientes.length} items pendientes encontrados',
        name: 'SyncEngine',
      );

      for (var item in pendientes) {
        if (_syncingItems.contains(item.clientId) || item.status == 'DEAD') {
          continue;
        }

        // Ejecutar procesamiento asíncrono para no bloquear el bucle
        _processItem(item);
      }
    } catch (e) {
      AppLogger.error(
        'ERROR CRÍTICO en SyncEngine.procesarCola: $e',
        name: 'SyncEngine',
      );
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processItem(OutboxData item) async {
    if (_syncingItems.contains(item.clientId)) return;

    _syncingItems.add(item.clientId);
    try {
      await _outbox.updateStatus(item.clientId, 'SYNCING');

      if (item.entityType == 'solicitud' && item.operation == 'CREATE') {
        await _processSolicitud(item);
      } else if (item.entityType == 'cotizacion' && item.operation == 'CREATE') {
        await _processCotizacion(item);
      } else {
        await _outbox.updateStatus(
          item.clientId,
          'DEAD',
          error: 'operación no soportada: ${item.operation}',
        );
        return;
      }

      // Éxito: eliminar de Outbox después de confirmar la creación remota.
      await _outbox.deleteItem(item.clientId);
      AppLogger.info(
        'Item ${item.clientId} sincronizado y eliminado de Outbox',
        name: 'SyncEngine',
      );
    } catch (e) {
      final isNetworkError = _isNetworkError(e);
      final nextAttempt = item.attempts + 1;
      // Los errores de red son transitorios: nunca DEAD, se reintentan con el
      // timer periódico / evento de conectividad hasta que la conexión vuelva.
      // Solo los errores de negocio (4xx/5xx) agotan intentos hasta DEAD.
      final status = (!isNetworkError && nextAttempt >= 5) ? 'DEAD' : 'FAILED';

      await _outbox.updateStatus(item.clientId, status, error: e.toString());
      AppLogger.warning(
        'Fallo en sincronización de ${item.clientId}: $e. Intento: $nextAttempt',
        name: 'SyncEngine',
      );

      if (status == 'FAILED' && !isNetworkError) {
        // Programar reintento con backoff exponencial: 2s * 2^attempts
        final delaySeconds = 2 * (1 << nextAttempt);
        Timer(Duration(seconds: delaySeconds), () {
          procesarCola();
        });
      } else if (status == 'FAILED') {
        // Error de red: el reintento lo cubren el timer periódico y el
        // listener de conectividad (no se programa backoff adicional).
        AppLogger.info(
          'Error de red en ${item.clientId}; reintento en el próximo ciclo',
          name: 'SyncEngine',
        );
      } else {
        AppLogger.error(
          'Item ${item.clientId} marcado como DEAD tras 5 intentos.',
          name: 'SyncEngine',
        );
      }
    } finally {
      _syncingItems.remove(item.clientId);
    }
  }

  /// Distingue errores de red (transitorios) de errores de negocio (permanentes).
  bool _isNetworkError(Object e) {
    if (e is ApiException) {
      return e.statusCode == null || e.statusCode == 0 || e.statusCode == 504;
    }
    return e is SocketException || e is TimeoutException;
  }

  Future<void> _processSolicitud(OutboxData item) async {
    final payload = json.decode(item.payload) as Map<String, dynamic>;
    // Clave de idempotencia generada al encolar: estable para todos los
    // reintentos. Los items legacy (antes de la migración v9) usan clientId.
    final idempotencyKey = item.idempotencyKey ?? item.clientId;

    String? fotoUrl = payload['foto_url'];
    File? localImageFile;
    final localImagePath = payload['local_image_path'] as String?;

    if (localImagePath != null && localImagePath.isNotEmpty) {
      AppLogger.info(
        'Subiendo imagen pendiente para item ${item.clientId}',
        name: 'SyncEngine',
      );
      localImageFile = File(localImagePath);
      if (!await localImageFile.exists()) {
        throw Exception('imagen local no encontrada: $localImagePath');
      }

      // Nombre del objeto derivado de la key: un reintento sobrescribe el
      // mismo objeto en vez de crear un duplicado (hallazgo [12]).
      final uploadedUrl = await UploadService().uploadRequestImage(
        localImageFile,
        payload['cliente_id'],
        idempotencyKey: idempotencyKey,
      );
      if (uploadedUrl != null) {
        fotoUrl = uploadedUrl;
      } else {
        throw Exception('Fallo al subir la imagen durante la sincronización');
      }
    }

    final response = await _solicitudService.crearSolicitud(
      clienteId: payload['cliente_id'],
      vehiculoId: payload['vehiculo_id'],
      piezaNombre: payload['pieza_nombre'],
      descripcion: payload['descripcion'],
      fotoUrl: fotoUrl,
      direccionEntregaId: payload['direccion_entrega_id'],
      esUrgente: payload['es_urgente'] == true,
      categoriaId: payload['categoria_id'],
      repuestoId: payload['repuesto_id'],
      repuestoNombreSnapshot: payload['repuesto_nombre_snapshot'],
      descripcionProblema: payload['descripcion_problema'],
      idempotencyKey: idempotencyKey,
    );

    final serverSolicitud = Solicitud(response);
    await _repository.marcarSincronizado(item.clientId, serverSolicitud);

    // El archivo solo se elimina después de confirmar subida y CREATE remoto.
    if (localImageFile != null) {
      try {
        await localImageFile.delete();
      } catch (e) {
        AppLogger.warning(
          'No se pudo limpiar la imagen sincronizada: $e',
          name: 'SyncEngine',
        );
      }
    }
  }

  Future<void> _processCotizacion(OutboxData item) async {
    final payload = json.decode(item.payload) as Map<String, dynamic>;
    final idempotencyKey = item.idempotencyKey ?? item.clientId;

    String? fotoUrl = payload['foto_evidencia_url'];
    File? localImageFile;
    final localImagePath = payload['local_image_path'] as String?;

    if (localImagePath != null && localImagePath.isNotEmpty) {
      AppLogger.info(
        'Subiendo imagen pendiente de cotización para item ${item.clientId}',
        name: 'SyncEngine',
      );
      localImageFile = File(localImagePath);
      if (!await localImageFile.exists()) {
        throw Exception('imagen local no encontrada: $localImagePath');
      }

      final uploadedUrl = await UploadService().uploadQuotationImage(
        localImageFile,
        payload['almacen_id'],
        idempotencyKey: idempotencyKey,
      );
      if (uploadedUrl != null) {
        fotoUrl = uploadedUrl;
      } else {
        throw Exception(
          'Fallo al subir la imagen de cotización durante la sincronización',
        );
      }
    }

    await _solicitudService.crearCotizacion(
      solicitudId: payload['solicitud_id'],
      almacenId: payload['almacen_id'],
      precio: (payload['precio'] as num?)?.toDouble() ?? 0.0,
      notas: payload['notas'],
      fotoUrl: fotoUrl,
      tiempoEntrega: payload['tiempo_entrega_estimado'],
      estadoRepuesto: payload['condicion_repuesto'],
      idempotencyKey: idempotencyKey,
    );

    // La cotización no tiene espejo de display local: se borra la fila
    // pendiente (la entrada de Outbox la elimina el caller tras el 2xx).
    await _outbox.deleteCotizacionPendiente(item.clientId);

    // El archivo solo se elimina después de confirmar subida y CREATE remoto.
    if (localImageFile != null) {
      try {
        await localImageFile.delete();
      } catch (e) {
        AppLogger.warning(
          'No se pudo limpiar la imagen de cotización sincronizada: $e',
          name: 'SyncEngine',
        );
      }
    }
  }
}
