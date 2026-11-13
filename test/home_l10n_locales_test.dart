// ホームの手書きの表・日本語と英語だけの文をARBへ移したことの見張り。
//
// 以前は languageCode で分けた表で、スペイン語・フランス語は英語、繁体字は
// 簡体字（'zh'の行）、ダイアログ・メニューの多くは日本語以外すべて英語だった。
// 本物のアプリを起動処理から組み立ててホームを開き、各言語の文を確かめる。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/export_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/exported_work_card.dart';
import 'package:niarim/screens/home/widgets/home_selection_toolbar.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/export_storage.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/work_folder_service.dart';
import 'package:niarim/utils/app_locale.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// 言語ごとに、画面に出るはずの文。
const _expected = <String, Map<String, String>>{
  'es': {
    'received': 'Recibidos',
    'created': 'Creados por mí',
    'createdEmpty': 'Todavía no has creado archivos compartidos',
    'createdProject': 'Proyecto creado',
    'receivedShare': 'Compartido contigo',
    'createdShare': 'Compartido por ti',
    'exportedWork': 'Obra exportada',
    'cut2': '2 elementos cortados',
    'copied1': '1 elemento copiado',
    'clear': 'Cancelar',
    'open': 'Abrir',
    'thumbnail': 'Cambiar miniatura',
  },
  'fr': {
    'received': 'Reçus',
    'created': 'Créés par moi',
    'createdEmpty': 'Vous n’avez encore créé aucun fichier partagé',
    'createdProject': 'Projet créé',
    'receivedShare': 'Partagé avec vous',
    'createdShare': 'Partagé par vous',
    'exportedWork': 'Œuvre exportée',
    'cut2': '2 éléments coupés',
    'copied1': '1 élément copié',
    'clear': 'Annuler',
    'open': 'Ouvrir',
    'thumbnail': 'Changer la miniature',
  },
  'ko': {
    'received': '받은 파일',
    'created': '내가 만든 파일',
    'createdEmpty': '생성한 공유 파일이 없습니다',
    'createdProject': '내 프로젝트',
    'receivedShare': '받은 공유 파일',
    'createdShare': '내가 만든 공유 파일',
    'exportedWork': '내보낸 작품',
    'cut2': '2개 항목 잘라냄',
    'copied1': '1개 항목 복사함',
    'clear': '취소',
    'open': '열기',
    'thumbnail': '썸네일 변경',
  },
  'zh': {
    'received': '收到的文件',
    'created': '我创建的文件',
    'createdEmpty': '尚未创建共享文件',
    'createdProject': '创建的项目',
    'receivedShare': '收到的共享文件',
    'createdShare': '我创建的共享文件',
    'exportedWork': '导出的作品',
    'cut2': '已剪切2项',
    'copied1': '已复制1项',
    'clear': '清除',
    'open': '打开',
    'thumbnail': '更换缩略图',
  },
  'zh_Hant': {
    'received': '收到的檔案',
    'created': '我建立的檔案',
    'createdEmpty': '尚未建立共享檔案',
    'createdProject': '建立的專案',
    'receivedShare': '收到的共享檔案',
    'createdShare': '我建立的共享檔案',
    'exportedWork': '匯出的作品',
    'cut2': '已剪下2項',
    'copied1': '已複製1項',
    'clear': '清除',
    'open': '開啟',
    'thumbnail': '更換縮圖',
  },
};

Future<void> _frames(WidgetTester tester, [int count = 6]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _settleIo(WidgetTester tester, [int rounds = 3]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  await _frames(tester, 3);
}

Future<void> _openHome(
  WidgetTester tester,
  String language, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'first_launch': false,
    'language': language,
    'force_pc_mode': 0,
    firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    ...prefs,
  });
  final dir = Directory.systemTemp.createTempSync('home-l10n-');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (_) async => dir.path);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1000);
  addTearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } on FileSystemException {
      // 後始末の途中で保存が走っていても、テストの結果は変えない。
    }
  });
  ExportStorage.invalidate();
  Directory('${dir.path}/exports').createSync();
  await tester.runAsync(
    () => ExportEngine.listExportedFiles(forceRefresh: true),
  );
  appRouter.go('/home');
  final providers = await tester.runAsync(buildAppProviders);
  await tester.pumpWidget(
    MultiProvider(providers: providers!, child: const NiarimApp()),
  );
  await _frames(tester);
  await _settleIo(tester);
}

Future<void> _showTab(WidgetTester tester, int index) async {
  tester
      .widget<TabBarView>(find.byType(TabBarView))
      .controller!
      .animateTo(index);
  await _frames(tester, 8);
  await _settleIo(tester, 2);
}

String _text(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).data!;

