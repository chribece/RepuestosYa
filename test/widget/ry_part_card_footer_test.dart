import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/widgets/ry_part_card.dart';

/// Footer de la tarjeta con el badge de estado y el indicador offline ("En
/// cola") activos a la vez, en pantallas estrechas. Se valida por geometría
/// porque la fuente Ahem del harness es más ancha que la real.
void main() {
  for (final variant in [
    RyPartCardVariant.client,
    RyPartCardVariant.warehouse,
  ]) {
    testWidgets('footer ${variant.name}: badge e indicador "En cola" caben en '
        '320 px', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: RyPartCard(
                partName: 'Terminal de batería',
                status: 'pendiente',
                quotationCount: 3,
                createdAt: DateTime(2026, 11, 1),
                variant: variant,
                isSynced: false,
                showImage: false,
                showPrice: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final tarjeta = tester.getRect(find.byType(RyPartCard));
      final indicador = tester.getRect(find.text('En cola'));
      final footer = tester.getRect(
        find.ancestor(of: find.text('En cola'), matching: find.byType(Wrap)),
      );

      expect(indicador.left, greaterThanOrEqualTo(tarjeta.left));
      expect(indicador.right, lessThanOrEqualTo(tarjeta.right));
      expect(footer.right, lessThanOrEqualTo(tarjeta.right));
      expect(tester.takeException(), isNull);
    });
  }
}
