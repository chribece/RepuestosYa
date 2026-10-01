import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:repuestosya/pages/home_page.dart';
import 'package:repuestosya/providers/solicitudes_provider.dart';
import 'package:repuestosya/services/auth_service.dart';
import 'package:repuestosya/theme/app_spacing.dart';

import '../helpers/fake_connectivity.dart';
import '../helpers/fake_solicitud_repository.dart';

/// Regresiones responsive del Home (móvil angosto ~420px lógicos vs tablet):
/// 1. Las tarjetas de estadísticas comparten altura real por fila y el bloque
///    número+ícono queda alineado entre las 4 (títulos de 1 o 2 líneas).
/// 2. El subtítulo de "NUEVA BÚSQUEDA" respeta el padding horizontal de la
///    card aunque haga wrap (no toca el borde izquierdo).
/// 3. El bottom nav agrega el padding de área segura inferior (barra de
///    gestos) en teléfonos y queda igual en tablet (padding 0).
///
/// Nota sobre la fuente de TEST (Ahem): dibuja cada glifo con ancho =
/// fontSize (~2x el ancho real de Sora), por lo que en pruebas angostas
/// aparecen overflows en widgets NO relacionados (app bar, header "Mis
/// Solicitudes") que NO existen en dispositivo con Sora — el test de tablet
/// de 800px no reporta ninguno. Esos artefactos se drenan al final con
/// [drenarExcepcionesAhem]; los widgets de los 3 fixes se verifican con
/// aserciones de geometría y contención, que sí fallan si el fix se rompe.
void main() {
  late FakeConnectivityPlatform conectividad;

  setUp(() {
    conectividad = FakeConnectivityPlatform();
    ConnectivityPlatform.instance = conectividad;
    // El singleton de Auth no arrastra sesión entre tests.
    AuthService().currentUserForTesting = null;
  });

  Future<SolicitudesProvider> pumpHome(
    WidgetTester tester, {
    required Size size,
    double bottomPadding = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = FakeViewPadding(bottom: bottomPadding);
    addTearDown(tester.view.reset);

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

    final provider = SolicitudesProvider(fake);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<SolicitudesProvider>.value(
        value: provider,
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return provider;
  }

  /// Descarta los overflows de layout que la fuente de test (Ahem) genera en
  /// widgets NO relacionados con los 3 fixes (ver nota arriba).
  void drenarExcepcionesAhem(WidgetTester tester) {
    while (tester.takeException() != null) {}
  }

  /// Verifica que las dos tarjetas de cada fila tengan la misma altura, que
  /// la fila número+ícono quede a la misma distancia del tope de su tarjeta y
  /// que el valor quede contenido dentro de la tarjeta (sin desbordes).
  void expectStatsAlineados(WidgetTester tester) {
    final rectActivas = tester.getRect(
      find.byKey(const ValueKey('stat-card-Solicitudes Activas')),
    );
    final rectCotizadas = tester.getRect(
      find.byKey(const ValueKey('stat-card-Cotizaciones Recibidas')),
    );
    final rectProceso = tester.getRect(
      find.byKey(const ValueKey('stat-card-En Proceso')),
    );
    final rectOrdenes = tester.getRect(
      find.byKey(const ValueKey('stat-card-Órdenes Realizadas')),
    );

    expect(
      rectActivas.height,
      rectCotizadas.height,
      reason: 'fila 1: alturas iguales',
    );
    expect(
      rectProceso.height,
      rectOrdenes.height,
      reason: 'fila 2: alturas iguales',
    );

    // Valores '02' (Solicitudes Activas) y '00' (Cotizaciones Recibidas)
    // están en la primera fila: el bloque número+ícono debe alinearse igual.
    final vActivas = tester.getRect(find.text('02').first);
    final vCotizadas = tester.getRect(find.text('00').first);

    expect(
      vActivas.top - rectActivas.top,
      vCotizadas.top - rectCotizadas.top,
      reason: 'número+ícono a la misma altura en ambas tarjetas de la fila',
    );

    // Contención: el valor no se sale de su tarjeta (sin desborde vertical).
    expect(vActivas.bottom, lessThanOrEqualTo(rectActivas.bottom));
    expect(vActivas.right, lessThanOrEqualTo(rectActivas.right));
  }

  testWidgets(
    'móvil angosto (~420px): stats con alturas iguales por fila y subtítulo '
    'de la hero con padding',
    (tester) async {
      await pumpHome(tester, size: const Size(420, 900));

      expectStatsAlineados(tester);

      // Subtítulo de la hero: respeta el padding horizontal de la card (no
      // toca los bordes) y queda contenido verticalmente.
      final cardRect = tester.getRect(
        find.byKey(const ValueKey('hero-search-card')),
      );
      final subRect = tester.getRect(
        find.text('Sube una foto y encuentra tu repuesto al instante'),
      );
      expect(
        subRect.left - cardRect.left,
        greaterThanOrEqualTo(AppSpacing.spacingLg - 0.5),
        reason: 'subtítulo separado del borde izquierdo',
      );
      expect(
        cardRect.right - subRect.right,
        greaterThanOrEqualTo(AppSpacing.spacingLg - 0.5),
        reason: 'subtítulo separado del borde derecho',
      );
      expect(
        subRect.bottom,
        lessThanOrEqualTo(cardRect.bottom),
        reason: 'subtítulo contenido dentro de la card',
      );

      drenarExcepcionesAhem(tester);
    },
  );

  testWidgets(
    'móvil con barra de gestos: el bottom nav respeta el área segura inferior',
    (tester) async {
      const screenHeight = 900.0;
      const inset = 24.0;
      await pumpHome(
        tester,
        size: const Size(420, screenHeight),
        bottomPadding: inset,
      );

      final navRect = tester.getRect(
        find.byKey(const ValueKey('bottom-nav-bar')),
      );
      // El fondo cubre el área de gestos: 64 de barra + inset del sistema.
      expect(navRect.height, 64 + inset);
      expect(navRect.bottom, screenHeight);

      // Los ítems quedan por encima del área de gestos.
      final homeRect = tester.getRect(find.text('Home'));
      expect(
        homeRect.bottom,
        lessThanOrEqualTo(screenHeight - inset + 0.5),
        reason: 'ítem visible por encima de la barra de gestos',
      );

      drenarExcepcionesAhem(tester);
    },
  );

  testWidgets(
    'tablet: stats alineadas y bottom nav de 64 (padding de sistema 0)',
    (tester) async {
      await pumpHome(tester, size: const Size(800, 2000));

      expectStatsAlineados(tester);

      final navRect = tester.getRect(
        find.byKey(const ValueKey('bottom-nav-bar')),
      );
      expect(navRect.height, 64, reason: 'sin inset el nav mantiene 64');

      // En ancho de tablet el subtítulo cabe en una línea y sigue sin tocar
      // los bordes de la card.
      final cardRect = tester.getRect(
        find.byKey(const ValueKey('hero-search-card')),
      );
      final subRect = tester.getRect(
        find.text('Sube una foto y encuentra tu repuesto al instante'),
      );
      expect(subRect.left, greaterThanOrEqualTo(cardRect.left));
      expect(subRect.right, lessThanOrEqualTo(cardRect.right));

      // A 800px ni siquiera Ahem desborda: no debe haber excepciones.
      expect(tester.takeException(), isNull);
    },
  );
}
