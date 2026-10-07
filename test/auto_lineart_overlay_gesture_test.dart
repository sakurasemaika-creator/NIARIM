import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/auto_lineart_engine.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/canvas/widgets/auto_lineart_control_overlay.dart';

/// Auto line art's control-point editor tells a tap from a drag: a press
/// that wobbles a few pixels is a tap (the point stays where it was and the
/// delete confirmation opens), a drag past that moves the point and never
/// asks to delete it; in add mode a point is added when the tap ends, not
/// when a finger lands (so starting to scroll from the preview adds none).
void main() {
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

  Future<ui.Image> image() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint());
    return recorder.endRecording().toImage(100, 100);
  }

  Future<void> mount(
    WidgetTester tester,
    ui.Image img, {
    AutoLineartControlMode mode = AutoLineartControlMode.move,
    required List<AutoLineartPoint> moves,
    required List<AutoLineartGraph> changes,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: AutoLineartControlOverlay(
            image: img,
            graph: graph,
            mode: mode,
            onPointMoved: (_, _, point) => moves.add(point),
            onGraphChanged: changes.add,
          ),
        ),
      ),
    ),
  );

  testWidgets('a wobbling tap does not move the point and asks to delete', (
    tester,
  ) async {
    final img = await tester.runAsync(image);
    final moves = <AutoLineartPoint>[];
    await mount(tester, img!, moves: moves, changes: []);
    final centre = tester.getRect(find.byType(AutoLineartControlOverlay)).center;
    final gesture = await tester.startGesture(centre);
    await gesture.moveBy(const Offset(2, 1));
    await gesture.moveBy(const Offset(1, -2));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(moves, isEmpty, reason: 'the point stays where it was');
    expect(find.byType(AlertDialog), findsOneWidget);
    img.dispose();
  });

  testWidgets('a drag past the slop moves the point and asks nothing', (
    tester,
  ) async {
    final img = await tester.runAsync(image);
    final moves = <AutoLineartPoint>[];
    await mount(tester, img!, moves: moves, changes: []);
    final centre = tester.getRect(find.byType(AutoLineartControlOverlay)).center;
    final gesture = await tester.startGesture(centre);
    await gesture.moveBy(const Offset(3, 0));
    expect(moves, isEmpty, reason: 'not yet a drag');
    await gesture.moveBy(const Offset(10, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(moves, isNotEmpty);
    expect(moves.last.x, greaterThan(50));
    expect(find.byType(AlertDialog), findsNothing);
    img.dispose();
  });

  testWidgets('add mode adds on release, and not for a drag', (tester) async {
    final img = await tester.runAsync(image);
    final changes = <AutoLineartGraph>[];
    await mount(
      tester,
      img!,
      mode: AutoLineartControlMode.add,
      moves: [],
      changes: changes,
    );
    final rect = tester.getRect(find.byType(AutoLineartControlOverlay));
    // On the segment between the first two points.
    final onSegment = Offset(rect.left + rect.width * .35, rect.center.dy);
    final press = await tester.startGesture(onSegment);
    await tester.pump();
    expect(changes, isEmpty, reason: 'nothing yet while the finger is down');
    await press.up();
    await tester.pump();
    expect(changes, hasLength(1));
    expect(changes.single.paths.single.points, hasLength(4));

    // A drag that starts on the line (a scroll) adds nothing.
    final drag = await tester.startGesture(onSegment);
    await drag.moveBy(const Offset(0, 30));
    await drag.up();
    await tester.pump();
    expect(changes, hasLength(1));
    img.dispose();
  });
}
