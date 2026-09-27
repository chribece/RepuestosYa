import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:repuestosya/pages/home_page.dart';
import 'package:repuestosya/providers/solicitudes_provider.dart';
import 'package:repuestosya/services/auth_service.dart';
import 'package:repuestosya/utils/api_error_handler.dart';
import 'package:repuestosya/widgets/ry_part_card.dart';

import '../helpers/fake_connectivity.dart';
import '../helpers/fake_solicitud_repository.dart';

/// Los 4 estados de la sección "Mis Solicitudes" del Home del cliente
/// (Fase 2 de docs/TESTING.md): cargando / con datos / vacía / error.
///
/// La fuente de datos es el [FakeSolicitudRepository] reutilizable (Fase 4),
/// inyectado vía [SolicitudesProvider]; el transporte HTTP nunca se toca.
void main() {
  late FakeConnectivityPlatform conectividad;

  setUp(() {
    conectividad = FakeConnectivityPlatform();
    ConnectivityPlatform.instance = conectividad;
    // Garantiza que el singleton de Auth no arrastre sesión entre tests.
    AuthService().currentUserForTesting = null;
  });

  Future<SolicitudesProvider> pumpHome(
    WidgetTester tester,
    FakeSolicitudRepository fake,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = SolicitudesProvider(fake);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SolicitudesProvider>.value(
        value: provider,
        child: const MaterialApp(home: HomePage()),
      ),
    );
    // Primer frame + post-frame del Home (dispara refreshFromServer).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return provider;
  }

  testWidgets('estado CARGANDO: spinner y título, sin contenido final', (
    tester,
  ) async {
    final fake = FakeSolicitudRepository()..setOnline(true);
    // La respuesta del "servidor" nunca llega → isLoading permanece true.
    fake.bloquearRespuesta();
    await pumpHome(tester, fake);

    expect(find.text('Cargando solicitudes...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    // El contenido final (tarjetas / estado vacío) NO debe renderizarse.
    expect(find.text('Sin solicitudes'), findsNothing);
    expect(find.byType(RyPartCard), findsNothing);
  });

  testWidgets('estado CON DATOS: las tarjetas renderizan los datos reales', (
    tester,
  ) async {
    final fake = FakeSolicitudRepository()..setOnline(true);
    fake.setRespuestaServidor([
      {
        'id': 'srv-1',
        'pieza_nombre': 'Filtro de aceite',
        'estado': 'pendiente',
        'created_at': '2026-09-20T10:00:00.000Z',
      },
      {
        'id': 'srv-2',
        'pieza_nombre': 'Bujías NGK',
        'estado': 'en_proceso',
        'created_at': '2026-09-21T10:00:00.000Z',
      },
    ]);
    final provider = await pumpHome(tester, fake);

    // El provider recibió los datos del "servidor" y la UI los muestra.
    expect(provider.solicitudes, hasLength(2));
    expect(find.text('Filtro de aceite'), findsOneWidget);
    expect(find.text('Bujías NGK'), findsOneWidget);
    // Con datos no se muestra ni loading ni vacío.
    expect(find.text('Cargando solicitudes...'), findsNothing);
    expect(find.text('Sin solicitudes'), findsNothing);

    // Las estadísticas locales derivan de la lista (2 activas → '02' en las
    // dos tarjetas que las cuentan: Activas y En Proceso).
    expect(find.text('02'), findsNWidgets(2));
  });

  testWidgets('estado VACÍA: mensaje real de estado vacío con CTA', (
    tester,
  ) async {
    final fake = FakeSolicitudRepository()..setOnline(true);
    fake.setRespuestaServidor([]);
    await pumpHome(tester, fake);

    expect(find.text('Sin solicitudes'), findsOneWidget);
    expect(find.text('Crea tu primera solicitud de repuesto'), findsOneWidget);
    expect(find.byType(RyPartCard), findsNothing);
  });

  testWidgets(
    'estado ERROR: la sincronización falla → banner de datos desactualizados '
    'con reintento (la pantalla no expone error en crudo, riesgo R15)',
    (tester) async {
      final fake = FakeSolicitudRepository()
        ..setOnline(true)
        ..setUltimaSincronizacion(
          DateTime.now().subtract(const Duration(minutes: 11)),
        );
      // El backend falla (500): el provider traga el error (R15).
      fake.setFalloAlObtener(
        ApiErrorHandler.fromResponse(
          http.Response('{"error":"internal"}', 500),
        ),
      );
      final provider = await pumpHome(tester, fake);

      // No hay estado de error dedicado: queda el vacío + banner con CTA.
      expect(fake.llamadasObtener, 1);
      expect(provider.isLoading, isFalse);
      expect(find.text('Datos desactualizados'), findsOneWidget);
      expect(find.text('SINCRONIZAR'), findsOneWidget);

      // El CTA del banner es la acción de reintento real.
      await tester.tap(find.text('SINCRONIZAR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fake.llamadasObtener, greaterThanOrEqualTo(2));
    },
  );
}
