import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';

import 'helpers/home_clipboard_harness.dart';

/// ホームの「お気に入り」の絞り込み・作品とフォルダの星をキーボードで押しても、
/// フォーカスは押した部品に残る（DISC125の（b））。どれも押した後も画面に残る
/// 部品なので、画面の根へ戻すと、続けて操作する（もう一度押して戻す）のに
/// Tabを何度も押し直すことになった（絞り込みは9回）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  bool focusIn(Finder finder) {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    final targets = finder.evaluate().toSet();
    var inside = false;
    focused.visitAncestorElements((element) {
      if (targets.contains(element)) {
        inside = true;
        return false;
      }
      return true;
    });
    return inside || targets.contains(focused);
  }

  Future<void> tabTo(HomeClipboardHarness home, Finder target) async {
    for (var i = 0; i < 80 && !focusIn(target); i++) {
      await home.tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await home.tester.pump();
    }
    expect(focusIn(target), isTrue, reason: 'Tab never reached the star');
  }

  for (final viewMode in ['medium', 'detail']) {
    testWidgets('the favourites filter keeps the focus after a keyboard '
        'press, so the same key turns it back off ($viewMode)', (tester) async {
      final home = await HomeClipboardHarness.open(
        tester,
        prefs: {'home.projectViewMode.v1': viewMode},
      );
      await home.addWork('apple');
      await home.addWork('pear');
      await home.settleIo(2);
      final chip = find.descendant(
        of: find.byType(ProjectListWidget),
        matching: find.byType(FilterChip),
      );
      await tabTo(home, chip);
      for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
        await tester.sendKeyEvent(key);
        await home.settleIo(2);
        expect(tester.widget<FilterChip>(chip).selected, isTrue);
        expect(
          focusIn(chip),
          isTrue,
          reason:
              '$key: the focus left the filter: '
              '${FocusManager.instance.primaryFocus}',
        );
        await tester.sendKeyEvent(key);
        await home.settleIo(2);
        expect(tester.widget<FilterChip>(chip).selected, isFalse);
        expect(focusIn(chip), isTrue);
        expect(find.text('apple'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await home.close();
    });

    // フォーカスが残るだけでなく、フォーカスの印も描き続ける（WCAG 2.4.7）。
    // 一覧の見出しを作り直さずに移す作りで、最初に押した後は灰色の印が
    // チップの地の色の下になって見えなかった（Linuxの実操作で、2回目以降の
    // 押下でも出なかった）。縁の輪か、地の色より上のインクの印で見えること。
    testWidgets('the favourites filter keeps drawing its focus highlight '
        'after keyboard presses ($viewMode)', (tester) async {
      final home = await HomeClipboardHarness.open(
        tester,
        prefs: {'home.projectViewMode.v1': viewMode},
      );
      await home.addWork('apple');
      await home.addWork('pear');
      await home.settleIo(2);
      final chip = find.descendant(
        of: find.byType(ProjectListWidget),
        matching: find.byType(FilterChip),
      );
      // 絞り込みのフォーカスの印（インクの下地に足す灰色）が、絞り込み
      //自身の地の色（同じインクの下地に描く InkDecoration）より上に描かれて
      // いるか。インクの下地は足した順に描くので、印が地の色より先にあると
      // 地の色に塗りつぶされて見えない。
      bool highlighted() {
        final ink = find.descendant(of: chip, matching: find.byType(InkWell));
        final controller = Material.of(tester.element(ink.first));
        final features =
            (controller as dynamic).debugInkFeatures as List<InkFeature>? ??
            const <InkFeature>[];
        final highlight = features.lastIndexWhere(
          (feature) => feature is InkHighlight && feature.active,
        );
        final background = features.lastIndexWhere(
          (feature) => feature is InkDecoration,
        );
        if (highlight >= 0 && highlight > background) return true;
        // インクの印が地の色の下になっても、縁の輪（チップの形の一部）で
        // フォーカスが見える。
        final material = tester.widget<Material>(
          find.descendant(of: chip, matching: find.byType(Material)).first,
        );
        final shape = material.shape;
        return shape is OutlinedBorder && shape.side.width >= 2;
      }

      final size = tester.getSize(chip);
      await tabTo(home, chip);
      await home.settle();
      expect(highlighted(), isTrue, reason: 'no focus highlight before');
      // 印を出しても、チップの大きさ（並び）は変わらない。
      expect(tester.getSize(chip), size);
      for (var press = 1; press <= 4; press++) {
        await tester.sendKeyEvent(
          press.isOdd ? LogicalKeyboardKey.space : LogicalKeyboardKey.enter,
        );
        await home.settleIo(2);
        await home.settle();
        expect(focusIn(chip), isTrue, reason: 'press $press');
        expect(
          highlighted(),
          isTrue,
          reason: 'press $press: the focus highlight is gone',
        );
      }
      expect(tester.takeException(), isNull);
      await home.close();
    });

    testWidgets('a work\'s star keeps the focus after a keyboard press '
        '($viewMode)', (tester) async {
      final home = await HomeClipboardHarness.open(
        tester,
        prefs: {'home.projectViewMode.v1': viewMode},
      );
      final apple = await home.addWork('apple');
      await home.addWork('pear');
      await home.settleIo(2);
      final star = find.byKey(Key('collectionFavorite_${apple.id}'));
      await tabTo(home, star);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await home.waitFor(
        () =>
            home.projects.projects.any((p) => p.id == apple.id && p.isFavorite),
      );
      await home.settleIo(2);
      expect(
        focusIn(find.byKey(Key('collectionFavorite_${apple.id}'))),
        isTrue,
        reason:
            'the focus left the star: '
            '${FocusManager.instance.primaryFocus}',
      );
      // そのままもう一度押すと外れる。
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await home.waitFor(
        () => home.projects.projects.any(
          (p) => p.id == apple.id && !p.isFavorite,
        ),
      );
      await home.settleIo(2);
      expect(
        focusIn(find.byKey(Key('collectionFavorite_${apple.id}'))),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }

  testWidgets('a folder\'s star keeps the focus after a keyboard press', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester);
    final box = await home.addFolder('box');
    await home.addWork('apple');
    await home.settleIo(2);
    final star = find.byKey(Key('collectionFavorite_${box.id}'));
    await tabTo(home, star);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await home.waitFor(
      () => home.projects.folders.any((f) => f.id == box.id && f.isFavorite),
    );
    await home.settleIo(2);
    expect(
      focusIn(find.byKey(Key('collectionFavorite_${box.id}'))),
      isTrue,
      reason: 'the focus left the star: ${FocusManager.instance.primaryFocus}',
    );
    expect(tester.takeException(), isNull);
    await home.close();
  });
}
