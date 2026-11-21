import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/folder_thumbnail.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/frame_preview_background.dart';

import 'helpers/home_app_harness.dart';
import 'helpers/load_app_fonts.dart';

/// 検索の結果はフォルダの階層をまたぐので、どのフォルダの中にあるかを
/// 添える（同じ名前の作品が別々のフォルダにあると見分けられなかった）。
/// カードは名前の下に場所の行、詳細表示は「フォルダ：…」。
void main() {
  final ja = lookupAppLocalizations(const Locale('ja'));

  Future<void> seed(ProjectService service) async {
    final first = await service.createFolder('第1話');
    final inner = await service.createFolder('Aパート', parentFolderId: first.id);
    await HomeAppHarness.work(service, 'シーン1');
    await HomeAppHarness.work(service, 'シーン1', folderId: first.id);
    await HomeAppHarness.work(service, 'シーン1', folderId: inner.id);
  }

  Future<void> search(WidgetTester tester, String query) async {
    if (find.byKey(const Key('homeSearchInput')).evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('homeSearchButton')));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byKey(const Key('homeSearchInput')), query);
    await tester.pumpAndSettle();
  }

  Finder inList(Finder finder) => HomeAppHarness.inProjects(finder);

  // カードの絵の欄の大きさ。
  List<Rect> pictures(WidgetTester tester) => [
    for (final finder in [
      find.byType(FramePreviewBackground),
      find.byType(FolderThumbnail),
    ])
      for (final element in inList(finder).evaluate())
        tester.getRect(find.byElementPredicate((e) => e == element)),
  ];

  void expectPicturesKept(WidgetTester tester, String why) {
    final rects = pictures(tester);
    expect(rects, isNotEmpty, reason: why);
    final rows = <double, List<Rect>>{};
    for (final rect in rects) {
      rows.putIfAbsent(rect.top.roundToDouble(), () => []).add(rect);
    }
    for (final row in rows.values) {
      for (final rect in row) {
        expect(rect.height, closeTo(row.first.height, 0.5), reason: why);
        expect(rect.height, greaterThanOrEqualTo(80), reason: why);
      }
    }
  }

  testWidgets('search results on cards say which folder they are in', (
    tester,
  ) async {
    final home = HomeAppHarness.prepare(tester);
    await home.open(size: const Size(390, 844), seed: seed);
    // 探していない間は場所を出さない（今のフォルダの中だけを出している）。
    expect(inList(find.text('第1話')), findsOneWidget);
    await search(tester, 'シーン1');
    expect(inList(find.text('シーン1')), findsNWidgets(3));
    expect(inList(find.text('第1話')), findsOneWidget);
    expect(inList(find.text('第1話 / Aパート')), findsOneWidget);
    // フォルダの結果にも、そのフォルダが入っているフォルダを添える。
    await search(tester, 'パート');
    expect(inList(find.text('Aパート')), findsOneWidget);
    expect(inList(find.text('第1話')), findsOneWidget);
    expectPicturesKept(tester, '390 x1');
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('search results in detail rows say which folder', (tester) async {
    final home = HomeAppHarness.prepare(
      tester,
      preferences: {'home.projectViewMode.v1': 'detail'},
    );
    await home.open(seed: seed);
    await search(tester, 'シーン1');
    expect(
      inList(find.textContaining(ja.projectListInFolder('第1話 / Aパート'))),
      findsOneWidget,
    );
    expect(
      inList(find.textContaining(ja.projectListInFolder('第1話'))),
      findsNWidgets(2),
    );
    expect(tester.takeException(), isNull);
    await home.close();
  });

  // 場所の行を足しても、文字2倍の狭いカードの絵の欄（右上の操作と左下の星が
  // 入る高さ）を保ち、同じ行の絵の高さがそろう。7言語・320/360/1280px。
  for (final language in ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant']) {
    testWidgets('search locations fit in $language', (tester) async {
      await loadAppFonts(tester);
      final home = HomeAppHarness.prepare(tester, language: language);
      await home.open(size: const Size(320, 640), seed: seed);
      await search(tester, 'シーン1');
      for (final width in [320.0, 360.0, 1280.0]) {
        for (final scale in [1.0, 2.0]) {
          await home.resize(Size(width, 900), textScale: scale);
          final why = '$language $width x$scale';
          expect(tester.takeException(), isNull, reason: why);
          expect(inList(find.text('第1話')), findsOneWidget, reason: why);
          expectPicturesKept(tester, why);
        }
      }
      await home.close();
    });
  }
}
