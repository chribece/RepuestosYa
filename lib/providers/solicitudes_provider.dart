import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/solicitud_service.dart';
import '../services/solicitud_repository.dart';
import '../services/catalog_service.dart';
import '../services/vehiculo_service.dart';
import '../services/direccion_service.dart';
import '../database/app_database.dart';
import '../utils/app_logger.dart';

class SolicitudesProvider with ChangeNotifier {
  final SolicitudService _service = SolicitudService();
  final SolicitudRepository _repository;

  List<SolicitudLocal> _solicitudes = [];
  bool _isLoading = false;
  bool _isOffline = false;
  DateTime? _lastSync;

  StreamSubscription? _solicitudesSubscription;
  StreamSubscription? _connectivitySubscription;

  SolicitudesProvider(this._repository) {
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
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final bool offline = results.contains(ConnectivityResult.none);

      if (_isOffline != offline) {
        _isOffline = offline;
        notifyListeners();
      }

      if (!offline) {
        refreshFromServer();
      }
    });

    // Verificación de conexión inicial inmediata
    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _isOffline = results.contains(ConnectivityResult.none);
    notifyListeners();
    // No llamamos a refreshFromServer aquí para evitar conflictos con el Home
  }

  Future<void> refreshFromServer() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    if (connectivityResults.contains(ConnectivityResult.none)) {
      _isOffline = true;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _isOffline = false;
    notifyListeners();

    try {
      AppLogger.info('SINCRO: Pidiendo datos...', name: 'SolicitudesProvider');
      final remoteData = await _service.obtenerSolicitudesCliente('');

      AppLogger.info(
        'SINCRO: Servidor entregó ${remoteData.length} items',
        name: 'SolicitudesProvider',
      );

      final mappedData = remoteData.map((json) => Solicitud(json)).toList();
      await _repository.reemplazarDesdeServidor(mappedData);

      // Sincronizar metadatos para uso offline (Caché)
      _sincronizarMetadatos();

      _lastSync = await _repository.ultimaSincronizacion();
    } catch (e) {
      AppLogger.error(
        'SINCRO: Error de red/servidor: $e',
        name: 'SolicitudesProvider',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _sincronizarMetadatos() async {
    try {
      AppLogger.info(
        'Sincronizando metadatos (caché offline)...',
        name: 'SolicitudesProvider',
      );

      final categorias = await CatalogService().getPartCategories();
      await _repository.guardarCategorias(categorias);

      final vehiculos = await VehiculoService().getVehiculos();
      await _repository.guardarVehiculos(vehiculos);

      final direcciones = await DireccionService().getDirecciones();
      await _repository.guardarDirecciones(direcciones);

      AppLogger.info(
        'Metadatos sincronizados con éxito',
        name: 'SolicitudesProvider',
      );
    } catch (e) {
      AppLogger.warning(
        'No se pudieron sincronizar todos los metadatos: $e',
        name: 'SolicitudesProvider',
      );
    }
  }

  @override
  void dispose() {
    _solicitudesSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
