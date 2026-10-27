import 'package:flutter/foundation.dart';

import '../services/almacen_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

class ProfileImageProvider extends ChangeNotifier {
  final AuthService _authService;
  final ProfileService _profileService;
  final AlmacenService _warehouseService;

  ProfileImageProvider({
    AuthService? authService,
    ProfileService? profileService,
    AlmacenService? warehouseService,
  }) : _authService = authService ?? AuthService(),
       _profileService = profileService ?? ProfileService(),
       _warehouseService = warehouseService ?? AlmacenService();

  String? _imageUrl;
  String? _userId;
  bool _hasLoaded = false;
  bool _isLoading = false;
  int _loadGeneration = 0;

  String? get imageUrl => _imageUrl;
  bool get isLoading => _isLoading;

  Future<void> loadForCurrentUser() async {
    final user = _authService.currentUser;
    if (user == null) {
      _loadGeneration++;
      if (_userId != null || _imageUrl != null || _isLoading) {
        _userId = null;
        _imageUrl = null;
        _hasLoaded = false;
        _isLoading = false;
        notifyListeners();
      }
      return;
    }

    if (_userId == user.id && (_hasLoaded || _isLoading)) return;

    final generation = ++_loadGeneration;
    _userId = user.id;
    _imageUrl = null;
    _hasLoaded = false;
    _isLoading = true;
    notifyListeners();

    String? imageUrl;
    try {
      if (user.rol == 'almacen' || user.rol == 'warehouse') {
        final warehouse = await _warehouseService.obtenerMiAlmacen();
        imageUrl = warehouse?['logo_url']?.toString();
      } else {
        final profile = await _profileService.getUserProfile(user.id);
        imageUrl = profile?['avatar_url']?.toString();
      }
    } catch (_) {
      // The home avatar is decorative; keep the role-specific fallback on error.
    }

    if (generation != _loadGeneration) return;
    if (_authService.currentUser?.id != user.id) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _imageUrl = _normalizedUrl(imageUrl);
    _hasLoaded = true;
    _isLoading = false;
    notifyListeners();
  }

  void setImageUrl(String? imageUrl, {required String userId}) {
    final currentUser = _authService.currentUser;
    if (currentUser != null && currentUser.id != userId) return;

    _loadGeneration++;
    _userId = userId;
    _imageUrl = _normalizedUrl(imageUrl);
    _hasLoaded = true;
    _isLoading = false;
    notifyListeners();
  }

  String? _normalizedUrl(String? url) {
    final normalized = url?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
