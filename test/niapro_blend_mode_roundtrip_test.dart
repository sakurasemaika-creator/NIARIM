import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('niapro round-trip preserves all added blend modes distinctly', () async {
    final dir = await Directory.systemTemp.createTemp('niarim-blend-roundtrip-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final modes = <LayerBlendMode>[
      LayerBlendMode.addition,
      LayerBlendMode.linearBurn,
      LayerBlendMode.linearDodge,
      LayerBlendMode.vividLight,
      LayerBlendMode.linearLight,
      LayerBlendMode.pinLight,
      LayerBlendMode.hardMix,
      LayerBlendMode.exclusion,
      LayerBlendMode.divide,
    ];

    final layers = <Layer>[
      for (var i = 0; i < modes.length; i++)
        Layer(
          id: 'blend_$i',
          name: modes[i].name,
          type: LayerType.normal,
          blendMode: modes[i],
        ),
    ];
    final scene = Scene(
      id: 'Scene0001',
      index: 0,
      frames: [Frame(index: 0, layers: layers)],
    );
    final now = DateTime.utc(2026, 1, 1);
    final project = Project(
      id: 'blend-roundtrip',
      name: 'Blend Round Trip',
      fps: 24,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      createdAt: now,
      updatedAt: now,
      totalWorkSeconds: 0,
    );
    final path = '${dir.path}/blend-roundtrip.niapro';
    final tm = TileManager(canvasWidth: 16, canvasHeight: 16);

    await NiaproSerializer.saveToPath(
      filePath: path,
      project: project,
      scenes: [scene],
      tileManager: tm,
    );
    final loaded = await NiaproSerializer.load(path);
    final restored = loaded.scenes.single.frames.single.layers;

    expect(restored.map((l) => l.blendMode).toList(), modes);
    expect(
      restored.firstWhere((l) => l.name == 'addition').blendMode,
      LayerBlendMode.addition,
    );
    expect(
      restored.firstWhere((l) => l.name == 'linearDodge').blendMode,
      LayerBlendMode.linearDodge,
    );
    expect(LayerBlendMode.addition, isNot(LayerBlendMode.linearDodge));
  });
}
