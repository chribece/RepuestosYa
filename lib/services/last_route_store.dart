import 'package:shared_preferences/shared_preferences.dart';

/// Recuerda la última pantalla privada visitada para reabrirla al reiniciar la
/// app. Se carga una vez antes de `runApp` (el router necesita el valor de
/// forma síncrona) y se restaura una sola vez por arranque.
class LastRouteStore {
  static const _key = 'last_private_route';
  static String? _cached;
  static bool _pendingRestore = false;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _cached = prefs.getString(_key);
    _pendingRestore = _cached != null;
  }

  /// Devuelve la ruta guardada solo la primera vez tras el arranque.
  static String? takeRestorable() {
    if (!_pendingRestore) return null;
    _pendingRestore = false;
    return _cached;
  }

  static void save(String location) {
    if (location == _cached) return;
    _cached = location;
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_key, location),
    );
  }

  static Future<void> clear() async {
    _cached = null;
    _pendingRestore = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
