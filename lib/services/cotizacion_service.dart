import 'api_client.dart';
import '../models/cotizacion.dart';

class CotizacionService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Cotizacion>> obtenerCotizacionesPorSolicitud(
    String solicitudId,
  ) async {
    final jsonData = await _apiClient.getList(
      '/quotations/request/$solicitudId',
    );
    return jsonData.map(Cotizacion.fromJson).toList();
  }

  Future<Map<String, dynamic>> aceptarCotizacion(String cotizacionId) async {
    return _apiClient.post('/quotations/$cotizacionId/accept');
  }

  Future<Map<String, dynamic>> rechazarCotizacion(String cotizacionId) async {
    return _apiClient.post('/quotations/$cotizacionId/reject');
  }
}
