import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

/// ペン先が隣の画素の境目をどれだけ越えたら、その画素へ移るか（画素の幅に
/// 対する割合）。手の震えで境目の上を行き来しても、線が隣の行・列と
/// 行ったり来たりしない（ジグザグ・こぶにならない）。
const double kPixelLineHysteresis = 0.35;

/// 同じ軸で直前に進んだのと逆の向きへ戻るときの遊び。手の震えのジグザグは
/// 「1段進んですぐ戻る」の繰り返しなので、戻る向きだけ遊びを大きくする
/// （進み続ける向きは[kPixelLineHysteresis]のまま、線は遅れない）。
const double kPixelLineReverseHysteresis = 0.65;

/// ランの長さを整えるとき、ペン先から何点までを描き直してよいか。これより
/// 前の点は確定していて、ペンを離した後の線と同じ。
const int kPixelRunWindow = 16;

/// 画素の格子点（太さが奇数の線は画素、偶数の線は画素の角）。
typedef PixelPoint = ({int x, int y});

/// ピクセルモードの線が通る格子点を、ペン先の動きからたどる。
///
/// 格子の境目を遊び（[hysteresis]）だけ越えたときに隣へ移るので、通る点は
/// 上下左右に1つずつつながる（境目の角をちょうど通るときだけ斜め）。どの点へ
/// 移るかは線の形だけで決まり、点の細かさ（ゆっくり描いて点が多い・速く描いて
/// まばら）には左右されない。直前に進んだのと逆の向きへ戻るときだけ遊びを
/// [reverseHysteresis]に広げる（震えで隣の行と行き来しない）。
class PixelLineWalker {
  PixelLineWalker(
    Offset start, {
    this.hysteresis = kPixelLineHysteresis,
    double? reverseHysteresis,
  }) : reverseHysteresis = reverseHysteresis ?? hysteresis,
       x = start.dx.floor(),
       y = start.dy.floor();

  final double hysteresis;
  final double reverseHysteresis;

  /// 今いる格子点。
  int x;
  int y;

  // それぞれの軸で最後に進んだ向き（-1・0・1）。
  int _lastX = 0;
  int _lastY = 0;

  /// [from]から[to]へ進む間に移った点を、移った順に[onCell]へ渡す
  /// （[t]はその区間の上で移った位置、0〜1）。[from]は前の区間の終わり。
  void walk(
    Offset from,
    Offset to,
    void Function(int x, int y, double t) onCell,
  ) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    while (true) {
      final tx = _crossing(from.dx, dx, to.dx, x, _lastX);
      final ty = _crossing(from.dy, dy, to.dy, y, _lastY);
      if (tx == null && ty == null) return;
      // 同じ位置で両方の境目を越えるときは斜めに移る。
      final stepX = tx != null && (ty == null || tx <= ty);
      final stepY = ty != null && (tx == null || ty <= tx);
      if (stepX) {
        _lastX = dx > 0 ? 1 : -1;
        x += _lastX;
      }
      if (stepY) {
        _lastY = dy > 0 ? 1 : -1;
        y += _lastY;
      }
      onCell(x, y, stepX ? tx : ty!);
    }
  }

  /// 1つの軸で、今の点[cell]から隣へ移る位置（区間の上の0〜1）。区間の中で
  /// 越えなければnull。[last]はその軸で最後に進んだ向き。
  double? _crossing(double from, double delta, double to, int cell, int last) {
    if (delta > 0) {
      final edge = cell + 1 + (last < 0 ? reverseHysteresis : hysteresis);
      return to > edge ? ((edge - from) / delta).clamp(0.0, 1.0) : null;
    }
    if (delta < 0) {
      final edge = cell - (last > 0 ? reverseHysteresis : hysteresis);
      return to < edge ? ((edge - from) / delta).clamp(0.0, 1.0) : null;
    }
    return null;
  }
}

/// ドット絵の「ピクセルパーフェクト」：たどった点の並びから、線を太らせる
/// だけの点を取り除いて、1点ずつ斜めにもつながる線にする。
///
/// 新しい点が、1つ前に確定した点の隣（斜めを含む）に来たら、その間の点は
/// 要らない（L字の角・1点だけ戻る・とがり）。そのため点は1つ遅れて確定する
/// （[add]・[flush]）。確定を待つ点を先に描くときは[copy]で写して終わらせる。
class PixelPerfectPath<T> {
  PixelPerfectPath({this.removeCorners = true});

  PixelPerfectPath._copy(PixelPerfectPath<T> other)
    : removeCorners = other.removeCorners,
      _first = other._first,
      _last = other._last,
      _pending = other._pending,
      _committed = other._committed;

  /// 偽なら点を取り除かない（四角形の角のように、角の画素も描く線）。
  final bool removeCorners;

  ({int x, int y})? _first;
  ({int x, int y, T data})? _last;
  ({int x, int y, T data})? _pending;
  int _committed = 0;

