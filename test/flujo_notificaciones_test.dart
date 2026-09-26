import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:repuestosya/widgets/flujo_notificaciones.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Valida el flujo de permiso de notificaciones compartido
/// (`solicitarPermisoNotificaciones`), usado por el home del cliente y el
/// dashboard del almacén: rationale previo ANTES del popup nativo, mensaje
/// específico por rol, manejo de los 4 estados (concedido / denegado con
/// reintento / denegado permanente → Ajustes / restringido) y sin propagar
/// errores.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String mensajeCliente =
      'RepuestosYa te avisa al instante cuando un almacén responde tu '
      'solicitud con una cotización o cuando cambia el estado de tu orden de '
      'compra. ¿Permites las notificaciones?';
  const String mensajeAlmacen =
      'RepuestosYa te avisa al instante cuando un cliente publica una nueva '
      'solicitud de repuesto o acepta tu cotización. ¿Permites las '
      'notificaciones?';

  late _FakePermissionHandler permisos;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    permisos = _FakePermissionHandler(PermissionStatus.denied);
    PermissionHandlerPlatform.instance = permisos;
  });

  Future<void> pumpBotonPedirPermiso(
    WidgetTester tester, {
    required String mensaje,
    Future<PermissionStatus> Function()? requestPermiso,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => solicitarPermisoNotificaciones(
                context,
                mensaje: mensaje,
                requestPermiso: requestPermiso,
              ),
              child: const Text('pedir'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> confirmarRationale(WidgetTester tester) async {
    // El rationale aparece ANTES del popup nativo.
    expect(find.text('Permiso de notificaciones'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
  }

  testWidgets('cliente: muestra su rationale específico ANTES del popup '
      'nativo', (tester) async {
    await pumpBotonPedirPermiso(tester, mensaje: mensajeCliente);
    await tester.tap(find.text('pedir'));
    await tester.pumpAndSettle();

    expect(find.text(mensajeCliente), findsOneWidget);
    await confirmarRationale(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('almacén: muestra su rationale específico ANTES del popup '
      'nativo', (tester) async {
    await pumpBotonPedirPermiso(tester, mensaje: mensajeAlmacen);
    await tester.tap(find.text('pedir'));
    await tester.pumpAndSettle();

    expect(find.text(mensajeAlmacen), findsOneWidget);
    await confirmarRationale(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rationale declinado ("Ahora no") → cancela sin pedir el '
      'permiso', (tester) async {
    await pumpBotonPedirPermiso(tester, mensaje: mensajeCliente);
    await tester.tap(find.text('pedir'));
    await tester.pumpAndSettle();

    expect(find.text('Permiso de notificaciones'), findsOneWidget);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permiso ya concedido → no muestra ningún diálogo', (
    tester,
  ) async {
    permisos.estado = PermissionStatus.granted;

    await pumpBotonPedirPermiso(tester, mensaje: mensajeCliente);
    await tester.tap(find.text('pedir'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Permiso de notificaciones'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permanentlyDenied → diálogo "Notificaciones bloqueadas" con '
      'Abrir Ajustes (sin reintento)', (tester) async {
    permisos.estado = PermissionStatus.permanentlyDenied;

    await pumpBotonPedirPermiso(
      tester,
      mensaje: mensajeCliente,
      requestPermiso: () async => PermissionStatus.permanentlyDenied,
    );
    await tester.tap(find.text('pedir'));
    await tester.pumpAndSettle();
    await confirmarRationale(tester);

    // Sin diálogo de reintento: directamente a Ajustes.
    expect(find.text('Notificaciones bloqueadas'), findsOneWidget);
    expect(find.text('Abrir Ajustes'), findsOneWidget);

    await tester.tap(find.text('Abrir Ajustes'));
    await tester.pumpAndSettle();
    expect(permisos.settingsCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('doble rechazo → reintento → llega al diálogo de Ajustes', (
    tester,
  ) async {
    var llamadas = 0;

    await pumpBotonPedirPermiso(
      tester,
      mensaje: mensajeCliente,
      requestPermiso: () async {
        llamadas++;
        return PermissionStatus.denied;
      },
    );
    await tester.tap(find.text('pedir'));
    await tester.pumpAndSettle();
    await confirmarRationale(tester);

    // Primer rechazo: diálogo de contexto con reintento.
    expect(
      find.textContaining('¿Quieres intentarlo de nuevo?'),
      findsOneWidget,
    );
    expect(llamadas, 1);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    // Segundo rechazo: Android 11+ auto-denegará → única vía es Ajustes.
    expect(llamadas, 2);
    expect(find.text('Notificaciones bloqueadas'), findsOneWidget);

    await tester.tap(find.text('Abrir Ajustes'));
    await tester.pumpAndSettle();
    expect(permisos.settingsCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reintento concedido → no muestra diálogo de Ajustes', (
    tester,
  ) async {
    var llamadas = 0;

    await pumpBotonPedirPermiso(
      tester,
      mensaje: mensajeCliente,
      requestPermiso: () async {
        llamadas++;
        return llamadas == 1
            ? PermissionStatus.denied
            : PermissionStatus.granted;
      },
    );
    await tester.tap(find.text('pedir'));
    await tester.pumpAndSettle();
    await confirmarRationale(tester);

    expect(
      find.textContaining('¿Quieres intentarlo de nuevo?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(llamadas, 2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(permisos.settingsCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restringido → mensaje informativo, sin Ajustes', (tester) async {
    permisos.estado = PermissionStatus.restricted;

    await pumpBotonPedirPermiso(
      tester,
      mensaje: mensajeCliente,
      requestPermiso: () async => PermissionStatus.restricted,
    );
    await tester.tap(find.text('pedir'));
    await tester.pumpAndSettle();
    await confirmarRationale(tester);

    expect(find.text('Notificaciones no disponibles'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(permisos.settingsCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el rationale solo se muestra una vez (bandera persistida)', (
    tester,
  ) async {
    await pumpBotonPedirPermiso(tester, mensaje: mensajeCliente);

    // Primera invocación: aparece el rationale.
    await tester.tap(find.text('pedir'));
    await tester.pumpAndSettle();
    expect(find.text('Permiso de notificaciones'), findsOneWidget);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();

    // Segunda invocación: la bandera ya está persistida → sin rationale.
    await tester.tap(find.text('pedir'));
    await tester.pumpAndSettle();
    expect(find.text('Permiso de notificaciones'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// Fake de la plataforma de permisos: evita el canal nativo y cuenta las
/// llamadas a `openAppSettings` (mismo patrón que
/// `test/ry_image_picker_camera_test.dart`).
class _FakePermissionHandler extends PermissionHandlerPlatform {
  _FakePermissionHandler(this.estado);

  PermissionStatus estado;
  int settingsCalls = 0;

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      estado;

  @override
  Future<bool> openAppSettings() async {
    settingsCalls++;
    return true;
  }
}
