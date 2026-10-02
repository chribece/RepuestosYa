import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/utils/formato_fecha.dart';

/// Helper central de fechas: ISO 8601 del backend → hora local del
/// dispositivo en formato corto español ("01 oct 2026, 03:47"). Nulos o
/// inválidos devuelven "—" sin lanzar.
const _mesesCortos = [
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

void main() {
  String esperadoDe(DateTime local) {
    final dia = local.day.toString().padLeft(2, '0');
    final hora = local.hour.toString().padLeft(2, '0');
    final minuto = local.minute.toString().padLeft(2, '0');
    return '$dia ${_mesesCortos[local.month - 1]} ${local.year}, $hora:$minuto';
  }

  test('ISO con offset (+00:00) se convierte a hora local del dispositivo', () {
    const iso = '2026-10-01T03:47:06.204109+00:00';
    final local = DateTime.parse(iso).toLocal();

    final resultado = formatFechaHora(iso);

    expect(resultado, esperadoDe(local));
    // No puede quedar el timestamp crudo ni la zona.
    expect(resultado.contains('T03:47'), isFalse);
    expect(resultado.contains('+00:00'), isFalse);
    final mesEsperado = _mesesCortos[local.month - 1];
    expect(
      resultado,
      matches(RegExp('^\\d{2} $mesEsperado \\d{4}, \\d{2}:\\d{2}\$')),
    );
  });

  test('ISO en UTC (sufijo Z) se convierte a hora local', () {
    const iso = '2026-10-01T03:47:06Z';
    final local = DateTime.parse(iso).toLocal();

    expect(formatFechaHora(iso), esperadoDe(local));
  });

  test('DateTime directo se formatea sin re-parsear', () {
    final dt = DateTime(2026, 10, 1, 3, 47);
    final esperado = '01 oct 2026, ${dt.hour.toString().padLeft(2, '0')}:47';

    expect(formatFechaHora(dt), esperado);
  });

  test('null devuelve "—" sin lanzar', () {
    expect(formatFechaHora(null), '—');
  });

  test('texto inválido devuelve "—" sin lanzar', () {
    expect(formatFechaHora('no es una fecha'), '—');
    expect(formatFechaHora(''), '—');
    expect(formatFechaHora('2026-13-99T99:99:99'), '—');
  });

  test('meses cortos en español (enero y diciembre)', () {
    expect(formatFechaHora('2026-01-05T10:00:00Z').contains(' ene '), isTrue);
    expect(formatFechaHora('2026-12-05T10:00:00Z').contains(' dic '), isTrue);
  });
}
