import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/home_selection_toolbar.dart';

import 'helpers/home_matrix_harness.dart';
import 'helpers/home_matrix2_known_problems.dart';

/// ホームの表示マトリクスの続き（環境）：画面のキーボード・安全な領域
/// （状態バー・ジェスチャー/3ボタンの帯・切り欠き）・動きを減らす設定・
/// 左利きの設定で、ホームを確かめる。
///
/// * キーボード：検索を開いて語を打ったときと、フォルダの名前のダイアログを
///   開いたときに、画面の下をキーボード（スマホ300px、PCは0）が覆う。
///   境目の9幅×スマホ/PC×7言語で、入力欄・ボタンがキーボードの上に見えて
///   押せ、何もはみ出さない。
/// * 安全な領域：390x844（縦）と844x390（横）のスマホで、状態バー・
///   ジェスチャーの帯か3ボタンの帯・カメラの切り欠きがあるとき、全タブ・
///   一番下まで送った一覧・引き出しで、文字と押す物が帯と切り欠きの下に
///   無い（7言語）。
/// * 動きを減らす：タブの切り替え・引き出しの開け閉め・知らせが、次の
///   1フレームで終わる（動かない）。比べるため、設定がオフのときに何フレーム
///   かかるかも記録する。
/// * 左利き：ホームは左利きの設定を使わない作りなので、入り切りで全タブと
///   引き出しの画素が同じ（ja・frは24幅×スマホ/PC、ほかの5言語は3幅）。
///
/// 画像と一覧は`build/home-matrix2/environment`へ出す。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_run.prepare);
  tearDownAll(() {
    _run.writeManifest();
    _run.expectKnownProblemsSeen();
  });

  for (final language in kHomeMatrixLanguages) {
    testWidgets('keyboard shown ($language): search and the folder name '
        'dialog at the boundary widths x phone/PC', (tester) async {
      final m = HomeMatrix(tester, language, _run)..extended = true;
      await m.begin();
      addTearDown(tester.view.resetViewInsets);
      try {
        await m.start();
        await m.seedRich();
        for (final pc in const [false, true]) {
          await m.setPc(pc);
          for (final w in kHomeMatrixBoundaryWidths) {
            await m.resize(
              Size(
                w.toDouble(),
                pc ? kHomeMatrixPcHeight : kHomeMatrixPhoneHeight,
              ),
            );
            await _keyboardSearchCell(m, keyboard: pc ? 0 : 300);
            await _keyboardFolderDialogCell(m, keyboard: pc ? 0 : 300);
          }
        }
      } finally {
        debugDisableShadows = true;
      }
      m.expectNoFailures();
    }, timeout: const Timeout(Duration(minutes: 40)));

    testWidgets('safe-area insets ($language): every tab, the list end and '
        'the drawer, portrait and landscape phone', (tester) async {
      final m = HomeMatrix(tester, language, _run)..extended = true;
      await m.begin();
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetDisplayFeatures);
      addTearDown(tester.view.resetSystemGestureInsets);
      try {
        await m.start();
        await m.seedRich();
        await m.setPc(false);
        for (final insets in _insets) {
          await m.resize(insets.size);
          _applyInsets(tester, insets);
          await m.frames(3);
          for (final view in HomeView.values) {
            await m.cell('safe-${insets.name}', view, captureEnd: true);
          }
          await m.show(HomeView.projects);
          await m.drawerCell('safe-${insets.name}');
        }
      } finally {
        debugDisableShadows = true;
      }
      m.expectNoFailures();
    }, timeout: const Timeout(Duration(minutes: 40)));
  }

  testWidgets('reduced motion: tab switch, drawer and notices end in one '
      'frame', (tester) async {
    final m = HomeMatrix(tester, 'ja', _run)..extended = true;
    await m.begin();
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    try {
      await m.start();
      await m.seedRich();
      for (final language in const ['ja', 'en', 'fr']) {
        await m.setLanguage(language);
        for (final (w, pc) in const [(390, false), (1280, true)]) {
          await m.setPc(pc);
          await m.resize(
            Size(
              w.toDouble(),
              pc ? kHomeMatrixPcHeight : kHomeMatrixPhoneHeight,
            ),
          );
          for (final reduced in const [false, true]) {
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                FakeAccessibilityFeatures(disableAnimations: reduced);
            await m.frames(3);
            await _motionCells(m, reduced: reduced);
          }
        }
      }
    } finally {
      debugDisableShadows = true;
    }
    m.expectNoFailures();
  }, timeout: const Timeout(Duration(minutes: 40)));

  for (final language in kHomeMatrixLanguages) {
    testWidgets(
      'left-handed on ($language): Home is drawn exactly as with it off',
      (tester) async {
        final m = HomeMatrix(tester, language, _run)..extended = true;
        // 画素の比べ合わせだけ（ほかの確かめは他のマトリクスが同じ画面で
        // 行う）。
        m.walkFocus = false;
        await m.begin();
        try {
          await m.start();
          await m.seedRich();
          final everyWidth = language == 'ja' || language == 'fr';
          for (final pc in const [false, true]) {
            await m.setPc(pc);
            for (final w
                in everyWidth
                    ? kHomeMatrixWidths
                    : (pc ? const [760, 1280] : const [320])) {
              await m.resize(
                Size(
                  w.toDouble(),
                  pc ? kHomeMatrixPcHeight : kHomeMatrixPhoneHeight,
                ),
              );
              for (final view in HomeView.values) {
                await m.show(view);
                await _leftHandedCell(m, view.name);
              }
              await m.show(HomeView.projects);
              await tester.tap(find.byKey(const Key('homeMenuButton')));
              await m.frames(8);
              await _leftHandedCell(m, 'drawer');
              final drawer = find.byType(Drawer);
              Navigator.of(tester.element(drawer)).pop();
              await m.frames(8);
            }
          }
        } finally {
          debugDisableShadows = true;
        }
        m.expectNoFailures();
      },
      timeout: const Timeout(Duration(minutes: 40)),
    );
  }
}

