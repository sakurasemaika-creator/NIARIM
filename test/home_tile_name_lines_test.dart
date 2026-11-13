import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/widgets/folder_thumbnail.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/frame_preview_background.dart';

import 'helpers/home_app_harness.dart';
import 'helpers/load_app_fonts.dart';

/// カードの名前は最大2行・全角16文字（半角32文字）分まで出し、それを
/// 超える分だけ「…」にする（所有者の判断5）。以前は1行で、320px・文字2倍の
/// 小表示では2文字ほどで切れていた（「カッ…」）。
void main() {
  const short = ['カット36', 'Cut 36'];
  // 全角12文字。文字1倍ならどの幅の小表示でも2行に入る（320pxの小で
  // 1行7文字）。文字2倍の狭いカードでは入らず、2行目の終わりで「…」。
  const twelve = '夕暮れの街を歩く猫と少女';
  const folderName = 'フォルダ12';
  const longJa = 'あいうえおかきくけこさしすせそたちつてと';
  const longEn = 'The quick brown fox jumps over the lazy dog';

  Future<void> seed(ProjectService service) async {
    await HomeAppHarness.work(service, longEn);
    await HomeAppHarness.work(service, longJa);
    for (final name in [...short, twelve]) {
      await HomeAppHarness.work(service, name);
    }
    await service.createFolder(folderName);
  }

  Finder caption(String name) => HomeAppHarness.inProjects(
    find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.style?.fontFamily == 'Kuramubon' &&
          (w.semanticsLabel ?? w.data) == name,
    ),
  );

  // カードの絵の欄（作品は紙の色、フォルダはフォルダの絵）。
  List<Rect> pictures(WidgetTester tester) => [
    for (final finder in [
      find.byType(FramePreviewBackground),
      find.byType(FolderThumbnail),
    ])
      for (final element in HomeAppHarness.inProjects(finder).evaluate())
        tester.getRect(find.byElementPredicate((e) => e == element)),
  ];

  void expectTwoLineNames(
    WidgetTester tester,
    String reason, {
    bool twelveFits = true,
  }) {
    expect(tester.takeException(), isNull, reason: reason);
    for (final name in [...short, folderName, if (twelveFits) twelve]) {
      final text = tester.widget<Text>(caption(name));
      expect(text.maxLines, 2, reason: '$reason $name');
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: caption(name), matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse, reason: '$reason $name');
    }
    // 全角16文字（半角32文字）を超える名前は、そこまでで「…」。読み上げは
    // 名前の全部。
    final ja = tester.widget<Text>(caption(longJa));
    expect(ja.data, '${longJa.substring(0, 16)}…', reason: reason);
    expect(ja.semanticsLabel, longJa, reason: reason);
    final en = tester.widget<Text>(caption(longEn));
    expect(en.data, 'The quick brown fox jumps over…', reason: reason);
    expect(en.semanticsLabel, longEn, reason: reason);
    // 同じ行のカードは、名前が1行でも2行でも絵の高さがそろう（名前の帯は
    // いつも2行分）。右上の操作と左下の星が入る高さも残る。
    final rects = pictures(tester);
    expect(rects, isNotEmpty, reason: reason);
    final rows = <double, List<Rect>>{};
    for (final rect in rects) {
      rows.putIfAbsent(rect.top.roundToDouble(), () => []).add(rect);
    }
    for (final row in rows.values) {
      for (final rect in row) {
        expect(rect.height, closeTo(row.first.height, 0.5), reason: reason);
        expect(rect.height, greaterThanOrEqualTo(80), reason: reason);
      }
    }
  }

  testWidgets('320px with 2x text shows short names in full on two lines', (
    tester,
  ) async {
    final home = HomeAppHarness.prepare(tester);
    await home.open(size: const Size(320, 568), textScale: 2, seed: seed);
    expectTwoLineNames(tester, '320 x2', twelveFits: false);
    await home.close();
  });

  testWidgets('360px phones show a 12-character name in full', (tester) async {
    final home = HomeAppHarness.prepare(tester);
    await home.open(size: const Size(360, 800), seed: seed);
    expectTwoLineNames(tester, '360 x1');
    await home.close();
  });

  // 7言語・320/360/1280px・文字1倍/2倍で、名前の帯がはみ出さず、短い名前が
  // 切れず、同じ行の絵の高さがそろう（同梱の書体で描く）。
  for (final language in ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant']) {
    testWidgets('names keep two lines in $language at every width', (
      tester,
    ) async {
      await loadAppFonts(tester);
      final home = HomeAppHarness.prepare(tester, language: language);
      await home.open(size: const Size(320, 568), seed: seed);
      for (final width in [320.0, 360.0, 1280.0]) {
        for (final scale in [1.0, 2.0]) {
          await home.resize(Size(width, 800), textScale: scale);
          expectTwoLineNames(
            tester,
            '$language $width x$scale',
            twelveFits: scale == 1 || width == 1280,
          );
        }
      }
      await home.close();
    });
  }
}
