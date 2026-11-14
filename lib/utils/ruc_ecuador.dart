const _mensajeLongitud = 'El RUC debe tener exactamente 13 dígitos';
const _mensajeProvincia = 'El código de provincia del RUC no es válido';
const _mensajeTipo =
    'El tercer dígito del RUC no corresponde a un tipo de contribuyente válido';
const _mensajeVerificador = 'El RUC no es válido. Revisa los dígitos.';
const _mensajeEstablecimiento =
    'El código de establecimiento del RUC no es válido.';

/// Valida un RUC ecuatoriano (13 dígitos) según las reglas del SRI.
/// Devuelve el mensaje de error o `null` si es válido.
String? validarRucEcuador(String? value) {
  final ruc = value?.trim() ?? '';
  if (ruc.isEmpty) return 'El RUC es requerido';
  if (!RegExp(r'^\d{13}$').hasMatch(ruc)) return _mensajeLongitud;

  final digitos = ruc.split('').map(int.parse).toList();
  final provincia = int.parse(ruc.substring(0, 2));
  if (!((provincia >= 1 && provincia <= 24) || provincia == 30)) {
    return _mensajeProvincia;
  }

  final tipo = digitos[2];
  if (tipo <= 5) {
    // Persona natural: 10 dígitos de cédula (Módulo 10) + 3 de establecimiento.
    if (!_moduloDiez(digitos)) return _mensajeVerificador;
    return ruc.substring(10) == '000' ? _mensajeEstablecimiento : null;
  }
  if (tipo == 6) {
    // Entidad pública: verificador en el 9.º dígito (Módulo 11) + 4 de
    // establecimiento.
    if (!_moduloOnce(digitos, const [3, 2, 7, 6, 5, 4, 3, 2], 8)) {
      return _mensajeVerificador;
    }
    return ruc.substring(9) == '0000' ? _mensajeEstablecimiento : null;
  }
  if (tipo == 9) {
    // Sociedad privada: verificador en el 10.º dígito (Módulo 11) + 3 de
    // establecimiento.
    if (!_moduloOnce(digitos, const [4, 3, 2, 7, 6, 5, 4, 3, 2], 9)) {
      return _mensajeVerificador;
    }
    return ruc.substring(10) == '000' ? _mensajeEstablecimiento : null;
  }
  return _mensajeTipo;
}

bool _moduloDiez(List<int> digitos) {
  const coeficientes = [2, 1, 2, 1, 2, 1, 2, 1, 2];
  var suma = 0;
  for (var i = 0; i < coeficientes.length; i++) {
    var producto = digitos[i] * coeficientes[i];
    if (producto > 9) producto -= 9;
    suma += producto;
  }
  final verificador = (10 - suma % 10) % 10;
  return verificador == digitos[9];
}

bool _moduloOnce(List<int> digitos, List<int> coeficientes, int indiceDv) {
  var suma = 0;
  for (var i = 0; i < coeficientes.length; i++) {
    suma += digitos[i] * coeficientes[i];
  }
  final residuo = suma % 11;
  final verificador = residuo == 0 ? 0 : 11 - residuo;
  if (verificador == 10) return false;
  return verificador == digitos[indiceDv];
}
