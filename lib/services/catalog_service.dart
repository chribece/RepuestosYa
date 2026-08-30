import '../models/part_catalog.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import 'api_client.dart';

class CatalogService {
  final ApiClient _apiClient = ApiClient();

  /// Obtener todas las categorías de repuestos activas
  Future<List<PartCategory>> getPartCategories() async {
    try {
      final response = await _apiClient.getList('/catalog/part-categories');
      return response.map((json) => PartCategory.fromJson(json)).toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      AppLogger.error(
        'Error en getPartCategories',
        error: e,
        name: 'CatalogService',
      );
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'getPartCategories: $e',
      );
    }
  }

  /// Obtener repuestos del catálogo, opcionalmente filtrados por categoría o búsqueda
  Future<List<CatalogPart>> getParts({
    String? categoryId,
    String? query,
  }) async {
    try {
      final Map<String, String> queryParams = {};
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (query != null && query.isNotEmpty) queryParams['q'] = query;

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final response = await _apiClient.getList('/catalog/parts$queryString');
      return response.map((json) => CatalogPart.fromJson(json)).toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      AppLogger.error('Error en getParts', error: e, name: 'CatalogService');
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'getParts: $e',
      );
    }
  }
}
