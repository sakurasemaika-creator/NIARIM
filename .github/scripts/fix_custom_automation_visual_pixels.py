from pathlib import Path

p = Path('test/custom_automation_visual_audit_test.dart')
s = p.read_text()

if "import 'dart:async';" not in s:
    s = s.replace("import 'dart:io';\n", "import 'dart:async';\nimport 'dart:io';\n", 1)
if "package:niarim/engine/tile_manager.dart" not in s:
    s = s.replace(
        "import 'package:niarim/engine/custom_automation_filter_runner.dart';\n",
        "import 'package:niarim/engine/custom_automation_filter_runner.dart';\n"
        "import 'package:niarim/engine/tile_manager.dart';\n",
        1,
    )

start = s.find('      Future<Uint8List> activeLayerPixels() async {')
end = s.find('\n      int changedBytes(', start)
if start < 0 or end < 0:
    raise SystemExit('activeLayerPixels anchor changed')

replacement = '''      Uint8List activeLayerPixels() {
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
        const tileBytes = TileManager.tileSize * TileManager.tileSize * 4;
        final snapshot = Uint8List(tm.tilesX * tm.tilesY * tileBytes);
        var offset = 0;
        for (var ty = 0; ty < tm.tilesY; ty++) {
          for (var tx = 0; tx < tm.tilesX; tx++) {
            final tile = tm.getTile(key, tx, ty);
            if (tile != null) {
              snapshot.setRange(offset, offset + tileBytes, tile);
            }
            offset += tileBytes;
          }
        }
        return snapshot;
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
          await tester.pump(const Duration(milliseconds: 16));
          await Future<void>.delayed(Duration.zero);
        }
        if (!done) {
          throw TimeoutException('Canvas automation async operation did not finish');
        }
        if (error != null) {
          Error.throwWithStackTrace(error!, stack!);
        }
        return value as T;
      }
'''
s = s[:start] + replacement + s[end:]

s = s.replace('await tester.runAsync(activeLayerPixels)', 'activeLayerPixels()')

old_runner = '''      await tester.runAsync(
        () => CustomAutomationFilterRunner.apply(
          projectService: ps!,
          projectId: project.id,
          sceneId: canvasAtRecord.sceneId,
          frameIndex: canvasAtRecord.currentFrame,
          sourceLayerId: sourceLayerId!,
          filter: recordedFilter,
        ),
      );'''
new_runner = '''      await driveAsync(
        CustomAutomationFilterRunner.apply(
          projectService: ps!,
          projectId: project.id,
          sceneId: canvasAtRecord.sceneId,
          frameIndex: canvasAtRecord.currentFrame,
          sourceLayerId: sourceLayerId!,
          filter: recordedFilter,
        ),
      );'''
if old_runner not in s:
    raise SystemExit('filter runner anchor changed')
s = s.replace(old_runner, new_runner, 1)

old_replay = '''      await tester.pump(const Duration(milliseconds: 900));
      final afterReplay ='''
new_replay = '''      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await Future<void>.delayed(Duration.zero);
      }
      final afterReplay ='''
if old_replay not in s:
    raise SystemExit('replay pump anchor changed')
s = s.replace(old_replay, new_replay, 1)

p.write_text(s)
