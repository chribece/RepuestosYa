import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/services/sync_engine.dart';
import 'package:repuestosya/utils/api_error_handler.dart';

/// Clasificación red vs negocio del [SyncEngine] (riesgo R08 de
/// docs/TESTING.md): decide si un item de Outbox se reintenta (FAILED,
/// transitorio) o agota intentos hasta DEAD (permanente).
void main() {
  group('SyncEngine.esErrorDeRed', () {
    test('ApiException sin statusCode (timeout/no respuesta) → red', () {
      expect(
        SyncEngine.esErrorDeRed(const ApiException('sin respuesta')),
        isTrue,
      );
    });

    test('ApiException con statusCode 0 → red', () {
      expect(
        SyncEngine.esErrorDeRed(const ApiException('x', statusCode: 0)),
        isTrue,
      );
    });

    test('ApiException 504 (gateway timeout) → red', () {
      expect(
        SyncEngine.esErrorDeRed(const ApiException('x', statusCode: 504)),
        isTrue,
      );
    });

    test('errores de negocio 4xx/5xx → NO red (agotan hasta DEAD)', () {
      expect(
        SyncEngine.esErrorDeRed(const ApiException('x', statusCode: 400)),
        isFalse,
      );
      expect(
        SyncEngine.esErrorDeRed(const ApiException('x', statusCode: 422)),
        isFalse,
      );
      expect(
        SyncEngine.esErrorDeRed(const ApiException('x', statusCode: 500)),
        isFalse,
      );
    });

    test('401 → NO red (es un error de sesión permanente, no transitorio)', () {
      expect(
        SyncEngine.esErrorDeRed(const ApiException('x', statusCode: 401)),
        isFalse,
      );
    });

    test('SocketException → red', () {
      expect(SyncEngine.esErrorDeRed(const SocketException('refused')), isTrue);
    });

    test('TimeoutException → red', () {
      expect(SyncEngine.esErrorDeRed(TimeoutException('t')), isTrue);
    });

    test('excepción arbitraria (imagen no encontrada) → NO red', () {
      expect(
        SyncEngine.esErrorDeRed(Exception('imagen local no encontrada')),
        isFalse,
      );
    });
  });
}
