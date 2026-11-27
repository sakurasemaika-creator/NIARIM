import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/engine/stamp_engine.dart';
import 'package:niarim/models/stamp.dart';
import 'package:niarim/services/stamp_service.dart';
import 'package:niarim/utils/creative_image_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// スタンプは描く大きさに合わせてなめらかに描く。
///
/// 以前はキャンバスの1画素ごとに一番近いテクセルを1つ写すだけで、128pxの
/// テクスチャを小さく描くと細い所（キラキラの光の筋）が点線に切れ、大きく
/// 描くと128pxの画像を引き伸ばした段（角のギザギザ）が出た。今は小さく描く
/// ときはテクスチャを描く大きさまで面積で平均してから、画素の中心で
/// バイリニアに読む。組み込みの図形は描く大きさで形から描き直す。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Uint8List texture(int size, bool Function(int x, int y) ink) {
    final data = Uint8List(size * size * 4);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (ink(x, y)) data[(y * size + x) * 4 + 3] = 255;
      }
    }
    return data;
  }

  Uint8List draw(
    Uint8List tex,
    int texSize,
    double stampSize, {
    int canvas = 96,
    bool smooth = true,
    ui.Offset? at,
  }) => StampEngine().stampAlongPath(
    canvasData: Uint8List(canvas * canvas * 4),
    width: canvas,
    height: canvas,
    texture: tex,
    texSize: texSize,
    points: [at ?? ui.Offset(canvas / 2, canvas / 2)],
    stampSize: stampSize,
    premultiplied: true,
    smooth: smooth,
  );

  int alphaAt(Uint8List rgba, int width, int x, int y) =>
      rgba[(y * width + x) * 4 + 3];

  test('小さく描いても細い線が点線に切れず、インクの量が保たれる', () {
    // A 4-texel vertical bar in a 128 texture drawn at 16px is half a pixel
    // wide: picking the nearest texel draws it in some rows and not others.
    const size = 128;
    final bar = texture(size, (x, y) => x >= 62 && x < 66 && y >= 8 && y < 120);
    final smooth = draw(bar, size, 16, at: const ui.Offset(48.3, 48.2));
    var ink = 0;
    for (var y = 42; y < 55; y++) {
      var row = 0;
      for (var x = 0; x < 96; x++) {
        row += alphaAt(smooth, 96, x, y);
      }
      expect(row, greaterThan(0), reason: 'row $y is empty');
      ink += row;
    }
    // Area of the bar at the drawn size: 0.5 px × 14 px = 7 px of ink.
    final expected = 4 * 112 / (size * size) * 16 * 16 * 255;
    var total = 0;
    for (var i = 3; i < smooth.length; i += 4) {
      total += smooth[i];
    }
    expect(total, closeTo(expected, expected * 0.1));
    expect(ink, greaterThan(0));
  });

  test('大きく描いた斜めの縁は段にならない', () {
    // A 16-texel texture drawn at 256px: each texel is 16 canvas pixels.
    const size = 16;
    final half = texture(size, (x, y) => x > y);
    const canvas = 300;
    final smooth = draw(half, size, 256, canvas: canvas);
    final nearest = draw(half, size, 256, canvas: canvas, smooth: false);
    int? edge(Uint8List rgba, int y) {
      for (var x = 30; x < 270; x++) {
        if (alphaAt(rgba, canvas, x, y) >= 128) return x;
      }
      return null;
    }

    int largestJump(Uint8List rgba) {
      var largest = 0;
      int? previous;
      for (var y = 40; y < 260; y++) {
        final x = edge(rgba, y);
        if (x == null) continue;
        if (previous != null && (x - previous).abs() > largest) {
          largest = (x - previous).abs();
        }
        previous = x;
      }
      return largest;
    }

    expect(largestJump(nearest), greaterThanOrEqualTo(15));
    expect(largestJump(smooth), lessThanOrEqualTo(2));
  });

  test('ドット絵のスタンプ（smooth: false）は今までどおり一番近いテクセル', () {
    const size = 8;
    final checker = texture(size, (x, y) => (x + y).isEven);
    final rgba = draw(checker, size, 32, smooth: false);
    for (var i = 3; i < rgba.length; i += 4) {
      expect(rgba[i] == 0 || rgba[i] == 255, isTrue);
    }
  });

  test('不透明度と色は乗算済みのまま正しく重なる', () {
    final solid = Uint8List.fromList([200, 100, 50, 255]);
    final once = StampEngine().stampAlongPath(
      canvasData: Uint8List(32 * 32 * 4),
      width: 32,
      height: 32,
      texture: solid,
      texSize: 1,
      points: const [ui.Offset(16, 16)],
      stampSize: 8,
      opacity: 50,
      premultiplied: true,
    );
    final i = (16 * 32 + 16) * 4;
    expect(once[i + 3], closeTo(128, 1));
    expect(once[i], closeTo(100, 1));
    expect(once[i + 1], closeTo(50, 1));
  });

  test('描く大きさに合うテクスチャの大きさ', () {
    const shape = Stamp(id: 's', name: '星');
    expect(stampTextureSizeFor(shape, 20), baseStampTextureSize);
    expect(stampTextureSizeFor(shape, 300), 300);
    expect(stampTextureSizeFor(shape, 5000), maxStampTextureSize);
    expect(
      stampTextureSizeFor(shape.copyWith(pixelMode: true), 300),
      baseStampTextureSize,
    );
  });

  testWidgets('組み込みの画像は形を128pxで描いたもので、大きく描くときは形から描き直す', (tester) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({});
      final service = StampService();
      await service.init();
      final bundled = {
        for (final stamp in service.stamps)
          if (stamp.imagePath?.startsWith('assets/stamps/') ?? false)
            RegExp(r'Stamp\d+').firstMatch(stamp.imagePath!)![0]!,
      };
      expect(bundled, isNotEmpty);
      for (final id in bundled) {
        final shape = builtInStampShapes[id];
        expect(shape, isNotNull, reason: '$id has no shape to redraw');
        // The bundled image and the shape drawn at the same size agree.
        final png = await readCreativeImageSource('assets/stamps/$id.png');
        expect(png, isNotNull, reason: id);
        final drawn = await generateBuiltInStampTexture(
          Stamp(id: 'copy', name: 'copy', imagePath: 'assets/stamps/$id.png'),
        );
        final decoded = await _decode(png!);
        var worst = 0;
        for (var i = 0; i < drawn.length; i++) {
          final d = (drawn[i] - decoded[i]).abs();
          if (d > worst) worst = d;
        }
        expect(worst, lessThanOrEqualTo(1), reason: id);
      }
      // A renamed copy keeps the bundled shape: it is chosen by the image.
      final big = await generateBuiltInStampTexture(
        const Stamp(
          id: 'mine',
          name: '自分の星',
          imagePath: 'assets/stamps/Stamp0004.png',
        ),
        size: 400,
      );
      final star = await generateBuiltInStampTexture(
        const Stamp(id: 'Stamp0004', name: '星'),
        size: 400,
      );
      expect(big, star);
      service.dispose();
    });
  });
}

Future<Uint8List> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  codec.dispose();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  frame.image.dispose();
  return data!.buffer.asUint8List();
}
