// マスクとX/Y軸回転の描画：素材のマスク（四角・楕円・反転・ぼかし）は
// 素材の内側だけを見せ、フレーム（イラスト）のマスクは描画レイヤーを
// まとめて隠す。X軸・Y軸回転は奥行きのある変形になる（Y軸回転で幅が縮む）。
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/engine/layer_keyframe_engine.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/engine/timeline_stack.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/layer_keyframe.dart';
import 'package:niarim/models/layer_mask.dart';

const _size = 100;

Uint8List _fill(int argb, {int left = 0, int top = 0, int right = 100}) {
  final data = Uint8List(_size * _size * 4);
  for (var y = top; y < _size; y++) {
    for (var x = left; x < right; x++) {
      final i = (y * _size + x) * 4;
      data[i] = argb >> 16 & 0xFF;
      data[i + 1] = argb >> 8 & 0xFF;
      data[i + 2] = argb & 0xFF;
      data[i + 3] = argb >>> 24;
    }
  }
  return data;
}

String _key(String id) => frameLayerKey('s', 0, id);

Future<Uint8List> _render(
  TileManager tiles,
  List<Layer> layers, {
  List<LayerMaskGroup> maskGroups = const [],
}) async {
  final engine = LayerKeyframeEngine();
  final image = await LayerCompositor.composite(
    tiles,
    layers,
    (l) => _key(l.id),
    _size,
    _size,
    keyframeOf: (l) =>
        l.keyframes.isEmpty ? null : engine.valueAt(l.keyframes, 0),
    maskGroups: maskGroups,
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

int _alpha(Uint8List rgba, int x, int y) => rgba[(y * _size + x) * 4 + 3];

void main() {
  testWidgets('a material mask shows only inside (or outside) its shape', (
    tester,
  ) async {
    final tiles = TileManager(canvasWidth: _size, canvasHeight: _size);
    tiles.replaceLayerPixels(_key('t'), _fill(0xFF2040E0));
    Layer text(LayerMask mask) =>
        Layer(id: 't', name: 't', type: LayerType.timelineText, mask: mask);

    final ellipse = (await tester.runAsync(
      () => _render(tiles, [
        text(
          const LayerMask(shape: LayerMaskShape.ellipse, width: 50, height: 50),
        ),
      ]),
    ))!;
    expect(_alpha(ellipse, 50, 50), 255);
    expect(_alpha(ellipse, 5, 5), 0);
    // An ellipse, not its bounding box: the box's corner is outside.
    expect(_alpha(ellipse, 28, 28), 0);
    expect(_alpha(ellipse, 50, 27), 255);

    final inverted = (await tester.runAsync(
      () => _render(tiles, [
        text(const LayerMask(width: 40, height: 40, invert: true)),
      ]),
    ))!;
    expect(_alpha(inverted, 50, 50), 0);
    expect(_alpha(inverted, 5, 5), 255);

    final feathered = (await tester.runAsync(
      () => _render(tiles, [
        text(const LayerMask(width: 50, height: 50, feather: 10)),
      ]),
    ))!;
    // Soft across the edge (x 25): partly visible either side.
    final atEdge = _alpha(feathered, 25, 50);
    expect(atEdge, inExclusiveRange(40, 215));
    expect(_alpha(feathered, 50, 50), 255);
  });

  testWidgets('the frame mask hides the drawing layers together', (
    tester,
  ) async {
    final tiles = TileManager(canvasWidth: _size, canvasHeight: _size);
    tiles.replaceLayerPixels(_key('a'), _fill(0xFFE03030, right: 50));
    tiles.replaceLayerPixels(_key('b'), _fill(0xFF30C040, left: 50));
    tiles.replaceLayerPixels(_key('t'), _fill(0xFF2040E0, top: 90));
    const a = Layer(id: 'a', name: 'a', type: LayerType.normal);
    const b = Layer(id: 'b', name: 'b', type: LayerType.normal);
    const t = Layer(id: 't', name: 't', type: LayerType.timelineText);
    final rgba = (await tester.runAsync(
      () => _render(
        tiles,
        [t, a, b],
        maskGroups: const [
          LayerMaskGroup(
            layerIds: {'a', 'b'},
            mask: LayerMask(centerY: 25, width: 100, height: 50),
          ),
        ],
      ),
    ))!;
    // The top half of the drawing shows, the bottom half is hidden...
    expect(_alpha(rgba, 20, 20), 255);
    expect(_alpha(rgba, 80, 20), 255);
    expect(_alpha(rgba, 20, 70), 0);
    // ...but not the text in front of it, which is outside the group.
    expect(_alpha(rgba, 20, 95), 255);
  });

  testWidgets('turning about the Y axis narrows the layer in perspective', (
    tester,
  ) async {
    final tiles = TileManager(canvasWidth: _size, canvasHeight: _size);
    tiles.replaceLayerPixels(_key('t'), _fill(0xFF2040E0, left: 30, right: 70));
    Layer turned(double y) => Layer(
      id: 't',
      name: 't',
      type: LayerType.timelineText,
      keyframes: [LayerKeyframe(frameIndex: 0, rotationY: y)],
    );
    int width(Uint8List rgba) {
      var count = 0;
      for (var x = 0; x < _size; x++) {
        if (_alpha(rgba, x, 50) > 128) count++;
      }
      return count;
    }

    final flat = (await tester.runAsync(() => _render(tiles, [turned(0)])))!;
    final turnedImage = (await tester.runAsync(
      () => _render(tiles, [turned(60)]),
    ))!;
    expect(width(flat), closeTo(40, 1));
    // cos 60° = 0.5: about half as wide, a little more for the near side.
    expect(width(turnedImage), inInclusiveRange(18, 26));
    // Perspective: the receding right side is shorter than the near left.
    int height(Uint8List rgba, int x) {
      var count = 0;
      for (var y = 0; y < _size; y++) {
        if (_alpha(rgba, x, y) > 128) count++;
      }
      return count;
    }

    var left = -1, right = -1;
    for (var x = 0; x < _size; x++) {
      if (_alpha(turnedImage, x, 50) > 128) {
        if (left < 0) left = x;
        right = x;
      }
    }
    expect(
      height(turnedImage, left + 1),
      greaterThan(height(turnedImage, right - 1)),
    );
  });
}
