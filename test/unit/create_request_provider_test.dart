import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/providers/create_request_provider.dart';

/// Reglas de estado del formulario de solicitud (`CreateRequestProvider`):
/// cantidades mínimas, reseteo de selecciones dependientes, notificación
/// solo cuando el estado cambia y limpieza completa.
void main() {
  group('updateAdditionalQuantity (mínimo 1)', () {
    test('0 → 1', () {
      final provider = CreateRequestProvider();
      final part = provider.addAdditionalPart();

      provider.updateAdditionalQuantity(part.id, 0);

      expect(part.cantidad, 1);
    });

    test('negativo → 1', () {
      final provider = CreateRequestProvider();
      final part = provider.addAdditionalPart();

      provider.updateAdditionalQuantity(part.id, -5);

      expect(part.cantidad, 1);
    });

    test('valor válido se conserva', () {
      final provider = CreateRequestProvider();
      final part = provider.addAdditionalPart();

      provider.updateAdditionalQuantity(part.id, 4);

      expect(part.cantidad, 4);
    });
  });

  group('setSelectedCategoryId (selección dependiente)', () {
    test('cambiar categoría resetea el repuesto seleccionado', () {
      final provider = CreateRequestProvider();
      provider.setSelectedCategoryId('cat-1');
      provider.setSelectedPartId('rep-1', 'Filtro');

      provider.setSelectedCategoryId('cat-2');

      expect(provider.selectedCategoryId, 'cat-2');
      expect(provider.selectedPartId, isNull);
      expect(provider.partNameSnapshot, isNull);
    });

    test('mismo id → no notifica de nuevo', () {
      final provider = CreateRequestProvider();
      provider.setSelectedCategoryId('cat-1');
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      provider.setSelectedCategoryId('cat-1');

      expect(notificaciones, 0);
    });
  });

  group('setSelectedPartId', () {
    test('con nombre → actualiza piezaNombre (snapshot del catálogo)', () {
      final provider = CreateRequestProvider();

      provider.setSelectedPartId('rep-1', 'Freno trasero');

      expect(provider.selectedPartId, 'rep-1');
      expect(provider.piezaNombre, 'Freno trasero');
    });

    test('sin nombre → no toca piezaNombre', () {
      final provider = CreateRequestProvider();
      provider.updatePiezaNombre('escrito a mano');

      provider.setSelectedPartId('rep-1', null);

      expect(provider.piezaNombre, 'escrito a mano');
    });
  });

  group('piezas adicionales', () {
    test('add/remove mantienen la lista consistente', () {
      final provider = CreateRequestProvider();
      final p1 = provider.addAdditionalPart();
      final p2 = provider.addAdditionalPart();

      expect(provider.additionalParts, hasLength(2));

      provider.removeAdditionalPart(p1.id);

      expect(provider.additionalParts, hasLength(1));
      expect(provider.additionalParts.single.id, p2.id);
    });

    test('updateAdditionalCategory limpia el repuesto elegido', () {
      final provider = CreateRequestProvider();
      final part = provider.addAdditionalPart();
      provider.updateAdditionalPart(part.id, 'rep-9', 'Bujía');

      provider.updateAdditionalCategory(part.id, 'cat-3', 'Motor');

      expect(part.categoriaId, 'cat-3');
      expect(part.categoriaNombre, 'Motor');
      expect(part.repuestoId, isNull);
      expect(part.repuestoNombreSnapshot, isNull);
    });

    test('actualizaciones sobre id inexistente son no-op (no lanzan)', () {
      final provider = CreateRequestProvider();

      provider.updateAdditionalCategory('fantasma', 'cat', 'X');
      provider.updateAdditionalPart('fantasma', 'rep', 'Y');
      provider.updateAdditionalDescription('fantasma', 'detalle');
      provider.updateAdditionalQuantity('fantasma', 3);
      provider.removeAdditionalPart('fantasma');

      expect(provider.additionalParts, isEmpty);
    });
  });

  group('ubicacionResuelta', () {
    test('notifica solo cuando cambia el valor', () {
      final provider = CreateRequestProvider();
      provider.setUbicacionResuelta(true);
      var notificaciones = 0;
      provider.addListener(() => notificaciones++);

      provider.setUbicacionResuelta(true);
      expect(notificaciones, 0);

      provider.setUbicacionResuelta(false);
      expect(notificaciones, 1);
    });
  });

  group('clear()', () {
    test('resetea todos los campos, incluidas piezas y ubicación', () {
      final provider = CreateRequestProvider();
      provider.updatePiezaNombre('Filtro');
      provider.updateDescripcion('cambio');
      provider.updateVehiculo('v-1');
      provider.updateDireccion('d-1');
      provider.updatePrioridad('urgente');
      provider.setSelectedCategoryId('cat-1');
      provider.setSelectedPartId('rep-1', 'Filtro de aceite');
      provider.addAdditionalPart();
      provider.setUbicacionResuelta(true);

      provider.clear();

      expect(provider.piezaNombre, '');
      expect(provider.descripcion, '');
      expect(provider.selectedVehiculoId, isNull);
      expect(provider.selectedDireccionId, isNull);
      expect(provider.selectedPrioridad, 'estándar');
      expect(provider.selectedCategoryId, isNull);
      expect(provider.selectedPartId, isNull);
      expect(provider.partNameSnapshot, isNull);
      expect(provider.additionalParts, isEmpty);
      expect(provider.ubicacionResuelta, isFalse);
    });
  });
}