  PixelPerfectPath<T> copy() => PixelPerfectPath<T>._copy(this);

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
      // 確定した点の隣へ来たので、間の点は要らない。
      _pending = last.x == x && last.y == y ? null : (x: x, y: y, data: data);
      return;
    }
    _commit(pending, commit);
    _pending = (x: x, y: y, data: data);
  }

  /// 確定を待っている点を確定する（線の終わり）。[heading]は線の終わりで
  /// ペンが進んでいた向き。
  ///
  /// 終わりの点が、斜めに進む途中で縦か横に1段だけ動いたもの（次の点が
  /// 来ればL字の角として取り除く点）や、進む向きと違う向きへの1段なら
  /// 描かない（線の終わりに足のような1画素が付かない）。輪を描いて最初の
  /// 点の隣へ戻ったときも、1つ前の点で輪がつながるなら描かない。
  ///
  /// [keepEnd]なら終わりの点も必ず描く（描いている途中のペン先）。
  void flush(
    void Function(int x, int y, T data) commit, {
    Offset heading = Offset.zero,
    bool keepEnd = false,
  }) {
    final pending = _pending;
    final last = _last;
    if (pending == null || last == null) return;
    _pending = null;
    if (removeCorners && !keepEnd && _redundantEnd(last, pending, heading)) {
      return;
    }
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

/// ドット絵の線の段（ラン）の長さを整える。
///
/// 1画素の線は、同じ行（列）に並ぶ画素のかたまり（ラン）が斜めの1段で
/// つながってできる。ゆるい傾き・ゆるい曲線を手で描くと、震えで「3・1・3」の
/// ように両隣より2以上短い（長い）ランが混じり、そこだけ段がつまって見える。
/// ペン先から[window]点までの間で、そのランと隣のランの間の段を1画素ずらして
/// 長さをならす（同じ向きの横の1歩と斜めの1歩を入れ替えるだけなので、線は
/// つながったままで、L字の角もできない）。それより前の点は確定していて
/// 変えない。同じ点の並びを渡せば、描いている途中も描き直しも同じ結果になる。
class PixelRunRegularizer<T> {
  PixelRunRegularizer({this.window = kPixelRunWindow, this.holdLoops = false});

  /// 描き直してよい点の数。0なら何も整えない（図形）。
  final int window;

  /// 輪を閉じて書き始めに沿って進む線の終わりを、確定させずに待つか
  /// （ペンを離したときに、書き始めにくっつくだけの点を落とせるように）。
  final bool holdLoops;

  final List<PixelPoint> _points = [];
  final List<T> _data = [];
  int _frozen = 0;

  /// 確定した点の数。
  int get frozen => _frozen;

  void add(int x, int y, T data) {
    _frozen = _push(_points, _data, 0, _frozen, (x: x, y: y), data);
  }

  /// 確定していない点を、今の点の並びの続きとして[tail]を足したときの
  /// 並び（ペンを今離したときの線）。状態は変えない。
  PixelChain<T> resolve(
    List<({int x, int y, T data})> tail, {
    bool trimLoop = false,
  }) {
    final offset = math.max(0, _frozen - _context);
    final points = _points.sublist(offset);
    final data = _data.sublist(offset);
    var frozen = _frozen;
    for (final cell in tail) {
      frozen = _push(points, data, offset, frozen, (
        x: cell.x,
        y: cell.y,
      ), cell.data);
    }
    var length = offset + points.length;
    if (trimLoop) {
      length = _trimmedLength(
        (i) => i < offset ? _points[i] : points[i - offset],
        frozen,
        length,
      );
    }
    return PixelChain<T>._(_points, _data, offset, points, data, length);
  }

  /// [tail]を足して線を終える。返す並びはどれも確定した点。
  PixelChain<T> finish(
    List<({int x, int y, T data})> tail, {
    bool trimLoop = false,
  }) {
    for (final cell in tail) {
      add(cell.x, cell.y, cell.data);
    }
    var length = _points.length;
    if (trimLoop) length = _trimmedLength((i) => _points[i], _frozen, length);
    _points.length = length;
    _data.length = length;
    _frozen = length;
    return PixelChain<T>._(_points, _data, length, const [], const [], length);
  }

  // ランの長さを数えるのに、確定した点をどこまでさかのぼって見るか。
  int get _context => 3 * window;

  int _push(
    List<PixelPoint> points,
    List<T> data,
    int offset,
    int frozen,
    PixelPoint point,
    T value,
  ) {
    points.add(point);
    data.add(value);
    if (window <= 0) return offset + points.length;
    final from = math.max(0, frozen - _context) - offset;
    _regularize(points, from, frozen - offset);
    final length = offset + points.length;
    var next = math.max(frozen, length - window);
    if (holdLoops) {
      PixelPoint at(int i) => i < offset ? _points[i] : points[i - offset];
      for (var i = frozen; i < next; i++) {
        // 長く沿って進む線は、待ちきれないので確定する。
        if (length - i > window + _head) continue;
        if (_hugsHead(at, i)) {
          next = i;
          break;
        }
      }
    }
    return next;
  }

  // 書き始めの何点に沿って並ぶ線を、輪のはみ出しとみなすか。
  static const int _head = 64;

  /// [index]番目の点が、輪を閉じて書き始めの線（最初の[_head]点）の隣を
  /// 同じ向きに進む点か。逆向きに沿う線（往復して塗る線）は含めない。
  static bool _hugsHead(PixelPoint Function(int i) at, int index) {
    if (index < 40) return false;
    final p = at(index);
    final back = at(index - 3);
    final ux = p.x - back.x, uy = p.y - back.y;
    for (var i = 0; i < _head && i < index - 24; i++) {
      final q = at(i);
      if ((p.x - q.x).abs() > 1 || (p.y - q.y).abs() > 1) continue;
      final ahead = at(math.min(i + 3, index - 24));
      if (ux * (ahead.x - q.x) + uy * (ahead.y - q.y) > 0) return true;
    }
    return false;
  }

  /// 輪を閉じて書き始めのあたりへ戻った線の終わりで、書き始めの線に沿って
  /// くっついて並ぶだけの点（ダマになる）を落とした長さ。[at]は全体の
  /// [length]点のうちの[i]番目。
  static int _trimmedLength(
    PixelPoint Function(int i) at,
    int frozen,
    int length,
  ) {
    if (length < 40) return length;
    final floor = math.max(math.max(frozen, length ~/ 2), 1);
    while (length - 1 >= floor &&
        _hugsHead(at, length - 1) &&
        _hugsHead(at, length - 2)) {
      length--;
    }
    return length;
  }

  /// [points]の[from]から先で、[modifiable]より前の点を変えずにランを整える。
  static void _regularize(List<PixelPoint> points, int from, int modifiable) {
    for (var guard = 0; guard < 64; guard++) {
      if (!_fixOne(points, from, modifiable)) return;
    }
  }

  // 斜めの1歩と、それと同じ向きに進む縦横の1歩の組（8通り）。
  static const List<(int, int, int, int)> _pairs = [
    (1, 0, 1, 1),
    (1, 0, 1, -1),
    (-1, 0, -1, 1),
    (-1, 0, -1, -1),
    (0, 1, 1, 1),
    (0, 1, -1, 1),
    (0, -1, 1, -1),
    (0, -1, -1, -1),
  ];

  static bool _fixOne(List<PixelPoint> points, int from, int modifiable) {
    final n = points.length;
    if (n - from < 6) return false;
    final steps = <(int, int)>[
      for (var i = from; i < n - 1; i++)
        (points[i + 1].x - points[i].x, points[i + 1].y - points[i].y),
    ];
    for (final (ax, ay, dx, dy) in _pairs) {
      bool inPair((int, int) s) =>
          (s.$1 == ax && s.$2 == ay) || (s.$1 == dx && s.$2 == dy);
      var s = 0;
      while (s < steps.length) {
        if (!inPair(steps[s])) {
          s++;
          continue;
        }
        var e = s;
        while (e < steps.length && inPair(steps[e])) {
          e++;
        }
        for (final runIsAxis in const [true, false]) {
          final fix = _findJag(
            steps,
            s,
            e,
            (s) => runIsAxis
                ? (s.$1 == dx && s.$2 == dy)
                : !(s.$1 == dx && s.$2 == dy),
            from,
            modifiable,
          );
          if (fix != null) {
            // 隣り合う2歩を入れ替える：その間の点が1画素ずれる。
            final a = steps[fix], b = steps[fix + 1];
            final at = from + fix + 1;
            points[at] = (
              x: points[at - 1].x + b.$1,
              y: points[at - 1].y + b.$2,
            );
            assert(
              points[at].x + a.$1 == points[at + 1].x &&
                  points[at].y + a.$2 == points[at + 1].y,
            );
            return true;
          }
        }
        s = e;
      }
    }
    return false;
  }

  /// 区間[s, e)の歩みで、区切り（[isSeparator]）の間のランに、両隣より2以上
  /// 短い・長いものがあれば、入れ替える2歩の前の方の位置を返す。
  static int? _findJag(
    List<(int, int)> steps,
    int s,
    int e,
    bool Function((int, int)) isSeparator,
    int from,
    int modifiable,
  ) {
    final separators = [
      for (var i = s; i < e; i++)
        if (isSeparator(steps[i])) i,
    ];
    if (separators.length < 2) return null;
    // ラン：区切りの前・間・後。端のランは、線の始まり・並びの端で切れて
    // いれば長さが分からないので比べない。
    final runs = <({int length, bool bounded})>[
      (length: separators.first - s, bounded: s > 0),
      for (var j = 0; j + 1 < separators.length; j++)
        (length: separators[j + 1] - separators[j] - 1, bounded: true),
      (length: e - separators.last - 1, bounded: e < steps.length),
    ];
    // 入れ替えた後も、前後の歩みとL字の角（横の1歩と縦の1歩が続く）を
    // 作らないこと。
    bool lCorner((int, int) a, (int, int) b) =>
        (a.$2 == 0 && b.$1 == 0) || (a.$1 == 0 && b.$2 == 0);
    bool movable(int pointIndex) {
      if (from + pointIndex < modifiable) return false;
      final q = pointIndex - 1; // 入れ替える2歩の前の方
      if (q < 0 || q + 1 >= steps.length) return false;
      if (q == 0 && from > 0) return false;
      if (q > 0 && lCorner(steps[q - 1], steps[q + 1])) return false;
      if (q + 2 < steps.length && lCorner(steps[q], steps[q + 2])) {
        return false;
      }
      return true;
    }

    for (var j = 1; j + 1 < runs.length; j++) {
      final a = runs[j - 1], b = runs[j], c = runs[j + 1];
      if (!a.bounded || !c.bounded) continue;
      final before = separators[j - 1]; // bの前の区切り
      final after = separators[j]; // bの後の区切り
      if (b.length <= math.min(a.length, c.length) - 2) {
        // 短いラン：長い方の隣から1歩もらう。
        final fromC = movable(after + 1);
        final fromA = movable(before);
        if (c.length >= a.length && fromC) return after;
        if (fromA) return before - 1;
        if (fromC) return after;
      } else if (b.length >= math.max(a.length, c.length) + 2) {
        // 長いラン：短い方の隣へ1歩渡す。
        final toC = movable(after);
        final toA = movable(before + 1);
        if (c.length <= a.length && toC) return after - 1;
        if (toA) return before;
        if (toC) return after - 1;
      }
    }
    return null;
  }
}

/// 1画素の線の点の並び（確定した前半と、まだ変わりうる後半）。
class PixelChain<T> {
  PixelChain._(
    this._base,
    this._baseData,
    this._split,
    this._tail,
    this._tailData,
    this.length,
  );

  /// 図形のように、並びを丸ごと渡す。
  PixelChain.of(List<PixelPoint> points, List<T> data)
    : _base = points,
      _baseData = data,
      _split = points.length,
      _tail = const [],
      _tailData = const [],
      length = points.length;

  final List<PixelPoint> _base;
  final List<T> _baseData;
  // [_split]より前は[_base]、そこから先は[_tail]（[_base]の[_split]番目から
  // 写して続きを足したもの）。
  final int _split;
  final List<PixelPoint> _tail;
  final List<T> _tailData;
  final int length;

  PixelPoint operator [](int i) => i < _split ? _base[i] : _tail[i - _split];

  /// 最初の[count]点だけの並び。
  PixelChain<T> prefix(int count) =>
      PixelChain<T>._(_base, _baseData, _split, _tail, _tailData, count);

  T dataAt(int i) => i < _split ? _baseData[i] : _tailData[i - _split];
}

/// ペン先の動きから、ピクセルモードの1本の線の点の並びを作る：画素の境目の
/// 遊びでたどり（[PixelLineWalker]）、L字の角を取り（[PixelPerfectPath]）、
/// ペン先の近くでランを整える（[PixelRunRegularizer]）。
///
/// [resolve]は、ペンを今離したときの線（ペンの下の画素まで）を返す：
/// 描いている途中はこれを描き、ペンを離すと[finish]が同じ並びを確定する。
/// [corners]なら画素の角を格子点にする（太さが偶数の線の中心）。
class PixelLineTracer<T> {
  PixelLineTracer(
    Offset start,
    T data, {
    this.corners = false,
    double hysteresis = kPixelLineHysteresis,
    double reverseHysteresis = kPixelLineReverseHysteresis,
    bool removeCorners = true,
    int window = kPixelRunWindow,
    this.trimLoop = true,
  }) : _walker = PixelLineWalker(
         start + Offset(corners ? 0.5 : 0, corners ? 0.5 : 0),
         hysteresis: hysteresis,
         reverseHysteresis: reverseHysteresis,
       ),
       _path = PixelPerfectPath<T>(removeCorners: removeCorners),
       _runs = PixelRunRegularizer<T>(window: window, holdLoops: trimLoop),
       _pen = start,
       _penData = data {
    _trail.add(start);
    _path.add(_walker.x, _walker.y, data, _runs.add);
  }

  /// 画素の角を格子点にするか（偽なら画素）。
  final bool corners;

  /// 輪を閉じた線の終わりで、最初の点にくっつくだけの点を落とすか。
  final bool trimLoop;

  final PixelLineWalker _walker;
  final PixelPerfectPath<T> _path;
  final PixelRunRegularizer<T> _runs;
  final List<Offset> _trail = [];
  Offset _pen;
  T _penData;

  /// 確定した点の数（これより前の点は、この先もペンを離しても変わらない）。
  int get frozen => _runs.frozen;

  void walk(Offset from, Offset to, T Function(double t) dataAt) {
    final shift = Offset(corners ? 0.5 : 0, corners ? 0.5 : 0);
    _walker.walk(
      from + shift,
      to + shift,
      (x, y, t) => _path.add(x, y, dataAt(t), _runs.add),
    );
    _pen = to;
    _penData = dataAt(1);
    _trail.add(to);
  }

  /// 描いている途中の線：確定した点に、ペンの下の点までの続きを足したもの
  /// （ペンの下の画素は必ず描く）。
  PixelChain<T> resolve() {
    final tail = <({int x, int y, T data})>[];
    _end(
      _path.copy(),
      (x, y, data) => tail.add((x: x, y: y, data: data)),
      live: true,
    );
    return _runs.resolve(tail, trimLoop: trimLoop);
  }

  /// 線を終える。
  PixelChain<T> finish() {
    final tail = <({int x, int y, T data})>[];
    _end(_path, (x, y, data) => tail.add((x: x, y: y, data: data)));
    return _runs.finish(tail, trimLoop: trimLoop);
  }

  /// ペンの下の点まで1歩進め、確定を待つ点を確定する。
  ///
  /// 描いている途中（[live]）はペンの下の点まで進んで必ず描く（次の点が来れば
  /// 取り除く点でも）。線を終えるときは、進んでいた向きにだけ進む（画素の
  /// 境目を少し越えただけで止めた線も、ペンの下の画素まで届く。横へずれた
  /// 震えで線の終わりに鉤が付かない）。
  void _end(
    PixelPerfectPath<T> path,
    void Function(int x, int y, T data) commit, {
    bool live = false,
  }) {
    final px = (_pen.dx + (corners ? 0.5 : 0)).floor();
    final py = (_pen.dy + (corners ? 0.5 : 0)).floor();
    var sx = (px - _walker.x).sign;
    var sy = (py - _walker.y).sign;
    final heading = _heading();
    if (!live) {
      final length = heading.distance;
      bool along(int step, double component) =>
          step != 0 && component * step >= 0.4 * length;
      if (!along(sx, heading.dx)) sx = 0;
      if (!along(sy, heading.dy)) sy = 0;
    }
    if (sx != 0 || sy != 0) {
      path.add(_walker.x + sx, _walker.y + sy, _penData, commit);
    }
    path.flush(commit, heading: heading, keepEnd: live);
  }

  /// 線の終わりでペンが進んでいた向き（最後の3pxほど）。
  Offset _heading() {
    if (_trail.length < 2) return Offset.zero;
    final end = _trail.last;
    for (var i = _trail.length - 2; i >= 0; i--) {
      final heading = end - _trail[i];
      if (heading.distance >= 3) return heading;
    }
    return end - _trail.first;
  }
}

/// 画素の集まり（ドット・線の断面・ペン先の形）。
class PixelMask {
  PixelMask._(this.left, this.top, this.width, this.height, this._bits);

  /// 左上[left]・[top]から[width]×[height]の空の形。
  factory PixelMask.empty(int left, int top, int width, int height) =>
      PixelMask._(left, top, width, height, Uint8List(width * height));

  final int left;
  final int top;
  final int width;
  final int height;
  final Uint8List _bits;

  int get right => left + width;
  int get bottom => top + height;

  bool contains(int x, int y) {
    final i = x - left, j = y - top;
    return i >= 0 &&
        j >= 0 &&
        i < width &&
        j < height &&
        _bits[j * width + i] != 0;
  }

  void _set(int x, int y) => _bits[(y - top) * width + (x - left)] = 1;

  bool get isEmpty => !_bits.any((b) => b != 0);

  /// 塗る画素。
  Iterable<PixelPoint> get pixels sync* {
    for (var j = 0; j < height; j++) {
      for (var i = 0; i < width; i++) {
        if (_bits[j * width + i] != 0) yield (x: left + i, y: top + j);
      }
    }
  }

  /// [masks]のどれかが塗る画素。
  static PixelMask union(List<PixelMask> masks) {
    if (masks.length == 1) return masks.first;
    var l = masks.first.left, t = masks.first.top;
    var r = masks.first.right, b = masks.first.bottom;
    for (final m in masks.skip(1)) {
      l = math.min(l, m.left);
      t = math.min(t, m.top);
      r = math.max(r, m.right);
      b = math.max(b, m.bottom);
    }
    final out = PixelMask.empty(l, t, r - l, b - t);
    for (final m in masks) {
      for (var j = 0; j < m.height; j++) {
        for (var i = 0; i < m.width; i++) {
          if (m._bits[j * m.width + i] != 0) out._set(m.left + i, m.top + j);
        }
      }
    }
    return out;
  }

  /// 塗る画素から[radius]画素以内（太さ2×[radius]＋1のドットの形）まで
  /// 広げた形（ドットの縁取り）。
  PixelMask dilate(int radius) {
    if (radius <= 0) return this;
    final d = 2 * radius + 1;
    final offsets = <(int, int)>[
      for (var j = 0; j < d; j++)
        for (var i = 0; i < d; i++)
          if (pixelDotCovers(d, i, j)) (i - radius, j - radius),
    ];
    final out = PixelMask.empty(
      left - radius,
      top - radius,
      width + 2 * radius,
      height + 2 * radius,
    );
    for (var j = 0; j < height; j++) {
      for (var i = 0; i < width; i++) {
        if (_bits[j * width + i] == 0) continue;
        for (final (ox, oy) in offsets) {
          out._set(left + i + ox, top + j + oy);
        }
      }
    }
    return out;
  }

  /// 格子点[point]を中心にした太さ[diameter]のドット（[pixelDotCovers]）。
  static PixelMask dot(PixelPoint point, int diameter) {
    final d = math.max(1, diameter);
    final out = PixelMask.empty(
      pixelDotOrigin(point.x, d),
      pixelDotOrigin(point.y, d),
      d,
      d,
    );
    for (var j = 0; j < d; j++) {
      for (var i = 0; i < d; i++) {
        if (pixelDotCovers(d, i, j)) out._bits[j * d + i] = 1;
      }
    }
    return out;
  }

  /// 格子点[point]を中心にした[diameter]四方の四角（四角形の角）。
  static PixelMask square(PixelPoint point, int diameter) {
    final d = math.max(1, diameter);
    final out = PixelMask.empty(
      pixelDotOrigin(point.x, d),
      pixelDotOrigin(point.y, d),
      d,
      d,
    );
    out._bits.fillRange(0, d * d, 1);
    return out;
  }
}

/// 太さ[diameter]のピクセルの線が、点の並び[chain]の[k]番目の点から次の点
/// までに塗る画素。
///
/// 線は、1画素の線（[chain]）を少しならした中心線（前後[_smoothing]点の
/// 平均）から、直角に測って太さの半分より近くに中心がある画素を塗る（太さが
/// 一定の帯）。どの角度でも、曲線でも線に直角な太さがそろい、縁は中心線を
/// 平行にずらした線になるので、ドットを重ねたときのような段ごとのこぶが
/// できない。線の両端（[closed]でなければ）はその太さのドットの形で終える。
/// [squareCorners]なら、四角形の角のように折れた所を四角く埋める。
/// [corners]なら格子点は画素の角（偽なら画素）。
PixelMask pixelLineMask(
  PixelChain<Object?> chain,
  int k,
  int diameter, {
  required bool corners,
  bool closed = false,
  bool squareCorners = false,
}) {
  final n = chain.length;
  final p = chain[k];
  final d = math.max(1, diameter);
  if (d == 1 || n == 1) return PixelMask.dot(p, d);
  final last = closed ? n : n - 1;
  final ends = <PixelMask>[];
  if (!closed && k == 0) ends.add(PixelMask.dot(p, d));
  if (!closed && k == n - 1) return PixelMask.dot(p, d);
  final smoothing = squareCorners ? 0 : _smoothing;
  final a = _smoothedCentre(chain, k, closed, corners, d, smoothing);
  final b = _smoothedCentre(chain, k + 1, closed, corners, d, smoothing);
  final r = d / 2;
  final reach = r.ceil() + 1;
  final left = (math.min(a.dx, b.dx) - reach).floor();
  final top = (math.min(a.dy, b.dy) - reach).floor();
  final right = (math.max(a.dx, b.dx) + reach).ceil();
  final bottom = (math.max(a.dy, b.dy) + reach).ceil();
  final band = PixelMask.empty(left, top, right - left, bottom - top);
  final vx = b.dx - a.dx, vy = b.dy - a.dy;
  final vv = vx * vx + vy * vy;
  final rr = r * r - 1e-9;
  // 線の両端は、ドットの形で終える（帯の丸い端は使わない）。
  final cutStart = !closed && k == 0;
  final cutEnd = !closed && k + 1 == last;
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      final px = x + 0.5 - a.dx, py = y + 0.5 - a.dy;
      var t = vv == 0 ? 0.0 : (px * vx + py * vy) / vv;
      if ((cutStart && t < 0) || (cutEnd && t > 1)) continue;
      t = t.clamp(0.0, 1.0);
      final ex = px - vx * t, ey = py - vy * t;
      if (ex * ex + ey * ey < rr) band._set(x, y);
    }
  }
  final masks = [band, ...ends];
  if (cutEnd) masks.add(PixelMask.dot(chain[k + 1], d));
  if (squareCorners) {
    final turn = 2;
    if (closed || (k - turn >= 0 && k + turn <= n - 1)) {
      PixelPoint at(int i) => chain[((i % n) + n) % n];
      final u = at(k - turn), v = at(k + turn);
      final ux = p.x - u.x, uy = p.y - u.y, wx = v.x - p.x, wy = v.y - p.y;
      final cross = ux * wy - uy * wx;
      if (cross != 0 && ux * wx + uy * wy == 0) {
        masks.add(PixelMask.square(p, d));
      }
    }
  }
  return PixelMask.union(masks);
}

