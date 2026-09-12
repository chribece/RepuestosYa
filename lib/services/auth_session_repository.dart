import 'auth_service.dart';

abstract class AuthSessionRepository {
  User? get currentUser;
  Stream<AuthState> get authStateChanges;
}

class AuthSessionRepositoryImpl implements AuthSessionRepository {
  final AuthService _auth;

  AuthSessionRepositoryImpl({AuthService? auth})
    : _auth = auth ?? AuthService();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Stream<AuthState> get authStateChanges => _auth.authStateChanges;
}
