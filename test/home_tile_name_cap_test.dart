import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/services/project_service.dart';

import 'helpers/home_app_harness.dart';
import 'helpers/load_app_fonts.dart';

/// カードの名前は、決めた長さまで出し、それを超える分だけ「…」にする
/// （所有者の判断5「表示最大文字数を決めて、そこまでは表示できるように
/// タイトル表示可能列数を最大2行に増やします」）。決めた長さは、スマホの
/// 既定のカード（幅360px・小表示・文字1倍）の名前の帯の2行分。上限で
/// 切った名前はそのカードの2行に入りきり、どの大きさのカードでも同じ
/// ところで切れる。
///
/// 以前は上限を「全角16文字・半角32文字」と数えていて、既定のカードには
/// 全角が1行7文字しか入らず、上限ちょうどの名前でも13文字で「…」に
/// なっていた（英数字は字の幅が全角の半分より広く、もっと手前で切れた）。
void main() {
  // 上限を超える名前（かな・漢字・英語・英数字・数字・韓国語）。
  const long = [
    'あいうえおかきくけこさしすせそたちつてと',
    '夕暮れの街を歩く猫と少女の物語第一話後編',
    'The quick brown fox jumps over the lazy dog',
    'Scene_0012_background_v2_final_fix',
    '01234567890123456789012345678901',
    '가나다라마바사아자차카타파하가나다라마바사',
  ];
  // 全角14文字（既定のカードの1行に7文字）は切らずに出る。
  const fourteen = ['あいうえおかきくけこさしすせ', '夕暮れの街を歩く猫と少女の物'];

  Future<void> seed(ProjectService service) async {
    for (final name in [...long, ...fourteen]) {
      await HomeAppHarness.work(service, name);
    }
  }

  Finder caption(String name) => HomeAppHarness.inProjects(
    find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.style?.fontFamily == 'Kuramubon' &&
          (w.semanticsLabel ?? w.data) == name,
    ),
  );

  RenderParagraph paragraphOf(WidgetTester tester, String name) =>
      tester.renderObject<RenderParagraph>(
        find.descendant(of: caption(name), matching: find.byType(RichText)),
      );

  // 名前ごとの、カードに出した文（「…」で切った名前は「…」まで）。
  Map<String, String> shown(WidgetTester tester) => {
    for (final name in [...long, ...fourteen])
      name: tester.widget<Text>(caption(name)).data!.replaceAll('⁠', ''),
  };

  void expectCapFits(WidgetTester tester, String why) {
    expect(tester.takeException(), isNull, reason: why);
    for (final name in long) {
      final text = tester.widget<Text>(caption(name));
      final data = text.data!.replaceAll('⁠', '');
      expect(data, endsWith('…'), reason: '$why $name');
      expect(
        name.startsWith(data.substring(0, data.length - 1).trimRight()),
        isTrue,
        reason: '$why $name → $data',
      );
      expect(text.semanticsLabel, name, reason: '$why $name');
      // 上限で切った名前は2行に入りきる（2行目の終わりで切れていない）。
      expect(
        paragraphOf(tester, name).didExceedMaxLines,
        isFalse,
        reason: '$why $name → $data',
      );
    }
    for (final name in fourteen) {
      expect(
        tester.widget<Text>(caption(name)).data,
        name,
        reason: '$why $name',
      );
      expect(
        paragraphOf(tester, name).didExceedMaxLines,
        isFalse,
        reason: '$why $name',
      );
    }
  }

  testWidgets('the default phone card shows names up to the cap in full', (
    tester,
  ) async {
    await loadAppFonts(tester);
    final home = HomeAppHarness.prepare(
      tester,
      preferences: {'home.projectViewMode.v1': 'small'},
    );
    await home.open(size: const Size(360, 2400), seed: seed);
    expectCapFits(tester, '360 small x1');
    // 決めた長さは全角なら14文字（1行7文字×2行。「…」も1字分）。
    expect(
      shown(tester)[long.first],
      '${long.first.substring(0, 13)}…',
      reason: 'kana',
    );
    await home.close();
  });

  // 7言語で、既定のカードより広いカード（360・1280pxの大・中・小）は上限で
  // 切った名前が2行に入りきり、どのカードでも同じところで切れる。320px・
  // 文字2倍の狭いカードは、2行目の終わりで「…」（はみ出さない）。
  for (final language in ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant']) {
    testWidgets('names are cut at the same place in $language', (tester) async {
      await loadAppFonts(tester);
      Map<String, String>? reference;
      for (final mode in ['small', 'medium', 'large']) {
        final home = HomeAppHarness.prepare(
          tester,
          language: language,
          preferences: {'home.projectViewMode.v1': mode},
        );
        await home.open(size: const Size(360, 2400), seed: seed);
        reference ??= shown(tester);
        for (final width in [320.0, 360.0, 1280.0]) {
          for (final scale in [1.0, 2.0]) {
            await home.resize(Size(width, 2400), textScale: scale);
            final why = '$language $mode $width x$scale';
            expect(tester.takeException(), isNull, reason: why);
            expect(shown(tester), reference, reason: why);
            if (width >= 360 && scale == 1) expectCapFits(tester, why);
          }
        }
        await home.close();
      }
    });
  }
}
