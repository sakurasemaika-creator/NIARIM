import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/app_scroll_behavior.dart';

/// Every vertical scroll in the app shows its scrollbar on the right all
/// the time, not only while scrolling (and on phones, where Flutter shows
/// none at all).
void main() {
  Widget app(Widget body) => MaterialApp(
    scrollBehavior: const AppScrollBehavior(),
    home: Scaffold(body: body),
  );

  List<Widget> rows(int count) => [
    for (var i = 0; i < count; i++) SizedBox(height: 50, child: Text('$i')),
  ];

  /// Where the thumb of the indicator [index] is drawn, in its own box.
  Rect? thumbOf(WidgetTester tester, [int index = 0]) {
    final indicator = find.byType(AlwaysShownScrollIndicator).at(index);
    final paint = find
        .descendant(of: indicator, matching: find.byType(CustomPaint))
        .first;
    final painter =
        tester.widget<CustomPaint>(paint).foregroundPainter!
            as ScrollIndicatorPainter;
    return ScrollIndicatorPainter.thumbRectFor(
      painter.metrics.value,
      tester.getSize(paint),
    );
  }

  testWidgets('a long list shows a thumb on the right before scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(app(ListView(children: rows(60))));
    await tester.pump();
    expect(find.byType(AlwaysShownScrollIndicator), findsOneWidget);
    final size = tester.getSize(find.byType(ListView));
    final thumb = thumbOf(tester)!;
    expect(thumb.right, closeTo(size.width - 2, 0.01), reason: 'right edge');
    expect(thumb.top, closeTo(2, 0.01), reason: 'at the top');
    // 600 of 3000 px are in view: the thumb is a fifth of the track.
    expect(thumb.height, closeTo((size.height - 4) * 600 / 3000, 1));

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    final moved = thumbOf(tester)!;
    expect(moved.top, greaterThan(thumb.top + 20), reason: 'followed');

    // Scrolled to the end, the thumb sits at the bottom.
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(thumbOf(tester)!.bottom, closeTo(size.height - 2, 0.5));
  });

  testWidgets('nothing is drawn when everything fits', (tester) async {
    await tester.pumpWidget(app(ListView(children: rows(3))));
    await tester.pump();
    expect(find.byType(AlwaysShownScrollIndicator), findsOneWidget);
    expect(thumbOf(tester), isNull);
  });

  testWidgets('two lists on one screen each have their own thumb', (
    tester,
  ) async {
    // Neither has a controller, so on a phone both share the screen's
    // PrimaryScrollController: Flutter's always-shown Scrollbar throws
    // here, the indicator must not.
    await tester.pumpWidget(
      app(
        Column(
          children: [
            Expanded(child: ListView(children: rows(40))),
            Expanded(
              child: SingleChildScrollView(child: Column(children: rows(40))),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlwaysShownScrollIndicator), findsNWidgets(2));
    final first = thumbOf(tester, 0)!;
    final second = thumbOf(tester, 1)!;
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(thumbOf(tester, 0)!.top, greaterThan(first.top));
    expect(thumbOf(tester, 1), second, reason: 'the other did not move');
  });

  testWidgets('a nested list does not move the outer thumb', (tester) async {
    await tester.pumpWidget(
      app(
        ListView(
          children: [
            SizedBox(height: 300, child: ListView(children: rows(40))),
            ...rows(40),
          ],
        ),
      ),
    );
    await tester.pump();
    final outer = thumbOf(tester, 0)!;
    final inner = thumbOf(tester, 1)!;
    await tester.drag(find.text('3').first, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(thumbOf(tester, 1)!.top, greaterThan(inner.top));
    expect(thumbOf(tester, 0), outer);
  });

  testWidgets('sideways scrolling and page views get no bar', (tester) async {
    await tester.pumpWidget(
      app(
        Column(
          children: [
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(width: 60, child: Text('h$i')),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                scrollDirection: Axis.vertical,
                children: const [Text('a'), Text('b')],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AlwaysShownScrollIndicator), findsNothing);
  });

  testWidgets('on desktop the draggable scrollbar is always shown', (
    tester,
  ) async {
    await tester.pumpWidget(app(ListView(children: rows(60))));
    await tester.pump();
    expect(find.byType(AlwaysShownScrollIndicator), findsNothing);
    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    expect(scrollbar.thumbVisibility, isTrue);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  test('the app uses it', () {
    final source = File('lib/app.dart').readAsStringSync();
    expect(source, contains('scrollBehavior: const AppScrollBehavior()'));
  });
}