final _run = HomeMatrixRun(
  Directory('build/home-matrix2/environment'),
  knownProblems: homeMatrix2Known(const [
    'DISC212',
    'DISC214',
    'DISC215',
    'DISC216',
    'DISC217',
  ]),
);

// ─── キーボード ───────────────────────────────────────────────────────

/// 検索を開いて語を打ち、キーボードを出して確かめる。
Future<void> _keyboardSearchCell(
  HomeMatrix m, {
  required double keyboard,
}) async {
  final tester = m.tester;
  await m.show(HomeView.projects);
  final appBar = find.byType(AppBar);
  await tester.tap(
    find.descendant(of: appBar, matching: find.byIcon(Icons.search)),
  );
  await m.frames(4);
  await tester.enterText(
    find.descendant(of: appBar, matching: find.byType(TextField)),
    'カット',
  );
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  await m.frames(4);
  final field = find.descendant(of: appBar, matching: find.byType(TextField));
  await m.checkScreen(
    'keyboard',
    'search',
    problems: [
      ..._aboveKeyboard(m, keyboard),
      ?_visibleAndPressable(m, 'search field', field, keyboard),
      if (find.byIcon(Icons.search_off).evaluate().isNotEmpty)
        'search for a seeded name found nothing',
    ],
    walk: true,
  );
  tester.view.viewInsets = FakeViewPadding.zero;
  await m.frames(3);
  await tester.tap(
    find.descendant(of: appBar, matching: find.byIcon(Icons.close)),
  );
  await m.frames(6);
}

/// 作品一覧の「新しいフォルダ」で名前のダイアログを開き、キーボードを
/// 出して確かめる。
Future<void> _keyboardFolderDialogCell(
  HomeMatrix m, {
  required double keyboard,
}) async {
  final tester = m.tester;
  final l10n = m.l10n;
  await m.show(HomeView.works);
  await tester.tap(find.byTooltip(l10n.homeAddSheetNewFolder).last);
  await m.frames(8);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  await m.frames(6);
  final dialog = find.byType(AlertDialog);
  final field = find.descendant(of: dialog, matching: find.byType(TextField));
  final create = find.descendant(
    of: dialog,
    matching: find.widgetWithText(FilledButton, l10n.commonCreate),
  );
  final cancel = find.descendant(
    of: dialog,
    matching: find.widgetWithText(TextButton, l10n.commonCancel),
  );
  final problems = <String>[
    if (dialog.evaluate().length != 1)
      'folder name dialog shown ${dialog.evaluate().length} times'
    else ...[
      ?_visibleAndPressable(m, 'folder name field', field, keyboard),
      ?_visibleAndPressable(m, 'cancel', cancel, keyboard),
      if (create.evaluate().length != 1) 'create button missing',
      if (!_inside(m, tester.getRect(dialog), keyboard))
        'dialog ${tester.getRect(dialog)} under the keyboard',
      if (!_focused(field))
        'folder name field not focused when the dialog opens',
    ],
  ];
  await m.checkScreen(
    'keyboard',
    'folder-dialog',
    problems: problems,
    scope: dialog,
  );
  tester.view.viewInsets = FakeViewPadding.zero;
  await m.frames(3);
  if (cancel.evaluate().length == 1) {
    await tester.tap(cancel);
  } else {
    Navigator.of(tester.element(dialog.first)).pop();
  }
  await m.frames(8);
  await m.show(HomeView.projects);
}

