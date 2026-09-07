import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/auto_lineart_engine.dart';
import 'package:niarim/screens/canvas/widgets/auto_lineart_control_overlay.dart';

void main() {
  testWidgets('auto lineart preview control point can be dragged', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint());
    final image = await recorder.endRecording().toImage(100, 100);
    int? movedPath;
    int? movedPoint;
    AutoLineartPoint? movedTo;
    const graph = AutoLineartGraph(
      width: 100,
      height: 100,
      paths: [
        AutoLineartPath(
          points: [
            AutoLineartPoint(20, 50),
            AutoLineartPoint(50, 50),
            AutoLineartPoint(80, 50),
          ],
          startIsJunction: false,
          endIsJunction: false,
          persistence: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: AutoLineartControlOverlay(
              image: image,
              graph: graph,
              onPointMoved: (p, i, point) {
                movedPath = p;
                movedPoint = i;
                movedTo = point;
              },
            ),
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byType(AutoLineartControlOverlay));
    final start = Offset(box.left + box.width * .5, box.top + box.height * .5);
    await tester.dragFrom(start, const Offset(25, -30));
    await tester.pump();

    expect(movedPath, 0);
    expect(movedPoint, 1);
    expect(movedTo, isNotNull);
    expect(movedTo!.x, greaterThan(50));
    expect(movedTo!.y, lessThan(50));
    image.dispose();
  });
}
