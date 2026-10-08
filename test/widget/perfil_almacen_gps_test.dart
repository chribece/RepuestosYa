import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repuestosya/pages/perfil_almacen_page.dart';
import 'package:repuestosya/services/almacen_service.dart';
import 'package:repuestosya/services/geocoding_service.dart';
import 'package:repuestosya/services/ubicacion_service.dart';

/// Dobles de los servicios del perfil de almacén (sin red ni GPS reales).
class _FakeAlmacenService extends AlmacenService {
  _FakeAlmacenService() : super(null);

  int llamadasMiAlmacen = 0;

  @override
  Future<Map<String, dynamic>?> obtenerMiAlmacen() async {
    llamadasMiAlmacen++;
    return {
      'id': 'a-1',
      'nombre_comercial': 'Repuestos Central',
      'ruc': '1790000000001',
      'telefono': '0991234567',
      'direccion_texto': '',
      'latitude': 0,
      'longitude': 0,
      'verification_status': 'approved',
      'estado_abierto': true,
    };
  }

  @override
  Future<Map<String, dynamic>> actualizarAlmacen(
    String id,
    Map<String, dynamic> data,
  ) async {
    return {'id': id, ...data};
  }
}

class _FakeUbicacionService extends UbicacionService {
  int llamadas = 0;

  @override
  Future<UbicacionResultado> obtenerUbicacion({
    int intentos = UbicacionService.maxIntentos,
  }) async {
    llamadas++;
    return const UbicacionResultado.ok(-0.1913664, -78.4930512);
  }
}

class _FakeGeocodingService extends GeocodingService {
  @override
  Future<DireccionAutocompletada?> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    return const DireccionAutocompletada(
      callePrincipal: 'Av. Amazonas y Naciones Unidas',
      referencia: 'Frente al parque',
    );
  }
}

void main() {
  late _FakeAlmacenService almacen;
  late _FakeUbicacionService ubicacion;
  late _FakeGeocodingService geocoding;

  setUp(() {
    // El rationale de ubicación ya fue visto: el flujo GPS no muestra el
    // diálogo previo en el test.
    SharedPreferences.setMockInitialValues({'rationale_ubicacion': true});
    almacen = _FakeAlmacenService();
    ubicacion = _FakeUbicacionService();
    geocoding = _FakeGeocodingService();
  });

  Future<void> pumpPerfil(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: PerfilAlmacenPage(
          almacenService: almacen,
          ubicacionService: ubicacion,
          geocodingService: geocoding,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    '"Usar mi ubicación actual" fija lat/lng y autocompleta la dirección '
    'del almacén (mismo flujo GPS que la solicitud)',
    (tester) async {
      await pumpPerfil(tester);

      expect(almacen.llamadasMiAlmacen, 1);
      // Aparece en el encabezado y en el campo "Nombre Comercial".
      expect(find.text('Repuestos Central'), findsWidgets);

      // Entrar en modo edición para que aparezca el botón GPS.
      await tester.tap(find.text('Editar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Usar mi ubicación actual'), findsOneWidget);
      await tester.tap(find.text('Usar mi ubicación actual'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // El GPS se consultó y la dirección se autocompletó por reverse
      // geocoding (no se pisa texto previo: el almacén no tenía dirección).
      expect(ubicacion.llamadas, 1);
      expect(
        find.text('Av. Amazonas y Naciones Unidas, Frente al parque'),
        findsOneWidget,
      );

      // Las coordenadas quedaron fijadas en los campos de lat/lng.
      expect(find.text('-0.191366'), findsOneWidget);
      expect(find.text('-78.493051'), findsOneWidget);
    },
  );

  testWidgets('el botón GPS solo está disponible en modo edición', (
    tester,
  ) async {
    await pumpPerfil(tester);

    // Modo lectura: sin botón.
    expect(find.text('Usar mi ubicación actual'), findsNothing);

    await tester.tap(find.text('Editar'));
    await tester.pump();
    expect(find.text('Usar mi ubicación actual'), findsOneWidget);
  });
}
