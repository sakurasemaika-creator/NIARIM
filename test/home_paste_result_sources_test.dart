import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:provider/provider.dart';

import 'helpers/home_clipboard_harness.dart';

// 所有者の判断6「件数内訳を出して正常に貼り付けられているかわかるように
// しましょう。」の続き。1件ずつの貼り付け（作品一覧・共有・ゴミ箱の項目）で
// 元が無くなっていたら、「1件を貼り付けました」と言わず、元が無い件数として
// 出してクリップボードから外す（押すたびに同じ失敗を繰り返さない）。一部だけ
// 保存できたときは、それと分かる文を出す。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 貼り付けの後に初めて出た知らせ（前の知らせは[letNoticesGo]で消して
  /// おく）。
  Future<String?> firstNotice(HomeClipboardHarness home) async {
    String? shown;
    for (var i = 0; i < 60 && shown == null; i++) {
      shown = home.snackText();
      if (shown == null) await home.settleIo(1);
    }
    debugPrint('paste result: $shown');
    return shown;
  }

  Future<void> expectNotice(
    HomeClipboardHarness home,
    String expected, {
    String? reason,
  }) async {
    expect(await firstNotice(home), expected, reason: reason);
  }

  /// 前の知らせが消えるまで待つ（次の知らせと取り違えない）。
  Future<void> letNoticesGo(WidgetTester tester) async {
    for (var i = 0; i < 7; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> confirmIfAsked(
    HomeClipboardHarness home,
    String confirmKey,
  ) async {
    final confirm = find.byKey(Key(confirmKey));
    if (confirm.evaluate().isNotEmpty) {
      await home.tester.tap(confirm);
      await home.settle();
    }
  }

  testWidgets('a Trash copy of a work deleted for good is not counted as '
      'pasted', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    final apple = await home.addWork('apple');
    await tester.runAsync(() => home.projects.deleteProject(apple.id));
    await home.settleIo(3);
    await home.showTab(3);
    await tester.tap(find.byKey(ValueKey('trashCopyProject_${apple.id}')));
    await home.settle();
    await tester.runAsync(() => home.projects.permanentDelete(apple.id));
    await home.settleIo(3);
    await letNoticesGo(tester);
    await home.showTab(0);
    await tester.tap(home.pasteButton);
    await home.settle();
    await confirmIfAsked(home, 'homePasteRestoreConfirmButton');
    await expectNotice(home, home.l10n.homePasteSkippedMissing(1));
    expect(home.projects.projects, isEmpty);
    expect(home.pasteButton, findsNothing, reason: 'the gone work stayed');
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a Trash copy of a folder deleted for good is not counted as '
      'pasted', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    final box = await home.addFolder('box');
    await home.addWork('apple', folderId: box.id);
    await tester.runAsync(() => home.projects.moveFolderToTrash(box.id));
    await home.settleIo(3);
    await home.showTab(3);
    await tester.tap(find.byKey(ValueKey('trashCopyFolder_${box.id}')));
    await home.settle();
    await tester.runAsync(
      () => home.projects.permanentDeleteTrashedFolder(box.id),
    );
    await home.settleIo(3);
    await letNoticesGo(tester);
    await home.showTab(0);
    await tester.tap(home.pasteButton);
    await home.settle();
    await confirmIfAsked(home, 'homePasteRestoreConfirmButton');
    await expectNotice(home, home.l10n.homePasteSkippedMissing(1));
    expect(home.projects.folders, isEmpty);
    expect(home.pasteButton, findsNothing, reason: 'the gone folder stayed');
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a copied received work that is gone, pasted into the Trash, '
      'is not counted as pasted', (tester) async {
    final home = await HomeClipboardHarness.open(tester, language: 'en');
    final gift = await home.addReceived('gift');
    await home.showTab(2);
    await tester.longPress(find.text('gift').first);
    await home.settle();
    await home.copySelection();
    await tester.runAsync(() async {
      await home.projects.deleteProject(gift.id);
      await home.projects.permanentDelete(gift.id);
    });
    await home.settleIo(4);
    await letNoticesGo(tester);
    await home.showTab(3);
    await tester.tap(home.pasteButton);
    await home.settle();
    await confirmIfAsked(home, 'homePasteTrashConfirmButton');
    await expectNotice(home, home.l10n.homePasteSkippedMissing(1));
    expect(home.projects.trash, isEmpty);
    expect(home.pasteButton, findsNothing, reason: 'the gone work stayed');
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a copied exported file that is gone, pasted into the Trash, '
      'is reported once as gone', (tester) async {
    final home = await HomeClipboardHarness.open(
      tester,
      language: 'en',
      exports: ['loose.gif'],
    );
    await home.showTab(1);
    await tester.longPress(find.text('loose.gif').first);
    await home.settle();
    await home.copySelection();
    File('${home.dir.path}/exports/loose.gif').deleteSync();
    await letNoticesGo(tester);
    await home.showTab(3);
    await tester.tap(home.pasteButton);
    await home.settle();
    await confirmIfAsked(home, 'homePasteTrashConfirmButton');
    await expectNotice(
      home,
      home.l10n.homePasteSkippedMissing(1),
      reason: 'a file that is gone was reported as a storage failure',
    );
    expect(
      home.pasteButton,
      findsNothing,
      reason: 'the gone file stayed on the clipboard',
    );
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a copied received folder that is gone is not counted as a '
      'storage failure', (tester) async {
    final home = await HomeClipboardHarness.open(tester, language: 'en');
    final gifts = (await tester.runAsync(
      () => home.projects.createSharedFolder('gifts'),
    ))!;
    await home.settleIo(2);
    await home.showTab(2);
    await tester.longPress(find.text('gifts').first);
    await home.settle();
    await home.copySelection();
    await tester.runAsync(() => home.projects.deleteSharedFolder(gifts.id));
    await home.settleIo(3);
    await letNoticesGo(tester);
    await tester.tap(home.pasteButton);
    await home.settle();
    await expectNotice(home, home.l10n.homePasteSkippedMissing(1));
    expect(home.projects.sharedFolders, isEmpty);
    expect(home.pasteButton, findsNothing, reason: 'the gone folder stayed');
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a copied Works folder that is gone does not make a folder in '
      'Projects', (tester) async {
    final home = await HomeClipboardHarness.open(tester, language: 'en');
    final works = tester
        .element(find.byType(HomeScreen))
        .read<WorkFolderService>();
    final reel = (await tester.runAsync(() => works.createFolder('reel')))!;
    await home.settleIo(2);
    await home.showTab(1);
    await tester.longPress(find.text('reel').first);
    await home.settle();
    await home.copySelection();
    await tester.runAsync(() => works.deleteFolder(reel.id));
    await home.settleIo(3);
    await letNoticesGo(tester);
    await home.showTab(0);
    await tester.tap(home.pasteButton);
    await home.settle();
    await expectNotice(home, home.l10n.homePasteSkippedMissing(1));
    expect(
      home.projects.folders,
      isEmpty,
      reason: 'a folder was made from a source that is gone',
    );
    expect(home.pasteButton, findsNothing, reason: 'the gone folder stayed');
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a cut folder whose move is only partly saved says so', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester);
    final box = await home.addFolder('box');
    final a = await home.addWork('a', folderId: box.id);
    final b = await home.addWork('b', folderId: box.id);
    // 1つずつゴミ箱へ移した作品はフォルダに残る（中身0件なので、タブを
    // またいで貼り付けられる）。
    await tester.runAsync(() async {
      await home.projects.deleteProject(a.id);
      await home.projects.deleteProject(b.id);
    });
    await home.settleIo(3);
    await home.cut(['box']);
    // フォルダを消すときの2つ目の作品の保存を失敗させる（1つ目は保存
    // できる＝一部だけ保存される）。
    final second = home.projects.trash.last;
    final base = (await tester.runAsync(NiaproSerializer.projectsBasePath))!;
    final file = File('$base/${second.id}/${second.id}.niapro');
    file.renameSync('${file.path}.aside');
    Directory(file.path).createSync();
    File('${file.path}/keep').writeAsStringSync('x');
    await letNoticesGo(tester);
    await home.showTab(1);
    await home.paste();
    final shown = await firstNotice(home);
    final l10n = home.l10n;
    expect(
      shown,
      (l10n as dynamic).homePasteSkippedPartial(1) as String,
      reason: 'a partly saved change was reported as a plain failure',
    );
    expect(tester.takeException(), isNull);
    await home.close();
  });
}
