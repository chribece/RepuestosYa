import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/models/cotizacion.dart';
import 'package:repuestosya/providers/cotizacion_provider.dart';
import 'package:repuestosya/services/cotizacion_repository.dart';

/// Pruebas del [CotizacionProvider] con un repositorio falso: carga,
/// actualización optimista al aceptar/rechazar y manejo de errores sin tocar
/// la red.
void main() {
  Cotizacion cotizacion({
    String id = 'c1',
    String estado = 'pendiente',
    double precio = 25.0,
  }) {
    return Cotizacion(
      id: id,
      solicitudId: 's1',
      almacenId: 'a1',
      precioVenta: precio,
      estado: estado,
      createdAt: DateTime(2026, 9, 20),
    );
  }

  group('cargarCotizaciones', () {
    test('éxito: carga la lista y limpia loading/error', () async {
      final repo = _FakeCotizacionRepository(
        alCargar: () async => [cotizacion(id: 'c1'), cotizacion(id: 'c2')],
      );
      final provider = CotizacionProvider(repository: repo);

      await provider.cargarCotizaciones('s1');

      expect(provider.cotizaciones, hasLength(2));
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test(
      'error: expone el mensaje amigable y no rompe la lista previa',
      () async {
        final repo = _FakeCotizacionRepository(
          alCargar: () async => throw Exception('boom'),
        );
        final provider = CotizacionProvider(repository: repo);

        await provider.cargarCotizaciones('s1');

        expect(provider.errorMessage, isNotNull);
        expect(provider.isLoading, isFalse);
        expect(provider.cotizaciones, isEmpty);
      },
    );
  });

  group('aceptarCotizacion', () {
    test(
      'éxito: guarda ordenId y marca la cotización aceptada (optimista)',
      () async {
        final repo = _FakeCotizacionRepository(
          alCargar: () async => [cotizacion()],
          alAceptar: (id) async => {'ordenId': 'ord-1'},
        );
        final provider = CotizacionProvider(repository: repo);
        await provider.cargarCotizaciones('s1');

        await provider.aceptarCotizacion('c1');

        expect(provider.ordenCompraId, 'ord-1');
        expect(provider.cotizaciones.single.estado, 'aceptada');
        expect(provider.errorMessage, isNull);
        expect(provider.isCotizacionProcesando('c1'), isFalse);
      },
    );

    test('error: mensaje de error y NO se marca aceptada', () async {
      final repo = _FakeCotizacionRepository(
        alCargar: () async => [cotizacion()],
        alAceptar: (id) async => throw Exception('Error al aceptar'),
      );
      final provider = CotizacionProvider(repository: repo);
      await provider.cargarCotizaciones('s1');

      await provider.aceptarCotizacion('c1');

      expect(provider.errorMessage, isNotNull);
      expect(provider.ordenCompraId, isNull);
      expect(provider.cotizaciones.single.estado, 'pendiente');
      expect(provider.isCotizacionProcesando('c1'), isFalse);
    });
  });

  group('rechazarCotizacion', () {
    test('éxito: refleja solicitudCerrada y marca rechazada', () async {
      final repo = _FakeCotizacionRepository(
        alCargar: () async => [cotizacion()],
        alRechazar: (id) async => {'solicitudCerrada': true},
      );
      final provider = CotizacionProvider(repository: repo);
      await provider.cargarCotizaciones('s1');

      await provider.rechazarCotizacion('c1');

      expect(provider.solicitudCerrada, isTrue);
      expect(provider.cotizaciones.single.estado, 'rechazada');
      expect(provider.ordenCompraId, isNull);
    });

    test('error: mensaje de error y el estado no cambia', () async {
      final repo = _FakeCotizacionRepository(
        alCargar: () async => [cotizacion()],
        alRechazar: (id) async => throw Exception('no se pudo'),
      );
      final provider = CotizacionProvider(repository: repo);
      await provider.cargarCotizaciones('s1');

      await provider.rechazarCotizacion('c1');

      expect(provider.errorMessage, isNotNull);
      expect(provider.cotizaciones.single.estado, 'pendiente');
    });
  });

  test('reset() limpia todo el estado', () async {
    final repo = _FakeCotizacionRepository(
      alCargar: () async => [cotizacion()],
      alAceptar: (id) async => {'ordenId': 'ord-1'},
    );
    final provider = CotizacionProvider(repository: repo);
    await provider.cargarCotizaciones('s1');
    await provider.aceptarCotizacion('c1');

    provider.reset();

    expect(provider.cotizaciones, isEmpty);
    expect(provider.ordenCompraId, isNull);
    expect(provider.errorMessage, isNull);
    expect(provider.isLoading, isFalse);
    expect(provider.solicitudCerrada, isFalse);
  });
}

/// Doble del repositorio de cotizaciones: resultados scriptables por llamada,
/// sin red.
class _FakeCotizacionRepository implements CotizacionRepository {
  _FakeCotizacionRepository({
    Future<List<Cotizacion>> Function()? alCargar,
    Future<Map<String, dynamic>> Function(String id)? alAceptar,
    Future<Map<String, dynamic>> Function(String id)? alRechazar,
  }) : alCargar = alCargar ?? (() async => []),
       alAceptar = alAceptar ?? ((id) async => {'ordenId': 'ord-x'}),
       alRechazar = alRechazar ?? ((id) async => {'solicitudCerrada': false});

  Future<List<Cotizacion>> Function() alCargar;
  Future<Map<String, dynamic>> Function(String id) alAceptar;
  Future<Map<String, dynamic>> Function(String id) alRechazar;

  @override
  Future<List<Cotizacion>> getCotizacionesPorSolicitud(String solicitudId) {
    return alCargar();
  }

  @override
  Future<Map<String, dynamic>> aceptarCotizacion(String cotizacionId) {
    return alAceptar(cotizacionId);
  }

  @override
  Future<Map<String, dynamic>> rechazarCotizacion(String cotizacionId) {
    return alRechazar(cotizacionId);
  }
}
