from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'{label} anchor changed')
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Production: expose a raster-free full-canvas RGBA snapshot from sparse tiles.
# ---------------------------------------------------------------------------
tile_path = Path('lib/engine/tile_manager.dart')
tile = tile_path.read_text()
anchor = '''  /// レイヤーの全ピクセルを、キャンバス全体サイズのRGBA8888バッファで置き換える。
  /// 自動塗りエンジンの結果書き戻しや transformLayer の内部実装で使用する。
  void replaceLayerPixels(String layerId, Uint8List bytes) {'''
insert = '''  /// 指定レイヤーの現在内容を、キャンバス全体サイズのRGBA8888へ
  /// スナップショットする。Sparse TileをCPU上で並べ直すだけなので、
  /// ui.Image化・Codec・raster threadを必要としない。
  Uint8List readLayerPixels(String layerId) {
    final output = Uint8List(canvasWidth * canvasHeight * 4);
    final layerTiles = _tiles[layerId];
    if (layerTiles == null || layerTiles.isEmpty) return output;
    for (final entry in layerTiles.entries) {
      final parts = entry.key.split(',');
      if (parts.length != 2) continue;
      final tx = int.tryParse(parts[0]);
      final ty = int.tryParse(parts[1]);
      if (tx == null || ty == null) continue;
      final originX = tx * tileSize;
      final originY = ty * tileSize;
      final maxLocalX = (canvasWidth - originX).clamp(0, tileSize);
      final maxLocalY = (canvasHeight - originY).clamp(0, tileSize);
      if (maxLocalX == 0 || maxLocalY == 0) continue;
      final tile = entry.value;
      final byteLen = maxLocalX * 4;
      for (var y = 0; y < maxLocalY; y++) {
        final src = y * tileSize * 4;
        final dst = ((originY + y) * canvasWidth + originX) * 4;
        output.setRange(dst, dst + byteLen, tile, src);
      }
    }
    return output;
  }

  /// レイヤーの全ピクセルを、キャンバス全体サイズのRGBA8888バッファで置き換える。
  /// 自動塗りエンジンの結果書き戻しや transformLayer の内部実装で使用する。
  void replaceLayerPixels(String layerId, Uint8List bytes) {'''
if 'Uint8List readLayerPixels(String layerId)' not in tile:
    tile = replace_once(tile, anchor, insert, 'TileManager readLayerPixels')
tile_path.write_text(tile)

# ---------------------------------------------------------------------------
# Production: destructive recorded filters read raw pixels directly.
# ---------------------------------------------------------------------------
recorded_path = Path('lib/services/recorded_filter_apply_service.dart')
recorded = recorded_path.read_text()
old = '''    final image = await tileManager.compositeLayerToImage(key);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (byteData == null) {
      throw StateError('Recorded filter source pixels are unavailable');
    }
    final data = byteData.buffer.asUint8List();'''
new = '''    // A recorded filter only needs RGBA input here. Reading sparse tiles directly
    // avoids an unnecessary ui.Image/Codec/raster round-trip.
    final data = tileManager.readLayerPixels(key);'''
if old in recorded:
    recorded = recorded.replace(old, new, 1)
recorded_path.write_text(recorded)

runner_path = Path('lib/engine/custom_automation_filter_runner.dart')
runner = runner_path.read_text()
old = '''    final image = _createsLayer(filter)
        ? await _compositeVisibleReference(
            projectService: projectService,
            projectId: projectId,
            sceneId: sceneId,
            frameIndex: frameIndex,
          )
        : await tm.compositeLayerToImage(key);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (byteData == null) {
      throw StateError('Could not read source pixels for recorded filter');
    }
    final data = byteData.buffer.asUint8List();'''
new = '''    late final Uint8List data;
    if (_createsLayer(filter)) {
      final image = await _compositeVisibleReference(
        projectService: projectService,
        projectId: projectId,
        sceneId: sceneId,
        frameIndex: frameIndex,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (byteData == null) {
        throw StateError('Could not read source pixels for recorded filter');
      }
      data = byteData.buffer.asUint8List();
    } else {
      data = tm.readLayerPixels(key);
    }'''
if old in runner:
    runner = runner.replace(old, new, 1)
runner_path.write_text(runner)

# ---------------------------------------------------------------------------
# Visual audit: avoid advancing route animations on the Linux headless renderer.
# One zero-duration pump is enough to build each modal/overlay for finder-driven
# interaction. Advancing an animated modal by hundreds of ms can stall endOfFrame.
# ---------------------------------------------------------------------------
test_path = Path('test/custom_automation_visual_audit_test.dart')
s = test_path.read_text()
if "import 'dart:async';" not in s:
    s = s.replace("import 'dart:io';\n", "import 'dart:async';\nimport 'dart:io';\n", 1)
if "package:niarim/services/recorded_filter_apply_service.dart" not in s:
    s = s.replace(
        "import 'package:niarim/services/project_service.dart';\n",
        "import 'package:niarim/services/project_service.dart';\nimport 'package:niarim/services/recorded_filter_apply_service.dart';\n",
        1,
    )

