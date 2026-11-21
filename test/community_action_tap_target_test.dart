// 作品広場の作品のカード・ランキングの一覧の丸い操作（ブックマーク・︙）は、
// 描く丸は40×40のまま、押せる所が読み上げの枠と同じ48×48ある（DISC240）。
//
// 丸は`CollectionActionFrame`（押せる所と読み上げの枠は丸の外へ4pxずつ）だが、
// 作品のカードは丸を普通の`Row`に並べ、カードの右の余白が2pxしかなく、
// ランキングの大きな絵の︙は絵の角から2px、横長の一覧は︙とブックマークを
// 隙間なく縦に重ね、右の余白が3pxだった。親の箱の外は押しても届かず、
// 読み上げの枠は48×48なのに、押せる所の端（丸の外の帯）は押せないか、
// 隣の丸・カードへ届いた。
//
// 作品のカード（格子）とランキング（横長・大きな絵）×幅360・412（スマホ）・
// 1280（PC）×文字1.0・2.0で、全体が見えている丸ごとに、
// - 描く丸は40×40、読み上げの枠（押す操作のある枠）は48×48以上、
// - 押せる所の辺の真ん中（1px内側）と角（5px内側。カードの角丸の外は
//   押せない）を押すと、その丸に届く、
// - 押せる所のすぐ外（1px外）は、その丸に届かない、
// を見る。あわせて丸の外（押せる所の端の近く）を実際に押して、ブックマークが替わり、
// 作品は開かないことを見る。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/community_work.dart';
import 'package:niarim/screens/community/widgets/community_ranking_work_list.dart';
import 'package:niarim/screens/community/widgets/community_work_card.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:niarim/widgets/collection_action_controls.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

CommunityWork _work(String id, {int rank = 0}) => CommunityWork(
  id: id,
  title: 'Audit title $id with 日本語 and français',
  authorId: 'creator',
  authorName: 'Audit creator',
  viewCount: 1234,
  likeCount: 0,
  bookmarkCount: 4321 - rank,
  postedAt: DateTime.utc(2026, 10, 22),
  durationSeconds: 95,
  thumbnailColorIndex: rank,
);