bool _focused(Finder field) {
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  return editable.evaluate().length == 1 &&
      (editable.evaluate().single.widget as EditableText).focusNode.hasFocus;
}

bool _inside(HomeMatrix m, Rect rect, double keyboard) =>
    rect.left >= -0.5 &&
    rect.top >= -0.5 &&
    rect.right <= m.size.width + 0.5 &&
    rect.bottom <= m.size.height - keyboard + 0.5;

/// [finder]が1つあり、キーボードの上に全部見えていて、真ん中を押せる。
String? _visibleAndPressable(
  HomeMatrix m,
  String name,
  Finder finder,
  double keyboard,
) {
  final found = finder.evaluate().length;
  if (found != 1) return '$name found $found times';
  final rect = m.tester.getRect(finder);
  if (!_inside(m, rect, keyboard)) return '$name $rect under the keyboard';
  final box = m.tester.renderObject(finder);
  final hit = m.tester
      .hitTestOnBinding(rect.center)
      .path
      .any((entry) => entry.target == box || _isUnder(entry.target, box));
  return hit ? null : '$name not pressable at ${rect.center}';
}

bool _isUnder(HitTestTarget target, RenderObject box) {
  if (target is! RenderObject) return false;
  RenderObject? node = target;
  while (node != null) {
    if (identical(node, box)) return true;
    node = node.parent;
  }
  return false;
}

/// キーボードの覆う所に、押す物・浮かぶボタン・入力欄が無い（縦に送る
/// 一覧の中は、送れば上へ出せるので見ない）。
List<String> _aboveKeyboard(HomeMatrix m, double keyboard) {
  if (keyboard == 0) return const [];
  final top = m.size.height - keyboard;
  final out = <String>[];
  for (final e
      in find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is FloatingActionButton ||
                  w is IconButton ||
                  w is ButtonStyleButton ||
                  w is TextField,
            ),
          )
          .evaluate()) {
    final box = e.renderObject;
    if (box is! RenderBox || !box.attached || !box.hasSize) continue;
    if (box.size.isEmpty) continue;
    var scrolled = false;
    e.visitAncestorElements((a) {
      if (a is StatefulElement &&
          a.state is ScrollableState &&
          (a.state as ScrollableState).position.axis == Axis.vertical) {
        scrolled = true;
        return false;
      }
      return true;
    });
    if (scrolled) continue;
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    if (rect.bottom > top + 0.5) {
      out.add('${e.widget.runtimeType} at $rect under the keyboard (top $top)');
    }
  }
  return out;
}

// ─── 安全な領域 ───────────────────────────────────────────────────────

class _Insets {
  const _Insets(
    this.name,
    this.size, {
    required this.padding,
    required this.cutout,
    this.gestures = EdgeInsets.zero,
  });

  final String name;
  final Size size;
  final EdgeInsets padding;
  final Rect cutout;
  final EdgeInsets gestures;
}

/// 縦（390x844）・横（844x390）のスマホの、ジェスチャーの帯と3ボタンの帯。
/// 切り欠き（カメラ）は縦では上の真ん中、横では左（状態バー・帯の中）。
const _insets = [
  _Insets(
    'portrait-gesture',
    Size(390, 844),
    padding: EdgeInsets.only(top: 47, bottom: 34),
    cutout: Rect.fromLTWH(160, 0, 70, 32),
    gestures: EdgeInsets.only(bottom: 34),
  ),
  _Insets(
    'portrait-buttons',
    Size(390, 844),
    padding: EdgeInsets.only(top: 24, bottom: 48),
    cutout: Rect.fromLTWH(165, 0, 60, 24),
  ),
  _Insets(
    'landscape-gesture',
    Size(844, 390),
    padding: EdgeInsets.only(left: 47, top: 24, bottom: 21),
    cutout: Rect.fromLTWH(0, 160, 32, 70),
    gestures: EdgeInsets.only(bottom: 21),
  ),
  _Insets(
    'landscape-buttons',
    Size(844, 390),
    padding: EdgeInsets.only(left: 47, top: 24, right: 48),
    cutout: Rect.fromLTWH(0, 160, 32, 70),
  ),
];

