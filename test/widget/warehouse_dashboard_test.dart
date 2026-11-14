import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repuestosya/pages/warehouse_dashboard.dart';
import 'package:repuestosya/theme/app_colors.dart';
import 'package:repuestosya/utils/api_error_handler.dart';
import 'package:repuestosya/widgets/ry_button.dart';
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
        'city': 'Quito',
        'tipo_establecimiento': 'matriz',
        'verification_status': 'approved',
        'estado_abierto': true,
      };
    solicitud = FakeSolicitudService();
  });

  Future<void> pumpDashboard(WidgetTester tester, {double width = 800}) async {
    tester.view.physicalSize = Size(width, 2000);
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
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator).first,
    );
    expect(
      (spinner.valueColor as AlwaysStoppedAnimation<Color>).value,
      AppColors.primaryContainer,
    );
    // El feed no debe renderizarse mientras valida.
    expect(find.text('Solicitudes Disponibles'), findsNothing);
  });

  testWidgets('el label Pendientes no se divide en pantallas angostas', (
    tester,
  ) async {
    await pumpDashboard(tester, width: 420);

    final pendientes = tester.widget<Text>(find.text('Pendientes'));
    expect(pendientes.maxLines, 1);
    expect(pendientes.softWrap, isFalse);
  });

  testWidgets('el subtítulo evita duplicar el aviso de verificación', (
    tester,
  ) async {
    almacen.respuestaMiAlmacen = {
      ...almacen.respuestaMiAlmacen!,
      'verification_status': 'pending',
    };
    await pumpDashboard(tester);

    expect(find.text('Repuestos Central'), findsOneWidget);
    expect(
      find.textContaining('Tu establecimiento está en verificación.'),
      findsOneWidget,
    );
    expect(find.text('En Verificación'), findsNothing);
    expect(
      find.textContaining('Tu cuenta está en proceso de revisión.'),
      findsNothing,
    );
  });

  testWidgets('pendiente de verificación: estado vacío en vez de spinner', (
    tester,
  ) async {
    almacen.respuestaMiAlmacen = {
      ...almacen.respuestaMiAlmacen!,
      'verification_status': 'pending',
    };
    await pumpDashboard(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.byKey(const ValueKey('warehouse-pending-empty-state')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.assignment_late_outlined), findsOneWidget);
    expect(
      find.text(
        'Aún no hay solicitudes disponibles. Estaremos notificándote cuando '
        'tu cuenta sea aprobada.',
      ),
      findsOneWidget,
    );
    expect(solicitud.solicitudesActivasCalls, 0);
  });

  testWidgets('"Ver todas" sin verificar avisa con un SnackBar', (
    tester,
  ) async {
    almacen.respuestaMiAlmacen = {
      ...almacen.respuestaMiAlmacen!,
      'verification_status': 'pending',
    };
    await pumpDashboard(tester);

    await tester.tap(find.text('Ver todas'));
    await tester.pump();

    expect(
      find.text(
        'Debes esperar la verificación de tu establecimiento para ver '
        'solicitudes.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('la primera pestaña se llama "Inicio"', (tester) async {
    await pumpDashboard(tester);

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('las tres métricas comparten el mismo tamaño de fuente a 360px', (
    tester,
  ) async {
    await pumpDashboard(tester, width: 360);

    for (final label in ['Ventas', 'Pendientes', 'Vistas']) {
      expect(
        tester.widget<Text>(find.text(label)).style?.fontSize,
        12,
        reason: label,
      );
    }
  });

  testWidgets(
    'con almacén en verificación, Ventas y Pendientes no son clickeables',
    (tester) async {
      almacen.respuestaMiAlmacen = {
        ...almacen.respuestaMiAlmacen!,
        'verification_status': 'pending',
      };
      await pumpDashboard(tester);

      InkWell tarjeta(String label) => tester.widget<InkWell>(
        find
            .ancestor(of: find.text(label), matching: find.byType(InkWell))
            .first,
      );

      expect(tarjeta('Ventas').onTap, isNull);
      expect(tarjeta('Pendientes').onTap, isNull);
    },
  );

  testWidgets('con almacén aprobado, Ventas y Pendientes sí son clickeables', (
    tester,
  ) async {
    await pumpDashboard(tester);

    InkWell tarjeta(String label) => tester.widget<InkWell>(
      find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
    );

    expect(tarjeta('Ventas').onTap, isNotNull);
    expect(tarjeta('Pendientes').onTap, isNotNull);
  });

  testWidgets('las métricas centran ícono, número y etiqueta, en ese orden', (
    tester,
  ) async {
    await pumpDashboard(tester, width: 360);

    final tarjeta = find
        .ancestor(of: find.text('Ventas'), matching: find.byType(InkWell))
        .first;
    final icono = find.descendant(
      of: tarjeta,
      matching: find.byIcon(Icons.monetization_on_outlined),
    );
    final valor = find.descendant(of: tarjeta, matching: find.text('0'));
    final etiqueta = find.text('Ventas');

    final centro = tester.getCenter(tarjeta).dx;
    expect(tester.getCenter(icono).dx, closeTo(centro, 1));
    expect(tester.getCenter(valor).dx, closeTo(centro, 1));
    expect(tester.getCenter(etiqueta).dx, closeTo(centro, 1));
    expect(tester.getCenter(icono).dy, lessThan(tester.getCenter(valor).dy));
    expect(tester.getCenter(valor).dy, lessThan(tester.getCenter(etiqueta).dy));
  });

  testWidgets(
    'las tres métricas comparten fondo y borde neutros, número blanco',
    (tester) async {
      await pumpDashboard(tester, width: 360);

      BoxDecoration decoracion(String label) {
        final tarjeta = find.ancestor(
          of: find.text(label),
          matching: find.byType(InkWell),
        );
        final contenedor = find.ancestor(
          of: tarjeta.first,
          matching: find.byType(Container),
        );
        return tester.widget<Container>(contenedor.first).decoration!
            as BoxDecoration;
      }

      for (final label in ['Ventas', 'Pendientes', 'Vistas']) {
        final deco = decoracion(label);
        expect(deco.gradient, isNull, reason: label);
        expect(deco.color, AppColors.surfaceContainerLow, reason: label);
        expect(
          (deco.border! as Border).top.color,
          AppColors.outlineVariant.withValues(alpha: 0.65),
          reason: label,
        );
        expect(deco.borderRadius, BorderRadius.circular(16), reason: label);
      }

      final tarjeta = find
          .ancestor(of: find.text('Ventas'), matching: find.byType(InkWell))
          .first;
      final numero = tester.widget<Text>(
        find.descendant(of: tarjeta, matching: find.text('0')),
      );
      expect(numero.style?.color, Colors.white);
      expect(numero.style?.fontWeight, FontWeight.w700);
      expect(numero.style?.fontSize, 22);
    },
  );

  testWidgets(
    'las métricas se adaptan en altura con texto grande sin overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: WarehouseDashboard(
            almacenService: almacen,
            solicitudService: solicitud,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);

      double alto(String label) => tester
          .getSize(
            find
                .ancestor(of: find.text(label), matching: find.byType(InkWell))
                .first,
          )
          .height;
      expect(alto('Pendientes'), closeTo(alto('Ventas'), 0.01));
      expect(alto('Vistas'), closeTo(alto('Ventas'), 0.01));
    },
  );

  testWidgets('el aviso de verificación es un SnackBar oscuro sin apilarse', (
    tester,
  ) async {
    almacen.respuestaMiAlmacen = {
      ...almacen.respuestaMiAlmacen!,
      'verification_status': 'pending',
    };
    await pumpDashboard(tester);

    await tester.tap(find.text('Ver todas'));
    await tester.pump();
    await tester.tap(find.text('Ver todas'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SnackBar), findsOneWidget);
    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snack.behavior, SnackBarBehavior.floating);
    expect(snack.backgroundColor, const Color(0xFF18181B));
    final borde = (snack.shape! as RoundedRectangleBorder).side.color;
    expect(borde, const Color(0xFFF59E0B).withValues(alpha: 0.35));
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byIcon(Icons.warning_amber_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('las pestañas inferiores usan "Mi Local" y la misma tipografía', (
    tester,
  ) async {
    await pumpDashboard(tester, width: 360);

    expect(find.text('Mi Local'), findsOneWidget);
    expect(find.text('Mi Establecimiento'), findsNothing);
    for (final label in ['Inicio', 'Cotizaciones', 'Mi Local']) {
      final texto = tester.widget<Text>(find.text(label));
      expect(texto.style?.fontSize, 12.0, reason: label);
      expect(texto.maxLines, 1, reason: label);
      expect(texto.overflow, TextOverflow.ellipsis, reason: label);
    }
  });

  testWidgets('el banner de verificación indica el tiempo estimado', (
    tester,
  ) async {
    almacen.respuestaMiAlmacen = {
      ...almacen.respuestaMiAlmacen!,
      'verification_status': 'pending',
    };
    await pumpDashboard(tester);

    expect(find.text('En revisión • Máx. 48h'), findsOneWidget);
  });

  testWidgets('el Inicio permite pull-to-refresh con el color de marca', (
    tester,
  ) async {
    await pumpDashboard(tester);

    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    expect(refresh.color, AppColors.primaryContainer);
    final scroll = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    expect(scroll.physics, isA<AlwaysScrollableScrollPhysics>());
  });

  testWidgets('confirma el cierre solo después de guardar el estado', (
    tester,
  ) async {
    final confirmacionBackend = Completer<void>();
    almacen.bloquearActualizarAlmacen = confirmacionBackend.future;
    await pumpDashboard(tester);

    await tester.tap(find.text('Abierto'));
    await tester.pump();

    expect(almacen.actualizarAlmacenCalls, 1);
    expect(find.text('Abierto'), findsOneWidget);
    expect(find.text('Establecimiento cerrado temporalmente'), findsNothing);

    confirmacionBackend.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Cerrado'), findsOneWidget);
    expect(find.text('Establecimiento cerrado temporalmente'), findsOneWidget);
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
    expect(find.textContaining(' km'), findsNothing);
    expect(find.byType(RyPartCard), findsNWidgets(2));
    expect(find.text('Urgente'), findsOneWidget);
    expect(find.text('Sin cotizaciones aún'), findsNWidgets(2));
    expect(find.text('COTIZAR'), findsNWidgets(2));
    expect(solicitud.solicitudesActivasCalls, 1);
  });

  testWidgets('formatea a un decimal la distancia georreferenciada recibida', (
    tester,
  ) async {
    solicitud.respuestaActivas = [
      {
        'id': 'distance-1',
        'pieza_nombre': 'Bomba de agua',
        'created_at': '2026-09-20T10:00:00.000Z',
        'distancia_km': 12.36,
      },
    ];
    await pumpDashboard(tester);

    expect(find.text('12.4 km'), findsOneWidget);
  });

  testWidgets(
    'estado CON DATOS: el Home muestra solo 3 solicitudes de vista previa '
    'y "Ver todas", sin tocar la métrica del Bento',
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

      // Vista previa: solo 3 tarjetas; las demás no se construyen en el Home.
      expect(find.byType(RyPartCard), findsNWidgets(3));
      expect(find.text('Pieza 4'), findsNothing);
      expect(find.text('Cargar más'), findsNothing);
      expect(find.text('Ver todas'), findsOneWidget);

      // La métrica "Pendientes" del Bento usa la lista COMPLETA (6), no la
      // vista previa (3).
      expect(find.text('6'), findsOneWidget);
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

  testWidgets(
    'tarjeta GANADA muestra datos de entrega del cliente y la no ganada no',
    (tester) async {
      solicitud.respuestaMisCotizaciones = [
        {
          'id': 'cot-1',
          'precio_venta': 45.5,
          'estado': 'aceptada',
          'created_at': '2026-10-01T10:00:00.000Z',
          'tiempo_entrega_estimado': 'Mañana',
          'solicitudes_repuesto': {
            'pieza_nombre': 'Filtro de aceite',
            'estado': 'aceptada',
            'profiles': {
              'nombre_completo': 'Juan Pérez',
              'telefono': '0991234567',
            },
            'direcciones_entrega': {
              'alias': 'Casa',
              'calle_principal': 'Av. Amazonas',
              'calle_secundaria': 'Calle 10',
              'referencia': 'Frente al parque',
            },
          },
          'ordenes_compra': {'id': 'ord-1', 'estado': 'pendiente'},
        },
        {
          'id': 'cot-2',
          'precio_venta': 60.0,
          'estado': 'rechazada',
          'created_at': '2026-10-01T11:00:00.000Z',
          'tiempo_entrega_estimado': 'Mañana',
          // Sin teléfono ni dirección: el backend no los envía.
          'solicitudes_repuesto': {
            'pieza_nombre': 'Bujías NGK',
            'estado': 'rechazada',
            'profiles': {'nombre_completo': 'María Gómez'},
          },
        },
      ];
      await pumpDashboard(tester);

      // Cambiar a la pestaña de Cotizaciones Enviadas.
      await tester.tap(find.text('Cotizaciones'));
      await tester.pumpAndSettle();

      // Solo la GANADA muestra la sección de datos de entrega del cliente.
      expect(find.text('Datos de entrega del cliente'), findsOneWidget);
      // El nombre va una sola vez, en el encabezado de la tarjeta.
      expect(find.text('Cliente: Juan Pérez'), findsOneWidget);
      expect(find.text('Juan Pérez'), findsNothing);
      expect(find.text('0991234567'), findsOneWidget);
      expect(find.textContaining('Av. Amazonas'), findsOneWidget);
      expect(find.textContaining('Frente al parque'), findsOneWidget);
      // Botones de contacto habilitados (teléfono válido).
      expect(find.text('Llamar'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);

      // La no ganada muestra su badge y NUNCA los datos del cliente.
      expect(find.text('NO SELECCIONADA'), findsOneWidget);
      expect(find.text('María Gómez'), findsNothing);
      expect(find.text('Sin teléfono registrado'), findsNothing);
    },
  );

  testWidgets(
    'cotizaciones: el precio muestra un solo símbolo de dólar y cada pestaña vacía '
    'muestra su mensaje en lugar de una lista en blanco',
    (tester) async {
      solicitud.respuestaMisCotizaciones = [
        {
          'id': 'c-1',
          'precio_venta': '23.00',
          'estado': 'pendiente',
          'created_at': '2026-10-05T10:00:00.000Z',
          'solicitudes_repuesto': {'pieza_nombre': 'Filtro de aceite'},
        },
      ];
      await pumpDashboard(tester);

      await tester.tap(find.text('Cotizaciones'));
      await tester.pumpAndSettle();

      // Pestaña Todas: la tarjeta con un único símbolo de dólar.
      expect(find.text('\$23.00'), findsOneWidget);
      expect(find.text('\$ \$23.00'), findsNothing);
      expect(find.text('Filtro de aceite'), findsOneWidget);

      // Pestaña Pendientes: la cotización pendiente sigue visible.
      await tester.tap(find.text('Pendientes'));
      await tester.pumpAndSettle();
      expect(find.text('Filtro de aceite'), findsOneWidget);

      // Pestaña Ganadas: sin cotizaciones ganadas, mensaje de estado vacío.
      await tester.tap(find.text('Ganadas'));
      await tester.pumpAndSettle();
      expect(find.text('Filtro de aceite'), findsNothing);
      expect(find.text('Aún no tienes cotizaciones ganadas.'), findsOneWidget);

      // Pestaña No seleccionadas: mensaje propio de rechazadas.
      await tester.tap(find.text('No seleccionadas'));
      await tester.pumpAndSettle();
      expect(find.text('Filtro de aceite'), findsNothing);
      expect(find.text('No tienes cotizaciones rechazadas.'), findsOneWidget);
    },
  );

  testWidgets(
    'estructura REAL de my-quotations (caso "Bomba de agua"): la oferta '
    'ganada conserva teléfono y dirección del cliente',
    (tester) async {
      // Shape exacta que devuelve GET /quotations/my-quotations con el
      // backend actualizado (solicitudes_repuesto embebida con
      // repuesto_nombre_snapshot, direccion_entrega_id, direcciones_entrega
      // y profiles.telefono).
      solicitud.respuestaMisCotizaciones = [
        {
          'id': '68b7684a-2380-43a3-8a75-996c5892c095',
          'precio_venta': '45.50',
          'estado': 'aceptada',
          'created_at': '2026-10-05T10:00:00.000Z',
          'tiempo_entrega_estimado': 'Mañana',
          'solicitudes_repuesto': {
            'pieza_nombre': 'Bomba de agua',
            'repuesto_nombre_snapshot': 'Bomba de agua',
            'estado': 'aceptada',
            'direccion_entrega_id': '4944c4da-a3d7-412f-a42a-464eeadd1735',
            'direcciones_entrega': {
              'alias': 'Taller pepito',
              'calle_principal': 'De los Colibries',
              'calle_secundaria': null,
              'referencia': 'Marianitas',
            },
            'profiles': {
              'nombre_completo': 'TestCliente',
              'telefono': '0981234512',
            },
          },
          'ordenes_compra': {
            'id': 'e158e893-8123-4664-9fbd-1da50481b235',
            'estado': 'pendiente',
          },
        },
      ];
      await pumpDashboard(tester);

      await tester.tap(find.text('Cotizaciones'));
      await tester.pumpAndSettle();

      expect(find.text('Datos de entrega del cliente'), findsOneWidget);
      // El nombre va una sola vez, en el encabezado de la tarjeta.
      expect(find.text('Cliente: TestCliente'), findsOneWidget);
      expect(find.text('TestCliente'), findsNothing);
      expect(find.text('0981234512'), findsOneWidget);
      // Dirección completa: alias + calles + referencia.
      expect(find.textContaining('Taller pepito'), findsOneWidget);
      expect(find.textContaining('De los Colibries'), findsOneWidget);
      expect(find.textContaining('Marianitas'), findsOneWidget);
      expect(find.text('Sin teléfono registrado'), findsNothing);
      expect(find.text('Sin dirección registrada'), findsNothing);
    },
  );

  testWidgets(
    'tarjeta GANADA sin teléfono deshabilita Llamar/WhatsApp y lo indica',
    (tester) async {
      solicitud.respuestaMisCotizaciones = [
        {
          'id': 'cot-1',
          'precio_venta': 45.5,
          'estado': 'aceptada',
          'created_at': '2026-10-01T10:00:00.000Z',
          'tiempo_entrega_estimado': 'Mañana',
          'solicitudes_repuesto': {
            'pieza_nombre': 'Filtro de aceite',
            'estado': 'aceptada',
            'profiles': {'nombre_completo': 'Juan Pérez'},
          },
          'ordenes_compra': {'id': 'ord-1', 'estado': 'pendiente'},
        },
      ];
      await pumpDashboard(tester);

      await tester.tap(find.text('Cotizaciones'));
      await tester.pumpAndSettle();

      expect(find.text('Datos de entrega del cliente'), findsOneWidget);
      expect(find.text('Sin teléfono registrado'), findsOneWidget);
      final llamar = tester.widget<RyButton>(
        find.widgetWithText(RyButton, 'Llamar'),
      );
      final whatsapp = tester.widget<RyButton>(
        find.widgetWithText(RyButton, 'WhatsApp'),
      );
      expect(llamar.isDisabled, isTrue);
      expect(whatsapp.isDisabled, isTrue);
    },
  );
}
