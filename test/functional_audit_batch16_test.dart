import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/engine/stamp_engine.dart';
import 'package:niarim/models/stamp.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('スタンプ不透明度25/50/100%は生成テクスチャalphaへ数値通り反映される', () async {
    final maxima = <int, int>{};
    for (final opacity in [25, 50, 100]) {
      final stamp = Stamp(id: 'opacity$opacity', name: '星', opacity: opacity);
      final tex = await generateBuiltInStampTexture(stamp, size: 64);
      final maxAlpha = _maxAlpha(tex);
      maxima[opacity] = maxAlpha;
      await _save(tex, 64, 64, '${out.path}/stamp_opacity_$opacity.png');
    }
    expect(maxima[25], inInclusiveRange(63, 65));
    expect(maxima[50], inInclusiveRange(127, 129));
    expect(maxima[100], 255);
    expect(maxima[25]!, lessThan(maxima[50]!));
    expect(maxima[50]!, lessThan(maxima[100]!));
  });

  test('50%スタンプを別ストロークで同じ場所に2回重ねると約75%になる', () async {
    const w = 120, h = 120;
    final tex = await generateBuiltInStampTexture(
      const Stamp(id: 'half', name: '星', opacity: 50),
      size: 64,
    );
    final first = StampEngine().stampAlongPath(
      canvasData: Uint8List(w * h * 4),
      width: w,
      height: h,
      texture: tex,
      texSize: 64,
      points: const [ui.Offset(60, 60)],
      stampSize: 64,
    );
    final second = StampEngine().stampAlongPath(
      canvasData: first,
      width: w,
      height: h,
      texture: tex,
      texSize: 64,
      points: const [ui.Offset(60, 60)],
      stampSize: 64,
    );
    await _save(first, w, h, '${out.path}/stamp_opacity_50_first_stroke.png');
    await _save(second, w, h, '${out.path}/stamp_opacity_50_second_stroke.png');

    final a1 = _maxAlpha(first);
    final a2 = _maxAlpha(second);
    expect(a1, inInclusiveRange(127, 129));
    // 0.5 + 0.5*(1-0.5) = 0.75 -> 191.25〜192 depending integer alpha.
    expect(a2, inInclusiveRange(190, 193));
    expect(a2, greaterThan(a1));
  });

  test('pixelMode併用時も50%不透明度が失われない', () async {
    final normal = await generateBuiltInStampTexture(
      const Stamp(id: 'normal', name: 'ハート', opacity: 50, pixelMode: false),
      size: 64,
    );
    final pixel = await generateBuiltInStampTexture(
      const Stamp(id: 'pixel', name: 'ハート', opacity: 50, pixelMode: true),
      size: 64,
    );
    await _save(normal, 64, 64, '${out.path}/stamp_opacity_50_normal.png');
    await _save(pixel, 64, 64, '${out.path}/stamp_opacity_50_pixelmode.png');

    expect(_maxAlpha(normal), inInclusiveRange(127, 129));
    expect(_maxAlpha(pixel), inInclusiveRange(127, 129));
    expect(_nonTransparentPixels(pixel), greaterThan(0));
    expect(
      pixel,
      isNot(orderedEquals(normal)),
      reason:
          'pixelMode should alter the texture geometry/color processing without resetting opacity',
    );
  });

  test('不透明度の境界値は1〜100として保持される', () {
    final low = Stamp.fromJson({'id': 'low', 'name': 'x', 'opacity': -20});
    final high = Stamp.fromJson({'id': 'high', 'name': 'x', 'opacity': 999});
    expect(low.opacity, 1);
    expect(high.opacity, 100);
  });
}

int _maxAlpha(Uint8List rgba) {
  var maxA = 0;
  for (var i = 3; i < rgba.length; i += 4) {
    maxA = math.max(maxA, rgba[i]);
  }
  return maxA;
}

int _nonTransparentPixels(Uint8List rgba) {
  var n = 0;
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] != 0) n++;
  }
  return n;
}

Future<void> _save(Uint8List rgba, int w, int h, String path) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final desc = ui.ImageDescriptor.raw(
    buffer,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await desc.instantiateCodec();
  final frame = await codec.getNextFrame();
  final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(png!.buffer.asUint8List());
  frame.image.dispose();
  codec.dispose();
  desc.dispose();
  buffer.dispose();
}
