import 'api_client.dart';
import '../models/orden_compra.dart';
import '../utils/api_error_handler.dart';

class OrdenCompraService {
  final ApiClient _apiClient = ApiClient();

  Future<OrdenCompra> getOrdenDetalle(String ordenId) async {
    final jsonData = await _apiClient.get('/orders/$ordenId');
    if (jsonData.isEmpty) {
      throw ApiException('Respuesta vacía del servidor');
    }

    final data = jsonData['data'] as Map<String, dynamic>?;
    if (data != null) {
      return OrdenCompra.fromJson(data);
    }
    return OrdenCompra.fromJson(jsonData);
  }

  Future<Map<String, dynamic>> actualizarEstadoOrden(
    String ordenId,
    String nuevoEstado,
  ) async {
    return _apiClient.patch(
      '/orders/$ordenId/status',
      body: {'estado': nuevoEstado},
    );
  }
}