Widget _localized(String language, Widget child) => MaterialApp(
  locale: localeFromLanguageCode(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  for (final MapEntry(key: language, value: expected) in _expected.entries) {
    testWidgets('$language: 共有の切り替え・空の表示・ゴミ箱の種類がその言語で出る', (tester) async {
      await _openHome(tester, language);

      await _showTab(tester, 2);
      expect(
        _text(tester, find.byKey(const Key('sharedReceivedFilter'))),
        expected['received'],
      );
      expect(
        _text(tester, find.byKey(const Key('sharedOutgoingFilter'))),
        expected['created'],
      );
      await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
      await _frames(tester);
      await _settleIo(tester, 2);
      expect(find.text(expected['createdEmpty']!), findsOneWidget);

      await _showTab(tester, 3);
      for (final (kind, label) in [
        ('createdProject', expected['createdProject']!),
        ('receivedShare', expected['receivedShare']!),
        ('createdShare', expected['createdShare']!),
        ('exportedWork', expected['exportedWork']!),
      ]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('trashKind_$kind')),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: '$language trashKind_$kind',
        );
      }
    });

    testWidgets('$language: コピー・切り取りの帯の件数とボタン', (tester) async {
      Future<void> show({required int count, required bool cut}) =>
          tester.pumpWidget(
            _localized(
              language,
              HomeClipboardToolbar(
                itemCount: count,
                isCut: cut,
                onPaste: () {},
                onClear: () {},
              ),
            ),
          );
      await show(count: 2, cut: true);
      await tester.pump();
      expect(find.text(expected['cut2']!), findsOneWidget);
      expect(find.text(expected['clear']!), findsOneWidget);
      await show(count: 1, cut: false);
      await tester.pump();
      expect(find.text(expected['copied1']!), findsOneWidget);
    });

    testWidgets('$language: 書き出した作品のメニュー', (tester) async {
      await tester.pumpWidget(
        _localized(
          language,
          ExportedWorkCard(
            name: 'clip.mp4',
            metadata: '',
            icon: Icons.movie_outlined,
            moveLabel: 'move',
            shareLabel: 'share',
            deleteLabel: 'delete',
            onOpen: () {},
            onMove: () {},
            onShare: () {},
            onDelete: () {},
            onChangeThumbnail: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('exportedWorkMoreMenu')));
      await tester.pumpAndSettle();
      expect(find.text(expected['open']!), findsOneWidget);
      expect(find.text(expected['thumbnail']!), findsOneWidget);
    });
  }

  // メニュー・ダイアログ・日付・フォルダの件数。以前は英語の直書き・
  // 日本語の書き方の日付（2026/11/13）・名詞の無い数（「0」）・
  // 同じ文の並ぶダイアログが出ていた。
  for (final language in const ['es', 'zh_Hant']) {
    testWidgets('$language: ホームのメニュー・ダイアログ・日付・フォルダの件数がその言語で出る', (tester) async {
      final l10n = lookupAppLocalizations(localeFromLanguageCode(language));
      final tag = localeFromLanguageCode(language).toString();
      // フォルダの件数と共有ファイルの日付は、詳細表示の行に出る。
      await _openHome(
        tester,
        language,
        prefs: const {
          'home.worksViewMode.v1': 'detail',
          'home.sharedViewMode.v1': 'detail',
        },
      );
      final home = tester.element(find.byType(HomeScreen));
      final projects = home.read<ProjectService>();
      final today = DateTime.now();
      final ids = (await tester.runAsync(() async {
        final project = await projects.createProject(
          name: 'P1',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 64,
          exportHeight: 64,
        );
        final deleted = await projects.createProject(
          name: 'P2',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 64,
          exportHeight: 64,
        );
        await projects.deleteProject(deleted.id);
        await projects.createOutgoingShare(project: project);
        final worksFolder = await home.read<WorkFolderService>().createFolder(
          'WF',
        );
        final sharedFolder = await projects.createSharedFolder('SF');
        return (project.id, deleted.id, worksFolder.id, sharedFolder.id);
      }))!;
      await _settleIo(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      // 見つかった食い違いをすべて集めてから最後に確かめる。
      final problems = <String>[];
      void check(bool ok, String what) {
        if (!ok) problems.add(what);
      }

      // 行の押下はダブルタップを待つので、メニューが開くのは少し後。
      Future<void> openMenu(Finder button) async {
        await tester.tap(button);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      }

      Future<List<String>> menuTexts(Finder button) async {
        await openMenu(button);
        final texts = [
          for (final item in tester.widgetList<PopupMenuItem<String>>(
            find.byType(PopupMenuItem<String>),
          ))
            if (item.child is Text) (item.child! as Text).data!,
        ];
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        return texts;
      }

      List<String> dialogTexts() => [
        for (final text in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Text),
          ),
        ))
          if ((text.data ?? '').isNotEmpty) text.data!,
      ];

      // プロジェクト：メニューとサムネイルのダイアログ。
      final projectMenuButton = find
          .descendant(
            of: find.byType(ProjectListWidget),
            matching: find.byType(PopupMenuButton<String>),
          )
          .first;
      final projectMenu = await menuTexts(projectMenuButton);
      expect(projectMenu, contains(l10n.thumbnailChangeAction));
      expect(projectMenu, contains(l10n.themeDuplicateAction));
      await openMenu(projectMenuButton);
      await tester.tap(find.text(l10n.thumbnailChangeAction).last);
      await _frames(tester, 8);
      await _settleIo(tester, 2);
      await tester.tap(find.byKey(const Key('projectThumbnailCustom')));
      await _frames(tester, 4);
      final thumbnailTexts = dialogTexts();
      check(
        thumbnailTexts.contains(l10n.thumbnailSelectFrame) &&
            thumbnailTexts.length == thumbnailTexts.toSet().length,
        'プロジェクトのサムネイルのダイアログに同じ文が2つ並ぶ: $thumbnailTexts',
      );
      await tester.tap(find.text(l10n.commonCancel).last);
      await _frames(tester, 8);

      // 作品一覧：フォルダの行の件数と、フォルダのメニューの説明。
      // 空のフォルダは、プロジェクトのフォルダの行と同じ「中身なし」の文。
      await _showTab(tester, 1);
      final worksFolderRow = find.byKey(ValueKey('collectionFolder_${ids.$3}'));
      expect(worksFolderRow, findsOneWidget);
      check(
        find
                .descendant(
                  of: worksFolderRow,
                  matching: find.text(l10n.homeFolderContents(0, 0)),
                )
                .evaluate()
                .length ==
            1,
        '作品のフォルダの行に「${l10n.homeFolderContents(0, 0)}」が無い',
      );
      check(
        find
            .descendant(of: worksFolderRow, matching: find.text('0'))
            .evaluate()
            .isEmpty,
        '作品のフォルダの行に名詞の無い「0」',
      );
      check(
        tester
                .widget<IconButton>(
                  find.byKey(ValueKey('collectionFolderMenu_${ids.$3}')),
                )
                .tooltip ==
            l10n.homeFolderMenuTooltip,
        'フォルダのメニューの説明',
      );

      // 共有：受け取ったものの区分のフォルダの件数、自分が作成したものの
      // 日付とメニュー。
      await _showTab(tester, 2);
      check(
        find
                .descendant(
                  of: find.byKey(ValueKey('collectionFolder_${ids.$4}')),
                  matching: find.text(l10n.homeFolderContents(0, 0)),
                )
                .evaluate()
                .length ==
            1,
        '共有のフォルダの行に「${l10n.homeFolderContents(0, 0)}」が無い',
      );
      await tester.tap(find.byKey(const Key('sharedOutgoingFilter')));
      await _frames(tester);
      await _settleIo(tester, 2);
      final share = projects.outgoingShares.single;
      final dateTime = DateFormat.yMd(tag).add_jm().format(share.updatedAt);
      check(
        find.textContaining(dateTime).evaluate().length == 1,
        '自分が作成した共有ファイルの日付が、書き出した作品の行と同じ書き方'
        '（$dateTime）でない',
      );
      final outgoingMenuButton = find.byKey(
        ValueKey('outgoingShareMenu_${share.path}'),
      );
      final outgoingMenu = await menuTexts(outgoingMenuButton);
      expect(outgoingMenu, contains(l10n.themeDuplicateAction));

      // プロジェクトを、形式の違う「自分が作成したもの」へ貼り付ける。
      await _showTab(tester, 0);
      await tester.longPress(find.text('P1').first);
      await tester.pump(const Duration(milliseconds: 400));
      await _frames(tester);
      await tester.tap(find.byIcon(Icons.content_copy).first);
      await _frames(tester);
      await _showTab(tester, 2);
      await tester.tap(find.byKey(const Key('homeCrossTabPasteButton')));
      await _frames(tester);
      expect(
        find.byKey(const Key('homePasteRestrictionDialog')),
        findsOneWidget,
      );
      check(
        listEquals(dialogTexts(), [
          l10n.homePasteRestrictionTitle,
          l10n.homePasteCrossFormatBody,
          l10n.commonClose,
        ]),
        '貼り付けられないときのダイアログ: ${dialogTexts()}',
      );
      await tester.tap(find.text(l10n.commonClose));
      await _frames(tester);

      // ゴミ箱：消した日付（書き出した作品の行と同じ、その言語の日付の
      // 書き方）・コピーのボタン・復元のダイアログ。
      await _showTab(tester, 3);
      final deletedOn = DateFormat.yMd(
        tag,
      ).format(projects.deletedAtOf(ids.$2) ?? today);
      final restore = find.byKey(ValueKey('trash-restore-${ids.$2}'));
      expect(restore, findsOneWidget);
      check(
        find
                .descendant(
                  of: find
                      .ancestor(of: restore, matching: find.byType(Card))
                      .first,
                  matching: find.textContaining(deletedOn),
                )
                .evaluate()
                .length ==
            1,
        'ゴミ箱の消した日付が $deletedOn の書き方でない',
      );
      check(
        find
                .descendant(
                  of: find.byKey(ValueKey('trashCopyProject_${ids.$2}')),
                  matching: find.text(l10n.commonCopy),
                )
                .evaluate()
                .length ==
            1,
        'ゴミ箱のコピーのボタン',
      );
      check(
        l10n.commonCopy != l10n.themeDuplicateAction,
        'ゴミ箱の「コピー」と共有のメニューの「複製」が同じ文（${l10n.commonCopy}）',
      );
      await tester.tap(restore);
      await _frames(tester);
      check(
        find
                .descendant(
                  of: find.byKey(const Key('homeTrashRestoreConfirmation')),
                  matching: find.text(l10n.homeRestoreFromTrashTitle),
                )
                .evaluate()
                .length ==
            1,
        'ゴミ箱から復元のダイアログの見出し',
      );
      await tester.tap(find.text(l10n.commonCancel).last);
      await _frames(tester);
      expect(problems, isEmpty, reason: '$language:\n${problems.join('\n')}');
      expect(tester.takeException(), isNull);
    });
  }

  // 320px・文字2倍で、ゴミ箱の種類のチップが切れず、フォルダのサムネイルの
  // 「デフォルト（最新の作品）」が単語の途中で折り返さない（スペイン語・
  // フランス語の長い訳で、チップの文字が途中で消え、「Predeterm|inada」
  // 「réc|emment」と折れていた）。
  for (final language in const ['es', 'fr']) {
    testWidgets('$language: 320px・文字2倍でもゴミ箱の種類と既定のサムネイルの文が切れない', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(localeFromLanguageCode(language));
      await loadAppFonts(tester);
      await _openHome(tester, language);
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _frames(tester);
      final projects = tester
          .element(find.byType(HomeScreen))
          .read<ProjectService>();
      await tester.runAsync(() => projects.createFolder('F'));
      await _settleIo(tester);

      final problems = <String>[];
      RenderParagraph paragraphOf(Finder text) =>
          tester.renderObject<RenderParagraph>(text);

      // フォルダのメニュー → サムネイル変更。
      await tester.tap(
        find
            .descendant(
              of: find.byType(ProjectListWidget),
              matching: find.byType(PopupMenuButton<String>),
            )
            .first,
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.tap(find.text(l10n.thumbnailChangeAction).last);
      await _frames(tester, 8);
      final label = l10n.thumbnailDefaultLatestWork;
      final paragraph = paragraphOf(find.text(label));
      // 1字ずつの箱の上端で行の変わり目を見つけ、その前後が単語の境目か見る。
      double? previousTop;
      for (var offset = 0; offset < label.length; offset++) {
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: offset, extentOffset: offset + 1),
        );
        if (boxes.isEmpty) continue;
        final top = boxes.first.top;
        if (previousTop != null && top > previousTop + 1) {
          final before = label[offset - 1];
          final after = label[offset];
          final atWordEdge =
              before.trim().isEmpty ||
              after.trim().isEmpty ||
              before == '-' ||
              after == '(';
          if (!atWordEdge) {
            problems.add('「$label」が「${label.substring(0, offset)}|」で折れる');
            break;
          }
        }
        previousTop = top;
      }
      await tester.tap(find.text(l10n.commonCancel).last);
      await _frames(tester, 8);

      await _showTab(tester, 3);
      for (final kind in const [
        'createdProject',
        'receivedShare',
        'createdShare',
        'exportedWork',
      ]) {
        final chip = paragraphOf(
          find.descendant(
            of: find.byKey(ValueKey('trashKind_$kind')),
            matching: find.byType(RichText),
          ),
        );
        final needed = chip.getMaxIntrinsicWidth(double.infinity);
        if (needed > chip.size.width + 0.5) {
          problems.add(
            'ゴミ箱の種類「${chip.text.toPlainText()}」が切れる'
            '（${needed.round()} > ${chip.size.width.round()}）',
          );
        }
      }
      expect(problems, isEmpty, reason: '$language:\n${problems.join('\n')}');
      expect(tester.takeException(), isNull);
    });
  }
}
