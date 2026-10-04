class Almacen {
  final String id;
  final String nombreComercial;
  final String? direccionTexto;
  final double? latitude;
  final double? longitude;
  final String verificationStatus; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;
  final bool isOpen;

  /// Teléfono de contacto del almacén. Solo llega poblado tras la aceptación
  /// de una cotización (el backend sanitiza el resto de respuestas).
  final String? telefono;

  /// Email de contacto del almacén (misma regla de privacidad que [telefono]).
  final String? email;

  Almacen({
    required this.id,
    required this.nombreComercial,
    this.direccionTexto,
    this.latitude,
    this.longitude,
    this.verificationStatus = 'pending',
    this.rejectionReason,
    this.isOpen = true,
    this.telefono,
    this.email,
  });

  factory Almacen.fromJson(Map<String, dynamic> json) {
    return Almacen(
      id: json['id']?.toString() ?? '',
      nombreComercial:
          json['nombre_comercial']?.toString() ?? 'Almacén desconocido',
      direccionTexto: json['direccion_texto']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      verificationStatus: json['verification_status']?.toString() ?? 'pending',
      rejectionReason: json['rejection_reason']?.toString(),
      isOpen: json['estado_abierto'] ?? true,
      telefono: json['telefono']?.toString(),
      email: json['email']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre_comercial': nombreComercial,
      'direccion_texto': direccionTexto,
      'latitude': latitude,
      'longitude': longitude,
      'verification_status': verificationStatus,
      'rejection_reason': rejectionReason,
      'estado_abierto': isOpen,
      'telefono': telefono,
      'email': email,
    };
  }

  bool get isApproved => verificationStatus == 'approved';
  bool get isPending => verificationStatus == 'pending';
  bool get isRejected => verificationStatus == 'rejected';
}
