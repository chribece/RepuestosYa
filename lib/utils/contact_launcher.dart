/// Funciones puras y testeables para abrir WhatsApp / teléfono / email desde
/// las pantallas de coordinación de entrega (cliente) y de ofertas ganadas
/// (almacén). Las funciones de normalización y construcción de URIs no tocan
/// plugins; [ContactLauncher.launch] sí usa `url_launcher` y acepta dobles
/// inyectables para los tests.
library;

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Código de país por defecto para números sin prefijo (Ecuador).
const String kCountryCodeEcuador = '593';

/// Normaliza un teléfono para WhatsApp / tel: dejando solo dígitos:
/// - `"09XXXXXXXX"` (celular Ecuador) → `"5939XXXXXXXX"`
/// - `"+593 9X XX..."` o `"5939XXXXXXXX"` → se respeta el prefijo `593`
/// - cualquier otro número → se antepone `593`
/// - vacío / sin dígitos → `''`
String normalizePhoneForWhatsApp(
  String phone, {
  String countryCode = kCountryCodeEcuador,
}) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith(countryCode)) return digits;
  if (digits.startsWith('0')) return '$countryCode${digits.substring(1)}';
  return '$countryCode$digits';
}

/// Un teléfono es utilizable si tiene al menos 7 dígitos (antes de
/// normalizar): evita que un número inválido corto "se vuelva válido" solo
/// por anteponer el código de país.
bool isValidPhone(String? phone) {
  if (phone == null) return false;
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 7;
}

/// URI de WhatsApp: `https://wa.me/<numero>?text=<mensaje codificado>`.
Uri buildWhatsAppUri(String phone, String message) {
  final normalized = normalizePhoneForWhatsApp(phone);
  return Uri(
    scheme: 'https',
    host: 'wa.me',
    path: '/$normalized',
    queryParameters: {'text': message},
  );
}

/// URI de llamada: `tel:+<numero normalizado>`.
Uri buildTelUri(String phone) {
  final normalized = normalizePhoneForWhatsApp(phone);
  return Uri(scheme: 'tel', path: '+$normalized');
}

/// URI de correo: `mailto:<email>`.
Uri? buildMailtoUri(String? email) {
  final trimmed = email?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return Uri(scheme: 'mailto', path: trimmed);
}

/// Mensaje predeterminado del CLIENTE al almacén ganador.
String mensajeWhatsAppCliente({
  required String almacenNombre,
  required String repuestoNombre,
  required double precio,
}) {
  return 'Hola $almacenNombre, soy cliente de RepuestosYa. '
      'Acabo de seleccionar tu cotización para mi repuesto $repuestoNombre '
      'por un valor de \$${precio.toStringAsFixed(2)}. '
      'Me comunico para coordinar el pago y el envío.';
}

/// Mensaje predeterminado del ALMACÉN al cliente ganador.
String mensajeWhatsAppAlmacen({
  required String clienteNombre,
  required String almacenNombre,
  required String repuestoNombre,
}) {
  return 'Hola $clienteNombre, soy $almacenNombre de RepuestosYa. '
      'Tu cotización para $repuestoNombre fue seleccionada. '
      'Te contacto para coordinar el pago y la entrega.';
}

/// Resultado de un intento de apertura de URI externa.
enum ContactLaunchResult {
  /// La URI se abrió correctamente (app externa).
  launched,

  /// No hay app capaz de manejar la URI (p. ej. sin WhatsApp instalado).
  notAvailable,

  /// `launchUrl` devolvió false o lanzó una excepción.
  failed,
}

typedef CanLaunchUrlFn = Future<bool> Function(Uri uri);
typedef LaunchUrlFn = Future<bool> Function(Uri uri, {LaunchMode mode});

/// Abre una URI externa (tel:, https://wa.me, mailto:) con
/// `LaunchMode.externalApplication`. Nunca lanza: cualquier fallo de
/// plataforma se degrada a [ContactLaunchResult.failed] para que la UI
/// muestre el SnackBar y ofrezca copiar el número.
class ContactLauncher {
  const ContactLauncher._();

  static Future<ContactLaunchResult> launch(
    Uri uri, {
    CanLaunchUrlFn? canLaunch,
    LaunchUrlFn? launch,
  }) async {
    try {
      final canOpen = await (canLaunch ?? canLaunchUrl)(uri);
      if (!canOpen) return ContactLaunchResult.notAvailable;

      final opened = await (launch ?? launchUrl)(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return opened ? ContactLaunchResult.launched : ContactLaunchResult.failed;
    } catch (_) {
      return ContactLaunchResult.failed;
    }
  }
}

/// Copia [texto] al portapapeles (fallback cuando no se puede abrir la app).
Future<void> copiarAlPortapapeles(String texto) async {
  await Clipboard.setData(ClipboardData(text: texto));
}
