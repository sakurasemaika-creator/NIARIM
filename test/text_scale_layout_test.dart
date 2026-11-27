// OSの文字サイズ設定（Androidの「フォントサイズ」「表示サイズ」）を
// 大きくした状態でも、主要画面がRenderFlexオーバーフローやレイアウト
// 例外を起こさないことを確認するリグレッションテスト。
//
// 【経緯】ユーザーから「プロジェクト一覧画面の昇順降順切り替えボタンで
// flowed byのようなエラーが表示される」という報告があったが、既定の
// 文字サイズ（1.0倍）では再現しなかった。textScalerを1.3倍以上にすると
// 起動画面・ホーム画面・プロジェクト詳細・引き継ぎ設定・タイムライン・
// ショートカット設定の6箇所で再現することが判明したため、修正とあわせて
// このテストを追加している。文字サイズは端末側の設定であり、開発端末が
// 既定値のままだと気付けないため、自動テストで恒久的に監視する。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/cut_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('niarim_text_scale');
    addTearDown(() => dir.deleteSync(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
  });

  /// [scale]倍の文字サイズで主要画面を巡回し、レイアウト例外が出た画面と
  /// 内容を文字列として返す（空なら問題なし）。
  Future<List<String>> visitScreens(WidgetTester tester, double scale) async {
    final problems = <String>[];
    var route = '起動';
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final s = details.toString();
      final where = RegExp(
        r'file:///[^\s:]*/(lib/[^\s:]+:\d+:\d+)',
      ).firstMatch(s);
      final what =
          RegExp(
            r'(overflowed by [\d.]+ pixels on the \w+)',
          ).firstMatch(s)?.group(1) ??
          s
              .split('\n')
              .firstWhere((l) => l.contains('thrown'), orElse: () => 'レイアウト例外');
      problems.add('$route ${where?.group(1) ?? "場所不明"}: $what');
    };
    try {
      // 一般的なスマホ相当（360×760dp）。狭い端末ほど文字拡大の影響が出る。
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final providers = await tester.runAsync(buildAppProviders);
      await tester.pumpWidget(
        MultiProvider(providers: providers!, child: const NiarimApp()),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final createButton = find.byIcon(Icons.brush_outlined);
      if (createButton.evaluate().isNotEmpty) {
        await tester.tap(createButton);
        await tester.pump(const Duration(milliseconds: 400));
        final start = find.byKey(const Key('tutorialSkip'));
        if (start.evaluate().isNotEmpty) {
          await tester.tap(start);
          await tester.pump(const Duration(milliseconds: 400));
        }
      }

      // id付きルートも巡回できるようプロジェクトを1件用意する。
      final ctx = tester.element(find.byType(Navigator).first);
      final projectService = ctx.read<ProjectService>();
      await tester.runAsync(
        () => projectService.createProject(
          name: 'text-scale',
          fps: 24,
          durationSeconds: 5,
          backgroundColor: 0xFFFFFFFF,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final projectId = projectService.projects.first.id;

      for (final path in <String>[
        '/',
        '/home',
        '/shared',
        '/trash',
        '/community',
        '/new-project',
        '/project/$projectId',
        '/canvas/$projectId',
        '/timeline/$projectId',
        '/export/$projectId',
        '/save-tree/$projectId',
        '/materials/$projectId',
        '/settings',
        '/settings/gestures',
        '/settings/shortcuts',
        '/settings/performance',
        '/settings/pen',
        '/settings/bucket',
        '/settings/workspace',
        '/settings/transfer',
        '/settings/theme',
        '/settings/watermark',
        '/settings/fonts',
        '/settings/license',
        '/settings/privacy-policy',
        '/settings/error-log',
        '/help',
        '/tips',
        '/premium',
        '/autofill-presets',
        '/storage',
      ]) {
        route = path;
        appRouter.go(route);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        // 大きな文字でも、ボタン・チップの上下（や左右）が切る欄に一部だけ
        // 切られていない（所有者の依頼、2026-11-27）。
        for (final cut in cutControls(tester)) {
          problems.add('$route 切れたボタン: $cut');
        }
        if (route == '/project/$projectId') {
          final fullscreen = find.byKey(
            const Key('projectDetailFullscreenButton'),
          );
          if (fullscreen.hitTestable().evaluate().length != 1) {
            problems.add('$route 全画面再生を開けません');
            continue;
          }
          await tester.tap(fullscreen);
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const Key('projectDetailFullscreenImage')),
          );
          await tester.pumpAndSettle();
          for (final size in [
            const Size(1080, 660),
            const Size(960, 660),
            const Size(960, 480),
            const Size(1080, 2280),
          ]) {
            tester.view.physicalSize = size;
            await tester.pumpAndSettle();
            final image = find.byKey(const Key('projectDetailFullscreenImage'));
            final height = image.evaluate().length == 1
                ? tester.getSize(image).height
                : 0.0;
            if (height < 64) {
              problems.add('$route $size 全画面の画像の高さ: $height');
            }
            for (final key in [
              'projectDetailFullscreenLoopButton',
              'projectDetailFullscreenTransport',
            ]) {
              final control = find.byKey(Key(key));
              if (control.evaluate().length == 1) {
                await tester.ensureVisible(control);
                await tester.pumpAndSettle();
              }
              if (control.hitTestable().evaluate().length != 1) {
                problems.add('$route $size $key を操作できません');
              }
            }
          }
          final exit = find.byKey(const Key('projectDetailFullscreenExit'));
          if (exit.hitTestable().evaluate().length == 1) {
            await tester.tap(exit);
            await tester.pumpAndSettle();
          }
          if (find
              .byKey(const Key('projectDetailFullscreenImage'))
              .evaluate()
              .isNotEmpty) {
            problems.add('$route 全画面再生を閉じられません');
          }
        }
      }
      // 後続テストへ影響しないようホームへ戻す。
      appRouter.go('/home');
      await tester.pump(const Duration(milliseconds: 300));
    } finally {
      FlutterError.onError = original;
    }
    return problems;
  }

  testWidgets('文字サイズ1.3倍でも全画面がレイアウト例外を起こさない', (WidgetTester tester) async {
    final problems = await visitScreens(tester, 1.3);
    expect(
      problems,
      isEmpty,
      reason: '文字サイズ1.3倍で以下の問題:\n${problems.join("\n")}',
    );
  }, timeout: const Timeout(Duration(seconds: 90)));

  testWidgets('文字サイズ2.0倍でも全画面がレイアウト例外を起こさない', (WidgetTester tester) async {
    final problems = await visitScreens(tester, 2.0);
    expect(
      problems,
      isEmpty,
      reason: '文字サイズ2.0倍で以下の問題:\n${problems.join("\n")}',
    );
  }, timeout: const Timeout(Duration(seconds: 90)));
}
