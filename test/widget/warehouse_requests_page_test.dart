import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/pages/warehouse_requests_page.dart';
import 'package:repuestosya/widgets/ry_part_card.dart';

import '../helpers/fake_services.dart';

/// Listado completo de solicitudes ("Ver todas"): a diferencia de la vista
/// previa del Home, debe renderizar TODAS las solicitudes del feed.
void main() {
  late FakeSolicitudService solicitud;

  setUp(() {
    solicitud = FakeSolicitudService();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: WarehouseRequestsPage(solicitudService: solicitud)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets(
    'muestra todas las solicitudes sin el límite de la vista previa',
    (tester) async {
      solicitud.respuestaActivas = [
        for (var i = 1; i <= 6; i++)
          {
            'id': 's$i',
            'pieza_nombre': 'Pieza $i',
            'created_at': '2026-09-2${i}T10:00:00.000Z',
          },
      ];
      await pumpPage(tester);

      expect(solicitud.solicitudesActivasCalls, 1);
      expect(find.text('Solicitudes Disponibles'), findsOneWidget);
      expect(find.byType(RyPartCard), findsNWidgets(6));
      expect(find.text('Pieza 6', skipOffstage: false), findsOneWidget);
    },
  );

  testWidgets('estado VACÍA: mensaje de estado vacío', (tester) async {
    solicitud.respuestaActivas = [];
    await pumpPage(tester);

    expect(find.text('Sin solicitudes'), findsOneWidget);
    expect(find.byType(RyPartCard), findsNothing);
  });
}
