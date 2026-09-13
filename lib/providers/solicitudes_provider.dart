import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/solicitud_repository.dart';
import '../utils/app_logger.dart';

class SolicitudesProvider with ChangeNotifier {
  final SolicitudRepositoryContract _repository;

  List<SolicitudLocal> _solicitudes = [];
  bool _isLoading = false;
  bool _isOffline = false;
  DateTime? _lastSync;

  /// Evita refrescos concurrentes: el listener de conectividad, el Home y el
  /// listado pueden disparar [refreshFromServer] casi a la vez; solo el
  /// primero en ejecutarse hace la petición, el resto se descarta.
  bool _isRefreshing = false;

  StreamSubscription? _solicitudesSubscription;
  StreamSubscription? _connectivitySubscription;

  SolicitudesProvider(SolicitudRepositoryContract repository)
    : _repository = repository {
    _init();
  }

  List<SolicitudLocal> get solicitudes => _solicitudes;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  DateTime? get lastSync => _lastSync;

  void _init() {
    // 1. Escuchar la base de datos local (Reactividad)
    _solicitudesSubscription = _repository.watchTodas().listen((data) {
      AppLogger.info(
        'DB LOCAL: Emitiendo ${data.length} registros',
        name: 'SolicitudesProvider',
      );
      _solicitudes = data;
      notifyListeners();
    });

    // 2. Cargar marca de última sincronización
    _repository.ultimaSincronizacion().then((value) {
      _lastSync = value;
      notifyListeners();
    });

    // 3. Escuchar cambios de conectividad
    _connectivitySubscription = _repository.watchOffline().listen((offline) {
      if (_isOffline != offline) {
        _isOffline = offline;
        notifyListeners();
      }

      if (!offline) {
        // Pequeña espera para que la red asiente: checkConnectivity() puede
        // devolver un falso "offline" justo tras el evento de reconexión y
        // abortar el refresco. Con el delay se evita ese falso negativo.
        Future<void>.delayed(const Duration(milliseconds: 400), () {
          refreshFromServer();
        });
      }
    });

    // Verificación de conexión inicial inmediata
    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    _isOffline = await _repository.isOffline();
    notifyListeners();
    // No llamamos a refreshFromServer aquí para evitar conflictos con el Home
  }

  Future<void> refreshFromServer() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final offline = await _repository.isOffline();

      if (offline) {
        AppLogger.info(
          'SINC-PROV: Sin conexión, trabajando en local',
          name: 'SolicitudesProvider',
        );
        _isOffline = true;
        notifyListeners();
        return;
      }

      _isLoading = true;
      _isOffline = false;
      notifyListeners();

      try {
        AppLogger.info(
          'SINC-PROV: Pidiendo datos...',
          name: 'SolicitudesProvider',
        );
        final remoteData = await _repository.obtenerSolicitudesCliente('');

        AppLogger.info(
          'SINC-PROV: Servidor respondió con ${remoteData.length} solicitudes',
          name: 'SolicitudesProvider',
        );

        final mappedData = remoteData.map((json) => Solicitud(json)).toList();
        await _repository.reemplazarDesdeServidor(mappedData);

        // Sincronizar metadatos para uso offline (Caché)
        unawaited(
          _repository.sincronizarMetadatos().catchError((error) {
            AppLogger.warning(
              'No se pudieron sincronizar todos los metadatos: $error',
              name: 'SolicitudesProvider',
            );
          }),
        );

        _lastSync = await _repository.ultimaSincronizacion();
      } catch (e) {
        AppLogger.error(
          'SINC-PROV: ERROR CRÍTICO: $e',
          name: 'SolicitudesProvider',
        );
      } finally {
        _isLoading = false;
        // IMPORTANTE: Asegurar que _isOffline se actualice después del intento
        _isOffline = await _repository.isOffline();
        notifyListeners();
      }
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  void dispose() {
    _solicitudesSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
