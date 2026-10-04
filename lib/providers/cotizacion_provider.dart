import 'package:flutter/foundation.dart';
import '../models/coordinacion_entrega.dart';
import '../models/cotizacion.dart';
import '../services/cotizacion_repository.dart';
import '../utils/api_error_handler.dart';

class CotizacionProvider extends ChangeNotifier {
  final CotizacionRepository _repository;

  CotizacionProvider({CotizacionRepository? repository})
    : _repository = repository ?? CotizacionRepositoryImpl();

  // Lista de cotizaciones
  List<Cotizacion> _cotizaciones = [];
  List<Cotizacion> get cotizaciones => _cotizaciones;

  // Estado de carga general
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Mensaje de error
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ID de la orden de compra generada al aceptar
  String? _ordenCompraId;
  String? get ordenCompraId => _ordenCompraId;

  // Datos de coordinación de entrega (contacto del almacén ganador) devueltos
  // por el endpoint de aceptación. Null si la respuesta no los incluye.
  DatosCoordinacionEntrega? _coordinacionData;
  DatosCoordinacionEntrega? get coordinacionData => _coordinacionData;

  // Indica si la solicitud fue cerrada (todas las cotizaciones rechazadas)
  bool _solicitudCerrada = false;
  bool get solicitudCerrada => _solicitudCerrada;

  // Mapa para rastrear qué cotización está siendo procesada individualmente
  final Map<String, bool> _cotizacionesProcesando = {};
  bool isCotizacionProcesando(String cotizacionId) {
    return _cotizacionesProcesando[cotizacionId] ?? false;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _setCotizacionProcesando(String cotizacionId, bool procesando) {
    _cotizacionesProcesando[cotizacionId] = procesando;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> cargarCotizaciones(String solicitudId) async {
    try {
      _setLoading(true);
      _setErrorMessage(null);

      final cotizaciones = await _repository.getCotizacionesPorSolicitud(
        solicitudId,
      );
      _cotizaciones = cotizaciones;

      notifyListeners();
    } catch (e) {
      _setErrorMessage(ApiErrorHandler.userMessage(e));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> aceptarCotizacion(String cotizacionId) async {
    try {
      _setCotizacionProcesando(cotizacionId, true);
      _setErrorMessage(null);

      final result = await _repository.aceptarCotizacion(cotizacionId);

      _ordenCompraId = result['ordenId']?.toString();
      _solicitudCerrada = false;

      // Guardar el contacto del almacén ganador para la pantalla de
      // coordinación (solo si la respuesta lo incluye).
      final indice = _cotizaciones.indexWhere((c) => c.id == cotizacionId);
      _coordinacionData = DatosCoordinacionEntrega.fromAceptacionResponse(
        result,
        cotizacionId: cotizacionId,
        solicitudId: indice != -1 ? _cotizaciones[indice].solicitudId : '',
      );

      // Actualización optimista: cambiar estado localmente
      final index = _cotizaciones.indexWhere((c) => c.id == cotizacionId);
      if (index != -1) {
        _cotizaciones[index] = _cotizaciones[index].copyWith(
          estado: 'aceptada',
        );
      }

      notifyListeners();
    } catch (e) {
      _setErrorMessage(ApiErrorHandler.userMessage(e));
    } finally {
      _setCotizacionProcesando(cotizacionId, false);
    }
  }

  Future<void> rechazarCotizacion(String cotizacionId) async {
    try {
      _setCotizacionProcesando(cotizacionId, true);
      _setErrorMessage(null);

      final result = await _repository.rechazarCotizacion(cotizacionId);

      _solicitudCerrada = result['solicitudCerrada'] as bool? ?? false;
      _ordenCompraId = null;

      // Actualización optimista: cambiar estado localmente
      final index = _cotizaciones.indexWhere((c) => c.id == cotizacionId);
      if (index != -1) {
        _cotizaciones[index] = _cotizaciones[index].copyWith(
          estado: 'rechazada',
        );
      }

      notifyListeners();
    } catch (e) {
      _setErrorMessage(ApiErrorHandler.userMessage(e));
    } finally {
      _setCotizacionProcesando(cotizacionId, false);
    }
  }

  void reset() {
    _cotizaciones = [];
    _isLoading = false;
    _errorMessage = null;
    _ordenCompraId = null;
    _coordinacionData = null;
    _solicitudCerrada = false;
    _cotizacionesProcesando.clear();
    notifyListeners();
  }
}
