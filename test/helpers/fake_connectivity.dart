import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';

/// Doble de la plataforma de conectividad: reemplaza el canal nativo en
/// widget tests (sin red real) y permite scriptear el estado de red y emitir
/// transiciones offline → online.
class FakeConnectivityPlatform extends ConnectivityPlatform {
  FakeConnectivityPlatform([
    List<ConnectivityResult> results = const [ConnectivityResult.wifi],
  ]) : _results = results;

  List<ConnectivityResult> _results;
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  int llamadasCheck = 0;

  set resultados(List<ConnectivityResult> value) => _results = value;

  void emitir(List<ConnectivityResult> value) => _controller.add(value);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    llamadasCheck++;
    return _results;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;
}
