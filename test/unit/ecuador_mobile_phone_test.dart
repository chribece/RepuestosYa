import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repuestosya/utils/ecuador_mobile_phone.dart';

void main() {
  group('tieneTelefonoMovilEcuador', () {
    test('detecta teléfonos existentes en los formatos soportados', () {
      expect(tieneTelefonoMovilEcuador('0991234567'), isTrue);
      expect(tieneTelefonoMovilEcuador('991234567'), isTrue);
      expect(tieneTelefonoMovilEcuador('+593 99 123 4567'), isTrue);
    });

    test('detecta teléfono ausente, pendiente o inválido', () {
      expect(tieneTelefonoMovilEcuador(null), isFalse);
      expect(tieneTelefonoMovilEcuador(''), isFalse);
      expect(tieneTelefonoMovilEcuador('pendiente'), isFalse);
      expect(tieneTelefonoMovilEcuador('0891234567'), isFalse);
    });
  });

  group('validarTelefonoLocalEcuador', () {
    test('requiere 10 dígitos locales iniciando con 09', () {
      expect(validarTelefonoLocalEcuador(null), 'El teléfono es requerido');
      expect(validarTelefonoLocalEcuador('0991234567'), isNull);
      expect(
        validarTelefonoLocalEcuador('991234567'),
        ecuadorLocalMobilePhoneError,
      );
      expect(
        validarTelefonoLocalEcuador('0891234567'),
        ecuadorLocalMobilePhoneError,
      );
      expect(
        validarTelefonoLocalEcuador('099123456'),
        ecuadorLocalMobilePhoneError,
      );
    });
  });

  group('validarTelefonoMovilEcuador', () {
    test('requiere un teléfono', () {
      expect(validarTelefonoMovilEcuador(null), 'El teléfono es requerido');
      expect(validarTelefonoMovilEcuador('  '), 'El teléfono es requerido');
    });

    test('exige nueve dígitos comenzando con 9, sin cero inicial', () {
      expect(validarTelefonoMovilEcuador('981894367'), isNull);
      expect(validarTelefonoMovilEcuador('98189436'), ecuadorMobilePhoneError);
      expect(
        validarTelefonoMovilEcuador('0981894367'),
        ecuadorMobilePhoneError,
      );
      expect(validarTelefonoMovilEcuador('881894367'), ecuadorMobilePhoneError);
    });
  });

  group('ecuadorMobilePhoneInputFormatters', () {
    TextEditingValue format(String text) {
      final oldValue = TextEditingValue.empty;
      var newValue = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );

      for (final formatter in ecuadorMobilePhoneInputFormatters()) {
        newValue = formatter.formatEditUpdate(oldValue, newValue);
      }
      return newValue;
    }

    test('solo deja escribir nueve dígitos', () {
      expect(format('9818943675').text, '981894367');
      expect(format('9818a94367').text, '981894367');
    });

    test('quita el cero del formato local al pegar el teléfono', () {
      expect(format('0981894367').text, '981894367');
    });

    test('rechaza números que no comienzan con 9', () {
      expect(format('881894367').text, isEmpty);
    });
  });
}
