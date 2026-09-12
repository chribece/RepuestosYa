import 'vehiculo_service.dart';

abstract class VehiculoRepository {
  Future<List<Map<String, dynamic>>> getVehiculos();
}

class VehiculoRepositoryImpl implements VehiculoRepository {
  final VehiculoService _remote;

  VehiculoRepositoryImpl({VehiculoService? remote})
    : _remote = remote ?? VehiculoService();

  @override
  Future<List<Map<String, dynamic>>> getVehiculos() {
    return _remote.getVehiculos();
  }
}
