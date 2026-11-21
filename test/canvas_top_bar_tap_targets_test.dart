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
import 'package:niarim/screens/canvas/canvas_screen.dart';
import 'package:niarim/screens/canvas/widgets/canvas_icon_button.dart';
import 'package:niarim/screens/home/home_screen.dart';
import 'package:niarim/screens/timeline/timeline_screen.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/load_app_fonts.dart';

/// The canvas's top bar (undo, redo, settings, home, timeline) on a phone:
/// each button is a 48x48 target with room between neighbours, so a thumb
/// hits the one it means (owner's request: bigger icons, wider spacing).
/// The arrow after the timeline symbol opens the timeline too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('niarim_canvas_top_bar_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => tempDir.path);
    appRouter.go('/home');
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
      'first_launch': false,
      'language': 'ja',
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> settleIo(WidgetTester tester, [int rounds = 8]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final width in const [390.0, 320.0]) {
    testWidgets('top bar buttons are 48px targets with gaps at ${width}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await loadAppFonts(tester);
      final boundary = GlobalKey();
      final providers = (await tester.runAsync(buildAppProviders))!;
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: RepaintBoundary(key: boundary, child: const NiarimApp()),
        ),
      );
      await settleIo(tester, 4);
      final service = tester
          .element(find.byType(HomeScreen))
          .read<ProjectService>();
      late String id;
      await tester.runAsync(() async {
        id = (await service.createProject(
          name: 'キャンバス',
          fps: 2,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 64,
          exportHeight: 36,
        )).id;
      });
      appRouter.go('/canvas/$id');
      await settleIo(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CanvasScreen)),
      )!;

      Rect rectOf(Finder finder) => tester.getRect(
        find.descendant(of: finder, matching: find.byType(InkResponse)).first,
      );
      final rects = [
        rectOf(find.byTooltip(l10n.commonUndo)),
        rectOf(find.byTooltip(l10n.commonRedo)),
        rectOf(find.byTooltip(l10n.canvasSettingsMenuTooltip)),
        rectOf(find.byTooltip(l10n.timelineBackToProjectListTooltip)),
        tester.getRect(
          find
              .descendant(
                of: find.byKey(const Key('canvasTimelineModeButton')),
                matching: find.byType(InkResponse),
              )
              .first,
        ),
      ];
      for (final rect in rects) {
        expect(rect.width, greaterThanOrEqualTo(48), reason: '$rect');
        expect(rect.height, greaterThanOrEqualTo(48), reason: '$rect');
        expect(rect.right, lessThanOrEqualTo(width), reason: '$rect');
      }
      // undo-redo, settings-home, home-timeline sit apart.
      for (final (a, b) in [(0, 1), (2, 3), (3, 4)]) {
        expect(
          rects[b].left - rects[a].right,
          greaterThanOrEqualTo(8),
          reason: 'gap between buttons $a and $b',
        );
      }
      expect(
        find.descendant(
          of: find.byType(CanvasIconButton),
          matching: find.byIcon(Icons.undo),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      // Capture for the owner (half scale).
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final out = Directory('build/canvas-top-bar')
          ..createSync(recursive: true);
        File(
          '${out.path}/canvas_${width.toInt()}.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
      });

      // The arrow is part of the timeline button: tapping it opens the
      // timeline.
      final arrow = find.descendant(
        of: find.byKey(const Key('canvasTimelineModeButton')),
        matching: find.byIcon(Icons.arrow_forward),
      );
      await tester.tap(arrow);
      await settleIo(tester);
      expect(find.byType(TimelineScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
