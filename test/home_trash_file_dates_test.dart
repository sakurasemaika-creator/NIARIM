import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:provider/provider.dart';

import 'helpers/home_clipboard_harness.dart';

/// ゴミ箱へ移した書き出したファイル・そのフォルダの中のファイル・作成した
/// 共有ファイルを戻しても（知らせの「元に戻す」とゴミ箱のタブの「復元」）、
/// 更新日時は移す前のまま。以前は戻した時刻になり、作品一覧の行の日付が
/// 変わり、「更新日時」の並びで先頭へ動いた（作品は元の日時のまま戻る）。
/// 受け取ったものも元の日時のまま戻ることを確かめる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final old = DateTime(2026, 11, 13, 12, 26);
  final older = DateTime(2026, 11, 10, 9, 5);

  Future<void> confirm(HomeClipboardHarness home) async {
    final button = find.byKey(const Key('trash-dialog-confirm'));
    await home.waitFor(
      () => button.evaluate().isNotEmpty,
      reason: 'the trash confirmation did not open',
    );
    await home.tester.tap(button);
    await home.waitFor(
      () => find.byType(AlertDialog).evaluate().isEmpty,
      reason: 'the question stayed open',
    );
  }

  Future<void> undo(HomeClipboardHarness home) async {
    await home.waitFor(
      () => find.text(home.l10n.homeUndoAction).evaluate().isNotEmpty,
      reason: 'no Undo (now: ${home.snackText()})',
    );
    await home.tester.tap(find.text(home.l10n.homeUndoAction));
    await home.settle();
  }

  Future<List<LocalTrashedFile>> trashedFiles(
    HomeClipboardHarness home,
  ) async => (await home.tester.runAsync(LocalFileTrashService.list))!;

  /// 戻し終える（[files]が元の場所にあり、ゴミ箱の控えが消える）まで待つ。
  /// 戻している間は控えの記録を書き直すので、一度読めなかっただけでは
  /// 終わったと見なさない。
  Future<void> waitForRestored(
    HomeClipboardHarness home,
    List<File> files,
  ) async {
    var quiet = 0;
    for (var i = 0; i < 120 && quiet < 3; i++) {
      await home.settleIo(1);
      final done =
          files.every((file) => file.existsSync()) &&
          (await trashedFiles(home)).isEmpty;
      quiet = done ? quiet + 1 : 0;
    }
    expect(quiet, 3, reason: 'the restore did not finish');
  }

  /// ゴミ箱のタブで、ファイルの控えの「復元」を押して確かめる。
  Future<void> restoreFromTrashTab(
    HomeClipboardHarness home,
    List<File> files,
  ) async {
    await home.showTab(3);
    final entry = (await trashedFiles(home)).single;
    final button = find.byKey(ValueKey('trash-restore-local-${entry.id}'));
    await home.waitFor(
      () => button.evaluate().isNotEmpty,
      reason: 'the Trash tab does not list ${entry.fileName}',
    );
    await home.tester.ensureVisible(button);
    await home.tester.tap(button);
    await home.settle();
    await home.tester.tap(
      find.byKey(const Key('homeTrashRestoreConfirmButton')),
    );
    await home.settle();
    await waitForRestored(home, files);
  }

  Future<void> trashExportFromMenu(
    HomeClipboardHarness home,
    String name,
  ) async {
    await home.tester.tap(
      find.descendant(
        of: find
            .ancestor(
              of: find.text(name),
              matching: find.byType(ExportedWorkCard),
            )
            .first,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await home.settle();
    await home.tester.tap(find.text(home.l10n.homeMoveToTrash).last);
    await home.settle();
    await confirm(home);
  }

  testWidgets('a trash row shows the current retention deadline', (
    tester,
  ) async {
    final home = await HomeClipboardHarness.open(
      tester,
      exports: ['deadline.gif'],
    );
    final settings = tester
        .element(find.byType(HomeScreen))
        .read<SettingsService>();
    await settings.setTrashAutoDelete(60);
    await home.showTab(1);
    await trashExportFromMenu(home, 'deadline.gif');
    await home.showTab(3);
    final remaining = home.l10n.homeTrashDaysUntilPermanentDelete(60);
    final countdown = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.semanticsLabel ??
                  widget.data ??
                  widget.textSpan?.toPlainText() ??
                  '')
              .contains(remaining),
    );
    await home.waitFor(
      () => countdown.evaluate().isNotEmpty,
      reason: 'Trash should show the remaining retention period',
    );
    expect(countdown, findsOneWidget);
    await settings.setTrashAutoDelete(0);
    await home.settle();
    expect(countdown, findsNothing);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  for (final how in ['Undo', 'Restore']) {
    testWidgets('an exported file keeps its date ($how)', (tester) async {
      final home = await HomeClipboardHarness.open(
        tester,
        exports: ['clip_1.gif', 'clip_2.gif'],
      );
      final file = File('${home.dir.path}/exports/clip_1.gif')
        ..setLastModifiedSync(old);
      File('${home.dir.path}/exports/clip_2.gif').setLastModifiedSync(older);
      await home.showTab(1);
      await trashExportFromMenu(home, 'clip_1.gif');
      expect(file.existsSync(), isFalse);
      if (how == 'Undo') {
        await undo(home);
        await waitForRestored(home, [file]);
      } else {
        await restoreFromTrashTab(home, [file]);
      }
      final date = file.lastModifiedSync();
      expect(tester.takeException(), isNull);
      await home.close();
      expect(date, old, reason: 'the date changed');
    });

    testWidgets('files in a works folder keep their dates ($how)', (
      tester,
    ) async {
      final home = await HomeClipboardHarness.open(
        tester,
        exports: ['clip_1.gif', 'clip_2.gif', 'clip_3.gif'],
      );
      final one = File('${home.dir.path}/exports/clip_1.gif')
        ..setLastModifiedSync(old);
      final two = File('${home.dir.path}/exports/clip_2.gif')
        ..setLastModifiedSync(older);
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
      await tester.tap(find.text(home.l10n.homeMoveToTrash).last);
      await home.settle();
      await confirm(home);
      expect(one.existsSync() || two.existsSync(), isFalse);
      if (how == 'Undo') {
        await undo(home);
        await waitForRestored(home, [one, two]);
      } else {
        await restoreFromTrashTab(home, [one, two]);
      }
      final dates = [one.lastModifiedSync(), two.lastModifiedSync()];
      expect(tester.takeException(), isNull);
      await home.close();
      expect(dates, [old, older], reason: 'clip_1.gif, clip_2.gif');
    });

    testWidgets('a created share file keeps its date ($how)', (tester) async {
      final home = await HomeClipboardHarness.open(tester);
      final file = File(
        '${home.dir.path}/niarim/shared/outgoing/1/mine_share.niashare',
      )..createSync(recursive: true);
      file
        ..writeAsBytesSync(List.filled(64, 1))
        ..setLastModifiedSync(old);
      await tester.runAsync(() => home.projects.refreshOutgoingShares());
      await home.settleIo(2);
      await home.showTab(2);
      await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
      await home.settleIo(2);
      await tester.tap(find.byKey(ValueKey('outgoingShareMenu_${file.path}')));
      await home.settle();
      await tester.tap(find.text(home.l10n.projectDetailTrashMenuItem).last);
      await home.settle();
      await confirm(home);
      await home.waitFor(() => !file.existsSync());
      if (how == 'Undo') {
        await undo(home);
        await waitForRestored(home, [file]);
      } else {
        await restoreFromTrashTab(home, [file]);
      }
      final date = file.lastModifiedSync();
      expect(tester.takeException(), isNull);
      await home.close();
      expect(date, old, reason: 'the date changed');
    });

    testWidgets('a received work keeps its date ($how)', (tester) async {
      final home = await HomeClipboardHarness.open(tester);
      final received = await home.addReceived('gift');
      final before = home.projects.shared
          .singleWhere((p) => p.id == received.id)
          .updatedAt;
      await home.showTab(2);
      await tester.tap(
        find.byKey(ValueKey('receivedShareMenu_${received.id}')),
      );
      await home.settle();
      await tester.tap(find.text(home.l10n.homeMoveToTrash).last);
      await home.settle();
      await confirm(home);
      await home.waitFor(
        () => home.projects.trash.any((p) => p.id == received.id),
      );
      if (how == 'Undo') {
        await undo(home);
      } else {
        await home.showTab(3);
        final button = find.byKey(ValueKey('trash-restore-${received.id}'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await home.settle();
        await tester.tap(
          find.byKey(const Key('homeTrashRestoreConfirmButton')),
        );
        await home.settle();
      }
      await home.waitFor(
        () => home.projects.shared.any((p) => p.id == received.id),
        reason: 'the work did not come back',
      );
      final after = home.projects.shared
          .singleWhere((p) => p.id == received.id)
          .updatedAt;
      expect(tester.takeException(), isNull);
      await home.close();
      expect(after, before);
    });
  }
}
