import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/home_matrix_harness.dart';

/// 動きを減らす設定で引き出しを閉じたら、引き出しが画面の外へ出た次の
/// フレームから、ホームのタブに指が届く（設定がオフのときと同じ）。
///
/// 以前は、引き出しが2フレームで見えなくなった後も約24フレーム（約0.4秒）、
/// DrawerControllerの透明な幕（BlockSemantics・閉じるためのGestureDetector・
/// ColoredBox）が残り、押してもホームに届かなかった（DISC214）。設定が
/// オンのときAnimationController.flingは速さを200倍にしたばねで動き、値は
/// 0で止まって見えても、ばねが落ち着くまで状態が「閉じた」にならない。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final run = HomeMatrixRun(Directory('build/home-reduced-motion-drawer'));
  setUpAll(run.prepare);

  /// 引き出しが画面の外にある（無い）。
  bool drawerGone(HomeMatrix m) {
    final drawer = find.byType(Drawer);
    if (drawer.evaluate().isEmpty) return true;
    return m.tester.getRect(drawer).left >= m.size.width - 0.5;
  }

  bool under(HitTestTarget target, RenderObject box) {
    if (target is! RenderObject) return false;
    RenderObject? node = target;
    while (node != null) {
      if (identical(node, box)) return true;
      node = node.parent;
    }
    return false;
  }

  /// 2つ目のタブの真ん中を押すと、そのタブに届く（引き出しの幕が無い）。
  bool tabPressable(HomeMatrix m) {
    final tab = find.byKey(const ValueKey('home_tab_1'));
    if (tab.evaluate().length != 1) return false;
    final box = m.tester.renderObject(tab);
    return m.tester
        .hitTestOnBinding(m.tester.getCenter(tab))
        .path
        .any((entry) => under(entry.target, box));
  }

  /// 引き出しを開き切る。
  Future<void> openDrawer(HomeMatrix m) async {
    await m.tester.tap(find.byKey(const Key('homeMenuButton')));
    for (var i = 0; i < 40; i++) {
      await m.tester.pump(const Duration(milliseconds: 16));
    }
    final rect = m.tester.getRect(find.byType(Drawer));
    expect((rect.right - m.size.width).abs(), lessThan(0.5));
  }

  /// 閉じ始めてから、引き出しが出切るまで・タブに届くまでのフレームの数。
  Future<({int gone, int pressable})> measureClose(HomeMatrix m) async {
    int? gone;
    int? pressable;
    for (var i = 1; i <= 90 && pressable == null; i++) {
      await m.tester.pump(const Duration(milliseconds: 16));
      if (gone == null && drawerGone(m)) gone = i;
      if (tabPressable(m)) pressable = i;
    }
    return (gone: gone ?? 91, pressable: pressable ?? 91);
  }

  final closers = <String, Future<void> Function(HomeMatrix m)>{
    'Navigator.pop from the drawer': (m) async {
      Navigator.of(m.tester.element(find.byType(Drawer))).pop();
    },
    'tap on the dimmed screen beside the drawer': (m) async {
      // 引き出しの左の、暗くした所（閉じるための幕）。
      final drawer = m.tester.getRect(find.byType(Drawer));
      await m.tester.tapAt(Offset(drawer.left / 2, m.size.height / 2));
    },
    'system back': (m) async {
      await m.tester.binding.handlePopRoute();
    },
    'fling it closed': (m) async {
      final drawer = m.tester.getRect(find.byType(Drawer));
      await m.tester.flingFrom(drawer.center, const Offset(300, 0), 1500);
    },
    'drag it half-way and let go': (m) async {
      final drawer = m.tester.getRect(find.byType(Drawer));
      final gesture = await m.tester.startGesture(drawer.center);
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(Offset(drawer.width * 0.07, 0));
        await m.tester.pump(const Duration(milliseconds: 16));
      }
      // まだ指で押さえている間は、引き出しが見えたまま残る（途中で消えない）。
      expect(drawerGone(m), isFalse);
      expect(find.byType(Drawer), findsOneWidget);
      await gesture.up();
    },
  };

  for (final reduced in const [true, false]) {
    testWidgets('${reduced ? 'reduced motion' : 'motion on'}: Home takes '
        'taps on the frame after the closed drawer leaves the screen', (
      tester,
    ) async {
      final m = HomeMatrix(tester, 'ja', run);
      await m.begin();
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final results = <String, Object>{};
      final failures = <String>[];
      try {
        await m.start();
        for (final (width, pc) in const [(390, false), (1280, true)]) {
          await m.setPc(pc);
          await m.resize(
            Size(
              width.toDouble(),
              pc ? kHomeMatrixPcHeight : kHomeMatrixPhoneHeight,
            ),
          );
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(disableAnimations: reduced);
          await m.frames(3);
          for (final entry in closers.entries) {
            // マウスで操作するPCでは引き出しを指で引けない。
            if (pc && entry.key.startsWith('fling')) continue;
            if (pc && entry.key.startsWith('drag')) continue;
            await openDrawer(m);
            expect(tabPressable(m), isFalse);
            await entry.value(m);
            final frames = await measureClose(m);
            results['$width ${entry.key}'] = '$frames';
            if (frames.pressable > frames.gone + 1) {
              failures.add(
                '${entry.key} at $width: the drawer left the screen on '
                'frame ${frames.gone}, Home took taps on frame '
                '${frames.pressable}',
              );
            }
            // 設定がオンなら、閉じる動きそのものも1〜2フレーム。
            if (reduced && frames.gone > 2) {
              failures.add(
                '${entry.key} at $width: closing took ${frames.gone} frames',
              );
            }
            // 押せるようになったタブは、実際に押すとそのタブになる。
            await tester.tap(find.byKey(const ValueKey('home_tab_1')));
            await m.frames(10);
            expect(m.tabIndex, 1, reason: entry.key);
            await tester.tap(find.byKey(const ValueKey('home_tab_0')));
            await m.frames(10);
            // 閉じた後も、もう一度開ける。
            expect(find.byType(DrawerController), findsOneWidget);
          }
        }
      } finally {
        debugDisableShadows = true;
      }
      debugPrint('${reduced ? 'reduced' : 'normal'}: $results');
      expect(failures, isEmpty, reason: failures.join('\n'));
      expect(tester.takeException(), isNull);
    });
  }
}
