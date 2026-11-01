import 'package:flutter_test/flutter_test.dart';
import 'package:repuestosya/models/almacen.dart';

void main() {
  test('serializa ciudad y tipo de establecimiento', () {
    final almacen = Almacen.fromJson({
      'id': 'warehouse-1',
      'nombre_comercial': 'Repuestos Central',
      'city': 'Quito',
      'tipo_establecimiento': 'sucursal',
    });

    expect(almacen.city, 'Quito');
    expect(almacen.tipoEstablecimiento, 'sucursal');
    expect(almacen.toJson()['city'], 'Quito');
    expect(almacen.toJson()['tipo_establecimiento'], 'sucursal');
  });

  test('mantiene compatibilidad con perfiles existentes sin ciudad', () {
    final almacen = Almacen.fromJson({
      'id': 'warehouse-legacy',
      'nombre_comercial': 'Repuestos Central',
    });

    expect(almacen.city, isNull);
    expect(almacen.tipoEstablecimiento, 'matriz');
  });
}
