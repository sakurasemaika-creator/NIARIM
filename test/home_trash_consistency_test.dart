import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/services/project_service.dart'
    show FavoriteProjectDeleteException, ProjectFolder;
import 'package:niarim/widgets/project_trash_dialog.dart';

import 'helpers/home_clipboard_harness.dart';
import 'helpers/paragraph_lines.dart';

/// ゴミ箱まわりの小さな食い違い（DISC124の（1）（2）（3）（4）（10））を、
/// 本物のアプリのホームで確かめる。
/// （1）ゴミ箱のフォルダの行にも、作品・ファイルの行と同じく移した日を出す。
/// （2）書き出したファイルをゴミ箱へ移す確認も、作品・フォルダと同じ形
///     （名前を出し、「移動」は差し色）。
/// （3）ゴミ箱の行の2行目は、数と単位（「10秒」）・日付の途中で折り返さない。
/// （4）中にお気に入りの作品があるフォルダを断るときは、それが理由だと言う。
/// （10）ゴミ箱への貼り付けの確認では、お気に入りで移さないものを分けて出す。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const languages = ['ja', 'en', 'es', 'fr', 'ko', 'zh', 'zh_Hant'];

  String plain(Text text) =>
      text.semanticsLabel ?? text.data ?? text.textSpan?.toPlainText() ?? '';

  List<String> textsIn(WidgetTester tester, Finder scope) => [
    for (final text in tester.widgetList<Text>(
      find.descendant(
        of: scope,
        matching: find.byWidgetPredicate((widget) => widget is Text),
      ),
    ))
      plain(text).replaceAll(wordJoiner, ''),
  ];

  // 書き換えた後にだけある文（直す前のアプリでは呼べない）。
  String newText(AppLocalizations l10n, String key) =>
      switch (key) {
            'folderHoldsFavorite' =>
              (l10n as dynamic).homeTrashFolderHoldsFavorite,
            'pasteKeepsFavorites' =>
              (l10n as dynamic).homePasteToTrashKeepsFavorites,
            _ => throw ArgumentError(key),
          }
          as String;

  // フォルダの行の1行目は移した日だけ。作品・ファイルの種類の名前
  // （「作成したプロジェクト」「受け取った共有ファイル」）は、フォルダの
  // アイコンと名前の下では、フォルダを1つの作品・ファイルと言ってしまう
  // （種類は絞り込みのチップで分ける）。
  for (final language in ['ja', 'en', 'fr']) {
    testWidgets('(1) a folder row in the Trash shows the day it was moved, '
        'and does not call the folder a project or a file ($language)', (
      tester,
    ) async {
      final home = await HomeClipboardHarness.open(tester, language: language);
      final box = await home.addFolder('box');
      await home.addWork('inside', folderId: box.id);
      await home.addWork('loose');
      final inbox = (await tester.runAsync(
        () => home.projects.createSharedFolder('inbox'),
      ))!;
      await home.addReceived('gift', sharedFolderId: inbox.id);
      await tester.runAsync(() async {
        await home.projects.moveFolderToTrash(box.id);
        await home.projects.moveFolderToTrash(inbox.id, shared: true);
        final loose = home.projects.projects.firstWhere(
          (p) => p.name == 'loose',
        );
        await home.projects.deleteProject(loose.id);
      });
      await home.settleIo(2);
      await home.showTab(3);
      final l10n = home.l10n;
      for (final (id, inside) in [(box.id, 'inside'), (inbox.id, 'gift')]) {
        final record = home.projects.trashedFolders.firstWhere(
          (t) => t.folder.id == id,
        );
        final rowTexts = textsIn(
          tester,
          find.byKey(ValueKey('trashedFolder_$id')),
        );
        final folderRow = rowTexts.join('\n');
        debugPrint('folder row: $folderRow');
        expect(folderRow, contains(l10n.homeTrashDeletedOn(record.deletedAt)));
        for (final kind in [
          l10n.homeTrashKindCreatedProject,
          l10n.homeTrashKindReceivedShare,
        ]) {
          expect(
            folderRow,
            isNot(contains(kind)),
            reason: 'a folder row says "$kind"',
          );
        }
        // 中身（作品の名前）も出したまま。
        expect(folderRow, contains(inside));
      }
      // 作品の行は種類と移した日のまま。
      final looseRow = textsIn(
        tester,
        find.ancestor(of: find.text('loose'), matching: find.byType(ListTile)),
      ).join('\n');
      expect(looseRow, contains(l10n.homeTrashKindCreatedProject));
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }

  testWidgets('(2) moving an exported file to the Trash asks like a work or '
      'a folder: with its name and the accent-coloured Move', (tester) async {
    final home = await HomeClipboardHarness.open(
      tester,
      exports: ['clip_1.gif', 'clip_2.gif'],
    );
    await home.showTab(1);
    final card = find.ancestor(
      of: find.text('clip_1.gif'),
      matching: find.byType(ExportedWorkCard),
    );
    await tester.tap(
      find.descendant(
        of: card.first,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await home.settle();
    final l10n = home.l10n;
    await tester.tap(find.text(l10n.homeMoveToTrash).last);
    await home.settle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final texts = textsIn(tester, dialog);
    debugPrint('exported file question: $texts');
    expect(texts, contains('clip_1.gif'), reason: 'the file is not named');
    expect(find.byType(ProjectTrashDialog), findsOneWidget);
    final scheme = Theme.of(tester.element(dialog)).colorScheme;
    final confirm = tester.widget<FilledButton>(
      find.descendant(of: dialog, matching: find.byType(FilledButton)),
    );
    final fill = confirm.style?.backgroundColor?.resolve({});
    expect(fill, isNot(scheme.error), reason: 'Move is painted as danger');
    expect(fill, scheme.primary);
    await tester.tap(
      find.descendant(of: dialog, matching: find.byType(FilledButton)),
    );
    await home.waitFor(() => find.byType(AlertDialog).evaluate().isEmpty);
    await home.waitFor(
      () => find.text('clip_1.gif').evaluate().isEmpty,
      reason: 'the moved file stayed in the list',
    );
    expect(find.text('clip_2.gif'), findsWidgets);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  // 共有の「自分が作成したもの」（.niashare）をゴミ箱へ移す確認も、作品・
  // フォルダ・書き出したファイルと同じ形（名前を出し、移せなかったときは
  // 中に理由を出して開いたまま）。以前は名前の無い別のダイアログだった。
  testWidgets('(2) moving a created share file to the Trash asks with its '
      'name, like the others', (tester) async {
    final home = await HomeClipboardHarness.open(tester);
    final file = File(
      '${home.dir.path}/niarim/shared/outgoing/mine_share.niashare',
    )..createSync(recursive: true);
    file.writeAsBytesSync(List.filled(64, 1));
    await tester.runAsync(() => home.projects.refreshOutgoingShares());
    await home.settleIo(2);
    await home.showTab(2);
    await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
    await home.settleIo(2);
    await home.settle();
    final menu = find.byKey(ValueKey('outgoingShareMenu_${file.path}'));
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await home.settle();
    final l10n = home.l10n;
    await tester.tap(find.text(l10n.projectDetailTrashMenuItem).last);
    await home.settle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    final texts = textsIn(tester, dialog);
    debugPrint('created share file question: $texts');
    expect(texts, contains('mine_share'), reason: 'the file is not named');
    expect(find.byType(ProjectTrashDialog), findsOneWidget);
    await tester.tap(
      find.descendant(of: dialog, matching: find.byType(FilledButton)),
    );
    await home.waitFor(() => find.byType(AlertDialog).evaluate().isEmpty);
    await home.waitFor(
      () => !file.existsSync() && home.projects.outgoingShares.isEmpty,
      reason: 'the file was not moved',
    );
    await home.settle();
    expect(menu, findsNothing);
    expect(tester.takeException(), isNull);
    await home.close();
  });

  for (final language in languages) {
    testWidgets('(3) a Trash row keeps numbers with their units and the date '
        'whole when it wraps ($language)', (tester) async {
      final home = await HomeClipboardHarness.open(
        tester,
        language: language,
        realFonts: true,
        size: const Size(360, 900),
      );
      final project = (await tester.runAsync(
        () => home.projects.createProject(
          name: 'clip',
          fps: 12,
          durationSeconds: 10,
          backgroundColor: 0xFFFFFFFF,
        ),
      ))!;
      await tester.runAsync(() async {
        await home.projects.saveProject(project.id);
        await home.projects.deleteProject(project.id);
      });
      await home.settleIo(2);
      await home.showTab(3);
      final l10n = home.l10n;
      final deleted = home.projects.deletedAtOf(project.id)!;
      final date = DateFormat.yMd(l10n.localeName).format(deleted);
      final units = RegExp(r'\d+(?:fps|ips|s|秒|초)');
      final problems = <String>[];
      var checked = 0;
      for (final scale in [1.0, 1.3, 2.0]) {
        for (var width = 300.0; width <= 440; width += 10) {
          tester.view.physicalSize = Size(width, 900);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await home.settle();
          for (final element
              in find
                  .byWidgetPredicate(
                    (w) =>
                        w is RichText &&
                        RegExp(r'\d+(?:fps|ips)').hasMatch(
                          w.text
                              .toPlainText(includeSemanticsLabels: false)
                              .replaceAll(wordJoiner, ''),
                        ),
                  )
                  .evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            final lines = ParagraphLines(paragraph);
            // 改行しない空白は、空白として探す（字の数は同じ）。
            final text = lines.visible.replaceAll('\u00a0', ' ');
            final parts = [
              date,
              for (final match in units.allMatches(text)) match[0]!,
            ];
            for (final part in parts) {
              final at = text.indexOf(part);
              if (at < 0) continue;
              checked++;
              final painter = TextPainter(
                text: TextSpan(
                  text: part,
                  style: (paragraph.text as TextSpan).style,
                ),
                textDirection: paragraph.textDirection,
                textScaler: paragraph.textScaler,
                locale: paragraph.locale,
              )..layout();
              final fits = painter.width <= paragraph.constraints.maxWidth;
              painter.dispose();
              if (!fits) continue;
              if (lines.breaksWithin(at, at + part.length).isNotEmpty) {
                problems.add(
                  '$width x$scale 「$part」: ${lines.lines.join(' / ')}',
                );
              }
            }
          }
        }
      }
      debugPrint('$language: $checked parts checked, ${problems.length} split');
      expect(checked, greaterThan(0), reason: 'no Trash row was found');
      expect(problems, isEmpty);
      expect(tester.takeException(), isNull);
      await home.close();
    });
  }

  group('(4) a folder holding a favourite work', () {
    testWidgets('its menu says the favourite inside is the reason', (
      tester,
    ) async {
      final home = await HomeClipboardHarness.open(tester);
      final box = await home.addFolder('box');
      final favourite = await home.addWork('star', folderId: box.id);
      await tester.runAsync(
        () => home.projects.setFavorite(favourite.id, true),
      );
      await home.settleIo(2);
      final l10n = home.l10n;
      await home.chooseFromCardMenu('box', l10n.homeMoveToTrash);
      await home.settle();
      expect(find.byType(ProjectTrashDialog), findsNothing);
      expect(home.snackText(), newText(l10n, 'folderHoldsFavorite'));
      expect(home.projects.trashedFolders, isEmpty);
      expect(tester.takeException(), isNull);
      await home.close();
    });

    testWidgets('a selection holding it says the same', (tester) async {
      final home = await HomeClipboardHarness.open(tester);
      final box = await home.addFolder('box');
      final favourite = await home.addWork('star', folderId: box.id);
      await home.addWork('loose');
      await tester.runAsync(
        () => home.projects.setFavorite(favourite.id, true),
      );
      await home.settleIo(2);
      final l10n = home.l10n;
      await home.select(['box', 'loose']);
      await tester.tap(find.byTooltip(l10n.homeMoveToTrash));
      await home.settle();
      expect(find.byType(ProjectTrashDialog), findsNothing);
      expect(home.snackText(), newText(l10n, 'folderHoldsFavorite'));
      expect(home.projects.trash, isEmpty);
      await home.close();
    });

    testWidgets('a folder that is itself a favourite keeps the plain '
        'favourite refusal', (tester) async {
      final home = await HomeClipboardHarness.open(tester);
      final box = await home.addFolder('box');
      await tester.runAsync(() => home.projects.toggleFolderFavorite(box.id));
      await home.settleIo(2);
      final l10n = home.l10n;
      await home.chooseFromCardMenu('box', l10n.homeMoveToTrash);
      await home.settle();
      expect(home.snackText(), l10n.commonFavoriteDeleteBlocked);
      await home.close();
    });

    // お気に入りのフォルダが下の階層にあるフォルダも、お気に入りの作品が
    // 入っているフォルダと同じく、確かめる前に理由を出して断る（以前は
    // 一番上のフォルダと作品しか見ず、お気に入りのフォルダを中身として
    // ゴミ箱へ移した）。
    Future<(HomeClipboardHarness, ProjectFolder)> openWithNestedFavourite(
      WidgetTester tester,
    ) async {
      final home = await HomeClipboardHarness.open(tester);
      final parent = await home.addFolder('Parent');
      final child = await home.addFolder('Middle', parentId: parent.id);
      final favourite = await home.addFolder('FavChild', parentId: child.id);
      await home.addWork('plain', folderId: favourite.id);
      await tester.runAsync(
        () => home.projects.toggleFolderFavorite(favourite.id),
      );
      await home.settleIo(2);
      return (home, parent);
    }

    testWidgets('a favourite folder deeper inside: the menu says why '
        'before asking', (tester) async {
      final (home, _) = await openWithNestedFavourite(tester);
      final l10n = home.l10n;
      await home.chooseFromCardMenu('Parent', l10n.homeMoveToTrash);
      await home.settle();
      expect(find.byType(ProjectTrashDialog), findsNothing);
      expect(home.snackText(), newText(l10n, 'folderHoldsFavorite'));
      expect(home.projects.trashedFolders, isEmpty);
      expect(home.projects.folders.map((f) => f.name), contains('FavChild'));
      expect(tester.takeException(), isNull);
      await home.close();
    });

    testWidgets('a favourite folder deeper inside: a selection says the same', (
      tester,
    ) async {
      final (home, _) = await openWithNestedFavourite(tester);
      await home.addWork('loose');
      final l10n = home.l10n;
      await home.select(['Parent', 'loose']);
      await tester.tap(find.byTooltip(l10n.homeMoveToTrash));
      await home.settle();
      expect(find.byType(ProjectTrashDialog), findsNothing);
      expect(home.snackText(), newText(l10n, 'folderHoldsFavorite'));
      expect(home.projects.trash, isEmpty);
      expect(home.projects.trashedFolders, isEmpty);
      await home.close();
    });

    testWidgets('a favourite folder deeper inside: the service refuses too', (
      tester,
    ) async {
      final (home, parent) = await openWithNestedFavourite(tester);
      Object? failure;
      await tester.runAsync(() async {
        try {
          await home.projects.moveFolderToTrash(parent.id);
        } catch (error) {
          failure = error;
        }
      });
      await home.settleIo(2);
      expect(failure, isA<FavoriteProjectDeleteException>());
      expect(home.projects.trashedFolders, isEmpty);
      expect(home.projects.trash, isEmpty);
      expect(
        home.projects.folders.map((f) => f.name).toSet(),
        containsAll({'Parent', 'Middle', 'FavChild'}),
      );
      await home.close();
    });

    testWidgets('a favourite folder deeper inside: pasting into the Trash '
        'lists it apart and keeps it', (tester) async {
      final (home, _) = await openWithNestedFavourite(tester);
      await home.addWork('apple');
      await home.copy(['Parent', 'apple']);
      await home.showTab(3);
      await tester.tap(home.pasteButton);
      await home.settle();
      final l10n = home.l10n;
      final dialog = find.byKey(const Key('homePasteToTrashDialog'));
      expect(dialog, findsOneWidget);
      final texts = textsIn(tester, dialog);
      debugPrint('paste a folder holding a favourite folder: $texts');
      final note = texts.indexOf(newText(l10n, 'pasteKeepsFavorites'));
      expect(note, isNonNegative, reason: 'Parent is not set apart');
      expect(texts.indexOf(l10n.commonBulletItem('Parent')), greaterThan(note));
      expect(texts.indexOf(l10n.commonBulletItem('apple')), lessThan(note));
      await tester.tap(find.byKey(const Key('homePasteTrashConfirmButton')));
      await home.waitFor(() => home.projects.trash.length == 1);
      await home.settleIo(2);
      expect(home.projects.trash.single.name, 'apple');
      expect(home.projects.trashedFolders, isEmpty);
      expect(
        home.projects.folders.map((f) => f.name).toSet(),
        containsAll({'Parent', 'Middle', 'FavChild'}),
      );
      expect(tester.takeException(), isNull);
      await home.close();
    });
  });

  group('(10) pasting into the Trash', () {
    testWidgets('the question lists favourites apart, as staying', (
      tester,
    ) async {
      final home = await HomeClipboardHarness.open(tester);
      await home.addWork('apple');
      final banana = await home.addWork('banana');
      await home.addWork('cherry');
      await tester.runAsync(() => home.projects.setFavorite(banana.id, true));
      await home.settleIo(2);
      await home.copy(['banana', 'apple', 'cherry']);
      await home.showTab(3);
      await tester.tap(home.pasteButton);
      await home.settle();
      final l10n = home.l10n;
      final dialog = find.byKey(const Key('homePasteToTrashDialog'));
      expect(dialog, findsOneWidget);
      final texts = textsIn(tester, dialog);
      debugPrint('paste into Trash question: $texts');
      final note = texts.indexOf(newText(l10n, 'pasteKeepsFavorites'));
      expect(note, isNonNegative, reason: 'favourites are not set apart');
      final bananaAt = texts.indexOf(l10n.commonBulletItem('banana'));
      expect(bananaAt, greaterThan(note));
      expect(texts.indexOf(l10n.commonBulletItem('apple')), lessThan(note));
      expect(texts.indexOf(l10n.commonBulletItem('cherry')), lessThan(note));
      await tester.tap(find.byKey(const Key('homePasteTrashConfirmButton')));
      await home.waitFor(() => home.projects.trash.length == 2);
      expect(home.projects.trash.map((p) => p.name).toSet(), {
        'apple',
        'cherry',
      });
      await home.close();
    });

    // お気に入りのフォルダ自身も、メニュー・選んで移すときと同じく移さない
    // （以前はゴミ箱への貼り付けだけが中のお気に入りしか見ず、お気に入りの
    // フォルダを移していた）。確かめるときも、移さないものとして分けて出す。
    testWidgets('a folder that is itself a favourite is listed apart and '
        'stays out of the Trash', (tester) async {
      final home = await HomeClipboardHarness.open(tester);
      final box = await home.addFolder('box');
      await home.addWork('inside', folderId: box.id);
      await home.addWork('apple');
      await tester.runAsync(() => home.projects.toggleFolderFavorite(box.id));
      await home.settleIo(2);
      await home.copy(['box', 'apple']);
      await home.showTab(3);
      await tester.tap(home.pasteButton);
      await home.settle();
      final l10n = home.l10n;
      final dialog = find.byKey(const Key('homePasteToTrashDialog'));
      expect(dialog, findsOneWidget);
      final texts = textsIn(tester, dialog);
      debugPrint('paste a favourite folder into Trash: $texts');
      final note = texts.indexOf(newText(l10n, 'pasteKeepsFavorites'));
      expect(
        note,
        isNonNegative,
        reason: 'the favourite folder is not set apart',
      );
      expect(texts.indexOf(l10n.commonBulletItem('box')), greaterThan(note));
      expect(texts.indexOf(l10n.commonBulletItem('apple')), lessThan(note));
      await tester.tap(find.byKey(const Key('homePasteTrashConfirmButton')));
      await home.waitFor(() => home.projects.trash.length == 1);
      await home.settleIo(2);
      expect(home.projects.trash.single.name, 'apple');
      expect(home.projects.trashedFolders, isEmpty);
      expect(home.projects.folders.map((f) => f.id), contains(box.id));
      // 結果の知らせ（コピーの知らせの後に出る）が、残した理由を言う。
      await home.waitFor(
        () =>
            home.snackText()?.contains(l10n.homePasteSkippedFavorite(1)) ??
            false,
        reason: 'the result does not say why the folder stayed',
      );
      expect(tester.takeException(), isNull);
      await home.close();
    });

    testWidgets('the service itself refuses to move a favourite folder', (
      tester,
    ) async {
      final home = await HomeClipboardHarness.open(tester);
      final box = await home.addFolder('box');
      await tester.runAsync(() => home.projects.toggleFolderFavorite(box.id));
      Object? failure;
      await tester.runAsync(() async {
        try {
          await home.projects.moveFolderToTrash(box.id);
        } catch (error) {
          failure = error;
        }
      });
      await home.settleIo(2);
      expect(failure, isA<FavoriteProjectDeleteException>());
      expect(home.projects.trashedFolders, isEmpty);
      expect(home.projects.folders.map((f) => f.id), contains(box.id));
      await home.close();
    });

    testWidgets('only favourites: no question to move nothing, and the '
        'result says why they stayed', (tester) async {
      final home = await HomeClipboardHarness.open(tester);
      final banana = await home.addWork('banana');
      await home.addWork('apple');
      await tester.runAsync(() => home.projects.setFavorite(banana.id, true));
      await home.settleIo(2);
      await home.copy(['banana']);
      await home.showTab(3);
      await tester.tap(home.pasteButton);
      await home.settle();
      expect(find.byKey(const Key('homePasteToTrashDialog')), findsNothing);
      final l10n = home.l10n;
      await home.waitFor(
        () => home.snackText() == l10n.homePasteSkippedFavorite(1),
      );
      expect(home.projects.trash, isEmpty);
      await home.close();
    });
  });
}
