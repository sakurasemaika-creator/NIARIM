import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/engine/stamp_engine.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('組み込み全7スタンプをStampService実プリセットから生成し実キャンバスへ1個ずつ配置する', () async {
    final service = StampService();
    await service.init();
    final stamps = service.stamps;
    expect(stamps.length, 7);
    expect(stamps.map((s) => s.id).toSet(), {
      'Stamp0001',
      'Stamp0002',
      'Stamp0003',
      'Stamp0004',
      'Stamp0005',
      'Stamp0006',
      'Stamp0007',
    });
    final signatures = <String>{};
    for (final stamp in stamps) {
      const w = 128, h = 128, size = 72;
      final tex = await generateBuiltInStampTexture(stamp, size: size);
      final result = StampEngine().stampAlongPath(
        canvasData: Uint8List(w * h * 4),
        width: w,
        height: h,
        texture: tex,
        texSize: size,
        points: const [ui.Offset(64, 64)],
        stampSize: size.toDouble(),
      );
      await _save(
        result,
        w,
        h,
        '${out.path}/builtin_stamp_${stamp.id}_${stamp.name}.png',
      );
      var opaque = 0, hash = 2166136261;
      for (var i = 0; i < result.length; i += 4) {
        final a = result[i + 3];
        if (a > 0) opaque++;
        hash = ((hash ^ result[i]) * 16777619) & 0x7fffffff;
        hash = ((hash ^ result[i + 1]) * 16777619) & 0x7fffffff;
        hash = ((hash ^ result[i + 2]) * 16777619) & 0x7fffffff;
        hash = ((hash ^ a) * 16777619) & 0x7fffffff;
      }
      expect(opaque, greaterThan(40), reason: '${stamp.name}が実際に可視形状を生成すること');
      signatures.add('$hash:$opaque');
    }
    expect(
      signatures.length,
      7,
      reason: '7種類の組み込みスタンプが同じ形状へ潰れず全て異なる実画素出力を持つこと',
    );
  });
}

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