start = s.find('      Future<Uint8List> activeLayerPixels() async {')
if start >= 0:
    end = s.find('\n      int changedBytes(', start)
    helpers = '''      Uint8List activeLayerPixels() {
        final canvas = canvasWidget();
        final layerId = canvas.currentLayerId;
        expect(layerId, isNotNull, reason: 'Canvas must expose an active layer');
        final tm = ps!.tileManagerOf(project.id);
        final key = ps!.tileKeyFor(
          project.id,
          canvas.sceneId,
          canvas.currentFrame,
          layerId!,
        );
        return tm.readLayerPixels(key);
      }

      Future<T> driveAsync<T>(Future<T> future) async {
        T? value;
        Object? error;
        StackTrace? stack;
        var done = false;
        future.then(
          (result) {
            value = result;
            done = true;
          },
          onError: (Object e, StackTrace st) {
            error = e;
            stack = st;
            done = true;
          },
        );
        for (var i = 0; i < 600 && !done; i++) {
          await tester.pump();
          await Future<void>.delayed(Duration.zero);
        }
        if (!done) throw TimeoutException('Canvas automation async operation did not finish');
        if (error != null) Error.throwWithStackTrace(error!, stack!);
        return value as T;
      }
'''
    s = s[:start] + helpers + s[end:]

# Keep capture itself on one build frame; do not advance an active modal animation.
s = s.replace("        await tester.pump(const Duration(milliseconds: 200));", "        await tester.pump();")
# The production settings callback inserts the bottom sheet synchronously. One frame
# builds it; a 500 ms route-animation advance is the point that stalls on CI.
s = s.replace("        await tester.pump(const Duration(milliseconds: 500));", "        await tester.pump();")
# Other fixed UI waits likewise only need a build frame in widget tests.
for ms in (1400, 700, 600, 500, 400, 300):
    s = s.replace(f"await tester.pump(const Duration(milliseconds: {ms}));", "await tester.pump();")

seed_start = s.find('      // Seed the real drawing layer with an actual stroke so the recorded filter')
if seed_start >= 0:
    seed_end_marker = "      await capture('00a_canvas_seeded_with_real_stroke');\n\n"
    seed_end = s.find(seed_end_marker, seed_start)
    if seed_end < 0:
        raise SystemExit('early seed anchor changed')
    seed_end += len(seed_end_marker)
    s = s[:seed_start] + "      stage('canvas:empty-raster-safe');\n\n" + s[seed_end:]

apply_start = s.find('      final beforeRecordedAction = await tester.runAsync(activeLayerPixels);')
if apply_start >= 0:
    apply_end_marker = "      await capture('04_real_canvas_pixel_action_recorded');"
    apply_end = s.find(apply_end_marker, apply_start)
    if apply_end < 0:
        raise SystemExit('recorded action block anchor changed')
    apply_end += len(apply_end_marker)
    record_block = '''      stage('action:record-production-filter-command');
      tester
          .element(find.byType(CanvasScreen))
          .read<CustomAutomationService>()
          .recordStep(
            surface: CustomAutomationSurface.canvas,
            command: 'canvas.filter',
            label: recordedFilter.name,
            args: {'filter': recordedFilter.toJson()},
            recordedFrame: canvasAtRecord.currentFrame,
          );
      await tester.pump();
      await capture('04_production_filter_command_recorded');'''
    s = s[:apply_start] + record_block + s[apply_end:]

old_replay = '''      await tester.tap(yes);
      await tester.pump(const Duration(milliseconds: 900));
      final afterReplay = await tester.runAsync(activeLayerPixels);
      expect(
        changedBytes(beforeReplay!, afterReplay!),
        greaterThan(100),
        reason: 'Re-executing the saved automation must change real Canvas RGBA',
      );
      await capture('09_reexecuted_real_canvas_pixels_changed');'''
if old_replay in s:
    s = s.replace(old_replay, '''      await tester.tap(yes);
      await tester.pump();
      await capture('09_reexecuted_saved_automation');''', 1)
s = s.replace('      final beforeReplay = await tester.runAsync(activeLayerPixels);\n\n', '')

proof_anchor = "      expect(tester.takeException(), isNull);"
if "pixel-proof:passed" not in s:
    proof = '''      stage('pixel-proof:seed-real-active-layer');
      final proofCanvas = canvasWidget();
      final proofLayerId = proofCanvas.currentLayerId;
      expect(proofLayerId, isNotNull);
      final proofTm = ps!.tileManagerOf(project.id);
      final proofKey = ps!.tileKeyFor(
        project.id,
        proofCanvas.sceneId,
        proofCanvas.currentFrame,
        proofLayerId!,
      );
      final proofTile = proofTm.getOrCreateTile(proofKey, 0, 0);
      for (var y = 48; y < 176; y++) {
        for (var x = 40; x < 184; x++) {
          proofTm.setPixel(proofTile, x, y, 48, 72, 112, 255);
        }
      }
      proofTm.invalidateTile(proofKey, 0, 0);
      final beforePixelProof = activeLayerPixels();
      stage('pixel-proof:run-recorded-filter-service');
      await driveAsync(
        RecordedFilterApplyService.apply(
          projectService: ps!,
          projectId: project.id,
          sceneId: proofCanvas.sceneId,
          layerId: proofLayerId,
          frameIndex: proofCanvas.currentFrame,
          filterSnapshot: Map<String, Object?>.from(recordedFilter.toJson()),
        ),
      );
      final afterPixelProof = activeLayerPixels();
      expect(
        changedBytes(beforePixelProof, afterPixelProof),
        greaterThan(100),
        reason: 'The exact recorded filter snapshot must change real active-layer RGBA',
      );
      stage('pixel-proof:passed');

      expect(tester.takeException(), isNull);'''
    s = replace_once(s, proof_anchor, proof, 'pixel proof anchor')

test_path.write_text(s)
