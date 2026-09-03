import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/models/pixel_color_mode.dart';

const _w = 320;
const _h = 180;

Uint8List _source() {
  final d = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final i = (y * _w + x) * 4;
      // Background: smooth blue/teal gradient so color filters are visible.
      d[i] = (24 + x * 90 ~/ _w).clamp(0, 255);
      d[i + 1] = (42 + y * 100 ~/ _h).clamp(0, 255);
      d[i + 2] = (110 + x * 70 ~/ _w).clamp(0, 255);
      d[i + 3] = 255;

      // Large warm subject rectangle with sharp edges.
      if (x >= 66 && x < 254 && y >= 36 && y < 145) {
        d[i] = (188 + (x - 66) * 55 ~/ 188).clamp(0, 255);
        d[i + 1] = (72 + (y - 36) * 70 ~/ 109).clamp(0, 255);
        d[i + 2] = 48;
      }

      // High-frequency black/white patch for blur/sharpen/pixelate/CRT.
      if (x >= 94 && x < 150 && y >= 62 && y < 118) {
        final v = ((x ~/ 4 + y ~/ 4).isEven) ? 238 : 18;
        d[i] = v;
        d[i + 1] = v;
        d[i + 2] = v;
      }

      // Three saturated bars for channel/color effects.
      if (x >= 172 && x < 220 && y >= 56 && y < 76) {
        d[i] = 240;
        d[i + 1] = 38;
        d[i + 2] = 44;
      }
      if (x >= 172 && x < 220 && y >= 80 && y < 100) {
        d[i] = 34;
        d[i + 1] = 220;
        d[i + 2] = 72;
      }
      if (x >= 172 && x < 220 && y >= 104 && y < 124) {
        d[i] = 40;
        d[i + 1] = 82;
        d[i + 2] = 238;
      }

      // Fine diagonal light line: distortion and chromatic aberration reference.
      final lineY = 150 - ((x - 30) * 90 ~/ 260);
      if (x >= 30 && x < 290 && (y - lineY).abs() <= 1) {
        d[i] = 246;
        d[i + 1] = 238;
        d[i + 2] = 170;
      }
    }
  }
  return d;
}

/// Outline is defined around opaque content. A fully opaque audit canvas has no useful
/// interior silhouette, so use a transparent layer containing two asymmetric subjects.
Uint8List _outlineSource() {
  final d = Uint8List(_w * _h * 4);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final inMain = x >= 72 && x < 214 && y >= 42 && y < 132;
      final dx = x - 238;
      final dy = y - 92;
      final inCircle = dx * dx + dy * dy <= 29 * 29;
      if (!inMain && !inCircle) continue;
      final i = (y * _w + x) * 4;
      if (inMain) {
        d[i] = 238;
        d[i + 1] = 126;
        d[i + 2] = 48;
      } else {
        d[i] = 58;
        d[i + 1] = 184;
        d[i + 2] = 236;
      }
      d[i + 3] = 255;
    }
  }
  return d;
}

Uint8List _mask() {
  final m = Uint8List(_w * _h * 4);
  final cx = _w / 2;
  final cy = _h / 2;
  const rx = 92.0;
  const ry = 58.0;
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final dx = (x - cx) / rx;
      final dy = (y - cy) / ry;
      if (dx * dx + dy * dy <= 1.0) {
        m[(y * _w + x) * 4 + 3] = 255;
      }
    }
  }
  return m;
}

Future<void> _save(Uint8List rgba, String path) async {
  final image = img.Image.fromBytes(
    width: _w,
    height: _h,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  await File(path).writeAsBytes(img.encodePng(image));
}

FilterDef _def(FilterKind kind) => FilterDef(
  id: 'visual_${kind.name}',
  name: kind.name,
  kind: kind,
  strength: switch (kind) {
    FilterKind.gaussianBlur => 7,
    FilterKind.lensBlur => 8,
    FilterKind.unsharpMask => 4,
    FilterKind.pixelate => 12,
    FilterKind.lensDistortion => 58,
    FilterKind.fisheye => 55,
    FilterKind.chromaticAberration => 55,
    FilterKind.noise => 35,
    FilterKind.vignette => 75,
    FilterKind.auroraHologram => 82,
    _ => 62,
  },
  colorLevels: 5,
  edgeStrength: 1.35,
  inputBlack: 28,
  inputWhite: 222,
  outputBlack: 8,
  outputWhite: 248,
  toneCurvePreset: ToneCurvePreset.highContrast,
  outlineColor: 0xFFFF2D55,
  outlineWidth: 6,
  vignetteColor: 0xFF07101E,
  caSaturation: 42,
  caBrightness: 15,
  caContrast: 28,
  monochromeColor: 0xFF72B9FF,
  thresholdValue: 126,
  lensCenterOffsetX: 8,
  lensCenterOffsetY: -4,
  pixelColorMode: PixelColorMode.explicit,
  pixelExplicitColors: const [
    0xFF111827,
    0xFFF8FAFC,
    0xFFFF4D5A,
    0xFF18C98B,
    0xFF4E7BFF,
  ],
  hologramBrightness: 12,
  hologramSaturation: 28,
  hologramPreset: AuroraHologramPreset.aurora,
  bgBlendColor: 0xFF78A9C8,
  bgBlendDirection: 35,
  bgBlendLength: 14,
  bgBlendBlur: 7,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/visual-reaudit/filters');
  setUpAll(() => out.createSync(recursive: true));

  test('全FilterKindを本番dispatcherで描画し見た目再監査用PNGを保存する', () async {
    final source = _source();
    final outlineSource = _outlineSource();
    final mask = _mask();
    await _save(source, '${out.path}/00_source.png');
    await _save(outlineSource, '${out.path}/00_outline_source.png');

    final kinds = FilterKind.values;
    for (var i = 0; i < kinds.length; i++) {
      final kind = kinds[i];
      final input = kind == FilterKind.outline ? outlineSource : source;
      final rendered = applyDrawFilterInIsolate((
        input,
        _w,
        _h,
        _def(kind),
        mask,
      ));
      expect(rendered.length, input.length, reason: '${kind.name}: RGBA size');

      // This is only a guard. Visual acceptance is done from the emitted PNG itself.
      var changed = 0;
      for (var p = 0; p < input.length; p += 4) {
        if (input[p] != rendered[p] ||
            input[p + 1] != rendered[p + 1] ||
            input[p + 2] != rendered[p + 2] ||
            input[p + 3] != rendered[p + 3]) {
          changed++;
        }
      }
      expect(
        changed,
        greaterThan(40),
        reason: '${kind.name}: visible region must exist',
      );
      await _save(
        rendered,
        '${out.path}/${(i + 1).toString().padLeft(2, '0')}_${kind.name}.png',
      );
    }

    expect(
      kinds.length,
      21,
      reason: '新しいFilterKind追加時はVisual Audit対象を自動的に増やすこと',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
