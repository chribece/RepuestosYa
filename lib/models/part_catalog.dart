class PartCategory {
  final String id;
  final String nombre;
  final String slug;
  final String? descripcion;
  final bool activo;

  PartCategory({
    required this.id,
    required this.nombre,
    required this.slug,
    this.descripcion,
    this.activo = true,
  });

  factory PartCategory.fromJson(Map<String, dynamic> json) {
    return PartCategory(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      descripcion: json['descripcion']?.toString(),
      activo: json['activo'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'slug': slug,
      'descripcion': descripcion,
      'activo': activo,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CatalogPart {
  final String id;
  final String categoriaId;
  final String nombre;
  final String slug;
  final List<String> sinonimos;
  final bool activo;

  CatalogPart({
    required this.id,
    required this.categoriaId,
    required this.nombre,
    required this.slug,
    this.sinonimos = const [],
    this.activo = true,
  });

  factory CatalogPart.fromJson(Map<String, dynamic> json) {
    List<String> parsedSinonimos = [];
    if (json['sinonimos'] != null) {
      if (json['sinonimos'] is List) {
        parsedSinonimos = List<String>.from(
          json['sinonimos'].map((e) => e.toString()),
        );
      } else if (json['sinonimos'] is String) {
        // Handle PostgreSQL array format if necessary: {item1,item2}
        String s = json['sinonimos'];
        if (s.startsWith('{') && s.endsWith('}')) {
          parsedSinonimos = s
              .substring(1, s.length - 1)
              .split(',')
              .map((e) => e.trim())
              .toList();
        }
      }
    }

    return CatalogPart(
      id: json['id']?.toString() ?? '',
      categoriaId: json['categoria_id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      sinonimos: parsedSinonimos,
      activo: json['activo'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoria_id': categoriaId,
      'nombre': nombre,
      'slug': slug,
      'sinonimos': sinonimos,
      'activo': activo,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogPart &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
