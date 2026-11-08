import '../models/orden_compra.dart';
import 'orden_compra_service.dart';

abstract class OrdenCompraRepository {
  Future<OrdenCompra> getOrdenDetalle(String ordenId);

  Future<Map<String, dynamic>> actualizarEstadoOrden(
    String ordenId,
    String nuevoEstado,
  );

  Future<Map<String, dynamic>> calificarOrden(
    String ordenId, {
    required int estrellas,
    String? comentario,
  });
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
  Future<Map<String, dynamic>> calificarOrden(
    String ordenId, {
    required int estrellas,
    String? comentario,
  }) {
    return _remote.calificarOrden(
      ordenId,
      estrellas: estrellas,
      comentario: comentario,
    );
  }

  @override
  Future<Map<String, dynamic>> actualizarEstadoOrden(
    String ordenId,
    String nuevoEstado,
  ) {
    return _remote.actualizarEstadoOrden(ordenId, nuevoEstado);
  }
}
