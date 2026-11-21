import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/home_keyboard_harness.dart';

/// Tab（Shift+Tab）でホームを1周すると、どの部品にもちょうど1回止まる。
/// 以前は、一覧の下に浮かぶボタンが読む順の並べ替えに混ざり、浮かぶボタンの
/// 高さに入った行の︙だけが同じ行の星より先に並んだ。星へ進んで一覧が
/// スクロールすると並びが変わり、同じ︙にもう一度止まった（fr 360・文字2倍：
/// 24番が左下のカードの︙、25番が星、26番が同じ︙。ko 360：036/039・037/041）。
void main() {
  for (final (language, size, textScale) in [
    ('ko', const Size(360, 740), 1.0),
    ('fr', const Size(360, 740), 2.0),
    ('ja', const Size(360, 740), 2.0),
    ('ja', const Size(1280, 800), 1.0),
    ('ja', const Size(1280, 800), 2.0),
  ]) {
    for (final shift in [false, true]) {
      testWidgets('$language ${size.width} x$textScale '
          '${shift ? 'Shift+Tab' : 'Tab'}: one stop per control per round', (
        tester,
      ) async {
        const works = 24;
        final home = await HomeKeyboardHarness.open(
          tester,
          language: language,
          size: size,
          textScale: textScale,
          works: works,
        );
        final order = <String>[];
        if (shift) {
          // 一覧の終わりまで進んでから（行は見える所の近くだけを作るので、
          // 一番上から戻ると、まだ作っていない下の行へは戻れない）、最後の
          // 部品（＋）から1周戻る。
          final add = find.byWidgetPredicate(
            (w) => w is FloatingActionButton && w.heroTag == 'home-add-project',
          );
          for (var i = 0; i < 200 && !home.focusIsIn(add); i++) {
            await home.tab();
          }
          expect(home.focusIsIn(add), isTrue);
          order.add(home.describeFocus());
        }
        String? repeated;
        for (var step = 0; step < 200; step++) {
          await home.tab(shift: shift);
          final name = home.describeFocus();
          if (order.contains(name)) {
            repeated = name;
            break;
          }
          order.add(name);
        }
        final steps = [
          for (var i = 0; i < order.length; i++) '${i + 1}: ${order[i]}',
        ].join('\n');
        // 最初に戻ってきた部品が1周の始まり（それより前に同じ部品は無い）。
        expect(repeated, order.first, reason: 'stopped twice:\n$steps');
        expect(
          order.where((n) => n.startsWith('collectionMenu_')).length,
          works,
          reason: steps,
        );
        expect(
          order.where((n) => n.startsWith('collectionFavorite_')).length,
          works,
          reason: steps,
        );
        expect(tester.takeException(), isNull);
        await home.close();
      });
    }
  }
}
