import 'package:flutter/foundation.dart';
import '../services/profile_service.dart';

enum UserRole { admin, cliente, almacen, unknown }

class UserRoleProvider with ChangeNotifier {
  final ProfileService _profileService = ProfileService();
  
  UserRole _currentRole = UserRole.unknown;
  bool _isLoading = false;
  String? _errorMessage;

  UserRole get currentRole => _currentRole;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  bool get isAdmin => _currentRole == UserRole.admin;
  bool get isCliente => _currentRole == UserRole.cliente;
  bool get isAlmacen => _currentRole == UserRole.almacen;
  bool get isUnknown => _currentRole == UserRole.unknown;

  // Cargar el rol del usuario desde la base de datos
  Future<void> loadUserRole(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final roleString = await _profileService.getUserRole(userId);
      
      if (roleString == null) {
        _errorMessage = 'Perfil de usuario no encontrado';
        _currentRole = UserRole.unknown;
      } else {
        _currentRole = _parseRole(roleString);
        _errorMessage = null;
      }
    } catch (e) {
      _errorMessage = 'Error al cargar el rol: $e';
      _currentRole = UserRole.unknown;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Parsear el string del rol al enum
  UserRole _parseRole(String roleString) {
    switch (roleString.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'cliente':
        return UserRole.cliente;
      case 'almacen':
        return UserRole.almacen;
      default:
        return UserRole.unknown;
    }
  }

  // Establecer el rol manualmente (útil para pruebas o casos especiales)
  void setRole(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }

  // Limpiar el rol (al cerrar sesión)
  void clearRole() {
    _currentRole = UserRole.unknown;
    _errorMessage = null;
    notifyListeners();
  }

  // Obtener el nombre del rol como string
  String getRoleName() {
    switch (_currentRole) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.cliente:
        return 'Cliente';
      case UserRole.almacen:
        return 'Almacén';
      case UserRole.unknown:
        return 'Desconocido';
    }
  }
}
