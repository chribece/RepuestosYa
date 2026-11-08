import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:repuestosya/models/orden_compra.dart';
import 'package:repuestosya/pages/orden_compra_page.dart';
import 'package:repuestosya/providers/orden_compra_provider.dart';
import 'package:repuestosya/services/orden_compra_repository.dart';
import 'package:repuestosya/widgets/ry_calificacion_orden.dart';

Future<void> _pumpCalificacion(
  WidgetTester tester, {
  required EnviarCalificacion onEnviar,
  int? estrellasIniciales,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RyCalificacionOrden(
            onEnviar: onEnviar,
            estrellasIniciales: estrellasIniciales,
          ),
        ),
      ),
    ),
  );
}

Map<String, dynamic> _ordenJson({required String estado, int? estrellas}) {
  return {
    'id': 'ord-1',
    'cliente_id': 'c-1',
    'almacen_id': 'a-1',
    'solicitud_id': 's-1',
    'cotizacion_id': 'cot-1',
    'estado': estado,
    'created_at': '2026-09-20T10:00:00.000Z',
    'updated_at': '2026-09-20T10:00:00.000Z',
    'almacenes': {'nombre_comercial': 'Test Almaceb'},
    'detalles': {'precio_venta': 22, 'condicion_repuesto': 'Nuevo'},
    if (estrellas != null)
      'calificaciones_orden': [
        {'estrellas': estrellas, 'comentario': 'Muy bien'},
      ],
  };
}

class _FakeOrdenRepository implements OrdenCompraRepository {
  _FakeOrdenRepository({required this.estado, this.estrellas});

  final String estado;
  final int? estrellas;

  @override
  Future<OrdenCompra> getOrdenDetalle(String ordenId) async =>
      OrdenCompra.fromJson(_ordenJson(estado: estado, estrellas: estrellas));

  @override
  Future<Map<String, dynamic>> actualizarEstadoOrden(
    String ordenId,
    String nuevoEstado,
  ) async => {'id': ordenId, 'estado': nuevoEstado};

  @override
  Future<Map<String, dynamic>> calificarOrden(
    String ordenId, {
    required int estrellas,
    String? comentario,
  }) async => {'estrellas': estrellas, 'comentario': comentario};
}

void main() {
  testWidgets('sin estrellas el botón Enviar queda deshabilitado', (
    tester,
  ) async {
    var llamadas = 0;
    await _pumpCalificacion(
      tester,
      onEnviar: (_, _) async {
        llamadas++;
        return null;
      },
    );

    expect(find.text('Califica tu experiencia'), findsOneWidget);
    await tester.tap(find.text('Enviar Calificación'));
    await tester.pump();

    expect(llamadas, 0);
    expect(find.text('¡Gracias por tu calificación!'), findsNothing);
  });

  testWidgets(
    'tocar 4 estrellas y enviar envía la calificación y muestra el agradecimiento',
    (tester) async {
      int? estrellasEnviadas;
      String? comentarioEnviado;
      await _pumpCalificacion(
        tester,
        onEnviar: (estrellas, comentario) async {
          estrellasEnviadas = estrellas;
          comentarioEnviado = comentario;
          return null;
        },
      );

      await tester.tap(find.byTooltip('4 estrellas'));
      await tester.pump();
      expect(find.byIcon(Icons.star), findsNWidgets(4));
      expect(find.byIcon(Icons.star_border), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  Llegó a tiempo  ');
      await tester.tap(find.text('Enviar Calificación'));
      await tester.pumpAndSettle();

      expect(estrellasEnviadas, 4);
      expect(comentarioEnviado, 'Llegó a tiempo');
      expect(find.text('¡Gracias por tu calificación!'), findsOneWidget);
      expect(find.text('Califica tu experiencia'), findsNothing);
      expect(find.byIcon(Icons.star), findsNWidgets(4));
      expect(find.byIcon(Icons.star_border), findsOneWidget);
    },
  );

  testWidgets(
    'si el envío falla, el formulario sigue abierto para reintentar',
    (tester) async {
      await _pumpCalificacion(tester, onEnviar: (_, _) async => 'Sin conexión');

      await tester.tap(find.byTooltip('5 estrellas'));
      await tester.pump();
      await tester.tap(find.text('Enviar Calificación'));
      await tester.pumpAndSettle();

      expect(find.text('Califica tu experiencia'), findsOneWidget);
      expect(find.text('¡Gracias por tu calificación!'), findsNothing);
    },
  );

  testWidgets('una calificación previa abre directamente el agradecimiento', (
    tester,
  ) async {
    await _pumpCalificacion(
      tester,
      onEnviar: (_, _) async => null,
      estrellasIniciales: 3,
    );

    expect(find.text('¡Gracias por tu calificación!'), findsOneWidget);
    expect(find.text('Califica tu experiencia'), findsNothing);
    expect(find.byIcon(Icons.star), findsNWidgets(3));
  });

  testWidgets(
    'orden entregada muestra la calificación en lugar del encabezado de éxito',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<OrdenCompraProvider>(
          create: (_) => OrdenCompraProvider(
            repository: _FakeOrdenRepository(estado: 'entregada'),
          ),
          child: const MaterialApp(home: OrdenCompraPage(ordenId: 'ord-1')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Califica tu experiencia'), findsOneWidget);
      expect(find.text('¡Orden Generada con Éxito!'), findsNothing);
    },
  );

  testWidgets('orden entregada ya calificada muestra las estrellas guardadas', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<OrdenCompraProvider>(
        create: (_) => OrdenCompraProvider(
          repository: _FakeOrdenRepository(estado: 'entregada', estrellas: 5),
        ),
        child: const MaterialApp(home: OrdenCompraPage(ordenId: 'ord-1')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('¡Gracias por tu calificación!'), findsOneWidget);
    expect(find.text('Califica tu experiencia'), findsNothing);
    expect(find.byIcon(Icons.star), findsNWidgets(5));
  });

  testWidgets(
    'orden confirmada conserva el encabezado de éxito sin calificación',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<OrdenCompraProvider>(
          create: (_) => OrdenCompraProvider(
            repository: _FakeOrdenRepository(estado: 'confirmada'),
          ),
          child: const MaterialApp(home: OrdenCompraPage(ordenId: 'ord-1')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('¡Orden Generada con Éxito!'), findsOneWidget);
      expect(find.text('Califica tu experiencia'), findsNothing);
    },
  );
}
