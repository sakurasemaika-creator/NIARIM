import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:provider/provider.dart';

import 'helpers/home_clipboard_harness.dart';

// ホームで作った複製の名前は、画面の言語の「(コピー)」と番号で付ける
// （以前は、どの言語でも日本語の「名前 (コピー)」になっていた）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];

  AppLocalizations l10nFor(String language) =>
      lookupAppLocalizations(localeFromLanguageCode(language));

  for (final language in languages) {
    testWidgets('$language: pasted, duplicated and folder copies are named '
        'in the screen language', (tester) async {
      final l10n = l10nFor(language);
      final home = await HomeClipboardHarness.open(tester, language: language);
      await home.addWork('apple');
      await home.addFolder('box');

      // 作品をコピーして2回貼り付ける。
      await home.copy(['apple']);
      await home.paste();
      await home.paste();
      // カードのメニューの「複製」。
      await home.chooseFromCardMenu('apple', home.l10n.themeDuplicateAction);
      await home.waitFor(() => home.projects.projects.length == 4);
      await home.settle();
      expect(home.projects.projects.map((p) => p.name).toSet(), {
        'apple',
        l10n.projectDuplicateName('apple'),
        l10n.projectDuplicateNameNumbered('apple', 2),
        l10n.projectDuplicateNameNumbered('apple', 3),
      });

      // フォルダをコピーして貼り付ける。
      await home.copy(['box']);
      await home.paste();
      expect(home.projects.folders.map((f) => f.name).toSet(), {
        'box',
        l10n.projectDuplicateName('box'),
      });
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }

  for (final language in const ['en', 'ko']) {
    testWidgets('$language: received works and folders are copied with '
        'names in the screen language', (tester) async {
      final l10n = l10nFor(language);
      final home = await HomeClipboardHarness.open(tester, language: language);
      final folder = (await tester.runAsync(
        () => home.projects.createSharedFolder('Inbox'),
      ))!;
      final walk = await home.addReceived('Walk');
      await home.addReceived('Sea', sharedFolderId: folder.id);
      await home.showTab(2);

      // 受け取った作品のメニューの「複製」。
      await tester.tap(find.byKey(ValueKey('receivedShareMenu_${walk.id}')));
      await home.settle();
      await tester.tap(find.text(home.l10n.themeDuplicateAction).last);
      await home.waitFor(() => home.projects.shared.length == 3);
      await home.settle();
      expect(
        home.projects.shared.map((p) => p.name),
        contains(l10n.projectDuplicateName('Walk')),
      );

      // 受け取ったフォルダをコピーして同じタブへ貼り付ける。
      await tester.longPress(find.text('Inbox').first);
      await home.settle();
      await home.copySelection();
      await home.paste();
      await home.waitFor(() => home.projects.sharedFolders.length == 2);
      final copy = home.projects.sharedFolders.firstWhere(
        (f) => f.id != folder.id,
      );
      expect(copy.name, l10n.projectDuplicateName('Inbox'));
      expect(
        home.projects.shared
            .where((p) => p.sharedFolderId == copy.id)
            .map((p) => p.name),
        [l10n.projectDuplicateName('Sea')],
      );
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }

  for (final language in const ['en', 'fr']) {
    testWidgets('$language: exported works and their folders are copied with '
        'names in the screen language', (tester) async {
      final l10n = l10nFor(language);
      final home = await HomeClipboardHarness.open(
        tester,
        language: language,
        exports: ['clip.mp4', 'loose.gif'],
      );
      final works = tester
          .element(find.byType(Scaffold).first)
          .read<WorkFolderService>();
      final folder = (await tester.runAsync(
        () => works.createFolder('Clips'),
      ))!;
      await tester.runAsync(
        () => works.moveFileToFolder('clip.mp4', folder.id),
      );
      await home.showTab(1);

      // 書き出したファイルを選んでコピーし、同じタブへ貼り付ける。
      await tester.longPress(find.text('loose.gif').first);
      await home.settle();
      await home.copySelection();
      await home.paste();
      final exported = Directory('${home.dir.path}/exports');
      await home.waitFor(
        () => exported.listSync().whereType<File>().length == 3,
      );
      expect(
        exported.listSync().whereType<File>().map(
          (f) => f.uri.pathSegments.last,
        ),
        contains('${l10n.projectDuplicateName('loose')}.gif'),
      );

      // 書き出したファイルのフォルダをコピーして貼り付ける。
      await tester.longPress(find.text('Clips').first);
      await home.settle();
      await home.copySelection();
      await home.paste();
      await home.waitFor(() => works.folders.length == 2);
      expect(
        works.folders.map((f) => f.name),
        contains(l10n.projectDuplicateName('Clips')),
      );
      final copiedClip = File(
        '${exported.path}/${l10n.projectDuplicateName('clip')}.mp4',
      );
      await home.waitFor(
        copiedClip.existsSync,
        reason: 'the work in the folder was not copied as ${copiedClip.path}',
      );
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }
}
