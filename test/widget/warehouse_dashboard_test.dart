import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repuestosya/pages/warehouse_dashboard.dart';
import 'package:repuestosya/utils/api_error_handler.dart';
import 'package:repuestosya/widgets/ry_part_card.dart';

import '../helpers/fake_connectivity.dart';
import '../helpers/fake_services.dart';

/// Estados del WarehouseDashboard (pantalla principal del rol almacén):
/// verificando perfil (cargando) / con datos / vacía / error. Los servicios
/// están inyectados como dobles; no hay red real.
void main() {
  late FakeConnectivityPlatform conectividad;
  late FakeAlmacenService almacen;
  late FakeSolicitudService solicitud;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      // El rationale de notificaciones ya fue visto: el popup de permiso no
      // debe aparecer (el request nativo no existe en tests y el flujo lo
      // captura silenciosamente).
      'rationale_notificaciones': true,
    });
    conectividad = FakeConnectivityPlatform();
    ConnectivityPlatform.instance = conectividad;

    almacen = FakeAlmacenService()
      ..respuestaMiAlmacen = {
        'id': 'a-1',
        'nombre_comercial': 'Repuestos Central',
        'verification_status': 'approved',
        'estado_abierto': true,
      };
    solicitud = FakeSolicitudService();
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: WarehouseDashboard(
          almacenService: almacen,
          solicitudService: solicitud,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('estado CARGANDO: verificación de perfil sin contenido final', (
    tester,
  ) async {
    almacen.bloquearValidacion = true;
    await pumpDashboard(tester);

    expect(find.text('Verificando perfil de almacén...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    // El feed no debe renderizarse mientras valida.
    expect(find.text('Solicitudes Disponibles'), findsNothing);
  });

  testWidgets('estado CON DATOS: el feed muestra las solicitudes activas', (
    tester,
  ) async {
    solicitud.respuestaActivas = [
      {
        'id': 's1',
        'pieza_nombre': 'Filtro de aceite',
        'es_urgente': true,
        'created_at': '2026-09-20T10:00:00.000Z',
      },
      {
        'id': 's2',
        'pieza_nombre': 'Bujías NGK',
        'es_urgente': false,
        'created_at': '2026-09-21T10:00:00.000Z',
      },
    ];
    await pumpDashboard(tester);

    expect(find.text('Repuestos Central'), findsOneWidget);
    expect(find.text('Filtro de aceite'), findsOneWidget);
    expect(find.text('Bujías NGK'), findsOneWidget);
    expect(find.byType(RyPartCard), findsNWidgets(2));
    expect(solicitud.solicitudesActivasCalls, 1);
  });

  testWidgets(
    'estado CON DATOS: el feed pagina de 5 en 5 con "Cargar más" y muestra '
    'fin de lista sin tocar la métrica del Bento',
    (tester) async {
      solicitud.respuestaActivas = [
        for (var i = 1; i <= 6; i++)
          {
            'id': 's$i',
            'pieza_nombre': 'Pieza $i',
            'created_at': '2026-09-2${i}T10:00:00.000Z',
          },
      ];
      await pumpDashboard(tester);

      // Primera página: solo 5 tarjetas, la 6 no está construida.
      expect(find.byType(RyPartCard), findsNWidgets(5));
      expect(find.text('Pieza 6'), findsNothing);

      // La métrica "Pendientes" del Bento usa la lista COMPLETA (6), no la
      // ventana visible (5).
      expect(find.text('6'), findsOneWidget);

      // El pie de paginación queda debajo del pliegue: desplazar el feed.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();
      expect(find.text('Cargar más'), findsOneWidget);

      // Cargar la siguiente página: indicador breve y luego la 6 + fin.
      await tester.tap(find.text('Cargar más'));
      await tester.pump();
      // Indicador de carga mientras avanza la ventana.
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(RyPartCard), findsNWidgets(6));
      expect(find.text('Pieza 6'), findsOneWidget);
      expect(find.text('Cargar más'), findsNothing);

      // El fin de lista queda bajo la sexta tarjeta: desplazar para verlo.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
      expect(find.text('No hay más solicitudes'), findsOneWidget);
    },
  );

  testWidgets('estado VACÍA: mensaje real de estado vacío del feed', (
    tester,
  ) async {
    solicitud.respuestaActivas = [];
    await pumpDashboard(tester);

    expect(find.text('Sin solicitudes'), findsOneWidget);
    expect(
      find.text(
        'No hay solicitudes activas. Las nuevas peticiones de los clientes aparecerán aquí.',
      ),
      findsOneWidget,
    );
    expect(find.byType(RyPartCard), findsNothing);
  });

  testWidgets('estado ERROR: fallo de validación del perfil con mensaje', (
    tester,
  ) async {
    almacen.falloAlValidar = ApiErrorHandler.fromResponse(
      http.Response('{"error":"internal"}', 500),
    );
    await pumpDashboard(tester);

    expect(
      find.text('No se pudo verificar tu perfil de almacén'),
      findsOneWidget,
    );
    expect(find.text(ApiErrorHandler.serverMessage), findsOneWidget);
    // El feed no se intentó cargar: el fallo ocurrió antes.
    expect(solicitud.solicitudesActivasCalls, 0);
  });
}
