import 'package:flutter/foundation.dart';
import '../services/onboarding_repository.dart';

class OnboardingProvider with ChangeNotifier {
  static const String skippedKey = 'onboarding_skipped';

  final OnboardingRepository _repository;

  OnboardingProvider({OnboardingRepository? repository})
    : _repository = repository ?? OnboardingRepositoryImpl();

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
      _isSkipped = await _repository.isSkipped();

      final results = await Future.wait([
        _repository.hasVehicle(),
        _repository.hasRequest(),
      ]);

      _hasVehicle = results[0];
      _hasRequest = results[1];
    } catch (e) {
      _errorMessage = 'No se pudo cargar el estado del onboarding.';
    } finally {
      _isLoadingVehicle = false;
      _isLoadingRequest = false;
      notifyListeners();
    }
  }

  Future<void> skip() async {
    await _repository.setSkipped();
    _isSkipped = true;
    notifyListeners();
  }

  Future<void> reset() async {
    await _repository.clearSkipped();
    _isSkipped = false;
    _hasVehicle = false;
    _hasRequest = false;
    _errorMessage = null;
    notifyListeners();
  }
}
