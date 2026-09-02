import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/stamp_engine.dart';

Uint8List _drawStamp({
  required int opacity,
  int textureAlpha = 255,
  Uint8List? canvas,
}) {
  const width = 32;
  const height = 32;
  final base = canvas ?? Uint8List(width * height * 4);
  final texture = Uint8List.fromList([200, 100, 50, textureAlpha]);
  return StampEngine().stampAlongPath(
    canvasData: base,
    width: width,
    height: height,
    texture: texture,
    texSize: 1,
    points: const [ui.Offset(16, 16)],
    stampSize: 8,
    opacity: opacity,
  );
}

int _channelAt(Uint8List bytes, int channel) {
  const width = 32;
  const x = 16;
  const y = 16;
  return bytes[(y * width + x) * 4 + channel];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stamp opacity 25/50/100 changes actual rendered alpha numerically', () {
    final a25 = _channelAt(_drawStamp(opacity: 25), 3);
    final a50 = _channelAt(_drawStamp(opacity: 50), 3);
    final a100 = _channelAt(_drawStamp(opacity: 100), 3);

    expect(a25, closeTo(64, 1));
    expect(a50, closeTo(128, 1));
    expect(a100, 255);
    expect(a25, lessThan(a50));
    expect(a50, lessThan(a100));
  });

  test('two separate 50 percent stamp strokes source-over to about 75 percent', () {
    final first = _drawStamp(opacity: 50);
    final second = _drawStamp(opacity: 50, canvas: first);
    final alpha = _channelAt(second, 3);

    expect(alpha, closeTo(192, 1));
    // The stamp carries its own RGB; opacity changes alpha, not its intrinsic color.
    expect(_channelAt(second, 0), closeTo(200, 1));
    expect(_channelAt(second, 1), closeTo(100, 1));
    expect(_channelAt(second, 2), closeTo(50, 1));
  });

  test('stamp setting opacity multiplies the texture intrinsic alpha', () {
    final rendered = _drawStamp(opacity: 50, textureAlpha: 128);
    expect(_channelAt(rendered, 3), closeTo(64, 1));
  });
}
