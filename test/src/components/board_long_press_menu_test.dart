import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/una.dart';

import '../../una_harness.dart';

/// A finger held on a board card lifts it; a context menu region on the
/// card must not open on the same press (it did: the card rose and its
/// menu came up under the finger).
void main() {
  Widget menuOn(String label) => ContextMenuRegion(
    items: [MenuItem(onPressed: () {}, child: const Text('Archive'))],
    child: SizedBox(height: 56, child: Center(child: Text(label))),
  );

  testWidgets('a long press on a board card lifts it and opens no menu', (
    tester,
  ) async {
    await pumpUna(
      tester,
      SizedBox(
        height: 600,
        child: Board<String>(
          columns: const [
            BoardColumn(id: 'a', label: 'A', items: ['Card']),
          ],
          itemBuilder: (context, item, details) => menuOn(item),
          onMove: (_) {},
        ),
      ),
      formFactor: FormFactor.mobile,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Card')),
    );
    await tester.pump(const Duration(milliseconds: 800));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Archive'), findsNothing);
    await gesture.up();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Archive'), findsNothing);
  });

  testWidgets('outside a board the same region opens on a long press', (
    tester,
  ) async {
    await pumpUna(
      tester,
      Center(child: menuOn('Card')),
      formFactor: FormFactor.mobile,
    );
    await tester.longPress(find.text('Card'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Archive'), findsOneWidget);
  });
}
