import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/models/camera_keyframe.dart';
import 'package:niarim/models/layer_keyframe.dart';
import 'package:niarim/models/layer_region_edit.dart';
import 'package:niarim/screens/timeline/widgets/material_gizmo.dart';

const _w = 160;
const _h = 120;

/// The preview is 400 × 300, so a layer pixel is 2.5 preview pixels.
const _fit = 2.5;

/// Where the preview shows the layer point [p] of a material moved by
/// [value] (scale about the canvas centre, then moved) through [camera]: the
/// same steps as the preview's picture.
Offset _onPreview(
  Offset p, {
  LayerKeyframe value = const LayerKeyframe(frameIndex: 0),
  CameraKeyframe? camera,
}) {
  const c = Offset(_w / 2, _h / 2);
  final a = value.rotation * math.pi / 180;
  var q = (p - c) * value.scale;
  q = Offset(
    q.dx * math.cos(a) - q.dy * math.sin(a),
    q.dx * math.sin(a) + q.dy * math.cos(a),
  );
  final canvasPoint = c + q + Offset(value.x, value.y);
  var v = canvasPoint - c - Offset(camera?.x ?? 0, camera?.y ?? 0);
  v = v * (camera?.zoom ?? 1);
  final t = (camera?.rotation ?? 0) * math.pi / 180;
  v = Offset(
    v.dx * math.cos(t) - v.dy * math.sin(t),
    v.dx * math.sin(t) + v.dy * math.cos(t),
  );
  return (c + v) * _fit;
}

final _square = RegionSelection.box(
  RegionShape.rectangle,
  const Rect.fromLTRB(40 / _w, 30 / _h, 80 / _w, 60 / _h),
);

