/// Reglas de negocio puras, extraídas de las pantallas para poder testearlas
/// sin widget tests ni plugins nativos (Fase 1 de docs/TESTING.md).
///
/// Las páginas delegan aquí; el comportamiento es idéntico al código original
/// que reemplazan. Cada función recibe entradas concretas y devuelve salidas
/// deterministas: se prueban con aserciones entrada → salida.
library;

import 'dart:math' as math;

/// Parsea `precio_venta` (numeric de Postgres llega serializado como string
/// en JSON o como num). Devuelve 0.0 si no se puede interpretar. Evita el
/// `TypeError` de `as num` cuando el valor es String.
double parsePrecioVenta(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

/// Parsea `distancia_km` (numeric de Postgres como string o num). Devuelve
/// `null` si no está disponible, para que la UI degrade (no mostrar la fila
/// de distancia) en lugar de fallar.
double? parseDistanciaKm(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Formato compacto y defensivo para la distancia de una solicitud.
String? formatearDistanciaKm(dynamic value) {
  final distancia = parseDistanciaKm(value);
  if (distancia == null || !distancia.isFinite || distancia < 0) return null;
  final redondeada = ((distancia * 10) + 1e-9).round() / 10;
  return '${redondeada.toStringAsFixed(1)} km';
}

/// Calcula la distancia geodésica entre dos puntos usando la fórmula de
/// Haversine. Devuelve null si alguna coordenada no es válida.
double? calcularDistanciaHaversineKm({
  required double? latitudOrigen,
  required double? longitudOrigen,
  required double? latitudDestino,
  required double? longitudDestino,
}) {
  if (latitudOrigen == null ||
      longitudOrigen == null ||
      latitudDestino == null ||
      longitudDestino == null ||
      latitudOrigen.abs() > 90 ||
      latitudDestino.abs() > 90 ||
      longitudOrigen.abs() > 180 ||
      longitudDestino.abs() > 180 ||
      (latitudOrigen == 0 && longitudOrigen == 0) ||
      (latitudDestino == 0 && longitudDestino == 0)) {
    return null;
  }

  const radioTierraKm = 6371.0;
  const gradosARadianes = math.pi / 180;
  final latitudOrigenRad = latitudOrigen * gradosARadianes;
  final latitudDestinoRad = latitudDestino * gradosARadianes;
  final diferenciaLatitud = (latitudDestino - latitudOrigen) * gradosARadianes;
  final diferenciaLongitud =
      (longitudDestino - longitudOrigen) * gradosARadianes;
  final senoLatitud = math.sin(diferenciaLatitud / 2);
  final senoLongitud = math.sin(diferenciaLongitud / 2);
  final a =
      senoLatitud * senoLatitud +
      math.cos(latitudOrigenRad) *
          math.cos(latitudDestinoRad) *
          senoLongitud *
          senoLongitud;
  final angular = 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  return radioTierraKm * angular;
}

/// Ordenamiento/filtro de cotizaciones por tab de la pantalla de cotizaciones
/// recibidas:
/// - `0` ("Todas"): la lista sin tocar.
/// - `1` ("Más baratas"): ofertas pendientes con el precio mínimo; si hay
///   empate se muestran todas las empatadas.
/// - `2` ("Más cercanas"): ofertas pendientes ordenadas por distancia,
///   dejando al final las que no tienen coordenadas disponibles.
/// Cualquier otro índice devuelve la lista original.
List<Map<String, dynamic>> ordenarCotizaciones(
  List<Map<String, dynamic>> cotizaciones,
  int tabIndex,
) {
  switch (tabIndex) {
    case 0: // Todas
      return cotizaciones;
    case 1: // Más baratas
      final disponibles = _cotizacionesPendientes(cotizaciones);
      if (disponibles.isEmpty) return disponibles;
      final precios = disponibles
          .map((c) => parsePrecioVenta(c['precio_venta']))
          .toList();
      final minPrecio = precios.reduce((a, b) => a < b ? a : b);
      return disponibles
          .where((c) => parsePrecioVenta(c['precio_venta']) == minPrecio)
          .toList();
    case 2: // Más cercanas
      final conDistancia =
          _cotizacionesPendientes(
              cotizaciones,
            ).where((c) => parseDistanciaKm(c['distancia_km']) != null).toList()
            ..sort(
              (a, b) => parseDistanciaKm(
                a['distancia_km'],
              )!.compareTo(parseDistanciaKm(b['distancia_km'])!),
            );
      final sinDistancia = _cotizacionesPendientes(
        cotizaciones,
      ).where((c) => parseDistanciaKm(c['distancia_km']) == null).toList();
      return [...conDistancia, ...sinDistancia];
    default:
      return cotizaciones;
  }
}

List<Map<String, dynamic>> _cotizacionesPendientes(
  List<Map<String, dynamic>> cotizaciones,
) {
  return cotizaciones
      .where(
        (cotizacion) =>
            (cotizacion['estado']?.toString().toLowerCase() ?? 'pendiente') ==
            'pendiente',
      )
      .toList();
}

String _cantidadConUnidad(int cantidad, String singular, String plural) =>
    '$cantidad ${cantidad == 1 ? singular : plural}';

/// Formato relativo de tiempo ("Hace un momento", "Hace 1 minuto", "Hace 5
/// minutos", "Hace 1 hora", "Hace 2 horas", "Hace 1 día", "Hace 3 días").
/// [now] es inyectable para hacer el test determinista.
String formatTiempoEnvio(String? createdAt, {DateTime? now}) {
  final dateTime = createdAt == null ? null : DateTime.tryParse(createdAt);
  if (dateTime == null) return 'Hace un momento';
  return formatTiempoRelativo(dateTime, now: now);
}

/// Tiempo transcurrido desde [dateTime] en palabras completas, con singular y
/// plural ("Hace 59 minutos", "Hace 1 hora", "Hace 3 días").
String formatTiempoRelativo(DateTime dateTime, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(dateTime);

  if (difference.inMinutes < 1) {
    return 'Hace un momento';
  } else if (difference.inMinutes < 60) {
    return 'Hace ${_cantidadConUnidad(difference.inMinutes, 'minuto', 'minutos')}';
  } else if (difference.inHours < 24) {
    return 'Hace ${_cantidadConUnidad(difference.inHours, 'hora', 'horas')}';
  }
  return 'Hace ${_cantidadConUnidad(difference.inDays, 'día', 'días')}';
}

/// Pone en mayúscula solo la primera letra de cada palabra y conserva el resto
/// ("test almaceb" → "Test Almaceb", "AutoPartes RUC" → "AutoPartes RUC").
String capitalizarNombre(String texto) => texto.replaceAllMapped(
  RegExp(r'(^|\s)(\S)'),
  (m) => '${m[1]}${m[2]!.toUpperCase()}',
);

/// Etiqueta legible de un estado: sin guiones bajos y con mayúscula inicial
/// ("confirmada" → "Confirmada", "pendiente_pago" → "Pendiente pago").
String etiquetaEstado(String estado) {
  final texto = estado.replaceAll('_', ' ').trim();
  if (texto.isEmpty) return texto;
  return '${texto[0].toUpperCase()}${texto.substring(1)}';
}

/// Capitaliza la primera letra de la dirección y de cada segmento separado por
/// coma, sin tocar el resto ("taller pepito, venezuela" → "Taller pepito,
/// Venezuela"). A diferencia de [capitalizarNombre], no pone en mayúscula cada
/// palabra de la calle ("frente al parque" se mantiene).
String capitalizarDireccion(String texto) => texto.replaceAllMapped(
  RegExp(r'(^|,\s*)(\S)'),
  (m) => '${m[1]}${m[2]!.toUpperCase()}',
);

/// Número de orden amigable a partir del UUID: últimos 6 caracteres en
/// mayúsculas con '#' ("…b301b9" → "#B301B9").
String formatearNumeroOrden(String id) {
  final sufijo = id.length <= 6 ? id : id.substring(id.length - 6);
  return '#${sufijo.toUpperCase()}';
}

/// Dirección de entrega legible (alias, calle principal, calle secundaria y
/// referencia). Devuelve `null` si no hay ningún dato.
String? formatearDireccionEntrega(Map<String, dynamic>? direccion) {
  if (direccion == null) return null;
  final partes = ['alias', 'calle_principal', 'calle_secundaria', 'referencia']
      .map((clave) => direccion[clave]?.toString().trim() ?? '')
      .where((t) => t.isNotEmpty);
  final texto = partes.join(', ');
  return texto.isEmpty ? null : texto;
}

/// Una dirección de entrega es utilizable sin flujo GPS cuando ya trae
/// coordenadas numéricas (`latitude`/`longitude`). Un valor string ("-0.19")
/// no cuenta: la decisión de degradar a captura manual depende de que las
/// coordenadas sean realmente numéricas.
bool direccionTieneCoordenadas(Map<String, dynamic>? direccion) {
  if (direccion == null) return false;
  final lat = direccion['latitude'];
  final lon = direccion['longitude'];
  return lat is num && lon is num;
}

/// Pieza adicional resumida para [buildDescripcionProblema] (desacoplada del
/// provider para mantener la función pura y testeable).
typedef AdditionalPartSummary = ({
  String? categoria,
  String? repuesto,
  int cantidad,
  String? detalle,
});

/// Construye la descripción que viaja al backend como `descripcion_problema`
/// combinando la descripción principal con las piezas adicionales del
/// formulario. Sin piezas adicionales devuelve la descripción tal cual.
String buildDescripcionProblema(
  String descripcion,
  List<AdditionalPartSummary> partes,
) {
  if (partes.isEmpty) return descripcion;

  final lines = <String>['Repuestos adicionales:'];
  for (var index = 0; index < partes.length; index++) {
    final part = partes[index];
    lines.add(
      '${index + 1}. Categoría: ${part.categoria} | '
      'Repuesto: ${part.repuesto} | '
      'Cantidad: ${part.cantidad}',
    );
    final detail = part.detalle?.trim();
    if (detail != null && detail.isNotEmpty) {
      lines.add('Detalle: $detail');
    }
  }

  final summary = lines.join('\n');
  final mainDescription = descripcion.trim();
  if (mainDescription.isEmpty) return summary;
  return '$mainDescription\n\n$summary';
}
