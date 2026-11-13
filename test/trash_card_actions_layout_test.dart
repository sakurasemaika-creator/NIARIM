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
/// 7言語×幅320・360・1280×文字の倍率1.0・2.0で、はみ出し・名前の省略・
/// ボタンの語の途中の折り返しが無いことも見る。
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

  testWidgets('trash card actions sit right of the name on wide cards and '
      'under it on narrow cards, for works, folders and exported works', (
    tester,
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

    final cards = <String, List<Key>>{
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
    };
    final titles = {'work': '海辺のスケッチ', 'folder': '旅行', 'file': 'clip_001.mp4'};

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
          final where = '$code ${size.width.toInt()} x$scale';
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await settle(tester);
          final error = tester.takeException();
          if (error != null) problems.add('$where: $error');
          // カードの右下の角から見た「完全削除」の位置（種類で同じ）。
          final corners = <String, Offset>{};
          for (final MapEntry(key: kind, value: keys) in cards.entries) {
            final delete = find.byKey(keys.last, skipOffstage: false);
            await tester.scrollUntilVisible(
              delete,
              80,
              scrollable: find.byType(Scrollable).last,
            );
            await settle(tester, rounds: 1);
            final card = tester.getRect(
              find.ancestor(of: delete, matching: find.byType(Card)).first,
            );
            final title = find.descendant(
              of: find.ancestor(of: delete, matching: find.byType(Card)).first,
              matching: find.text(titles[kind]!),
            );
            final titleBox = tester.renderObject<RenderParagraph>(title);
            if (titleBox.didExceedMaxLines) {
              problems.add('$where $kind: the name is cut');
            }
            final titleRect = tester.getRect(title);
            final buttons = [
              for (final key in keys) tester.getRect(find.byKey(key)),
            ];
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
            final wide = card.width >= 600 * scale;
            if (wide) {
              for (final button in buttons) {
                if (button.left < titleRect.right) {
                  problems.add(
                    '$where $kind: a button is not right of the name',
                  );
                }
                if ((button.center.dy - card.center.dy).abs() > 1) {
                  problems.add(
                    '$where $kind: buttons not centred '
                    '(${button.center.dy} vs ${card.center.dy})',
                  );
                }
              }
            } else {
              for (final button in buttons) {
                if (button.top < titleRect.bottom) {
                  problems.add('$where $kind: a button is not under the name');
                }
              }
              if (card.right - buttons.last.right > 24) {
                problems.add('$where $kind: buttons are not at the right edge');
              }
            }
            if (!card.contains(buttons.first.topLeft) ||
                buttons.last.right > card.right + 0.5 ||
                buttons.last.bottom > card.bottom + 0.5) {
              problems.add('$where $kind: a button is outside its card');
            }
          }
          // 作品・フォルダ・ファイルのカードで、ボタンは同じ所に並ぶ。
          if (scale == 1.0 || size.width == 1280) {
            final work = corners['work']!;
            for (final kind in ['folder', 'file']) {
              if ((corners[kind]!.dx - work.dx).abs() > 0.5) {
                problems.add(
                  '$where $kind: buttons not where the work has them',
                );
              }
            }
          }
          await tester.drag(
            find.byType(Scrollable).last,
            const Offset(0, 4000),
          );
          await settle(tester, rounds: 1);
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
