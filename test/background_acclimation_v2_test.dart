import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:niarim/engine/background_acclimation_engine.dart';
import 'package:niarim/models/filter_def.dart';

const w = 128;
const h = 96;

Uint8List subject() {
  final d = Uint8List(w * h * 4);
  for (var y = 18; y < 84; y++) {
    for (var x = 38; x < 90; x++) {
      final i = (y * w + x) * 4;
      d[i] = 185;
      d[i + 1] = 155;
      d[i + 2] = 135;
      d[i + 3] = 255;
    }
  }
  return d;
}

Uint8List background(String name) {
  final d = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      int r;
      int g;
      int b;
      switch (name) {
        case 'sky_grass':
          if (y < h * .62) {
            r = 120;
            g = 190;
            b = 250;
          } else {
            r = 70;
            g = 145;
            b = 65;
          }
          break;
        case 'sunset':
          if (y < h * .52) {
            r = 245;
            g = 125;
            b = 55;
          } else {
            r = 95;
            g = 45;
            b = 105;
          }
          break;
        case 'warm_room':
          r = x < w * .7 ? 225 : 150;
          g = x < w * .7 ? 180 : 110;
          b = x < w * .7 ? 115 : 80;
          break;
        case 'neon_night':
          if (x < w / 2) {
            r = 245;
            g = 40;
            b = 180;
          } else {
            r = 25;
            g = 190;
            b = 245;
          }
          break;
        case 'overcast':
          r = 165;
          g = 175;
          b = 185;
          break;
        case 'snow':
          r = y < h * .7 ? 185 : 235;
          g = y < h * .7 ? 210 : 240;
          b = y < h * .7 ? 235 : 245;
          break;
        case 'forest':
          r = 45 + (x % 24);
          g = 105 + (y % 40);
          b = 55;
          break;
        case 'mixed_temperature':
          if (x < w / 2) {
            r = 245;
            g = 190;
            b = 110;
          } else {
            r = 75;
            g = 135;
            b = 235;
          }
          break;
        default:
          r = 128;
          g = 128;
          b = 128;
      }
      final i = (y * w + x) * 4;
      d[i] = r;
      d[i + 1] = g;
      d[i + 2] = b;
      d[i + 3] = 255;
    }
  }
  return d;
}

void writeEvidence(String name, Uint8List bg, Uint8List out) {
  final image = img.Image(width: w, height: h, numChannels: 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final a = out[i + 3] / 255.0;
      final r = (out[i] * a + bg[i] * (1 - a)).round();
      final g = (out[i + 1] * a + bg[i + 1] * (1 - a)).round();
      final b = (out[i + 2] * a + bg[i + 2] * (1 - a)).round();
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }
  final dir = Directory('build/background-acclimation-v2')
    ..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(img.encodePng(image));
}

void main() {
  const base = FilterDef(
    id: 'bg-v2',
    name: '背景馴染ませ',
    kind: FilterKind.backgroundBlend,
  );
  const environments = [
    'sky_grass',
    'sunset',
    'warm_room',
    'neon_night',
    'overcast',
    'snow',
    'forest',
    'mixed_temperature',
  ];

  test('8環境で背景解析し、アルファを壊さず環境へ追従したPNGを生成する', () {
    final src = subject();
    final signatures = <String>{};
    for (final name in environments) {
      final bg = background(name);
      final analysis = BackgroundAcclimationEngine.analyze(src, bg, w, h, base);
      final out = BackgroundAcclimationEngine.apply(
        src,
        bg,
        w,
        h,
        base,
        analysis: analysis,
      );
      var changed = 0;
      for (var i = 0; i < src.length; i += 4) {
        expect(out[i + 3], src[i + 3]);
        if (out[i] != src[i] ||
            out[i + 1] != src[i + 1] ||
            out[i + 2] != src[i + 2]) {
          changed++;
        }
      }
      expect(changed, greaterThan(100), reason: name);
      signatures.add(
        '${analysis.primaryColor}:${analysis.ambientColor}:'
        '${analysis.shadowColor}:${analysis.reflectionColor}',
      );
      writeEvidence(name, bg, out);
    }
    expect(signatures.length, greaterThanOrEqualTo(6));
  });

  test('手動光源方向は自動推定を上書きする', () {
    final f = base.copyWith(bgBlendAutoLight: false, bgBlendDirection: 123);
    final a = BackgroundAcclimationEngine.analyze(
      subject(),
      background('sky_grass'),
      w,
      h,
      f,
    );
    expect(a.primaryDirectionDegrees, 123);
  });

  test('ネオン環境では有色光を解析できる', () {
    final a = BackgroundAcclimationEngine.analyze(
      subject(),
      background('neon_night'),
      w,
      h,
      base,
    );
    expect(a.primaryColor, isNot(0xFF808080));
    expect(a.confidence, inInclusiveRange(0.0, 1.0));
  });

  test('旧保存データ相当でもv2既定値へ安全に移行する', () {
    final restored = FilterDef.fromJson({
      'id': 'legacy',
      'name': '背景馴染ませ',
      'kind': 'backgroundBlend',
      'bgBlendColor': -1,
      'bgBlendDirection': 315,
      'bgBlendLength': 20,
      'bgBlendBlur': 6,
    });
    expect(restored.bgBlendAutoLight, isTrue);
    expect(restored.bgBlendMaterialProtection, 75);
    expect(restored.bgBlendAmbientColor, -1);
  });
}
