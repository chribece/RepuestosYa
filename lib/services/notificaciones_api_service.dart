import '../models/notificacion.dart';
import 'api_client.dart';

class NotificacionesApiService {
  final ApiClient _apiClient;

  NotificacionesApiService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<int> contarNoLeidas() async {
    final response = await _apiClient.get('/notificaciones/unread-count');
    final count = response['unreadCount'];
    if (count is int) return count;
    return int.tryParse(count?.toString() ?? '') ?? 0;
  }

  Future<PaginaNotificaciones> listar({
    required int page,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      '/notificaciones',
      queryParams: {'page': '$page', 'limit': '$limit'},
    );
    final rawItems = response['items'];
    if (rawItems is! List) {
      throw const FormatException(
        'La respuesta de notificaciones no contiene items.',
      );
    }
    return PaginaNotificaciones(
      items: rawItems
          .whereType<Map>()
          .map((item) => Notificacion.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      page: int.tryParse(response['page']?.toString() ?? '') ?? page,
      limit: int.tryParse(response['limit']?.toString() ?? '') ?? limit,
      hasMore: response['hasMore'] == true,
    );
  }

  Future<DateTime?> marcarLeida(String id) async {
    final response = await _apiClient.patch(
      '/notificaciones/${Uri.encodeComponent(id)}/leer',
    );
    return DateTime.tryParse(response['leido_en']?.toString() ?? '');
  }

  Future<int> marcarTodasLeidas() async {
    final response = await _apiClient.patch('/notificaciones/leer-todas');
    return int.tryParse(response['actualizadas']?.toString() ?? '') ?? 0;
  }
}
