import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/services/geocoding_service.dart';

void main() {
  group('parseCentroCiudad', () {
    test('lee lat/lon del primer resultado de Nominatim', () {
      final centro = GeocodingService.parseCentroCiudad(
        '[{"lat":"-2.1709979","lon":"-79.9223592","display_name":"Guayaquil"}]',
      );
      expect(centro, isNotNull);
      expect(centro!.lat, closeTo(-2.1709979, 1e-7));
      expect(centro.lng, closeTo(-79.9223592, 1e-7));
    });

    test('devuelve null si no hay resultados o el formato no coincide', () {
      expect(GeocodingService.parseCentroCiudad('[]'), isNull);
      expect(GeocodingService.parseCentroCiudad('{"error":"x"}'), isNull);
      expect(
        GeocodingService.parseCentroCiudad('[{"lat":"abc","lon":"1"}]'),
        isNull,
      );
    });
  });

  group('mismaCiudad', () {
    test('ignora mayúsculas, acentos y prefijos administrativos', () {
      expect(GeocodingService.mismaCiudad('Guayaquil', 'guayaquil'), isTrue);
      expect(GeocodingService.mismaCiudad('Durán', 'Duran'), isTrue);
      expect(
        GeocodingService.mismaCiudad(
          'Distrito Metropolitano de Quito',
          'Quito',
        ),
        isTrue,
      );
    });

    test('distingue ciudades distintas y rechaza vacíos', () {
      expect(GeocodingService.mismaCiudad('Quito', 'Guayaquil'), isFalse);
      expect(GeocodingService.mismaCiudad('', 'Quito'), isFalse);
      expect(GeocodingService.mismaCiudad(null, null), isFalse);
    });
  });
}
