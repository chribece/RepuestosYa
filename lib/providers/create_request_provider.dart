import 'dart:io';

import 'package:flutter/foundation.dart';

class AdditionalRequestPart {
  AdditionalRequestPart({String? id})
    : id = id ?? 'pieza-adicional-${_nextId++}';

  static int _nextId = 0;

  final String id;
  String? categoriaId;
  String? categoriaNombre;
  String? repuestoId;
  String? repuestoNombreSnapshot;
  String? descripcionProblema;
  int cantidad = 1;
}

class CreateRequestProvider with ChangeNotifier {
  String piezaNombre = '';
  String descripcion = '';
  File? selectedImage;
  String? selectedVehiculoId;
  String? selectedDireccionId;
  String selectedPrioridad = 'estándar';

  String? selectedCategoryId;
  String? selectedPartId;
  String? partNameSnapshot;

  final List<AdditionalRequestPart> _additionalParts = [];

  List<AdditionalRequestPart> get additionalParts =>
      List.unmodifiable(_additionalParts);

  void updatePiezaNombre(String val) {
    piezaNombre = val;
    notifyListeners();
  }

  void updateDescripcion(String val) {
    descripcion = val;
    notifyListeners();
  }

  void updateImage(File? file) {
    selectedImage = file;
    notifyListeners();
  }

  void updateVehiculo(String? id) {
    selectedVehiculoId = id;
    notifyListeners();
  }

  void updateDireccion(String? id) {
    selectedDireccionId = id;
    notifyListeners();
  }

  void updatePrioridad(String val) {
    selectedPrioridad = val;
    notifyListeners();
  }

  void setSelectedCategoryId(String? id) {
    if (selectedCategoryId != id) {
      selectedCategoryId = id;
      selectedPartId = null;
      partNameSnapshot = null;
      notifyListeners();
    }
  }

  void setSelectedPartId(String? id, String? name) {
    if (selectedPartId != id) {
      selectedPartId = id;
      partNameSnapshot = name;
      if (name != null) {
        piezaNombre = name;
      }
      notifyListeners();
    }
  }

  AdditionalRequestPart addAdditionalPart() {
    final part = AdditionalRequestPart();
    _additionalParts.add(part);
    notifyListeners();
    return part;
  }

  void updateAdditionalCategory(
    String partId,
    String? categoryId,
    String? categoryName,
  ) {
    final part = _findAdditionalPart(partId);
    if (part == null) return;

    part.categoriaId = categoryId;
    part.categoriaNombre = categoryName;
    part.repuestoId = null;
    part.repuestoNombreSnapshot = null;
    notifyListeners();
  }

  void updateAdditionalPart(
    String partId,
    String? repuestoId,
    String? repuestoName,
  ) {
    final part = _findAdditionalPart(partId);
    if (part == null) return;

    part.repuestoId = repuestoId;
    part.repuestoNombreSnapshot = repuestoName;
    notifyListeners();
  }

  void updateAdditionalDescription(String partId, String? description) {
    final part = _findAdditionalPart(partId);
    if (part == null) return;

    part.descripcionProblema = description;
    notifyListeners();
  }

  void updateAdditionalQuantity(String partId, int quantity) {
    final part = _findAdditionalPart(partId);
    if (part == null) return;

    part.cantidad = quantity < 1 ? 1 : quantity;
    notifyListeners();
  }

  void removeAdditionalPart(String partId) {
    _additionalParts.removeWhere((part) => part.id == partId);
    notifyListeners();
  }

  AdditionalRequestPart? _findAdditionalPart(String partId) {
    for (final part in _additionalParts) {
      if (part.id == partId) return part;
    }
    return null;
  }

  void clear() {
    piezaNombre = '';
    descripcion = '';
    selectedImage = null;
    selectedVehiculoId = null;
    selectedDireccionId = null;
    selectedPrioridad = 'estándar';
    selectedCategoryId = null;
    selectedPartId = null;
    partNameSnapshot = null;
    _additionalParts.clear();
    notifyListeners();
  }
}
