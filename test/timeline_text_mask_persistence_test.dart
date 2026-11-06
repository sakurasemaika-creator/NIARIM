// タイムラインのテキスト素材・マスク・X/Y軸回転・重なり順・シーンの並びが
// .niaproへ保存して読み戻しても残ること。
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/niapro_serializer.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_keyframe.dart';
import 'package:niarim/models/layer_mask.dart';
import 'package:niarim/models/project.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/models/scene_stack.dart';
import 'package:niarim/models/text_object.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('text materials, masks, 3D turns and the stacking order survive a '
      'save and load', () async {
    final dir = await Directory.systemTemp.createTemp('niarim-timeline-text-');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final now = DateTime.utc(2026, 10, 16);
    final project = Project(
      id: 'timeline-text',
      name: 'Timeline Text',
      fps: 12,
      durationSeconds: 1,
      backgroundColor: 0xFFFFFFFF,
      createdAt: now,
      updatedAt: now,
      totalWorkSeconds: 0,
    );
    const mask = LayerMask(
      shape: LayerMaskShape.ellipse,
      centerX: 30,
      centerY: 70,
      width: 40,
      height: 20,
      rotation: 15,
      feather: 4,
      invert: true,
    );
    final text = Layer(
      id: 'Layer0002',
      name: 'Title',
      type: LayerType.timelineText,
      trackRow: 1,
      rangeMode: LayerRangeMode.frameRange,
      rangeStart: 2,
      rangeEnd: 5,
      mask: mask,
      textObject: const TextObject(
        id: 'Layer0002',
        text: 'タイトル',
        fontSize: 40,
        color: Color(0xFFFF4060),
      ),
      keyframes: const [
        LayerKeyframe(
          frameIndex: 1,
          x: 12,
          y: -8,
          scale: 1.5,
          rotation: 10,
          rotationX: 35,
          rotationY: -20,
        ),
      ],
    );
    final stack = SceneStack(
      order: [
        stackTrackKey(StackTrackKind.text, 0),
        kStackFrame,
        stackTrackKey(StackTrackKind.text, 1),
      ],
      ranges: [
        StackRange(
          start: 3,
          end: 6,
          order: [kStackFrame, stackTrackKey(StackTrackKind.text, 1)],
        ),
      ],
      frameMask: const LayerMask(feather: 2),
    );
    // The second scene was moved in front of the first (its id keeps the
    // number it was made with).
    final scenes = [
      Scene(
        id: 'Scene0002',
        index: 0,
        frames: [
          const Frame(index: 0, layers: []),
          Frame(
            index: 1,
            layers: [
              text,
              const Layer(
                id: 'Layer0001',
                name: 'Layer',
                type: LayerType.normal,
              ),
            ],
          ),
        ],
        textRowNames: const [null, 'サブタイトル'],
        stack: stack,
      ),
      const Scene(
        id: 'Scene0001',
        index: 1,
        frames: [Frame(index: 0, layers: [])],
      ),
    ];
    final path = '${dir.path}/timeline-text.niapro';
    await NiaproSerializer.saveToPath(
      filePath: path,
      project: project,
      scenes: scenes,
      tileManager: TileManager(canvasWidth: 16, canvasHeight: 16),
    );

    final loaded = await NiaproSerializer.load(path);
    expect(loaded.scenes.map((s) => s.id), ['Scene0002', 'Scene0001']);
    final scene = loaded.scenes.first;
    expect(scene.textRowNames, [null, 'サブタイトル']);
    expect(scene.stack.order, stack.order);
    expect(scene.stack.ranges.single.start, 3);
    expect(scene.stack.ranges.single.end, 6);
    expect(scene.stack.ranges.single.order, stack.ranges.single.order);
    expect(scene.stack.frameMask, const LayerMask(feather: 2));

    final back = scene.frames[1].layers.firstWhere((l) => l.id == 'Layer0002');
    expect(back.type, LayerType.timelineText);
    expect(back.trackRow, 1);
    expect(back.rangeStart, 2);
    expect(back.rangeEnd, 5);
    expect(back.mask, mask);
    expect(back.textObject?.text, 'タイトル');
    final kf = back.keyframes.single;
    expect(kf.rotationX, 35);
    expect(kf.rotationY, -20);
    expect(kf.rotation, 10);
    expect(kf.scale, 1.5);
  });
}
