class Cotizacion {
  final String id;
  final String solicitudId;
  final String almacenId;
  final double precioVenta;
  final String? condicionRepuesto;
  final String? tiempoEntregaEstimado;
  final String? notasAdicionales;
  final String? fotoEvidenciaUrl;
  final String estado;
  final DateTime createdAt;
  final Almacen? almacen;

  Cotizacion({
    required this.id,
    required this.solicitudId,
    required this.almacenId,
    required this.precioVenta,
    this.condicionRepuesto,
    this.tiempoEntregaEstimado,
    this.notasAdicionales,
    this.fotoEvidenciaUrl,
    required this.estado,
    required this.createdAt,
    this.almacen,
  });

  factory Cotizacion.fromJson(Map<String, dynamic> json) {
    return Cotizacion(
      id: json['id']?.toString() ?? '',
      solicitudId: json['solicitud_id']?.toString() ?? '',
      almacenId: json['almacen_id']?.toString() ?? '',
      precioVenta: (json['precio_venta'] as num?)?.toDouble() ?? 0.0,
      condicionRepuesto: json['condicion_repuesto']?.toString(),
      tiempoEntregaEstimado: json['tiempo_entrega_estimado']?.toString(),
      notasAdicionales: json['notas_adicionales']?.toString(),
      fotoEvidenciaUrl: json['foto_evidencia_url']?.toString(),
      estado: json['estado']?.toString() ?? 'pendiente',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      almacen: json['almacenes'] != null
          ? Almacen.fromJson(json['almacenes'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'solicitud_id': solicitudId,
      'almacen_id': almacenId,
      'precio_venta': precioVenta,
      'condicion_repuesto': condicionRepuesto,
      'tiempo_entrega_estimado': tiempoEntregaEstimado,
      'notas_adicionales': notasAdicionales,
      'foto_evidencia_url': fotoEvidenciaUrl,
      'estado': estado,
      'created_at': createdAt.toIso8601String(),
      'almacenes': almacen?.toJson(),
    };
  }

  Cotizacion copyWith({
    String? id,
    String? solicitudId,
    String? almacenId,
    double? precioVenta,
    String? condicionRepuesto,
    String? tiempoEntregaEstimado,
    String? notasAdicionales,
    String? fotoEvidenciaUrl,
    String? estado,
    DateTime? createdAt,
    Almacen? almacen,
  }) {
    return Cotizacion(
      id: id ?? this.id,
      solicitudId: solicitudId ?? this.solicitudId,
      almacenId: almacenId ?? this.almacenId,
      precioVenta: precioVenta ?? this.precioVenta,
      condicionRepuesto: condicionRepuesto ?? this.condicionRepuesto,
      tiempoEntregaEstimado:
          tiempoEntregaEstimado ?? this.tiempoEntregaEstimado,
      notasAdicionales: notasAdicionales ?? this.notasAdicionales,
      fotoEvidenciaUrl: fotoEvidenciaUrl ?? this.fotoEvidenciaUrl,
      estado: estado ?? this.estado,
      createdAt: createdAt ?? this.createdAt,
      almacen: almacen ?? this.almacen,
    );
  }

  bool get isPendiente => estado == 'pendiente';
  bool get isAceptada => estado == 'aceptada';
  bool get isRechazada => estado == 'rechazada';
}

class Almacen {
  final String id;
  final String nombreComercial;
  final String? direccionTexto;
  final double? latitude;
  final double? longitude;

  Almacen({
    required this.id,
    required this.nombreComercial,
    this.direccionTexto,
    this.latitude,
    this.longitude,
  });

  factory Almacen.fromJson(Map<String, dynamic> json) {
    return Almacen(
      id: json['id']?.toString() ?? '',
      nombreComercial:
          json['nombre_comercial']?.toString() ?? 'Almacén desconocido',
      direccionTexto: json['direccion_texto']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre_comercial': nombreComercial,
      'direccion_texto': direccionTexto,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
