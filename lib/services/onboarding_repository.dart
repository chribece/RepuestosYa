import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import 'auth_service.dart';
import 'solicitud_repository.dart';
import 'vehiculo_repository.dart';

abstract class OnboardingRepository {
  Future<bool> isSkipped();
  Future<void> setSkipped();
  Future<void> clearSkipped();
  Future<bool> hasVehicle();
  Future<bool> hasRequest();
}

class OnboardingRepositoryImpl implements OnboardingRepository {
  static const String _skippedKey = 'onboarding_skipped';

  final AuthService _auth;
  final VehiculoRepository _vehiculos;
  final SolicitudRepositoryContract _solicitudes;

  OnboardingRepositoryImpl({
    AuthService? auth,
    VehiculoRepository? vehiculos,
    SolicitudRepositoryContract? solicitudes,
  }) : _auth = auth ?? AuthService(),
       _vehiculos = vehiculos ?? VehiculoRepositoryImpl(),
       _solicitudes = solicitudes ?? SolicitudRepository(AppDatabase());

  String get _userSkippedKey {
    final userId = _auth.currentUser?.id;
    return userId == null ? _skippedKey : '$_skippedKey:$userId';
  }

  @override
  Future<bool> isSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_userSkippedKey) ?? false;
  }

  @override
  Future<void> setSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_skippedKey, true);
    if (_userSkippedKey != _skippedKey) {
      await prefs.setBool(_userSkippedKey, true);
    }
  }

  @override
  Future<void> clearSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_skippedKey);
    if (_userSkippedKey != _skippedKey) {
      await prefs.remove(_userSkippedKey);
    }
  }

  @override
  Future<bool> hasVehicle() async {
    final vehicles = await _vehiculos.getVehiculos();
    return vehicles.isNotEmpty;
  }

  @override
  Future<bool> hasRequest() async {
    final requests = await _solicitudes.obtenerSolicitudesCliente(
      _auth.currentUser?.id ?? '',
    );
    return requests.isNotEmpty;
  }
}
