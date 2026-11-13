import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/camera_engine.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/engine/layer_keyframe_engine.dart';
import 'package:niarim/models/camera_keyframe.dart';
import 'package:niarim/models/effect_filter_instance.dart';
import 'package:niarim/models/layer_keyframe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Directory('build/time-change-strict');

  setUpAll(() => out.createSync(recursive: true));

  test(
    'camera pan/zoom/rotation interpolates and produces distinct visual frames',
    () async {
      final engine = CameraEngine();
      const keys = [
        CameraKeyframe(frameIndex: 0, x: 0, y: 0, zoom: 1.0, rotation: 0),
        CameraKeyframe(frameIndex: 10, x: 28, y: -18, zoom: 1.6, rotation: 36),
      ];

      final mid = engine.valueAt(keys, 5);
      expect(mid.x, closeTo(14, 1e-9));
      expect(mid.y, closeTo(-9, 1e-9));
      expect(mid.zoom, closeTo(1.3, 1e-9));
      expect(mid.rotation, closeTo(18, 1e-9));

      final rendered = <Uint8List>[];
      for (var frame = 0; frame <= 10; frame++) {
        final kf = engine.valueAt(keys, frame);
        final image = await _renderCameraFrame(engine, kf, 192, 144);
        final rgba = await _rgba(image);
        rendered.add(rgba);
        await _saveImage(
          image,
          '${out.path}/camera_${frame.toString().padLeft(2, '0')}.png',
        );
        image.dispose();
      }

      expect(_meanAbsDiff(rendered.first, rendered[5]), greaterThan(3));
      expect(_meanAbsDiff(rendered[5], rendered.last), greaterThan(3));
      for (var i = 1; i < rendered.length; i++) {
        expect(
          _meanAbsDiff(rendered[i - 1], rendered[i]),
          greaterThan(0.15),
          reason: 'camera frame $i must visibly change',
        );
      }
    },
  );

  test(
    'layer keyframe position/scale/rotation interpolation produces sequential visual evidence',
    () async {
      final engine = LayerKeyframeEngine();
      const keys = [
        LayerKeyframe(
          frameIndex: 0,
          x: -30,
          y: 16,
          scale: 0.72,
          rotation: -22,
          easing: LayerKeyframeEasing.easeInOut,
        ),
        LayerKeyframe(frameIndex: 10, x: 34, y: -20, scale: 1.42, rotation: 38),
      ];

      final start = engine.valueAt(keys, 0);
      final mid = engine.valueAt(keys, 5);
      final end = engine.valueAt(keys, 10);
      expect(start.x, -30);
      expect(end.x, 34);
      // easeInOut is exactly 0.5 at the interval midpoint.
      expect(mid.x, closeTo(2, 1e-9));
      expect(mid.y, closeTo(-2, 1e-9));
      expect(mid.scale, closeTo(1.07, 1e-9));
      expect(mid.rotation, closeTo(8, 1e-9));

      final rendered = <Uint8List>[];
      for (var frame = 0; frame <= 10; frame++) {
        final kf = engine.valueAt(keys, frame);
        final image = await _renderLayerKeyframe(engine, kf, 192, 144);
        final rgba = await _rgba(image);
        rendered.add(rgba);
        await _saveImage(
          image,
          '${out.path}/layer_keyframe_${frame.toString().padLeft(2, '0')}.png',
        );
        image.dispose();
      }
      expect(_meanAbsDiff(rendered.first, rendered[5]), greaterThan(2));
      expect(_meanAbsDiff(rendered[5], rendered.last), greaterThan(2));
      for (var i = 1; i < rendered.length; i++) {
        expect(
          _meanAbsDiff(rendered[i - 1], rendered[i]),
          greaterThan(0.10),
          reason: 'layer keyframe $i must visibly change',
        );
      }
    },
  );

  test(
    'layer keyframe easing curves differ from linear at quarter progress',
    () {
      final engine = LayerKeyframeEngine();
      const linear = [
        LayerKeyframe(frameIndex: 0, x: 0, easing: LayerKeyframeEasing.linear),
        LayerKeyframe(frameIndex: 100, x: 100),
      ];
      const easeIn = [
        LayerKeyframe(frameIndex: 0, x: 0, easing: LayerKeyframeEasing.easeIn),
        LayerKeyframe(frameIndex: 100, x: 100),
      ];
      const easeOut = [
        LayerKeyframe(frameIndex: 0, x: 0, easing: LayerKeyframeEasing.easeOut),
        LayerKeyframe(frameIndex: 100, x: 100),
      ];
      expect(engine.valueAt(linear, 25).x, closeTo(25, 1e-9));
      expect(engine.valueAt(easeIn, 25).x, lessThan(25));
      expect(engine.valueAt(easeOut, 25).x, greaterThan(25));
    },
  );

  test(
    'fade presentation effect changes continuously across its active range',
    () async {
      const w = 128, h = 96;
      final src = _testPattern(w, h);
      final engine = FilterEngine();
      const effect = EffectFilterInstance(
        id: 'fade',
        type: EffectFilterType.fade,
        startFrame: 0,
        endFrame: 10,
        fadeColor: ui.Color(0xFF000000),
      );

      final frames = <int, Uint8List>{};
      for (final frame in [0, 2, 4, 6, 8, 10]) {
        final got = engine.applyEffectFilters(
          Uint8List.fromList(src),
          w,
          h,
          const [effect],
          frame,
        );
        frames[frame] = got;
        await _saveRgba(
          got,
          w,
          h,
          '${out.path}/effect_fade_${frame.toString().padLeft(2, '0')}.png',
        );
      }
      final lum = frames.map((k, v) => MapEntry(k, _meanLuma(v)));
      expect(lum[0]!, greaterThan(lum[2]!));
      expect(lum[2]!, greaterThan(lum[4]!));
      expect(lum[4]!, greaterThan(lum[6]!));
      expect(lum[6]!, greaterThan(lum[8]!));
      expect(lum[8]!, greaterThan(lum[10]!));
    },
  );

  test('animatedNoise presentation effect changes from frame to frame', () async {
    const w = 128, h = 96;
    final src = _solid(w, h, 96, 112, 136);
    final engine = FilterEngine();
    const effect = EffectFilterInstance(
      id: 'noise',
      type: EffectFilterType.animatedNoise,
      startFrame: 0,
      endFrame: 5,
      param1: 16,
      param2: 75,
      param3: 2,
    );
    final frames = <Uint8List>[];
    for (var frame = 0; frame <= 5; frame++) {
      final got = engine.applyEffectFilters(
        Uint8List.fromList(src),
        w,
        h,
        const [effect],
        frame,
      );
      frames.add(got);
      await _saveRgba(
        got,
        w,
        h,
        '${out.path}/effect_animated_noise_${frame.toString().padLeft(2, '0')}.png',
      );
    }
    for (var i = 1; i < frames.length; i++) {
      expect(
        _meanAbsDiff(frames[i - 1], frames[i]),
        greaterThan(1),
        reason: 'animatedNoise frame $i must move/change',
      );
    }
  });

  test('rain presentation effect moves across consecutive frames', () async {
    const w = 160, h = 120;
    final src = _solid(w, h, 24, 32, 48);
    final engine = FilterEngine();
    const effect = EffectFilterInstance(
      id: 'rain',
      type: EffectFilterType.rain,
      startFrame: 0,
      endFrame: 5,
      param1: 15,
      param2: 7,
      param3: 2,
      param4: 18,
    );
    final frames = <Uint8List>[];
    for (var frame = 0; frame <= 5; frame++) {
      final got = engine.applyEffectFilters(
        Uint8List.fromList(src),
        w,
        h,
        const [effect],
        frame,
      );
      frames.add(got);
      await _saveRgba(
        got,
        w,
        h,
        '${out.path}/effect_rain_${frame.toString().padLeft(2, '0')}.png',
      );
    }
    for (var i = 1; i < frames.length; i++) {
      expect(
        _meanAbsDiff(frames[i - 1], frames[i]),
        greaterThan(0.15),
        reason: 'rain frame $i must move/change',
      );
    }
  });

  test('presentation effects obey frame range and enabled state', () {
    const w = 32, h = 32;
    final src = _solid(w, h, 100, 120, 140);
    final engine = FilterEngine();
    const ranged = EffectFilterInstance(
      id: 'ranged',
      type: EffectFilterType.fade,
      startFrame: 3,
      endFrame: 7,
      fadeColor: ui.Color(0xFF000000),
    );
    const disabled = EffectFilterInstance(
      id: 'disabled',
      type: EffectFilterType.animatedNoise,
      startFrame: 0,
      endFrame: 10,
      enabled: false,
      param1: 20,
      param2: 100,
    );
    expect(
      engine.applyEffectFilters(Uint8List.fromList(src), w, h, const [
        ranged,
      ], 2),
      orderedEquals(src),
    );
    expect(
      engine.applyEffectFilters(Uint8List.fromList(src), w, h, const [
        ranged,
      ], 8),
      orderedEquals(src),
    );
    expect(
      engine.applyEffectFilters(Uint8List.fromList(src), w, h, const [
        disabled,
      ], 5),
      orderedEquals(src),
    );
    expect(
      _meanAbsDiff(
        src,
        engine.applyEffectFilters(Uint8List.fromList(src), w, h, const [
          ranged,
        ], 5),
      ),
      greaterThan(0),
    );
  });
}

