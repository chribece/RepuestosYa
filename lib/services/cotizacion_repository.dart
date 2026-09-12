import '../models/cotizacion.dart';
import 'cotizacion_service.dart';

abstract class CotizacionRepository {
  Future<List<Cotizacion>> getCotizacionesPorSolicitud(String solicitudId);

  Future<Map<String, dynamic>> aceptarCotizacion(String cotizacionId);

  Future<Map<String, dynamic>> rechazarCotizacion(String cotizacionId);
}

class CotizacionRepositoryImpl implements CotizacionRepository {
  final CotizacionService _remote;

  CotizacionRepositoryImpl({CotizacionService? remote})
    : _remote = remote ?? CotizacionService();

  @override
  Future<List<Cotizacion>> getCotizacionesPorSolicitud(String solicitudId) {
    return _remote.obtenerCotizacionesPorSolicitud(solicitudId);
  }

  @override
  Future<Map<String, dynamic>> aceptarCotizacion(String cotizacionId) {
    return _remote.aceptarCotizacion(cotizacionId);
  }

  @override
  Future<Map<String, dynamic>> rechazarCotizacion(String cotizacionId) {
    return _remote.rechazarCotizacion(cotizacionId);
  }
}
