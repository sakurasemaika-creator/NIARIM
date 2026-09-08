import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/auto_lineart_control_overlay.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _rough(int w, int h) {
  final out = Uint8List(w * h * 4);
  void dot(int cx, int cy, int r) {
    for (var y = cy - r; y <= cy + r; y++) {
      for (var x = cx - r; x <= cx + r; x++) {
        if (x < 0 || x >= w || y < 0 || y >= h) continue;
        final dx = x - cx;
        final dy = y - cy;
        if (dx * dx + dy * dy > r * r) continue;
        final i = (y * w + x) * 4;
        out[i] = 30;
        out[i + 1] = 30;
        out[i + 2] = 30;
        out[i + 3] = 255;
      }
    }
  }

  for (var x = 15; x < w - 15; x++) {
    dot(x, (h / 2 + 14 * math.sin(x / 12)).round(), 4);
  }
  return out;
}

Future<Uint8List> _layerBytes(
  ProjectService ps,
  String projectId,
  String sceneId,
  int frame,
  String layerId,
) async {
  final image = await ps.tileManagerOf(projectId).compositeLayerToImage(
        ps.tileKeyFor(projectId, sceneId, frame, layerId),
      );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'manual frame-0 control edit is never reused by multi-frame application',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tempDir = Directory.systemTemp.createTempSync('niarim_lineart_bulk_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => tempDir.path);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      SharedPreferences.setMockInitialValues({});
      final providers = (await tester.runAsync(buildAppProviders))!;
      BuildContext? providerContext;
      final bulk = ValueNotifier<Set<int>?>(null);
      addTearDown(bulk.dispose);
      String? projectId;
      String? sceneId;
      String? layerId;

      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: Builder(
            builder: (context) {
              providerContext = context;
              return MaterialApp(
                theme: context.watch<ThemeService>().themeData,
                locale: const Locale('ja'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Center(
                    child: ValueListenableBuilder<Set<int>?>(
                      valueListenable: bulk,
                      builder: (_, frames, __) => projectId == null
                          ? const SizedBox()
                          : FilterPanel(
                              projectId: projectId!,
                              sceneId: sceneId!,
                              layerId: layerId,
                              frameIndex: 0,
                              bulkFrameIndices: frames,
                              onClose: () {},
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      final context = providerContext!;
      final ps = context.read<ProjectService>();
      final fs = context.read<FilterService>();
      final project = await tester.runAsync(
        () => ps.createProject(
          name: 'bulk isolation',
          fps: 12,
          durationSeconds: 1,
          backgroundColor: 0xFFFFFFFF,
          exportWidth: 160,
          exportHeight: 160,
        ),
      );
      projectId = project.id;
      final scene = ps.scenesOf(project.id).first;
      sceneId = scene.id;
      layerId = scene.frames.first.layers.first.id;
      ps.addFrame(project.id, scene.id);
      final tm = ps.tileManagerOf(project.id);
      final rough = _rough(tm.canvasWidth, tm.canvasHeight);
      for (final frame in [0, 1]) {
        tm.replaceLayerPixels(
          ps.tileKeyFor(project.id, scene.id, frame, layerId!),
          Uint8List.fromList(rough),
        );
      }
      fs.selectFilter('Filter0023');
      fs.updateFilterParams('Filter0023', autoLineartSmoothing: 5);
      bulk.notifyListeners();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byType(AutoLineartControlOverlay), findsOneWidget);

      final overlay = tester.widget<AutoLineartControlOverlay>(
        find.byType(AutoLineartControlOverlay),
      );
      final graph = overlay.graph;
      final pIndex = graph.paths.indexWhere((p) => p.points.length >= 3);
      expect(pIndex, greaterThanOrEqualTo(0));
      final point = graph.paths[pIndex].points[graph.paths[pIndex].points.length ~/ 2];
      final rect = tester.getRect(find.byType(AutoLineartControlOverlay));
      await tester.dragFrom(
        Offset(
          rect.left + point.x / graph.width * rect.width,
          rect.top + point.y / graph.height * rect.height,
        ),
        const Offset(0, -35),
      );
      await tester.pump(const Duration(milliseconds: 250));

      // Switch this same panel state into bulk mode after a manual edit.
      bulk.value = {0, 1};
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(AutoLineartControlOverlay), findsNothing);
      final apply = find.descendant(
        of: find.byType(FilterPanel),
        matching: find.byType(FilledButton),
      );
      await tester.tap(apply);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() async {
        for (var i = 0; i < 120; i++) {
          final f0 = ps.layersOf(project.id, scene.id, 0);
          final f1 = ps.layersOf(project.id, scene.id, 1);
          if (f0.length >= 2 && f1.length >= 2) break;
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pump(const Duration(milliseconds: 300));

      final f0 = ps.layersOf(project.id, scene.id, 0);
      final f1 = ps.layersOf(project.id, scene.id, 1);
      expect(f0, hasLength(2));
      expect(f1, hasLength(2));
      final g0 = f0.singleWhere((l) => l.id != layerId);
      final g1 = f1.singleWhere((l) => l.id != layerId);
      expect(g0.id, g1.id);
      final b0 = await _layerBytes(ps, project.id, scene.id, 0, g0.id);
      final b1 = await _layerBytes(ps, project.id, scene.id, 1, g1.id);
      expect(b0, orderedEquals(b1));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