Future<ui.Image> _renderCameraFrame(
  CameraEngine engine,
  CameraKeyframe kf,
  int w,
  int h,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFF4EEE4),
  );
  canvas.save();
  engine.apply(canvas, kf, w.toDouble(), h.toDouble());
  canvas.drawRect(
    const ui.Rect.fromLTWH(22, 22, 62, 34),
    ui.Paint()..color = const ui.Color(0xFFE05252),
  );
  canvas.drawCircle(
    const ui.Offset(135, 44),
    20,
    ui.Paint()..color = const ui.Color(0xFF438EDB),
  );
  final path = ui.Path()
    ..moveTo(50, 112)
    ..lineTo(96, 70)
    ..lineTo(148, 112)
    ..close();
  canvas.drawPath(path, ui.Paint()..color = const ui.Color(0xFF4BA56A));
  canvas.restore();
  return recorder.endRecording().toImage(w, h);
}

Future<ui.Image> _renderLayerKeyframe(
  LayerKeyframeEngine engine,
  LayerKeyframe kf,
  int w,
  int h,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFF3F0E9),
  );
  canvas.save();
  engine.apply(canvas, kf, w.toDouble(), h.toDouble());
  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(
      const ui.Rect.fromLTWH(48, 44, 96, 54),
      const ui.Radius.circular(10),
    ),
    ui.Paint()..color = const ui.Color(0xFFBE4A64),
  );
  canvas.drawRect(
    const ui.Rect.fromLTWH(58, 55, 25, 12),
    ui.Paint()..color = const ui.Color(0xFFF4D66D),
  );
  canvas.drawCircle(
    const ui.Offset(122, 72),
    14,
    ui.Paint()..color = const ui.Color(0xFF3979B9),
  );
  canvas.restore();
  return recorder.endRecording().toImage(w, h);
}

