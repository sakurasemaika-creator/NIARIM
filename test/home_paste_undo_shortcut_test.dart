import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/router.dart';

import 'helpers/home_clipboard_harness.dart';

/// ホームの取り消し（Ctrl+Z）で、最後の貼り付けを取り消す。
///
/// 以前は貼り付けた直後にCtrl+Zを押しても何も起きなかった（取り消すのは
/// 最後にゴミ箱へ移したものだけだった。Linuxの実画面で発見、P4-17）。
/// - コピーの貼り付けは、作った複製（作品・フォルダ）をゴミ箱へ移す（消さない）。
///   お気に入りの作品の複製もゴミ箱へ移せるよう、複製のお気に入りは外す。
///   元の作品・フォルダは変えない。
/// - 切り取りの貼り付けは、移したものを元の場所へ戻す。
/// - 最後にゴミ箱へ移したものとの新しい方から戻す。取り消した貼り付けは
///   二度取り消さない。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pressUndo(HomeClipboardHarness home) async {
    await home.tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await home.tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await home.tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await home.settleIo();
  }

  Future<void> letNoticeGo(HomeClipboardHarness home) async {
    // 前の知らせが薄くなってから出る知らせもあるので、少しずつ進める。
    for (var i = 0; i < 14; i++) {
      await home.tester.pump(const Duration(milliseconds: 500));
    }
    await home.settle();
    expect(find.byType(SnackBar), findsNothing);
  }

  testWidgets('Ctrl+Z after pasting copies moves the copies to the trash', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester);
    final projects = home.projects;
    final apple = await home.addWork('apple');
    final folder = await home.addFolder('課題');
    final inside = await home.addWork('banana', folderId: folder.id);
    await tester.runAsync(() => projects.setFavorite(apple.id, true));
    await home.settleIo(2);

    await home.copy(['apple', '課題']);
    await home.paste();
    final copies = [
      for (final p in projects.projects)
        if (p.id != apple.id && p.id != inside.id) p,
    ];
    expect(copies.map((p) => p.name).toSet(), {'apple (コピー)', 'banana'});
    final folderCopy = projects.folders.singleWhere((f) => f.id != folder.id);
    expect(folderCopy.name, '課題 (コピー)');

    await pressUndo(home);
    await home.waitFor(
      () =>
          projects.folders.length == 1 &&
          projects.projects.length == 2 &&
          projects.trashedFolders.length == 1,
    );
    // 元の作品・フォルダはそのまま。複製はゴミ箱から戻せる。
    expect(projects.projects.map((p) => p.id).toSet(), {apple.id, inside.id});
    expect(
      projects.projects.firstWhere((p) => p.id == apple.id).isFavorite,
      isTrue,
    );
    expect(projects.folders.single.id, folder.id);
    expect(projects.looseTrash.single.name, 'apple (コピー)');
    expect(projects.trashedFolders.single.folder.id, folderCopy.id);
    // 貼り付けの知らせと入れ替わる。
    await home.waitFor(
      () => home.snackText() == home.l10n.homePasteUndoneToTrash(2),
    );
    await letNoticeGo(home);

    // もう一度押しても、複製をゴミ箱から戻さない（取り消した貼り付けは
    // 終わり。ゴミ箱へ移した操作としては数えない）。
    await pressUndo(home);
    await home.settle();
    expect(find.byType(SnackBar), findsNothing);
    expect(projects.looseTrash.single.name, 'apple (コピー)');
    expect(projects.trashedFolders, hasLength(1));
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('Ctrl+Z after pasting a cut moves it back', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    final projects = home.projects;
    final apple = await home.addWork('apple');
    final folder = await home.addFolder('課題');
    final inner = await home.addFolder('下書き');

    await home.cut(['apple', '下書き']);
    // 「課題」を開いて貼り付ける。
    await tester.tap(home.card('課題').first);
    await home.settleIo(2);
    await home.settle();
    await home.paste();
    expect(projects.projects.single.folderId, folder.id);
    expect(
      projects.folders.singleWhere((f) => f.id == inner.id).parentFolderId,
      folder.id,
    );

    await pressUndo(home);
    await home.waitFor(() => projects.projects.single.folderId == null);
    expect(projects.projects.single.id, apple.id);
    expect(
      projects.folders.singleWhere((f) => f.id == inner.id).parentFolderId,
      isNull,
    );
    expect(projects.trash, isEmpty);
    await home.waitFor(
      () => home.snackText() == home.l10n.homePasteUndoneMovedBack(2),
    );
    expect(tester.takeException(), isNull);
    appRouter.go('/home');
    await home.close();
  });

  testWidgets('the newer of the last paste and the last trash move goes '
      'first', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    final projects = home.projects;
    await home.addWork('apple');
    await home.addWork('cherry');

    await home.copy(['apple']);
    await home.paste();
    expect(projects.projects.map((p) => p.name), contains('apple (コピー)'));
    await letNoticeGo(home);
    // 貼り付けの後に、別の作品をゴミ箱へ移す。
    await tester.tap(home.card('cherry').first, buttons: kSecondaryMouseButton);
    await home.settle();
    await tester.tap(find.text(home.l10n.projectDetailTrashMenuItem).last);
    await home.waitFor(() => projects.trash.length == 1);
    await letNoticeGo(home);

    // 1回目はゴミ箱へ移した作品を戻す（複製はそのまま）。
    await pressUndo(home);
    await home.waitFor(() => projects.trash.isEmpty);
    expect(projects.projects.map((p) => p.name).toSet(), {
      'apple',
      'apple (コピー)',
      'cherry',
    });
    await letNoticeGo(home);
    // 2回目で貼り付けを取り消す。
    await pressUndo(home);
    await home.waitFor(() => projects.trash.length == 1);
    expect(projects.trash.single.name, 'apple (コピー)');
    expect(projects.projects.map((p) => p.name).toSet(), {'apple', 'cherry'});
    expect(tester.takeException(), isNull);
    await home.close();
  });
}
