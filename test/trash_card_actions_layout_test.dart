import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';
import 'helpers/paragraph_lines.dart';

/// 所有者の判断1：ゴミ箱のカードの操作（コピー・復元・完全削除）は、カードの
/// 幅が600×文字の倍率以上なら名前の右・上下の真ん中、狭ければ名前の下の
/// 右端の行に置く。作品・フォルダ・書き出した作品のカードで同じ。
///
/// 広いカードでも、名前の右に並べると名前の欄が名前の文字15字分
/// （16px×文字の倍率×15）より狭くなるときは、名前の下に回す（600×倍率を
/// 少し超えた幅で、フランス語・スペイン語の名前の欄が71〜103pxになり、
/// 「clip_001.m | p4」のように名前が途中で折れた）。
///
/// 7言語×幅320・360・1280×文字の倍率1.0・2.0、600×倍率のすぐ上の幅で、
/// はみ出し・名前の省略・名前とボタンの語の途中の折り返しが無いことも見る。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_trash_card_layout_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    for (var attempt = 0; tempDir.existsSync(); attempt++) {
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        if (attempt == 19) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }
  });

  Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// ボタンの文字が、語の途中で折り返されていないか（空白の所でだけ
  /// 折り返してよい。日本語・中国語のボタンは1行に収まる）。
  String? midWordBreak(RenderParagraph paragraph, String label) {
    final lines = ParagraphLines(paragraph);
    final text = lines.visible;
    for (final at in lines.breaksWithin(0, text.length)) {
      if (text[at - 1].trim().isNotEmpty && text[at].trim().isNotEmpty) {
        return '$label breaks inside a word: ${lines.lines.join(' | ')}';
      }
    }
    return null;
  }

  /// 名前の欄に残す幅の下限（名前の文字16pxの15字分×文字の倍率）。
  double nameRoomFor(double scale) => 16 * 15 * scale;

  /// ゴミ箱に作品・中身ごと移したフォルダ・書き出した作品を1つずつ置き、
  /// ゴミ箱のタブを開く。カードの種類ごとのボタンのキーを返す。
  Future<({Map<String, List<Key>> cards, SettingsService settings})> seed(
    WidgetTester tester,
  ) async {
    await loadAppFonts(tester);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final splash = tester.element(find.byType(SplashScreen));
    final service = splash.read<ProjectService>();
    final settings = splash.read<SettingsService>();
    late final String workId;
    late final String folderId;
    late final String fileId;
    await tester.runAsync(() async {
      final work = await service.createProject(
        name: '海辺のスケッチ',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
      );
      workId = work.id;
      await service.deleteProject(work.id);
      final folder = await service.createFolder('旅行');
      folderId = folder.id;
      for (final name in ['海', '山']) {
        final project = await service.createProject(
          name: name,
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
        );
        await service.moveToFolder(project.id, folder.id);
      }
      await service.moveFolderToTrash(folder.id);
      final exported = File('${tempDir.path}/clip_001.mp4')
        ..writeAsBytesSync(List<int>.filled(64, 7));
      fileId = (await LocalFileTrashService.move(
        exported,
        LocalTrashKind.exportedWork,
      )).id;
    });
    await tester.tap(find.byIcon(Icons.brush_outlined));
    await settle(tester);
    final tab = find.byKey(const ValueKey('home_tab_3'));
    await tester.tap(tab);
    await settle(tester, rounds: 8);
    return (
      cards: <String, List<Key>>{
        'work': [
          ValueKey('trashCopyProject_$workId'),
          ValueKey('trash-restore-$workId'),
          ValueKey('trash-delete-$workId'),
        ],
        'folder': [
          ValueKey('trashCopyFolder_$folderId'),
          ValueKey('trashedFolderRestore_$folderId'),
          ValueKey('trashedFolderDelete_$folderId'),
        ],
        'file': [
          ValueKey('trashCopyLocal_$fileId'),
          ValueKey('trash-restore-local-$fileId'),
          ValueKey('trash-delete-local-$fileId'),
        ],
      },
      settings: settings,
    );
  }

  const titles = {'work': '海辺のスケッチ', 'folder': '旅行', 'file': 'clip_001.mp4'};

  /// いまの幅・文字の倍率で3種のカードを見て、決まりに合わない所を返す。
  Future<List<String>> checkCards(
    WidgetTester tester,
    Map<String, List<Key>> cards, {
    required String where,
    required double scale,
    required bool sameCorners,
  }) async {
    final problems = <String>[];
    final error = tester.takeException();
    if (error != null) problems.add('$where: $error');
    // カードの右下の角から見た「完全削除」の位置と、並べ方（種類で同じ）。
    final corners = <String, Offset>{};
    final beside = <String, bool>{};
    for (final MapEntry(key: kind, value: keys) in cards.entries) {
      final delete = find.byKey(keys.last, skipOffstage: false);
      await tester.scrollUntilVisible(
        delete,
        80,
        scrollable: find.byType(Scrollable).last,
      );
      await settle(tester, rounds: 1);
      final cardFinder = find
          .ancestor(of: delete, matching: find.byType(Card))
          .first;
      final card = tester.getRect(cardFinder);
      final title = find.descendant(
        of: cardFinder,
        matching: find.text(titles[kind]!),
      );
      final titleBox = tester.renderObject<RenderParagraph>(title);
      if (titleBox.didExceedMaxLines) {
        problems.add('$where $kind: the name is cut');
      }
      // 名前は1語（ファイル名）か短い名前なので、1行に収まる。
      final titleLines = ParagraphLines(titleBox).lines;
      if (titleLines.length > 1) {
        problems.add(
          '$where $kind: the name breaks: ${titleLines.join(' | ')}',
        );
      }
      // 名前の欄（ListTileが名前に渡した幅）。
      final nameRoom = titleBox.constraints.maxWidth;
      final titleRect = tester.getRect(title);
      final buttons = [for (final key in keys) tester.getRect(find.byKey(key))];
      for (final key in keys) {
        final label = find.descendant(
          of: find.byKey(key),
          matching: find.byType(RichText),
        );
        for (final element in label.evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          final broken = midWordBreak(paragraph, '$where $kind $key');
          if (broken != null) problems.add(broken);
        }
      }
      corners[kind] = card.bottomRight - buttons.last.bottomRight;
      final isBeside = buttons.every((b) => b.left >= titleRect.right);
      beside[kind] = isBeside;
      final wide = card.width >= 600 * scale;
      if (isBeside) {
        if (!wide) {
          problems.add('$where $kind: beside the name on a narrow card');
        }
        for (final button in buttons) {
          if ((button.center.dy - card.center.dy).abs() > 1) {
            problems.add(
              '$where $kind: buttons not centred '
              '(${button.center.dy} vs ${card.center.dy})',
            );
          }
        }
        if (nameRoom < nameRoomFor(scale) - 0.5) {
          problems.add(
            '$where $kind: beside the buttons the name gets only '
            '${nameRoom.toStringAsFixed(0)}px',
          );
        }
      } else {
        for (final button in buttons) {
          if (button.top < titleRect.bottom) {
            problems.add(
              '$where $kind: a button is neither beside nor under '
              'the name',
            );
          }
        }
        if (card.right - buttons.last.right > 24) {
          problems.add('$where $kind: buttons are not at the right edge');
        }
        // 広いカードで下に回すのは、右に並べると名前の欄が狭すぎるときだけ。
        // 先頭の絵が一番大きい作品のカードで見る（ほかのカードも同じ並べ方
        // にそろえるので、絵の小さいカードは少し余る）。
        final row = buttons.last.right - buttons.first.left;
        final sameRow = buttons.every(
          (b) => (b.center.dy - buttons.first.center.dy).abs() < 1,
        );
        if (kind == 'work' &&
            wide &&
            sameRow &&
            nameRoom - row - 8 >= nameRoomFor(scale)) {
          problems.add(
            '$where $kind: under the name although the name would get '
            '${(nameRoom - row - 8).toStringAsFixed(0)}px beside them',
          );
        }
      }
      if (!card.contains(buttons.first.topLeft) ||
          buttons.last.right > card.right + 0.5 ||
          buttons.last.bottom > card.bottom + 0.5) {
        problems.add('$where $kind: a button is outside its card');
      }
    }
    // 作品・フォルダ・ファイルのカードで、ボタンは同じ所・同じ並べ方。
    if (beside.values.toSet().length > 1) {
      problems.add('$where: the cards are not laid out alike: $beside');
    }
    if (sameCorners) {
      final work = corners['work']!;
      for (final kind in ['folder', 'file']) {
        if ((corners[kind]!.dx - work.dx).abs() > 0.5) {
          problems.add('$where $kind: buttons not where the work has them');
        }
      }
    }
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 4000));
    await settle(tester, rounds: 1);
    return problems;
  }

  testWidgets('trash card actions sit right of the name on wide cards and '
      'under it on narrow cards, for works, folders and exported works', (
    tester,
  ) async {
    final (:cards, :settings) = await seed(tester);
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final code = locale.toLanguageTag().replaceAll('-', '_');
      await tester.runAsync(() => settings.setLanguage(code));
      for (final size in const [
        Size(320, 700),
        Size(360, 800),
        Size(1280, 800),
      ]) {
        for (final scale in const [1.0, 2.0]) {
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await settle(tester);
          problems.addAll(
            await checkCards(
              tester,
              cards,
              where: '$code ${size.width.toInt()} x$scale',
              scale: scale,
              sameCorners: scale == 1.0 || size.width == 1280,
            ),
          );
        }
      }
      // 1280px・文字1.0では、どの言語でも名前の右に並ぶ。
      tester.view.physicalSize = const Size(1280, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 1.0;
      await settle(tester);
      final delete = find.byKey(cards['work']!.last, skipOffstage: false);
      await tester.scrollUntilVisible(
        delete,
        80,
        scrollable: find.byType(Scrollable).last,
      );
      final title = find.text(titles['work']!);
      if (tester.getRect(delete).left < tester.getRect(title).right) {
        problems.add('$code 1280 x1.0: the buttons are not beside the name');
      }
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 4000));
      await settle(tester, rounds: 1);
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('just above 600 × text scale, the actions go under the name '
      'until the name keeps 15 characters beside them', (tester) async {
    final (:cards, :settings) = await seed(tester);
    final problems = <String>[];
    for (final locale in AppLocalizations.supportedLocales) {
      final code = locale.toLanguageTag().replaceAll('-', '_');
      await tester.runAsync(() => settings.setLanguage(code));
      for (final scale in const [1.0, 1.3, 1.5, 2.0]) {
        for (final extra in const [16, 36, 76, 136, 216, 336]) {
          final width = (600 * scale + extra).roundToDouble();
          tester.view.physicalSize = Size(width, 800);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await settle(tester);
          problems.addAll(
            await checkCards(
              tester,
              cards,
              where: '$code ${width.toInt()} x$scale',
              scale: scale,
              sameCorners: true,
            ),
          );
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