Uint8List _testPattern(int w, int h) {
  final b = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      b[i] = (40 + x * 180 ~/ math.max(1, w - 1)).clamp(0, 255);
      b[i + 1] = (55 + y * 150 ~/ math.max(1, h - 1)).clamp(0, 255);
      b[i + 2] = ((x ~/ 12 + y ~/ 12).isEven ? 220 : 80);
      b[i + 3] = 255;
    }
  }
  return b;
}

Uint8List _solid(int w, int h, int r, int g, int b) {
  final out = Uint8List(w * h * 4);
  for (var i = 0; i < out.length; i += 4) {
    out[i] = r;
    out[i + 1] = g;
    out[i + 2] = b;
    out[i + 3] = 255;
  }
  return out;
}

Future<Uint8List> _rgba(ui.Image image) async => (await image.toByteData(
  format: ui.ImageByteFormat.rawRgba,
))!.buffer.asUint8List();

Future<void> _saveImage(ui.Image image, String path) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(data!.buffer.asUint8List());
}

Future<void> _saveRgba(Uint8List rgba, int w, int h, String path) async {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete);
  final image = await c.future;
  await _saveImage(image, path);
  image.dispose();
}

double _meanAbsDiff(Uint8List a, Uint8List b) {
  var sum = 0.0;
  for (var i = 0; i < math.min(a.length, b.length); i++) {
    sum += (a[i] - b[i]).abs();
  }
  return sum / math.min(a.length, b.length);
}

double _meanLuma(Uint8List b) {
  var sum = 0.0;
  var n = 0;
  for (var i = 0; i < b.length; i += 4) {
    sum += 0.2126 * b[i] + 0.7152 * b[i + 1] + 0.0722 * b[i + 2];
    n++;
  }
  return sum / n;
}
