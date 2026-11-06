import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/engine/auto_lineart_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/models/layer.dart' as model;
import 'package:niarim/screens/canvas/widgets/auto_lineart_control_overlay.dart';
import 'package:niarim/screens/canvas/widgets/filter_panel.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pick_filter_card.dart';
import 'helpers/pump_real_async.dart';

const _size = 96;

/// Editing auto line art's control points (moving, adding, deleting) is
/// part of the filter's Undo / Redo, in order with the slider changes: one
/// drag or one tap is one step.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    SharedPreferences.setMockInitialValues({
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathChannel,
          (_) async => '${Directory.systemTemp.path}/niarim_lineart_undo',
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
  });

  testWidgets('moving, adding and deleting points are Undo steps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final providers = await tester.runAsync(buildAppProviders);
    Widget app(Widget home) => MultiProvider(
      providers: providers!,
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    );
    await tester.pumpWidget(app(const SizedBox()));
    final context = tester.element(find.byType(SizedBox).first);
    final projects = context.read<ProjectService>();
    final project = (await tester.runAsync(
      () => projects.createProject(
        name: 'lineart-undo',
        fps: 24,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: _size,
        exportHeight: _size,
      ),
    ))!;
    final sceneId = projects.scenesOf(project.id).first.id;
    final layerId = projects
        .layersOf(project.id, sceneId, 0)
        .firstWhere((layer) => layer.type == model.LayerType.normal)
        .id;
    // A rough diagonal stroke, several pixels wide.
    final rough = Uint8List(_size * _size * 4);
    for (var t = 10; t < 86; t++) {
      for (var dy = -3; dy <= 3; dy++) {
        for (var dx = -3; dx <= 3; dx++) {
          if (dx * dx + dy * dy > 9) continue;
          final x = t + dx, y = (t * 0.6 + 20).round() + dy;
          rough.setAll((y * _size + x) * 4, [30, 30, 30, 255]);
        }
      }
    }
    projects
        .tileManagerOf(project.id)
        .replaceLayerPixels(
          projects.tileKeyFor(project.id, sceneId, 0, layerId),
          rough,
        );
    await tester.pumpWidget(
      app(
        FilterPanel(
          projectId: project.id,
          sceneId: sceneId,
          layerId: layerId,
          frameIndex: 0,
          onClose: () {},
        ),
      ),
    );
    await pickFilterCard(tester, 'Filter0023');
    await pumpRealAsync(tester, const Duration(milliseconds: 600));
    final service = tester
        .element(find.byType(FilterPanel))
        .read<FilterService>();
    final overlay = find.byType(AutoLineartControlOverlay);
    expect(overlay, findsOneWidget);
    AutoLineartGraph graph() =>
        tester.widget<AutoLineartControlOverlay>(overlay).graph;
    final original = graph();
    expect(original.paths, isNotEmpty);
    expect(service.canUndoFilterEdit, isFalse);

    /// Where graph point [p] is on the screen.
    Offset onScreen(AutoLineartPoint p) {
      final rect = tester.getRect(overlay);
      final g = graph();
      final scale = (rect.width / g.width) < (rect.height / g.height)
          ? rect.width / g.width
          : rect.height / g.height;
      final left = rect.left + (rect.width - g.width * scale) / 2;
      final top = rect.top + (rect.height - g.height * scale) / 2;
      return Offset(left + p.x * scale, top + p.y * scale);
    }

    final path = original.paths.first;
    final pointIndex = path.points.length ~/ 2;
    final point = path.points[pointIndex];

    // ── Move a point: one drag, one step ──
    final gesture = await tester.startGesture(onScreen(point));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, -4));
      await tester.pump();
    }
    await gesture.up();
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    final moved = graph();
    expect(
      moved.paths.first.points[pointIndex].y,
      lessThan(point.y - 2),
      reason: 'the point moved up',
    );
    expect(service.canUndoFilterEdit, isTrue);

    // ── A slider change after it ──
    service.updateFilterParams('Filter0023', autoLineartOutputWidth: 4);
    await pumpRealAsync(tester, const Duration(milliseconds: 200));

    // Undo takes back the slider, then the drag.
    await tester.tap(find.byKey(const ValueKey('filter-undo-button')));
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    expect(service.currentFilter!.autoLineartOutputWidth, 2);
    expect(
      graph().paths.first.points[pointIndex].y,
      moved.paths.first.points[pointIndex].y,
      reason: 'the drag is still there',
    );
    await tester.tap(find.byKey(const ValueKey('filter-undo-button')));
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    expect(graph().paths.first.points[pointIndex].y, point.y);
    expect(service.canUndoFilterEdit, isFalse);

    // Redo brings the drag back, then the slider.
    await tester.tap(find.byKey(const ValueKey('filter-redo-button')));
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    expect(
      graph().paths.first.points[pointIndex].y,
      moved.paths.first.points[pointIndex].y,
    );
    await tester.tap(find.byKey(const ValueKey('filter-redo-button')));
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    expect(service.currentFilter!.autoLineartOutputWidth, 4);

    // ── Delete a point in delete mode: one tap, one step ──
    final before = graph();
    final count = before.paths.first.points.length;
    await tester.tap(
      find.byKey(const ValueKey('auto-lineart-delete-point-button')),
    );
    await tester.pump();
    await tester.tapAt(onScreen(before.paths.first.points[1]));
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    expect(graph().paths.first.points.length, count - 1);
    await tester.tap(find.byKey(const ValueKey('filter-undo-button')));
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    expect(graph().paths.first.points.length, count);

    // ── In move mode a tap on a point asks first (in the app's language);
    // the confirmed delete is one step too ──
    await tester.tap(
      find.byKey(const ValueKey('auto-lineart-delete-point-button')),
    );
    await tester.pump();
    final l10n = AppLocalizations.of(tester.element(overlay))!;
    await tester.tapAt(onScreen(graph().paths.first.points[1]));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(find.text(l10n.filterAutoLineartDeletePointConfirm), findsOneWidget);
    await tester.tap(find.text(l10n.commonDelete));
    await pumpRealAsync(tester, const Duration(milliseconds: 300));
    expect(graph().paths.first.points.length, count - 1);
    await tester.tap(find.byKey(const ValueKey('filter-undo-button')));
    await pumpRealAsync(tester, const Duration(milliseconds: 200));
    expect(graph().paths.first.points.length, count);
    await tester.pumpWidget(const SizedBox());
  });
}
