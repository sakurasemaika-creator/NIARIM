import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/widgets/sort_mode_control.dart';

import 'helpers/home_matrix_harness.dart';

/// ホームの引き出しの5つの行き先（コイン・特典／契約状態／使い方／設定／
/// 容量削減）を、本物のアプリで押して開き、戻ってくる。
///
/// 開く前のホームの状態（タブ・一覧の位置・並び順・共有のどちらの一覧か・
/// ゴミ箱の種類の絞り込み）を作っておき、行き先の画面が開くこと（場所と、
/// ホームが一番上でなくなったこと）、戻ると引き出しは閉じてホームが一番上に
/// 戻り、状態がそのまま残ることを確かめる。戻り方は、端末の「戻る」と、
/// 行き先の上部バーの戻るボタン（あれば）を交互に使う。
///
/// ja・enは4つのタブの状態×5つの行き先×スマホ390/PC1280、ほかの5言語は
/// プロジェクトのタブ×5つの行き先×スマホ390。行き先の画面を撮って
/// `build/home-matrix2/drawer-links`へ出す。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_run.prepare);
  tearDownAll(_run.writeManifest);

  for (final language in kHomeMatrixLanguages) {
    final every = language == 'ja' || language == 'en';
    testWidgets('drawer links ($language): open each destination and come '
        'back with the Home state kept', (tester) async {
      final m = HomeMatrix(tester, language, _run);
      await m.begin();
      try {
        await m.start();
        await m.seedRich();
        for (final (w, pc)
            in every
                ? const [(390, false), (1280, true)]
                : const [(390, false)]) {
          await m.setPc(pc);
          await m.resize(
            Size(
              w.toDouble(),
              pc ? kHomeMatrixPcHeight : kHomeMatrixPhoneHeight,
            ),
          );
          for (final view
              in every
                  ? const [
                      HomeView.projects,
                      HomeView.works,
                      HomeView.sharedOutgoing,
                      HomeView.trash,
                    ]
                  : const [HomeView.projects]) {
            await m.show(view);
            await _makeState(m, view);
            for (final (index, link) in _links.indexed) {
              await _roundTrip(m, view, link, systemBack: index.isEven);
            }
            await _undoState(m, view);
          }
        }
      } finally {
        debugDisableShadows = true;
      }
      m.expectNoFailures();
    }, timeout: const Timeout(Duration(minutes: 40)));
  }
}

final _run = HomeMatrixRun(Directory('build/home-matrix2/drawer-links'));

/// 引き出しの行き先（名前・押す項目・開く場所）。
typedef _Link = ({
  String name,
  Finder Function(HomeMatrix m) tile,
  String path,
});

final _links = <_Link>[
  (
    name: 'coins',
    tile: (_) => find.byKey(const Key('homeCoinBenefitsMenuItem')),
    path: '/rewards',
  ),
  (
    name: 'membership',
    tile: (_) => find.byKey(const Key('homeMembershipBenefitsMenuItem')),
    path: '/membership',
  ),
  (
    name: 'guide',
    tile: (_) => find.byKey(const Key('homeGuideMenuItem')),
    path: '/help',
  ),
  (
    name: 'settings',
    tile: (m) => find.ancestor(
      of: find.descendant(
        of: find.byType(Drawer),
        matching: find.text(m.l10n.homeDrawerSettings),
      ),
      matching: find.byType(ListTile),
    ),
    path: '/settings',
  ),
  (
    name: 'storage',
    tile: (m) => find.ancestor(
      of: find.descendant(
        of: find.byType(Drawer),
        matching: find.text(m.l10n.homeDrawerStorage),
      ),
      matching: find.byType(ListTile),
    ),
    path: '/storage',
  ),
];

/// 開く前のホームの状態を作る：プロジェクトは一覧を途中まで送る、作品一覧は
/// 並びを名前順にする、共有は「自分が作成したもの」（[HomeMatrix.show]が
/// 選ぶ）、ゴミ箱は「書き出した作品」だけに絞る。
Future<void> _makeState(HomeMatrix m, HomeView view) async {
  final tester = m.tester;
  switch (view) {
    case HomeView.projects:
      final scrollable = m.contentScrollable;
      scrollable?.position.jumpTo(scrollable.position.maxScrollExtent / 2);
    case HomeView.works:
      await _setSortByName(m, true);
    case HomeView.trash:
      await tester.tap(find.byKey(const ValueKey('trashKind_exportedWork')));
    case HomeView.sharedReceived || HomeView.sharedOutgoing:
      break;
  }
  await m.frames(6);
}

