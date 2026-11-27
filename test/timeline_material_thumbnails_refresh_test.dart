// タイムラインのフレーム一覧のサムネイルは、文字の素材を直したら、素材が
// 出ているどのコマでも描き直し、プレビュー・書き出しと同じ重なり順で描く。
//
// 実際に使ってみたとき（2026-11-27）、文字の素材を足した・直した後に、最初の
// コマ以外のサムネイルが違って見えた。サムネイルはレイヤー一覧の並び
// （layersOf）で合成していて、素材の前後（重なり順、Scene.stack）とマスクを
// 見ていなかったので、素材を足したコマだけ新しい素材が手前に描かれた。
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/app.dart';
import 'package:niarim/app_bootstrap.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/router.dart';
import 'package:niarim/services/project_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/first_use_tooltips.dart';
import 'helpers/pump_real_async.dart';

void main() {
  testWidgets('every frame of a material redraws its thumbnail when the '
      'material changes', (tester) async {
    SharedPreferences.setMockInitialValues({
      'first_launch': false,
      'language': 'ja',
      'force_pc_mode': 0,
      firstUseTooltipsSeenKey: kAllFirstUseTooltipKeys,
    });
    final directory = Directory.systemTemp.createTempSync('thumbs-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    appRouter.go('/');
    final providers = await tester.runAsync(buildAppProviders);
    await tester.pumpWidget(
      MultiProvider(providers: providers!, child: const NiarimApp()),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final ps = tester
        .element(find.byType(MaterialApp).first)
        .read<ProjectService>();

    const w = 160, h = 90;
    Uint8List filled(int r, int g, int b) {
      final bytes = Uint8List(w * h * 4);
      for (var i = 0; i < w * h; i++) {
        bytes[i * 4] = r;
        bytes[i * 4 + 1] = g;
        bytes[i * 4 + 2] = b;
        bytes[i * 4 + 3] = 255;
      }
      return bytes;
    }

    late String projectId, sceneId, textId;
    await tester.runAsync(() async {
      final project = await ps.createProject(
        name: 'thumbs',
        fps: 10,
        durationSeconds: 1,
        backgroundColor: 0xFFFFFFFF,
        exportWidth: w,
        exportHeight: h,
      );
      projectId = project.id;
      sceneId = ps.scenesOf(projectId).first.id;
      final text = ps.addLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: 0,
        type: LayerType.timelineText,
        name: 'text',
      );
      textId = text.id;
      ps.updateLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: 0,
        layer: text.copyWith(
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: 1,
          rangeEnd: 4,
        ),
      );
      ps.replaceLayerPixels(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: 0,
        layerId: textId,
        pixels: filled(255, 0, 0),
      );
    });

    appRouter.go('/timeline/$projectId');
    await pumpRealAsync(tester, const Duration(milliseconds: 800));

    Finder thumbs() => find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_TimelineFrameThumbnail',
    );
    Future<List<int>> centreOf(int index) async {
      final image = tester
          .widget<RawImage>(
            find.descendant(
              of: thumbs().at(index),
              matching: find.byType(RawImage),
            ),
          )
          .image!;
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final i = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
      // Opaque material pixels: their colour; nothing: transparent (the
      // project's paper is drawn behind the thumbnail, not in it).
      if (data.getUint8(i + 3) == 0) return const [];
      return [data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2)];
    }

    expect(thumbs(), findsAtLeastNWidgets(3));
    for (final i in [0, 1, 2]) {
      expect(await centreOf(i), [255, 0, 0], reason: 'frame ${i + 1} red');
    }

    // The material is redrawn (as the text panel does): every frame follows.
    final layer = ps
        .storedLayersOf(projectId, sceneId, 0)
        .firstWhere((l) => l.id == textId);
    ps.replaceLayerPixels(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: 0,
      layerId: textId,
      pixels: filled(0, 0, 255),
      updatedLayer: layer.copyWith(name: 'blue'),
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 800));
    for (final i in [0, 1, 2]) {
      expect(await centreOf(i), [0, 0, 255], reason: 'frame ${i + 1} blue');
    }

    // A new text added on frame 3 over frames 1–4, the way the timeline
    // adds one: the layer first, its pixels, then its range.
    ps.removeLayer(
      projectId: projectId,
      sceneId: sceneId,
      frameIndex: 0,
      layerId: textId,
    );
    await pumpRealAsync(tester, const Duration(milliseconds: 800));
    for (final i in [0, 1, 2, 3]) {
      expect(await centreOf(i), isEmpty, reason: 'frame ${i + 1}');
    }
    ps.editTimeline(projectId, 'Add text clip', () {
      final added = ps.addLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: 2,
        type: LayerType.timelineText,
        name: 'green',
      );
      ps
          .tileManagerOf(projectId)
          .replaceLayerPixels(
            ps.tileKeyFor(projectId, sceneId, 2, added.id),
            filled(0, 255, 0),
          );
      ps.updateLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: 2,
        layer: added.copyWith(
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: 1,
          rangeEnd: 4,
        ),
      );
      return added;
    });
    await pumpRealAsync(tester, const Duration(milliseconds: 800));
    // Every frame green: the only material.
    final seen = [
      for (final i in [0, 1, 2, 3]) await centreOf(i),
    ];
    expect(seen, List.filled(4, [0, 255, 0]));

    // A second text in its own row behind it, added on frame 3: the stack
    // puts the first row in front on every frame, as the preview does.
    ps.editTimeline(projectId, 'Add text clip', () {
      final added = ps.addLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: 2,
        type: LayerType.timelineText,
        name: 'yellow',
      );
      ps
          .tileManagerOf(projectId)
          .replaceLayerPixels(
            ps.tileKeyFor(projectId, sceneId, 2, added.id),
            filled(255, 255, 0),
          );
      ps.updateLayer(
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: 2,
        layer: added.copyWith(
          trackRow: 1,
          rangeMode: LayerRangeMode.frameRange,
          rangeStart: 1,
          rangeEnd: 4,
        ),
      );
      return added;
    });
    await pumpRealAsync(tester, const Duration(milliseconds: 800));
    final front = ps
        .stackedLayersOf(projectId, sceneId, 0)
        .layers
        .firstWhere((l) => l.type == LayerType.timelineText)
        .name;
    final expected = front == 'yellow' ? [255, 255, 0] : [0, 255, 0];
    for (final f in [0, 1, 2, 3]) {
      expect(
        ps
            .stackedLayersOf(projectId, sceneId, f)
            .layers
            .firstWhere((l) => l.type == LayerType.timelineText)
            .name,
        front,
        reason: 'the stack is the same on every frame',
      );
    }
    final stackedSeen = [
      for (final i in [0, 1, 2, 3]) await centreOf(i),
    ];
    expect(stackedSeen, List.filled(4, expected));
    expect(tester.takeException(), isNull);
  });
}
