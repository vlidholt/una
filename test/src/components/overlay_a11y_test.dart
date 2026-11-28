import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/una.dart';

import '../../una_harness.dart';

/// Records what is sent to a screen reader as an announcement.
List<String> _listenForAnnouncements(WidgetTester tester) {
  final announcements = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (message) async {
      final data = (message as Map)['data'] as Map;
      final text = data['message'];
      if (text is String) announcements.add(text);
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return announcements;
}

Future<void> _frames(WidgetTester tester, [int count = 20]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  group('Toast', () {
    Future<ToasterState> pumpToaster(
      WidgetTester tester, {
      bool accessibleNavigation = false,
      FormFactor formFactor = FormFactor.desktop,
    }) async {
      late BuildContext ctx;
      await pumpUna(
        tester,
        MediaQuery(
          data: MediaQueryData(accessibleNavigation: accessibleNavigation),
          child: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.expand();
            },
          ),
        ),
        formFactor: formFactor,
      );
      return Toaster.of(ctx);
    }

    Future<void> elapse(WidgetTester tester, Duration duration) async {
      final end = tester.binding.clock.now().add(duration);
      while (tester.binding.clock.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('one with an action stays under a screen reader', (
      tester,
    ) async {
      // The toaster sits above the page, so the flag is set on the view.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final toaster = await pumpToaster(tester, accessibleNavigation: true);
      toaster.show(
        Toast(
          title: const Text('Deleted'),
          action: Button.outline(onPressed: () {}, child: const Text('Undo')),
        ),
      );
      toaster.show(const Toast(title: Text('Saved')));
      await elapse(tester, const Duration(seconds: 8));
      expect(find.text('Deleted'), findsOneWidget);
      // One with nothing to act on still goes.
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('one with an action times out with no screen reader', (
      tester,
    ) async {
      final toaster = await pumpToaster(tester);
      toaster.show(
        Toast(
          title: const Text('Deleted'),
          action: Button.outline(onPressed: () {}, child: const Text('Undo')),
        ),
      );
      await elapse(tester, const Duration(seconds: 8));
      expect(find.text('Deleted'), findsNothing);
    });
  });

  group('Command', () {
    Widget palette() => const UnaApp(
      home: Center(
        child: Command(
          groups: [
            CommandGroup(
              items: [
                CommandItem(label: 'Apple'),
                CommandItem(label: 'Banana'),
                CommandItem(label: 'Cherry'),
              ],
            ),
          ],
        ),
      ),
    );

    testWidgets('announces the item the keys move to, and where it is', (
      tester,
    ) async {
      final announcements = _listenForAnnouncements(tester);
      await tester.pumpWidget(palette());
      await tester.pump();
      expect(announcements, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(announcements, ['Banana, 2 of 3', 'Cherry, 3 of 3']);
    });

    testWidgets('announces how many results a query leaves, once typing '
        'pauses', (tester) async {
      final announcements = _listenForAnnouncements(tester);
      await tester.pumpWidget(palette());
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'a');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(EditableText), 'an');
      await tester.pump(const Duration(milliseconds: 600));
      expect(announcements, ['1 result available']);

      await tester.enterText(find.byType(EditableText), 'zz');
      await tester.pump(const Duration(milliseconds: 600));
      expect(announcements.last, 'No results found.');
    });
  });

  testWidgets("showPopover's barrier is named Dismiss", (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUna(
      tester,
      Builder(
        builder: (context) => Center(
          child: Button(
            onPressed: () => showPopover<void>(
              context: context,
              anchorRect: const Rect.fromLTWH(100, 100, 40, 20),
              builder: (_) => const Text('Inside'),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await settle(tester);
    expect(find.text('Inside'), findsOneWidget);
    expect(find.bySemanticsLabel('Dismiss'), findsOneWidget);
    handle.dispose();
  });

  group('Alert', () {
    testWidgets('is a live region, and an alert on the web when it warns', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpUna(
        tester,
        const Column(
          children: [
            Alert(title: Text('Note')),
            Alert(variant: AlertVariant.warning, title: Text('Careful')),
          ],
        ),
      );
      for (final label in ['Note', 'Careful']) {
        var node = tester.getSemantics(find.text(label));
        final data = node.getSemanticsData();
        // The title's own node, or the alert's container around it.
        if (!data.flagsCollection.isLiveRegion &&
            data.role != SemanticsRole.alert) {
          node = node.parent!;
        }
        final container = node.getSemanticsData();
        if (kIsWeb && label == 'Careful') {
          expect(container.role, SemanticsRole.alert);
          expect(container.flagsCollection.isLiveRegion, isFalse);
        } else {
          expect(container.flagsCollection.isLiveRegion, isTrue);
          expect(container.role, isNot(SemanticsRole.alert));
        }
      }
      handle.dispose();
    });

    testWidgets('closing it from the keyboard moves the focus on', (
      tester,
    ) async {
      var dismissed = false;
      await pumpUna(
        tester,
        StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!dismissed)
                Alert(
                  title: const Text('Note'),
                  onDismissed: () => setState(() => dismissed = true),
                ),
              Button(onPressed: () {}, child: const Text('Next')),
            ],
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final close = FocusManager.instance.primaryFocus;
      expect(
        close?.context?.findAncestorWidgetOfExactType<Alert>(),
        isNotNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _frames(tester, 60);
      expect(dismissed, isTrue);
      final focus = FocusManager.instance.primaryFocus;
      expect(
        focus?.context?.findAncestorWidgetOfExactType<Button>(),
        isNotNull,
      );
      expect(
        find.descendant(
          of: find.byWidget(focus!.context!.widget),
          matching: find.text('Next'),
        ),
        findsOneWidget,
      );
    });
  });

  group('NavigationMenu', () {
    for (final collapsed in [false, true]) {
      testWidgets('is a navigation landmark with its name'
          '${collapsed ? ', collapsed' : ''}', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpUna(
          tester,
          Align(
            alignment: Alignment.topCenter,
            child: NavigationMenu(
              collapsed: collapsed,
              semanticLabel: 'Main',
              items: [
                NavigationMenuItem(
                  label: const Text('Pricing'),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );
        final landmarks = find.semantics.byPredicate(
          (node) =>
              node.getSemanticsData().role == SemanticsRole.navigation &&
              node.label == 'Main',
        );
        expect(landmarks, findsOne);
        handle.dispose();
      });
    }
  });
}
