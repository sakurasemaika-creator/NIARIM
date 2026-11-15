import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/home_matrix_harness.dart';

/// 動きを減らす設定（端末の「アニメーションを削除」＝disableAnimations）では、
/// ホームのタブを切り替えると本文がその場で次のタブになる（横に滑らない）。
/// 設定がオフなら今までどおり滑る。
///
/// 以前はTabBarの切り替え（TabControllerの既定の約300ms）がこの設定を見て
/// おらず、本文が19〜20フレームかけて横に滑った（DISC213）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final run = HomeMatrixRun(Directory('build/home-reduced-motion-tabs'));
  setUpAll(run.prepare);

  /// 本文のページ（横に送るスクロール）の位置。
  ScrollPosition pages() {
    for (final e
        in find
            .descendant(
              of: find.byType(TabBarView),
              matching: find.byType(Scrollable),
            )
            .evaluate()) {
      final p = ((e as StatefulElement).state as ScrollableState).position;
      if (p.axis == Axis.horizontal) return p;
    }
    throw StateError('no page view');
  }

  bool at(int tab) {
    final p = pages();
    return (p.pixels - tab * p.viewportDimension).abs() < 0.5;
  }

  /// [tab]のページに止まるまでの16msのフレームの数（[max]で打ち切る）。
  Future<int> framesUntil(WidgetTester tester, int tab, {int max = 60}) async {
    for (var i = 1; i <= max; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (at(tab)) return i;
    }
    return max + 1;
  }

  for (final (width, pc) in const [(390, false), (1280, true)]) {
    testWidgets('reduced motion: tapping a tab shows it on the next frame '
        '(${pc ? 'PC' : 'phone'} $width)', (tester) async {
      final m = HomeMatrix(tester, 'ja', run);
      await m.begin();
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      try {
        await m.start();
        await m.setPc(pc);
        await m.resize(
          Size(
            width.toDouble(),
            pc ? kHomeMatrixPcHeight : kHomeMatrixPhoneHeight,
          ),
        );
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        await m.frames(3);
        final measured = <String, int>{};
        // 隣のタブ・離れたタブ・最初のタブへ戻る。
        for (final tab in const [1, 3, 0, 2]) {
          await tester.tap(find.byKey(ValueKey('home_tab_$tab')));
          measured['tab$tab'] = await framesUntil(tester, tab);
          // 止まった後も動かない（行き過ぎて戻ることもない）。
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(at(tab), isTrue, reason: 'tab $tab moved after it stopped');
          }
        }
        debugPrint('reduced motion ($width): $measured');
        expect(
          measured.values.every((frames) => frames == 1),
          isTrue,
          reason: 'frames until the tab is shown: $measured',
        );

        // キーボードで選んだタブも（矢印で移ってEnter）その場で切り替わる。
        await tester.tap(find.byKey(const ValueKey('home_tab_0')));
        await m.frames(4);
        Focus.of(
          tester.element(find.byKey(const ValueKey('home_tab_1'))),
        ).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(await framesUntil(tester, 1), 1);
      } finally {
        debugDisableShadows = true;
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('motion on: the tab switch still slides as before '
        '(${pc ? 'PC' : 'phone'} $width)', (tester) async {
      final m = HomeMatrix(tester, 'ja', run);
      await m.begin();
      try {
        await m.start();
        await m.setPc(pc);
        await m.resize(
          Size(
            width.toDouble(),
            pc ? kHomeMatrixPcHeight : kHomeMatrixPhoneHeight,
          ),
        );
        final measured = <String, int>{};
        for (final tab in const [1, 3, 0]) {
          await tester.tap(find.byKey(ValueKey('home_tab_$tab')));
          measured['tab$tab'] = await framesUntil(tester, tab);
          await m.frames(6);
        }
        debugPrint('motion on ($width): $measured');
        // TabControllerの既定（300ms）で、16msのフレームが18〜20回。
        for (final frames in measured.values) {
          expect(frames, inInclusiveRange(15, 22), reason: '$measured');
        }
      } finally {
        debugDisableShadows = true;
      }
      expect(tester.takeException(), isNull);
    });
  }
}
