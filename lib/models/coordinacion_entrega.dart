/// Datos que el cliente necesita para coordinar pago y entrega con el almacén
/// ganador tras aceptar una cotización. Se persisten en caché local para que
/// la pantalla "Éxito y Coordinación de Entrega" funcione sin conexión y
/// pueda reabrirse desde una solicitud ya ACEPTADA.
class DatosCoordinacionEntrega {
  final String solicitudId;
  final String cotizacionId;
  final String almacenNombre;
  final String? telefono;
  final String? email;
  final String repuestoNombre;
  final double precioVenta;

  const DatosCoordinacionEntrega({
    required this.solicitudId,
    required this.cotizacionId,
    required this.almacenNombre,
    this.telefono,
    this.email,
    required this.repuestoNombre,
    required this.precioVenta,
  });

  factory DatosCoordinacionEntrega.fromJson(Map<String, dynamic> json) {
    return DatosCoordinacionEntrega(
      solicitudId: json['solicitudId']?.toString() ?? '',
      cotizacionId: json['cotizacionId']?.toString() ?? '',
      almacenNombre: json['almacenNombre']?.toString() ?? '',
      telefono: json['telefono']?.toString(),
      email: json['email']?.toString(),
      repuestoNombre: json['repuestoNombre']?.toString() ?? '',
      precioVenta: (json['precioVenta'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'solicitudId': solicitudId,
      'cotizacionId': cotizacionId,
      'almacenNombre': almacenNombre,
      'telefono': telefono,
      'email': email,
      'repuestoNombre': repuestoNombre,
      'precioVenta': precioVenta,
    };
  }

  /// Construye los datos desde la respuesta de `POST /quotations/:id/accept`
  /// (el backend incluye `almacen: { nombre, telefono, email }`,
  /// `repuestoNombre` y `precioVenta`). Devuelve `null` si la respuesta no
  /// trae el bloque `almacen` (p. ej. respuestas antiguas o errores).
  static DatosCoordinacionEntrega? fromAceptacionResponse(
    Map<String, dynamic> respuesta, {
    required String cotizacionId,
    required String solicitudId,
  }) {
    final almacen = respuesta['almacen'];
    if (almacen is! Map<String, dynamic>) return null;

    return DatosCoordinacionEntrega(
      solicitudId: solicitudId,
      cotizacionId: cotizacionId,
      almacenNombre: almacen['nombre']?.toString() ?? 'Almacén desconocido',
      telefono: almacen['telefono']?.toString(),
      email: almacen['email']?.toString(),
      repuestoNombre: respuesta['repuestoNombre']?.toString() ?? '',
      precioVenta: (respuesta['precioVenta'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Construye los datos desde un ítem de `GET /quotations/request/:id`
  /// (la cotización GANADA trae `almacenes.telefono/email`). Devuelve `null`
  /// si el ítem no representa la cotización aceptada.
  static DatosCoordinacionEntrega? fromCotizacionMap(
    Map<String, dynamic> cotizacion, {
    required String solicitudId,
  }) {
    if (cotizacion['estado'] != 'aceptada') return null;

    final almacenes = cotizacion['almacenes'];
    final almacen = almacenes is Map<String, dynamic> ? almacenes : null;
    final solicitud = cotizacion['solicitudes_repuesto'];

    return DatosCoordinacionEntrega(
      solicitudId: solicitudId,
      cotizacionId: cotizacion['id']?.toString() ?? '',
      almacenNombre:
          almacen?['nombre_comercial']?.toString() ?? 'Almacén desconocido',
      telefono: almacen?['telefono']?.toString(),
      email: almacen?['email']?.toString(),
      repuestoNombre:
          cotizacion['repuesto_nombre']?.toString() ??
          (solicitud is Map<String, dynamic>
              ? (solicitud['repuesto_nombre_snapshot']?.toString() ??
                    solicitud['pieza_nombre']?.toString() ??
                    '')
              : ''),
      precioVenta: (cotizacion['precio_venta'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Precio formateado consistente con la app (2 decimales).
  String get precioFormateado => '\$${precioVenta.toStringAsFixed(2)}';

  DatosCoordinacionEntrega copyWith({
    String? solicitudId,
    String? cotizacionId,
    String? almacenNombre,
    String? telefono,
    String? email,
    String? repuestoNombre,
    double? precioVenta,
  }) {
    return DatosCoordinacionEntrega(
      solicitudId: solicitudId ?? this.solicitudId,
      cotizacionId: cotizacionId ?? this.cotizacionId,
      almacenNombre: almacenNombre ?? this.almacenNombre,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      repuestoNombre: repuestoNombre ?? this.repuestoNombre,
      precioVenta: precioVenta ?? this.precioVenta,
    );
  }
}