void _applyInsets(WidgetTester tester, _Insets insets) {
  final p = insets.padding;
  final padding = FakeViewPadding(
    left: p.left,
    top: p.top,
    right: p.right,
    bottom: p.bottom,
  );
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  final g = insets.gestures;
  tester.view.systemGestureInsets = FakeViewPadding(
    left: g.left,
    top: g.top,
    right: g.right,
    bottom: g.bottom,
  );
  tester.view.displayFeatures = [
    ui.DisplayFeature(
      bounds: insets.cutout,
      type: ui.DisplayFeatureType.cutout,
      state: ui.DisplayFeatureState.unknown,
    ),
  ];
}

// ─── 動きを減らす ─────────────────────────────────────────────────────

/// [settled]になるまでの16msのフレームの数（[max]で打ち切る）。
Future<int> _framesUntil(
  WidgetTester tester,
  bool Function() settled, {
  int max = 60,
}) async {
  for (var i = 1; i <= max; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (settled()) return i;
  }
  return max + 1;
}

Future<void> _motionCells(HomeMatrix m, {required bool reduced}) async {
  final tester = m.tester;
  final mode = reduced ? 'reduced' : 'normal';
  // 動きを減らす設定では、押した次のフレームで動きが始まり、その次の
  // フレームまでに終わる（2フレーム）。設定がオフなら数えるだけ。
  final allowed = reduced ? 2 : 60;

  // タブの切り替え：本文のページが次のタブの位置に止まるまで。
  final measured = <String, int>{};
  for (final tab in const [1, 3, 0]) {
    await tester.tap(find.byKey(ValueKey('home_tab_$tab')));
    measured['tab$tab'] = await _framesUntil(tester, () => _pageAt(m, tab));
    await m.frames(6);
  }
  final tabFrames = measured.values.reduce((a, b) => a > b ? a : b);
  await m.checkScreen(
    'motion-$mode',
    'tabs',
    problems: [
      if (tabFrames > allowed)
        'tab switch takes $tabFrames frames with reduced motion '
            '($measured)',
    ],
  );
  m.run.results.last['frames'] = measured;

  // 引き出し：開き切るまで・閉じ切るまで。
  final menu = find.byKey(const Key('homeMenuButton'));
  await tester.tap(menu);
  final open = await _framesUntil(tester, () => _drawerAt(m, open: true));
  await m.frames(6);
  final drawer = find.byType(Drawer);
  Navigator.of(tester.element(drawer)).pop();
  // 見えなくなるまで（画面の外へ出切る）と、ホームを押せるようになる
  // まで（引き出しの幕が無くなり、タブに指が届く）。
  final close = await _framesUntil(tester, () => _drawerAt(m, open: false));
  final released =
      close + await _framesUntil(tester, () => _homePressable(m), max: 90);
  await m.frames(6);
  await m.checkScreen(
    'motion-$mode',
    'drawer',
    problems: [
      if (open > allowed)
        'drawer takes $open frames to open with reduced motion',
      if (close > allowed)
        'drawer takes $close frames to close with reduced motion',
      if (reduced && released > close + 1)
        'drawer leaves an invisible barrier for ${released - close} frames '
            'after closing with reduced motion (Home cannot be pressed)',
    ],
  );
  m.run.results.last['frames'] = {
    'open': open,
    'close': close,
    'pressable': released,
  };

  // 知らせ：作品を1つ選んでコピーした知らせが出切るまで・消え切るまで。
  await m.show(HomeView.projects);
  final card = find.byWidgetPredicate(
    (w) =>
        w is Text &&
        RegExp(r'^カット\d+$').hasMatch(w.data ?? w.textSpan?.toPlainText() ?? ''),
  );
  await tester.longPress(card.first);
  await m.frames(4);
  await tester.tap(
    find.descendant(
      of: find.byType(HomeSelectionToolbar),
      matching: find.byIcon(Icons.content_copy),
    ),
  );
  // 出てくる間・消える間（知らせはあるが出切っていないフレーム）を数える。
  // 動きを減らす設定では、どちらも無い（いきなり出て、いきなり消える）。
  var appearing = 0;
  var fading = 0;
  var shownOnce = false;
  for (var i = 0; i < 400; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    final present = find
        .byWidgetPredicate((w) => w is SnackBar)
        .evaluate()
        .isNotEmpty;
    if (!present) {
      if (shownOnce) break;
      continue;
    }
    final full = _noticeAt(m, shown: true);
    if (full) {
      shownOnce = true;
    } else if (shownOnce) {
      fading++;
    } else {
      appearing++;
    }
  }
  await m.checkScreen(
    'motion-$mode',
    'notice',
    problems: [
      if (!shownOnce) 'copy notice never fully shown',
      if (reduced && appearing > 1)
        'notice slides/fades in for $appearing frames with reduced motion',
      if (reduced && fading > 0)
        'notice fades out for $fading frames with reduced motion',
    ],
  );
  m.run.results.last['frames'] = {'appearing': appearing, 'fading': fading};
  if (find.byType(HomeSelectionToolbar).evaluate().isNotEmpty) {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await m.frames(4);
  }
}

