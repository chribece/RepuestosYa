class Notificacion {
  final String id;
  final String tipo;
  final String titulo;
  final String? mensaje;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;
  final DateTime? leidoEn;

  const Notificacion({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.payload,
    required this.createdAt,
    required this.leidoEn,
  });

  bool get estaLeida => leidoEn != null;

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    return Notificacion(
      id: json['id']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? '',
      titulo: json['titulo']?.toString() ?? '',
      mensaje: json['mensaje']?.toString(),
      payload: rawPayload is Map
          ? Map<String, dynamic>.from(rawPayload)
          : const {},
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      leidoEn: DateTime.tryParse(json['leido_en']?.toString() ?? ''),
    );
  }

  Notificacion marcadaLeida(DateTime fecha) => Notificacion(
    id: id,
    tipo: tipo,
    titulo: titulo,
    mensaje: mensaje,
    payload: payload,
    createdAt: createdAt,
    leidoEn: fecha,
  );
}

class PaginaNotificaciones {
  final List<Notificacion> items;
  final int page;
  final int limit;
  final bool hasMore;

  const PaginaNotificaciones({
    required this.items,
    required this.page,
    required this.limit,
    required this.hasMore,
  });
}
