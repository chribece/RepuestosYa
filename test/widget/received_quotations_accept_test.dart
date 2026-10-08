import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repuestosya/pages/coordinacion_entrega_page.dart';
import 'package:repuestosya/pages/received_quotations_page.dart';
import 'package:repuestosya/router/route_names.dart';
import 'package:repuestosya/services/auth_service.dart';
import 'package:repuestosya/services/solicitud_service.dart';
import 'package:repuestosya/utils/api_error_handler.dart';

import '../helpers/fake_connectivity.dart';

/// Doble del servicio de solicitudes: scriptable para el flujo de aceptación
/// de cotizaciones (sin red real).
class _FakeSolicitudService extends SolicitudService {
  int aceptarCalls = 0;
  Object? falloAlAceptar;

  Map<String, dynamic> respuestaAceptar = {
    'ordenId': 'ord-1',
    'almacen': {
      'nombre': 'Repuestos Central',
      'telefono': '0991234567',
      'email': 'contacto@repuestoscentral.com',
    },
    'repuestoNombre': 'Filtro de aceite',
    'precioVenta': 45.5,
  };

  List<Map<String, dynamic>> respuestaCotizaciones = [];
  Map<String, dynamic> respuestaSolicitud = {
    'id': 's1',
    'estado': 'en_proceso',
    'pieza_nombre': 'Filtro de aceite',
  };

  @override
  Future<List<Map<String, dynamic>>> obtenerCotizacionesRecibidas(
    String solicitudId,
  ) async {
    return respuestaCotizaciones;
  }

  @override
  Future<Map<String, dynamic>> obtenerSolicitudPorId(String id) async {
    return respuestaSolicitud;
  }

  @override
  Future<Map<String, dynamic>> aceptarCotizacion(String cotizacionId) async {
    aceptarCalls++;
    if (falloAlAceptar != null) throw falloAlAceptar!;
    return respuestaAceptar;
  }
}

Map<String, dynamic> cotizacionPendiente({
  String id = 'c1',
  double precio = 45.5,
}) {
  return {
    'id': id,
    'precio_venta': precio,
    'estado': 'pendiente',
    'tiempo_entrega_estimado': 'Mañana',
    'created_at': '2026-10-01T10:00:00.000Z',
    'distancia_km': 2.5,
    'almacenes': {'nombre_comercial': 'Repuestos Central'},
  };
}

