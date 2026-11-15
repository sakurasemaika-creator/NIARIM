import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';

import 'helpers/home_keyboard_harness.dart';

/// 前のタブの中身（カード・見出し）にキーボードのフォーカスがあるまま、
/// マウス・指でタブを替えたとき、フォーカスを新しいタブの見出し（選んだ
/// タブ）へ移す。以前はフォーカスが隠れたページに残り（位置がNaN）、次の
/// Tabで前のタブへスクロールして戻り、題も前のタブに戻った（ja PC：
/// プロジェクトのカードの︙→「作品一覧」をクリック→Tab）。
void main() {
  // タブの中身（TabBarViewのページ）。
  final pages = <Finder>[
    find.byType(ProjectListWidget, skipOffstage: false),
    find.byKey(const PageStorageKey<String>('home-works'), skipOffstage: false),
    find.byType(SharedScreen, skipOffstage: false),
    find.byType(TrashScreen, skipOffstage: false),
  ];

  int selectedTab(WidgetTester tester) =>
      tester.widget<TabBar>(find.byType(TabBar)).controller!.index;

  for (final (from, to, kind) in [
    (0, 1, PointerDeviceKind.mouse),
    (0, 2, PointerDeviceKind.mouse),
    (0, 3, PointerDeviceKind.mouse),
    (1, 0, PointerDeviceKind.mouse),
    (2, 3, PointerDeviceKind.mouse),
    (3, 1, PointerDeviceKind.mouse),
    (0, 1, PointerDeviceKind.touch),
  ]) {
    testWidgets('focus leaves tab $from when tab $to is chosen by '
        '${kind.name}', (tester) async {
      final home = await HomeKeyboardHarness.open(
        tester,
        size: const Size(1280, 800),
        works: 8,
      );
      if (from != 0) {
        await tester.tap(find.byKey(ValueKey('home_tab_$from')), kind: kind);
        await home.settle();
      }
      // 前のタブの中身（プロジェクトはカードの︙まで）へTabで入る。
      bool inside() =>
          home.focusIsIn(pages[from]) &&
          (from != 0 || home.describeFocus().startsWith('collectionMenu_'));
      for (var i = 0; i < 60 && !inside(); i++) {
        await home.tab();
      }
      expect(inside(), isTrue, reason: 'never reached tab $from');

      await tester.tap(find.byKey(ValueKey('home_tab_$to')), kind: kind);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(selectedTab(tester), to);
      expect(
        home.focusIsIn(pages[from]),
        isFalse,
        reason: 'the focus stayed in the hidden tab: ${home.describeFocus()}',
      );
      // 選んだタブにフォーカスがある（次のTabで新しいタブの中身へ進む）。
      final tab = tester.element(find.byKey(ValueKey('home_tab_$to')));
      expect(
        Focus.maybeOf(tab, createDependency: false),
        same(home.focus),
        reason: 'the focus is on ${home.describeFocus()}',
      );
      for (var i = 0; i < 12; i++) {
        await home.tab();
        expect(selectedTab(tester), to, reason: 'Tab ${i + 1} changed tabs');
        expect(
          home.focusIsIn(pages[from]),
          isFalse,
          reason: 'Tab ${i + 1} went back into tab $from',
        );
      }
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }
}