/// 線の太さを決める中心線のならし幅（前後の点の数）。
const int _smoothing = 3;

/// [k]番目の点の、ならした中心（画素の座標）。前後[smoothing]点の平均で、
/// 線の端では窓を縮めて、端の点はそのまま。
///
/// 45°の線は格子の斜めの並びにぴったり乗るので、帯の1列の画素の数が太さで
/// 奇数か偶数に決まってしまう（太さ3は5画素で18%太い）。太さ×√2により近い
/// 数になる方へ、45°の近くでだけ中心を線に直角に斜めの格子の半分
/// （0.35画素）ずらす。ずらす向きは進む向きの左なので、閉じた形は
/// どこでも同じ側へずれて形が崩れない。
Offset _smoothedCentre(
  PixelChain<Object?> chain,
  int k,
  bool closed,
  bool corners,
  int diameter,
  int smoothing,
) {
  final n = chain.length;
  PixelPoint at(int i) => chain[((i % n) + n) % n];
  var s = smoothing;
  if (!closed) s = math.min(s, math.min(k, n - 1 - k));
  var sx = 0, sy = 0;
  for (var i = k - s; i <= k + s; i++) {
    final q = at(i);
    sx += q.x;
    sy += q.y;
  }
  final count = 2 * s + 1;
  final shift = corners ? 0.0 : 0.5;
  var cx = sx / count + shift, cy = sy / count + shift;
  if (_prefersHalfDiagonalPhase(diameter)) {
    final lo = closed ? k - _smoothing : math.max(0, k - _smoothing);
    final hi = closed ? k + _smoothing : math.min(n - 1, k + _smoothing);
    final dx = (at(hi).x - at(lo).x).toDouble();
    final dy = (at(hi).y - at(lo).y).toDouble();
    final length = math.sqrt(dx * dx + dy * dy);
    if (length > 0) {
      // 近い方の軸からの角度（0〜45°）。38°から43°でずらし切る。
      final angle =
          math.atan2(
            math.min(dx.abs(), dy.abs()),
            math.max(dx.abs(), dy.abs()),
          ) *
          180 /
          math.pi;
      final amount = 0.5 / math.sqrt2 * ((angle - 38) / 5).clamp(0.0, 1.0);
      cx += dy / length * amount;
      cy -= dx / length * amount;
    }
  }
  return Offset(cx, cy);
}

