// 名前と整理（所有者の判断、2026-11-27、全部入りの作品づくりの判断カードJ19の
// うち3つ）：作品一覧のファイルの名前の変更、自動塗り設定の複製（1つずつ）、
// 演出フィルターの名前の変更。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:provider/provider.dart';

import 'helpers/home_keyboard_harness.dart';

void main() {
  testWidgets('an exported file is renamed and keeps its folder', (
    tester,
  ) async {
    final home = await HomeKeyboardHarness.open(tester);
    final folders = tester
        .element(find.byType(MaterialApp).first)
        .read<WorkFolderService>();
    late Directory exports;
    await tester.runAsync(() async {
      exports = await ExportStorage.createManagedDirectory();
      File(
        '${exports.path}/clip.gif',
      ).writeAsBytesSync(img.encodeGif(img.Image(width: 8, height: 8)));
      File(
        '${exports.path}/taken.gif',
      ).writeAsBytesSync(img.encodeGif(img.Image(width: 8, height: 8)));
      final folder = await folders.createFolder('box');
      await folders.moveFileToFolder('clip.gif', folder.id);
      ExportStorage.invalidate();
      await ExportEngine.listExportedFiles(forceRefresh: true);
    });
    Future<void> io() async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await home.settle();
    }

    final l10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    await tester.tap(find.byKey(const ValueKey('home_tab_1')));
    await io();
    // Into the folder, then the file's menu.
    await tester.tap(find.text('box').first);
    await io();
    final card = find.ancestor(
      of: find.text('clip.gif'),
      matching: find.byType(ExportedWorkCard),
    );
    await tester.tap(
      find.descendant(of: card, matching: find.byIcon(Icons.more_vert)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.commonRename).last);
    await tester.pumpAndSettle();
    final field = find.byType(TextField).last;
    // A name another file has is refused, and the dialog stays open.
    await tester.enterText(field, 'taken');
    await tester.tap(find.text(l10n.commonChange).last);
    await io();
    expect(find.text(l10n.homeWorkFileNameTaken), findsOneWidget);
    await tester.enterText(field, 'sunset');
    await tester.tap(find.text(l10n.commonChange).last);
    await io();
    expect(File('${exports.path}/sunset.gif').existsSync(), isTrue);
    expect(File('${exports.path}/clip.gif').existsSync(), isFalse);
    expect(
      folders.folderIdOf('sunset.gif'),
      isNotNull,
      reason: 'it stays in its folder',
    );
    for (var i = 0; i < 40 && find.text('sunset.gif').evaluate().isEmpty; i++) {
      await io();
    }
    expect(find.text('sunset.gif'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
