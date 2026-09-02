import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/stamp_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('スタンプ90度折れ線：同じ幾何形状なら疎入力と密入力で画素完全一致', () async {
    const w = 220, h = 220;
    final tex = _texture(7);
    const sparsePoints = <ui.Offset>[
      ui.Offset(25, 55),
      ui.Offset(165, 55),
      ui.Offset(165, 190),
    ];
    final densePoints = <ui.Offset>[
      ...List.generate(21, (i) => ui.Offset(25 + 140 * i / 20, 55)),
      ...List.generate(20, (i) => ui.Offset(165, 55 + 135 * (i + 1) / 20)),
    ];

    final sparse = StampEngine().stampAlongPath(
      canvasData: Uint8List(w * h * 4), width: w, height: h,
      texture: tex, texSize: 7, points: sparsePoints,
      stampSize: 18, density: 1.4, rotation: true,
    );
    final dense = StampEngine().stampAlongPath(
      canvasData: Uint8List(w * h * 4), width: w, height: h,
      texture: tex, texSize: 7, points: densePoints,
      stampSize: 18, density: 1.4, rotation: true,
    );
    await _save(sparse, w, h, '${out.path}/stamp_corner_sparse.png');
    await _save(dense, w, h, '${out.path}/stamp_corner_dense.png');

    expect(sparse, orderedEquals(dense),
        reason: 'same L-shaped path must not change with pointer event subdivision');
  });

  test('スタンプ散布付き折れ線：seed固定なら疎入力と密入力で画素完全一致', () async {
    const w = 260, h = 240;
    final tex = _texture(5);
    const sparsePoints = <ui.Offset>[
      ui.Offset(30, 70),
      ui.Offset(190, 70),
      ui.Offset(190, 205),
    ];
    final densePoints = <ui.Offset>[
      ...List.generate(33, (i) => ui.Offset(30 + 160 * i / 32, 70)),
      ...List.generate(27, (i) => ui.Offset(190, 70 + 135 * (i + 1) / 27)),
    ];

    final sparse = StampEngine().stampAlongPath(
      canvasData: Uint8List(w * h * 4), width: w, height: h,
      texture: tex, texSize: 5, points: sparsePoints,
      stampSize: 14, density: 0.9, rotation: false, scatter: 18, seed: 77,
    );
    final dense = StampEngine().stampAlongPath(
      canvasData: Uint8List(w * h * 4), width: w, height: h,
      texture: tex, texSize: 5, points: densePoints,
      stampSize: 14, density: 0.9, rotation: false, scatter: 18, seed: 77,
    );
    await _save(sparse, w, h, '${out.path}/stamp_corner_scatter_sparse.png');
    await _save(dense, w, h, '${out.path}/stamp_corner_scatter_dense.png');

    expect(sparse, orderedEquals(dense),
        reason: 'scatter RNG sequence and path normals must also be event-density invariant');
  });

  test('旧CanvasArea型の事前間引きは短い折れ返しを消すため使用してはいけない', () {
    // 実際のCanvasAreaに残っている「lastからspacing未満なら点を捨てる」方式を
    // 再現する。短いジグザグでは進行方向を表す重要な中間点が消えることを
    // 明示し、StampEngineへは生のストローク点列を渡すべきことを回帰条件にする。
    const raw = <ui.Offset>[
      ui.Offset(20, 100),
      ui.Offset(28, 90),
      ui.Offset(36, 100),
      ui.Offset(44, 90),
      ui.Offset(52, 100),
    ];
    const spacing = 18.0;
    final legacySampled = <ui.Offset>[];
    ui.Offset? last;
    for (final p in raw) {
      if (last == null || (p - last).distance >= spacing) {
        legacySampled.add(p);
        last = p;
      }
    }
    expect(legacySampled.length, lessThan(raw.length),
        reason: 'this demonstrates why pre-sampling before StampEngine loses geometry');
    expect(legacySampled, isNot(orderedEquals(raw)));
  });
}

Uint8List _texture(int size) {
  final d = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final i = (y * size + x) * 4;
      d[i] = x > size ~/ 2 ? 30 : 230;
      d[i + 1] = y > size ~/ 2 ? 180 : 50;
      d[i + 2] = 70;
      d[i + 3] = 180;
    }
  }
  return d;
}

Future<void> _save(Uint8List rgba, int w, int h, String path) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final desc = ui.ImageDescriptor.raw(
    buffer, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await desc.instantiateCodec();
  final frame = await codec.getNextFrame();
  final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(png!.buffer.asUint8List());
  frame.image.dispose(); codec.dispose(); desc.dispose(); buffer.dispose();
}
