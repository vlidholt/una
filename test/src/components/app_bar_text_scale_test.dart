import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/src/components/app_bar_layout.dart';
import 'package:una/una.dart';

import '../../app_bar_metrics.dart';
import '../../una_harness.dart';

void main() {
  /// Pumps a scaffold with a titled bar at [scale] and returns the height
  /// `AppBar.heightOf` reports under it.
  Future<double> pumpBar(
    WidgetTester tester,
    double scale, {
    FormFactor formFactor = FormFactor.desktop,
    bool centerTitle = false,
    double? height,
    double statusBar = 0,
  }) async {
    late double reported;
    await pumpUna(
      tester,
      MediaQuery(
        data: MediaQueryData(
          size: kSurfaceSizes[formFactor]!,
          textScaler: TextScaler.linear(scale),
          padding: EdgeInsets.only(top: statusBar),
        ),
        // Asked above the scaffold: under it, the top padding a descendant
        // sees is the bar itself.
        child: Builder(
          builder: (context) {
            reported = AppBar.heightOf(context);
            return Scaffold(
              appBar: AppBar(
                title: const Text('Inbox'),
                centerTitle: centerTitle,
                height: height,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton.ghost(
                    icon: const PhosphorIcon(PhosphorIconsRegular.gear),
                    onPressed: () {},
                  ),
                ],
              ),
              body: const SizedBox.expand(key: ValueKey('body')),
            );
          },
        ),
      ),
      formFactor: formFactor,
    );
    expect(tester.takeException(), isNull, reason: 'scale $scale');
    return reported;
  }

  double barHeight(WidgetTester tester) =>
      tester.getSize(find.byType(AppBar)).height;

  group('AppBar and the text scale', () {
    testWidgets('at a scale of 1 or less it is exactly its style height', (
      tester,
    ) async {
      for (final formFactor in FormFactor.values) {
        final theme = ThemeData(formFactor: formFactor);
        final style = filledToolbarHeight(theme);
        // A filled bar keeps no margin above its toolbar where there is no
        // status bar, as here: its toolbar has room of its own.
        const inset = 0;
        for (final scale in [.85, 1.0]) {
          await tester.pumpWidget(const SizedBox.shrink());
          final reported = await pumpBar(tester, scale, formFactor: formFactor);
          // The toolbar and its hairline.
          expect(
            barHeight(tester),
            style + 1 + inset,
            reason: '$formFactor $scale',
          );
          expect(reported, style + 1 + inset);
        }
      }
    });

    testWidgets('it keeps its height while a line of the title fits', (
      tester,
    ) async {
      for (final scale in [1.3, 1.6, 2.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpBar(tester, scale);
        final title = tester.getRect(find.text('Inbox'));
        final bar = tester.getRect(find.byType(AppBar));
        expect(bar.height, 65, reason: 'scale $scale');
        // The whole line is inside the bar.
        expect(title.top, greaterThanOrEqualTo(bar.top));
        expect(title.bottom, lessThanOrEqualTo(bar.bottom - 1));
      }
    });

    testWidgets('past that it is as tall as the line, title in or centred', (
      tester,
    ) async {
      for (final centerTitle in [false, true]) {
        for (final formFactor in FormFactor.values) {
          for (final scale in [3.0, 3.5]) {
            await tester.pumpWidget(const SizedBox.shrink());
            final reported = await pumpBar(
              tester,
              scale,
              formFactor: formFactor,
              centerTitle: centerTitle,
            );
            final reason = '$formFactor $scale centred: $centerTitle';
            final theme = themeOf(tester, find.byType(AppBar));
            final style = theme.appBarTheme.height!;
            final title = tester.getRect(find.text('Inbox'));
            final bar = tester.getRect(find.byType(AppBar));
            expect(bar.height, greaterThan(style + 1), reason: reason);
            expect(title.height, lessThanOrEqualTo(bar.height - 1));
            expect(title.top, greaterThanOrEqualTo(bar.top), reason: reason);
            expect(
              title.bottom,
              lessThanOrEqualTo(bar.bottom - 1),
              reason: reason,
            );
            // What heightOf says is what the bar takes…
            expect(reported, bar.height, reason: reason);
            // …and the scaffold tells its body to keep clear of all of it.
            final body = tester.element(find.byKey(const ValueKey('body')));
            expect(
              MediaQuery.paddingOf(body).top,
              bar.height,
              reason: reason,
            );
          }
        }
      }
    });

    testWidgets('an explicit height is a floor too', (tester) async {
      await pumpBar(tester, 1, height: 40);
      expect(barHeight(tester), 41);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpBar(tester, 3, height: 40);
      final title = tester.getRect(find.text('Inbox'));
      expect(barHeight(tester), greaterThanOrEqualTo(title.height + 1));
    });

    testWidgets('the status bar is added on top of the scaled height', (
      tester,
    ) async {
      final plain = await pumpBar(tester, 3);
      await tester.pumpWidget(const SizedBox.shrink());
      final reported = await pumpBar(tester, 3, statusBar: 47);
      expect(reported, plain + 47);
      expect(barHeight(tester), plain + 47);
    });

    testWidgets('a SliverAppBar grows its toolbar as an AppBar does', (
      tester,
    ) async {
      Future<double> toolbarOf(Widget bar) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpUna(
          tester,
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(3)),
              child: Scaffold(body: bar),
            ),
          ),
        );
        return tester
            .getSize(
              find.ancestor(
                of: find.text('Inbox').first,
                matching: find.byType(AppBarToolbar),
              ),
            )
            .height;
      }

      final plain = await toolbarOf(
        const Align(
          alignment: Alignment.topCenter,
          child: AppBar(title: Text('Inbox')),
        ),
      );
      final sliver = await toolbarOf(
        const CustomScrollView(
          slivers: [
            SliverAppBar(title: Text('Inbox')),
            SliverToBoxAdapter(child: SizedBox(height: 2000)),
          ],
        ),
      );
      expect(plain, greaterThan(64));
      expect(sliver, plain);
    });
  });
}
