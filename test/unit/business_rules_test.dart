import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/utils/business_rules.dart';

/// Pruebas de las reglas de negocio puras extraídas de las pantallas
/// (`lib/utils/business_rules.dart`). Entrada concreta → salida concreta.
void main() {
  group('parsePrecioVenta', () {
    test('num → double', () {
      expect(parsePrecioVenta(150), 150.0);
      expect(parsePrecioVenta(99.5), 99.5);
    });

    test('string numérico → double', () {
      expect(parsePrecioVenta('12.50'), 12.5);
    });

    test('string no numérico → 0.0', () {
      expect(parsePrecioVenta('abc'), 0.0);
    });

    test('null → 0.0', () {
      expect(parsePrecioVenta(null), 0.0);
    });

    test('tipo inesperado (bool) → 0.0, no lanza', () {
      expect(parsePrecioVenta(true), 0.0);
    });
  });

  group('parseDistanciaKm', () {
    test('num → double', () {
      expect(parseDistanciaKm(3), 3.0);
    });

    test('string numérico → double', () {
      expect(parseDistanciaKm('3.5'), 3.5);
    });

    test('string no numérico → null', () {
      expect(parseDistanciaKm('n/a'), isNull);
    });

    test('null → null', () {
      expect(parseDistanciaKm(null), isNull);
    });

    test('tipo inesperado (bool) → null', () {
      expect(parseDistanciaKm(false), isNull);
    });
  });

  group('formatearDistanciaKm', () {
    test('muestra un decimal', () {
      expect(formatearDistanciaKm(2.84), '2.8 km');
      expect(formatearDistanciaKm('12.35'), '12.4 km');
    });

    test('oculta valores nulos, inválidos o negativos', () {
      expect(formatearDistanciaKm(null), isNull);
      expect(formatearDistanciaKm('n/a'), isNull);
      expect(formatearDistanciaKm(double.infinity), isNull);
      expect(formatearDistanciaKm(-1), isNull);
    });
  });

  group('ordenarCotizaciones', () {
    Map<String, dynamic> cot({
      String id = 'c',
      Object? precio,
      Object? distancia,
      String estado = 'pendiente',
    }) {
      return {
        'id': id,
        'precio_venta': ?precio,
        'distancia_km': ?distancia,
        'estado': estado,
      };
    }

    test('tab 0 (Todas) devuelve la lista sin tocar', () {
      final lista = [cot(id: 'a'), cot(id: 'b')];
      expect(ordenarCotizaciones(lista, 0), same(lista));
    });

    test('tab 1 (Más baratas) filtra por precio mínimo', () {
      final lista = [
        cot(id: 'a', precio: '30'),
        cot(id: 'b', precio: '15'),
        cot(id: 'c', precio: 25),
      ];

      final resultado = ordenarCotizaciones(lista, 1);
      expect(resultado.map((c) => c['id']), ['b']);
    });

    test('tab 1 conserva todas las empatadas en el mínimo', () {
      final lista = [
        cot(id: 'a', precio: '10'),
        cot(id: 'b', precio: 10),
        cot(id: 'c', precio: 20),
      ];

      final resultado = ordenarCotizaciones(lista, 1);
      expect(resultado.map((c) => c['id']).toSet(), {'a', 'b'});
    });

    test('tab 1 excluye cotizaciones que ya no están pendientes', () {
      final lista = [
        cot(id: 'rechazada', precio: 1, estado: 'rechazada'),
        cot(id: 'pendiente', precio: 20),
      ];

      expect(ordenarCotizaciones(lista, 1).map((c) => c['id']), ['pendiente']);
    });

    test('tab 1 con lista vacía → lista vacía', () {
      expect(ordenarCotizaciones([], 1), isEmpty);
    });

    test('tab 2 (Más cercanas) ordena por distancia asc y deja las sin '
        'distancia al final', () {
      final lista = [
        cot(id: 'sin', distancia: null),
        cot(id: 'lejos', distancia: '9.0'),
        cot(id: 'cerca', distancia: 2.5),
        cot(id: 'medio', distancia: '5.1'),
      ];

      final resultado = ordenarCotizaciones(lista, 2);
      expect(resultado.map((c) => c['id']).toList(), [
        'cerca',
        'medio',
        'lejos',
        'sin',
      ]);
    });

    test('tab 2 excluye cotizaciones que ya no están pendientes', () {
      final lista = [
        cot(id: 'rechazada', distancia: 0.1, estado: 'rechazada'),
        cot(id: 'pendiente', distancia: 2.0),
      ];

      expect(ordenarCotizaciones(lista, 2).map((c) => c['id']), ['pendiente']);
    });

    test('tab inválido → lista original', () {
      final lista = [cot(id: 'a')];
      expect(ordenarCotizaciones(lista, 99), same(lista));
    });
  });

  group('calcularDistanciaHaversineKm', () {
    test('calcula la distancia entre coordenadas reales', () {
      final distancia = calcularDistanciaHaversineKm(
        latitudOrigen: -0.18,
        longitudOrigen: -78.49,
        latitudDestino: -0.19,
        longitudDestino: -78.49,
      );

      expect(distancia, isNotNull);
      expect(distancia!, closeTo(1.11, 0.02));
    });

    test('rechaza coordenadas ausentes o fuera de rango', () {
      expect(
        calcularDistanciaHaversineKm(
          latitudOrigen: null,
          longitudOrigen: -78.49,
          latitudDestino: -0.19,
          longitudDestino: -78.49,
        ),
        isNull,
      );
      expect(
        calcularDistanciaHaversineKm(
          latitudOrigen: 91,
          longitudOrigen: -78.49,
          latitudDestino: -0.19,
          longitudDestino: -78.49,
        ),
        isNull,
      );
    });
  });

  group('formatTiempoEnvio', () {
    final now = DateTime.parse('2026-09-25T12:00:00.000Z');

    test('null → "Hace un momento"', () {
      expect(formatTiempoEnvio(null, now: now), 'Hace un momento');
    });

    test('menos de 1 minuto → "Hace un momento"', () {
      final hace = now.subtract(const Duration(seconds: 30));
      expect(
        formatTiempoEnvio(hace.toIso8601String(), now: now),
        'Hace un momento',
      );
    });

    test('1 minuto → "Hace 1 minuto" (singular)', () {
      final hace = now.subtract(const Duration(minutes: 1));
      expect(
        formatTiempoEnvio(hace.toIso8601String(), now: now),
        'Hace 1 minuto',
      );
    });

    test('5 minutos → "Hace 5 minutos"', () {
      final hace = now.subtract(const Duration(minutes: 5));
      expect(
        formatTiempoEnvio(hace.toIso8601String(), now: now),
        'Hace 5 minutos',
      );
    });

    test('1 hora → "Hace 1 hora" (singular)', () {
      final hace = now.subtract(const Duration(hours: 1));
      expect(
        formatTiempoEnvio(hace.toIso8601String(), now: now),
        'Hace 1 hora',
      );
    });

    test('2 horas → "Hace 2 horas"', () {
      final hace = now.subtract(const Duration(hours: 2));
      expect(
        formatTiempoEnvio(hace.toIso8601String(), now: now),
        'Hace 2 horas',
      );
    });

    test('1 día → "Hace 1 día" (singular)', () {
      final hace = now.subtract(const Duration(days: 1));
      expect(formatTiempoEnvio(hace.toIso8601String(), now: now), 'Hace 1 día');
    });

    test('3 días → "Hace 3 días"', () {
      final hace = now.subtract(const Duration(days: 3));
      expect(
        formatTiempoEnvio(hace.toIso8601String(), now: now),
        'Hace 3 días',
      );
    });

    test('fecha inválida → "Hace un momento" (no lanza)', () {
      expect(formatTiempoEnvio('no-es-fecha', now: now), 'Hace un momento');
    });
  });

  group('capitalizarNombre', () {
    test('primera letra de cada palabra en mayúscula', () {
      expect(capitalizarNombre('test almaceb'), 'Test Almaceb');
    });

    test('conserva el resto de letras (siglas y mayúsculas intermedias)', () {
      expect(capitalizarNombre('autoPartes RUC'), 'AutoPartes RUC');
    });

    test('texto vacío se devuelve igual', () {
      expect(capitalizarNombre(''), '');
    });
  });

  group('etiquetaEstadoOrden', () {
    test('mayúscula inicial en estados simples', () {
      expect(etiquetaEstadoOrden('confirmada'), 'Confirmada');
      expect(etiquetaEstadoOrden('entregada'), 'Entregada');
    });

    test('guiones bajos se reemplazan por espacios', () {
      expect(etiquetaEstadoOrden('pendiente_pago'), 'Pendiente pago');
    });

    test('vacío se devuelve vacío', () {
      expect(etiquetaEstadoOrden(''), '');
    });
  });

  group('capitalizarDireccion', () {
    test('primera letra de la dirección y de cada segmento tras coma', () {
      expect(
        capitalizarDireccion('taller pepito, venezuela'),
        'Taller pepito, Venezuela',
      );
    });

    test('no capitaliza cada palabra de la calle', () {
      expect(capitalizarDireccion('frente al parque'), 'Frente al parque');
    });
  });

  group('formatearNumeroOrden', () {
    test('usa los últimos 6 caracteres en mayúsculas con #', () {
      expect(formatearNumeroOrden('6f1c2a3d-4e5f-4a6b-8c7d-b301b9'), '#B301B9');
    });

    test('id corto se muestra completo', () {
      expect(formatearNumeroOrden('ab12'), '#AB12');
    });
  });

  group('formatearDireccionEntrega', () {
    test('une alias, calles y referencia omitiendo vacíos', () {
      expect(
        formatearDireccionEntrega({
          'alias': 'Taller',
          'calle_principal': 'Av. Amazonas',
          'calle_secundaria': '',
          'referencia': 'Frente al parque',
        }),
        'Taller, Av. Amazonas, Frente al parque',
      );
    });

    test('null o sin datos → null', () {
      expect(formatearDireccionEntrega(null), isNull);
      expect(formatearDireccionEntrega({'alias': '  '}), isNull);
    });
  });

  group('formatTiempoRelativo', () {
    final now = DateTime.parse('2026-09-25T12:00:00.000Z');

    test('59 minutos → "Hace 59 minutos" (palabras completas)', () {
      final hace = now.subtract(const Duration(minutes: 59));
      expect(formatTiempoRelativo(hace, now: now), 'Hace 59 minutos');
    });

    test('1 día → "Hace 1 día" (sin "Ayer")', () {
      final hace = now.subtract(const Duration(days: 1));
      expect(formatTiempoRelativo(hace, now: now), 'Hace 1 día');
    });
  });

  group('direccionTieneCoordenadas', () {
    test('null → false', () {
      expect(direccionTieneCoordenadas(null), isFalse);
    });

    test('sin latitude/longitude → false', () {
      expect(direccionTieneCoordenadas({'alias': 'Casa'}), isFalse);
    });

    test('coordenadas numéricas → true', () {
      expect(
        direccionTieneCoordenadas({'latitude': -0.19, 'longitude': -78.49}),
        isTrue,
      );
    });

    test('coordenadas como string → false (no cuenta como resuelta)', () {
      expect(
        direccionTieneCoordenadas({'latitude': '-0.19', 'longitude': '-78.49'}),
        isFalse,
      );
    });

    test('solo una coordenada → false', () {
      expect(direccionTieneCoordenadas({'latitude': -0.19}), isFalse);
    });
  });

  group('buildDescripcionProblema', () {
    test('sin piezas adicionales devuelve la descripción tal cual', () {
      expect(
        buildDescripcionProblema('ruido al frenar', []),
        'ruido al frenar',
      );
    });

    test('con piezas arma el resumen con categoría/repuesto/cantidad', () {
      final resultado = buildDescripcionProblema('Falla principal', [
        (
          categoria: 'Frenos',
          repuesto: 'Pastillas',
          cantidad: 2,
          detalle: null,
        ),
      ]);

      expect(
        resultado,
        'Falla principal\n\n'
        'Repuestos adicionales:\n'
        '1. Categoría: Frenos | Repuesto: Pastillas | Cantidad: 2',
      );
    });

    test('detalle no vacío agrega la línea Detalle', () {
      final resultado = buildDescripcionProblema('', [
        (
          categoria: 'Suspensión',
          repuesto: 'Amortiguador',
          cantidad: 1,
          detalle: '  trasero derecho  ',
        ),
      ]);

      expect(resultado, contains('Detalle: trasero derecho'));
      // El detalle se recorta (trim) antes de incluirse.
      expect(resultado, isNot(contains('  trasero')));
    });

    test('detalle vacío no agrega línea Detalle', () {
      final resultado = buildDescripcionProblema('', [
        (
          categoria: 'Suspensión',
          repuesto: 'Amortiguador',
          cantidad: 1,
          detalle: '   ',
        ),
      ]);

      expect(resultado, isNot(contains('Detalle:')));
    });

    test('descripción vacía con piezas → solo el resumen', () {
      final resultado = buildDescripcionProblema('', [
        (categoria: 'Motor', repuesto: 'Bujía', cantidad: 4, detalle: null),
      ]);

      expect(resultado, startsWith('Repuestos adicionales:'));
      expect(resultado, isNot(contains('\n\n')));
    });

    test('cae a IDs cuando no hay nombres (snapshots ausentes)', () {
      final resultado = buildDescripcionProblema('', [
        (categoria: 'cat-1', repuesto: 'rep-1', cantidad: 1, detalle: null),
      ]);

      expect(resultado, contains('Categoría: cat-1'));
      expect(resultado, contains('Repuesto: rep-1'));
    });
  });
}
