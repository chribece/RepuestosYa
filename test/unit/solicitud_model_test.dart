import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/services/solicitud_service.dart';

/// Pruebas de los getters del modelo [Solicitud] (mapeo del contrato del
/// backend): fallbacks de display, parsing estricto de booleanos y fechas.
void main() {
  group('displayPartName / displayDescription (fallback legacy)', () {
    test('repuesto_nombre_snapshot tiene prioridad sobre pieza_nombre', () {
      final s = Solicitud({
        'pieza_nombre': 'Legacy',
        'repuesto_nombre_snapshot': 'Filtro de aceite X',
      });

      expect(s.displayPartName, 'Filtro de aceite X');
    });

    test('sin snapshot usa pieza_nombre', () {
      final s = Solicitud({'pieza_nombre': 'Freno delantero'});

      expect(s.displayPartName, 'Freno delantero');
    });

    test('descripcion_problema tiene prioridad sobre descripcion', () {
      final s = Solicitud({
        'descripcion': 'texto viejo',
        'descripcion_problema': 'Detalle del catálogo',
      });

      expect(s.displayDescription, 'Detalle del catálogo');
    });

    test('sin descripcion_problema usa descripcion', () {
      final s = Solicitud({'descripcion': 'ruido al frenar'});

      expect(s.displayDescription, 'ruido al frenar');
    });

    test('sin ninguna descripción → cadena vacía', () {
      expect(Solicitud({}).displayDescription, '');
    });
  });

  group('esUrgente (parseo estricto)', () {
    test('true booleano → true', () {
      expect(Solicitud({'es_urgente': true}).esUrgente, isTrue);
    });

    test('string "true" → false (el backend envía booleano real)', () {
      expect(Solicitud({'es_urgente': 'true'}).esUrgente, isFalse);
    });

    test('1 numérico → false (tipo inesperado)', () {
      expect(Solicitud({'es_urgente': 1}).esUrgente, isFalse);
    });

    test('ausente → false', () {
      expect(Solicitud({}).esUrgente, isFalse);
    });
  });

  group('cantidadCotizaciones', () {
    test('lee el count de la primera cotización', () {
      final s = Solicitud({
        'cotizaciones': [
          {'count': 3},
        ],
      });

      expect(s.cantidadCotizaciones, 3);
    });

    test('lista vacía → 0', () {
      expect(Solicitud({'cotizaciones': []}).cantidadCotizaciones, 0);
    });

    test('campo ausente → 0', () {
      expect(Solicitud({}).cantidadCotizaciones, 0);
    });

    test('sin count → 0', () {
      expect(
        Solicitud({
          'cotizaciones': [{}],
        }).cantidadCotizaciones,
        0,
      );
    });
  });

  group('createdAt / updatedAt (parseo de fechas)', () {
    test('ISO válido → DateTime', () {
      final s = Solicitud({'created_at': '2026-09-20T10:00:00.000Z'});

      expect(s.createdAt, DateTime.parse('2026-09-20T10:00:00.000Z'));
    });

    test('fecha inválida → null (no lanza)', () {
      expect(Solicitud({'created_at': 'ayer'}).createdAt, isNull);
    });

    test('ausente → null', () {
      expect(Solicitud({}).createdAt, isNull);
    });

    test('updated_at tiene prioridad; sin él usa created_at', () {
      final s = Solicitud({
        'created_at': '2026-09-20T10:00:00.000Z',
        'updated_at': '2026-09-21T10:00:00.000Z',
      });

      expect(s.updatedAt, DateTime.parse('2026-09-21T10:00:00.000Z'));

      final soloCreated = Solicitud({'created_at': '2026-09-20T10:00:00.000Z'});
      expect(soloCreated.updatedAt, DateTime.parse('2026-09-20T10:00:00.000Z'));
    });
  });

  group('categoriaNombre (categoría embebida)', () {
    test('mapea el nombre de la categoría anidada', () {
      final s = Solicitud({
        'categorias_repuestos': {'nombre': 'Frenos'},
      });

      expect(s.categoriaNombre, 'Frenos');
    });

    test('sin categoría → null', () {
      expect(Solicitud({}).categoriaNombre, isNull);
    });
  });

  group('IDs', () {
    test('id numérico del backend se normaliza a string', () {
      expect(Solicitud({'id': 42}).id, '42');
    });

    test('id ausente → cadena vacía', () {
      expect(Solicitud({}).id, '');
    });

    test('clienteId se normaliza a string', () {
      expect(Solicitud({'cliente_id': 'u-1'}).clienteId, 'u-1');
    });
  });

  test('toJson devuelve los datos originales', () {
    final data = {'id': 's1', 'pieza_nombre': 'Filtro'};
    expect(Solicitud(data).toJson(), data);
  });
}
