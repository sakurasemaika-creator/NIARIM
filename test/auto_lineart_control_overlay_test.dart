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

  testWidgets(
    'SP-sized transparent hit target reaches 20px from a control point',
    (tester) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint());
      final image = await recorder.endRecording().toImage(100, 100);
      AutoLineartPoint? movedTo;
      const graph = AutoLineartGraph(
        width: 100,
        height: 100,
        paths: [
          AutoLineartPath(
            points: [AutoLineartPoint(50, 50), AutoLineartPoint(80, 50)],
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
                onPointMoved: (_, _, point) => movedTo = point,
              ),
            ),
          ),
        ),
      );
      final box = tester.getRect(find.byType(AutoLineartControlOverlay));
      await tester.dragFrom(
        Offset(box.left + box.width * .5 + 20, box.top + box.height * .5),
        const Offset(15, -20),
      );
      await tester.pump();
      expect(movedTo, isNotNull);
      image.dispose();
    },
  );

  testWidgets('overlapping touch targets select the nearest control point', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint());
    final image = await recorder.endRecording().toImage(100, 100);
    int? movedIndex;
    const graph = AutoLineartGraph(
      width: 100,
      height: 100,
      paths: [
        AutoLineartPath(
          points: [
            AutoLineartPoint(45, 50),
            AutoLineartPoint(55, 50),
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
            width: 100,
            height: 100,
            child: AutoLineartControlOverlay(
              image: image,
              graph: graph,
              onPointMoved: (_, pointIndex, _) => movedIndex = pointIndex,
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byType(AutoLineartControlOverlay));
    await tester.dragFrom(
      Offset(rect.left + 54, rect.top + 50),
      const Offset(6, -10),
    );
    await tester.pump();

    expect(movedIndex, 1);
    image.dispose();
  });

  for (final graphExtent in <int>[25, 100, 400]) {
    final zoomLabel = switch (graphExtent) {
      25 => '4x',
      100 => '1x',
      _ => '0.25x',
    };
    testWidgets(
      'control hit target stays screen-fixed at $zoomLabel graph scale',
      (tester) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, graphExtent.toDouble(), graphExtent.toDouble()),
          Paint(),
        );
        final image = await recorder.endRecording().toImage(
          graphExtent,
          graphExtent,
        );
        int? movedIndex;
        final center = graphExtent / 2.0;
        final graph = AutoLineartGraph(
          width: graphExtent,
          height: graphExtent,
          paths: [
            AutoLineartPath(
              points: [
                AutoLineartPoint(center, center),
                AutoLineartPoint(graphExtent * 0.8, center),
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
                  onPointMoved: (_, pointIndex, _) => movedIndex = pointIndex,
                ),
              ),
            ),
          ),
        );

        final rect = tester.getRect(find.byType(AutoLineartControlOverlay));
        // The point is at screen center for every graph scale. Starting 20
        // logical pixels away must still hit because the 22px hit radius is a
        // screen-space constant, independent of graph/canvas scale.
        await tester.dragFrom(
          Offset(rect.center.dx + 20, rect.center.dy),
          const Offset(8, -8),
        );
        await tester.pump();

        expect(movedIndex, 0);
        image.dispose();
      },
    );
  }
}