bool _pageAt(HomeMatrix m, int tab) {
  for (final e
      in find
          .descendant(
            of: find.byType(TabBarView),
            matching: find.byType(Scrollable),
          )
          .evaluate()) {
    final state = (e as StatefulElement).state as ScrollableState;
    final p = state.position;
    if (p.axis != Axis.horizontal || !p.hasPixels) continue;
    return (p.pixels - tab * p.viewportDimension).abs() < 0.5;
  }
  return false;
}

/// 引き出しが無く、2つ目のタブの真ん中を押すとそのタブに届く。
bool _homePressable(HomeMatrix m) {
  if (find.byType(Drawer).evaluate().isNotEmpty) return false;
  final tab = find.byKey(const ValueKey('home_tab_1'));
  if (tab.evaluate().length != 1) return false;
  final box = m.tester.renderObject(tab);
  return m.tester
      .hitTestOnBinding(m.tester.getCenter(tab))
      .path
      .any((entry) => _isUnder(entry.target, box));
}

bool _drawerAt(HomeMatrix m, {required bool open}) {
  final drawer = find.byType(Drawer);
  if (drawer.evaluate().isEmpty) return !open;
  final rect = m.tester.getRect(drawer);
  // 右から出る引き出し：開き切ると右端が画面の右端、閉じ切ると画面の外。
  return open
      ? (rect.right - m.size.width).abs() < 0.5
      : rect.left >= m.size.width - 0.5;
}

/// 知らせが出切っている（[shown]）／もう無い。知らせ（アプリの知らせは
/// SnackBarの派生）の中の、出てくる・消えるときの動き（薄さ・高さの割合・
/// ずらし）がどれも終わっている。
bool _noticeAt(HomeMatrix m, {required bool shown}) {
  final bar = find.byWidgetPredicate((w) => w is SnackBar);
  if (bar.evaluate().isEmpty) return !shown;
  if (!shown) return false;
  var full = true;
  void visit(Element e) {
    final w = e.widget;
    if (w is FadeTransition && w.opacity.value < 0.999) full = false;
    if (w is Opacity && w.opacity < 0.999) full = false;
    if (w is Align && (w.heightFactor ?? 1) < 0.999) full = false;
    if (w is SlideTransition && w.position.value != Offset.zero) full = false;
    e.visitChildElements(visit);
  }

  final element = bar.evaluate().first;
  visit(element);
  element.visitAncestorElements((a) {
    final w = a.widget;
    if (w is FadeTransition && w.opacity.value < 0.999) full = false;
    if (w is Opacity && w.opacity < 0.999) full = false;
    return w is! Scaffold;
  });
  return full;
}

// ─── 左利き ───────────────────────────────────────────────────────────

/// 左利きの入り切りで、今の画面の画素が同じか。違えば両方を撮る。
Future<void> _leftHandedCell(HomeMatrix m, String what) async {
  final off = await m.pixels();
  await m.tester.runAsync(() => m.settings.setLeftHanded(true));
  await m.frames(4);
  final on = await m.pixels();
  final name = m.cellName('lefthanded', what);
  final same = off.length == on.length && _sameBytes(off, on);
  if (!same) await m.capture('${name}_on');
  await m.tester.runAsync(() => m.settings.setLeftHanded(false));
  await m.frames(4);
  if (!same) await m.capture('${name}_off');
  m.record(
    name,
    'lefthanded',
    what,
    same ? null : ['${name}_on.png', '${name}_off.png'],
    [if (!same) 'left-handed changes the Home pixels'],
    const [],
  );
}

bool _sameBytes(List<int> a, List<int> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
