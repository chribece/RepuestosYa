import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/pages/create_quotation_page.dart';
import 'package:repuestosya/theme/app_theme.dart';

import '../helpers/fake_services.dart';

void main() {
  testWidgets(
    'la ruta de cotizar con solo solicitudId carga y muestra la ficha técnica',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final solicitud = FakeSolicitudService()
        ..respuestaSolicitudPorId = {
          'id': 'solicitud-desde-notificacion',
          'pieza_nombre': 'Alternador',
          'descripcion': 'Ruido y pérdida de carga',
          'vin_busqueda': '1HGCM82633A004352',
          'vehiculos_cliente': {
            'año': 2018,
            'vin': '1HGCM82633A004352',
            'modelos_vehiculo': {
              'nombre': 'Civic',
              'marcas_vehiculo': {'nombre': 'Honda'},
            },
          },
          'latitud_entrega': -0.18,
          'longitud_entrega': -78.47,
          'direcciones_entrega': {
            'latitude': -0.18,
            'longitude': -78.47,
            'calle_principal': 'Av. Amazonas',
          },
        };
      final almacen = FakeAlmacenService()
        ..respuestaMiAlmacen = {
          'id': 'almacen-1',
          'nombre_comercial': 'Repuestos Central',
          'verification_status': 'approved',
          'latitude': -0.18,
          'longitude': -78.47,
        };

      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: CreateQuotationPage(
            solicitud: const {'id': 'solicitud-desde-notificacion'},
            solicitudService: solicitud,
            almacenService: almacen,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(solicitud.obtenerSolicitudPorIdCalls, 1);
      expect(
        solicitud.ultimaSolicitudConsultada,
        'solicitud-desde-notificacion',
      );
      expect(find.text('FICHA TÉCNICA DEL VEHÍCULO'), findsOneWidget);
      expect(find.text('Honda'), findsOneWidget);
      expect(find.text('Civic'), findsOneWidget);
      expect(find.text('2018'), findsOneWidget);
      expect(find.text('1HGCM82633A004352'), findsOneWidget);
    },
  );
}
