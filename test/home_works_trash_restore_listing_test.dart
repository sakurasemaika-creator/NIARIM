import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:provider/provider.dart';

import 'helpers/home_clipboard_harness.dart';

/// 作品一覧のファイル・フォルダをゴミ箱へ移し、ゴミ箱のタブの「復元」で
/// 戻すと、作品一覧へ戻ったときに戻したファイルが出る。以前は作品一覧が
/// 前に読んだ一覧（ゴミ箱へ移した後のもの）を使い続け、戻したフォルダは
/// 再起動するまで空（「このフォルダには書き出した作品がありません」）、
/// 戻したファイルは出なかった（知らせの「元に戻す」は作品一覧を開いたまま
/// なので読み直していた）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> confirm(HomeClipboardHarness home) async {
    await home.tester.tap(find.byKey(const Key('trash-dialog-confirm')));
    await home.waitFor(
      () => find.byType(AlertDialog).evaluate().isEmpty,
      reason: 'the question stayed open',
    );
  }

  Future<List<LocalTrashedFile>> trashedFiles(
    HomeClipboardHarness home,
  ) async => (await home.tester.runAsync(LocalFileTrashService.list))!;

  /// ゴミ箱のタブで、ただ1つのファイルの控えを「復元」する。
  Future<void> restoreFromTrashTab(HomeClipboardHarness home) async {
    await home.showTab(3);
    final entry = (await trashedFiles(home)).single;
    final button = find.byKey(ValueKey('trash-restore-local-${entry.id}'));
    await home.waitFor(() => button.evaluate().isNotEmpty);
    await home.tester.ensureVisible(button);
    await home.tester.tap(button);
    await home.settle();
    await home.tester.tap(
      find.byKey(const Key('homeTrashRestoreConfirmButton')),
    );
    await home.settle();
    // 戻している間は控えの記録を書き直すので、続けて空のときに終わりとする。
    var quiet = 0;
    for (var i = 0; i < 120 && quiet < 3; i++) {
      await home.settleIo(1);
      quiet = (await trashedFiles(home)).isEmpty ? quiet + 1 : 0;
    }
    expect(quiet, 3, reason: 'the restore did not finish');
  }

  testWidgets('a works folder restored from the Trash tab lists its files', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(
      tester,
      exports: ['clip_1.gif', 'clip_2.gif', 'clip_3.gif'],
    );
    final l10n = home.l10n;
    final folders = tester
        .element(find.byType(HomeScreen))
        .read<WorkFolderService>();
    final clips = (await tester.runAsync(() async {
      final folder = await folders.createFolder('Clips');
      await folders.moveFileToFolder('clip_1.gif', folder.id);
      await folders.moveFileToFolder('clip_2.gif', folder.id);
      return folder;
    }))!;
    await home.showTab(1);
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('collectionFolder_${clips.id}')),
        matching: find.byIcon(Icons.more_vert),
      ),
    );
    await home.settle();
    await tester.tap(find.text(l10n.homeMoveToTrash).last);
    await home.settle();
    await confirm(home);
    expect(folders.folders, isEmpty);
    await restoreFromTrashTab(home);
    expect(
      File('${home.dir.path}/exports/clip_1.gif').existsSync() &&
          File('${home.dir.path}/exports/clip_2.gif').existsSync(),
      isTrue,
    );
    await home.showTab(1);
    final restored = folders.folders.singleWhere((f) => f.name == 'Clips');
    // フォルダを移す確かめは、中の作品の数を出す（前の一覧のままだと
    // 中が空に見えて、この行が出なかった）。
    final menu = find.descendant(
      of: find.byKey(ValueKey('collectionFolder_${restored.id}')),
      matching: find.byIcon(Icons.more_vert),
    );
    await home.waitFor(
      () => menu.evaluate().isNotEmpty,
      reason: 'the Works tab does not show the folder',
    );
    await tester.tap(menu);
    await home.settle();
    await tester.tap(find.text(l10n.homeMoveToTrash).last);
    await home.settle();
    expect(
      find.textContaining(
        l10n.homeMoveToTrashFolderContents(l10n.homeWorkFolderContents(2)),
      ),
      findsOneWidget,
      reason: 'the folder looks empty in its trash question',
    );
    await tester.tap(find.byKey(const Key('trash-dialog-cancel')));
    await home.settle();
    // フォルダを開くと、戻した2つのファイルが出る。
    await tester.tap(find.byKey(ValueKey('collectionFolder_${restored.id}')));
    await home.settleIo(3);
    await home.waitFor(
      () =>
          find
              .descendant(
                of: find.byType(ExportedWorkCard),
                matching: find.text('clip_1.gif'),
              )
              .evaluate()
              .isNotEmpty &&
          find
              .descendant(
                of: find.byType(ExportedWorkCard),
                matching: find.text('clip_2.gif'),
              )
              .evaluate()
              .isNotEmpty,
      reason: 'the restored folder looks empty',
    );
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('an exported file restored from the Trash tab is listed', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(
      tester,
      exports: ['clip_1.gif', 'clip_2.gif'],
    );
    await home.showTab(1);
    await tester.tap(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('clip_1.gif'),
              matching: find.byType(ExportedWorkCard),
            )
            .first,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await home.settle();
    await tester.tap(find.text(home.l10n.homeMoveToTrash).last);
    await home.settle();
    await confirm(home);
    await restoreFromTrashTab(home);
    await home.showTab(1);
    await home.waitFor(
      () => find.text('clip_1.gif').evaluate().isNotEmpty,
      reason: 'the restored file is not listed',
    );
    expect(tester.takeException(), isNull);
    await home.close();
  });
}