/// 太さ[diameter]の45°の線で、1列の画素の数を偶数（中心を半画素ずらす）に
/// した方が、太さ×√2に近いか。
bool _prefersHalfDiagonalPhase(int diameter) {
  final half = diameter / math.sqrt2;
  final odd = 2 * (half - 1e-9).ceil() - 1;
  final even = 2 * (half + 0.5).floor();
  final target = diameter * math.sqrt2;
  return (even - target).abs() < (odd - target).abs();
}

/// 画素の格子の点で、左上[x0]・[y0]から右下[x1]・[y1]までの四角に
/// 内接する楕円（中点法の楕円。Zinglの「A Rasterizing Algorithm for Drawing
/// Curves」）を、輪をたどる順に返す（最後の点は最初の点の隣で、重ならない）。
List<PixelPoint> pixelEllipse(int x0, int y0, int x1, int y1) {
  if (x0 > x1) (x0, x1) = (x1, x0);
  if (y0 > y1) (y0, y1) = (y1, y0);
  final a = x1 - x0, b = y1 - y0;
  var b1 = b & 1;
  var dx = 4.0 * (1 - a) * b * b;
  var dy = 4.0 * (b1 + 1) * a * a;
  var err = dx + dy + b1 * a * a;
  var lowY = y0 + (b + 1) ~/ 2;
  var highY = lowY - b1;
  final aa = 8.0 * a * a;
  final bb = 8.0 * b * b;
  var left = x0, right = x1;
  // 右下・左下・左上・右上の4分の1ずつ（横の端から縦の端へ）。
  final q1 = <PixelPoint>[], q2 = <PixelPoint>[];
  final q3 = <PixelPoint>[], q4 = <PixelPoint>[];
  do {
    q1.add((x: right, y: lowY));
    q2.add((x: left, y: lowY));
    q3.add((x: left, y: highY));
    q4.add((x: right, y: highY));
    final e2 = 2 * err;
    if (e2 <= dy) {
      lowY++;
      highY--;
      dy += aa;
      err += dy;
    }
    if (e2 >= dx || 2 * err > dy) {
      left++;
      right--;
      dx += bb;
      err += dx;
    }
  } while (left <= right);
  // 細い楕円は横の端が先に来るので、縦の端まで伸ばす。
  while (lowY - highY <= b) {
    q1.add((x: right + 1, y: lowY));
    q2.add((x: left - 1, y: lowY));
    q3.add((x: left - 1, y: highY));
    q4.add((x: right + 1, y: highY));
    lowY++;
    highY--;
  }
  // L字の角が出ないように、4分の1ずつ同じ向きに整える（左右・上下の
  // 対称を崩さない）。
  List<PixelPoint> clean(List<PixelPoint> quarter) {
    final out = <PixelPoint>[];
    final path = PixelPerfectPath<void>();
    for (final p in quarter) {
      path.add(p.x, p.y, null, (x, y, _) => out.add((x: x, y: y)));
    }
    path.flush((x, y, _) => out.add((x: x, y: y)), keepEnd: true);
    return out;
  }

  final ring = <PixelPoint>[
    ...clean(q1),
    ...clean(q2).reversed,
    ...clean(q3),
    ...clean(q4).reversed,
  ];
  // とても平たい・細い楕円は、端の1画素の幅の所を行って戻るので、同じ
  // 画素を2度描かない。
  final seen = <PixelPoint>{};
  return [
    for (final p in ring)
      if (seen.add(p)) p,
  ];
}

