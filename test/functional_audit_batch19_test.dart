import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/tile_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('選択変形の途中キャンセルは切り取り済み画素を全RGBA完全復元する', () async {
    const w = 96;
    const h = 80;
    const layer = 'scene#0#selection-race';
    final tm = TileManager(canvasWidth: w, canvasHeight: h);

    // 実際の選択変形に近い非対称な元画像を作る。選択内外を別色にし、
    // 透明・半透明画素も混ぜてRGBだけでなくalpha復元まで確認する。
    final initial = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        if (x >= 12 && x < 78 && y >= 10 && y < 66) {
          initial[i] = (x * 3) & 255;
          initial[i + 1] = (y * 5) & 255;
          initial[i + 2] = ((x + y) * 2) & 255;
          initial[i + 3] = ((x + y) % 7 == 0) ? 96 : 255;
        }
      }
    }
    tm.replaceLayerPixels(layer, initial);
    final before = _canvas(tm, layer, w, h);
    await _save(before, w, h, '${out.path}/selection_interrupt_before.png');

    // 投げ縄選択相当の不規則マスク。CanvasAreaは浮動画像生成前に、
    // このmask内の元レイヤー画素を透明化する。
    final polygon = <ui.Offset>[
      const ui.Offset(19, 17),
      const ui.Offset(67, 13),
      const ui.Offset(76, 38),
      const ui.Offset(59, 61),
      const ui.Offset(28, 57),
      const ui.Offset(14, 34),
    ];

    tm.beginUndoRecording(layer);
    var cleared = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (!_inside(ui.Offset(x + 0.5, y + 0.5), polygon)) continue;
        final tx = x ~/ TileManager.tileSize;
        final ty = y ~/ TileManager.tileSize;
        final tile = tm.getOrCreateTile(layer, tx, ty);
        final lx = x % TileManager.tileSize;
        final ly = y % TileManager.tileSize;
        final idx = (ly * TileManager.tileSize + lx) * 4;
        if (tile[idx + 3] != 0) cleared++;
        tm.setPixel(tile, lx, ly, 0, 0, 0, 0);
        tm.markDirty(layer, tx, ty);
      }
    }
    expect(cleared, greaterThan(500));
    final cut = _canvas(tm, layer, w, h);
    expect(cut, isNot(orderedEquals(before)));
    await _save(cut, w, h, '${out.path}/selection_interrupt_cut.png');

    // 高速pointer-up・フレーム切替・ツール離脱など、変形確定前のキャンセル。
    tm.cancelUndoRecordingAndRestore();
    final restored = _canvas(tm, layer, w, h);
    expect(
      restored,
      orderedEquals(before),
      reason: '選択変形が成立しなかった場合、切り取った領域も含め全byteが操作前へ戻ること',
    );
    await _save(restored, w, h, '${out.path}/selection_interrupt_restored.png');
  });

  test('空レイヤーに途中生成したタイルもキャンセル時は完全に消える', () {
    const layer = 'new-tile';
    final tm = TileManager(canvasWidth: 64, canvasHeight: 64);
    expect(tm.hasLayer(layer), isFalse);

    tm.beginUndoRecording(layer);
    final tile = tm.getOrCreateTile(layer, 0, 0);
    tm.setPixel(tile, 11, 17, 20, 40, 60, 200);
    tm.markDirty(layer, 0, 0);
    expect(tm.hasLayer(layer), isTrue);

    tm.cancelUndoRecordingAndRestore();
    expect(
      tm.hasLayer(layer),
      isFalse,
      reason: '操作前に存在しなかったタイルはキャンセルでnullスナップショットへ戻ること',
    );
  });
}

Uint8List _canvas(TileManager tm, String layer, int w, int h) {
  final result = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final tile = tm.getTile(
        layer,
        x ~/ TileManager.tileSize,
        y ~/ TileManager.tileSize,
      );
      if (tile == null) continue;
      final lx = x % TileManager.tileSize;
      final ly = y % TileManager.tileSize;
      final src = (ly * TileManager.tileSize + lx) * 4;
      final dst = (y * w + x) * 4;
      result[dst] = tile[src];
      result[dst + 1] = tile[src + 1];
      result[dst + 2] = tile[src + 2];
      result[dst + 3] = tile[src + 3];
    }
  }
  return result;
}

bool _inside(ui.Offset p, List<ui.Offset> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final pi = poly[i];
    final pj = poly[j];
    final intersects =
        ((pi.dy > p.dy) != (pj.dy > p.dy)) &&
        (p.dx <
            (pj.dx - pi.dx) *
                    (p.dy - pi.dy) /
                    ((pj.dy - pi.dy).abs() < 1e-12 ? 1e-12 : pj.dy - pi.dy) +
                pi.dx);
    if (intersects) inside = !inside;
  }
  return inside;
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
