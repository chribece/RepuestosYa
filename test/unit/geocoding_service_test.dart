import 'package:flutter_test/flutter_test.dart';
import 'package:repuestosya/services/geocoding_service.dart';

/// Pruebas del parseo del reverse geocoding (Nominatim) a campos del
/// formulario: solo autocompleta dentro de Ecuador (alcance actual), road →
/// calle principal y suburb/neighbourhood → referencia.
void main() {
  test('dirección ecuatoriana con road y suburb se mapea a los campos', () {
    final resultado = GeocodingService.parse({
      'road': 'Avenida 10 de Agosto',
      'suburb': 'La Pradera',
      'city': 'Quito',
      'country_code': 'ec',
    });

    expect(resultado, isNotNull);
    expect(resultado!.callePrincipal, 'Avenida 10 de Agosto');
    expect(resultado.referencia, 'La Pradera');
    // Un punto reverse no entrega la intersección: se deja para el usuario.
    expect(resultado.calleSecundaria, isNull);
  });

  test('usa neighbourhood cuando no hay suburb', () {
    final resultado = GeocodingService.parse({
      'road': 'Av. Amazonas',
      'neighbourhood': 'Iñaquito',
      'country_code': 'ec',
    });

    expect(resultado, isNotNull);
    expect(resultado!.callePrincipal, 'Av. Amazonas');
    expect(resultado.referencia, 'Iñaquito');
  });

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
    expect(resultado.referencia, 'La Carolina');
  });

  test('country_code ausente → null (no autocompletar sin contexto)', () {
    final resultado = GeocodingService.parse({'road': 'Av. 10 de Agosto'});
    expect(resultado, isNull);
  });
}
