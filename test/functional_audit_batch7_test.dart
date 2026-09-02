import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/onion_skin.dart';
import 'package:niarim/engine/procedural_texture.dart';
import 'package:niarim/engine/undo_manager.dart';
import 'package:niarim/models/onion_skin_settings.dart';
import 'package:niarim/models/stamp.dart';
import 'package:niarim/models/tone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('オニオンスキン：表示枚数・間隔・前後ON/OFFが正しく反映', () {
    final engine = OnionSkinEngine();
    const settings = OnionSkinSettings(
      enabled: true,
      showPrev: true,
      showNext: true,
      prevFrames: 2,
      nextFrames: 3,
      frameInterval: 2,
      fadeByDistance: false,
    );
    expect(engine.getVisibleFrameOffsets(settings), equals([-2, -4, 2, 4, 6]));
    expect(engine.getOpacityForFrame(settings, -1), 0);
    expect(engine.getOpacityForFrame(settings, -2), closeTo(settings.prevOpacity, 1e-9));
    expect(engine.getOpacityForFrame(settings, 6), closeTo(settings.nextOpacity, 1e-9));
    expect(engine.getOpacityForFrame(settings, 8), 0);

    final prevOnly = settings.copyWith(showNext: false);
    expect(engine.getVisibleFrameOffsets(prevOnly), equals([-2, -4]));
    expect(engine.getOpacityForFrame(prevOnly, 2), 0);
  });

  test('オニオンスキン：距離減衰は遠いフレームほど薄い', () {
    final engine = OnionSkinEngine();
    const settings = OnionSkinSettings(
      enabled: true,
      prevFrames: 4,
      nextFrames: 4,
      frameInterval: 1,
      prevOpacity: 0.5,
      nextOpacity: 0.4,
      fadeByDistance: true,
    );
    final p1 = engine.getOpacityForFrame(settings, -1);
    final p4 = engine.getOpacityForFrame(settings, -4);
    final n1 = engine.getOpacityForFrame(settings, 1);
    final n4 = engine.getOpacityForFrame(settings, 4);
    expect(p1, greaterThan(p4));
    expect(n1, greaterThan(n4));
    expect(p1, closeTo(0.5, 1e-9));
    expect(p4, closeTo(0.2, 1e-9));
    expect(engine.getColorForFrame(settings, -1), settings.prevColor);
    expect(engine.getColorForFrame(settings, 1), settings.nextColor);
  });

  test('組み込みトーン：市松・格子・散らしが仕様どおりの周期', () async {
    const size = 16;
    final checker = generateBuiltInToneTexture(const Tone(id: 'c', name: '市松'), size: size);
    final grid = generateBuiltInToneTexture(const Tone(id: 'g', name: '格子'), size: size);
    final scatter = generateBuiltInToneTexture(const Tone(id: 's', name: '散らし'), size: size);

    expect(_alpha(checker, size, 0, 0), 255);
    expect(_alpha(checker, size, 1, 0), 0);
    expect(_alpha(checker, size, 1, 1), 255);

    expect(_alpha(grid, size, 0, 1), 255);
    expect(_alpha(grid, size, 1, 0), 255);
    expect(_alpha(grid, size, 1, 1), 0);

    expect(_alpha(scatter, size, 0, 0), 255);
    expect(_alpha(scatter, size, 1, 0), 0);
    expect(_alpha(scatter, size, 0, 1), 0);
    expect(_alpha(scatter, size, 2, 2), 255);

    await _saveRgba(checker, size, size, '${out.path}/tone_builtin_checker.png');
    await _saveRgba(grid, size, size, '${out.path}/tone_builtin_grid.png');
    await _saveRgba(scatter, size, size, '${out.path}/tone_builtin_scatter.png');
  });

  test('組み込みトーン：ディザ密度は指定%に概ね一致し粗密で周期が変わる', () async {
    const size = 32;
    final fine = generateBuiltInToneTexture(const Tone(id: 'd1', name: 'ピクセルディザ50%'), size: size);
    final coarse = generateBuiltInToneTexture(const Tone(id: 'd2', name: 'ピクセルディザ50%粗'), size: size);
    final fineRatio = _opaqueRatio(fine);
    final coarseRatio = _opaqueRatio(coarse);
    expect(fineRatio, closeTo(0.5, 0.03));
    expect(coarseRatio, closeTo(0.5, 0.03));
    expect(fine, isNot(equals(coarse)));
    await _saveRgba(fine, size, size, '${out.path}/tone_builtin_dither50.png');
    await _saveRgba(coarse, size, size, '${out.path}/tone_builtin_dither50_coarse.png');
  });

  test('組み込みトーン：網点%が高いほどインク密度が増える', () {
    const size = 64;
    final low = generateBuiltInToneTexture(const Tone(id: 'a', name: '網点20%'), size: size);
    final high = generateBuiltInToneTexture(const Tone(id: 'b', name: '網点80%'), size: size);
    expect(_opaqueRatio(high), greaterThan(_opaqueRatio(low)));
  });

  test('組み込みスタンプ：代表形状をRGBAテクスチャとして生成', () async {
    const names = ['三角形', '五角形', '六角形', '星', 'ハート', '吹き出し', '矢印'];
    for (final name in names) {
      final tex = await generateBuiltInStampTexture(Stamp(id: name, name: name), size: 64);
      expect(tex.length, 64 * 64 * 4);
      expect(_opaqueRatio(tex), greaterThan(0.03), reason: name);
      expect(_opaqueRatio(tex), lessThan(0.9), reason: name);
      await _saveRgba(tex, 64, 64, '${out.path}/stamp_builtin_${_safe(name)}.png');
    }
  });

  test('組み込みスタンプ：pixelModeでドット絵化される', () async {
    final normal = await generateBuiltInStampTexture(const Stamp(id: 'star', name: '星'), size: 64);
    final pixel = await generateBuiltInStampTexture(const Stamp(id: 'star-px', name: '星', pixelMode: true), size: 64);
    expect(pixel.length, normal.length);
    expect(pixel, isNot(equals(normal)));
    await _saveRgba(pixel, 64, 64, '${out.path}/stamp_builtin_star_pixel.png');
  });

  test('UndoManager：undo/redo順序とredoクリアが正しい', () {
    final manager = UndoManager();
    final values = <String>[];

    manager.push(_CallbackAction(
      descriptionText: 'A',
      undoFn: () => values.add('undoA'),
      redoFn: () => values.add('redoA'),
    ));
    manager.push(_CallbackAction(
      descriptionText: 'B',
      undoFn: () => values.add('undoB'),
      redoFn: () => values.add('redoB'),
    ));

    expect(manager.undoCount, 2);
    manager.undo();
    manager.undo();
    expect(values, equals(['undoB', 'undoA']));
    expect(manager.redoCount, 2);

    manager.redo();
    expect(values.last, 'redoA');
    manager.push(_CallbackAction(
      descriptionText: 'C',
      undoFn: () => values.add('undoC'),
      redoFn: () => values.add('redoC'),
    ));
    expect(manager.redoCount, 0, reason: 'new action after undo must clear redo stack');
  });

  test('UndoManager：最大履歴数を超えた古い操作は破棄', () {
    final manager = UndoManager();
    manager.setMaxUndoCount(2);
    var value = 0;
    for (var i = 1; i <= 3; i++) {
      final n = i;
      manager.push(_CallbackAction(
        descriptionText: '$n',
        undoFn: () => value -= n,
        redoFn: () => value += n,
      ));
    }
    expect(manager.undoCount, 2);
    manager.undo();
    manager.undo();
    expect(manager.canUndo, isFalse);
    expect(value, -5, reason: 'oldest action 1 should have been discarded');
  });
}

int _alpha(Uint8List d, int width, int x, int y) => d[(y * width + x) * 4 + 3];

double _opaqueRatio(Uint8List d) {
  var n = 0;
  var count = 0;
  for (var i = 3; i < d.length; i += 4) {
    count++;
    if (d[i] > 0) n++;
  }
  return count == 0 ? 0 : n / count;
}

String _safe(String s) => s
    .replaceAll('三角形', 'triangle')
    .replaceAll('五角形', 'pentagon')
    .replaceAll('六角形', 'hexagon')
    .replaceAll('星', 'star')
    .replaceAll('ハート', 'heart')
    .replaceAll('吹き出し', 'bubble')
    .replaceAll('矢印', 'arrow');

Future<void> _saveRgba(Uint8List rgba, int width, int height, String path) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(png!.buffer.asUint8List());
  frame.image.dispose();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
}

class _CallbackAction extends UndoAction {
  final void Function() undoFn;
  final void Function() redoFn;
  final String descriptionText;

  _CallbackAction({required this.undoFn, required this.redoFn, required this.descriptionText});

  @override
  void undo() => undoFn();

  @override
  void redo() => redoFn();

  @override
  String get description => descriptionText;
}
