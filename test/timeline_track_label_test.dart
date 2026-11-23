import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// タイムラインのトラック名（「フレーム」等）が省略されずに出ることを
/// 実画面で検証する。
///
/// ラベル欄は固定幅で、アイコンと余白を引いた残りに文字を入れている。
/// 幅が足りないと「フレ…」のように切れるが、テストは全て緑のままなので
/// 実キャプチャ（`build/all-route-screenshots/05_timeline.png`）を
/// 見るまで気付けなかった。7言語ぶんの文字幅が変わったときにも
/// 気付けるよう、**描画されたテキストの実寸**で判定する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('タイムラインのトラック名が省略されずに収まる', (tester) async {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final tempDir = Directory.systemTemp.createTempSync('niarim_track_label_');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> settle({int rounds = 5}) async {
      for (var i = 0; i < rounds; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }
    }

    await loadAppFonts(tester);
    appRouter.go('/');
    final captureKey = GlobalKey();
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MultiProvider(providers: providers!, child: const NiarimApp()),
      ),
    );
    await settle();

    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();
    final project = (await tester.runAsync(
      () => ps.createProject(
        name: 'track-label',
        fps: 12,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: 320,
        exportHeight: 180,
      ),
    ))!;
    appRouter.go('/timeline/${project.id}');
    await settle();
    expect(tester.takeException(), isNull);

    final settings = tester
        .element(find.byType(MaterialApp).first)
        .read<SettingsService>();
    const locales = [
      Locale('ja'),
      Locale('en'),
      Locale('zh'),
      Locale('ko'),
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      Locale('fr'),
      Locale('es'),
    ];
    const logicalWidths = [320.0, 360.0, 412.0];
    final captures = Directory('build/timeline-preview-ui-captures')
      ..createSync(recursive: true);

    for (final locale in locales) {
      final languageCode = locale.scriptCode == 'Hant'
          ? 'zh_Hant'
          : locale.languageCode;
      await settings.setLanguage(languageCode);
      await settle();
      final l10n = await AppLocalizations.delegate.load(locale);

      for (final logicalWidth in logicalWidths) {
        tester.view.physicalSize = Size(logicalWidth * 3, 2280);
        await settle();
        expect(
          tester.takeException(),
          isNull,
          reason:
              'Timeline layout threw for $languageCode at '
              '${logicalWidth.toInt()}dp',
        );

        final finder = find.text(l10n.timelineFrameTrackLabel);
        expect(
          finder,
          findsOneWidget,
          reason:
              '$languageCode ${logicalWidth.toInt()}dp: '
              'frame track label not found',
        );
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        expect(
          tester.widget<Text>(finder).style?.fontSize,
          11,
          reason: 'Track labels must remain comfortably readable on phones',
        );
        expect(
          paragraph.size.height,
          lessThan(20),
          reason:
              '$languageCode ${logicalWidth.toInt()}dp: track label wrapped',
        );
        final intrinsic = paragraph.getMaxIntrinsicWidth(double.infinity);
        expect(
          paragraph.size.width,
          greaterThanOrEqualTo(intrinsic - 0.5),
          reason:
              '$languageCode ${logicalWidth.toInt()}dp: '
              '"${l10n.timelineFrameTrackLabel}" is clipped '
              '(${paragraph.size.width.toStringAsFixed(1)}px / '
              '${intrinsic.toStringAsFixed(1)}px)',
        );

        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(captureKey),
        );
        // toImage and PNG encoding are real async work; under the fake clock
        // they never finish unless awaited inside runAsync.
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${captures.path}/timeline_track_labels_${languageCode}_'
            '${logicalWidth.toInt()}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
