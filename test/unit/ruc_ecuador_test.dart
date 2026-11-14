import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/utils/ruc_ecuador.dart';

void main() {
  group('validarRucEcuador', () {
    test(
      'acepta RUC válidos de persona natural, sociedad privada y pública',
      () {
        expect(validarRucEcuador('1710034065001'), isNull);
        expect(validarRucEcuador('1790000001001'), isNull);
        expect(validarRucEcuador('1760000070001'), isNull);
      },
    );

    test('rechaza vacío y longitud distinta de 13 dígitos', () {
      expect(validarRucEcuador(null), 'El RUC es requerido');
      expect(validarRucEcuador(''), 'El RUC es requerido');
      expect(
        validarRucEcuador('171003406500'),
        'El RUC debe tener exactamente 13 dígitos',
      );
      expect(
        validarRucEcuador('17100340650011'),
        'El RUC debe tener exactamente 13 dígitos',
      );
    });

    test('rechaza caracteres no numéricos', () {
      expect(
        validarRucEcuador('171003406500A'),
        'El RUC debe tener exactamente 13 dígitos',
      );
    });

    test('valida el código de provincia (01-24 o 30)', () {
      expect(
        validarRucEcuador('3510034065001'),
        'El código de provincia del RUC no es válido',
      );
      expect(
        validarRucEcuador('0010034065001'),
        'El código de provincia del RUC no es válido',
      );
    });

    test('valida el tercer dígito según el tipo de contribuyente', () {
      expect(
        validarRucEcuador('1770034065001'),
        'El tercer dígito del RUC no corresponde a un tipo de contribuyente válido',
      );
    });

    test('persona natural: la cédula debe pasar Módulo 10', () {
      expect(
        validarRucEcuador('1710034066001'),
        'El RUC no es válido. Revisa los dígitos.',
      );
    });

    test('sociedad privada: el verificador debe pasar Módulo 11', () {
      expect(
        validarRucEcuador('1790000002001'),
        'El RUC no es válido. Revisa los dígitos.',
      );
    });

    test('entidad pública: el verificador debe pasar Módulo 11', () {
      expect(
        validarRucEcuador('1760000060001'),
        'El RUC no es válido. Revisa los dígitos.',
      );
    });

    test('rechaza establecimiento 000 (persona natural y privada)', () {
      expect(
        validarRucEcuador('1710034065000'),
        'El código de establecimiento del RUC no es válido.',
      );
      expect(
        validarRucEcuador('1790000001000'),
        'El código de establecimiento del RUC no es válido.',
      );
    });

    test('entidad pública: establecimiento de 4 dígitos no puede ser 0000', () {
      expect(
        validarRucEcuador('1760000070000'),
        'El código de establecimiento del RUC no es válido.',
      );
    });
  });
}
