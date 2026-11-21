import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/widgets/collection_card_keys.dart';

import 'helpers/home_keyboard_harness.dart';

/// Tabで一覧の部品へ進んだとき、その部品を浮かぶボタン（「一番上へ」・＋）の
/// 上まで送り出す（一覧の下に浮かぶボタンの分を空けてあるのと同じ）。以前は
/// 一覧の下端までしか送らず、一番下の行の右の︙のフォーカスが＋の下に完全に
/// 隠れ、左下の星も「一番上へ」の下に一部隠れた（ko 360×740で1周に7回、
/// fr 360・文字2倍で5回）。
void main() {
  testWidgets('Tab visits each grid card and its buttons together', (
    tester,
  ) async {
    final home = await HomeKeyboardHarness.open(
      tester,
      size: const Size(360, 844),
      works: 8,
    );
    final list = find.byType(ProjectListWidget);
    final visited = <Element>[];
    final stopsPerCard = <Element, int>{};
    for (var step = 0; step < 90; step++) {
      await home.tab();
      if (!home.focusIsIn(list)) {
        if (visited.isNotEmpty) break;
        continue;
      }
      Element? card;
      home.focus?.context?.visitAncestorElements((element) {
        if (element.widget is CollectionCardFocus) {
          card = element;
          return false;
        }
        return true;
      });
      if (card case final Element current) {
        if (visited.lastOrNull != current) {
          expect(visited, isNot(contains(current)));
          visited.add(current);
        }
        stopsPerCard.update(current, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    expect(visited, hasLength(8));
    expect(stopsPerCard.values, everyElement(3));
    await home.close();
  });

  for (final (language, size, textScale) in [
    ('ko', const Size(360, 740), 1.0),
    ('fr', const Size(360, 740), 2.0),
    ('ja', const Size(360, 740), 1.0),
    ('ja', const Size(1280, 800), 1.0),
  ]) {
    for (final shift in [false, true]) {
      testWidgets('$language ${size.width} x$textScale '
          '${shift ? 'Shift+Tab' : 'Tab'}: focus is never under a FAB', (
        tester,
      ) async {
        final home = await HomeKeyboardHarness.open(
          tester,
          language: language,
          size: size,
          textScale: textScale,
          works: 24,
        );
        final list = find.byType(ProjectListWidget);
        final problems = <String>[];
        var visited = 0;
        for (var step = 1; step <= 150; step++) {
          await home.tab(shift: shift);
          if (!home.focusIsIn(list)) continue;
          visited++;
          // 一覧の見える所（タブの下）に出ている。
          final top = tester.getRect(find.byType(TabBarView)).top;
          final rect = home.focusRect;
          if (rect.top < top - 0.5 || rect.bottom > size.height + 0.5) {
            problems.add('$step ${home.describeFocus()} $rect off screen');
          }
          for (final fab in home.fabRects()) {
            if (fab.overlaps(rect)) {
              problems.add('$step ${home.describeFocus()} $rect under $fab');
            }
          }
        }
        expect(visited, greaterThan(48), reason: 'the walk missed the list');
        expect(problems, isEmpty, reason: problems.join('\n'));
        expect(tester.takeException(), isNull);
        await home.close();
      });
    }
  }
}
