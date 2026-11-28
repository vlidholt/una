import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/src/components/decorator.dart' show OutwardBorderPainter;
import 'package:una/una.dart';

import '../../una_harness.dart';

/// A control reshaped through its decoration's border — a pill-shaped
/// field — has its focus ring, and its focused and error borders, on the
/// same shape: the theme's are baked at the theme's own radius.
void main() {
  const pill = BorderRadius.all(Radius.circular(999));

  Widget field({bool error = false}) => Center(
    child: SizedBox(
      width: 200,
      child: TextField(
        autofocus: true,
        decoration: UnaDecoration(
          border: UnaBorder.all(borderRadius: pill),
          hasError: error,
        ),
      ),
    ),
  );

  OutwardBorderPainter? ring(WidgetTester tester) {
    for (final paint in tester.widgetList<CustomPaint>(
      find.byType(CustomPaint),
    )) {
      if (paint.foregroundPainter case final OutwardBorderPainter painter) {
        return painter;
      }
    }
    return null;
  }

  testWidgets("the focus ring goes round the control's own radius", (
    tester,
  ) async {
    await pumpUna(tester, field());
    await tester.pump(const Duration(milliseconds: 300));
    final painter = ring(tester);
    expect(painter, isNotNull);
    expect(painter!.radius!.topLeft.x, greaterThan(999));
  });

  testWidgets('without a ring, the focused border keeps the radius', (
    tester,
  ) async {
    await pumpUna(
      tester,
      field(),
      theme: ThemeData(disableSecondaryBorder: true),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final decorated = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<ShadowDecoration>()
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.borderRadius != null);
    expect(decorated, isNotEmpty);
    for (final decoration in decorated) {
      expect(decoration.borderRadius, pill);
    }
  });
}
