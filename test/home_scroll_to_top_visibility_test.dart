import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/home_matrix_harness.dart';

/// ホームのプロジェクトの一覧の「↑」（一番上へ、右下の＋の左。左下は起動画面へ
/// 戻る矢印）は、一覧を上へ戻せる
/// とき（一番上から送ってあるとき）だけ出す。一覧の一番上にいるとき・
/// スクロールできない短い一覧（2件のフォルダ）では出さない。押して一番上へ
/// 戻ったら消える。フォルダへ入って一覧が一番上から始まったら消える。
/// スマホ（390）・PC（1280）×文字1倍・2倍。
///
/// 以前は一覧に1件でもあれば、一番上でもスクロールできないフォルダでも出て、
/// 一番上の左下のカードの名前を隠した（DISC181）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final run = HomeMatrixRun(Directory('build/home-scroll-to-top'));
  setUpAll(run.prepare);

  final arrow = find.byKey(const Key('homeScrollToTopFab'));

  ScrollableState? projectsList(HomeMatrix m) {
    ScrollableState? best;
    var bestArea = 0.0;
    for (final e
        in find
            .descendant(
              of: find.byType(TabBarView),
              matching: find.byType(Scrollable),
            )
            .evaluate()) {
      final state = (e as StatefulElement).state as ScrollableState;
      if (state.position.axis != Axis.vertical) continue;
      final box = e.renderObject;
      if (box is! RenderBox || !box.hasSize) continue;
      final origin = box.localToGlobal(Offset.zero);
      final rect = (origin & box.size).intersect(Offset.zero & m.size);
      if (rect.isEmpty) continue;
      if (rect.width * rect.height > bestArea) {
        bestArea = rect.width * rect.height;
        best = state;
      }
    }
    return best;
  }

  for (final (width, pc) in const [(390, false), (1280, true)]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('the up arrow shows only when the list can go up '
          '(${pc ? 'PC' : 'phone'} $width, text x$scale)', (tester) async {
        final m = HomeMatrix(tester, 'ja', run);
        await m.begin();
        final problems = <String>[];
        try {
          await m.start();
          await m.seedRich();
          await m.seedMoreCuts(pc ? 30 : 6);
          await m.setPc(pc);
          await m.resize(
            Size(
              width.toDouble(),
              pc ? kHomeMatrixPcHeight : kHomeMatrixPhoneHeight,
            ),
          );
          await m.setTextScale(scale);
          await m.show(HomeView.projects);
          final tag = '${pc ? 'pc' : 'sp'}_${width}_x$scale';

          // 一番上：出さない。
          var list = projectsList(m)!;
          expect(list.position.pixels, 0);
          expect(list.position.maxScrollExtent, greaterThan(0));
          if (arrow.evaluate().isNotEmpty) problems.add('shown at the top');
          await m.capture('${tag}_top');

          // 少し送ると出る。
          list.position.jumpTo(120);
          await m.frames(2);
          if (arrow.evaluate().isEmpty) problems.add('not shown after 120px');
          // 途中（一覧の真ん中）の画面を撮る（左下のカードの名前と重なる所の
          // 見本。所有者の判断を仰ぐ資料）。
          list.position.jumpTo(list.position.maxScrollExtent / 2);
          await m.frames(2);
          await m.capture('${tag}_middle');
          // 一番下：出ている（一番下の行は浮かぶボタンの上で終わる）。
          list.position.jumpTo(list.position.maxScrollExtent);
          await m.frames(2);
          if (arrow.evaluate().isEmpty) problems.add('not shown at the end');
          final controls = find.byType(FloatingActionButton);
          final buttonTop = tester.getTopLeft(arrow).dy;
          final viewport = list.context.findRenderObject()! as RenderBox;
          final bottom = viewport
              .localToGlobal(Offset(0, viewport.size.height))
              .dy;
          final tail = find.byKey(const Key('homeProjectListEndClearance'));
          // 起動画面へ戻る矢印・一番上へ・＋。
          expect(controls, findsNWidgets(3));
          expect(
            tester.getSize(tail).height,
            closeTo(bottom - buttonTop + 16, 0.5),
            reason: 'use the actual button clearance',
          );
          expect(tester.getTopLeft(tail).dy, lessThan(buttonTop));
          await m.capture('${tag}_end');

          // 押すと一番上へ戻り、戻ったら消える。
          await tester.tap(arrow);
          await m.frames(12);
          list = projectsList(m)!;
          if (list.position.pixels != 0) {
            problems.add('the arrow left the list at ${list.position.pixels}');
          }
          if (arrow.evaluate().isNotEmpty) {
            problems.add('still shown after going back to the top');
          }

          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          try {
            list.position.jumpTo(120);
            await m.frames(2);
            await tester.tap(arrow);
            expect(
              list.position.pixels,
              0,
              reason: 'reduced motion jumps immediately',
            );
          } finally {
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
          }

          // 送ってからスクロールできない2件のフォルダへ入る：一番上から
          // 始まり、出さない。
          list.position.jumpTo(list.position.maxScrollExtent);
          await m.frames(2);
          expect(arrow, findsOneWidget);
          // フォルダのカードが見える所まで送ってから入る。
          final series = find.text('シリーズ');
          list.position.jumpTo(0);
          await m.frames(2);
          while (series.hitTestable().evaluate().isEmpty &&
              list.position.pixels < list.position.maxScrollExtent) {
            list.position.jumpTo(
              (list.position.pixels + 200).clamp(
                0,
                list.position.maxScrollExtent,
              ),
            );
            await m.frames(1);
          }
          await tester.tap(series.hitTestable().first);
          await m.frames(8);
          list = projectsList(m)!;
          expect(list.position.maxScrollExtent, 0);
          if (arrow.evaluate().isNotEmpty) {
            problems.add('shown in a folder that cannot scroll');
          }
          await m.capture('${tag}_folder');
          // 戻ると、フォルダへ入る前に読んでいた所（送った位置）へ戻るので、
          // そこが一番上でなければ出る。一番上へ送ると消える。
          await tester.binding.handlePopRoute();
          await m.frames(8);
          list = projectsList(m)!;
          final restored = list.position.pixels;
          if ((restored > 0) != arrow.evaluate().isNotEmpty) {
            problems.add(
              'after leaving the folder at $restored px the arrow is '
              '${arrow.evaluate().isEmpty ? 'hidden' : 'shown'}',
            );
          }
          list.position.jumpTo(0);
          await m.frames(2);
          if (arrow.evaluate().isNotEmpty) {
            problems.add('shown after scrolling back to the top by hand');
          }
        } finally {
          debugDisableShadows = true;
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
