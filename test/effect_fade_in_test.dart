// フェードイン（色から絵へ）（所有者の判断、2026-11-27、全部入りの作品づくりの
// 判断カードJ18）：演出フィルターのフェードは「始めの絵→終わりで色」だけだった。
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A white 2x2 frame, faded to black over frames 0..4.
  Uint8List white() => Uint8List.fromList([
    for (var i = 0; i < 4; i++) ...[255, 255, 255, 255],
  ]);
  int redAt(EffectFilterInstance e, int frame) =>
      FilterEngine().applyEffectFilters(white(), 2, 2, [e], frame)[0];
  const out = EffectFilterInstance(
    id: 'f',
    type: EffectFilterType.fade,
    startFrame: 0,
    endFrame: 4,
  );

  test('a fade-out goes to the colour, a fade-in comes from it', () {
    expect(redAt(out, 0), 255);
    expect(redAt(out, 4), 0);
    final fadeIn = out.copyWith(fadeIn: true);
    expect(redAt(fadeIn, 0), 0);
    expect(redAt(fadeIn, 2), closeTo(128, 1));
    expect(redAt(fadeIn, 4), 255);
  });

  test('the direction is saved, and older files read as a fade-out', () async {
    final dir = await Directory.systemTemp.createTemp('niarim-fade-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final now = DateTime.utc(2026, 1, 1);
    final project = Project(
      id: 'fade',
      name: 'Fade',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      createdAt: now,
      updatedAt: now,
      totalWorkSeconds: 0,
    );
    final scene = Scene(
      id: 'Scene0001',
      index: 0,
      frames: const [Frame(index: 0, layers: [])],
      effectFilters: [
        out.copyWith(
          id: 'in',
          fadeIn: true,
          fadeColor: const Color(0xFF000000),
        ),
        out.copyWith(id: 'out'),
      ],
    );
    final path = '${dir.path}/fade.niapro';
    await NiaproSerializer.saveToPath(
      filePath: path,
      project: project,
      scenes: [scene],
      tileManager: TileManager(canvasWidth: 4, canvasHeight: 4),
    );
    final loaded = {
      for (final e in (await NiaproSerializer.load(
        path,
      )).scenes.single.effectFilters)
        e.id: e,
    };
    expect(loaded['in']!.fadeIn, isTrue);
    expect(loaded['out']!.fadeIn, isFalse);
  });
}
