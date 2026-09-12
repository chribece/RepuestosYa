import 'auth_service.dart';
import 'auth_session_repository.dart';
import 'profile_repository.dart';

abstract class UserRoleRepository {
  User? get currentUser;
  Stream<AuthState> get authStateChanges;
  Future<String?> getUserRole(String userId);
}

class UserRoleRepositoryImpl implements UserRoleRepository {
  final AuthSessionRepository _session;
  final ProfileRepository _profile;

  UserRoleRepositoryImpl({
    AuthSessionRepository? session,
    ProfileRepository? profile,
  }) : _session = session ?? AuthSessionRepositoryImpl(),
       _profile = profile ?? ProfileRepositoryImpl();

  @override
  User? get currentUser => _session.currentUser;

  @override
  Stream<AuthState> get authStateChanges => _session.authStateChanges;

  @override
  Future<String?> getUserRole(String userId) {
    return _profile.getUserRole(userId);
  }
}
