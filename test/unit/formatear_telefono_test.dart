import 'package:flutter_test/flutter_test.dart';
import 'package:repuestosya/utils/contact_launcher.dart';

void main() {
  group('formatearTelefonoParaMostrar', () {
    test('celular local guardado sin 0 inicial recupera el 0', () {
      expect(formatearTelefonoParaMostrar('985245128'), '0985245128');
    });

    test('celular ya con 0 inicial no cambia', () {
      expect(formatearTelefonoParaMostrar('0985245128'), '0985245128');
    });

    test('formato internacional con + no cambia', () {
      expect(formatearTelefonoParaMostrar('+593 998757857'), '+593 998757857');
    });

    test('prefijo internacional 00 no cambia', () {
      expect(formatearTelefonoParaMostrar('00593998757857'), '00593998757857');
    });

    test('número con prefijo 593 (12 dígitos) no cambia', () {
      expect(formatearTelefonoParaMostrar('593998757857'), '593998757857');
    });

    test('espacios alrededor se recortan', () {
      expect(formatearTelefonoParaMostrar('  985245128 '), '0985245128');
    });
  });
}
