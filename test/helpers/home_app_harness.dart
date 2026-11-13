import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/router.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'first_use_tooltips.dart';

/// 本物のアプリ（[NiarimApp]）でホームを開く。
///
/// 保存先は一時フォルダ。[seed]で作品・フォルダを作ってから一覧を描き直す。
/// 作る順に更新日時が新しくなるよう、1件ごとに少し待つ。
class HomeAppHarness {
  HomeAppHarness._(this.tester, this.dir);

  final WidgetTester tester;
  final Directory dir;
  static const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  /// 起動時の設定（言語・表示サイズ等）を決めてから[open]する。
  static HomeAppHarness prepare(
    WidgetTester tester, {
    String language = 'ja',
    Map<String, Object> preferences = const {},
  }) {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': language,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      ...preferences,
    });
    final dir = Directory.systemTemp.createTempSync('niarim-home-harness-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_pathChannel, (_) async => dir.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(_pathChannel, null);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    return HomeAppHarness._(tester, dir);
  }

  /// 画面の大きさ・文字の倍率を変える（ホームを開いたままでもよい）。
  Future<void> resize(Size size, {double textScale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await settle();
  }

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  late ProjectService service;

  /// ホームを開き、[seed]で作品・フォルダを作る。
  Future<ProjectService> open({
    Size size = const Size(390, 844),
    double textScale = 1,
    Future<void> Function(ProjectService service)? seed,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    appRouter.go('/home');
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await settle();
    service = tester.element(find.byType(HomeScreen)).read<ProjectService>();
    if (seed != null) {
      await tester.runAsync(() => seed(service));
      await settle();
    }
    return service;
  }

  /// 作品を作る（作るたびに少し待ち、更新日時が作った順に新しくなる）。
  static Future<Project> work(
    ProjectService service,
    String name, {
    String? folderId,
  }) async {
    final project = await service.createProject(
      name: name,
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      exportWidth: 32,
      exportHeight: 18,
    );
    if (folderId != null) await service.moveToFolder(project.id, folderId);
    await Future<void>.delayed(const Duration(milliseconds: 3));
    return service.projects.firstWhere((p) => p.id == project.id);
  }

  /// ホームの「プロジェクト」タブの一覧の中だけを探す。
  static Finder inProjects(Finder finder) =>
      find.descendant(of: find.byType(ProjectListWidget), matching: finder);

  /// 一覧のカード・行の名前（上の行から、行の中は左から）。名前は
  /// 見出しの書体の字で、読み上げの名前（[Text.semanticsLabel]）があれば
  /// それを使う（カードは長い名前を短くして出す）。
  List<String> shownNames() {
    final items = inProjects(
      find.byWidgetPredicate((w) => w is Card || w is ListTile),
    );
    final names = <(Offset, String)>[];
    for (final element
        in find
            .descendant(of: items, matching: find.byType(Text))
            .evaluate()
            .toSet()) {
      final text = element.widget as Text;
      final name = text.semanticsLabel ?? text.data;
      if (name == null) continue;
      if (text.style?.fontFamily != 'Kuramubon') continue;
      final box = element.renderObject! as RenderBox;
      names.add((box.localToGlobal(Offset.zero), name));
    }
    names.sort((a, b) {
      final dy = a.$1.dy - b.$1.dy;
      if (dy.abs() > 8) return dy.sign.toInt();
      return a.$1.dx.compareTo(b.$1.dx);
    });
    return [for (final n in names) n.$2];
  }

  Future<void> close() => tester.pumpWidget(const SizedBox.shrink());
}
