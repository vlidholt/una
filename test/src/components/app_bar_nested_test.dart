import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/una.dart';

import '../../una_harness.dart';

/// A shell — the app's drawer and its bottom bar — around a navigator of
/// its own, whose pages each have their own scaffold and bar, as a
/// destination with its own stack of pages has.
void main() {
  final navigator = GlobalKey<NavigatorState>();

  Widget page(String title) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: const SizedBox.expand(),
  );

  Widget shell({bool drawer = true, bool endDrawer = false}) => Scaffold(
    drawer: drawer ? const Text('Menu') : null,
    endDrawer: endDrawer ? const Text('Filters') : null,
    body: Navigator(
      key: navigator,
      onGenerateInitialRoutes: (_, _) => [
        UnaPageRoute<void>(builder: (_) => page('Trips')),
      ],
    ),
  );

  Finder button(String label) => find.byWidgetPredicate(
    (w) => w is IconButton && w.semanticLabel == label,
  );

  testWidgets("a page's own bar opens the shell's drawer", (tester) async {
    await pumpUna(tester, shell(), formFactor: FormFactor.mobile);
    expect(button('Open menu'), findsOneWidget);
    await tester.tap(button('Open menu'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Menu'), findsOneWidget);
  });

  testWidgets('a page pushed in the shell has a back button, not the menu', (
    tester,
  ) async {
    await pumpUna(tester, shell(), formFactor: FormFactor.mobile);
    navigator.currentState!.push(
      UnaPageRoute<void>(builder: (_) => page('Lofoten')),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(BackButton), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Lofoten'),
          matching: find.byType(AppBar),
        ),
        matching: button('Open menu'),
      ),
      findsNothing,
    );
  });

  testWidgets("a page's own bar opens the shell's end drawer", (tester) async {
    await pumpUna(
      tester,
      shell(drawer: false, endDrawer: true),
      formFactor: FormFactor.mobile,
    );
    expect(button('Open menu'), findsOneWidget);
  });
}
