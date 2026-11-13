import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/widgets/collection_action_controls.dart';

import 'helpers/home_app_harness.dart';
import 'helpers/load_app_fonts.dart';

/// ホームの表示サイズ（大・中・小）は、どの幅でも列数が違う。基準の幅だけで
/// 列数を決めると、スマホの幅では近い2つのサイズが同じ列数になり、選んでも
/// 何も変わらなかった（360pxで大と中、390〜430pxで中と小）。スマホは
/// 大1列・中2列・小3列。もともと違っていた幅（480px以上）は変えない。
///
/// 分割画面・ポップアップの窓・折りたたみ端末のカバー画面のような狭い窓
/// でも、幅260pxまでは3つとも違う列数にする（小のカードが幅76px以上に
/// なる間は小を3列にする）。それより狭いと3列のカードに右上のメニューと
/// 左下の星が並ばないので、大と中が同じ1列になる。
void main() {
  const widths = [
    240.0,
    250.0,
    260.0,
    280.0,
    300.0,
    320.0,
    360.0,
    390.0,
    412.0,
    430.0,
    480.0,
    600.0,
    800.0,
    1280.0,
  ];
  // 幅ごとの[大, 中, 小]の列数。
  final expected = <double, List<int>>{
    240: [1, 1, 2],
    250: [1, 1, 2],
    260: [1, 2, 3],
    280: [1, 2, 3],
    300: [1, 2, 3],
    320: [1, 2, 3],
    360: [1, 2, 3],
    390: [1, 2, 3],
    412: [1, 2, 3],
    430: [1, 2, 3],
    480: [2, 3, 4],
    600: [3, 4, 5],
    800: [4, 5, 6],
    1280: [6, 8, 10],
  };

  // 一番上の行のカードの数。
  int columns(WidgetTester tester, Finder cards) {
    final tops = <double, int>{};
    for (final element in cards.evaluate()) {
      final rect = tester.getRect(find.byElementPredicate((e) => e == element));
      tops.update(rect.top.roundToDouble(), (n) => n + 1, ifAbsent: () => 1);
    }
    final first = tops.keys.reduce((a, b) => a < b ? a : b);
    return tops[first]!;
  }

  const modes = ['large', 'medium', 'small'];

  for (final (index, mode) in modes.indexed) {
    testWidgets('$mode cards use their own column count at every width', (
      tester,
    ) async {
      final home = HomeAppHarness.prepare(
        tester,
        preferences: {'home.projectViewMode.v1': mode},
      );
      await home.open(
        size: const Size(1280, 900),
        seed: (service) async {
          for (var i = 0; i < 12; i++) {
            await HomeAppHarness.work(service, 'カット$i');
          }
        },
      );
      for (final width in widths) {
        await home.resize(Size(width, 2400));
        expect(
          columns(
            tester,
            find.descendant(
              of: find.byType(ProjectListWidget),
              matching: find.byType(Card),
            ),
          ),
          expected[width]![index],
          reason: '$mode at $width',
        );
        expect(tester.takeException(), isNull, reason: '$mode at $width');
        // 狭いカードでも、右上のメニューと左下の星が重ならない。
        for (final card
            in find
                .descendant(
                  of: find.byType(ProjectListWidget),
                  matching: find.byType(Card),
                )
                .evaluate()) {
          Rect rectOf(Type type) => tester.getRect(
            find
                .descendant(
                  of: find.byElementPredicate((e) => e == card),
                  matching: find.byType(type),
                )
                .first,
          );
          final menu = rectOf(CollectionActionFrame);
          final star = rectOf(CollectionFavoriteButton);
          expect(
            menu.overlaps(star),
            isFalse,
            reason: '$mode at $width: $menu $star',
          );
        }
      }
      await home.close();
    });
  }

  // 作品一覧のカードも同じ列数（同じ並べ方を使う）。
  testWidgets('exported works follow the same column counts', (tester) async {
    for (final (index, mode) in modes.indexed) {
      final home = HomeAppHarness.prepare(
        tester,
        preferences: {'home.worksViewMode.v1': mode},
      );
      final exports = Directory('${home.dir.path}/exports')..createSync();
      for (var i = 0; i < 4; i++) {
        File('${exports.path}/clip$i.gif').writeAsBytesSync(
          base64Decode(
            'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
          ),
        );
      }
      await tester.runAsync(
        () => ExportEngine.listExportedFiles(forceRefresh: true),
      );
      await home.open(size: const Size(360, 2400));
      await tester.tap(find.byKey(const ValueKey('home_tab_1')));
      await tester.pumpAndSettle();
      final cards = find.ancestor(
        of: find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.semanticsLabel ?? w.data)?.startsWith('clip') == true,
        ),
        matching: find.byType(Card),
      );
      expect(columns(tester, cards), expected[360.0]![index], reason: mode);
      expect(tester.takeException(), isNull);
      await home.close();
    }
  });

  // 小が3列になった狭い幅（260〜295px）でも、7言語・文字1倍/2倍でカードが
  // はみ出さない（同梱の書体）。
  for (final language in ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant']) {
    testWidgets('narrow small cards fit in $language', (tester) async {
      await loadAppFonts(tester);
      final home = HomeAppHarness.prepare(
        tester,
        language: language,
        preferences: {'home.projectViewMode.v1': 'small'},
      );
      await home.open(
        size: const Size(260, 1600),
        seed: (service) async {
          await service.createFolder('フォルダ');
          for (final name in ['カット1', 'Morning walk', '애니메이션 연습']) {
            await HomeAppHarness.work(service, name);
          }
        },
      );
      for (final width in [260.0, 280.0, 295.0]) {
        for (final scale in [1.0, 2.0]) {
          await home.resize(Size(width, 1600), textScale: scale);
          expect(
            tester.takeException(),
            isNull,
            reason: '$language $width x$scale',
          );
        }
      }
      await home.close();
    });
  }
}
