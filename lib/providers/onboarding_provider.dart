import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/solicitud_service.dart';
import '../services/vehiculo_service.dart';

class OnboardingProvider with ChangeNotifier {
  static const String skippedKey = 'onboarding_skipped';

  final VehiculoService _vehiculoService = VehiculoService();
  final SolicitudService _solicitudService = SolicitudService();
  final AuthService _authService = AuthService();

  String get _userSkippedKey {
    final userId = _authService.currentUser?.id;
    return userId == null ? skippedKey : '$skippedKey:$userId';
  }

  bool _isLoadingVehicle = false;
  bool _isLoadingRequest = false;
  bool _hasVehicle = false;
  bool _hasRequest = false;
  bool _isSkipped = false;
  String? _errorMessage;

  bool get isLoadingVehicle => _isLoadingVehicle;
  bool get isLoadingRequest => _isLoadingRequest;
  bool get hasVehicle => _hasVehicle;
  bool get hasRequest => _hasRequest;
  bool get isComplete => _hasVehicle && _hasRequest;
  bool get isSkipped => _isSkipped;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoadingVehicle || _isLoadingRequest;

  Future<void> load() async {
    _isLoadingVehicle = true;
    _isLoadingRequest = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _isSkipped = prefs.getBool(_userSkippedKey) ?? false;

      final clienteId = _authService.currentUser?.id ?? '';
      final results = await Future.wait([
        _vehiculoService.getVehiculos(),
        _solicitudService.obtenerSolicitudesCliente(clienteId),
      ]);

      _hasVehicle = results[0].isNotEmpty;
      _hasRequest = results[1].isNotEmpty;
    } catch (e) {
      _errorMessage = 'No se pudo cargar el estado del onboarding.';
    } finally {
      _isLoadingVehicle = false;
      _isLoadingRequest = false;
      notifyListeners();
    }
  }

  Future<void> skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(skippedKey, true);
    if (_userSkippedKey != skippedKey) {
      await prefs.setBool(_userSkippedKey, true);
    }
    _isSkipped = true;
    notifyListeners();
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(skippedKey);
    if (_userSkippedKey != skippedKey) {
      await prefs.remove(_userSkippedKey);
    }
    _isSkipped = false;
    _hasVehicle = false;
    _hasRequest = false;
    _errorMessage = null;
    notifyListeners();
  }
}