final _shotKey = GlobalKey();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final shots = Platform.environment['NIARIM_SET4_SHOTS'];

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    binding.platformDispatcher.clearTextScaleFactorTestValue();
  });

  Rect globalRect(RenderBox box) => MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );

  Rect nodeRect(SemanticsNode node) {
    var rect = node.rect;
    SemanticsNode? current = node;
    while (current != null) {
      final transform = current.transform;
      if (transform != null) rect = MatrixUtils.transformRect(transform, rect);
      current = current.parent;
    }
    return rect;
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

  Element? frameAt(WidgetTester tester, Offset point, List<Element> frames) {
    for (final entry in tester.hitTestOnBinding(point).path) {
      for (final frame in frames) {
        if (under(entry.target, frame.renderObject!)) return frame;
      }
    }
    return null;
  }

  /// 決まり：丸の40×40を押せる所の48×48が囲む。隣の丸と隙間8px以下で並ぶ
  /// （横・縦）ところは隙間の真ん中で分け、残りを外側へ伸ばす。
  Rect expectedTarget(Rect circle, Iterable<Rect> all) {
    const spare = kMinInteractiveDimension - CollectionActionFrame.extent;
    var left = spare / 2, right = spare / 2;
    var top = spare / 2, bottom = spare / 2;
    for (final other in all) {
      if (other == circle) continue;
      if ((other.center.dy - circle.center.dy).abs() <= 1) {
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
      if ((other.center.dx - circle.center.dx).abs() <= 1) {
        final gapBelow = other.top - circle.bottom;
        if (gapBelow >= 0 && gapBelow <= spare) {
          bottom = gapBelow / 2;
          top = spare - bottom;
        }
        final gapAbove = circle.top - other.bottom;
        if (gapAbove >= 0 && gapAbove <= spare) {
          top = gapAbove / 2;
          bottom = spare - top;
        }
      }
    }
    return Rect.fromLTRB(
      circle.left - left,
      circle.top - top,
      circle.right + right,
      circle.bottom + bottom,
    );
  }

  Future<void> pumpList(
    WidgetTester tester,
    String kind,
    CommunityService community,
    ThemeData theme, {
    required void Function(String id) onBookmark,
    required void Function(String id) onOpen,
  }) async {
    final works = [_work('a'), _work('b', rank: 1)];
    final Widget list = switch (kind) {
      'grid' => CommunityWorkGrid(
        works: works,
        bookmarkedIds: const {'a'},
        onTapWork: (w) => onOpen(w.id),
        onToggleBookmark: (w) => onBookmark(w.id),
        onTapAuthor: (_) {},
      ),
      _ => CommunityRankingWorkList(
        works: works,
        layout: kind == 'ranking-horizontal'
            ? CommunityRankingLayout.horizontal
            : CommunityRankingLayout.largeThumbnail,
        bookmarkedIds: const {'a'},
        onTapWork: (w) => onOpen(w.id),
        onToggleBookmark: (w) => onBookmark(w.id),
        onTapAuthor: (_) {},
        bottomPadding: 24,
      ),
    };
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: MaterialApp(
          theme: theme,
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChangeNotifierProvider<CommunityService>.value(
            value: community,
            child: Scaffold(body: SingleChildScrollView(child: list)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (width, pc) in const [(360, false), (412, false), (1280, true)]) {
    testWidgets('community card actions take 48x48 taps '
        '(${pc ? 'PC' : 'phone'} $width)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await loadAppFonts(tester);
      final themes = ThemeService();
      await tester.runAsync(themes.init);
      final community = CommunityService();
      await tester.runAsync(() => community.contentFiltersReady);
      final semantics = tester.ensureSemantics();
      final problems = <String>{};
      var checked = 0;
      try {
        tester.view.devicePixelRatio = 1;
        for (final scale in const [1.0, 2.0]) {
          tester.view.physicalSize = Size(width.toDouble(), pc ? 900 : 1600);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          for (final kind in const [
            'grid',
            'ranking-horizontal',
            'ranking-large',
          ]) {
            final opened = <String>[];
            final bookmarked = <String>[];
            // 前の並びで開いたもの（メニュー等）を残さない。
            await tester.pumpWidget(const SizedBox.shrink());
            await pumpList(
              tester,
              kind,
              community,
              themes.themeData,
              onBookmark: bookmarked.add,
              onOpen: opened.add,
            );
            final cell = '$kind x$scale';
            if (shots != null) {
              await tester.runAsync(() async {
                final boundary =
                    _shotKey.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 1);
                final data = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  '$shots/DISC240-${pc ? 'pc' : 'sp'}$width-$kind-x'
                  '${scale.toString().replaceAll('.', '')}.png',
                ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
                image.dispose();
              });
            }
            final frames = <Element>[
              for (final e in find.byType(CollectionActionFrame).evaluate())
                if (e.renderObject case final RenderBox box
                    when box.hasSize &&
                        globalRect(box).bottom <
                            tester.view.physicalSize.height)
                  e,
            ];
            expect(frames, isNotEmpty, reason: cell);
            final circles = {
              for (final f in frames)
                f: globalRect(f.renderObject! as RenderBox),
            };
            for (final frame in frames) {
              checked++;
              final circle = circles[frame]!;
              if ((circle.width - CollectionActionFrame.extent).abs() > 0.01 ||
                  (circle.height - CollectionActionFrame.extent).abs() > 0.01) {
                problems.add('$cell: the circle is ${circle.size}');
              }
              final target = expectedTarget(circle, circles.values);
              final button = find.descendant(
                of: find.byWidget(frame.widget),
                matching: find.byWidgetPredicate(
                  (w) => w is IconButton || w is PopupMenuButton,
                ),
              );
              final node = tester.getSemantics(button.first);
              final rect = nodeRect(node);
              if (!node.getSemanticsData().hasAction(ui.SemanticsAction.tap)) {
                problems.add('$cell: the action at $circle has no tap');
              }
              if (rect.width < 48 - 0.01 || rect.height < 48 - 0.01) {
                problems.add(
                  '$cell: the action node is ${rect.size} (circle $circle)',
                );
              }
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
                    '$cell: the $where edge of the target $target (circle '
                    '$circle) goes to '
                    '${hit == null ? 'no action' : 'another action'}',
                  );
                }
              }
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
            // 実際に押す：ブックマークの丸の外（押せる所の端から2px内側。隣の
            // 丸の側は隣の押せる所なので、丸から離れる3つの向き）。
            final bookmark = find.byKey(const ValueKey('community-bookmark-a'));
            final circle = tester.getRect(bookmark);
            final target = expectedTarget(circle, circles.values);
            final outward = <Offset>[
              Offset(target.left + 2, target.center.dy),
              Offset(target.right - 2, target.center.dy),
              Offset(target.center.dx, target.top + 2),
              Offset(target.center.dx, target.bottom - 2),
            ].where((p) => !circle.inflate(1).contains(p)).take(3).toList();
            for (final point in outward) {
              await tester.tapAt(point);
              await tester.pump(const Duration(milliseconds: 400));
            }
            if (bookmarked.length != outward.length || opened.isNotEmpty) {
              problems.add(
                '$cell: ${outward.length} taps beside the bookmark gave '
                '${bookmarked.length} bookmark toggles and opened '
                '${opened.length} works',
              );
            }
            expect(tester.takeException(), isNull, reason: cell);
          }
        }
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          community.dispose();
          themes.dispose();
        });
      }
      debugPrint('circles checked: $checked');
      for (final p in problems) {
        debugPrint(p);
      }
      expect(problems, isEmpty, reason: '${problems.length} problems');
    });
  }
}
