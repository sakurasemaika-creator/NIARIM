import 'dart:ui' show Offset;

/// ペン先が隣の画素の境目をどれだけ越えたら、その画素へ移るか（画素の幅に
/// 対する割合）。手の震えで境目の上を行き来しても、線が隣の行・列と
/// 行ったり来たりしない（ジグザグ・こぶにならない）。0.5未満なので、
/// 画素の真ん中に置いたペンは必ずその画素を描く。
const double kPixelLineHysteresis = 0.35;

/// ピクセルモードの線が通る画素を、ペン先の動きからたどる。
///
/// 画素の境目を[hysteresis]だけ越えたときに隣の画素へ移るので、通る画素は
/// 上下左右に1つずつつながる（境目の角をちょうど通るときだけ斜め）。
/// どの画素へ移るかは線の形だけで決まり、点の細かさ（ゆっくり描いて点が
/// 多い・速く描いてまばら）には左右されない。
class PixelLineWalker {
  PixelLineWalker(Offset start, {this.hysteresis = kPixelLineHysteresis})
    : x = start.dx.floor(),
      y = start.dy.floor();

  final double hysteresis;

  /// 今いる画素。
  int x;
  int y;

  /// [from]から[to]へ進む間に移った画素を、移った順に[onCell]へ渡す
  /// （[t]はその区間の上で移った位置、0〜1）。[from]は前の区間の終わり。
  void walk(
    Offset from,
    Offset to,
    void Function(int x, int y, double t) onCell,
  ) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    while (true) {
      final tx = _crossing(from.dx, dx, to.dx, x);
      final ty = _crossing(from.dy, dy, to.dy, y);
      if (tx == null && ty == null) return;
      // 同じ位置で両方の境目を越えるときは斜めに移る。
      final stepX = tx != null && (ty == null || tx <= ty);
      final stepY = ty != null && (tx == null || ty <= tx);
      if (stepX) x += dx > 0 ? 1 : -1;
      if (stepY) y += dy > 0 ? 1 : -1;
      onCell(x, y, stepX ? tx : ty!);
    }
  }

  /// 1つの軸で、今の画素[cell]から隣へ移る位置（区間の上の0〜1）。
  /// 区間の中で越えなければnull。
  double? _crossing(double from, double delta, double to, int cell) {
    if (delta > 0) {
      final edge = cell + 1 + hysteresis;
      return to > edge ? ((edge - from) / delta).clamp(0.0, 1.0) : null;
    }
    if (delta < 0) {
      final edge = cell - hysteresis;
      return to < edge ? ((edge - from) / delta).clamp(0.0, 1.0) : null;
    }
    return null;
  }
}

/// ドット絵の「ピクセルパーフェクト」：たどった画素の並びから、線を
/// 太らせるだけの画素を取り除いて、1画素ずつ斜めにもつながる線にする。
///
/// 新しい画素が、1つ前に確定した画素の隣（斜めを含む）に来たら、その間の
/// 画素は要らない（L字の角・1画素だけ戻る・とがり）。そのため画素は1つ
/// 遅れて確定する（[add]・[flush]）。同じ並びを渡せば、描いている途中も
/// 描き直しも同じ画素が確定する。
class PixelPerfectPath<T> {
  PixelPerfectPath({this.removeCorners = true});

  /// 偽なら画素を取り除かない（四角形の角のように、角の画素も描く線）。
  final bool removeCorners;

  ({int x, int y})? _first;
  ({int x, int y, T data})? _last;
  ({int x, int y, T data})? _pending;
  int _committed = 0;

  void add(int x, int y, T data, void Function(int x, int y, T data) commit) {
    final last = _last;
    if (last == null) {
      _first = (x: x, y: y);
      _commit((x: x, y: y, data: data), commit);
      return;
    }
    if (!removeCorners) {
      if (last.x != x || last.y != y) _commit((x: x, y: y, data: data), commit);
      return;
    }
    final pending = _pending;
    if (pending == null) {
      if (last.x != x || last.y != y) _pending = (x: x, y: y, data: data);
      return;
    }
    if (pending.x == x && pending.y == y) return;
    if (_touches(last, x, y)) {
      // 確定した画素の隣へ来たので、間の画素は要らない。
      _pending = last.x == x && last.y == y ? null : (x: x, y: y, data: data);
      return;
    }
    _commit(pending, commit);
    _pending = (x: x, y: y, data: data);
  }

  /// 確定を待っている画素を確定する（線の終わり）。[heading]は線の終わりで
  /// ペンが進んでいた向き。
  ///
  /// 終わりの画素が、斜めに進む途中で縦か横に1段だけ動いたもの（次の画素が
  /// 来ればL字の角として取り除く画素）や、進む向きと違う向きへの1段なら
  /// 描かない（線の終わりに足のような1画素が付かない）。輪を描いて最初の
  /// 画素の隣へ戻ったときも、1つ前の画素で輪がつながるなら描かない。
  void flush(
    void Function(int x, int y, T data) commit, {
    Offset heading = Offset.zero,
  }) {
    final pending = _pending;
    final last = _last;
    if (pending == null || last == null) return;
    _pending = null;
    if (removeCorners && _redundantEnd(last, pending, heading)) return;
    _commit(pending, commit);
  }

  bool _redundantEnd(
    ({int x, int y, T data}) last,
    ({int x, int y, T data}) end,
    Offset heading,
  ) {
    final first = _first!;
    if (_committed >= 4 &&
        (last.x != first.x || last.y != first.y) &&
        _touches(last, first.x, first.y) &&
        _touches(end, first.x, first.y)) {
      return true;
    }
    final stepX = end.x != last.x;
    if (stepX && end.y != last.y) return false;
    final along = (stepX ? heading.dx : heading.dy).abs();
    final across = (stepX ? heading.dy : heading.dx).abs();
    return along > 0 || across > 0 ? along <= across * 1.1 : false;
  }

  void _commit(
    ({int x, int y, T data}) cell,
    void Function(int x, int y, T data) commit,
  ) {
    _last = cell;
    _committed++;
    commit(cell.x, cell.y, cell.data);
  }

  static bool _touches(({int x, int y, Object? data}) cell, int x, int y) =>
      (x - cell.x).abs() <= 1 && (y - cell.y).abs() <= 1;
}

/// 太さ[diameter]のドットの形（ドット絵のブラシと同じ、画素の格子に
/// 固定した円）で、左上から[i]列・[j]行の画素を塗るか。1は1画素、2は2×2、
/// 3は十字（3×3の四角だと斜めの段で4画素・45°で5画素の幅になり、線が
/// 太ったり細ったりする）、4以上は画素の中心が円の内側にあるもの。
bool pixelDotCovers(int diameter, int i, int j) {
  if (diameter == 3) return i == 1 || j == 1;
  final ox = i - (diameter - 1) / 2;
  final oy = j - (diameter - 1) / 2;
  return ox * ox + oy * oy < diameter * diameter / 4;
}

/// 画素[cell]を中心にした太さ[diameter]のドットの左上の画素。偶数の太さは
/// 画素の左上の角を中心にする。
int pixelDotOrigin(int cell, int diameter) => cell - diameter ~/ 2;
