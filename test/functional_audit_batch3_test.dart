import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/autofill_engine.dart';
import 'package:niarim/engine/layer_compositor.dart';
import 'package:niarim/engine/layer_range_resolver.dart';
import 'package:niarim/engine/tile_manager.dart';
import 'package:niarim/models/autofill_gradient.dart';
import 'package:niarim/models/autofill_preset.dart';
import 'package:niarim/models/layer.dart';
import 'package:niarim/models/scene.dart';

const int w = 96;
const int h = 96;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/functional-visual');
  setUpAll(() => out.createSync(recursive: true));

  test('共通レイヤー：ホームの実ピクセルを表示範囲先で共有描画', () async {
    const common = Layer(
      id: 'common', name: 'common', type: LayerType.common,
      rangeMode: LayerRangeMode.allFrames,
    );
    const scenes = [
      Scene(id: 's1', index: 0, frames: [
        Frame(index: 0, layers: [common]),
        Frame(index: 1),
        Frame(index: 2),
      ]),
      Scene(id: 's2', index: 1, frames: [Frame(index: 0), Frame(index: 1)]),
    ];
    final homes = buildLayerHomeIndex(scenes);
    expect(homes['common']!.sceneId, 's1');
    expect(homes['common']!.frameIndex, 0);

    final tm = TileManager(canvasWidth: w, canvasHeight: h);
    final homeKey = frameLayerKey('s1', 0, 'common');
    final tile = tm.getOrCreateTile(homeKey, 0, 0);
    for (var y = 34; y < 62; y++) {
      for (var x = 26; x < 70; x++) {
        tm.setPixel(tile, x, y, 45, 120, 235, 255);
      }
    }
    tm.markDirty(homeKey, 0, 0);

    for (final target in [('s1', 0), ('s1', 1), ('s1', 2), ('s2', 0), ('s2', 1)]) {
      final scene = scenes.firstWhere((s) => s.id == target.$1);
      final own = scene.frames[target.$2].layers;
      final resolved = resolveFrameLayers(scenes, homes, target.$1, target.$2, own);
      expect(resolved.any((l) => l.id == 'common'), isTrue, reason: '$target common visible');
      final image = await LayerCompositor.composite(
        tm,
        resolved,
        (l) => resolveTileKey(homes, target.$1, target.$2, l.id),
        w,
        h,
      );
      await _save(image, '${out.path}/common_all_${target.$1}_${target.$2}.png');
      final rgba = await _rgba(image);
      expect(_pixel(rgba, 48, 48), equals([45, 120, 235, 255]), reason: '$target must use home pixels');
      image.dispose();
    }
    tm.dispose();
  });

  test('共通レイヤー：currentScene / sceneRange / frameRange が正しい範囲だけ表示', () {
    const current = Layer(id: 'c', name: 'c', type: LayerType.common, rangeMode: LayerRangeMode.currentScene);
    expect(rangeAppliesToFrame(current, 's1', 's1', 99), isTrue);
    expect(rangeAppliesToFrame(current, 's1', 's2', 0), isFalse);

    const sceneRange = Layer(
      id: 's', name: 's', type: LayerType.common,
      rangeMode: LayerRangeMode.sceneRange, rangeSceneId: 's2',
    );
    expect(rangeAppliesToFrame(sceneRange, 's1', 's2', 0), isTrue);
    expect(rangeAppliesToFrame(sceneRange, 's1', 's1', 0), isFalse);

    const frameRange = Layer(
      id: 'f', name: 'f', type: LayerType.common,
      rangeMode: LayerRangeMode.frameRange, rangeStart: 2, rangeEnd: 4,
    );
    expect(rangeAppliesToFrame(frameRange, 's1', 's1', 0), isFalse);
    expect(rangeAppliesToFrame(frameRange, 's1', 's1', 1), isTrue);
    expect(rangeAppliesToFrame(frameRange, 's1', 's1', 3), isTrue);
    expect(rangeAppliesToFrame(frameRange, 's1', 's1', 4), isFalse);
    expect(rangeAppliesToFrame(frameRange, 's1', 's2', 2), isFalse);
  });

  test('自動塗り：閉領域だけを単色で塗り、外側と線画を侵食しない', () async {
    final lineart = _rectLineart();
    const part = AutofillPart(id: 'p', name: 'solid', color: 0xFFE05090);
    final result = AutofillEngine().repaint(lineartData: lineart, width: w, height: h, part: part);
    final image = await _image(result);
    await _save(image, '${out.path}/autofill_solid.png');
    image.dispose();

    expect(_pixel(result, 48, 48), equals([224, 80, 144, 255]));
    expect(_pixel(result, 5, 5)[3], 0, reason: 'outside must remain transparent');
    expect(_pixel(result, 20, 20)[3], 0, reason: 'lineart boundary must not be painted into fill layer');
  });

  test('自動塗り：線が一箇所開いていれば閉領域扱いしない', () async {
    final lineart = _rectLineart(gap: true);
    const part = AutofillPart(id: 'p', name: 'open', color: 0xFF30A060);
    final result = AutofillEngine().repaint(lineartData: lineart, width: w, height: h, part: part);
    final image = await _image(result);
    await _save(image, '${out.path}/autofill_open_gap.png');
    image.dispose();
    expect(_countOpaque(result), 0, reason: 'open contour must not be autofilled');
  });

  test('自動塗り：線形グラデーションの向きと色変化', () async {
    final lineart = _rectLineart();
    const gradient = AutofillGradient(
      type: AutofillGradientType.linear,
      angle: 0,
      colors: [0xFFFF2020, 0xFF2040FF],
      stops: [0, 1],
    );
    const part = AutofillPart(id: 'p', name: 'gradient', color: 0xFFFFFFFF, gradient: gradient);
    final result = AutofillEngine().repaint(lineartData: lineart, width: w, height: h, part: part);
    final image = await _image(result);
    await _save(image, '${out.path}/autofill_gradient_linear.png');
    image.dispose();
    final left = _pixel(result, 28, 48);
    final right = _pixel(result, 68, 48);
    expect(left[0], greaterThan(right[0]), reason: '0deg gradient red should be stronger at left');
    expect(right[2], greaterThan(left[2]), reason: '0deg gradient blue should be stronger at right');
  });

  test('自動塗り：トーンは閉領域内だけで2x2周期を維持', () async {
    final lineart = _rectLineart();
    final tone = Uint8List.fromList([
      0, 0, 0, 255, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 255,
    ]);
    const part = AutofillPart(id: 'p', name: 'tone', color: 0xFF7040D0, useTone: true, toneId: 'checker');
    final result = AutofillEngine().repaint(
      lineartData: lineart, width: w, height: h, part: part,
      toneTexture: tone, toneWidth: 2, toneHeight: 2,
    );
    final image = await _image(result);
    await _save(image, '${out.path}/autofill_tone.png');
    image.dispose();
    expect(_pixel(result, 48, 48)[3], 255);
    expect(_pixel(result, 49, 48)[3], 0);
    expect(_pixel(result, 49, 49)[3], 255);
    expect(_pixel(result, 5, 5)[3], 0);
  });

  test('自動塗り：縁取りは塗り領域外周だけに形成される', () async {
    final lineart = _rectLineart();
    const part = AutofillPart(
      id: 'p', name: 'outline', color: 0xFF40B060,
      outlineEnabled: true, outlineColor: 0xFFFF3020, outlineWidth: 3,
    );
    final result = AutofillEngine().repaint(lineartData: lineart, width: w, height: h, part: part);
    final image = await _image(result);
    await _save(image, '${out.path}/autofill_outline.png');
    image.dispose();
    expect(_pixel(result, 48, 48).sublist(0, 3), equals([64, 176, 96]));
    final edge = _pixel(result, 20, 48);
    expect(edge[0], greaterThan(200), reason: 'outline should be red around region edge');
    expect(edge[1], lessThan(100));
    expect(_pixel(result, 5, 5)[3], 0);
  });

  test('自動塗り：色更新は形状alphaを維持してRGBだけ更新', () async {
    final lineart = _rectLineart();
    const first = AutofillPart(id: 'p', name: 'first', color: 0xFFE05090);
    final engine = AutofillEngine();
    final initial = engine.repaint(lineartData: lineart, width: w, height: h, part: first);
    const second = AutofillPart(id: 'p', name: 'second', color: 0xFF20A0E0);
    final updated = engine.colorUpdate(existingData: initial, width: w, height: h, part: second);
    final image = await _image(updated);
    await _save(image, '${out.path}/autofill_color_update.png');
    image.dispose();
    for (var i = 3; i < initial.length; i += 4) {
      expect(updated[i], initial[i], reason: 'color update must preserve alpha mask');
    }
    expect(_pixel(updated, 48, 48), equals([32, 160, 224, 255]));
  });

  test('自動塗り：線画色変更は形状alphaを保持', () async {
    final lineart = _rectLineart();
    const specified = AutofillPart(
      id: 'p', name: 'line', color: 0xFF60B080,
      lineColorMode: AutofillLineColorMode.specified, lineColor: 0xFF8040E0,
    );
    final result = AutofillEngine().recolorLineart(lineartData: lineart, width: w, height: h, part: specified);
    final image = await _image(result);
    await _save(image, '${out.path}/autofill_line_recolor.png');
    image.dispose();
    expect(_pixel(result, 20, 48), equals([128, 64, 224, 255]));
    expect(_pixel(result, 48, 48)[3], 0);
    for (var i = 3; i < lineart.length; i += 4) {
      expect(result[i], lineart[i], reason: 'line recolor must preserve alpha');
    }
  });
}

Uint8List _rectLineart({bool gap = false}) {
  final data = Uint8List(w * h * 4);
  void put(int x, int y) {
    final i = (y * w + x) * 4;
    data[i] = data[i + 1] = data[i + 2] = 20;
    data[i + 3] = 255;
  }
  for (var x = 20; x <= 75; x++) {
    if (!(gap && x >= 45 && x <= 51)) put(x, 20);
    put(x, 75);
  }
  for (var y = 20; y <= 75; y++) {
    put(20, y);
    put(75, y);
  }
  return data;
}

int _countOpaque(List<int> rgba) {
  var n = 0;
  for (var i = 3; i < rgba.length; i += 4) if (rgba[i] > 0) n++;
  return n;
}

Future<ui.Image> _image(Uint8List rgba) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(buffer, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return frame.image;
}

Future<List<int>> _rgba(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

List<int> _pixel(List<int> rgba, int x, int y) {
  final i = (y * w + x) * 4;
  return [rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]];
}

Future<void> _save(ui.Image image, String path) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(data!.buffer.asUint8List());
}
