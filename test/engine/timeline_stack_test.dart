// タイムラインの重なり順（ユーザー指定「テキスト1とテキスト2の間にフレームの
// イラストを表示させる」「レイヤー順を細かくフレームごと、シーンごとに
// 変えられる」）：既定の順番、シーンの順番、「このフレームから」の変更、
// 素材は表示範囲のフレームにだけ出ること、フレーム（イラスト）のマスク。
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/timeline_stack.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_mask.dart';
import 'package:niarim/models/scene.dart';
import 'package:niarim/models/scene_stack.dart';

Layer _drawing(String id) => Layer(id: id, name: id, type: LayerType.normal);

Layer _clip(
  String id,
  LayerType type, {
  int row = 0,
  int start = 1,
  int end = 10,
}) => Layer(
  id: id,
  name: id,
  type: type,
  trackRow: row,
  rangeMode: LayerRangeMode.frameRange,
  rangeStart: start,
  rangeEnd: end,
);

List<String> _ids(StackedFrameLayers stacked) =>
    stacked.layers.map((l) => l.id).toList();

void main() {
  final lines = _drawing('lines');
  final paint = _drawing('paint');
  final text1 = _clip('text1', LayerType.timelineText);
  final text2 = _clip('text2', LayerType.timelineText, row: 1);
  final image = _clip('image', LayerType.timelineImage);
  final video = _clip('video', LayerType.timelineVideo);
  final resolved = [text2, image, lines, paint, video, text1];

  test('by default text is in front, then the drawing, images, video', () {
    const scene = Scene(id: 's', index: 0);
    expect(_ids(stackFrameLayers(scene, 0, resolved)), [
      'text1',
      'text2',
      'lines',
      'paint',
      'image',
      'video',
    ]);
  });

  test('the scene order can put the drawing between two texts', () {
    final scene = Scene(
      id: 's',
      index: 0,
      stack: SceneStack(
        order: [
          stackTrackKey(StackTrackKind.text, 0),
          kStackFrame,
          stackTrackKey(StackTrackKind.text, 1),
        ],
      ),
    );
    // The rows the order leaves out keep their default place among them.
    expect(_ids(stackFrameLayers(scene, 0, resolved)), [
      'text1',
      'lines',
      'paint',
      'text2',
      'image',
      'video',
    ]);
  });

  test('a change from a frame on lasts until the next change', () {
    final scene = Scene(
      id: 's',
      index: 0,
      stack: SceneStack(
        changes: [
          StackChange(
            frameIndex: 3,
            order: [stackTrackKey(StackTrackKind.video, 0), kStackFrame],
          ),
          const StackChange(frameIndex: 5, order: []),
        ],
      ),
    );
    List<String> at(int frame) =>
        _ids(stackFrameLayers(scene, frame, resolved));
    expect(at(2).last, 'video');
    expect(at(3).first, 'text1');
    expect(at(3).indexOf('video'), lessThan(at(3).indexOf('lines')));
    expect(at(4).indexOf('video'), lessThan(at(4).indexOf('lines')));
    // An empty change goes back to the scene's (default) order.
    expect(at(5).last, 'video');
  });

  test('a material shows only within its frame range', () {
    const scene = Scene(id: 's', index: 0);
    final late = _clip('late', LayerType.timelineText, start: 5, end: 6);
    expect(_ids(stackFrameLayers(scene, 0, [lines, late])), ['lines']);
    expect(_ids(stackFrameLayers(scene, 4, [lines, late])), ['late', 'lines']);
    expect(_ids(stackFrameLayers(scene, 6, [lines, late])), ['lines']);
  });

  test('watermarks stay in front of everything', () {
    const scene = Scene(id: 's', index: 0);
    const mark = Layer(id: 'mark', name: 'mark', type: LayerType.watermark);
    expect(_ids(stackFrameLayers(scene, 0, [lines, text1, mark])), [
      'mark',
      'text1',
      'lines',
    ]);
  });

  test('the frame mask groups the drawing layers, not the canvas', () {
    const scene = Scene(
      id: 's',
      index: 0,
      stack: SceneStack(frameMask: LayerMask(shape: LayerMaskShape.ellipse)),
    );
    final stacked = stackFrameLayers(scene, 0, resolved);
    expect(stacked.maskGroups, hasLength(1));
    expect(stacked.maskGroups.single.layerIds, {'lines', 'paint'});
    expect(
      stackFrameLayers(scene, 0, resolved, applyFrameMask: false).maskGroups,
      isEmpty,
    );
  });

  test('the order and changes are saved and read back', () {
    final stack = SceneStack(
      order: [kStackFrame, stackTrackKey(StackTrackKind.image, 2)],
      changes: [
        StackChange(
          frameIndex: 7,
          order: [stackTrackKey(StackTrackKind.text, 0), kStackFrame],
        ),
      ],
      frameMask: const LayerMask(
        shape: LayerMaskShape.ellipse,
        centerX: 40,
        feather: 5,
        invert: true,
      ),
    );
    final back = SceneStack.fromJson(stack.toJson());
    expect(back.order, stack.order);
    expect(back.changes.single.frameIndex, 7);
    expect(back.changes.single.order, stack.changes.single.order);
    expect(back.frameMask, stack.frameMask);
    expect(SceneStack.fromJson(null).isEmpty, isTrue);
  });
}
