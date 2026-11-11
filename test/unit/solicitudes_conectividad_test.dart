import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repuestosya/database/app_database.dart';
import 'package:repuestosya/providers/solicitudes_provider.dart';
import 'package:repuestosya/services/solicitud_repository.dart';

import '../helpers/fake_connectivity.dart';

/// Pipeline REAL de red: plataforma de connectivity_plus → SolicitudRepository
/// (watchOffline) → SolicitudesProvider.isOffline. Sin dobles en el medio.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> esperar() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  test(
    'airplane mode (none) pone isOffline en true sin pull-to-refresh',
    () async {
      final conectividad = FakeConnectivityPlatform();
      ConnectivityPlatform.instance = conectividad;
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final provider = SolicitudesProvider(SolicitudRepository(db));
      addTearDown(provider.dispose);
      await esperar();
      expect(provider.isOffline, isFalse);

      conectividad.emitir([ConnectivityResult.none]);
      await esperar();

      expect(provider.isOffline, isTrue);
    },
  );

  test('recuperar la red quita isOffline automáticamente', () async {
    final conectividad = FakeConnectivityPlatform();
    ConnectivityPlatform.instance = conectividad;
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final provider = SolicitudesProvider(SolicitudRepository(db));
    addTearDown(provider.dispose);
    await esperar();

    conectividad.emitir([ConnectivityResult.none]);
    await esperar();
    expect(provider.isOffline, isTrue);

    conectividad.emitir([ConnectivityResult.wifi]);
    await esperar();

    expect(provider.isOffline, isFalse);
  });
}