/// 太さ[diameter]のペン先の形を画素の格子に写したもの（左上は格子点からの
/// ずれ）。[ratio]は幅の割合（カリグラフィーの平たいペン先）、[angle]は
/// 向き（ラジアン）。[alpha]を渡すとその画像（[alphaSize]四方、RGBAの
/// 不透明度）の形、渡さなければ円。
///
/// 格子点[point]（[corners]なら画素の角、偽なら画素）を中心に置く。
/// 画素の中心が形の中に入る画素を塗る（画像は画素ごとの範囲の平均が半分
/// 以上）。細いペン先は、長い向きの1画素の線も塗る（途切れないように）。
PixelMask pixelTipMask(
  PixelPoint point,
  int diameter, {
  required bool corners,
  double ratio = 1,
  double angle = 0,
  Uint8List? alpha,
  int alphaSize = 0,
}) {
  final d = math.max(1, diameter);
  final key =
      '$d|${ratio.toStringAsFixed(3)}|${angle.toStringAsFixed(4)}|'
      '${alpha == null ? 0 : identityHashCode(alpha)}|$corners';
  final shape = _tipShapes[key] ??= _tipShape(
    d,
    ratio: ratio,
    angle: angle,
    alpha: alpha,
    alphaSize: alphaSize,
    corners: corners,
  );
  if (_tipShapes.length > 512) _tipShapes.remove(_tipShapes.keys.first);
  final out = PixelMask.empty(
    point.x + shape.left,
    point.y + shape.top,
    shape.width,
    shape.height,
  );
  out._bits.setAll(0, shape._bits);
  return out;
}

