import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/widgets/collection_action_controls.dart';

import 'helpers/home_matrix_harness.dart';

/// ホームのカードの丸い操作（星・︙・フォルダの︙）は、描く丸は今までどおり
/// 40×40のまま、押せる所（と読み上げの枠）がAndroidの決まりの48×48ある。
/// 隣り合う星と︙（詳細の行）は押せる所が重ならず、隙間の真ん中で分かれる
/// （どちらも相手の押す所を取らない）。押せる所の端（辺の真ん中・角の少し
/// 内側）を押すと、その操作に届く。プロジェクト・作品一覧・受け取ったもの・
/// 自分が作成したものの格子と詳細×幅360・412（スマホ）・1280（PC）。
///
/// 以前は押せる所が40×40（丸の外の四隅は押せない）で、Androidの決まりより
/// 小さかった（DISC212）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final run = HomeMatrixRun(Directory('build/collection-action-tap-target'));
  setUpAll(run.prepare);

  Rect globalRect(RenderBox box) => Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );

  /// [node]の画面の上の枠（Androidの決まりの確かめと同じ求め方）。
  Rect nodeRect(SemanticsNode node, double ratio) {
    var rect = node.rect;
    SemanticsNode? current = node;
    while (current != null) {
      final transform = current.transform;
      if (transform != null) rect = MatrixUtils.transformRect(transform, rect);
      current = current.parent;
    }
    return Rect.fromLTRB(
      rect.left / ratio,
      rect.top / ratio,
      rect.right / ratio,
      rect.bottom / ratio,
    );
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

  /// [point]を押すと届く丸い操作（[frames]のどれか。無ければnull）。
  Element? frameAt(WidgetTester tester, Offset point, List<Element> frames) {
    final path = tester.hitTestOnBinding(point).path;
    for (final entry in path) {
      for (final frame in frames) {
        if (under(entry.target, frame.renderObject!)) return frame;
      }
    }
    return null;
  }

  /// 決まり：丸の40×40を、押せる所の48×48が囲む。隣の丸が隙間4pxで
  /// 並ぶ所（詳細の行の星と︙）は隙間の真ん中で分け、残りを外側へ伸ばす。
  Rect expectedTarget(Rect circle, List<Rect> all) {
    const spare = kMinInteractiveDimension - CollectionActionFrame.extent;
    var left = spare / 2;
    var right = spare / 2;
    for (final other in all) {
      if (other == circle || (other.center.dy - circle.center.dy).abs() > 1) {
        continue;
      }
      final gapRight = other.left - circle.right;
      if (gapRight >= 0 && gapRight <= spare) {
        right = gapRight / 2;
        left = spare - right;
      }
      final gapLeft = circle.left - other.right;
      if (gapLeft >= 0 && gapLeft <= spare) {
        left = gapLeft / 2;
        right = spare - left;
      }
    }
    return Rect.fromLTRB(
      circle.left - left,
      circle.top - spare / 2,
      circle.right + right,
      circle.bottom + spare / 2,
    );
  }

  Future<void> chooseViewMode(HomeMatrix m, ProjectViewMode mode) async {
    await m.tester.tap(find.byType(ProjectViewModeMenu));
    await m.frames(6);
    await m.tester.tap(
      find.byType(PopupMenuItem<ProjectViewMode>).at(mode.index),
    );
    await m.frames(6);
  }

  for (final (width, pc) in const [(360, false), (412, false), (1280, true)]) {
    testWidgets('card actions take 48x48 taps without overlapping '
        '(${pc ? 'PC' : 'phone'} $width)', (tester) async {
      final m = HomeMatrix(tester, 'ja', run);
      await m.begin();
      final problems = <String>{};
      var framesChecked = 0;
      final semantics = tester.ensureSemantics();
      try {
        await m.start();
        await m.seedRich();
        await m.setPc(pc);
        await m.resize(
          Size(
            width.toDouble(),
            pc ? kHomeMatrixPcHeight : kHomeMatrixPhoneHeight,
          ),
        );
        final ratio = tester.view.devicePixelRatio;
        for (final view in const [
          HomeView.projects,
          HomeView.works,
          HomeView.sharedReceived,
          HomeView.sharedOutgoing,
        ]) {
          for (final mode in const [null, ProjectViewMode.detail]) {
            await m.show(view);
            if (mode != null) await chooseViewMode(m, mode);
            final cell = '${view.name} ${mode?.name ?? 'grid'}';
            await m.capture(
              'cards_${pc ? 'pc' : 'sp'}_${width}_${view.name}_'
              '${mode?.name ?? 'grid'}',
            );
            // 一覧の中で全体が見えている丸。
            final frames = <Element>[];
            for (final e
                in find
                    .descendant(
                      of: find.byType(TabBarView),
                      matching: find.byType(CollectionActionFrame),
                    )
                    .evaluate()) {
              final box = e.renderObject;
              if (box is! RenderBox || !box.attached || !box.hasSize) continue;
              final rect = globalRect(box);
              if (rect.top < 120 || rect.bottom > m.size.height - 120) continue;
              if (rect.left < 0 || rect.right > m.size.width) continue;
              frames.add(e);
            }
            expect(frames, isNotEmpty, reason: cell);
            final circles = {
              for (final f in frames)
                f: globalRect(f.renderObject! as RenderBox),
            };
            for (final frame in frames) {
              framesChecked++;
              final circle = circles[frame]!;
              // 描く丸は40×40のまま。
              if ((circle.width - CollectionActionFrame.extent).abs() > 0.01 ||
                  (circle.height - CollectionActionFrame.extent).abs() > 0.01) {
                problems.add('$cell: the circle is ${circle.size}');
              }
              final target = expectedTarget(circle, circles.values.toList());
              // 読み上げの枠（押す操作のある枠）は48×48以上。
              final button = find.descendant(
                of: find.byWidget(frame.widget),
                matching: find.byWidgetPredicate(
                  (w) => w is IconButton || w is PopupMenuButton,
                ),
              );
              final node = tester.getSemantics(button.first);
              final data = node.getSemanticsData();
              final rect = nodeRect(node, ratio);
              if (!data.hasAction(ui.SemanticsAction.tap)) {
                problems.add('$cell: the action node has no tap');
              }
              if (rect.width < 48 - 0.01 || rect.height < 48 - 0.01) {
                problems.add(
                  '$cell: the action node is ${rect.size} (circle $circle)',
                );
              }
              // 押せる所の辺の真ん中（1px内側）と、角（5px内側。カードの
              // 角丸の外は押せない）を押すと、この丸に届く。
              final points = <String, Offset>{
                'left': Offset(target.left + 1, target.center.dy),
                'right': Offset(target.right - 1, target.center.dy),
                'top': Offset(target.center.dx, target.top + 1),
                'bottom': Offset(target.center.dx, target.bottom - 1),
                'top-left': target.topLeft + const Offset(5, 5),
                'top-right': target.topRight + const Offset(-5, 5),
                'bottom-left': target.bottomLeft + const Offset(5, -5),
                'bottom-right': target.bottomRight + const Offset(-5, -5),
              };
              for (final MapEntry(key: where, value: point) in points.entries) {
                final hit = frameAt(tester, point, frames);
                if (!identical(hit, frame)) {
                  problems.add(
                    '$cell: the $where edge of the target $target goes to '
                    '${hit == null ? 'no action' : 'another action'}',
                  );
                }
              }
              // 押せる所のすぐ外は、この丸に届かない（隣の丸・カードへ）。
              for (final point in [
                Offset(target.left - 1, target.center.dy),
                Offset(target.right + 1, target.center.dy),
                Offset(target.center.dx, target.top - 1),
                Offset(target.center.dx, target.bottom + 1),
              ]) {
                if (identical(frameAt(tester, point, frames), frame)) {
                  problems.add('$cell: $point outside $target still hits it');
                }
              }
            }
            if (mode != null) {
              await chooseViewMode(
                m,
                pc ? ProjectViewMode.large : ProjectViewMode.small,
              );
            }
          }
        }

        // 実際に押す：プロジェクトの格子の星の外側の辺（丸の外）で
        // お気に入りが替わり、︙の上の辺でメニューが開く。
        await m.show(HomeView.projects);
        final star = find.byWidgetPredicate(
          (w) =>
              w is CollectionFavoriteButton &&
              w.itemId != null &&
              !w.favorite &&
              m.projects.projects.any((p) => p.id == w.itemId),
        );
        // 一覧の中で全体が見えている星（浮かぶボタン・上部バーから離れた所）。
        final visibleStar = star.evaluate().firstWhere((e) {
          final r = globalRect(e.renderObject! as RenderBox);
          return r.top > 150 && r.bottom < m.size.height - 150;
        });
        final starWidget = visibleStar.widget as CollectionFavoriteButton;
        final starCircle = globalRect(visibleStar.renderObject! as RenderBox);
        debugPrint('tapping beside the star at $starCircle');
        await tester.tapAt(Offset(starCircle.left - 3, starCircle.center.dy));
        await m.frames(10);
        // お気に入りの保存（ファイルの書き込み）が終わるまで実時間を進める。
        for (var i = 0; i < 10; i++) {
          await m.settleIo();
        }
        await m.frames(4);
        if (!m.projects.projects
            .firstWhere((p) => p.id == starWidget.itemId)
            .isFavorite) {
          problems.add('tapping 3px left of the star did not favourite it');
        }
        final menu = find.byKey(Key('collectionMenu_${starWidget.itemId}'));
        if (menu.evaluate().isEmpty) {
          // 星の横を押してカード（作品を開く）に届き、ホームを離れた。
          problems.add('tapping 3px left of the star left Home');
        } else {
          final menuCircle = tester.getRect(menu);
          await tester.tapAt(Offset(menuCircle.center.dx, menuCircle.top - 3));
          await m.frames(8);
          if (find.byType(PopupMenuItem<String>).evaluate().isEmpty) {
            problems.add('tapping 3px above the menu did not open it');
          }
          await tester.tapAt(const Offset(5, 5));
          await m.frames(8);
        }
      } finally {
        semantics.dispose();
        debugDisableShadows = true;
      }
      debugPrint('circles checked: $framesChecked');
      expect(problems, isEmpty, reason: problems.join('\n'));
      expect(tester.takeException(), isNull);
    });
  }
}
