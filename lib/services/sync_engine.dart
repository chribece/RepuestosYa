import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
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
/// Los fallos transitorios pasan por `FAILED` en los primeros cuatro intentos;
/// el quinto intento pasa a `DEAD` y requiere reintento o descarte manual.
class SyncEngine {
  final OutboxService _outbox;
  final SolicitudRepository _repository;
  final SolicitudService _solicitudService = SolicitudService();

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

      if (item.entityType != 'solicitud' || item.operation != 'CREATE') {
        await _outbox.updateStatus(
          item.clientId,
          'DEAD',
          error: 'operación no soportada: ${item.operation}',
        );
        return;
      }

      await _processSolicitud(item);

      // Éxito: eliminar de Outbox después de confirmar la creación remota.
      await _outbox.deleteItem(item.clientId);
      AppLogger.info(
        'Item ${item.clientId} sincronizado y eliminado de Outbox',
        name: 'SyncEngine',
      );
    } catch (e) {
      final nextAttempt = item.attempts + 1;
      final status = nextAttempt >= 5 ? 'DEAD' : 'FAILED';

      await _outbox.updateStatus(item.clientId, status, error: e.toString());
      AppLogger.warning(
        'Fallo en sincronización de ${item.clientId}: $e. Intento: $nextAttempt',
        name: 'SyncEngine',
      );

      if (status == 'FAILED') {
        // Programar reintento con backoff exponencial: 2s * 2^attempts
        final delaySeconds = 2 * (1 << nextAttempt);
        Timer(Duration(seconds: delaySeconds), () {
          procesarCola();
        });
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

  Future<void> _processSolicitud(OutboxData item) async {
    final payload = json.decode(item.payload) as Map<String, dynamic>;
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

      final uploadedUrl = await UploadService().uploadRequestImage(
        localImageFile,
        payload['cliente_id'],
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
}
