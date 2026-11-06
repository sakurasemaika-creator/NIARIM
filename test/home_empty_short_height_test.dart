import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:niarim/widgets/empty_state_placeholder.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// ホームの3つのタブの空の表示は、低い画面（横向き・分割画面）と大きな文字
/// でもはみ出さず、題・説明・ボタンのどれもスクロールで画面に出せること。
/// 以前は固定の高さの並びで、640×220で89px、640×360・文字2倍で16px
/// はみ出していた。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;
  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_home_short_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('empty Home tabs fit short screens and large text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
    });
    await loadAppFonts(tester);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 360);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final providers = (await tester.runAsync(buildAppProviders))!;
    await tester.pumpWidget(
      MultiProvider(providers: providers, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final settings = tester
        .element(find.byType(Scaffold).first)
        .read<SettingsService>();
    appRouter.go('/home');
    await tester.pump(const Duration(seconds: 1));
    // 作品一覧の読み込み（実際のファイルの読み書き）を待つ。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final failures = <String>[];
    for (final language in const [
      'ja',
      'en',
      'es',
      'fr',
      'ko',
      'zh',
      'zh_Hant',
    ]) {
      await tester.runAsync(() => settings.setLanguage(language));
      for (final scale in const [1.0, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (final size in const [
          Size(640, 220),
          Size(640, 360),
          Size(320, 480),
        ]) {
          tester.view.physicalSize = size;
          for (final tab in const [0, 1, 2]) {
            final where =
                '$language x$scale ${size.width.round()}x${size.height.round()} tab$tab';
            tester
                .widget<TabBarView>(find.byType(TabBarView))
                .controller!
                .animateTo(tab);
            for (var i = 0; i < 4; i++) {
              await tester.pump(const Duration(milliseconds: 150));
            }
            final error = tester.takeException();
            if (error != null) {
              failures.add('$where: $error');
              continue;
            }
            final empty = find.byType(EmptyStatePlaceholder);
            if (empty.evaluate().isEmpty) continue;
            // 空の表示の中の文字・ボタンを1つずつ画面へ出せること。
            final parts = find.descendant(
              of: empty.first,
              matching: find.byWidgetPredicate(
                (w) => w is Text || w is ButtonStyleButton,
              ),
            );
            for (var i = 0; i < parts.evaluate().length; i++) {
              final part = parts.at(i);
              await tester.ensureVisible(part);
              await tester.pump();
              final rect = tester.getRect(part);
              final view = tester.getRect(
                find
                    .ancestor(of: part, matching: find.byType(Scrollable))
                    .first,
              );
              if (rect.top < view.top - 0.5 ||
                  rect.bottom > view.bottom + 0.5) {
                failures.add('$where: part $i not reachable $rect in $view');
              }
            }
          }
        }
      }
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
