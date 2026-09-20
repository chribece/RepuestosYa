import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:repuestosya/widgets/ry_image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Valida el flujo de cámara del widget COMPARTIDO `RyImagePicker`, el mismo
/// que usan la solicitud del cliente (create_request_page) y la cotización
/// del almacén (create_quotation_page): el manejo de permisos (request
/// primero, reintento, Abrir Ajustes) es idéntico en ambos.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePermissionHandler permisos;
  late _FakeImagePicker picker;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    permisos = _FakePermissionHandler(PermissionStatus.denied);
    picker = _FakeImagePicker();
    PermissionHandlerPlatform.instance = permisos;
    ImagePickerPlatform.instance = picker;
  });

  Future<void> abrirCamara(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RyImagePicker(onImageSelected: (_) {}, onRemove: () {}),
        ),
      ),
    );
    // Abrir el bottom sheet de opciones y elegir "Cámara".
    await tester.tap(find.byType(RyImagePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cámara'));
    await tester.pumpAndSettle();
    // Rationale previo (antes del popup nativo): confirmar para continuar.
    expect(find.text('Entendido'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
  }

  testWidgets('denegado → request() → concedido → abre la cámara', (
    tester,
  ) async {
    permisos.respuestaRequest = {Permission.camera: PermissionStatus.granted};

    await abrirCamara(tester);

    // Se pidió el permiso una vez y se abrió la cámara (pickImage).
    expect(permisos.requestCalls, 1);
    expect(picker.llamadasCamara, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('bloqueo permanente → diálogo "Permiso de cámara bloqueado" '
      'con Abrir Ajustes (sin abrir la cámara)', (tester) async {
    permisos.estado = PermissionStatus.permanentlyDenied;
    permisos.respuestaRequest = {
      Permission.camera: PermissionStatus.permanentlyDenied,
    };

    await abrirCamara(tester);

    expect(find.text('Permiso de cámara bloqueado'), findsOneWidget);
    expect(find.text('Abrir Ajustes'), findsOneWidget);
    expect(picker.llamadasCamara, 0);
  });

  testWidgets('doble rechazo → reintento → llega al diálogo de Ajustes', (
    tester,
  ) async {
    permisos.respuestaRequest = {Permission.camera: PermissionStatus.denied};

    await abrirCamara(tester);

    // Primer rechazo: diálogo de contexto con reintento.
    expect(
      find.textContaining('¿Quieres intentarlo de nuevo?'),
      findsOneWidget,
    );
    expect(picker.llamadasCamara, 0);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    // Segundo rechazo: Android 11+ auto-denegará → única vía es Ajustes.
    expect(permisos.requestCalls, 2);
    expect(find.text('Permiso de cámara bloqueado'), findsOneWidget);
    expect(picker.llamadasCamara, 0);
  });
}

/// Fake de la plataforma de permisos: estado configurable y respuestas de
/// `request()` por test. Evita el canal nativo.
class _FakePermissionHandler extends PermissionHandlerPlatform {
  _FakePermissionHandler(this.estado);

  PermissionStatus estado;
  Map<Permission, PermissionStatus> respuestaRequest = {};
  int requestCalls = 0;
  int settingsCalls = 0;

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      estado;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    requestCalls++;
    if (respuestaRequest.isEmpty) {
      return {for (final p in permissions) p: PermissionStatus.granted};
    }
    return respuestaRequest;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsCalls++;
    return true;
  }
}

/// Fake de la plataforma de image_picker: registra los intentos de cámara
/// (y galería) sin abrir el sistema.
class _FakeImagePicker extends ImagePickerPlatform {
  int llamadasCamara = 0;
  int llamadasGaleria = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    if (source == ImageSource.camera) llamadasCamara++;
    if (source == ImageSource.gallery) llamadasGaleria++;
    return null; // el usuario cancela: flujo normal sin imagen
  }
}
