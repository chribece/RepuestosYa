/// Helper central de formateo de fechas para la UI.
///
/// Convierte un timestamp ISO 8601 del backend (con zona horaria) a la hora
/// local del dispositivo y lo muestra en un formato corto en español:
/// `01 oct 2026, 03:47`. Acepta `DateTime` también. Los valores nulos o
/// inválidos devuelven `—` sin lanzar excepción.
///
/// No se usa `intl` (no está en el proyecto): los meses se formatean a mano.
library;

const List<String> _mesesCortos = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Formatea [input] (String ISO 8601 o [DateTime]) a `dd mmm aaaa, hh:mm`
/// en hora local del dispositivo. `null`/inválido → `'—'`.
String formatFechaHora(Object? input) {
  final DateTime? dateTime = switch (input) {
    null => null,
    DateTime value => value,
    final value => _parsearIso(value.toString()),
  };
  if (dateTime == null) return '—';

  final local = dateTime.toLocal();
  final dia = local.day.toString().padLeft(2, '0');
  final hora = local.hour.toString().padLeft(2, '0');
  final minuto = local.minute.toString().padLeft(2, '0');
  return '$dia ${_mesesCortos[local.month - 1]} ${local.year}, $hora:$minuto';
}

/// Parsea un ISO 8601 rechazando los valores fuera de rango: Dart normaliza
/// silenciosamente fechas imposibles (p. ej. `2026-13-99T99:99:99` se
/// convierte en una fecha válida), así que se compara la fecha parseada
/// contra los componentes del texto original.
DateTime? _parsearIso(String texto) {
  final dateTime = DateTime.tryParse(texto);
  if (dateTime == null) return null;

  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(texto);
  if (match == null) return null;
  final anio = int.parse(match.group(1)!);
  final mes = int.parse(match.group(2)!);
  final dia = int.parse(match.group(3)!);
  if (dateTime.year != anio || dateTime.month != mes || dateTime.day != dia) {
    return null;
  }
  return dateTime;
}
