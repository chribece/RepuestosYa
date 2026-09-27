import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:repuestosya/models/part_catalog.dart';
import 'package:repuestosya/services/almacen_service.dart';
import 'package:repuestosya/services/auth_service.dart';
import 'package:repuestosya/services/catalog_service.dart';
import 'package:repuestosya/services/direccion_service.dart';
import 'package:repuestosya/services/marca_service.dart';
import 'package:repuestosya/services/modelo_service.dart';
import 'package:repuestosya/services/solicitud_service.dart';
import 'package:repuestosya/services/vehiculo_service.dart';

/// ÚNICA prueba E2E (Fase 5 de docs/TESTING.md): el recorrido crítico del
/// negocio contra el backend REAL (Express + Supabase) desde el dispositivo:
///
///   cliente crea una solicitud → almacén cotiza esa solicitud →
///   cliente acepta la cotización → se genera la orden.
///
/// Decide y documenta (docs/TESTING.md §5): corre contra el backend local de
/// desarrollo (192.168.100.2:3000, el mismo que la app usa por defecto) con
/// datos de prueba — el cliente es una cuenta EFÍMERA por corrida y el
/// almacén es un fixture pre-aprobado (la aprobación es acción de admin, no
/// parte del recorrido del usuario).
///
/// Se corre SOLO en dispositivo físico (nunca emulador):
///   flutter test integration_test/ -d T10MPROPLUS00342411
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'recorrido crítico: solicitud → cotización → aceptar → orden generada',
    (tester) async {
      // Fixture de DESARROLLO (TEST-ONLY): cuenta `almacen.e2e@repuestosya.test`
      // creada por backend/scripts/e2e_fixture.js contra el backend local +
      // Supabase de desarrollo. No es una credencial de producción: solo da
      // acceso a un almacén de prueba aprobado. Los --dart-define no llegan
      // al integration_test en dispositivos (quirk de Flutter 3.44), por lo
      // que la contraseña del fixture es una constante documentada.
      const almacenEmail = 'almacen.e2e@repuestosya.test';
      const almacenPassword = 'E2e-Almacen-Fixture-2026!';

      final auth = AuthService();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final clienteEmail = 'e2e.cliente.$stamp@repuestosya.test';
      const clientePassword = 'Cliente-E2E-2026!';

      // 1) Registro del cliente (cuenta efímera, única por corrida).
      final registro = await auth.signUpWithEmailAndPassword(
        email: clienteEmail,
        password: clientePassword,
        nombreCompleto: 'Cliente E2E',
        rol: 'cliente',
      );
      expect(registro.user.rol, 'cliente');
      expect(registro.user.id, isNotEmpty);

      // 2) Vehículo del cliente (catálogo real de marcas/modelos).
      final marcas = await MarcaService().getMarcas();
      expect(marcas, isNotEmpty, reason: 'El catálogo de marcas está vacío');
      final marcaId = int.parse(marcas.first['id'].toString());
      final modelos = await ModeloService().getModelosPorMarca(marcaId);
      expect(modelos, isNotEmpty, reason: 'La marca no tiene modelos');
      final modeloId = int.parse(modelos.first['id'].toString());
      final vehiculo = await VehiculoService().createVehiculo(
        marcaId: marcaId,
        modeloId: modeloId,
        anio: '2020',
        vin: 'E2E$stamp',
      );
      // /vehicles responde envuelto {exito, datos} (inconsistencia B6) a
      // diferencia de /addresses (fila directa): se lee el id robustamente.
      final vehiculoId =
          (vehiculo['datos'] as Map<String, dynamic>?)?['id']?.toString() ??
          vehiculo['id']?.toString();
      expect(vehiculoId, isNotEmpty, reason: 'El vehículo no devolvió id');

      // 3) Dirección de entrega con coordenadas (Quito).
      final direccion = await DireccionService().createDireccion(
        alias: 'Casa E2E',
        callePrincipal: 'Av. Amazonas y Naciones Unidas',
        latitude: -0.1807,
        longitude: -78.4678,
        coordenadasFuente: 'gps',
      );
      final direccionId = direccion['id'].toString();
      expect(direccionId, isNotEmpty, reason: 'La dirección no devolvió id');

      // 4) Categoría + repuesto del catálogo real. Algunas categorías están
      // vacías: se elige la primera que tenga repuestos.
      final categorias = await CatalogService().getPartCategories();
      expect(
        categorias,
        isNotEmpty,
        reason: 'El catálogo de categorías está vacío',
      );
      PartCategory? categoria;
      CatalogPart? repuesto;
      for (final c in categorias) {
        final parts = await CatalogService().getParts(categoryId: c.id);
        if (parts.isNotEmpty) {
          categoria = c;
          repuesto = parts.first;
          break;
        }
      }
      expect(
        categoria,
        isNotNull,
        reason: 'Ninguna categoría del catálogo tiene repuestos',
      );
      final categoriaSeleccionada = categoria!;
      final repuestoSeleccionado = repuesto!;

      // 5) El cliente crea la solicitud.
      final solicitudResp = await SolicitudService().crearSolicitud(
        clienteId: registro.user.id,
        vehiculoId: vehiculoId,
        piezaNombre: repuestoSeleccionado.nombre,
        descripcion: 'Solicitud generada por el E2E (recorrido crítico)',
        direccionEntregaId: direccionId,
        esUrgente: false,
        categoriaId: categoriaSeleccionada.id,
        repuestoId: repuestoSeleccionado.id,
        repuestoNombreSnapshot: repuestoSeleccionado.nombre,
        descripcionProblema:
            'Falla al frenar — solicitud E2E del recorrido crítico',
        latitude: -0.1807,
        longitude: -78.4678,
        coordenadasFuente: 'gps',
      );
      final solicitudId = solicitudResp['id'].toString();
      expect(solicitudId, isNotEmpty, reason: 'La solicitud no devolvió id');

      // 6) Login del almacén fixture (aprobado) y cotización de la solicitud.
      final loginAlmacen = await auth.signInWithEmailAndPassword(
        email: almacenEmail,
        password: almacenPassword,
      );
      expect(loginAlmacen.user.rol, 'almacen');

      final miAlmacen = await AlmacenService().obtenerMiAlmacen();
      final almacenId = miAlmacen?['id']?.toString();
      expect(
        almacenId,
        isNotNull,
        reason: 'El almacén fixture no devolvió id (¿está aprobado?)',
      );

      final cotizacion = await SolicitudService().crearCotizacion(
        solicitudId: solicitudId,
        almacenId: almacenId!,
        precio: 25.5,
        notas: 'Cotización E2E con garantía',
        tiempoEntrega: '2 días',
        // Valor real del enum `condicion_repuesto` (los que usa la UI);
        // 'nuevo' a secas lo rechaza la base de datos.
        estadoRepuesto: 'Nuevo (En caja original)',
      );
      final cotizacionId = cotizacion['id'].toString();
      expect(cotizacionId, isNotEmpty, reason: 'La cotización no devolvió id');

      // 7) El cliente acepta la cotización → se genera la orden.
      await auth.signInWithEmailAndPassword(
        email: clienteEmail,
        password: clientePassword,
      );
      final aceptar = await SolicitudService().aceptarCotizacion(cotizacionId);
      final ordenId = aceptar['ordenId']?.toString();
      expect(ordenId, isNotNull, reason: 'Aceptar no devolvió ordenId');

      // 8) La orden aparece en "Mis Órdenes" del cliente.
      final ordenes = await SolicitudService().obtenerMisOrdenes(
        page: 1,
        limit: 50,
      );
      final orden = ordenes.firstWhere(
        (o) => o['id'].toString() == ordenId,
        orElse: () => fail('La orden $ordenId no aparece en Mis Órdenes'),
      );
      expect(orden['estado']?.toString(), isNotEmpty);
      expect(orden['id'].toString(), ordenId);
    },
  );
}
