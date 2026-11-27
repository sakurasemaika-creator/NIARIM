import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/widgets/collection_action_controls.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/home_selection_toolbar.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';

import 'helpers/home_matrix_harness.dart';

/// 横向きのスマホ（844x390）で、左にカメラの切り欠き（安全な領域の左47px）・
/// 右に3ボタンの帯（右48px）があるとき、ホームのタブの本文（お気に入り・
/// 並び順・ゴミ箱の種類・カードの星・名前・︙・ゴミ箱の操作）と浮かぶボタンは、
/// 左右の安全な領域の中に描かれ、切り欠きの下に来ない（上部バーと同じ）。
/// 縦向き（左右の帯が無い）では今までと同じ所に描く。
///
/// 以前は本文と浮かぶボタンが左右の安全な領域を見ておらず、切り欠きと帯の
/// 下に描かれた（DISC216）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final run = HomeMatrixRun(Directory('build/home-landscape-side-insets'));
  setUpAll(run.prepare);

  void apply(
    WidgetTester tester,
    EdgeInsets p,
    Rect cutout, {
    double gestureBottom = 0,
  }) {
    final padding = FakeViewPadding(
      left: p.left,
      top: p.top,
      right: p.right,
      bottom: p.bottom,
    );
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
    tester.view.systemGestureInsets = FakeViewPadding(bottom: gestureBottom);
    tester.view.displayFeatures = [
      ui.DisplayFeature(
        bounds: cutout,
        type: ui.DisplayFeatureType.cutout,
        state: ui.DisplayFeatureState.unknown,
      ),
    ];
  }

  Rect globalRect(RenderBox box) => Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );

  List<ScrollableState> scrollAncestors(Element e) {
    final out = <ScrollableState>[];
    e.visitAncestorElements((a) {
      if (a is StatefulElement && a.state is ScrollableState) {
        out.add(a.state as ScrollableState);
      }
      return true;
    });
    return out;
  }

  /// 本文・浮かぶボタンの文字と押す物のうち、左右の安全な領域の外・切り欠き
  /// の下にあるもの。
  List<String> outside(
    HomeMatrix m,
    EdgeInsets p,
    Rect cutout, {
    Type scope = HomeScreen,
  }) {
    final safe = Rect.fromLTRB(
      p.left,
      p.top,
      m.size.width - p.right,
      m.size.height - p.bottom,
    );
    final out = <String>{};
    bool isAction(Widget w) =>
        w is IconButton ||
        w is ButtonStyleButton ||
        w is FloatingActionButton ||
        w is PopupMenuButton ||
        w is FilterChip ||
        w is RichText;
    for (final e
        in find
            .descendant(
              of: find.byType(scope),
              matching: find.byWidgetPredicate(isAction),
            )
            .evaluate()) {
      // 上部バー（タブを含む）は前から避けている。ここでは本文と浮かぶボタン。
      var inAppBar = false;
      e.visitAncestorElements((a) {
        inAppBar = a.widget is AppBar;
        return !inAppBar;
      });
      if (inAppBar) continue;
      final box = e.renderObject;
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      if (box.size.isEmpty) continue;
      final rect = globalRect(box);
      if (!rect.overlaps(Offset.zero & m.size)) continue;
      var inView = true;
      for (final s in scrollAncestors(e)) {
        final r = globalRect(s.context.findRenderObject()! as RenderBox);
        if (!(rect.left >= r.left - 0.5 &&
            rect.right <= r.right + 0.5 &&
            rect.top >= r.top - 0.5 &&
            rect.bottom <= r.bottom + 0.5)) {
          inView = false;
        }
      }
      if (!inView) continue;
      final what = e.widget is RichText
          ? 'text "${(e.widget as RichText).text.toPlainText()}"'
          : e.widget.runtimeType.toString();
      if (rect.left < safe.left - 0.5 || rect.right > safe.right + 0.5) {
        out.add('$what outside the side safe area: $rect');
      }
      if (cutout.overlaps(rect)) out.add('$what under the cutout: $rect');
    }
    return out.toList();
  }

  ScrollableState? content(HomeMatrix m) {
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
      final rect = globalRect(box).intersect(Offset.zero & m.size);
      if (rect.isEmpty) continue;
      if (rect.width * rect.height > bestArea) {
        bestArea = rect.width * rect.height;
        best = state;
      }
    }
    return best;
  }

  testWidgets('landscape: tab bodies and floating buttons stay inside the '
      'left/right safe area and off the cutout', (tester) async {
    final m = HomeMatrix(tester, 'ja', run);
    await m.begin();
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetDisplayFeatures);
    addTearDown(tester.view.resetSystemGestureInsets);
    final problems = <String>[];
    try {
      await m.start();
      await m.seedRich();
      await m.resize(const Size(844, 390));
      for (final (name, padding, gesture) in const [
        ('gesture', EdgeInsets.only(left: 47, top: 24, bottom: 21), 21.0),
        ('buttons', EdgeInsets.only(left: 47, top: 24, right: 48), 0.0),
      ]) {
        const cutout = Rect.fromLTWH(0, 160, 32, 70);
        apply(tester, padding, cutout, gestureBottom: gesture);
        await m.frames(3);
        for (final view in HomeView.values) {
          await m.show(view);
          for (final p in outside(m, padding, cutout)) {
            problems.add('$name ${view.name}: $p');
          }
          await m.capture('landscape_${name}_${view.name}');
          // 一番下まで送ったところも。
          final scrollable = content(m);
          if (scrollable != null && scrollable.position.maxScrollExtent > 0) {
            scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
            await m.frames(3);
            for (final p in outside(m, padding, cutout)) {
              problems.add('$name ${view.name} (end): $p');
            }
            scrollable.position.jumpTo(0);
            await m.frames(2);
          }
        }
        // 上部バーの続きの帯（選択中の操作・貼り付け）も。帯の色は端まで。
        await m.show(HomeView.projects);
        final cards = find
            .descendant(
              of: find.byType(ProjectListWidget),
              matching: find.byWidgetPredicate(
                (widget) => switch (widget) {
                  ListTile(:final onLongPress) => onLongPress != null,
                  // 作品のカード（ダブルタップでキャンバスを開く）。
                  RawGestureDetector(:final gestures) => gestures.containsKey(
                    CollectionCardDoubleTapRecognizer,
                  ),
                  _ => false,
                },
              ),
            )
            .hitTestable();
        expect(cards, findsWidgets);
        await tester.longPress(cards.first);
        await m.frames(4);
        expect(find.byType(HomeSelectionToolbar), findsOneWidget);
        for (final p in outside(m, padding, cutout)) {
          problems.add('$name selection: $p');
        }
        await m.capture('landscape_${name}_selection');
        await tester.tap(
          find.descendant(
            of: find.byType(HomeSelectionToolbar),
            matching: find.byIcon(Icons.content_copy),
          ),
        );
        await m.frames(6);
        expect(find.byKey(const Key('homeClipboardToolbar')), findsOneWidget);
        for (final p in outside(m, padding, cutout)) {
          problems.add('$name clipboard: $p');
        }
        await m.capture('landscape_${name}_clipboard');
        await tester.tap(find.byKey(const Key('homeClearClipboardButton')));
        await m.frames(6);
        // 引き出し（右から出る）も、右の帯の下に字・押す物を描かない。
        // 見出しの説明が長いフランス語でも。
        for (final language in const ['ja', 'fr']) {
          await m.setLanguage(language);
          await tester.tap(find.byKey(const Key('homeMenuButton')));
          await m.frames(8);
          for (final p in outside(m, padding, cutout, scope: Drawer)) {
            problems.add('$name drawer ($language): $p');
          }
          await m.capture('landscape_${name}_drawer_$language');
          Navigator.of(tester.element(find.byType(Drawer))).pop();
          await m.frames(8);
        }
        await m.setLanguage('ja');
      }
    } finally {
      debugDisableShadows = true;
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait (no side insets): the tab body and the floating '
      'buttons span the whole width as before', (tester) async {
    final m = HomeMatrix(tester, 'ja', run);
    await m.begin();
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetDisplayFeatures);
    addTearDown(tester.view.resetSystemGestureInsets);
    try {
      await m.start();
      await m.seedRich();
      await m.resize(const Size(390, kHomeMatrixPhoneHeight));
      apply(
        tester,
        const EdgeInsets.only(top: 47, bottom: 34),
        const Rect.fromLTWH(160, 0, 70, 32),
        gestureBottom: 34,
      );
      await m.frames(3);
      for (final view in HomeView.values) {
        await m.show(view);
        final body = globalRect(
          tester.renderObject<RenderBox>(find.byType(TabBarView)),
        );
        expect(body.left, 0, reason: view.name);
        expect(body.right, 390, reason: view.name);
        await m.capture('portrait_${view.name}');
      }
      await m.show(HomeView.projects);
      // 右下の＋は右の端から16px、左下の「↑」は左の端から16px（今までどおり）。
      final fabs = find.byType(FloatingActionButton).evaluate().toList();
      final rects = [
        for (final e in fabs) globalRect(e.renderObject! as RenderBox),
      ]..sort((a, b) => a.left.compareTo(b.left));
      expect(rects.last.right, 390 - 16);
      if (rects.length > 1) expect(rects.first.left, 16);
    } finally {
      debugDisableShadows = true;
    }
    expect(tester.takeException(), isNull);
  });
}
