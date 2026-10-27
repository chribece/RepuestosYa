import 'package:flutter_test/flutter_test.dart';
import 'package:repuestosya/services/geocoding_service.dart';

/// Pruebas del parseo del reverse geocoding (Nominatim) a campos del
/// formulario: solo autocompleta dentro de Ecuador (alcance actual), extrae
/// calles, filtra sectores y normaliza la ciudad detectada.
void main() {
  test('usa cruce cercano como calle secundaria y conserva el sector', () {
    final resultado = GeocodingService.parse({
      'road': 'Avenida 10 de Agosto',
      'intersection': 'Calle José Tamayo',
      'suburb': 'La Pradera',
      'city': 'Quito',
      'country_code': 'ec',
    });

    expect(resultado, isNotNull);
    expect(resultado!.ciudad, 'Quito');
    expect(resultado.callePrincipal, 'Avenida 10 de Agosto');
    expect(resultado.calleSecundaria, 'Calle José Tamayo');
    expect(resultado.referencia, 'La Pradera');
  });

  test('usa una vía alternativa del address cuando hay más de una', () {
    final resultado = GeocodingService.parse({
      'road': 'Av. Amazonas',
      'residential': 'Pasaje Los Pinos',
      'neighbourhood': 'Iñaquito',
      'town': 'Quito',
      'country_code': 'ec',
    });

    expect(resultado, isNotNull);
    expect(resultado!.callePrincipal, 'Av. Amazonas');
    expect(resultado.calleSecundaria, 'Pasaje Los Pinos');
    expect(resultado.ciudad, 'Quito');
    expect(resultado.referencia, 'Iñaquito');
  });

  test('conserva el sector como referencia, no como calle secundaria', () {
    final resultado = GeocodingService.parse({
      'road': 'Av. Amazonas',
      'neighbourhood': 'Iñaquito',
      'country_code': 'ec',
    });

    expect(resultado, isNotNull);
    expect(resultado!.calleSecundaria, isNull);
    expect(resultado.referencia, 'Iñaquito');
  });

  test('no acepta un barrio detectado como ciudad', () {
    final resultado = GeocodingService.parse({
      'city': 'Puertas del Sol',
      'city_district': 'Calderón',
      'neighbourhood': 'Puertas del Sol',
      'country_code': 'ec',
    });

    expect(resultado, isNotNull);
    expect(resultado!.ciudad, isNull);
  });

  test('no inventa ciudad si Nominatim solo devuelve distrito y barrio', () {
    final resultado = GeocodingService.parse({
      'city_district': 'Calderón',
      'suburb': 'Puertas del Sol',
      'country_code': 'ec',
    });

    expect(resultado, isNotNull);
    expect(resultado!.ciudad, isNull);
  });

  test('rechaza nombres de sectores inyectados en la clave city', () {
    final resultado = GeocodingService.parse({
      'city': 'Urbanización Puertas del Sol',
      'town': 'Quito',
      'country_code': 'ec',
    });

    expect(resultado, isNotNull);
    expect(resultado!.ciudad, 'Quito');
  });

  test('descarta sectores y urbanizaciones de la calle secundaria', () {
    final resultado = GeocodingService.parse({
      'road': 'Av. Simón Bolívar',
      'intersection': 'Barrio San Isidro',
      'cross_street': 'Lotización Los Pinos',
      'suburb': 'San Isidro del Inca',
      'country_code': 'ec',
    });

    expect(resultado, isNotNull);
    expect(resultado!.calleSecundaria, isNull);
    expect(resultado.referencia, 'San Isidro del Inca');
  });

  test(
    'selecciona la vía nombrada más cercana y descarta la calle principal',
    () {
      const lat = -0.133788;
      const lng = -78.466882;
      final secondary = GeocodingService.parseNearbySecondaryRoad(
        {
          'elements': [
            {
              'tags': {'name': 'Pedro Guerrero', 'highway': 'residential'},
              'geometry': [
                {'lat': -0.133788, 'lon': -78.4671},
                {'lat': -0.133788, 'lon': -78.4667},
              ],
            },
            {
              'tags': {'name': 'Calle paralela', 'highway': 'residential'},
              'geometry': [
                {'lat': -0.13375, 'lon': -78.4671},
                {'lat': -0.13375, 'lon': -78.4667},
              ],
            },
            {
              'tags': {'name': 'Cesar Teran Lopez', 'highway': 'residential'},
              'geometry': [
                {'lat': -0.1340, 'lon': -78.46675},
                {'lat': -0.1336, 'lon': -78.46675},
              ],
            },
            {
              'tags': {'name': 'Calle lejana', 'highway': 'residential'},
              'geometry': [
                {'lat': -0.1345, 'lon': -78.466882},
                {'lat': -0.1344, 'lon': -78.466882},
              ],
            },
          ],
        },
        lat: lat,
        lng: lng,
        callePrincipal: 'Pedro Guerrero',
      );

      expect(secondary, 'Cesar Teran Lopez');
    },
  );

  test('fuera de Ecuador → null (fuera del alcance actual)', () {
    final resultado = GeocodingService.parse({
      'road': 'Av. 9 de Octubre',
      'suburb': 'Centro',
      'country_code': 'co', // Colombia
    });

    expect(resultado, isNull);
  });

  test('sin road → callePrincipal nula (el usuario la escribe)', () {
    final resultado = GeocodingService.parse({
      'neighbourhood': 'La Carolina',
      'country_code': 'ec',
    });

    expect(resultado, isNotNull);
    expect(resultado!.callePrincipal, isNull);
    expect(resultado.calleSecundaria, isNull);
    expect(resultado.referencia, 'La Carolina');
  });

  test('country_code ausente → null (no autocompletar sin contexto)', () {
    final resultado = GeocodingService.parse({'road': 'Av. 10 de Agosto'});
    expect(resultado, isNull);
  });
}
