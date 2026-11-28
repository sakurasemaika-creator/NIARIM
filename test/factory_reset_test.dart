// 全データの削除（出荷時の状態に戻す）：消した後のアプリは、入れたばかりの
// アプリと同じ保存（設定のキー・ファイル）だけを持ち、初回の案内がまた出る。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_runner.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/services/brush_service.dart';
import 'package:niarim/services/layer_clipboard_service.dart';
import 'package:niarim/services/local_file_trash_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/services/share_intent_service.dart';
import 'package:niarim/services/storage_info_service.dart';
import 'package:niarim/utils/saved_list_reader.dart';
import 'package:niarim/widgets/app_tutorial.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  late Directory root;
  late Directory docs;
  late Directory support;
  late Directory cache;
  late Directory temp;

  setUp(() {
    root = Directory.systemTemp.createTempSync('factory-reset-');
    Directory folder(String name) =>
        Directory('${root.path}/$name')..createSync(recursive: true);
    docs = folder('docs');
    support = folder('support');
    cache = folder('cache');
    temp = folder('temp');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _pathChannel,
          (call) async => switch (call.method) {
            'getApplicationSupportDirectory' => support.path,
            'getApplicationCacheDirectory' => cache.path,
            'getTemporaryDirectory' => temp.path,
            _ => docs.path,
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathChannel, null);
    AppRunner.current = null;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (root.existsSync()) root.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        continue;
      }
    }
  });

  /// 書類・アプリの領域・キャッシュにあるファイル（根からの相対の道）。
  /// 一時フォルダは数えない（OSのもので、入れ直しでも残る）。
  Set<String> files() => {
    for (final dir in [docs, support, cache])
      for (final entity in dir.listSync(recursive: true))
        if (entity is File) entity.path.substring(root.path.length),
  };

  Future<Set<String>> keys() async =>
      (await SharedPreferences.getInstance()).getKeys();

  Future<Map<String, Object?>> saved() async {
    final prefs = await SharedPreferences.getInstance();
    return {for (final key in prefs.getKeys()) key: prefs.get(key)};
  }

  testWidgets('erasing everything keeps only what a fresh install has, and '
      'the first-launch guide comes back', (tester) async {
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget? shown;
    final runner = AppRunner(
      show: (app) => shown = app,
      // 画面は載せていないので、差し替えを待つものは無い。
      waitForFrame: () async {},
    );

    // 1. 入れたばかりのアプリが起動して書くもの。
    SharedPreferences.setMockInitialValues({});
    appRouter.go('/');
    await tester.runAsync(() async {
      await runner.start();
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    final freshKeys = await keys();
    final freshValues = await saved();
    final freshFiles = files();
    await tester.runAsync(runner.stopServices);
    for (final dir in [docs, support, cache]) {
      for (final entity in dir.listSync()) {
        entity.deleteSync(recursive: true);
      }
    }

    // 2. 使い込んだアプリ：設定・作品・書き出し・自作の素材・控え。
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'fr',
      'force_pc_mode': 0,
      'user_written_key_that_no_version_knows': 'x',
    });
    appRouter.go('/home');
    await tester.runAsync(runner.start);
    await tester.pumpWidget(shown!);
    await tester.pump();
    final context = tester.element(find.byType(HomeScreen));
    final projects = context.read<ProjectService>();
    final brushes = context.read<BrushService>();
    await tester.runAsync(() async {
      final project = await projects.createProject(
        name: 'œuvre',
        fps: 2,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 64,
        exportHeight: 36,
      );
      await projects.saveProject(project.id);
      brushes.updateCurrentBrushSize(17);
      await brushes.commitRememberedValues();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    final written = <File>[
      File('${docs.path}/niarim/exports/niarim_1.mp4'),
      File('${docs.path}/niarim/Fonts/mine.ttf'),
      File('${docs.path}/niarim/watermarks/sign.png'),
      File('${docs.path}/niarim/trash/files/1/meta.json'),
      File('${docs.path}/niarim/shared/outgoing/a.niashare'),
      File('${docs.path}/my brush.niabrush'),
      File('${docs.path}/palette.niapalette'),
      File('${docs.path}/desk.niaworkspace'),
      File('${support.path}/exported_covers/c.png'),
      File('${support.path}/folder_thumbnails/f.jpg'),
      File('${support.path}/post_thumbnails/p.jpg'),
      File('${cache.path}/thumb.bin'),
      // A copy of a file opened from another app, left while it was read.
      File('${cache.path}/${ShareIntentService.intakeFolderName}/1-0.niashare'),
    ];
    for (final file in written) {
      file
        ..createSync(recursive: true)
        ..writeAsStringSync('data');
    }
    // 以前の版の共有の書き出しは消さない（ほかのアプリと共有の場所がある）。
    final legacy = File('${docs.path}/exports/old work.mp4')
      ..createSync(recursive: true)
      ..writeAsStringSync('keep');
    // ほかのアプリの書類（NIARIMの形式でない）も消さない。
    final foreign = File('${docs.path}/letter.txt')..writeAsStringSync('keep');
    SavedListCarryOver.remember('brushes', ['{"broken": true}']);
    final usedKeys = await keys();
    expect(usedKeys, contains('user_written_key_that_no_version_knows'));
    expect(
      files().where((path) => path.contains('/niarim/projects/')),
      isNotEmpty,
    );

    // 3. 全データを削除する（画面を外してから止め、消して起動し直す）。
    await tester.pumpWidget(const SizedBox.shrink());
    var erased = 0;
    await tester.runAsync(() async {
      await runner.resetToFactory(
        languageCode: 'fr',
        erase: () {
          erased++;
          return StorageInfoService().eraseAllData();
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    expect(erased, 1);

    // 入れたばかりのときと同じキー・値・ファイルだけ。
    expect(await keys(), freshKeys);
    expect(await saved(), freshValues);
    expect(files(), {
      ...freshFiles,
      legacy.path.substring(root.path.length),
      foreign.path.substring(root.path.length),
    });
    expect(legacy.readAsStringSync(), 'keep');
    expect(SavedListCarryOver.total, 0);
    expect(LayerClipboardService.instance.hasLayer, isFalse);
    expect(LocalFileTrashService.hasItems, isFalse);

    // 起動し直したアプリは起動画面から始まり、ホームで初回の案内が出る。
    await tester.pumpWidget(shown!);
    await tester.pump();
    expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/');
    final restarted = tester.element(find.byType(NiarimApp));
    expect(restarted.read<SettingsService>().isFirstLaunch, isTrue);
    expect(restarted.read<ProjectService>().projects, isEmpty);
    appRouter.go('/home');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(AppTutorial), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(runner.stopServices);
  });
}
