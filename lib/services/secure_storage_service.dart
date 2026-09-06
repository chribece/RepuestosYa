import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(),
  );

  static const String _tokenKey = 'repuestosya_auth_token';
  static const String _refreshTokenKey = 'repuestosya_refresh_token';
  static const String _userIdKey = 'repuestosya_user_id';
  static const String _userRoleKey = 'repuestosya_user_role';

  // Singleton implementation
  SecureStorageService._privateConstructor();
  static final SecureStorageService _instance =
      SecureStorageService._privateConstructor();
  factory SecureStorageService() => _instance;

  Future<void> saveToken(String token, {String? refreshToken}) async {
    await _storage.write(key: _tokenKey, value: token);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<String?> readToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<String?> readRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> saveUser(String userId, String userRole) async {
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _userRoleKey, value: userRole);
  }

  Future<Map<String, String?>> readUser() async {
    final userId = await _storage.read(key: _userIdKey);
    final userRole = await _storage.read(key: _userRoleKey);
    return {'user_id': userId, 'user_role': userRole};
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
