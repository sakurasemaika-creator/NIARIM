import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/canvas/widgets/desktop_dock_content_viewport.dart';

void main() {
  testWidgets('complete visual fits narrow and short dock preserving proportions',
      (tester) async {
    for (final size in [
      const Size(182, 140),
      const Size(290, 200),
      const Size(462, 700),
    ]) {
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            key: const ValueKey('dockBounds'),
            width: size.width,
            height: size.height,
            child: const DesktopDockContentViewport(
              mode: DesktopDockContentMode.fit,
              designWidth: 288,
              minimumContentHeight: 310,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  key: ValueKey('wholeColourWheelArea'),
                  width: 288,
                  height: 310,
                ),
              ),
            ),
          ),
        ),
      ));
      final rect = tester.getRect(find.byKey(const ValueKey('dockBounds')));
      final visual = tester.getRect(
        find.byKey(const ValueKey('wholeColourWheelArea')),
      );
      expect(visual.left, greaterThanOrEqualTo(rect.left - 0.1));
      expect(visual.right, lessThanOrEqualTo(rect.right + 0.1));
      expect(visual.top, greaterThanOrEqualTo(rect.top - 0.1));
      expect(visual.bottom, lessThanOrEqualTo(rect.bottom + 0.1));
      expect(
        (visual.width - visual.height * 288 / 310).abs(), lessThan(0.3),
        reason: 'colour-wheel contents must scale uniformly',
      );
    }
  });

  testWidgets('list row height follows width but not viewport height',
      (tester) async {
    final windowHeight = ValueNotifier<double>(340);
    final windowWidth = ValueNotifier<double>(210);
    addTearDown(windowHeight.dispose);
    addTearDown(windowWidth.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: ValueListenableBuilder<double>(
          valueListenable: windowHeight,
          builder: (context, height, _) => ValueListenableBuilder<double>(
            valueListenable: windowWidth,
            builder: (context, width, _) => SizedBox(
              width: width,
              height: height,
              child: DesktopDockContentViewport(
                mode: DesktopDockContentMode.scroll,
                designWidth: 280,
                minimumContentHeight: 460,
                child: ListView.builder(
                  itemExtent: 50,
                  itemCount: 30,
                  itemBuilder: (context, index) => SizedBox(
                    key: ValueKey('brush-$index'),
                    height: 50,
                    child: Text('Brush $index'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    final first = tester.getRect(find.byKey(const ValueKey('brush-0')));
    windowHeight.value = 170;
    await tester.pump();
    final short = tester.getRect(find.byKey(const ValueKey('brush-0')));
    expect((first.height - short.height).abs(), lessThan(0.2),
        reason: 'vertical resize should reveal scrollbar, not shrink rows');
    expect(find.byKey(const ValueKey('desktopDockVerticalScroll')), findsOneWidget);

    windowWidth.value = 330;
    await tester.pump();
    final wide = tester.getRect(find.byKey(const ValueKey('brush-0')));
    expect(wide.height, greaterThan(first.height),
        reason: 'horizontal resize should scale list contents uniformly');
    expect(tester.takeException(), isNull);
  });
}
