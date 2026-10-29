import 'package:flutter/services.dart';

const int ecuadorMobilePhoneLength = 9;
const String ecuadorMobilePhoneError =
    'Ingresa 9 dígitos sin el 0, ej: 981894367';
const String ecuadorLocalMobilePhoneError =
    'Ingresa 10 dígitos y comienza con 09, ej: 0991234567';

final RegExp _ecuadorMobilePhonePattern = RegExp(r'^9\d{8}$');
final RegExp _ecuadorLocalMobilePhonePattern = RegExp(r'^09\d{8}$');

/// Acepta los formatos ya almacenados por la app y detecta valores pendientes.
bool tieneTelefonoMovilEcuador(String? value) {
  var digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
  if (digits.startsWith('593')) digits = digits.substring(3);
  if (digits.startsWith('0')) digits = digits.substring(1);
  return _ecuadorMobilePhonePattern.hasMatch(digits);
}

List<TextInputFormatter> ecuadorLocalMobilePhoneInputFormatters() => [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(10),
];

String? validarTelefonoLocalEcuador(String? value) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty) return 'El teléfono es requerido';
  if (!_ecuadorLocalMobilePhonePattern.hasMatch(phone)) {
    return ecuadorLocalMobilePhoneError;
  }
  return null;
}

List<TextInputFormatter> ecuadorMobilePhoneInputFormatters() => [
  FilteringTextInputFormatter.digitsOnly,
  TextInputFormatter.withFunction((oldValue, newValue) {
    final removeLeadingZero = newValue.text.startsWith('0');
    var phone = removeLeadingZero ? newValue.text.substring(1) : newValue.text;

    if (phone.isNotEmpty && !phone.startsWith('9')) {
      return oldValue;
    }
    if (phone.length > ecuadorMobilePhoneLength) {
      phone = phone.substring(0, ecuadorMobilePhoneLength);
    }

    final cursorOffset =
        newValue.selection.extentOffset - (removeLeadingZero ? 1 : 0);
    return newValue.copyWith(
      text: phone,
      selection: TextSelection.collapsed(
        offset: cursorOffset.clamp(0, phone.length),
      ),
      composing: TextRange.empty,
    );
  }),
  LengthLimitingTextInputFormatter(ecuadorMobilePhoneLength),
];

String? validarTelefonoMovilEcuador(String? value) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty) return 'El teléfono es requerido';
  if (!_ecuadorMobilePhonePattern.hasMatch(phone)) {
    return ecuadorMobilePhoneError;
  }
  return null;
}
