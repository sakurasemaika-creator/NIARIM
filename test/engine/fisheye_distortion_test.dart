import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_canvas_gizmo.dart';
import 'package:niarim/models/filter_def.dart';
import 'package:niarim/services/filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The fisheye's distortion bulges the middle out like a fisheye lens when
/// it is above 0 and pinches it when below, inside the reach its radius
/// sets; the radius can be dragged on the canvas.
void main() {
  const size = 101;

  /// An opaque white canvas with a black disc of [radius] in the middle.
  Uint8List disc(double radius) {
    final out = Uint8List(size * size * 4);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final d = math.sqrt(math.pow(x - 50, 2) + math.pow(y - 50, 2));
        final v = d <= radius ? 0 : 255;
        out.setAll((y * size + x) * 4, [v, v, v, 255]);
      }
    }
    return out;
  }

  /// How far the black disc reaches along the middle row.
  int discRadius(Uint8List data) {
    var r = 0;
    for (var x = 50; x < size; x++) {
      if (data[(50 * size + x) * 4] < 128) r = x - 50;
    }
    return r;
  }

  final engine = FilterEngine();

  test('above 0 the middle bulges, below 0 it pinches, 0 leaves it', () {
    final input = disc(12);
    expect(discRadius(input), 12);
    final bulged = engine.applyFisheye(input, size, size, 60);
    final pinched = engine.applyFisheye(input, size, size, -60);
    expect(discRadius(bulged), greaterThan(16), reason: 'magnified middle');
    expect(discRadius(pinched), lessThan(10), reason: 'shrunk middle');
    expect(engine.applyFisheye(input, size, size, 0), orderedEquals(input));
  });

  test('the radius limits how far the distortion reaches', () {
    final input = disc(30);
    // Reach of 20 % of the half-diagonal (about 14 px): the disc's edge at
    // 30 px is outside it and stays put.
    final small = engine.applyFisheye(input, size, size, 80, radiusPercent: 20);
    expect(discRadius(small), 30);
  });

  test('dragging the reach handle on the canvas sets the radius', () async {
    SharedPreferences.setMockInitialValues({});
    final service = FilterService();
    await service.init();
    final fisheye = service.filters.firstWhere(
      (f) => f.kind == FilterKind.fisheye,
    );
    final gizmo = filterCanvasGizmoFor(fisheye, 1000, 500)!;
    expect(gizmo.handles.keys, contains(FilterGizmoHandle.reach));
    final halfDiagonal = math.sqrt(1000 * 1000 + 500 * 500) / 2;
    expect(
      gizmo.handles[FilterGizmoHandle.reach],
      gizmo.center + Offset(halfDiagonal * fisheye.fisheyeRadius / 100, 0),
    );
    service.moveCanvasGizmo(
      fisheye.id,
      gizmo.copyWith(reach: halfDiagonal * 0.4),
      1000,
      500,
    );
    final moved = service.filters.firstWhere((f) => f.id == fisheye.id);
    expect(moved.fisheyeRadius, closeTo(40, 1e-9));
    expect(moved.fisheyeCenterX, fisheye.fisheyeCenterX, reason: 'unmoved');
  });
}
