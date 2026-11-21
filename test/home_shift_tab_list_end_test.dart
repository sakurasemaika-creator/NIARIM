import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/home_keyboard_harness.dart';

/// 一覧の一番上からShift+Tabで戻ると、浮かぶボタンの次は一覧の最後のカード
/// （まだ作られていない一番下の行も、一覧を送って作る）で、そこから1枚ずつ
/// 戻って一覧の全部のカードの星・︙に1回ずつ止まる。Tabで進むときも全部に
/// 1回ずつ止まる。スマホ（ko 360・ja 360文字2倍）とPC（1280）、作品24・60件。
///
/// 以前は浮かぶボタンの次に、作ってある一番下の行へ飛び、作られていない下の
/// 行（ko 360・24件で「Work 0〜2」）には後ろ向きでは行けなかった（DISC200）。
void main() {
  for (final (language, size, textScale, works) in const [
    ('ko', Size(360, 740), 1.0, 24),
    ('ja', Size(360, 740), 2.0, 24),
    ('ko', Size(360, 740), 1.0, 60),
    ('ja', Size(1280, 800), 1.0, 60),
  ]) {
    for (final shift in [true, false]) {
      testWidgets('$language ${size.width} x$textScale, $works works: '
          '${shift ? 'Shift+Tab' : 'Tab'} from the top reaches every card', (
        tester,
      ) async {
        final home = await HomeKeyboardHarness.open(
          tester,
          language: language,
          size: size,
          textScale: textScale,
          works: works,
          prefs: {'force_pc_mode': size.width > 600 ? 1 : 0},
        );
        // カードの︙のキー（collectionMenu_<作品のID>）から作品の名前。
        final names = {for (final p in home.projects.projects) p.id: p.name};
        String? card(String stop) {
          for (final prefix in const [
            'collectionMenu_',
            'collectionFavorite_',
          ]) {
            if (stop.startsWith(prefix)) {
              return names[stop.substring(prefix.length)];
            }
          }
          return null;
        }

        // 一覧の一番上（最初の止まり先）から始める。
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await home.tab();
        final first = home.describeFocus();
        final order = <String>[];
        String? repeated;
        for (var step = 0; step < 4 * works + 60; step++) {
          await home.tab(shift: shift);
          await home.settle();
          final name = home.describeFocus();
          if (name == first || order.contains(name)) {
            repeated = name;
            break;
          }
          order.add(name);
        }
        final steps = [
          for (var i = 0; i < order.length; i++) '${i + 1}: ${order[i]}',
        ].join('\n');
        expect(repeated, first, reason: 'stopped twice:\n$steps');
        final menus = {
          for (final s in order)
            if (s.startsWith('collectionMenu_')) card(s),
        };
        final stars = {
          for (final s in order)
            if (s.startsWith('collectionFavorite_')) card(s),
        };
        final missing = {
          for (final name in names.values)
            if (!menus.contains(name) || !stars.contains(name)) name,
        };
        expect(missing, isEmpty, reason: 'never reached:\n$steps');
        if (shift) {
          // 浮かぶボタンの次は、一覧の最後のカード（いちばん古い「Work 0」）。
          final firstCard = order.map(card).whereType<String>().first;
          expect(firstCard, 'Work 0', reason: steps);
        }
        expect(tester.takeException(), isNull);
        await home.close();
      });
    }
  }
}
