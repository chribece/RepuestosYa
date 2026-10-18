import 'package:flutter/services.dart';

const int ecuadorMobilePhoneLength = 9;
const String ecuadorMobilePhoneError =
    'Ingresa 9 dígitos sin el 0, ej: 981894367';

final RegExp _ecuadorMobilePhonePattern = RegExp(r'^9\d{8}$');

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