void main() {
  Future<_Harness> pump(
    WidgetTester tester, {
    LayerRegionEdit? edit,
    RegionSelection? selection,
    RegionShape shape = RegionShape.rectangle,
    LayerKeyframe value = const LayerKeyframe(frameIndex: 0),
    CameraKeyframe? camera,
  }) async {
    final harness = _Harness(edit: edit, selection: selection);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 300,
            child: StatefulBuilder(
              builder: (context, setState) => MaterialRegionGizmo(
                canvasWidth: _w,
                canvasHeight: _h,
                value: value,
                camera: camera,
                shape: shape,
                selection: harness.selection,
                onSelectionChanged: (s) =>
                    setState(() => harness.selection = s),
                edit: harness.edit,
                onEditChanged: (e) => setState(() => harness.edit = e),
                onChangeEnd: () => harness.ends++,
              ),
            ),
          ),
        ),
      ),
    );
    return harness;
  }

  Future<void> drag(WidgetTester tester, Offset from, Offset by) async {
    final gesture = await tester.startGesture(from);
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(by / 4);
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
  }

  group('selecting', () {
    test('outlines and handles', () {
      final handles = MaterialRegionGizmo.selectionHandles(
        const Rect.fromLTRB(10, 20, 30, 40),
      );
      expect(handles.first, const Offset(10, 20));
      expect(handles, hasLength(8));
    });

    testWidgets('a drag outlines the part under the finger, through the '
        'material\'s move, scale and turn and the camera', (tester) async {
      for (final (value, camera) in [
        (const LayerKeyframe(frameIndex: 0), null),
        (const LayerKeyframe(frameIndex: 0, x: 12, y: -6, scale: 1.5), null),
        (
          const LayerKeyframe(frameIndex: 0, rotation: 30, scale: 0.8),
          const CameraKeyframe(frameIndex: 0, x: 5, zoom: 1.25, rotation: -20),
        ),
      ]) {
        final harness = await pump(tester, value: value, camera: camera);
        final from = _onPreview(
          const Offset(50, 40),
          value: value,
          camera: camera,
        );
        final to = _onPreview(
          const Offset(90, 70),
          value: value,
          camera: camera,
        );
        await drag(tester, from, to - from);
        final bounds = harness.selection!.bounds;
        // Whatever the turn, the outline is drawn between the two layer
        // points the finger started and ended on.
        final corners = {
          Offset(bounds.left * _w, bounds.top * _h),
          Offset(bounds.right * _w, bounds.bottom * _h),
        };
        expect(
          corners.any((c) => (c - const Offset(50, 40)).distance < 0.5),
          isTrue,
          reason: '$value $camera: $bounds',
        );
        expect(
          corners.any((c) => (c - const Offset(90, 70)).distance < 0.5),
          isTrue,
          reason: '$value $camera: $bounds',
        );
      }
    });

    testWidgets('a drag inside moves the selection, a dot resizes it, a tap '
        'outside clears it', (tester) async {
      final harness = await pump(tester, selection: _square);
      await drag(tester, _onPreview(const Offset(60, 45)), const Offset(50, 0));
      expect(harness.selection!.bounds.left * _w, closeTo(60, 0.01));
      expect(harness.selection!.bounds.width * _w, closeTo(40, 0.01));

      // The bottom-right dot, now at (100, 60), pulled 10 layer pixels down.
      await drag(
        tester,
        _onPreview(const Offset(100, 60)),
        const Offset(0, 10 * _fit),
      );
      expect(harness.selection!.bounds.bottom * _h, closeTo(70, 0.01));
      expect(harness.selection!.bounds.top * _h, closeTo(30, 0.01));

      await tester.tapAt(_onPreview(const Offset(10, 100)));
      await tester.pump();
      expect(harness.selection, isNull);
      // Selecting is not an edit: nothing is recorded.
      expect(harness.ends, 0);
    });

    testWidgets('a freehand drag outlines the path', (tester) async {
      final harness = await pump(tester, shape: RegionShape.freehand);
      final gesture = await tester.startGesture(
        _onPreview(const Offset(40, 40)),
      );
      await tester.pump();
      for (final step in const [Offset(60, 0), Offset(0, 60), Offset(-60, 0)]) {
        await gesture.moveBy(step);
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      final outline = harness.selection!;
      expect(outline.shape, RegionShape.freehand);
      expect(outline.points.first.dx * _w, closeTo(40, 0.01));
      expect(outline.points, hasLength(4));
      expect(outline.bounds.right * _w, closeTo(40 + 60 / _fit, 0.01));
    });
  });

  group('changing a moved part', () {
    final edit = LayerRegionEdit(
      id: 'e',
      kind: RegionEditKind.move,
      region: _square,
    );

    testWidgets('a drag anywhere moves it by whole pixels', (tester) async {
      final harness = await pump(tester, edit: edit);
      await drag(tester, const Offset(300, 250), const Offset(50, -25));
      expect(harness.edit!.dx * _w, 20);
      expect(harness.edit!.dy * _h, -10);
      expect(harness.ends, 1);
    });

    testWidgets('a corner resizes it evenly, a side stretches it', (
      tester,
    ) async {
      final harness = await pump(tester, edit: edit);
      // Bottom-right corner (80, 60), 20 × 15 from the centre (60, 45):
      // pulled to twice as far.
      await drag(
        tester,
        _onPreview(const Offset(80, 60)),
        const Offset(20 * _fit, 15 * _fit),
      );
      expect(harness.edit!.scaleX, 2);
      expect(harness.edit!.scaleY, 2);

      final second = await pump(tester, edit: edit);
      // The middle of the right side (80, 45), pulled 20 further.
      await drag(
        tester,
        _onPreview(const Offset(80, 45)),
        const Offset(20 * _fit, 0),
      );
      expect(second.edit!.scaleX, 2);
      expect(second.edit!.scaleY, 1);
    });

    testWidgets('the dot above it turns it about its centre', (tester) async {
      final harness = await pump(tester, edit: edit);
      // The dot is 28 preview pixels above the middle of the top side.
      final dot = _onPreview(const Offset(60, 30)) + const Offset(0, -28);
      final centre = _onPreview(const Offset(60, 45));
      final reach = (dot - centre).distance;
      // A quarter turn clockwise: from straight up to straight right.
      await drag(tester, dot, centre + Offset(reach, 0) - dot);
      expect(harness.edit!.rotation, 90);
      expect(harness.edit!.scaleX, 1);
    });

    testWidgets('a flip is kept while resizing', (tester) async {
      final harness = await pump(tester, edit: edit.copyWith(scaleX: -1));
      await drag(
        tester,
        _onPreview(const Offset(80, 60)),
        const Offset(20 * _fit, 15 * _fit),
      );
      expect(harness.edit!.scaleX, -2);
      expect(harness.edit!.scaleY, 2);
    });

    testWidgets('a small part offers only its corners', (tester) async {
      final tiny = LayerRegionEdit(
        id: 't',
        kind: RegionEditKind.move,
        region: RegionSelection.box(
          RegionShape.rectangle,
          const Rect.fromLTRB(40 / _w, 30 / _h, 50 / _w, 40 / _h),
        ),
      );
      final harness = await pump(tester, edit: tiny);
      // On a 25-pixel part the middle of a side is too near the corners to
      // be a handle of its own: grabbing it takes the nearest corner, which
      // resizes evenly rather than stretching across.
      await drag(
        tester,
        _onPreview(const Offset(50, 35)),
        const Offset(10 * _fit, 0),
      );
      expect(harness.edit!.scaleX, greaterThan(1));
      expect(harness.edit!.scaleY, harness.edit!.scaleX);
    });
  });
}

class _Harness {
  _Harness({this.edit, this.selection});

  LayerRegionEdit? edit;
  RegionSelection? selection;
  int ends = 0;
}
