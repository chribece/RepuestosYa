class OrdenCompra {
  final String id;
  final String clienteId;
  final String almacenId;
  final String solicitudId;
  final String cotizacionId;
  final Map<String, dynamic> detalles;
  final String estado;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String nombreComercialAlmacen;
  final String? direccionTextoAlmacen;

  OrdenCompra({
    required this.id,
    required this.clienteId,
    required this.almacenId,
    required this.solicitudId,
    required this.cotizacionId,
    required this.detalles,
    required this.estado,
    required this.createdAt,
    required this.updatedAt,
    required this.nombreComercialAlmacen,
    this.direccionTextoAlmacen,
  });

  factory OrdenCompra.fromJson(Map<String, dynamic> json) {
    final almacenes = json['almacenes'] as Map<String, dynamic>?;
    return OrdenCompra(
      id: json['id']?.toString() ?? '',
      clienteId: json['cliente_id']?.toString() ?? '',
      almacenId: json['almacen_id']?.toString() ?? '',
      solicitudId: json['solicitud_id']?.toString() ?? '',
      cotizacionId: json['cotizacion_id']?.toString() ?? '',
      detalles: json['detalles'] as Map<String, dynamic>? ?? {},
      estado: json['estado']?.toString() ?? 'pendiente',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      nombreComercialAlmacen:
          almacenes?['nombre_comercial']?.toString() ?? 'Almacén desconocido',
      direccionTextoAlmacen: almacenes?['direccion_texto']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'almacen_id': almacenId,
      'solicitud_id': solicitudId,
      'cotizacion_id': cotizacionId,
      'detalles': detalles,
      'estado': estado,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'almacenes': {
        'nombre_comercial': nombreComercialAlmacen,
        'direccion_texto': direccionTextoAlmacen,
      },
    };
  }

  // Helpers para extraer datos del JSONB detalles
  double get precioVenta {
    return (detalles['precio_venta'] as num?)?.toDouble() ?? 0.0;
  }

  String? get condicionRepuesto {
    return detalles['condicion_repuesto']?.toString();
  }

  String? get tiempoEntrega {
    return detalles['tiempo_entrega_estimado']?.toString();
  }

  String? get notasAdicionales {
    return detalles['notas_adicionales']?.toString();
  }

  String? get fotoEvidenciaUrl {
    return detalles['foto_evidencia_url']?.toString();
  }

  String? get fechaAceptacion {
    return detalles['fecha_aceptacion']?.toString();
  }

  String? get almacenIdFromDetalles {
    return detalles['almacen_id']?.toString();
  }

  String? get cotizacionIdFromDetalles {
    return detalles['cotizacion_id']?.toString();
  }

  bool get isPendiente => estado == 'pendiente';
  bool get isProcesando => estado == 'procesando';
  bool get isCompletada => estado == 'completada';
  bool get isCancelada => estado == 'cancelada';

  String get estadoDisplay {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return 'Pendiente';
      case 'procesando':
        return 'En Proceso';
      case 'completada':
        return 'Completada';
      case 'cancelada':
        return 'Cancelada';
      default:
        return estado;
    }
  }
}
