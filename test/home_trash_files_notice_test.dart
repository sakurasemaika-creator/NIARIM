import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:provider/provider.dart';

import 'helpers/home_clipboard_harness.dart';

/// 作品一覧（書き出したファイル・そのフォルダ）と共有（作成した共有
/// ファイル・受け取ったもの・そのフォルダ）をゴミ箱へ移したときも、作品と
/// 同じく「ゴミ箱へ移動しました」と知らせ、その場で「元に戻す」で戻せる。
/// 以前は何も出ず、戻すにはゴミ箱のタブを開いて探すしかなかった。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> confirm(HomeClipboardHarness home) async {
    final confirm = find.byKey(const Key('trash-dialog-confirm'));
    await home.waitFor(() => confirm.evaluate().isNotEmpty);
    await home.tester.tap(confirm);
    await home.waitFor(
      () => find.byType(AlertDialog).evaluate().isEmpty,
      reason: 'the question stayed open',
    );
  }

  Future<void> undo(HomeClipboardHarness home, String notice) async {
    await home.waitFor(
      () => home.snackText() == notice,
      reason: 'no notice 「$notice」 (now: ${home.snackText()})',
    );
    await home.tester.tap(find.text(home.l10n.homeUndoAction));
    await home.settle();
  }

  Future<List<LocalTrashedFile>> trashedFiles(
    HomeClipboardHarness home,
  ) async => (await home.tester.runAsync(LocalFileTrashService.list))!;

  /// 戻し終える（ゴミ箱の控えが消える）まで待つ。
  Future<void> waitForEmptyFileTrash(HomeClipboardHarness home) async {
    for (var i = 0; i < 50 && (await trashedFiles(home)).isNotEmpty; i++) {
      await home.settleIo(1);
    }
    expect(await trashedFiles(home), isEmpty, reason: 'Undo left the copy');
  }

  testWidgets('an exported file from its menu: notice and Undo', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(
      tester,
      exports: ['clip_1.gif', 'clip_2.gif'],
    );
    final l10n = home.l10n;
    final file = File('${home.dir.path}/exports/clip_1.gif');
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
    await tester.tap(find.text(l10n.homeMoveToTrash).last);
    await home.settle();
    await confirm(home);
    expect(file.existsSync(), isFalse);
    await undo(home, l10n.homeMovedToTrashSnackbar(1));
    await home.waitFor(() => file.existsSync(), reason: 'Undo did nothing');
    await waitForEmptyFileTrash(home);
    await home.waitFor(
      () => find.text('clip_1.gif').evaluate().isNotEmpty,
      reason: 'the restored file is not listed',
    );
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a works folder from its sheet: named notice and Undo', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(
      tester,
      exports: ['clip_1.gif', 'clip_2.gif'],
    );
    final l10n = home.l10n;
    final folders = tester
        .element(find.byType(HomeScreen))
        .read<WorkFolderService>();
    final clips = (await tester.runAsync(() async {
      final folder = await folders.createFolder('Clips');
      await folders.moveFileToFolder('clip_1.gif', folder.id);
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
    await undo(home, l10n.homeFolderMovedToTrashSnackbar('Clips'));
    await home.waitFor(
      () =>
          folders.folders.any((f) => f.name == 'Clips') &&
          folders.folderIdOf('clip_1.gif') == folders.folders.single.id,
      reason: 'Undo did not bring the folder and its file back',
    );
    expect(File('${home.dir.path}/exports/clip_1.gif').existsSync(), isTrue);
    await waitForEmptyFileTrash(home);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a created share file from its menu: notice and Undo', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester);
    final l10n = home.l10n;
    final file = File(
      '${home.dir.path}/niarim/shared/outgoing/mine_share.niashare',
    )..createSync(recursive: true);
    file.writeAsBytesSync(List.filled(64, 1));
    await tester.runAsync(() => home.projects.refreshOutgoingShares());
    await home.settleIo(2);
    await home.showTab(2);
    await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
    await home.settleIo(2);
    await tester.tap(find.byKey(ValueKey('outgoingShareMenu_${file.path}')));
    await home.settle();
    await tester.tap(find.text(l10n.projectDetailTrashMenuItem).last);
    await home.settle();
    await confirm(home);
    await home.waitFor(() => !file.existsSync());
    await undo(home, l10n.homeMovedToTrashSnackbar(1));
    await home.waitFor(() => file.existsSync(), reason: 'Undo did nothing');
    await home.waitFor(
      () => home.projects.outgoingShares.any((s) => s.path == file.path),
      reason: 'the restored file is not listed',
    );
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a received folder from its sheet: named notice and Undo', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(tester);
    final l10n = home.l10n;
    final inbox = (await tester.runAsync(
      () => home.projects.createSharedFolder('Inbox'),
    ))!;
    await home.addReceived('gift', sharedFolderId: inbox.id);
    await home.showTab(2);
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('collectionFolder_${inbox.id}')),
        matching: find.byIcon(Icons.more_vert),
      ),
    );
    await home.settle();
    await tester.tap(find.text(l10n.homeMoveToTrash).last);
    await home.settle();
    await confirm(home);
    expect(home.projects.sharedFolders, isEmpty);
    await undo(home, l10n.homeFolderMovedToTrashSnackbar('Inbox'));
    await home.waitFor(
      () =>
          home.projects.sharedFolders.any((f) => f.id == inbox.id) &&
          home.projects.trash.isEmpty,
      reason: 'Undo did not bring the folder and its work back',
    );
    expect(home.projects.shared.single.sharedFolderId, inbox.id);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  testWidgets('a selection of two exported files: one notice and Undo '
      'brings back both', (tester) async {
    final home = await HomeClipboardHarness.open(
      tester,
      exports: ['clip_1.gif', 'clip_2.gif', 'clip_3.gif'],
    );
    final l10n = home.l10n;
    await home.showTab(1);
    await tester.longPress(find.text('clip_1.gif').first);
    await home.settle();
    await tester.tap(find.text('clip_2.gif').first);
    await home.settle();
    await tester.tap(find.byTooltip(l10n.homeMoveToTrash));
    await home.settle();
    await confirm(home);
    final one = File('${home.dir.path}/exports/clip_1.gif');
    final two = File('${home.dir.path}/exports/clip_2.gif');
    expect(one.existsSync() || two.existsSync(), isFalse);
    await undo(home, l10n.homeMovedToTrashSnackbar(2));
    await home.waitFor(
      () => one.existsSync() && two.existsSync(),
      reason: 'Undo did not bring both back',
    );
    await waitForEmptyFileTrash(home);
    expect(tester.takeException(), isNull);
    await home.close();
  });
}
