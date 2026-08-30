import 'dart:io';
import 'package:flutter/foundation.dart';

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
    notifyListeners();
  }
}
