import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/engine/tone_engine.dart';
import 'package:niarim/services/tone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('組み込み全25トーンをToneService実プリセットから生成し固定座標で実描画PNG化する', () async {
    final service = ToneService();
    await service.init();
    final tones = service.tones
        .where((t) => t.id.startsWith('Tone00'))
        .toList();
    expect(tones.length, 25, reason: '現行組み込みトーン25種を漏れなく監査すること');
    expect(tones.map((t) => t.id).toSet().length, 25);

    final signatures = <String>{};
    for (final tone in tones) {
      const w = 128, h = 128, texSize = 64;
      await ensureToneTextureLoaded(tone, size: texSize);
      final texture = generateBuiltInToneTexture(tone, size: texSize);
      expect(texture.length, texSize * texSize * 4);
      final result = ToneEngine().drawToneStroke(
        points: const [ui.Offset(64, 64)],
        brushSize: 92,
        color: const ui.Color(0xFF4030B0),
        canvasData: Uint8List(w * h * 4),
        canvasWidth: w,
        canvasHeight: h,
        toneTexture: texture,
        toneWidth: texSize,
        toneHeight: texSize,
      );
      await _save(
        result,
        w,
        h,
        '${out.path}/builtin_tone_${tone.id}_${_safe(tone.name)}.png',
      );
      var painted = 0, transparentInside = 0, hash = 2166136261;
      for (var y = 22; y < 106; y++) {
        for (var x = 22; x < 106; x++) {
          if ((x - 64) * (x - 64) + (y - 64) * (y - 64) > 40 * 40) continue;
          final i = (y * w + x) * 4, a = result[i + 3];
          if (a > 0) {
            painted++;
          } else {
            transparentInside++;
          }
          hash = ((hash ^ a) * 16777619) & 0x7fffffff;
        }
      }
      expect(
        painted,
        greaterThan(10),
        reason: '${tone.name} must actually paint visible pattern pixels',
      );
      expect(
        transparentInside,
        greaterThan(0),
        reason:
            '${tone.name} must retain pattern gaps rather than become a solid fill',
      );
      signatures.add('$hash:$painted:$transparentInside');
    }
    // 濃度違いで同じ位相になるものがあっても、25種が数個の同一画像へ潰れてはいけない。
    expect(signatures.length, greaterThanOrEqualTo(15));
  });
}

String _safe(String s) =>
    s.replaceAll(RegExp(r'[^0-9A-Za-z_\-ぁ-んァ-ヶ一-龠×（）%]'), '_');
Future<void> _save(Uint8List rgba, int w, int h, String path) async {
  final b = await ui.ImmutableBuffer.fromUint8List(rgba);
  final d = ui.ImageDescriptor.raw(
    b,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final c = await d.instantiateCodec();
  final f = await c.getNextFrame();
  final png = await f.image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(png!.buffer.asUint8List());
  f.image.dispose();
  c.dispose();
  d.dispose();
  b.dispose();
}
