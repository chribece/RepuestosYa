import 'profile_service.dart';

abstract class ProfileRepository {
  Future<String?> getUserRole(String userId);
}

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileService _remote;

  ProfileRepositoryImpl({ProfileService? remote})
    : _remote = remote ?? ProfileService();

  @override
  Future<String?> getUserRole(String userId) {
    return _remote.getUserRole(userId);
  }
}
