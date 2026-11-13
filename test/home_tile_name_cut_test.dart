import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/project_service.dart';

import 'helpers/home_app_harness.dart';
import 'helpers/load_app_fonts.dart';

/// 上限を超える名前を「…」で切るとき、語を空白で区切って書く字（英字・
/// ハングル等）の語の途中で切れる所だけ、その語を出さない。日本語・中国語の
/// 名前は空白があっても字の途中で切ってよいので、上限まで出す。
///
/// 以前は、残す文の後半に空白があるとどの言語でもそこまで戻していて、
/// 「主人公が初めて空を飛ぶ 場面の作画です」は「主人公が初めて空を飛ぶ…」と
/// 出ていた（上限までまだ入るのに、空白の後の「場面」を出さなかった）。
void main() {
  const japanese = '主人公が初めて空を飛ぶ 場面の作画です';
  const chinese = '小猫第一次去冒险 在雨中的街道上奔跑';
  const english = 'The quick brown fox jumps over the lazy dog';
  const korean = '애니메이션 만들기 연습 첫번째 장면입니다';

  Future<void> seed(ProjectService service) async {
    for (final name in [japanese, chinese, english, korean]) {
      await HomeAppHarness.work(service, name);
    }
  }

  String shown(WidgetTester tester, String name) {
    final text = tester.widget<Text>(
      HomeAppHarness.inProjects(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.style?.fontFamily == 'Kuramubon' &&
              w.semanticsLabel == name,
        ),
      ),
    );
    return text.data!.replaceAll('⁠', '');
  }

  void expectCuts(WidgetTester tester, String why) {
    expect(tester.takeException(), isNull, reason: why);
    // 日本語・中国語は、空白の後の字も上限まで出す。
    expect(shown(tester, japanese), '主人公が初めて空を飛ぶ 場面…', reason: why);
    expect(shown(tester, chinese), startsWith('小猫第一次去冒险 在'), reason: why);
    // 英語・韓国語は、途中で切れる語を出さない（空白の所で「…」）。
    final en = shown(tester, english);
    expect(en, endsWith('…'), reason: why);
    expect(
      english.split(' '),
      containsAll(en.substring(0, en.length - 1).split(' ')),
      reason: '$why $en',
    );
    final ko = shown(tester, korean);
    expect(ko, endsWith('…'), reason: why);
    expect(
      korean.split(' '),
      containsAll(ko.substring(0, ko.length - 1).split(' ')),
      reason: '$why $ko',
    );
  }

  for (final (mode, width) in [('large', 1280.0), ('small', 360.0)]) {
    testWidgets('CJK names keep text after a space ($mode $width)', (
      tester,
    ) async {
      await loadAppFonts(tester);
      final home = HomeAppHarness.prepare(
        tester,
        preferences: {'home.projectViewMode.v1': mode},
      );
      await home.open(size: Size(width, 2400), seed: seed);
      expectCuts(tester, '$mode $width');
      await home.close();
    });
  }
}
