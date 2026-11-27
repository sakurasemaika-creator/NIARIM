// 自動線画：点を足した・消した線は、なめらか補正を何度変えても手で直した形の
// まま残る。
//
// 実際に使ってみたとき（2026-11-27）、制御点を手で直した後になめらか補正の
// スライダーをドラッグすると、線の一部が消え、点がキャンバスの隅へ飛んだ。
// 手で形を変えた線は1回目の補正の変更ではそのまま残るが、そのとき基準を新しい
// 自動の線にしていたので、2回目には、点の数がたまたま同じ別の自動の線との
// 差を「手で動かした量」として読んでいた。
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/auto_lineart_engine.dart';

AutoLineartGraph _graph(List<List<AutoLineartPoint>> paths) => AutoLineartGraph(
  width: 100,
  height: 100,
  paths: [
    for (final points in paths)
      AutoLineartPath(
        points: points,
        startIsJunction: false,
        endIsJunction: false,
        persistence: 1,
      ),
  ],
);

List<AutoLineartPoint> _line(int count, {double y = 20}) => [
  for (var i = 0; i < count; i++)
    AutoLineartPoint(10 + 80 * i / (count - 1), y),
];

List<(double, double)> _xy(List<AutoLineartPoint> points) => [
  for (final p in points) (p.x, p.y),
];

void main() {
  test('a reshaped path survives smoothing changes one after another', () {
    // The automatic line, then the same line with a point added by hand
    // (pulled down to y = 60).
    final automatic = _graph([_line(5), _line(3, y: 80)]);
    final reshaped = _graph([
      [
        ..._line(5).sublist(0, 3),
        const AutoLineartPoint(60, 60),
        ..._line(5).sublist(3),
      ],
      _line(3, y: 80),
    ]);
    // Smoothing raised: the line now has six points, then four.
    final six = _graph([_line(6), _line(3, y: 80)]);
    final four = _graph([_line(4), _line(3, y: 80)]);

    final first = AutoLineartEngine.transferControlEditsWithBaseline(
      automatic,
      reshaped,
      six,
    );
    expect(
      _xy(first.graph.paths.first.points),
      _xy(reshaped.paths.first.points),
    );

    final second = AutoLineartEngine.transferControlEditsWithBaseline(
      first.baseline,
      first.graph,
      four,
    );
    expect(
      _xy(second.graph.paths.first.points),
      _xy(reshaped.paths.first.points),
      reason: 'the hand-made shape is kept',
    );
    // The untouched line follows the automatic one.
    expect(_xy(second.graph.paths.last.points), _xy(four.paths.last.points));
    expect(_xy(second.baseline.paths.last.points), _xy(four.paths.last.points));

    // What happened before: the new automatic line as the baseline. It has
    // as many points as the reshaped line, so the second change read the
    // differences as moves and bent the automatic line instead.
    final old = AutoLineartEngine.transferControlEdits(six, first.graph, four);
    expect(old.paths.first.points, hasLength(4));
  });

  test('a moved point keeps following the automatic line', () {
    final automatic = _graph([_line(5)]);
    final moved = AutoLineartEngine.moveControlPoint(
      automatic,
      pathIndex: 0,
      pointIndex: 2,
      point: const AutoLineartPoint(50, 30),
    );
    final six = _graph([_line(6)]);
    final result = AutoLineartEngine.transferControlEditsWithBaseline(
      automatic,
      moved,
      six,
    );
    expect(
      _xy(result.baseline.paths.single.points),
      _xy(six.paths.single.points),
    );
    expect(result.graph.paths.single.points, hasLength(6));
    final lowest = result.graph.paths.single.points
        .map((p) => p.y)
        .reduce((a, b) => a > b ? a : b);
    expect(lowest, greaterThan(20), reason: 'the move is carried over');
    for (final p in result.graph.paths.single.points) {
      expect(p.y, inInclusiveRange(20, 30));
    }
  });
}
