// タイムラインの重なり順（ユーザー指定「テキスト1とテキスト2の間にフレームの
// イラストを表示させる」「レイヤー順を細かくフレームごと、シーンごとに
// 変えられる」）：既定の順番、シーンの順番、「フレーム指定」の範囲、
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

  test('a frame range (F4〜F5) has its own order, the rest the scene\'s', () {
    final scene = Scene(
      id: 's',
      index: 0,
      stack: SceneStack(
        ranges: [
          StackRange(
            start: 3,
            end: 4,
            order: [stackTrackKey(StackTrackKind.video, 0), kStackFrame],
          ),
        ],
      ),
    );
    List<String> at(int frame) =>
        _ids(stackFrameLayers(scene, frame, resolved));
    expect(at(2).last, 'video');
    expect(at(3).first, 'text1');
    expect(at(3).indexOf('video'), lessThan(at(3).indexOf('lines')));
    expect(at(4).indexOf('video'), lessThan(at(4).indexOf('lines')));
    // After the range, the scene's (default) order again.
    expect(at(5).last, 'video');
  });

  test('saved 「このフレームから」 changes are read as frame ranges', () {
    final stack = SceneStack.fromJson({
      'changes': [
        {
          'frameIndex': 3,
          'order': ['video:0', 'frame'],
        },
        {'frameIndex': 5, 'order': <String>[]},
        {
          'frameIndex': 8,
          'order': ['frame', 'text:0'],
        },
      ],
    });
    expect(stack.ranges, hasLength(2));
    expect([stack.ranges[0].start, stack.ranges[0].end], [3, 4]);
    expect(stack.ranges[0].order, ['video:0', 'frame']);
    // The last change lasted to the end of the scene.
    expect(stack.ranges[1].start, 8);
    expect(stack.ranges[1].contains(500), isTrue);
    expect(stack.chosenOrderAt(6), isEmpty);
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
      ranges: [
        StackRange(
          start: 7,
          end: 9,
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
    expect(back.ranges.single.start, 7);
    expect(back.ranges.single.end, 9);
    expect(back.ranges.single.order, stack.ranges.single.order);
    expect(back.frameMask, stack.frameMask);
    expect(SceneStack.fromJson(null).isEmpty, isTrue);
  });

  group('moving several picked items together', () {
    const order = ['a', 'b', 'c', 'd', 'e'];

    test('one step: each passes its unpicked neighbour, runs move as one', () {
      expect(stepStackSelection(order, {'c', 'e'}, forward: true), [
        'a',
        'c',
        'b',
        'e',
        'd',
      ]);
      expect(stepStackSelection(order, {'c', 'd'}, forward: true), [
        'a',
        'c',
        'd',
        'b',
        'e',
      ]);
      // Already at the front: it stays, the other one still moves.
      expect(stepStackSelection(order, {'a', 'd'}, forward: true), [
        'a',
        'b',
        'd',
        'c',
        'e',
      ]);
      expect(stepStackSelection(order, {'a', 'c'}, forward: false), [
        'b',
        'a',
        'd',
        'c',
        'e',
      ]);
      // A run at the back stays where it is.
      expect(stepStackSelection(order, {'d', 'e'}, forward: false), order);
      // One item is a plain swap.
      expect(stepStackSelection(order, {'b'}, forward: true), [
        'b',
        'a',
        'c',
        'd',
        'e',
      ]);
    });

    test('to the front or back, keeping their own order', () {
      expect(stackSelectionToEnd(order, {'d', 'b'}, front: true), [
        'b',
        'd',
        'a',
        'c',
        'e',
      ]);
      expect(stackSelectionToEnd(order, {'d', 'b'}, front: false), [
        'a',
        'c',
        'e',
        'b',
        'd',
      ]);
    });

    test('dragging a picked item brings the others along', () {
      // b (picked with d) dragged to the back: d follows it.
      expect(dragStackSelection(order, {'b', 'd'}, 1, 4), [
        'a',
        'c',
        'e',
        'b',
        'd',
      ]);
      // d dragged to the front: b gathers in front of it (its own order).
      expect(dragStackSelection(order, {'b', 'd'}, 3, 0), [
        'b',
        'd',
        'a',
        'c',
        'e',
      ]);
      // An unpicked item moves on its own.
      expect(dragStackSelection(order, {'b', 'd'}, 4, 0), [
        'e',
        'a',
        'b',
        'c',
        'd',
      ]);
    });
  });
}
