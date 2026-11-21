import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/widgets/app_scroll_behavior.dart';

import 'helpers/home_clipboard_harness.dart';

/// ホームの一覧の小さな食い違い（DISC124の（6）（7））を本物のアプリで
/// 確かめる。
/// （6）空のプロジェクトの一覧は、何もスクロールしないのに画面いっぱいの
///     スクロールバーのつまみを出さない。
/// （7）ゴミ箱へ移して「元に戻す」で戻しても、作品の最終保存の日時は変わらず、
///     「更新日時」の並びも変わらない（ゴミ箱へ移すのは作品の変更ではない）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// プロジェクトの一覧に出ているスクロールバーのつまみ（無ければnull）。
  Rect? listThumb(WidgetTester tester) {
    final paints = find.descendant(
      of: find.byType(ProjectListWidget),
      matching: find.byWidgetPredicate(
        (w) =>
            w is CustomPaint && w.foregroundPainter is ScrollIndicatorPainter,
      ),
    );
    Rect? thumb;
    for (final element in paints.evaluate()) {
      final paint = element.widget as CustomPaint;
      final painter = paint.foregroundPainter! as ScrollIndicatorPainter;
      final size = (element.renderObject! as RenderBox).size;
      thumb ??= ScrollIndicatorPainter.thumbRectFor(
        painter.metrics.value,
        size,
      );
    }
    return thumb;
  }

  for (final size in const [
    Size(360, 740),
    Size(360, 640),
    Size(412, 915),
    Size(800, 900),
  ]) {
    testWidgets('(6) an empty project list shows no scrollbar thumb '
        '(${size.width.toInt()}x${size.height.toInt()})', (tester) async {
      final home = await HomeClipboardHarness.open(tester, size: size);
      await home.settleIo(2);
      final l10n = home.l10n;
      expect(find.text(l10n.projectListEmptyTitle), findsOneWidget);
      final thumb = listThumb(tester);
      debugPrint('$size empty list thumb: $thumb');
      expect(thumb, isNull, reason: 'a thumb for a list that does not scroll');
      // 空の表示は一覧の欄の中に収まったまま。
      final list = tester.getRect(find.byType(ProjectListWidget));
      final title = tester.getRect(find.text(l10n.projectListEmptyTitle));
      expect(list.contains(title.center), isTrue);
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }

  testWidgets('(6) when the empty message really is taller than the list '
      '(large text, short window), it still scrolls', (tester) async {
    final home = await HomeClipboardHarness.open(
      tester,
      size: const Size(360, 300),
      textScale: 2,
    );
    await home.settleIo(2);
    final l10n = home.l10n;
    final title = find.text(l10n.projectListEmptyTitle);
    expect(title, findsOneWidget);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  /// いま見えているタブ（画面の幅の中）の一覧のスクロールバーのつまみ。
  List<Rect> shownThumbs(WidgetTester tester, double width) {
    final thumbs = <Rect>[];
    final paints = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.foregroundPainter is ScrollIndicatorPainter,
    );
    for (final element in paints.evaluate()) {
      final box = element.renderObject! as RenderBox;
      if (!box.attached || !box.hasSize) continue;
      final x = box.localToGlobal(Offset.zero).dx;
      if (x < 0 || x >= width) continue; // ほかのタブ
      final painter =
          (element.widget as CustomPaint).foregroundPainter!
              as ScrollIndicatorPainter;
      final thumb = ScrollIndicatorPainter.thumbRectFor(
        painter.metrics.value,
        box.size,
      );
      if (thumb != null) thumbs.add(thumb);
    }
    return thumbs;
  }

  // 作品一覧・共有のタブの空の一覧も同じ（下に浮くボタンの分の余白を、
  // 空の表示の外にスクロールの分として足していたので、何も無いのに88px
  // スクロールでき、画面いっぱいに近いつまみが出ていた）。
  for (final (tab, emptyTitle) in [
    (1, (HomeClipboardHarness home) => home.l10n.homeWorksEmpty),
    (2, (HomeClipboardHarness home) => home.l10n.homeSharedEmpty),
  ]) {
    for (final size in const [
      Size(360, 740),
      Size(360, 640),
      Size(412, 915),
      Size(800, 900),
    ]) {
      testWidgets('(6) the empty tab $tab shows no scrollbar thumb '
          '(${size.width.toInt()}x${size.height.toInt()})', (tester) async {
        final home = await HomeClipboardHarness.open(tester, size: size);
        await home.showTab(tab);
        await home.settleIo(2);
        final title = find.text(emptyTitle(home));
        expect(title, findsOneWidget);
        final thumbs = shownThumbs(tester, size.width);
        debugPrint('$size empty tab $tab thumbs: $thumbs');
        expect(
          thumbs,
          isEmpty,
          reason: 'a thumb for a list that does not scroll',
        );
        // 空の表示は画面の中、下に浮くボタンより上。
        final rect = tester.getRect(title);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height - 88));
        expect(tester.takeException(), isNull);
        await home.close();
      });
    }

    testWidgets('(6) the empty tab $tab still scrolls when its message is '
        'taller than the list (large text, short window)', (tester) async {
      final home = await HomeClipboardHarness.open(
        tester,
        size: const Size(360, 300),
        textScale: 2,
      );
      await home.showTab(tab);
      await home.settleIo(2);
      final title = find.text(emptyTitle(home));
      expect(title, findsOneWidget);
      await tester.ensureVisible(title);
      await home.settle();
      final rect = tester.getRect(title);
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(300));
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }

  Future<void> trashFromMenu(HomeClipboardHarness home, String name) async {
    await home.tester.tap(home.card(name), buttons: kSecondaryMouseButton);
    await home.settle();
    await home.tester.tap(find.text(home.l10n.projectDetailTrashMenuItem));
    await home.waitFor(
      () => home.projects.trash.any((p) => p.name == name),
      reason: '$name was not moved to the Trash',
    );
    await home.settle();
  }

  /// 一覧のカードの名前（上の行から、行の中は左から）。
  List<String> shownOrder(WidgetTester tester, List<String> names) {
    final found = <(Offset, String)>[
      for (final name in names)
        if (find
            .descendant(
              of: find.byType(ProjectListWidget),
              matching: find.text(name),
            )
            .evaluate()
            .isNotEmpty)
          (
            tester.getTopLeft(
              find
                  .descendant(
                    of: find.byType(ProjectListWidget),
                    matching: find.text(name),
                  )
                  .first,
            ),
            name,
          ),
    ];
    found.sort((a, b) {
      final dy = a.$1.dy - b.$1.dy;
      if (dy.abs() > 8) return dy.sign.toInt();
      return a.$1.dx.compareTo(b.$1.dx);
    });
    return [for (final item in found) item.$2];
  }

  testWidgets('(7) moving a work to the Trash and undoing keeps its last '
      'saved time and its place in the list', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    await home.addWork('older');
    await home.addWork('middle');
    await home.addWork('newest');
    await home.settleIo(2);
    final names = ['older', 'middle', 'newest'];
    final before = shownOrder(tester, names);
    final older = home.projects.projects.firstWhere((p) => p.name == 'older');
    final savedAt = older.updatedAt;
    debugPrint('before: $before, older saved at $savedAt');
    expect(before, ['newest', 'middle', 'older']);

    await trashFromMenu(home, 'older');
    final undo = find.descendant(
      of: find.byType(SnackBar),
      matching: find.text(home.l10n.homeUndoAction),
    );
    expect(undo, findsOneWidget);
    await tester.tap(undo);
    await home.waitFor(() => home.projects.trash.isEmpty);
    await home.settleIo(2);
    final restored = home.projects.projects.firstWhere(
      (p) => p.name == 'older',
    );
    debugPrint(
      'after: ${shownOrder(tester, names)}, '
      'older saved at ${restored.updatedAt}',
    );
    expect(restored.updatedAt, savedAt);
    expect(shownOrder(tester, names), before);
    // 次に起動したときも同じ（保存した作品の日時も変わらない）。
    final base = (await tester.runAsync(NiaproSerializer.projectsBasePath))!;
    final saved = (await tester.runAsync(
      () => NiaproSerializer.load('$base/${older.id}/${older.id}.niapro'),
    ))!;
    expect(saved.project.updatedAt, savedAt);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('(7) moving a folder to the Trash and undoing keeps the last '
      'saved times of the works inside', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    final box = await home.addFolder('box');
    final inside = await home.addWork('inside', folderId: box.id);
    await home.addWork('outside');
    await home.settleIo(2);
    final savedAt = home.projects.projects
        .firstWhere((p) => p.id == inside.id)
        .updatedAt;
    await tester.runAsync(() => home.projects.moveFolderToTrash(box.id));
    await home.settleIo(2);
    await tester.runAsync(() => home.projects.restoreTrashedFolder(box.id));
    await home.settleIo(2);
    final restored = home.projects.projects.firstWhere(
      (p) => p.id == inside.id,
    );
    expect(restored.updatedAt, savedAt);
    final base = (await tester.runAsync(NiaproSerializer.projectsBasePath))!;
    final saved = (await tester.runAsync(
      () => NiaproSerializer.load('$base/${inside.id}/${inside.id}.niapro'),
    ))!;
    expect(saved.project.updatedAt, savedAt);
    await home.close();
  });
}
