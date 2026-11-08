import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repuestosya/models/orden_compra.dart';
import 'package:repuestosya/pages/almacen_orden_detalle_page.dart';
import 'package:repuestosya/services/orden_compra_service.dart';

/// Respuesta de `GET /orders/:id` para el almacén, con la forma real que
/// devuelve `getOrdenDetalleParaAlmacen` (cliente y dirección embebidos).
const _ordenId = '0f3e2ed1-5839-4a2a-a898-c31601b301b9';

final _respuesta = <String, dynamic>{
  'id': _ordenId,
  'cliente_id': 'cliente-1',
  'almacen_id': 'almacen-1',
  'solicitud_id': '9a8b7c6d-1111-2222-3333-44445555aaaa',
  'cotizacion_id': 'cotizacion-1',
  'estado': 'confirmada',
  'created_at': '2026-09-20T10:00:00.000Z',
  'updated_at': '2026-09-20T10:00:00.000Z',
  'almacenes': {'nombre_comercial': 'Test Almaceb', 'direccion_texto': null},
  'detalles': {
    'precio_venta': 22,
    'condicion_repuesto': 'Nuevo',
    'tiempo_entrega_estimado': '24 horas',
  },
  'solicitudes_repuesto': {
    'profiles': {'nombre_completo': 'Test Cliente', 'telefono': '981425412'},
    'direcciones_entrega': {'alias': 'taller', 'calle_principal': 'venezuela'},
  },
};

class _FakeOrdenService extends OrdenCompraService {
  @override
  Future<OrdenCompra> getOrdenDetalle(String ordenId) async =>
      OrdenCompra.fromJson(_respuesta);
}

void main() {
  Future<void> pumpPagina(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AlmacenOrdenDetallePage(
          ordenId: _ordenId,
          ordenService: _FakeOrdenService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('badge con estado capitalizado y número de orden corto', (
    tester,
  ) async {
    await pumpPagina(tester);

    expect(find.text('Confirmada'), findsOneWidget);
    expect(find.text('confirmada'), findsNothing);
    expect(find.text('Orden #B301B9'), findsOneWidget);
    expect(find.textContaining(_ordenId), findsNothing);
  });

  testWidgets('datos del cliente y entrega reemplazan los fallbacks', (
    tester,
  ) async {
    await pumpPagina(tester);

    expect(find.text('Test Cliente'), findsOneWidget);
    expect(find.text('0981425412'), findsOneWidget);
    expect(find.text('Taller, Venezuela'), findsOneWidget);
    expect(find.text('No disponible'), findsNothing);
    expect(find.text('No registrado'), findsNothing);
    expect(find.text('No registrada'), findsNothing);
  });

  testWidgets('precio con dos decimales en la fila de detalles', (
    tester,
  ) async {
    await pumpPagina(tester);

    expect(find.text('\$22.00'), findsOneWidget);
  });
}
