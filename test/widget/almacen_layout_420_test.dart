import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repuestosya/database/app_database.dart';
import 'package:repuestosya/models/orden_compra.dart';
import 'package:repuestosya/pages/create_quotation_page.dart';
import 'package:repuestosya/pages/orden_compra_page.dart';
import 'package:repuestosya/pages/warehouse_dashboard.dart';
import 'package:repuestosya/providers/orden_compra_provider.dart';
import 'package:repuestosya/router/route_names.dart';
import 'package:repuestosya/services/almacen_repository.dart';
import 'package:repuestosya/services/auth_service.dart';
import 'package:repuestosya/services/orden_compra_repository.dart';
import 'package:repuestosya/theme/app_text_styles.dart';
import 'package:repuestosya/theme/app_theme.dart';

import '../helpers/fake_connectivity.dart';
import '../helpers/fake_services.dart';

/// Geometría de las pantallas del ALMACÉN en móvil angosto real (420 px
/// lógicos, Parte 3 de los fixes de layout): captura cualquier
/// RenderFlex overflow / contenido recortado que no se nota hasta verlo en
/// el dispositivo.
void main() {
  late FakeConnectivityPlatform conectividad;

  setUp(() {
    conectividad = FakeConnectivityPlatform();
    ConnectivityPlatform.instance = conectividad;
    AuthService().currentUserForTesting = null;
  });

  Future<List<String>> capturarErrores(
    WidgetTester tester,
    Future<void> Function() accion,
  ) async {
    final errores = <FlutterErrorDetails>[];
    final original = FlutterError.onError;
    FlutterError.onError = (details) => errores.add(details);
    try {
      await accion();
    } finally {
      FlutterError.onError = original;
    }
    return errores.map((e) => e.toString()).toList();
  }

  FakeAlmacenService almacenAprobado() =>
      FakeAlmacenService()
        ..respuestaMiAlmacen = {
          'id': 'a-1',
          'nombre_comercial': 'Repuestos Central',
          'verification_status': 'approved',
          'estado_abierto': true,
        };

  FakeSolicitudService solicitudConDatos() => FakeSolicitudService()
    ..respuestaActivas = [
      for (var i = 1; i <= 3; i++)
        {
          'id': 's$i',
          'pieza_nombre': 'Amortiguador delantero derecho marca original',
          'es_urgente': i == 1,
          'created_at': '2026-09-2${i}T10:00:00.000Z',
          'profiles': {'nombre_completo': 'Cliente de prueba muy largo'},
          'vehiculos_cliente': {
            'modelos_vehiculo': {
              'nombre': 'Aveo Family 1.5',
              'marcas_vehiculo': {'nombre': 'Chevrolet'},
            },
          },
        },
    ]
    ..respuestaMisCotizaciones = [
      {
        'id': 'cot-1',
        'precio_venta': 125.50,
        'estado': 'aceptada',
        'created_at': '2026-09-20T10:00:00.000Z',
        'tiempo_entrega_estimado': '24-48 horas',
        'solicitudes_repuesto': {
          'pieza_nombre': 'Amortiguador delantero derecho marca original',
          'profiles': {'nombre_completo': 'Cliente de prueba muy largo'},
        },
        'ordenes_compra': {'id': 'ord-1', 'estado': 'pendiente'},
      },
      {
        'id': 'cot-2',
        'precio_venta': 89.00,
        'estado': 'pendiente',
        'created_at': '2026-09-19T10:00:00.000Z',
        'tiempo_entrega_estimado': 'Inmediata',
        'solicitudes_repuesto': {
          'pieza_nombre': 'Filtro de aceite',
          'profiles': {'nombre_completo': 'Otro cliente'},
        },
      },
    ];

  Future<void> montarDashboard(
    WidgetTester tester, {
    required FakeAlmacenService almacen,
    required FakeSolicitudService solicitud,
    Size size = const Size(420, 900),
  }) async {
    SharedPreferences.setMockInitialValues({'rationale_notificaciones': true});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => WarehouseDashboard(
            almacenService: almacen,
            solicitudService: solicitud,
          ),
        ),
        GoRoute(
          path: '/dashboard/orden/:id',
          name: RouteNames.ordenDetalleAlmacen,
          builder: (_, _) => const Scaffold(body: Center(child: Text('Orden'))),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> irACotizaciones(WidgetTester tester) async {
    await tester.tap(find.text('Cotizaciones'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('dashboard almacén a 420px: feed y cotizaciones sin overflow', (
    tester,
  ) async {
    final errores = await capturarErrores(tester, () async {
      await montarDashboard(
        tester,
        almacen: almacenAprobado(),
        solicitud: solicitudConDatos(),
      );
      await irACotizaciones(tester);
      // Scrollear la sección de cotizaciones para construir las tarjetas.
      // El scroll vertical es el que contiene el encabezado de la sección
      // (hay además un scroll horizontal con los chips de filtro).
      final scrollSeccion = find.ancestor(
        of: find.text('Cotizaciones Enviadas'),
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(scrollSeccion.first, const Offset(0, -400));
      await tester.pump();
    });

    expect(
      errores,
      isEmpty,
      reason: 'Overflows a 420px:\n${errores.join('\n')}',
    );
  });

  testWidgets('cotizaciones enviadas: pull-to-refresh dispara el fetch real', (
    tester,
  ) async {
    final solicitud = FakeSolicitudService()
      ..respuestaMisCotizaciones = [
        {
          'id': 'cot-1',
          'precio_venta': 125.50,
          'estado': 'pendiente',
          'created_at': '2026-09-20T10:00:00.000Z',
          'tiempo_entrega_estimado': '24-48 horas',
          'solicitudes_repuesto': {
            'pieza_nombre': 'Filtro de aceite',
            'profiles': {'nombre_completo': 'Juan Pérez'},
          },
        },
      ];

    await montarDashboard(
      tester,
      almacen: almacenAprobado(),
      solicitud: solicitud,
    );
    await irACotizaciones(tester);

    final llamadasIniciales = solicitud.misCotizacionesCalls;
    expect(find.text('Filtro de aceite'), findsOneWidget);

    // Gesto de pull-to-refresh: arrastrar hacia abajo desde el top del scroll
    // vertical de la sección.
    final scrollSeccion = find.ancestor(
      of: find.text('Cotizaciones Enviadas'),
      matching: find.byType(SingleChildScrollView),
    );
    await tester.fling(scrollSeccion.first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(
      solicitud.misCotizacionesCalls,
      greaterThan(llamadasIniciales),
      reason: 'El pull-to-refresh debe volver a pedir las cotizaciones',
    );
    // La lista se repinta con los datos del servidor.
    expect(find.text('Filtro de aceite'), findsOneWidget);
  });

  testWidgets(
    'orden_compra a 420px: títulos dentro de la jerarquía de tokens y sin '
    'overflow (Parte 5)',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final provider = OrdenCompraProvider(repository: _FakeOrdenRepository());

      final errores = await capturarErrores(tester, () async {
        await tester.pumpWidget(
          ChangeNotifierProvider<OrdenCompraProvider>.value(
            value: provider,
            child: const MaterialApp(home: OrdenCompraPage(ordenId: 'ord-1')),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      expect(
        errores,
        isEmpty,
        reason: 'Overflows orden_compra 420px:\n${errores.join('\n')}',
      );

      // Ningún texto debe usar tokens por encima de textStyleTitle (20px):
      // la queja era "texto sobredimensionado". Verificamos los fontSize
      // de todos los Text de la pantalla.
      final fontSizeMax = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.style?.fontSize ?? 14)
          .fold<double>(0, (max, f) => f > max ? f : max);
      expect(
        fontSizeMax,
        lessThanOrEqualTo(AppTextStyles.textStyleTitle.fontSize!),
        reason: 'Hay un texto con fontSize $fontSizeMax (> 20px)',
      );
    },
  );

  testWidgets(
    'create_quotation a 420px: sin overflow y el mensaje de comisión del '
    'precio se ve completo (wrap, no truncado)',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final errores = await capturarErrores(tester, () async {
        await tester.pumpWidget(
          Provider<AlmacenRepository>.value(
            value: AlmacenRepository(db),
            child: MaterialApp(
              theme: darkTheme,
              home: const CreateQuotationPage(
                solicitud: {
                  'id': 's-1',
                  'pieza_nombre':
                      'Amortiguador delantero derecho marca '
                      'original de alta calidad',
                  'descripcion': 'Falla al frenar, necesita revisión',
                  'es_urgente': false,
                  'created_at': '2026-09-20T10:00:00.000Z',
                  'profiles': {'nombre_completo': 'Cliente de prueba'},
                  'vehiculos_cliente': {
                    'modelos_vehiculo': {
                      'nombre': 'Aveo Family 1.5',
                      'marcas_vehiculo': {'nombre': 'Chevrolet'},
                    },
                  },
                  'latitud_entrega': -0.1807,
                  'longitud_entrega': -78.4678,
                  'direcciones_entrega': {
                    'calle_principal': 'Av. Amazonas y Naciones Unidas',
                  },
                },
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      expect(
        errores,
        isEmpty,
        reason: 'Overflows create_quotation 420px:\n${errores.join('\n')}',
      );

      // El mensaje de comisión del precio debe existir completo y con wrap.
      const comision = 'SE APLICARÁ UNA COMISIÓN DEL 5% POR TRANSACCIÓN';
      final comisionFinder = find.text(comision);
      expect(
        comisionFinder,
        findsOneWidget,
        reason: 'El mensaje de comisión completo debe estar en el árbol',
      );
      final alto = tester.getSize(comisionFinder).height;
      expect(
        alto,
        greaterThan(30),
        reason: 'El mensaje debe hacer wrap (alto $alto px = 1 línea truncada)',
      );
    },
  );

  testWidgets('orden_compra a 800px: sin regresiones de layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = OrdenCompraProvider(repository: _FakeOrdenRepository());

    final errores = await capturarErrores(tester, () async {
      await tester.pumpWidget(
        ChangeNotifierProvider<OrdenCompraProvider>.value(
          value: provider,
          child: const MaterialApp(home: OrdenCompraPage(ordenId: 'ord-1')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    expect(
      errores,
      isEmpty,
      reason: 'Overflows orden_compra 800px:\n${errores.join('\n')}',
    );
  });
}

/// Repositorio falso de orden de compra (sin red) para la geometría.
class _FakeOrdenRepository implements OrdenCompraRepository {
  @override
  Future<OrdenCompra> getOrdenDetalle(String ordenId) async {
    return OrdenCompra.fromJson({
      'id': 'ord-1',
      'cliente_id': 'c-1',
      'almacen_id': 'a-1',
      'solicitud_id': 's-1',
      'cotizacion_id': 'cot-1',
      'estado': 'pendiente',
      'created_at': '2026-09-20T10:00:00.000Z',
      'updated_at': '2026-09-20T10:00:00.000Z',
      'almacenes': {
        'nombre_comercial': 'Repuestos Central de la Sierra',
        'direccion_texto':
            'Av. Amazonas y Naciones Unidas, Quito — local comercial 45',
      },
      'detalles': {
        'precio_venta': 125.50,
        'condicion_repuesto': 'Nuevo (En caja original)',
        'tiempo_entrega_estimado': '24-48 horas',
        'fecha_aceptacion': '2026-09-21T10:00:00.000Z',
        'notas_adicionales':
            'Incluye instalación en el local del cliente y garantía de 6 meses',
        'foto_evidencia_url': '',
      },
    });
  }

  @override
  Future<Map<String, dynamic>> actualizarEstadoOrden(
    String ordenId,
    String nuevoEstado,
  ) async {
    return {'id': ordenId, 'estado': nuevoEstado};
  }
}
