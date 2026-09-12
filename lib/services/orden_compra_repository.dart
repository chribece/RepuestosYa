import '../models/orden_compra.dart';
import 'orden_compra_service.dart';

abstract class OrdenCompraRepository {
  Future<OrdenCompra> getOrdenDetalle(String ordenId);

  Future<Map<String, dynamic>> actualizarEstadoOrden(
    String ordenId,
    String nuevoEstado,
  );
}

class OrdenCompraRepositoryImpl implements OrdenCompraRepository {
  final OrdenCompraService _remote;

  OrdenCompraRepositoryImpl({OrdenCompraService? remote})
    : _remote = remote ?? OrdenCompraService();

  @override
  Future<OrdenCompra> getOrdenDetalle(String ordenId) {
    return _remote.getOrdenDetalle(ordenId);
  }

  @override
  Future<Map<String, dynamic>> actualizarEstadoOrden(
    String ordenId,
    String nuevoEstado,
  ) {
    return _remote.actualizarEstadoOrden(ordenId, nuevoEstado);
  }
}
