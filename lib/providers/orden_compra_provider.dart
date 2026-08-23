import 'package:flutter/foundation.dart';
import '../models/orden_compra.dart';
import '../services/orden_compra_service.dart';
import '../utils/api_error_handler.dart';

class OrdenCompraProvider extends ChangeNotifier {
  final OrdenCompraService _ordenCompraService = OrdenCompraService();

  // Estado de carga
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Mensaje de error
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Orden de compra
  OrdenCompra? _orden;
  OrdenCompra? get orden => _orden;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> cargarOrden(String ordenId) async {
    try {
      _setLoading(true);
      _setErrorMessage(null);

      final orden = await _ordenCompraService.getOrdenDetalle(ordenId);
      _orden = orden;

      notifyListeners();
    } catch (e) {
      _setErrorMessage(ApiErrorHandler.userMessage(e));
    } finally {
      _setLoading(false);
    }
  }

  void reset() {
    _isLoading = false;
    _errorMessage = null;
    _orden = null;
    notifyListeners();
  }
}
