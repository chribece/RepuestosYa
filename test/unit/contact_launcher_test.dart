import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:repuestosya/utils/contact_launcher.dart';

/// Pruebas del helper de contacto (Fase 1 de docs/TESTING.md): funciones
/// puras de normalización de teléfonos, construcción de URIs y mensajes de
/// WhatsApp, más el launcher con dobles inyectados (sin plugins nativos).
void main() {
  group('normalizePhoneForWhatsApp', () {
    test('celular Ecuador "09XXXXXXXX" → "5939XXXXXXXX"', () {
      expect(normalizePhoneForWhatsApp('0991234567'), '593991234567');
    });

    test('ya trae prefijo "593" → se respeta tal cual', () {
      expect(normalizePhoneForWhatsApp('593991234567'), '593991234567');
    });

    test('trae "+593" → se respeta (los dígitos conservan el 593)', () {
      expect(normalizePhoneForWhatsApp('+593 99 123 4567'), '593991234567');
    });

    test('con espacios, guiones y paréntesis → solo dígitos', () {
      expect(normalizePhoneForWhatsApp('(099) 123-4567'), '593991234567');
    });

    test('número sin cero inicial → se antepone 593', () {
      expect(normalizePhoneForWhatsApp('991234567'), '593991234567');
    });

    test('vacío / sin dígitos → cadena vacía', () {
      expect(normalizePhoneForWhatsApp(''), '');
      expect(normalizePhoneForWhatsApp('   '), '');
      expect(normalizePhoneForWhatsApp('abc-()'), '');
    });

    test('código de país configurable', () {
      expect(
        normalizePhoneForWhatsApp('0412345678', countryCode: '54'),
        '54412345678',
      );
    });
  });

  group('isValidPhone', () {
    test('nulo o vacío → inválido', () {
      expect(isValidPhone(null), isFalse);
      expect(isValidPhone(''), isFalse);
      expect(isValidPhone('   '), isFalse);
    });

    test('con 7+ dígitos → válido', () {
      expect(isValidPhone('0991234567'), isTrue);
      expect(isValidPhone('+593991234567'), isTrue);
    });

    test('con menos de 7 dígitos → inválido', () {
      expect(isValidPhone('123456'), isFalse);
    });
  });

  group('buildWhatsAppUri', () {
    test('arma wa.me con número normalizado y mensaje codificado', () {
      final uri = buildWhatsAppUri('0991234567', 'Hola ¿cómo estás? & bien');
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/593991234567');
      expect(uri.queryParameters['text'], 'Hola ¿cómo estás? & bien');
      // Dart codifica los espacios del query como '+' (forma válida para
      // wa.me) y los caracteres no ASCII/seguros con %XX.
      expect(
        uri.toString(),
        'https://wa.me/593991234567?text=Hola+%C2%BFc%C3%B3mo+est%C3%A1s%3F+%26+bien',
      );
    });

    test('mensaje con acentos y saltos se codifica correctamente', () {
      final uri = buildWhatsAppUri('593991234567', 'Hola\nMundo ñandú');
      expect(uri.queryParameters['text'], 'Hola\nMundo ñandú');
      expect(uri.toString(), contains('%C3%B1'));
      expect(uri.toString(), contains('%0A'));
    });
  });

  group('buildTelUri', () {
    test('usa esquema tel con + prefijo de país', () {
      final uri = buildTelUri('0991234567');
      expect(uri.scheme, 'tel');
      expect(uri.toString(), 'tel:+593991234567');
    });
  });

  group('buildMailtoUri', () {
    test('email válido → mailto', () {
      expect(buildMailtoUri('a@b.com')?.toString(), 'mailto:a@b.com');
    });

    test('nulo o vacío → null', () {
      expect(buildMailtoUri(null), isNull);
      expect(buildMailtoUri('  '), isNull);
    });
  });

  group('mensajes de WhatsApp', () {
    test('cliente: incluye almacén, repuesto y precio con 2 decimales', () {
      final mensaje = mensajeWhatsAppCliente(
        almacenNombre: 'Repuestos Central',
        repuestoNombre: 'Filtro de aceite',
        precio: 45.5,
      );
      expect(mensaje, contains('Repuestos Central'));
      expect(mensaje, contains('Filtro de aceite'));
      expect(mensaje, contains('\$45.50'));
      expect(mensaje, contains('coordinar el pago y el envío'));
    });

    test('almacén: incluye cliente, almacén y repuesto', () {
      final mensaje = mensajeWhatsAppAlmacen(
        clienteNombre: 'Juan Pérez',
        almacenNombre: 'Repuestos Central',
        repuestoNombre: 'Bujías NGK',
      );
      expect(mensaje, contains('Juan Pérez'));
      expect(mensaje, contains('Repuestos Central'));
      expect(mensaje, contains('Bujías NGK'));
      expect(mensaje, contains('fue seleccionada'));
    });
  });

  group('ContactLauncher.launch', () {
    test('canLaunch true y launch true → launched', () async {
      final resultado = await ContactLauncher.launch(
        Uri.parse('tel:+593991234567'),
        canLaunch: (_) async => true,
        launch:
            (Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async =>
                true,
      );
      expect(resultado, ContactLaunchResult.launched);
    });

    test('canLaunch false → notAvailable (sin llamar a launch)', () async {
      var launchLlamado = false;
      final resultado = await ContactLauncher.launch(
        Uri.parse('tel:+593991234567'),
        canLaunch: (_) async => false,
        launch:
            (Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
              launchLlamado = true;
              return true;
            },
      );
      expect(resultado, ContactLaunchResult.notAvailable);
      expect(launchLlamado, isFalse);
    });

    test('launch devuelve false → failed', () async {
      final resultado = await ContactLauncher.launch(
        Uri.parse('https://wa.me/593991234567'),
        canLaunch: (_) async => true,
        launch:
            (Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async =>
                false,
      );
      expect(resultado, ContactLaunchResult.failed);
    });

    test('excepción de plataforma → failed (nunca lanza)', () async {
      final resultado = await ContactLauncher.launch(
        Uri.parse('tel:+593991234567'),
        canLaunch: (_) async => throw Exception('MissingPluginException'),
        launch:
            (Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async =>
                true,
      );
      expect(resultado, ContactLaunchResult.failed);
    });
  });
}
