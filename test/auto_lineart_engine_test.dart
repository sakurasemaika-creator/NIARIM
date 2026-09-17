import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/auto_lineart_engine.dart';

void main() {
  test('moving one control point never moves coincident points on other paths', () {
    const graph = AutoLineartGraph(
      width: 100,
      height: 100,
      paths: [
        AutoLineartPath(
          points: [AutoLineartPoint(10, 10), AutoLineartPoint(50, 50)],
          startIsJunction: false,
          endIsJunction: true,
          persistence: 1,
        ),
        AutoLineartPath(
          points: [AutoLineartPoint(50, 50), AutoLineartPoint(90, 10)],
          startIsJunction: true,
          endIsJunction: false,
          persistence: 1,
        ),
      ],
    );

    final moved = AutoLineartEngine.moveControlPoint(
      graph,
      pathIndex: 0,
      pointIndex: 1,
      point: const AutoLineartPoint(60, 65),
    );

    expect(moved.paths[0].points[1].x, 60);
    expect(moved.paths[0].points[1].y, 65);
    expect(moved.paths[1].points[0].x, 50);
    expect(moved.paths[1].points[0].y, 50);
  });
}
