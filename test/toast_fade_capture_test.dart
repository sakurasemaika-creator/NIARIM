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
import 'package:niarim/screens/home/widgets/project_list_widget.dart';
import 'package:niarim/screens/splash/splash_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// ホームの「切り取り」の知らせ（「元に戻す」付き）が時間で消えていく様子を、
/// 既定のライト・ダークのテーマで6コマずつPNGへ焼く（目で確かめるため）。
///
/// 出力先は`build/toast-fade/`（環境変数`NIARIM_TOAST_FRAMES_DIR`で変えられる）。
/// 1コマ目は出切っている間（不透明度1）、残りは時間が来て薄くなっていく途中。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('ja'));
  const frame = Duration(milliseconds: 16);
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  /// 出ている知らせの面の不透明度（祖先のFadeTransition・Opacityの積）。
  double? toastOpacity() {
    double? best;
    final surfaces = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(Material),
    );
    for (final element in surfaces.evaluate()) {
      var opacity = 1.0;
      element.visitAncestorElements((ancestor) {
        final widget = ancestor.widget;
        if (widget is FadeTransition) opacity *= widget.opacity.value;
        if (widget is Opacity) opacity *= widget.opacity;
        return true;
      });
      if (best == null || opacity > best) best = opacity;
    }
    return best;
  }

  for (final themeId in ['default_light', 'default_dark']) {
    testWidgets('the cut notice fades out on Home ($themeId, 390x844)', (
      tester,
    ) async {
      final temp = Directory.systemTemp.createTempSync('niarim_toast_fade_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (_) async => temp.path);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathChannel, null);
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });
      final output = Directory(
        Platform.environment['NIARIM_TOAST_FRAMES_DIR'] ?? 'build/toast-fade',
      )..createSync(recursive: true);

      await loadAppFonts(tester);
      debugDisableShadows = false;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
        'first_launch': false,
        'language': 'ja',
        'home_view_mode': 'medium',
      });
      appRouter.go('/');
      final boundary = GlobalKey();
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MultiProvider(providers: providers, child: const NiarimApp()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final splash = tester.element(find.byType(SplashScreen));
      splash.read<ThemeService>().applyPreset(themeId);
      final service = splash.read<ProjectService>();
      await tester.runAsync(
        () => service.createProject(
          name: 'サンプルアニメーション',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
        ),
      );
      await tester.tap(find.byIcon(Icons.brush_outlined));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      final card = find.descendant(
        of: find.byType(ProjectListWidget),
        matching: find.text('サンプルアニメーション'),
      );
      await tester.longPress(card);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.tap(find.byTooltip(l10n.commonCut));
      // 知らせが出切るまで。
      var elapsed = Duration.zero;
      while (toastOpacity() != 1.0) {
        await tester.pump(frame);
        elapsed += frame;
        expect(elapsed, lessThan(const Duration(seconds: 2)));
      }
      // 出切ってしばらく後（読んでいる間）。
      await tester.pump(const Duration(seconds: 1));
      expect(toastOpacity(), 1.0);

      final shots = <String>[];
      Future<void> shot(int index) async {
        final opacity = toastOpacity() ?? 0.0;
        final name =
            '$themeId-$index-opacity-${(opacity * 100).round().toString().padLeft(3, '0')}.png';
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await render.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data!.buffer.asUint8List();
        });
        await tester.runAsync(
          () => File('${output.path}/$name').writeAsBytes(bytes!),
        );
        shots.add('$name (${opacity.toStringAsFixed(2)})');
      }

      // 1コマ目：出切っている間。
      await shot(1);
      while (toastOpacity() == 1.0) {
        await tester.pump(frame);
        elapsed += frame;
        expect(elapsed, lessThan(const Duration(seconds: 5)));
      }
      // 薄くなり始めてから5・10・15・20・24フレーム目（約0.8・0.6・0.4・
      // 0.2・0.04）。
      const capturedAt = [5, 10, 15, 20, 24];
      final opacities = <double>[];
      for (var fadeFrame = 1; fadeFrame <= 24; fadeFrame++) {
        opacities.add(toastOpacity() ?? 0.0);
        if (capturedAt.contains(fadeFrame)) {
          await shot(capturedAt.indexOf(fadeFrame) + 2);
        }
        if (fadeFrame < 24) await tester.pump(frame);
      }
      debugPrint('$themeId: ${shots.join(', ')}');
      expect(shots, hasLength(6));
      for (var i = 1; i < opacities.length; i++) {
        expect(opacities[i], lessThanOrEqualTo(opacities[i - 1]));
      }
      expect(opacities.first, greaterThan(0.9));
      expect(opacities.last, lessThan(0.1));
      for (var i = 0; i < 8; i++) {
        await tester.pump(frame);
      }
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      debugDisableShadows = true;
    });
  }
}
