// [KeepTogetherText]を並べた一覧を、欄の幅を変えて並べ直す手間（DISC130 の
// レビュー）。
//
// 欄の幅でつなぎ方を決めるようになってから、部品が作り直されるたびに
// つなぎ方を決め直し（文を並べ直し）、測るための[TextPainter]を毎回作って
// 捨てていた。「受け取る」のボタンの横か下に文を置く行（[ActionBesideOrBelow]）
// を300行、幅を12通りに3回ずつ変えると、DISC130 より前の倍以上の時間が
// かかった。
//
// 時間はほかの作業と共有する端末で揺れるので、数で確かめる：並べ直しで
// 新しい[TextPainter]を作らない、1行に入る文は並べずに決める、同じ幅で
// 決めたつなぎ方は覚えておいて使い回す（[KeepTogetherText.debugLayoutCount]
// ＝部品が自分で文を並べた回数）。
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/config/font_fallback.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/widgets/action_beside_or_below.dart';
import 'package:niarim/widgets/keep_together_text.dart';

import 'helpers/load_app_fonts.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('ja'));
  final widths = [for (var w = 200.0; w < 320; w += 10) w];

  // (説明, 行の文と、途中で切らない部分)
  final lists = <(String, List<(String, String)>)>[
    (
      '1行に入る文（日数とオパール）',
      [
        for (var i = 0; i < 300; i++)
          (
            '${l.recurringMissionProgress(i % 7, 7)} · '
                '${l.coinAmount(100 + i)}',
            l.coinAmount(100 + i),
          ),
      ],
    ),
    (
      '折り返す文（確定単価による合計）',
      [
        for (var i = 0; i < 100; i++)
          (
            l.rewardUnlockReviewFixedTotal(l.coinAmount(55000 + i)),
            l.coinAmount(55000 + i),
          ),
      ],
    ),
  ];

  for (final (what, rows) in lists) {
    testWidgets('幅を変えて並べ直しても、測るための部品を作り直さず、決めた'
        'つなぎ方を使い回す（$what, ${rows.length}行）', (tester) async {
      await loadAppFonts(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 3000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget list(double width) => MaterialApp(
        home: Material(
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'HakkouMincho',
              fontFamilyFallback: kBodyFontFallback,
              fontSize: 14,
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: 3000,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final (i, (text, keep)) in rows.indexed)
                        ActionBesideOrBelow(
                          key: ValueKey(i),
                          text: KeepTogetherText(text, keep: [keep]),
                          action: const SizedBox(width: 80, height: 20),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      var created = 0;
      void count(ObjectEvent event) {
        if (event is ObjectCreated && event.className == 'TextPainter') {
          created++;
        }
      }

      await tester.pumpWidget(list(300));
      FlutterMemoryAllocations.instance.addListener(count);
      addTearDown(
        () => FlutterMemoryAllocations.instance.removeListener(count),
      );
      final layouts = <int>[];
      for (var round = 0; round < 3; round++) {
        KeepTogetherText.debugLayoutCount = 0;
        for (final w in widths) {
          await tester.pumpWidget(list(w));
        }
        layouts.add(KeepTogetherText.debugLayoutCount);
      }
      debugPrint(
        '$what: TextPainter $created個, 部品が並べた回数 ${layouts.join(' / ')}',
      );
      expect(tester.takeException(), isNull);
      // 並べ直しでは、測るための部品（と中の段落）を作り直さない。
      expect(created, 0);
      // 1回目の12通りの幅でも、1行・1つの幅につき並べるのは数回まで
      // （つなぎ方を決めるのに数回、高さ等を測るのに1回）。
      expect(layouts.first, lessThanOrEqualTo(rows.length * widths.length * 3));
      // 2回目・3回目は、同じ幅で決めたつなぎ方を使い回す。
      expect(layouts.skip(1), everyElement(0));
    });
  }
}