Future<void> _undoState(HomeMatrix m, HomeView view) async {
  switch (view) {
    case HomeView.projects:
      m.contentScrollable?.position.jumpTo(0);
    case HomeView.works:
      await _setSortByName(m, false);
    case HomeView.trash:
      await m.tester.tap(find.byKey(const ValueKey('trashKind_exportedWork')));
    case HomeView.sharedReceived || HomeView.sharedOutgoing:
      await m.show(HomeView.sharedReceived);
  }
  await m.frames(6);
}

Future<void> _setSortByName(HomeMatrix m, bool byName) async {
  final control = find.descendant(
    of: find.byType(TabBarView),
    matching: find.byType(SortModeControl),
  );
  final widget = m.tester.widget<SortModeControl>(control.first);
  if (widget.sortByName != byName) {
    widget.onSortByNameChanged(byName);
    await m.frames(4);
  }
}

/// 今のホームの状態（戻ったときに同じであるはずのもの）。
Map<String, Object?> _state(HomeMatrix m) {
  final sort = find.descendant(
    of: find.byType(TabBarView),
    matching: find.byType(SortModeControl),
  );
  final shared = find.byKey(const Key('sharedDirectionSegmentedControl'));
  return {
    'tab': m.tabIndex,
    'scroll': m.contentScrollable?.position.pixels.round(),
    if (sort.evaluate().isNotEmpty) ...{
      'sortByName': m.tester.widget<SortModeControl>(sort.first).sortByName,
      'ascending': m.tester.widget<SortModeControl>(sort.first).sortAscending,
    },
    if (shared.evaluate().length == 1)
      'outgoing': m.tester
          .widget<SegmentedButton<bool>>(shared)
          .selected
          .single,
    'trashKinds': [
      for (final e
          in find
              .byWidgetPredicate(
                (w) =>
                    w is FilterChip &&
                    w.key is ValueKey<String> &&
                    (w.key! as ValueKey<String>).value.startsWith('trashKind_'),
              )
              .evaluate())
        if ((e.widget as FilterChip).selected)
          (e.widget.key! as ValueKey<String>).value,
    ],
  };
}

/// 一番上の画面の場所（pushした画面はURIを変えないので、最後の一致の場所）。
String get _location =>
    appRouter.routerDelegate.currentConfiguration.last.matchedLocation;

bool _homeOnTop(WidgetTester tester) {
  final home = find.byType(HomeScreen, skipOffstage: false);
  if (home.evaluate().isEmpty) return false;
  return ModalRoute.of(tester.element(home.first))?.isCurrent ?? false;
}

Future<void> _roundTrip(
  HomeMatrix m,
  HomeView view,
  _Link link, {
  required bool systemBack,
}) async {
  final tester = m.tester;
  final before = _state(m);
  final problems = <String>[];
  await tester.tap(find.byKey(const Key('homeMenuButton')));
  await m.frames(8);
  final tile = link.tile(m);
  if (tile.evaluate().length != 1) {
    problems.add('drawer link ${link.name} found ${tile.evaluate().length}');
  } else {
    await tester.ensureVisible(tile);
    await m.frames(2);
    await tester.tap(tile);
    await m.frames(10);
    await m.settleIo(6);
  }
  final name = m.cellName('drawer-link', '${view.name}-${link.name}');
  final error = tester.takeException();
  if (error != null) problems.add('exception: ${'$error'.split('\n').first}');
  if (_location != link.path) {
    problems.add('opened $_location instead of ${link.path}');
  }
  if (_homeOnTop(tester)) problems.add('Home still on top after the link');
  await m.capture(name);

  // 戻る：端末の「戻る」か、行き先の上部バーの戻るボタン。
  final backButton = find.byType(BackButton);
  final usedButton = !systemBack && backButton.evaluate().isNotEmpty;
  if (usedButton) {
    await tester.tap(backButton.first);
  } else {
    await tester.binding.handlePopRoute();
  }
  await m.frames(10);
  await m.settleIo(2);
  final after = _state(m);
  final error2 = tester.takeException();
  if (error2 != null) {
    problems.add('exception after back: ${'$error2'.split('\n').first}');
  }
  if (_location != '/home') problems.add('back went to $_location');
  if (!_homeOnTop(tester)) problems.add('Home is not on top after back');
  if (find.byType(Drawer).evaluate().isNotEmpty) {
    problems.add('drawer still open after coming back');
  }
  for (final key in {...before.keys, ...after.keys}) {
    if ('${before[key]}' != '${after[key]}') {
      problems.add('$key changed: ${before[key]} -> ${after[key]}');
    }
  }
  m.record(
    name,
    'drawer-link',
    '${view.name}-${link.name}',
    ['$name.png'],
    problems,
    const [],
  );
  m.run.results.last['back'] = usedButton ? 'app bar back button' : 'system';
  m.run.results.last['state'] = before;
}
