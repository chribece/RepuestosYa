import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repuestosya/models/coordinacion_entrega.dart';
import 'package:repuestosya/pages/coordinacion_entrega_page.dart';
import 'package:repuestosya/services/coordinacion_entrega_cache.dart';
import 'package:repuestosya/services/solicitud_service.dart';
import 'package:repuestosya/widgets/ry_button.dart';

/// Doble del servicio de solicitudes para la página de coordinación.
class _FakeSolicitudService extends SolicitudService {
  List<Map<String, dynamic>> respuestaCotizaciones = [];
  int llamadasRecibidas = 0;

  @override
  Future<List<Map<String, dynamic>>> obtenerCotizacionesRecibidas(
    String solicitudId,
  ) async {
    llamadasRecibidas++;
    return respuestaCotizaciones;
  }
}

DatosCoordinacionEntrega datosEjemplo({
  String? telefono = '0991234567',
  String? email = 'contacto@repuestoscentral.com',
}) {
  return DatosCoordinacionEntrega(
    solicitudId: 's1',
    cotizacionId: 'cot-1',
    almacenNombre: 'Repuestos Central',
    telefono: telefono,
    email: email,
    repuestoNombre: 'Filtro de aceite',
    precioVenta: 45.5,
  );
}

void main() {
  late _FakeSolicitudService servicio;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    servicio = _FakeSolicitudService();
  });

  Future<void> pumpPagina(
    WidgetTester tester, {
    DatosCoordinacionEntrega? datosIniciales,
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: CoordinacionEntregaPage(
          solicitudId: 's1',
          datosIniciales: datosIniciales,
          solicitudService: servicio,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('con datosIniciales muestra el contenido sin round-trip', (
    tester,
  ) async {
    await pumpPagina(tester, datosIniciales: datosEjemplo());

    expect(find.text('Cargando datos de contacto...'), findsNothing);
    expect(find.textContaining('¡Cotización seleccionada!'), findsOneWidget);
    expect(find.text('Repuestos Central'), findsOneWidget);
    expect(find.text('0991234567'), findsOneWidget);
    expect(servicio.llamadasRecibidas, 0);
  });

  testWidgets(
    'REGRESIÓN: sin datosIniciales ni caché, carga desde el backend y '
    'MUESTRA el contenido (no se queda en "Cargando datos de contacto...")',
    (tester) async {
      servicio.respuestaCotizaciones = [
        {
          'id': 'cot-1',
          'estado': 'aceptada',
          'precio_venta': '45.50', // numeric de PostgREST como string
          'almacenes': {
            'nombre_comercial': 'Repuestos Central',
            'telefono': '0991234567',
            'email': 'contacto@repuestoscentral.com',
          },
          'solicitudes_repuesto': {
            'pieza_nombre': 'Filtro de aceite',
            'repuesto_nombre_snapshot': 'Filtro de aceite Mann',
          },
        },
      ];
      await pumpPagina(tester);

      expect(servicio.llamadasRecibidas, 1);
      expect(find.text('Cargando datos de contacto...'), findsNothing);
      expect(find.textContaining('¡Cotización seleccionada!'), findsOneWidget);
      expect(find.text('Repuestos Central'), findsOneWidget);
      expect(find.text('0991234567'), findsOneWidget);
    },
  );

  testWidgets('reabrir desde caché (sin backend) muestra los datos', (
    tester,
  ) async {
    final cache = CoordinacionEntregaCache(
      await SharedPreferences.getInstance(),
    );
    await cache.guardar(datosEjemplo());

    await tester.pumpWidget(
      MaterialApp(
        home: CoordinacionEntregaPage(
          solicitudId: 's1',
          solicitudService: servicio,
          cache: cache,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Cargando datos de contacto...'), findsNothing);
    expect(find.text('Repuestos Central'), findsOneWidget);
    expect(servicio.llamadasRecibidas, 0);
  });

  testWidgets('sin teléfono: deshabilita Llamar/WhatsApp y lo indica', (
    tester,
  ) async {
    await pumpPagina(tester, datosIniciales: datosEjemplo(telefono: null));

    expect(find.text('El almacén no registró teléfono'), findsOneWidget);
    final llamar = tester.widget<RyButton>(
      find.widgetWithText(RyButton, 'Llamar por Teléfono'),
    );
    final whatsapp = tester.widget<RyButton>(
      find.widgetWithText(RyButton, 'Enviar WhatsApp'),
    );
    expect(llamar.isDisabled, isTrue);
    expect(whatsapp.isDisabled, isTrue);
    // El correo sigue disponible.
    expect(find.text('contacto@repuestoscentral.com'), findsOneWidget);
  });

  testWidgets(
    'REGRESIÓN caché vieja sin contacto: se refresca desde el backend y '
    'aparece teléfono/correo del almacén',
    (tester) async {
      // Caché guardada por una aceptación con backend ANTIGUO (respuesta sin
      // `almacen.telefono/email`): la reapertura NO debe mostrar "El almacén
      // no registró teléfono" para siempre.
      final cache = CoordinacionEntregaCache(
        await SharedPreferences.getInstance(),
      );
      await cache.guardar(
        DatosCoordinacionEntrega(
          solicitudId: 's1',
          cotizacionId: 'cot-1',
          almacenNombre: 'FQ REPUESTOS GYE',
          telefono: null,
          email: null,
          repuestoNombre: 'Bomba de agua',
          precioVenta: 45.5,
        ),
      );

      // El backend NUEVO ya devuelve el contacto en la cotización aceptada
      // (estructura real de GET /quotations/request/:id).
      servicio.respuestaCotizaciones = [
        {
          'id': 'cot-1',
          'estado': 'aceptada',
          'precio_venta': '45.50',
          'almacenes': {
            'nombre_comercial': 'FQ REPUESTOS GYE',
            'telefono': '0987777777',
            'email': 'testalmacen@gmail.com',
          },
          'solicitudes_repuesto': {'pieza_nombre': 'Bomba de agua'},
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: CoordinacionEntregaPage(
            solicitudId: 's1',
            solicitudService: servicio,
            cache: cache,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Muestra lo cacheado sin quedarse cargando...
      expect(find.text('Cargando datos de contacto...'), findsNothing);
      expect(find.text('FQ REPUESTOS GYE'), findsOneWidget);
      // ...y tras el refresh en segundo plano aparece el contacto real.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('0987777777'), findsOneWidget);
      expect(find.text('testalmacen@gmail.com'), findsOneWidget);
      // La caché quedó actualizada para la próxima reapertura.
      final actualizado = cache.leer('s1');
      expect(actualizado?.telefono, '0987777777');
      expect(actualizado?.email, 'testalmacen@gmail.com');
    },
  );

  testWidgets('error al cargar sin datos → estado de error con reintento', (
    tester,
  ) async {
    servicio.respuestaCotizaciones = [];
    await pumpPagina(tester);

    expect(find.text('Cargando datos de contacto...'), findsNothing);
    expect(
      find.text('No se encontró una cotización aceptada para esta solicitud.'),
      findsOneWidget,
    );
  });
}