final Map<String, PixelMask> _tipShapes = {};

PixelMask _tipShape(
  int d, {
  required double ratio,
  required double angle,
  required Uint8List? alpha,
  required int alphaSize,
  required bool corners,
}) {
  final r = d / 2;
  final reach = (r * math.sqrt2).ceil() + 1;
  final out = PixelMask.empty(-reach, -reach, 2 * reach + 1, 2 * reach + 1);
  final cosA = math.cos(angle), sinA = math.sin(angle);
  final flat = ratio.clamp(0.05, 1.0);
  // 中心（格子点の画素の左上から）。
  final cx = corners ? 0.0 : 0.5, cy = cx;
  for (var j = -reach; j <= reach; j++) {
    for (var i = -reach; i <= reach; i++) {
      final u = i + 0.5 - cx, v = j + 0.5 - cy;
      // ペン先の向きへ戻す（幅の向きがx）。
      final lu = (u * cosA + v * sinA) / flat;
      final lv = -u * sinA + v * cosA;
      final nx = lu / r, ny = lv / r;
      bool inside;
      if (alpha == null) {
        inside = nx * nx + ny * ny < 1;
      } else {
        inside = _alphaCovers(alpha, alphaSize, nx, ny, 1 / (r * flat), 1 / r);
      }
      if (inside) out._set(i, j);
    }
  }
  if (alpha == null && flat < 1) {
    // 長い向き（幅に直角）の1画素の線。
    final steps = (2 * r).ceil() * 2;
    for (var s = 0; s <= steps; s++) {
      final t = -r + 0.5 + (2 * r - 1) * s / steps;
      final x = (cx - t * sinA).floor(), y = (cy + t * cosA).floor();
      if (x.abs() <= reach && y.abs() <= reach) out._set(x, y);
    }
  }
  if (out.isEmpty) out._set(0, 0);
  return out;
}

