import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/app_logger.dart';
import 'outbox.dart';
import 'solicitud_repository.dart';
import 'solicitud_service.dart';
import 'upload_service.dart';
import '../database/app_database.dart';

/// LWW (Last-Write-Wins) Strategy:
///
/// LWW sacrifica cambios concurrentes entre dos dispositivos sobre el mismo registro;
/// es aceptable porque cada solicitud tiene un único cliente-autor y no hay edición
/// simultánea entre usuarios distintos sobre la misma fila.
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
    _syncingItems.add(item.clientId);
    await _outbox.updateStatus(item.clientId, 'SYNCING');

    try {
      if (item.entityType == 'solicitud') {
        await _processSolicitud(item);
      }

      // Éxito: Eliminar de outbox
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
        // TODO: Notificar al usuario que el item está DEAD (requiere reintento manual)
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

    if (item.operation == 'CREATE') {
      String? fotoUrl = payload['foto_url'];
      final localImagePath = payload['local_image_path'] as String?;

      // Si hay una imagen local pendiente de subir
      if (localImagePath != null && localImagePath.isNotEmpty) {
        AppLogger.info(
          'Subiendo imagen pendiente para item ${item.clientId}',
          name: 'SyncEngine',
        );
        final file = File(localImagePath);
        if (await file.exists()) {
          final uploadedUrl = await UploadService().uploadRequestImage(
            file,
            payload['cliente_id'],
          );
          if (uploadedUrl != null) {
            fotoUrl = uploadedUrl;
          } else {
            throw Exception(
              'Fallo al subir la imagen durante la sincronización',
            );
          }
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
    }
    // TODO: Implementar UPDATE y DELETE cuando el backend soporte estos endpoints
  }
}
