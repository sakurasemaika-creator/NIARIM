import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/save_tree/widgets/save_thumbnail_capture.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/services/save_tree_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ui.Image> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}

Future<ui.Color> _pixel(Uint8List png, int x, int y) async {
  final image = await _decode(png);
  try {
    final raw = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final index = (y * image.width + x) * 4;
    return ui.Color.fromARGB(
      raw.getUint8(index + 3),
      raw.getUint8(index),
      raw.getUint8(index + 1),
      raw.getUint8(index + 2),
    );
  } finally {
    image.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'slot and tree thumbnails include actual paper and ink, frozen at save time',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final temp = Directory.systemTemp.createTempSync(
        'save_thumbnail_accuracy_',
      );
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => temp.path);
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });

      final ps = ProjectService();
      final saves = SaveTreeService();
      addTearDown(ps.dispose);
      addTearDown(saves.dispose);

      final created = await tester.runAsync(
        () => ps.createProject(
          name: 'Snapshot background accuracy',
          fps: 12,
          durationSeconds: 1,
          exportWidth: 20,
          exportHeight: 10,
          backgroundColor: 0xFF1B8D4A,
        ),
      );
      expect(created, isNotNull);
      final project = created!;
      final id = project.id;
      final scene = ps.scenesOf(id).first;
      final layer = scene.frames.first.layers.first;
      final tm = ps.tileManagerOf(id);
      final key = ps.tileKeyFor(
        id,
        scene.id,
        scene.frames.first.index,
        layer.id,
      );
      final tile = tm.getOrCreateTile(key, 0, 0);
      // Opaque red paint covers the top-left quarter. The rest must retain the
      // project's custom green background, not the save-card surface color.
      for (var y = 0; y < 5; y++) {
        for (var x = 0; x < 10; x++) {
          tm.setPixel(tile, x, y, 255, 0, 0, 255);
        }
      }
      tm.invalidateTile(key, 0, 0);
      final png = (await tester.runAsync(() => captureSaveThumbnail(ps, id)))!;
      expect(
        await tester.runAsync(() => _pixel(png, 180, 80)),
        const ui.Color(0xFF1B8D4A),
      );
      expect(
        await tester.runAsync(() => _pixel(png, 20, 20)),
        const ui.Color(0xFFFF0000),
      );

      final slot = (await tester.runAsync(
        () => saves.saveToSlot(
          projectId: id,
          slotIndex: 0,
          project: project,
          scenes: ps.scenesOf(id),
          tileManager: tm,
          comment: 'slot capture',
          thumbnailPngBytes: png,
        ),
      ))!;
      expect(slot.thumbnailPath, isNotNull);
      final slotFile = File(slot.thumbnailPath!);
      expect(slotFile.readAsBytesSync(), orderedEquals(png));

      saves.setTreeMode(true);
      final branch = (await tester.runAsync(
        () => saves.saveAsChild(
          projectId: id,
          project: project,
          scenes: ps.scenesOf(id),
          tileManager: tm,
          comment: 'tree capture',
          thumbnailPngBytes: png,
        ),
      ))!;
      expect(branch.thumbnailPath, isNotNull);
      final treeFile = File(branch.thumbnailPath!);
      expect(treeFile.readAsBytesSync(), orderedEquals(png));

      // Renaming never changes timestamp, screenshot, or file payload.
      expect(
        await tester.runAsync(() => saves.renameSave(id, branch.id, 'renamed')),
        isTrue,
      );
      final renamed = saves.getNodes(id).singleWhere((n) => n.id == branch.id);
      expect(renamed.savedAt, branch.savedAt);
      expect(renamed.thumbnailPath, branch.thumbnailPath);
      expect(treeFile.readAsBytesSync(), orderedEquals(png));

      // A later drawing change must not rewrite the saved thumbnail.
      for (var y = 0; y < 5; y++) {
        for (var x = 0; x < 10; x++) {
          tm.setPixel(tile, x, y, 0, 0, 255, 255);
        }
      }
      tm.invalidateTile(key, 0, 0);
      final newer = (await tester.runAsync(
        () => captureSaveThumbnail(ps, id),
      ))!;
      expect(
        await tester.runAsync(() => _pixel(newer, 20, 20)),
        const ui.Color(0xFF0000FF),
      );
      expect(slotFile.readAsBytesSync(), orderedEquals(png));
      expect(treeFile.readAsBytesSync(), orderedEquals(png));

      final out = Directory('build/save-slot-visual-audit')
        ..createSync(recursive: true);
      File('${out.path}/snapshot_ink_and_background.png').writeAsBytesSync(png);
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