void main() {
  late FakeConnectivityPlatform conectividad;
  late _FakeSolicitudService servicio;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    conectividad = FakeConnectivityPlatform();
    ConnectivityPlatform.instance = conectividad;
    servicio = _FakeSolicitudService();
    // El cliente ya tiene teléfono registrado: el gate de "completar
    // teléfono" no debe aparecer en los flujos normales de aceptación.
    AuthService().currentUserForTesting = User(
      id: 'cliente-1',
      email: 'cliente@test.com',
      nombreCompleto: 'Cliente E2E',
      rol: 'cliente',
      telefono: '0991234567',
    );
  });

  tearDown(() {
    AuthService().currentUserForTesting = null;
  });

  Future<void> pumpPagina(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/solicitudes/s1',
      routes: [
        GoRoute(
          path: '/solicitudes/:id',
          name: RouteNames.receivedQuotations,
          builder: (context, state) => ReceivedQuotationsPage(
            solicitudId: state.pathParameters['id']!,
            solicitudService: servicio,
          ),
        ),
        GoRoute(
          path: '/solicitudes/:id/coordinacion-entrega',
          name: RouteNames.coordinacionEntrega,
          builder: (context, state) => CoordinacionEntregaPage(
            solicitudId: state.pathParameters['id']!,
            solicitudService: servicio,
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets(
    'pulsar "Seleccionar y Aceptar" abre el AlertDialog de confirmación '
    'con resumen y acciones Cancelar/Aceptar',
    (tester) async {
      servicio.respuestaCotizaciones = [cotizacionPendiente()];
      await pumpPagina(tester);

      expect(find.text('Seleccionar y Aceptar'), findsOneWidget);
      await tester.tap(find.text('Seleccionar y Aceptar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Aceptar esta cotización?'), findsOneWidget);
      // El resumen del diálogo (la tarjeta de la lista también muestra el
      // nombre del almacén y el precio, así que se acota al AlertDialog).
      final enDialogo = find.byType(AlertDialog);
      expect(
        find.descendant(
          of: enDialogo,
          matching: find.text('Repuestos Central'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: enDialogo,
          matching: find.textContaining('\$45.50'),
        ),
        findsOneWidget,
      );
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Aceptar'), findsOneWidget);
      expect(servicio.aceptarCalls, 0);
    },
  );

  testWidgets('"Cancelar" cierra el diálogo y NO llama al servicio', (
    tester,
  ) async {
    servicio.respuestaCotizaciones = [cotizacionPendiente()];
    await pumpPagina(tester);

    await tester.tap(find.text('Seleccionar y Aceptar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Aceptar esta cotización?'), findsNothing);
    expect(servicio.aceptarCalls, 0);
  });

  testWidgets(
    'confirmar con "Aceptar" llama al servicio y navega a la pantalla de '
    'coordinación (pushReplacement)',
    (tester) async {
      servicio.respuestaCotizaciones = [cotizacionPendiente()];
      await pumpPagina(tester);

      await tester.tap(find.text('Seleccionar y Aceptar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      expect(servicio.aceptarCalls, 1);
      // Pantalla de coordinación con el mensaje exacto y el contacto.
      expect(find.textContaining('¡Cotización seleccionada!'), findsOneWidget);
      expect(find.text('Repuestos Central'), findsOneWidget);
      expect(find.text('0991234567'), findsOneWidget);
      // "atrás" no regresa a la lista de cotizaciones: fue reemplazada.
      expect(find.text('Seleccionar y Aceptar'), findsNothing);
    },
  );

  testWidgets(
    'respuesta sin bloque "almacen" (backend antiguo): navega igual usando '
    'los datos de la tarjeta local',
    (tester) async {
      servicio.respuestaCotizaciones = [cotizacionPendiente()];
      // Backend antiguo: aceptar NO devuelve `almacen` ni `precioVenta`.
      servicio.respuestaAceptar = {'ordenId': 'ord-1'};
      await pumpPagina(tester);

      await tester.tap(find.text('Seleccionar y Aceptar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      expect(servicio.aceptarCalls, 1);
      // La pantalla de coordinación se abre con los datos de la tarjeta
      // (nombre del almacén) y NO se queda cargando.
      expect(find.textContaining('¡Cotización seleccionada!'), findsOneWidget);
      expect(find.text('Repuestos Central'), findsOneWidget);
      expect(find.text('Cargando datos de contacto...'), findsNothing);
    },
  );

  testWidgets('sin conexión: bloquea la acción con SnackBar y sin diálogo', (
    tester,
  ) async {
    servicio.respuestaCotizaciones = [cotizacionPendiente()];
    conectividad.resultados = [ConnectivityResult.none];
    await pumpPagina(tester);

    await tester.tap(find.text('Seleccionar y Aceptar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Aceptar esta cotización?'), findsNothing);
    expect(servicio.aceptarCalls, 0);
    expect(find.textContaining('No hay conexión a internet'), findsOneWidget);
  });

  testWidgets(
    'error 409: muestra el mensaje de conflicto y refresca (botón desaparece)',
    (tester) async {
      servicio.respuestaCotizaciones = [cotizacionPendiente()];
      servicio.falloAlAceptar = ApiException(
        'Esta solicitud ya tiene una cotización aceptada',
        statusCode: 409,
        technicalMessage: 'Esta solicitud ya tiene una cotización aceptada',
        type: ApiErrorType.http,
      );
      await pumpPagina(tester);

      await tester.tap(find.text('Seleccionar y Aceptar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();

      expect(servicio.aceptarCalls, 1);
      expect(
        find.text('Esta solicitud ya tiene una cotización aceptada'),
        findsOneWidget,
      );
    },
  );

  testWidgets('cliente SIN teléfono: se pide completarlo antes de aceptar y '
      '"Cancelar" bloquea la acción', (tester) async {
    // Perfil previo al requisito del teléfono: usuario sin teléfono.
    AuthService().currentUserForTesting = User(
      id: 'cliente-1',
      email: 'cliente@test.com',
      nombreCompleto: 'Cliente E2E',
      rol: 'cliente',
      telefono: null,
    );
    servicio.respuestaCotizaciones = [cotizacionPendiente()];
    await pumpPagina(tester);

    await tester.tap(find.text('Seleccionar y Aceptar'));
    await tester.pumpAndSettle();

    // Aparece el diálogo del teléfono, NO el de confirmación.
    expect(find.text('Completa tu teléfono'), findsOneWidget);
    expect(find.text('¿Aceptar esta cotización?'), findsNothing);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(servicio.aceptarCalls, 0);
    expect(
      find.textContaining('Completa tu teléfono en tu perfil'),
      findsOneWidget,
    );
  });

  testWidgets(
    'cliente SIN teléfono: "Guardar" con teléfono inválido no continúa',
    (tester) async {
      AuthService().currentUserForTesting = User(
        id: 'cliente-1',
        email: 'cliente@test.com',
        nombreCompleto: 'Cliente E2E',
        rol: 'cliente',
        telefono: null,
      );
      servicio.respuestaCotizaciones = [cotizacionPendiente()];
      await pumpPagina(tester);

      await tester.tap(find.text('Seleccionar y Aceptar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '123');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      // El error de validación se muestra en el propio diálogo.
      expect(
        find.text('Ingresa un teléfono válido (mín. 9 dígitos)'),
        findsOneWidget,
      );
      expect(servicio.aceptarCalls, 0);
      expect(find.text('¿Aceptar esta cotización?'), findsNothing);
    },
  );

  testWidgets(
    'cliente SIN teléfono: si la persistencia falla, la aceptación se '
    'bloquea (no se encola ni se asume un valor por defecto)',
    (tester) async {
      AuthService().currentUserForTesting = User(
        id: 'cliente-1',
        email: 'cliente@test.com',
        nombreCompleto: 'Cliente E2E',
        rol: 'cliente',
        telefono: null,
      );
      servicio.respuestaCotizaciones = [cotizacionPendiente()];
      await pumpPagina(tester);

      await tester.tap(find.text('Seleccionar y Aceptar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0991234567');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      // En tests la red está bloqueada: ProfileService no puede persistir y
      // la aceptación NO continúa.
      expect(servicio.aceptarCalls, 0);
      expect(
        find.textContaining('No se pudo guardar tu teléfono'),
        findsOneWidget,
      );
      expect(find.text('¿Aceptar esta cotización?'), findsNothing);
    },
  );
}
