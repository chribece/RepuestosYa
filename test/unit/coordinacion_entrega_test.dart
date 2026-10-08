import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/models/coordinacion_entrega.dart';

/// Pruebas del modelo de coordinación de entrega: construcción desde la
/// respuesta de aceptación, desde el mapa de una cotización (GET) y el
/// respaldo desde la tarjeta local. Cubre el caso real de PostgREST donde
/// `precio_venta` (numeric) llega serializado como STRING.
void main() {
  final cotizacionAceptada = <String, dynamic>{
    'id': 'cot-1',
    'estado': 'aceptada',
    // PostgREST serializa numeric como string en JSON.
    'precio_venta': '45.50',
    'almacenes': {
      'nombre_comercial': 'Repuestos Central',
      'telefono': '0991234567',
      'email': 'contacto@repuestoscentral.com',
    },
    'solicitudes_repuesto': {
      'pieza_nombre': 'Filtro de aceite',
      'repuesto_nombre_snapshot': 'Filtro de aceite Mann',
    },
  };

  group('fromCotizacionMap', () {
    test('cotización aceptada con precio como STRING → parsea 45.5', () {
      final datos = DatosCoordinacionEntrega.fromCotizacionMap(
        cotizacionAceptada,
        solicitudId: 's1',
      );

      expect(datos, isNotNull);
      expect(datos!.almacenNombre, 'Repuestos Central');
      expect(datos.telefono, '0991234567');
      expect(datos.email, 'contacto@repuestoscentral.com');
      expect(datos.repuestoNombre, 'Filtro de aceite Mann');
      expect(datos.precioVenta, 45.5);
      expect(datos.solicitudId, 's1');
      expect(datos.cotizacionId, 'cot-1');
    });

    test('cotización pendiente → null (solo la GANADA expone contacto)', () {
      final datos = DatosCoordinacionEntrega.fromCotizacionMap({
        ...cotizacionAceptada,
        'estado': 'pendiente',
      }, solicitudId: 's1');
      expect(datos, isNull);
    });

    test('precio como num también se parsea', () {
      final datos = DatosCoordinacionEntrega.fromCotizacionMap({
        ...cotizacionAceptada,
        'precio_venta': 89.0,
      }, solicitudId: 's1');
      expect(datos!.precioVenta, 89.0);
    });
  });

  group('desdeTarjetaLocal', () {
    test('construye sin validar estado (tarjeta aún en pendiente)', () {
      final tarjetaPendiente = {
        'id': 'cot-1',
        'precio_venta': 45.5,
        'almacenes': {'nombre_comercial': 'Repuestos Central'},
      };
      final datos = DatosCoordinacionEntrega.desdeTarjetaLocal(
        tarjetaPendiente,
        solicitudId: 's1',
      );
      expect(datos, isNotNull);
      expect(datos!.almacenNombre, 'Repuestos Central');
      expect(datos.precioVenta, 45.5);
      expect(datos.telefono, isNull);
    });

    test('sin bloque almacenes → null', () {
      final datos = DatosCoordinacionEntrega.desdeTarjetaLocal({
        'id': 'cot-1',
        'precio_venta': 10.0,
      }, solicitudId: 's1');
      expect(datos, isNull);
    });
  });

  group('fromAceptacionResponse', () {
    test('respuesta con bloque almacen → datos completos', () {
      final datos = DatosCoordinacionEntrega.fromAceptacionResponse(
        {
          'success': true,
          'ordenId': 'ord-1',
          'almacen': {
            'nombre': 'Repuestos Central',
            'telefono': '0991234567',
            'email': 'contacto@repuestoscentral.com',
          },
          'repuestoNombre': 'Filtro de aceite',
          'precioVenta': 45.5,
        },
        cotizacionId: 'cot-1',
        solicitudId: 's1',
      );

      expect(datos, isNotNull);
      expect(datos!.almacenNombre, 'Repuestos Central');
      expect(datos.telefono, '0991234567');
      expect(datos.precioVenta, 45.5);
    });

    test('respuesta SIN bloque almacen (backend antiguo) → null', () {
      final datos = DatosCoordinacionEntrega.fromAceptacionResponse(
        {'success': true, 'ordenId': 'ord-1'},
        cotizacionId: 'cot-1',
        solicitudId: 's1',
      );
      expect(datos, isNull);
    });
  });

  group('serialización (caché local)', () {
    test('toJson → fromJson round trip conserva todo', () {
      final original = DatosCoordinacionEntrega(
        solicitudId: 's1',
        cotizacionId: 'cot-1',
        almacenNombre: 'Repuestos Central',
        telefono: '0991234567',
        email: 'contacto@repuestoscentral.com',
        repuestoNombre: 'Filtro de aceite',
        precioVenta: 45.5,
      );

      final reconstruido = DatosCoordinacionEntrega.fromJson(original.toJson());

      expect(reconstruido.solicitudId, 's1');
      expect(reconstruido.cotizacionId, 'cot-1');
      expect(reconstruido.almacenNombre, 'Repuestos Central');
      expect(reconstruido.telefono, '0991234567');
      expect(reconstruido.email, 'contacto@repuestoscentral.com');
      expect(reconstruido.repuestoNombre, 'Filtro de aceite');
      expect(reconstruido.precioVenta, 45.5);
    });

    test('precioFormateado usa 2 decimales', () {
      final datos = DatosCoordinacionEntrega(
        solicitudId: 's1',
        cotizacionId: 'c1',
        almacenNombre: 'A',
        repuestoNombre: 'R',
        precioVenta: 45.5,
      );
      expect(datos.precioFormateado, '\$45.50');
    });
  });
}