/// 画像の、正規化した位置（[nx]・[ny]、-1〜1）のまわりの画素1つぶん
/// （幅[sx]・[sy]）の不透明度の平均が半分以上か。
bool _alphaCovers(
  Uint8List alpha,
  int size,
  double nx,
  double ny,
  double sx,
  double sy,
) {
  if (nx.abs() > 1 + sx || ny.abs() > 1 + sy) return false;
  var sum = 0.0;
  var count = 0;
  const samples = 3;
  for (var b = 0; b < samples; b++) {
    for (var a = 0; a < samples; a++) {
      final x = nx + sx * ((a + 0.5) / samples - 0.5);
      final y = ny + sy * ((b + 0.5) / samples - 0.5);
      count++;
      if (x.abs() > 1 || y.abs() > 1) continue;
      final tx = ((x + 1) * size / 2).floor().clamp(0, size - 1);
      final ty = ((y + 1) * size / 2).floor().clamp(0, size - 1);
      sum += alpha[(ty * size + tx) * 4 + 3];
    }
  }
  return sum / count >= 128;
}

/// 太さ[diameter]のドットの形（ドット絵のブラシと同じ、画素の格子に
/// 固定した円）で、左上から[i]列・[j]行の画素を塗るか。1は1画素、2は2×2、
/// 3は十字、4以上は画素の中心が円の内側にあるもの。
bool pixelDotCovers(int diameter, int i, int j) {
  if (diameter == 3) return i == 1 || j == 1;
  final ox = i - (diameter - 1) / 2;
  final oy = j - (diameter - 1) / 2;
  return ox * ox + oy * oy < diameter * diameter / 4;
}

/// 格子点[cell]を中心にした太さ[diameter]のドットの左上の画素。偶数の太さは
/// 格子点を画素の角として、その角を中心にする。
int pixelDotOrigin(int cell, int diameter) => cell - diameter ~/ 2;
