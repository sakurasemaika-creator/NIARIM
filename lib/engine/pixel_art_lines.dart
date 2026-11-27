import 'dart:math' as math;
import 'dart:typed_data';

/// ドット絵フィルターで、細い線（変換後に2.5ドット未満の太さの線）を
/// ドット絵の線として描き直すための解析。
///
/// 普通のドットの色は、そのドットに入る画素の色を混ぜて決まる。そのため
/// 細い線は、真ん中を通るドットは濃く、2つのドットにまたがる所は両方が線と
/// 紙の中間の色になり（1本の線が数珠つなぎのまだらになる）、線がわずかに
/// かかるだけのドットも薄い色で残り（斜めの段ごとにL字の余分な点が付く）、
/// 何ドットの太さになるかもドットの中の位置で変わる（1ドットと2ドットが
/// 混ざる）。そこで細い線は、元の絵から中心線を取り出し、ペンの
/// ピクセルモードと同じ考え方で格子の上へ描き直す：
/// - 中心線が通るドットを、L字の角を取り除いて斜めにもつながる1本の
///   並びにする（ピクセルパーフェクト。端と分かれ目のドットは残す）；
/// - 太さは線ごとに1つ（元の線の幅をドットの大きさで割って丸めた1か2）で、
///   並びの各ドットに決まった形（1は1ドット、2は2×2）を置く；
/// - 色も線ごとに1つ（線の芯の色）。
/// 描き直した線のインクは、ほかのドットの色から外す（線から外れたドットは
/// その下の地の色になる）。
///
/// 線と見なすのは、両側より暗い（紙の上の線）か両側より不透明な（透明な
/// レイヤーの線）細い形で、両側と端の先が実際に地になっているものだけ。
/// 塗りの面・ぼかし・グラデーション・細かい模様（線が1ドットより密に並ぶ
/// 所）・塗った形の一部（線とほぼ同じ暗さの塗りに触れる線、とがり）は
/// 対象外で、細い線の無い絵では何も見つからない（ドット絵の結果は以前と
/// 1ビットも変わらない）。
///
/// 解析は元の絵の画素の位置だけで決まり（線の中心は線を横切る断面の
/// インクの重心で小数まで測る）、たどる向きにも左右されない。
/// アニメーションでコマごとに絵が少しずつ動いても、線は中心線がドットの
/// 境目を越えた所でだけ1ドット動く。
class PixelArtLines {
  PixelArtLines._(this.line, this.color, this.alpha, this.inked, this.cover);

  /// ドットごと：線として描くなら1。
  final Uint8List line;

  /// ドットごと：線の色（不透明のRGB、0xffrrggbb）。
  final Int32List color;

  /// ドットごと：線の不透明度。
  final Uint8List alpha;

  /// 画素ごと：描き直した線のインクなら1（そのドットの地の色から外す）。
  final Uint8List inked;

  /// ドットごと：描き直した線のインクがドットを覆う割合（0〜1）。
  final Float64List cover;

  /// 線と見なす暗さの差（紙の上の線、0〜255の明るさ）の下限。
  static const int _minDark = 32;

  /// これより濃いインクは、周りの明るさによらず線の形に入れる（0〜255）。
  static const int _fullInk = 217;

  /// 線の横の塗りを地と見なす、線の芯との明るさの差（0〜255）の下限。
  static const int _sideContrast = 48;

  /// 線と見なす不透明度の差（透明なレイヤーの線）の下限。
  static const int _minAlpha = 64;

  /// これより薄いインクは線の一部として数えない（0〜255）。
  static const int _faint = 5;

  /// 線が隣の行（列）へこの割合（ドット）より浅くしか入らずに戻るなら、
  /// 前後と同じ行（列）にそろえる。
  static const double _shallow = 0.25;

  /// 描き直す線の太さの上限（ドット）。これ以上の太さは塗りの面として扱う。
  static const double _maxDots = 2.5;

  /// 線のドットの周り7×7ドットのうち、線のドットがこの割合を超える線は、
  /// 細かい模様の一部として描き直さない（1ドットより密に並ぶ線を1本ずつ
  /// 描くと、模様の濃淡が消えて塗りつぶしになる。2ドットおきの線や、
  /// 隣り合う2〜3本の線は描き直す）。
  static const double _crowded = 0.5;

  /// min(255, d × 255 ÷ depth)（[depth] << 8 | [d]、depthは1以上）。
  static final Uint8List _ratio = () {
    final table = Uint8List(1 << 16);
    for (var depth = 1; depth < 256; depth++) {
      for (var d = 0; d < 256; d++) {
        table[depth << 8 | d] = math.min(255, d * 255 ~/ depth);
      }
    }
    return table;
  }();

  /// 8近傍のずれ（上から時計回り）。
  static const _ring = [
    (0, -1),
    (1, -1),
    (1, 0),
    (1, 1),
    (0, 1),
    (-1, 1),
    (-1, 0),
    (-1, -1),
  ];

  /// [data]（乗算済みRGBA）の細い線を、[xs]・[ys]で区切ったドットの格子の
  /// 上の線として描き直す情報。細い線が無ければnull。
  ///
  /// [halfResolution]が真なら、4〜7画素のドットでも縦横半分に縮めた絵で
  /// 探す（1ドットが2画素以上）。
  static PixelArtLines? find(
    Uint8List data,
    int width,
    int height,
    List<int> xs,
    List<int> ys,
    double size, {
    bool halfResolution = false,
  }) {
    if (size < 2 || width < 3 || height < 3) return null;
    // 大きなドットでは、中心線を探すのに元の細かさは要らない：縦横を
    // 1/scale に縮めた絵（画素の平均：線のインクの量は変わらない）で探し、
    // 1ドットが4画素以上になるようにする。線の色は元の絵の芯の画素から取る。
    var scale = math.max(1, math.min(4, (size / 4).floor()));
    if (halfResolution && scale == 1 && size >= 4) scale = 2;
    if (scale == 1) {
      return _findAt(
        data,
        width,
        height,
        xs,
        ys,
        size,
        1,
        data,
        width,
        height,
        null,
      );
    }
    final sw = (width + scale - 1) ~/ scale, sh = (height + scale - 1) ~/ scale;
    final small = Uint8List(sw * sh * 4);
    // 画素を4バイトずつ読む（リトルエンディアンでRGBAは下の桁から）：
    // R・Bと G・Aを16ビットずつの2組にして足す（16画素×255でも溢れない）。
    final words = Endian.host == Endian.little && data.offsetInBytes % 4 == 0
        ? data.buffer.asUint32List(data.offsetInBytes, width * height)
        : null;
    // 欠けていないブロック（scale×scale画素）の平均は表で引く。
    final whole = scale * scale;
    final average = Uint8List(255 * whole + 1);
    for (var v = 0; v < average.length; v++) {
      average[v] = (v + whole ~/ 2) ~/ whole;
    }
    var allOf = 0xffffffff;
    for (var y = 0; y < sh; y++) {
      final y0 = y * scale, y1 = math.min(height, y0 + scale);
      for (var x = 0; x < sw; x++) {
        final x0 = x * scale, x1 = math.min(width, x0 + scale);
        final count = (y1 - y0) * (x1 - x0);
        var r = 0, g = 0, b = 0, a = 0;
        if (words != null && count == 4 && scale == 2) {
          final p = y0 * width + x0;
          final v0 = words[p], v1 = words[p + 1];
          final v2 = words[p + width], v3 = words[p + width + 1];
          allOf &= v0 & v1 & v2 & v3;
          final rb =
              (v0 & 0x00ff00ff) +
              (v1 & 0x00ff00ff) +
              (v2 & 0x00ff00ff) +
              (v3 & 0x00ff00ff);
          final ga =
              ((v0 >> 8) & 0x00ff00ff) +
              ((v1 >> 8) & 0x00ff00ff) +
              ((v2 >> 8) & 0x00ff00ff) +
              ((v3 >> 8) & 0x00ff00ff);
          r = rb & 0xffff;
          b = rb >> 16;
          g = ga & 0xffff;
          a = ga >> 16;
        } else if (words != null) {
          var rb = 0, ga = 0;
          for (var yy = y0; yy < y1; yy++) {
            for (var p = yy * width + x0, e = yy * width + x1; p < e; p++) {
              final v = words[p];
              allOf &= v;
              rb += v & 0x00ff00ff;
              ga += (v >> 8) & 0x00ff00ff;
            }
          }
          r = rb & 0xffff;
          b = rb >> 16;
          g = ga & 0xffff;
          a = ga >> 16;
        } else {
          for (var yy = y0; yy < y1; yy++) {
            var i = (yy * width + x0) * 4;
            for (var xx = x0; xx < x1; xx++, i += 4) {
              r += data[i];
              g += data[i + 1];
              b += data[i + 2];
              a += data[i + 3];
              allOf &= data[i + 3] << 24;
            }
          }
        }
        final o = (y * sw + x) * 4;
        if (count == whole) {
          small[o] = average[r];
          small[o + 1] = average[g];
          small[o + 2] = average[b];
          small[o + 3] = average[a];
        } else {
          small[o] = (r + count ~/ 2) ~/ count;
          small[o + 1] = (g + count ~/ 2) ~/ count;
          small[o + 2] = (b + count ~/ 2) ~/ count;
          small[o + 3] = (a + count ~/ 2) ~/ count;
        }
      }
    }
    // 縮める前の絵がすべて不透明か。
    final all = allOf >> 24;
    return _findAt(
      small,
      sw,
      sh,
      xs,
      ys,
      size / scale,
      scale,
      data,
      width,
      height,
      all == 255,
    );
  }

  /// [find]の本体：[data]（[width]×[height]）は元の絵を[scale]分の1に
  /// 縮めたもの、[size]はその上でのドットの大きさ。[xs]・[ys]と結果は元の
  /// 絵（[full]、[fullWidth]×[fullHeight]）の上。
  static PixelArtLines? _findAt(
    Uint8List data,
    int width,
    int height,
    List<int> xs,
    List<int> ys,
    double size,
    int scale,
    Uint8List full,
    int fullWidth,
    int fullHeight,
    bool? fullOpaque,
  ) {
    final n = width * height;
    // 白い紙の上での明るさ（透明な所は白）と不透明度。
    final lum = Uint8List(n), alpha = Uint8List(n);
    var all = 255;
    // 画素を4バイトずつ読む（リトルエンディアンでRGBAは下の桁から）。
    final words = Endian.host == Endian.little && data.offsetInBytes % 4 == 0
        ? data.buffer.asUint32List(data.offsetInBytes, n)
        : null;
    for (var p = 0, i = 0; p < n; p++, i += 4) {
      final int a, r0, g0, b0;
      if (words != null) {
        final v = words[p];
        r0 = v & 0xff;
        g0 = (v >> 8) & 0xff;
        b0 = (v >> 16) & 0xff;
        a = v >> 24;
      } else {
        r0 = data[i];
        g0 = data[i + 1];
        b0 = data[i + 2];
        a = data[i + 3];
      }
      alpha[p] = a;
      all &= a;
      final over = 255 - a;
      var r = r0 + over, g = g0 + over, b = b0 + over;
      if (r > 255) r = 255;
      if (g > 255) g = 255;
      if (b > 255) b = 255;
      lum[p] = (r * 77 + g * 150 + b * 29) >> 8;
    }
    final opaque = all == 255;

    // 細い形だけを取り出す（モルフォロジーのトップハット）。窓は描き直す
    // 太さの上限より少し広い正方形：それより細い暗い形は「閉じる」で消え、
    // 消えた分が線の暗さになる。
    final reach = (1.25 * size).ceil() + 1;
    final morph = _Morph(width, height, reach);
    final closed = Uint8List(n);
    morph.close(lum, closed);
    final dark = Uint8List(n);
    var strongest = 0;
    for (var p = 0; p < n; p++) {
      final d = closed[p] - lum[p];
      dark[p] = d;
      if (d > strongest) strongest = d;
    }
    Uint8List? opened, solid;
    var anyDark = strongest >= _minDark, anySolid = false;
    // 不透明でない画素の外接矩形から2窓分より遠い所は、開いても255のまま
    // （細い不透明な形は無い）：開くのは外接矩形を4窓分広げた範囲[rect]
    // だけで、正しい値を使うのは2窓分広げた範囲[near]（その中の画素の窓は
    // 絵の端か[rect]の中に収まる）。
    late final _Rect rect, near;
    late final _Morph local;
    if (!opaque) {
      var bx0 = width, by0 = height, bx1 = -1, by1 = -1;
      for (var y = 0, row = 0; y < height; y++, row += width) {
        var first = -1;
        for (var x = 0; x < width; x++) {
          if (alpha[row + x] != 255) {
            first = x;
            break;
          }
        }
        if (first < 0) continue;
        var last = first;
        for (var x = width - 1; x > first; x--) {
          if (alpha[row + x] != 255) {
            last = x;
            break;
          }
        }
        if (first < bx0) bx0 = first;
        if (last > bx1) bx1 = last;
        if (y < by0) by0 = y;
        by1 = y;
      }
      rect = _Rect.around(bx0, by0, bx1, by1, 4 * reach, width, height);
      near = _Rect.around(bx0, by0, bx1, by1, 2 * reach, width, height);
      local = _Morph(rect.w, rect.h, reach);
      final sub = rect.copy(alpha, width);
      final subOpened = Uint8List(sub.length);
      local.open(sub, subOpened);
      opened = Uint8List(n)..fillRange(0, n, 255);
      solid = Uint8List(n);
      var most = 0;
      for (var y = near.y0; y < near.y1; y++) {
        final row = y * width, from = (y - rect.y0) * rect.w - rect.x0;
        for (var x = near.x0; x < near.x1; x++) {
          final o = subOpened[from + x];
          opened[row + x] = o;
          final d = alpha[row + x] - o;
          solid[row + x] = d;
          if (d > most) most = d;
        }
      }
      anySolid = most >= _minAlpha;
    }
    if (!anyDark && !anySolid) return null;

    // インクの濃さ（0〜255）：線の芯に対する割合。芯は近くの細い形の中で
    // いちばん暗い（不透明な）画素で、線の縁の画素は芯と地の間のどこに
    // あるかで測る（両側の地の明るさが違っても、半分かかった画素は半分）。
    final ink = Uint8List(n);
    // インクが半分以上の画素の数。
    var rough = 0;
    final core = Uint8List(n), coreOut = Uint8List(n);
    if (anyDark) {
      for (var p = 0; p < n; p++) {
        core[p] = dark[p] >= _minDark ? lum[p] : 255;
      }
      morph.filter(core, coreOut, max: false);
      final ratio = _ratio;
      for (var p = 0; p < n; p++) {
        final d = dark[p];
        if (d == 0) continue;
        final depth = closed[p] - coreOut[p];
        if (depth < _minDark) continue;
        final v = ratio[depth << 8 | d];
        ink[p] = v;
        if (v >= 128) rough++;
      }
    }
    if (anySolid) {
      final solidOf = solid!, openedOf = opened!;
      final sub = Uint8List(rect.w * rect.h), subOut = Uint8List(sub.length);
      for (var y = rect.y0, k = 0; y < rect.y1; y++) {
        for (var x = rect.x0, p = y * width + x; x < rect.x1; x++, p++, k++) {
          sub[k] = solidOf[p] >= _minAlpha ? alpha[p] : 0;
        }
      }
      local.filter(sub, subOut, max: true);
      for (var y = near.y0; y < near.y1; y++) {
        final row = y * width, from = (y - rect.y0) * rect.w - rect.x0;
        for (var x = near.x0; x < near.x1; x++) {
          final p = row + x;
          final d = solidOf[p];
          if (d == 0) continue;
          final depth = subOut[from + x] - openedOf[p];
          if (depth < _minAlpha) continue;
          final v = _ratio[depth << 8 | d];
          final was = ink[p];
          if (v > was) {
            if (v >= 128 && was < 128) rough++;
            ink[p] = v;
          }
        }
      }
    }

    // 線の形：インクが半分以上の画素。ただし芯ほど濃くない画素は、周りと
    // 明るさ（不透明度）が違う所（線の縁のアンチエイリアス）だけ：線より
    // 明るく地より暗い平らな塗り（髪・服の影）は、線のそばでもインクが
    // 半分ほどに測れるが、線の形に入れない（入れると線と塗りが1つの太い
    // 形になり、中心線が塗りの中を通った）。
    // インクが半分以上の画素が絵の4分の1を超えるなら線画ではない（細かい
    // 模様・ざらつき）：形を細かく決める前に打ち切る。
    if (rough * 4 > n) return null;
    final lineShape = Uint8List(n);
    var mx0 = width, my0 = height, mx1 = -1, my1 = -1;
    var count = 0;
    for (var y = 0, row = 0; y < height; y++, row += width) {
      var first = -1, last = -1;
      for (var x = 0; x < width; x++) {
        final p = row + x;
        final v = ink[p];
        if (v < 128) continue;
        if (v < PixelArtLines._fullInk) {
          var lo = 255, hi = 0, aLo = 255, aHi = 0;
          for (
            var yy = math.max(0, y - 1);
            yy <= math.min(height - 1, y + 1);
            yy++
          ) {
            for (
              var xx = math.max(0, x - 1);
              xx <= math.min(width - 1, x + 1);
              xx++
            ) {
              final q = yy * width + xx;
              final l = lum[q], a = alpha[q];
              if (l < lo) lo = l;
              if (l > hi) hi = l;
              if (a < aLo) aLo = a;
              if (a > aHi) aHi = a;
            }
          }
          if (hi - lo < _minDark && aHi - aLo < _minDark) continue;
        }
        lineShape[p] = 1;
        if (first < 0) first = x;
        last = x;
        count++;
      }
      if (first < 0) continue;
      if (first < mx0) mx0 = first;
      if (last > mx1) mx1 = last;
      if (y < my0) my0 = y;
      my1 = y;
    }
    if (mx1 < 0) return null;
    // 線の形が絵の4分の1を超えるなら線画ではない（細かい模様・ざらつき）。
    if (count * 4 > n) return null;

    final analysis = _Analysis(
      data: data,
      width: width,
      height: height,
      xs: xs,
      ys: ys,
      size: size,
      lum: lum,
      alpha: alpha,
      closed: closed,
      opened: opened,
      dark: dark,
      solid: solid,
      ink: ink,
      lineShape: lineShape,
      box: (mx0, my0, mx1, my1),
      reach: reach,
      scale: scale,
      full: full,
      fullWidth: fullWidth,
      fullHeight: fullHeight,
      fullOpaque: fullOpaque ?? opaque,
    );
    return analysis.run();
  }
}

/// 絵の中の矩形（[x0], [y0]を含み[x1], [y1]を含まない）。
class _Rect {
  _Rect(this.x0, this.y0, this.x1, this.y1);

  /// 画素[x0]〜[x1]、[y0]〜[y1]（含む）を[margin]だけ広げ、絵（[width]×
  /// [height]）の中に収めたもの。
  factory _Rect.around(
    int x0,
    int y0,
    int x1,
    int y1,
    int margin,
    int width,
    int height,
  ) => _Rect(
    math.max(0, x0 - margin),
    math.max(0, y0 - margin),
    math.min(width, x1 + margin + 1),
    math.min(height, y1 + margin + 1),
  );

  final int x0, y0, x1, y1;
  int get w => x1 - x0;
  int get h => y1 - y0;

  /// 幅[width]の絵[src]から、この矩形の画素を詰めて写したもの。
  Uint8List copy(Uint8List src, int width) {
    final out = Uint8List(w * h);
    for (var y = y0; y < y1; y++) {
      out.setRange((y - y0) * w, (y - y0 + 1) * w, src, y * width + x0);
    }
    return out;
  }
}

/// 正方形の窓（半径[r]、絵の端で切れる）の中の最大・最小（縦横に分け、
/// それぞれ窓の長さを倍々にした最大・最小を重ねる：長さ2^jの窓の値は、長さ
/// 2^(j-1)の窓の値とその2^(j-1)先の値の大きい方（小さい方）。8画素ずつ
/// 64ビットの整数にまとめて比べる）。絵の端で切れる窓の画素だけは1つずつ
/// 数える。作業用の配列は使い回す。
class _Morph {
  _Morph(this.w, this.h, this.r)
    : _words = Uint64List(((w * h + 7) >> 3) + 2),
      _tmp = Uint8List(w * h) {
    _bytes = _words.buffer.asUint8List();
  }

  final int w, h, r;
  final Uint64List _words;
  late final Uint8List _bytes;
  final Uint8List _tmp;

  /// 8つのバイトの上の桁（0x80）と下の7桁（0x7f）。
  static const int _high = -0x7f7f7f7f7f7f7f80;
  static const int _low = 0x7f7f7f7f7f7f7f7f;
  static final bool _little = Endian.host == Endian.little;

  /// 閉じる（最大の後に最小）。
  void close(Uint8List src, Uint8List out) {
    _pass(src, _tmp, false, true);
    _pass(_tmp, out, true, true);
    _pass(out, _tmp, false, false);
    _pass(_tmp, out, true, false);
  }

  /// 開く（最小の後に最大）。
  void open(Uint8List src, Uint8List out) {
    _pass(src, _tmp, false, false);
    _pass(_tmp, out, true, false);
    _pass(out, _tmp, false, true);
    _pass(_tmp, out, true, true);
  }

  void filter(Uint8List src, Uint8List out, {required bool max}) {
    _pass(src, _tmp, false, max);
    _pass(_tmp, out, true, max);
  }

  /// 横（[down]なら縦）の窓[−r, r]の最大（最小）を[src]から[dst]へ。
  void _pass(Uint8List src, Uint8List dst, bool down, bool max) {
    final n = w * h, r = this.r, k = 2 * r + 1;
    // 隣の画素までの距離、その向きの画素の数、もう一方の向きの数。
    final step = down ? w : 1, length = down ? h : w, across = down ? w : h;
    final work = _bytes;
    work.setRange(0, n, src);
    // 長さ[span]の窓：work[i]はsrc[i]から[span]個の最大（最小）。
    var span = 1;
    while (span * 2 <= k) {
      _shift(span * step, n - span * step, max);
      span *= 2;
    }
    // 長さkの窓：長さspanの窓2つ（k − span離れたもの）を重ねる。
    _shift((k - span) * step, n - (k - span) * step, max);
    // 窓が絵の端で切れない画素：窓の始まり（r手前）の値。
    if (length > 2 * r) {
      if (!down) {
        for (var y = 0, row = 0; y < h; y++, row += w) {
          dst.setRange(row + r, row + w - r, work, row);
        }
      } else {
        dst.setRange(r * w, (h - r) * w, work, 0);
      }
    }
    // 窓が絵の端で切れる画素：1つずつ。
    final leftEnd = math.min(r, length);
    final rightStart = math.max(length - r, leftEnd);
    for (var line = 0; line < across; line++) {
      final base = down ? line : line * w;
      for (final (from, to) in [(0, leftEnd), (rightStart, length)]) {
        for (var x = from; x < to; x++) {
          final lo = math.max(0, x - r), hi = math.min(length - 1, x + r);
          var m = src[base + lo * step];
          for (var t = lo + 1; t <= hi; t++) {
            final v = src[base + t * step];
            if (max ? v > m : v < m) m = v;
          }
          dst[base + x * step] = m;
        }
      }
    }
  }

  /// work[i]をwork[i]とwork[i + s]の大きい方（小さい方）にする（0 ≤ i <
  /// [count]、前から順に：書き換える前の値を読む）。
  void _shift(int s, int count, bool max) {
    if (count <= 0) return;
    final bytes = _bytes;
    var from = 0;
    if (_little) {
      final words = _words;
      final full = count >> 3, ws = s >> 3, bits = (s & 7) << 3;
      for (var k = 0; k < full; k++) {
        final a = words[k];
        final q = k + ws;
        final b = bits == 0
            ? words[q]
            : (words[q] >>> bits) | (words[q + 1] << (64 - bits));
        // バイトごとにa ≥ bか（上の桁が立つ）。
        final ge = ((a & ~b) | (~(a ^ b) & ((a | _high) - (b & _low)))) & _high;
        final mask = (ge >>> 7) * 0xff;
        words[k] = max ? (a & mask) | (b & ~mask) : (b & mask) | (a & ~mask);
      }
      from = full << 3;
    }
    for (var i = from; i < count; i++) {
      final a = bytes[i], b = bytes[i + s];
      bytes[i] = max ? (a > b ? a : b) : (a < b ? a : b);
    }
  }
}

/// 線1本（中心線の分かれ目から分かれ目・端まで、または輪）。
class _Branch {
  _Branch(this.pixels, this.start, this.end, {this.closed = false});

  /// 中心線の画素（細線化した画像の上の位置）を線に沿った順に。
  final List<int> pixels;

  /// 両端の分かれ目（無ければ-1＝線の端）。
  final int start, end;
  final bool closed;

  double width = 0;
  int color = 0, alpha = 255;
  int contrast = 0;
  bool accepted = false;

  /// 線ではなく塗った形の一部（面に触れる・とがり・短い枝・太すぎる）。
  bool shape = false;

  /// 中心線が芯よりはっきり明るい（線の横の塗りの中を通る）。
  bool pale = false;
  int dots = 1;

  /// 中心線の各画素で測った断面：線の中心、幅、芯の画素。点（中心線が
  /// ほとんど無い線）の太さはインクの量と同じ面積の円の直径。
  final sectionCentres = <(double, double)>[];
  final sectionWidths = <double>[];
  final sectionCores = <int>[];
  double disc = 0;

  /// 小数まで測った中心線（画素の座標）と、それを描く線の端までそろえた
  /// もの。
  List<(double, double)> centre = const [];
  List<(double, double)> points = const [];

  /// 描いたドット。
  List<int> cells = const [];
}

class _Analysis {
  _Analysis({
    required this.data,
    required this.width,
    required this.height,
    required this.xs,
    required this.ys,
    required this.size,
    required this.lum,
    required this.alpha,
    required this.closed,
    required this.opened,
    required this.dark,
    required this.solid,
    required this.ink,
    required this.lineShape,
    required (int, int, int, int) box,
    required this.reach,
    required this.scale,
    required this.full,
    required this.fullWidth,
    required this.fullHeight,
    required this.fullOpaque,
  }) : x0 = box.$1,
       y0 = box.$2,
       lw = box.$3 - box.$1 + 3,
       lh = box.$4 - box.$2 + 3;

  final Uint8List data;
  final int width, height;
  final List<int> xs, ys;
  final double size;
  final Uint8List lum, alpha, closed, dark, ink;

  /// 画素ごと：線の形なら1。
  final Uint8List lineShape;
  final Uint8List? opened, solid;
  final int reach;

  /// 元の絵（[full]、[fullWidth]×[fullHeight]）は、この絵の何倍か。ドットの
  /// 格子（[xs]・[ys]）と描き直した線のインクの印は元の絵の上。
  final int scale;
  final Uint8List full;
  final int fullWidth, fullHeight;

  /// 元の絵がどこも不透明か。
  final bool fullOpaque;

  /// 元の絵の列（行）ごとの、それを含むドットの列（行）。
  late final Int32List cellOfX = _cellsOf(xs, fullWidth);
  late final Int32List cellOfY = _cellsOf(ys, fullHeight);

  static Int32List _cellsOf(List<int> edges, int length) {
    final out = Int32List(length);
    for (var c = 0; c + 1 < edges.length; c++) {
      out.fillRange(edges[c], edges[c + 1], c);
    }
    return out;
  }

  /// 細線化する範囲（線の形の外接矩形に1画素の余白）。ローカルの位置
  /// (lx, ly) は元の画素 (x0 + lx - 1, y0 + ly - 1)。
  final int x0, y0, lw, lh;

  int get cellsX => xs.length - 1;
  int get cellsY => ys.length - 1;

  late final Int32List _offsets = Int32List.fromList([
    for (final (dx, dy) in PixelArtLines._ring) dy * lw + dx,
  ]);

  int _global(int li) => (y0 + li ~/ lw - 1) * width + x0 + li % lw - 1;

  Uint8List? _degree, _visited, _flags, _masks;

  /// 細線化で、取り除いたときに周りが残っていなかった画素。
  final _alone = <int>[];
  Int32List? _nodeOf;

  PixelArtLines? run() {
    // 線の形（インクが半分以上）。
    final shape = Uint8List(lw * lh);
    var count = 0;
    for (var ly = 1; ly < lh - 1; ly++) {
      final from = ly * lw + 1, at = (y0 + ly - 1) * width + x0 - from;
      for (var li = from; li < from + lw - 2; li++) {
        if (lineShape[at + li] != 0) {
          shape[li] = 1;
          count++;
        }
      }
    }
    // 線の形の画素（細線化する画素の位置、上の行から順に）。
    final fore = Int32List(count);
    for (var li = 0, k = 0; k < count; li++) {
      if (shape[li] != 0) fore[k++] = li;
    }
    // 線の形が絵の4分の1を超えるなら線画ではない（細かい模様・ざらつき）。
    if (fore.length * 4 > width * height) return null;
    final skeleton = Uint8List.fromList(shape);
    _thinZhangSuen(skeleton, fore);
    _thinGuoHall(skeleton, fore);
    _keepVanishedDots(shape, skeleton);
    // ここからは中心線の画素だけを見る（上の行から順）。
    var live = _kept(fore, skeleton);
    live = _removeSteps(skeleton, live);

    // 細線化で線の端・角に出る短いひげを、線の太さの半分ほどまで取り除く。
    var branches = <_Branch>[];
    late List<List<int>> nodes;
    for (var round = 0; round < 4; round++) {
      final traced = _trace(skeleton, live);
      branches = traced.branches;
      nodes = traced.nodes;
      if (round == 3) break;
      var pruned = false;
      for (final b in branches) {
        if (b.closed) continue;
        final node = b.start >= 0 ? b.start : b.end;
        if (node < 0) continue;
        final freeEnd = b.start < 0 || b.end < 0;
        final loop = b.start == b.end;
        if (!freeEnd && !loop) continue;
        var half = 0;
        for (final j in nodes[node]) {
          half = math.max(half, _halfWidth(shape, j));
        }
        if (b.pixels.length > half + 1) continue;
        for (final li in b.pixels) {
          skeleton[li] = 0;
        }
        pruned = true;
      }
      if (!pruned) break;
      live = _removeSteps(skeleton, _kept(live, skeleton));
    }

    final skel = _kept(live, skeleton);
    if (skel.isEmpty) return null;
    final index = Int32List(lw * lh)..fillRange(0, lw * lh, -1);
    for (var k = 0; k < skel.length; k++) {
      index[skel[k]] = k;
    }
    final slices = _Slices.of(this, skel);

    for (final b in branches) {
      _profile(b, index, slices);
    }
    final nodeAt = _junctions(nodes, branches);
    for (final b in branches) {
      _measure(b, nodeAt);
    }
    // 中心が芯より明るい線（線の横の塗りの中を通る中心線）は、1ドット以内に
    // 描き直す暗い線があれば、その線の横の塗りなので描き直さない。
    if (branches.any((b) => b.accepted && b.pale)) {
      final reachDark = Uint8List(width * height);
      final r = size.ceil() + 1;
      for (final b in branches) {
        if (!b.accepted || b.pale) continue;
        for (final (cx, cy) in b.sectionCentres) {
          final px = cx.floor(), py = cy.floor();
          for (
            var y = math.max(0, py - r);
            y <= math.min(height - 1, py + r);
            y++
          ) {
            for (
              var x = math.max(0, px - r);
              x <= math.min(width - 1, px + r);
              x++
            ) {
              reachDark[y * width + x] = 1;
            }
          }
        }
      }
      for (final b in branches) {
        if (!b.accepted || !b.pale) continue;
        var near = 0;
        for (final (cx, cy) in b.sectionCentres) {
          final px = cx.floor().clamp(0, width - 1);
          final py = cy.floor().clamp(0, height - 1);
          if (reachDark[py * width + px] != 0) near++;
        }
        if (near * 2 > b.sectionCentres.length) {
          b.accepted = false;
        }
      }
    }

    // 分かれ目に線が7本以上集まる・分かれ目の塊が大きいのは、線の交わり
    // ではなく細かい模様の網（細い線が1ドットより密に並ぶ所）：そこへ
    // つながる線は描き直さない。
    final atNode = List.generate(nodes.length, (_) => <_Branch>[]);
    for (final b in branches) {
      if (b.start >= 0) atNode[b.start].add(b);
      if (b.end >= 0 && b.end != b.start) atNode[b.end].add(b);
    }
    final mesh = [
      for (var node = 0; node < nodes.length; node++)
        atNode[node].length > 6 || nodes[node].length > 4 * reach,
    ];
    for (final b in branches) {
      if ((b.start >= 0 && mesh[b.start]) || (b.end >= 0 && mesh[b.end])) {
        b
          ..accepted = false
          ..shape = true;
      }
    }

    // 小さなまとまり（アイコンのような塗った形）は、どこかが塗った形の
    // 一部なら全部を今まで通りのドットにする（一部だけ線として描き直すと
    // 形が崩れる）。
    final group = List<int>.generate(nodes.length, (k) => k);
    int root(int k) {
      while (group[k] != k) {
        k = group[k] = group[group[k]];
      }
      return k;
    }

    for (final b in branches) {
      if (b.start >= 0 && b.end >= 0) group[root(b.start)] = root(b.end);
    }
    final pixelsOf = <int, int>{}, shapeOf = <int, bool>{};
    for (final b in branches) {
      final node = b.start >= 0 ? b.start : b.end;
      if (node < 0) continue;
      final r = root(node);
      pixelsOf[r] = (pixelsOf[r] ?? 0) + b.pixels.length;
      if (b.shape) shapeOf[r] = true;
    }
    for (final b in branches) {
      final node = b.start >= 0 ? b.start : b.end;
      if (node < 0) continue;
      final r = root(node);
      if (shapeOf[r] == true && pixelsOf[r]! < 8 * size) {
        b
          ..accepted = false
          ..shape = true;
      }
    }
    // 塗った形の一部にしかつながっていない短い線（矢印の軸など）も形の
    // 一部（分かれ目にほかの描き直す線があれば、線どうしの交わり）。
    bool onlyShapes(int node, _Branch b) =>
        node >= 0 &&
        atNode[node].any((o) => o.shape) &&
        !atNode[node].any((o) => !identical(o, b) && o.accepted);
    for (final b in branches) {
      if (!b.accepted || b.pixels.length >= 8 * size) continue;
      if (onlyShapes(b.start, b) || onlyShapes(b.end, b)) {
        b
          ..accepted = false
          ..shape = true;
      }
    }

    // 同じくらいの太さの線は同じドット数にする（1本ずつ丸めると、同じペンの
    // 線が太さの境目（1.5ドット等）の前後に測られて、1ドットと2ドットに
    // 分かれる）：太さの近い線をまとめ、まとまりの長さで重みを付けた
    // 中央値で決める。
    final measured = [
      for (final b in branches)
        if (b.accepted) b,
    ]..sort((a, c) => a.width.compareTo(c.width));
    for (var i = 0; i < measured.length;) {
      var j = i + 1;
      while (j < measured.length &&
          measured[j].width <= measured[i].width * 1.2) {
        j++;
      }
      final group = measured.sublist(i, j);
      final total = group.fold(0, (v, b) => v + b.pixels.length);
      var walked = 0;
      var middle = group.first.width;
      for (final b in group) {
        walked += b.pixels.length;
        if (walked * 2 >= total) {
          middle = b.width;
          break;
        }
      }
      final dots = (middle / size).round().clamp(1, 2);
      for (final b in group) {
        if (b.dots != dots) {
          b.dots = dots;
          b.points = _endsFor(b, dots);
        }
      }
      i = j;
    }

    // 描き直す線どうしをつなぐ短い線（2本の線が寄り合う所で、細線化が
    // 分かれ目の間に残す短い線）は、両側が線なので地の確かめを通らない：
    // 両端の分かれ目に描き直す線があれば、その線と同じ太さ・色で描く。
    for (var pass = 0; pass < 3; pass++) {
      var joined = false;
      for (final b in branches) {
        if (b.accepted || b.closed || b.start < 0 || b.end < 0) continue;
        if (b.shape || b.width / size >= PixelArtLines._maxDots) continue;
        _Branch? strongest;
        var startOk = false, endOk = false;
        for (final (node, isStart) in [(b.start, true), (b.end, false)]) {
          for (final o in atNode[node]) {
            if (!o.accepted || identical(o, b)) continue;
            if (isStart) {
              startOk = true;
            } else {
              endOk = true;
            }
            if (strongest == null || o.contrast > strongest.contrast) {
              strongest = o;
            }
          }
        }
        if (!startOk || !endOk || strongest == null) continue;
        // 同じ2つの分かれ目を結ぶ線がもう1本ある（線とそのすぐ横の暗い塗りが
        // 輪になった細線化：服の襟の線と影）なら、もう少し長くてもつなぐ。
        // 2本のうち1本だけを描く（短い方）。
        var twin = false, twinFirst = false;
        for (final o in atNode[b.start]) {
          if (identical(o, b) || o.closed) continue;
          if ((o.start == b.start && o.end == b.end) ||
              (o.start == b.end && o.end == b.start)) {
            twin = true;
            if (o.accepted ||
                o.pixels.length < b.pixels.length ||
                (o.pixels.length == b.pixels.length &&
                    branches.indexOf(o) < branches.indexOf(b))) {
              twinFirst = true;
            }
          }
        }
        if (twinFirst) continue;
        final reachJoin = (twin ? 4 : 2) * size + 2 * strongest.width;
        if (b.pixels.length > reachJoin) continue;
        b
          ..dots = strongest.dots
          ..color = strongest.color
          ..alpha = strongest.alpha
          ..contrast = strongest.contrast
          ..points = _smooth([
            nodeAt[b.start],
            for (final li in b.pixels) (_x(li), _y(li)),
            nodeAt[b.end],
          ], false)
          ..accepted = true;
        joined = true;
      }
      if (!joined) break;
    }

    // 描き直す線を決め、格子の上へ描く。
    final stampCount = Uint16List(cellsX * cellsY);
    for (final b in branches) {
      if (!b.accepted) continue;
      b.cells = _stampCells(b);
      for (final c in b.cells) {
        stampCount[c]++;
      }
    }
    // 細かい模様（線が1ドットより密に並ぶ所）は描き直さない。
    final crowded = <_Branch>[];
    for (final b in branches) {
      if (!b.accepted || b.cells.isEmpty) continue;
      var share = 0.0;
      for (final c in b.cells) {
        final cx = c % cellsX, cy = c ~/ cellsX;
        var inside = 0, drawn = 0;
        for (var ny = cy - 3; ny <= cy + 3; ny++) {
          if (ny < 0 || ny >= cellsY) continue;
          for (var nx = cx - 3; nx <= cx + 3; nx++) {
            if (nx < 0 || nx >= cellsX) continue;
            inside++;
            if (stampCount[ny * cellsX + nx] != 0) drawn++;
          }
        }
        share += drawn / inside;
      }
      if (share / b.cells.length > PixelArtLines._crowded) {
        b.accepted = false;
        crowded.add(b);
      }
    }
    // 模様の端の線（片側だけ空いているので混み具合が下がる）も、模様と
    // 一緒に今まで通りにする：大半が描き直さない線の2ドット以内を通る線は
    // 描き直さない。
    final near = Uint8List(cellsX * cellsY);
    while (crowded.isNotEmpty) {
      for (final b in crowded) {
        for (final c in b.cells) {
          final cx = c % cellsX, cy = c ~/ cellsX;
          for (
            var ny = math.max(0, cy - 2);
            ny <= math.min(cellsY - 1, cy + 2);
            ny++
          ) {
            for (
              var nx = math.max(0, cx - 2);
              nx <= math.min(cellsX - 1, cx + 2);
              nx++
            ) {
              near[ny * cellsX + nx] = 1;
            }
          }
        }
      }
      crowded.clear();
      for (final b in branches) {
        if (!b.accepted || b.cells.isEmpty) continue;
        var inside = 0;
        for (final c in b.cells) {
          if (near[c] != 0) inside++;
        }
        if (inside * 2 > b.cells.length) {
          b.accepted = false;
          crowded.add(b);
        }
      }
    }

    final cellCount = cellsX * cellsY;
    final line = Uint8List(cellCount);
    final color = Int32List(cellCount);
    final alphaOut = Uint8List(cellCount);
    final strength = Int32List(cellCount);
    var any = false;
    for (final b in branches) {
      if (!b.accepted) continue;
      for (final c in b.cells) {
        // 分かれ目で何本かが重なるドットは、いちばんはっきりした線の色。
        if (line[c] != 0 && strength[c] >= b.contrast) continue;
        line[c] = 1;
        color[c] = b.color;
        alphaOut[c] = b.alpha;
        strength[c] = b.contrast;
        any = true;
      }
    }
    if (!any) return null;

    // 描き直した線のインクは、ドットの地の色から外す。分かれ目のインクは、
    // そこに集まる線がすべて描き直されたときだけ。
    // 分かれ目から1ドットに満たないほど突き出た、描き直さなかった小さな
    // ひげ（線の重なりの塊の角）は、分かれ目の塊の一部として一緒に外す
    // （残すと分かれ目のインクが今まで通りのまだらの色で残った）。
    bool stub(_Branch b) =>
        !b.accepted &&
        !b.shape &&
        b.pixels.length < size &&
        (b.start < 0) != (b.end < 0) &&
        atNode[b.start >= 0 ? b.start : b.end].any((o) => o.accepted);
    final owned = Uint8List(skel.length);
    final nodeDone = List<bool>.filled(nodes.length, true);
    for (final b in branches) {
      if (b.accepted || stub(b)) {
        for (final li in b.pixels) {
          owned[index[li]] = 1;
        }
      } else {
        if (b.start >= 0) nodeDone[b.start] = false;
        if (b.end >= 0) nodeDone[b.end] = false;
      }
    }
    for (var node = 0; node < nodes.length; node++) {
      if (!nodeDone[node]) continue;
      if (!atNode[node].any((b) => b.accepted)) continue;
      for (final li in nodes[node]) {
        owned[index[li]] = 1;
      }
    }
    var inked = Uint8List(width * height);
    final ownerOf = slices.owner;
    // 線として外す画素（この絵の画素）：中心線へ割り当てたインクと、
    // 中心線の近く。
    final here = Int32List(slices.pixels.length);
    var hereCount = 0;
    for (final p in slices.pixels) {
      if (owned[ownerOf[p] - 1] != 0) {
        inked[p] = 1;
        here[hereCount++] = p;
      }
    }
    // 線の縁の画素は、線と隣の面の間の色でも、インクとして測れないことが
    // ある（塗りの面の縁を囲む線の、紙の側の縁）：描き直した線の中心線から
    // 太さの半分と1.5画素の内側も、線のインクとして外す。
    final footprint = _markFootprints(branches, inked);
    final cellOfX = this.cellOfX, cellOfY = this.cellOfY;
    // 印の付いたドット。
    final touched = Uint8List(cellCount);
    if (scale > 1) {
      // 縮めた絵の1画素は、元の絵のscale×scale画素。
      final marks = Uint8List(fullWidth * fullHeight);
      void spread(int p) {
        final ay = p ~/ width, ax = p - ay * width;
        final left = ax * scale, top = ay * scale;
        final right = math.min(left + scale, fullWidth);
        final bottom = math.min(top + scale, fullHeight);
        for (var y = top; y < bottom; y++) {
          marks.fillRange(y * fullWidth + left, y * fullWidth + right, 1);
        }
        for (var cy = cellOfY[top]; cy <= cellOfY[bottom - 1]; cy++) {
          for (var cx = cellOfX[left]; cx <= cellOfX[right - 1]; cx++) {
            touched[cy * cellsX + cx] = 1;
          }
        }
      }

      for (var k = 0; k < hereCount; k++) {
        spread(here[k]);
      }
      for (final p in footprint) {
        spread(p);
      }
      inked = marks;
    } else {
      for (var k = 0; k < hereCount; k++) {
        final p = here[k];
        final y = p ~/ width;
        touched[cellOfY[y] * cellsX + cellOfX[p - y * width]] = 1;
      }
      for (final p in footprint) {
        final y = p ~/ width;
        touched[cellOfY[y] * cellsX + cellOfX[p - y * width]] = 1;
      }
    }
    // 線を外したドットに、線の縁のごく薄い画素（透明なレイヤーの線の縁）が
    // 残ると、ほとんど透明なドットになる：線のインクがあったドットでは、
    // それも線のインクとして外す。
    if (!fullOpaque) {
      for (var c = 0; c < cellCount; c++) {
        if (touched[c] == 0) continue;
        final cx = c % cellsX, cy = c ~/ cellsX;
        for (var y = ys[cy]; y < ys[cy + 1]; y++) {
          for (
            var x = xs[cx], p = y * fullWidth + x;
            x < xs[cx + 1];
            x++, p++
          ) {
            final a = full[p * 4 + 3];
            if (a != 0 && a < 128) inked[p] = 1;
          }
        }
      }
    }
    // ドットごとの、描き直した線のインクの量（縮めた絵の上で数える）。
    final cover = Float64List(cellCount);
    final columns = Int32List(cellsX), rows = Int32List(cellsY);
    for (var x = 0; x < width; x++) {
      columns[cellOfX[math.min(fullWidth - 1, x * scale)]]++;
    }
    for (var y = 0; y < height; y++) {
      rows[cellOfY[math.min(fullHeight - 1, y * scale)]]++;
    }
    for (var k = 0; k < hereCount; k++) {
      final p = here[k];
      final y = p ~/ width, x = p - y * width;
      final c =
          cellOfY[math.min(fullHeight - 1, y * scale)] * cellsX +
          cellOfX[math.min(fullWidth - 1, x * scale)];
      cover[c] += ink[p];
    }
    for (var c = 0; c < cellCount; c++) {
      final area = 255.0 * columns[c % cellsX] * rows[c ~/ cellsX];
      if (area > 0) cover[c] /= area;
    }
    return PixelArtLines._(line, color, alphaOut, inked, cover);
  }

  /// 描き直す線の中心線から（太さの半分＋1.5画素）以内の画素に印を付ける
  /// （中心線の点から、最も近い点の距離で広げる）。印を付けた画素を返す。
  Int32List _markFootprints(List<_Branch> branches, Uint8List marks) {
    var points = 0;
    for (final b in branches) {
      if (b.accepted) points += b.centre.length;
    }
    if (points == 0) return Int32List(0);
    final width = this.width, height = this.height;
    final seed = Int32List(width * height);
    final seedX = Float64List(points), seedY = Float64List(points);
    final seedR = Float64List(points);
    var seeds = 0;
    final queue = Int32List(width * height);
    var tail = 0;
    for (final b in branches) {
      if (!b.accepted) continue;
      final r = b.width / 2 + 1.5;
      for (final (x, y) in b.centre) {
        final px = x.floor(), py = y.floor();
        if (px < 0 || py < 0 || px >= width || py >= height) continue;
        final p = py * width + px;
        seedX[seeds] = x;
        seedY[seeds] = y;
        seedR[seeds] = r * r;
        seeds++;
        if (seed[p] == 0) {
          seed[p] = seeds;
          marks[p] = 1;
          queue[tail++] = p;
        }
      }
    }
    for (var head = 0; head < tail; head++) {
      final p = queue[head];
      final k = seed[p] - 1;
      final sx = seedX[k], sy = seedY[k], r2 = seedR[k];
      final y = p ~/ width, x = p - y * width;
      final inside = x > 0 && y > 0 && x < width - 1 && y < height - 1;
      for (var j = 0; j < 8; j++) {
        final nx = x + _dx[j], ny = y + _dy[j];
        if (!inside && (nx < 0 || ny < 0 || nx >= width || ny >= height)) {
          continue;
        }
        final q = ny * width + nx;
        if (seed[q] != 0) continue;
        final ex = nx + 0.5 - sx, ey = ny + 0.5 - sy;
        if (ex * ex + ey * ey > r2) continue;
        seed[q] = k + 1;
        marks[q] = 1;
        queue[tail++] = q;
      }
    }
    return Int32List.sublistView(queue, 0, tail);
  }

  /// この絵の画素[p]に当たる元の絵の画素のうち、線の芯（いちばん暗い、
  /// 透明なレイヤーの線ならいちばん不透明な）画素。縮めた絵の画素は線と
  /// 紙の混ざった色なので、線の色は元の絵から取る。
  int _fullCore(int p, bool darkLine) {
    if (scale == 1) return p;
    final left = math.max(0, (p % width) * scale - 1);
    final top = math.max(0, (p ~/ width) * scale - 1);
    final right = math.min(fullWidth, (p % width + 1) * scale + 1);
    final bottom = math.min(fullHeight, (p ~/ width + 1) * scale + 1);
    var best = top * fullWidth + left;
    var bestValue = -1;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final q = y * fullWidth + x;
        final i = q * 4;
        final a = full[i + 3];
        final int value;
        if (darkLine) {
          final over = 255 - a;
          final lum =
              (math.min(255, full[i] + over) * 77 +
                  math.min(255, full[i + 1] + over) * 150 +
                  math.min(255, full[i + 2] + over) * 29) >>
              8;
          value = 255 - lum;
        } else {
          value = a;
        }
        if (value > bestValue) {
          bestValue = value;
          best = q;
        }
      }
    }
    return best;
  }

  /// 分かれ目の位置：そこに集まる線の中心線（断面で測った中心の、分かれ目の
  /// 手前の数画素の向き）が交わる所（最小二乗）。細線化した分かれ目の
  /// 画素は線の中心から半画素ほどずれ、ドットの境目で分かれ目が隣の
  /// ドットに入って、交わりのドットが抜けた。
  List<(double, double)> _junctions(
    List<List<int>> nodes,
    List<_Branch> branches,
  ) {
    final n = nodes.length;
    final sxx = Float64List(n), sxy = Float64List(n), syy = Float64List(n);
    final bx = Float64List(n), by = Float64List(n);
    void add(int node, (double, double) near, (double, double) far) {
      var dx = near.$1 - far.$1, dy = near.$2 - far.$2;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length < 1e-6) return;
      dx /= length;
      dy /= length;
      // 線に直角な向きの成分だけを合わせる。
      final nx = -dy, ny = dx;
      sxx[node] += nx * nx;
      sxy[node] += nx * ny;
      syy[node] += ny * ny;
      final d = nx * near.$1 + ny * near.$2;
      bx[node] += nx * d;
      by[node] += ny * d;
    }

    // 分かれ目のすぐそばの断面は分かれ目の塊で中心がずれるので、少し
    // 離れた所の向きを使う。
    for (final b in branches) {
      final c = b.sectionCentres;
      if (c.length < 2 || b.closed) continue;
      final last = c.length - 1;
      final near = math.min(last ~/ 2, 3), far = math.min(last, near + 5);
      if (near == far) continue;
      if (b.start >= 0) add(b.start, c[near], c[far]);
      if (b.end >= 0) add(b.end, c[last - near], c[last - far]);
    }
    return [
      for (var k = 0; k < n; k++)
        () {
          final members = nodes[k];
          final px = members.fold(0.0, (v, li) => v + _x(li)) / members.length;
          final py = members.fold(0.0, (v, li) => v + _y(li)) / members.length;
          // 線が平行に近いときは画素の真ん中へ寄せる（弱いばね）。
          const pull = 0.05;
          final a = sxx[k] + pull, bb = sxy[k], d = syy[k] + pull;
          final rx = bx[k] + pull * px, ry = by[k] + pull * py;
          final det = a * d - bb * bb;
          if (det.abs() < 1e-9) return (px, py);
          final x = (rx * d - ry * bb) / det, y = (ry * a - rx * bb) / det;
          // 分かれ目の画素から遠くへは動かさない。
          if ((x - px).abs() > 3 || (y - py).abs() > 3) return (px, py);
          return (x, y);
        }(),
    ];
  }

  /// 細線化した画像の上の位置[li]の画素の中心（元の絵の座標）。
  double _x(int li) => x0 + li % lw - 0.5;
  double _y(int li) => y0 + li ~/ lw - 0.5;

  /// インクの濃さ（0〜255）を位置(x, y)で読む（画素の間は直線で補う）。
  double _inkAt(double x, double y) {
    final fx = x - 0.5, fy = y - 0.5;
    final px = fx.floor(), py = fy.floor();
    final tx = fx - px, ty = fy - py;
    final w = width;
    double a, b, c, d;
    if (px >= 0 && py >= 0 && px + 1 < w && py + 1 < height) {
      final ink = this.ink, i = py * w + px;
      a = ink[i] * 1.0;
      b = ink[i + 1] * 1.0;
      c = ink[i + w] * 1.0;
      d = ink[i + w + 1] * 1.0;
    } else {
      a = _inkPixel(px, py);
      b = _inkPixel(px + 1, py);
      c = _inkPixel(px, py + 1);
      d = _inkPixel(px + 1, py + 1);
    }
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty;
  }

  double _inkPixel(int x, int y) => x < 0 || y < 0 || x >= width || y >= height
      ? 0
      : ink[y * width + x] * 1.0;

  /// 位置(x, y)を通る、向き(nx, ny)の線の断面：インクの重心までのずれ、
  /// 断面の幅（インクの合計）、いちばん濃い所の画素。隣の線へ入る手前
  /// （薄くなってからまた濃くなる所）で止める。
  /// 線の縁で、0.5画素ごとにインクがこれ以上減らなければ縁の外。
  static const double _plateau = 6;

  ({double offset, double width, int core}) _section(
    double x,
    double y,
    double nx,
    double ny,
  ) {
    const step = 0.5;
    final limit = reach + 2.0;
    var sum = _inkAt(x, y), moment = 0.0;
    var peak = sum, peakAt = 0.0;
    for (final sign in const [1.0, -1.0]) {
      var low = 255.0;
      // 半分より薄いまま減らなかった、続けて数えた標本（平らな塗りなら
      // 取り消す）。
      var flat = 0;
      var flatSum = 0.0, flatMoment = 0.0;
      for (var t = step; t <= limit; t += step) {
        final sx = x + sign * nx * t, sy = y + sign * ny * t;
        var v = _inkAt(sx, sy);
        // 線の形の外の、半分より濃く測れた平らな塗り（髪・影）は、線の縁の
        // 外として扱う（下の「減らなくなったら止める」で止まる）。
        if (v >= 128) {
          final px = sx.floor(), py = sy.floor();
          if (px >= 0 &&
              py >= 0 &&
              px < width &&
              py < height &&
              lineShape[py * width + px] == 0) {
            v = 127;
          }
        }
        if (v < PixelArtLines._faint) break;
        if (low < 128 && v > low + 64) break;
        // 線の縁を過ぎて、インクが半分より薄いまま1画素の間減らなくなった
        // 所は、線の横の塗り（線より明るいが地ほど明るくない髪・影など）：
        // 線の幅に数えない（数えると幅が太く、中心が塗りの側へずれた）。
        // 縁の裾（インクが1割ほど）と、縮めた絵で縁が2画素にまたがった所の
        // ゆるい傾きは今まで通り数える。
        if (low < 128 && v >= 32 && v > low - _plateau) {
          flat++;
          if (flat > 2) {
            sum -= flatSum;
            moment -= flatMoment;
            break;
          }
          flatSum += v;
          flatMoment += v * sign * t;
        } else {
          flat = 0;
          flatSum = 0;
          flatMoment = 0;
        }
        if (v < low) low = v;
        sum += v;
        moment += v * sign * t;
        if (v > peak) {
          peak = v;
          peakAt = sign * t;
        }
      }
    }
    final offset = sum > 0 ? moment / sum : 0.0;
    final cx = (x + nx * peakAt).floor().clamp(0, width - 1);
    final cy = (y + ny * peakAt).floor().clamp(0, height - 1);
    return (offset: offset, width: sum * step / 255, core: cy * width + cx);
  }

  /// 線の中心と太さを、中心線の各画素で線を横切る断面から測る（線の向きに
  /// 直角な断面のインクの重心と合計。画素を最寄りの中心線へ割り当てる
  /// 方法は、斜めの線の段ごとに偏り、中心が段ごとに1画素ずれた）。
  void _profile(_Branch b, Int32List index, _Slices slices) {
    final pixels = b.pixels;
    final count = pixels.length;
    var totalInk = 0.0;
    for (final li in pixels) {
      totalInk += slices.ink[index[li]] / 255;
    }
    final disc = b.disc = 2 * math.sqrt(totalInk / math.pi);
    // 中心線がほとんど無い（丸い点）。
    final isDot = count < 3;

    final centres = b.sectionCentres;
    final widths = b.sectionWidths;
    final cores = b.sectionCores;
    for (var i = 0; i < count; i++) {
      final x = _x(pixels[i]), y = _y(pixels[i]);
      if (isDot) {
        final across = _section(x, y, 1, 0), down = _section(x, y, 0, 1);
        centres.add((x + across.offset, y + down.offset));
        widths.add(disc);
        cores.add(across.core);
        continue;
      }
      final ahead = b.closed
          ? pixels[((i + 4) % count + count) % count]
          : pixels[(i + 4).clamp(0, count - 1)];
      final behind = b.closed
          ? pixels[((i - 4) % count + count) % count]
          : pixels[(i - 4).clamp(0, count - 1)];
      final dx = _x(ahead) - _x(behind);
      final dy = _y(ahead) - _y(behind);
      final length = math.sqrt(dx * dx + dy * dy);
      if (length < 1e-6) {
        centres.add((x, y));
        widths.add(disc);
        cores.add(_section(x, y, 1, 0).core);
        continue;
      }
      final nx = -dy / length, ny = dx / length;
      final cut = _section(x, y, nx, ny);
      centres.add((x + nx * cut.offset, y + ny * cut.offset));
      widths.add(cut.width);
      cores.add(cut.core);
    }
  }

  /// 線の太さ・色・中心線を測り（[_profile]の断面から）、描き直すかを決める。
  void _measure(_Branch b, List<(double, double)> nodeAt) {
    final count = b.pixels.length;
    final isDot = count < 3;
    final disc = b.disc;
    final centres = b.sectionCentres;
    final widths = b.sectionWidths;
    final cores = b.sectionCores;
    // 線の丸い端・分かれ目の塊の断面は広く出るので、中央値。
    final sorted = List<double>.of(widths)..sort();
    final lineWidth = isDot ? disc : sorted[sorted.length ~/ 2];
    b.width = lineWidth;

    // 暗い線か不透明な線か：芯の画素の多数決（いちばん強い芯の1画素で
    // 決めると、線の角・端の数画素だけ不透明度で強く測れたとき、線全体を
    // 不透明な線として測り、隣の不透明な塗りを同じ不透明さの面と見誤った）。
    var darkVotes = 0;
    final solidOf = solid;
    for (var i = 0; i < count; i++) {
      final c = cores[i];
      if (solidOf == null || dark[c] >= solidOf[c]) darkVotes++;
    }
    final darkLine = darkVotes * 2 >= count;
    // 線の芯：芯の画素のうち、はっきりしたもの（薄い線は画素の位置で
    // 芯の濃さが変わるので、濃い側の1割の所）。暗い線では暗さ（明るさの
    // 低さ）で比べる：周りより暗い度合い（トップハット）で比べると、透明な
    // 所に近い塗り（服の影）の画素が線の画素より強く測れることがあった。
    int strength(int p) => darkLine ? 255 - lum[p] : solidOf![p];
    // 芯の強さ（0〜255）の順、同じなら並びの順で、((count - 1) × 0.9)番目。
    final strengths = Uint8List(count);
    final histogram = Int32List(256);
    for (var i = 0; i < count; i++) {
      final v = strength(cores[i]);
      strengths[i] = v;
      histogram[v]++;
    }
    var rank = ((count - 1) * 0.9).floor();
    var level = 0;
    while (rank >= histogram[level]) {
      rank -= histogram[level++];
    }
    var pickAt = 0;
    for (var i = 0; i < count; i++) {
      if (strengths[i] != level) continue;
      if (rank-- == 0) {
        pickAt = i;
        break;
      }
    }
    final core = cores[pickAt];

    // 線とほぼ同じ暗さ（不透明さ）の塗りの面に触れる線は、塗った形の一部
    // （星やはねの先、形の角、形どうしをつなぐ細い部分、同じ色の塗りへ続く
    // 線）：描き直すと形の輪郭が変わり、面とのつなぎ目がずれるので、
    // 今まで通りのドットにする。
    final spread = math.max(2.0, lineWidth) + 1;

    for (var i = 0; i < count; i++) {
      final (cx, cy) = centres[i];
      // 線の縁のぼけ（線と面の間の色）の外側を見る。
      final radius = widths[i] / 2 + 2.5;
      if (_touches(cx, cy, radius, spread, darkLine, core) ||
          _touches(cx, cy, radius + 1.5, spread, darkLine, core)) {
        b.shape = true;
        return;
      }
    }
    for (final node in [b.start, b.end]) {
      if (node < 0) continue;
      final (nx, ny) = nodeAt[node];
      if (_touches(nx, ny, lineWidth / 2 + 3, spread, darkLine, core)) {
        b.shape = true;
        return;
      }
    }
    if (lineWidth / size >= PixelArtLines._maxDots) return;
    // 線の中心の明るさ（中央値）：芯より明るい塗り（服の襟の影など）の中を
    // 通る中心線は、そばの暗い線まで断面が届いて芯を借りていることがある
    // （後でそばに描き直す暗い線があれば外す）。
    if (darkLine && !isDot) {
      final atCentre = Int32List(256);
      for (var i = 0; i < count; i++) {
        final (cx, cy) = centres[i];
        final px = cx.floor().clamp(0, width - 1);
        final py = cy.floor().clamp(0, height - 1);
        atCentre[lum[py * width + px]]++;
      }
      var middle = 0, below = count ~/ 2;
      while (below >= atCentre[middle]) {
        below -= atCentre[middle++];
      }
      b.pale = (middle - lum[core]) * 5 > (closed[core] - lum[core]) * 2;
    }
    if (!isDot) {
      // 分かれ目から突き出た、太さほどの長さしかない枝（塗った小さな形の
      // 骨組み：三角形の角へ向かう枝など）は線ではない。
      if ((b.start >= 0) != (b.end >= 0) && count < 1.5 * lineWidth) {
        b.shape = true;
        return;
      }
      // 先へ向かって細くなる短いとがり（塗った形の先）は、同じ太さの線では
      // ない：断面の幅を線に沿って直線で当てはめ、一方の端がもう一方の半分
      // より細く、太い側が1.5ドット以上あるなら描き直さない（1ドットほどの
      // 細いとがりと、長い線の入り抜きは線のまま）。線の端は1画素、
      // 分かれ目の側は分かれ目の塊で断面が広く出るので（太さの半分＋1）
      // 画素外して測る。
      final skipNode = (lineWidth / 2).ceil() + 1;
      final from = b.start >= 0 ? skipNode : 1;
      final to = count - 1 - (b.end >= 0 ? skipNode : 1);
      if (to - from + 1 >= 5) {
        var n = 0;
        var si = 0.0, sw = 0.0, sii = 0.0, siw = 0.0, widest = 0.0;
        for (var i = from; i <= to; i++) {
          final w = widths[i];
          n++;
          si += i;
          sw += w;
          sii += i * i;
          siw += i * w;
          widest = math.max(widest, w);
        }
        final slope = (n * siw - si * sw) / (n * sii - si * si);
        final mean = sw / n, middle = si / n;
        final first = mean + slope * (from - middle);
        final last = mean + slope * (to - middle);
        final thick = math.max(first, last), thin = math.min(first, last);
        if (count < 6 * thick &&
            widest >= 1.5 * size &&
            thin < 0.45 * thick &&
            lineWidth >= 0.75 * size) {
          b.shape = true;
          return;
        }
      }
    }

    // 線の色は芯の色。
    final pick = _fullCore(core, darkLine);
    final a = full[pick * 4 + 3];
    if (a == 0) return;
    int channel(int v) => ((v * 255 + a ~/ 2) ~/ a).clamp(0, 255);
    b.color =
        0xff000000 |
        channel(full[pick * 4]) << 16 |
        channel(full[pick * 4 + 1]) << 8 |
        channel(full[pick * 4 + 2]);
    b.alpha = a;
    b.contrast = darkLine ? dark[core] : solidOf![core];

    // 中心線を少しならす。分かれ目では、集まる線がみな同じ位置を通る。
    final smoothed = _smooth([
      if (b.start >= 0) nodeAt[b.start],
      ...centres,
      if (b.end >= 0) nodeAt[b.end],
    ], b.closed);
    b.centre = _sharpenCorners(smoothed, b.closed, lineWidth);
    b.dots = (lineWidth / size).round().clamp(1, 2);
    b.points = _endsFor(b, b.dots);

    // 両側が地になっているか（太い塗りの縁や、2つの形の間ではない）。
    bool background(double x, double y) {
      final px = x.floor(), py = y.floor();
      if (px < 0 || py < 0 || px >= width || py >= height) return false;
      final q = py * width + px;
      // 地：線の芯より明るく（不透明な線なら透明に）、それ自体は細い形の
      // 一部でない所（細かい模様の中の明るい所は地ではない）。
      if (darkLine) {
        if (lum[q] * 2 >= lum[core] + closed[core] &&
            dark[q] * 4 <= dark[core]) {
          return true;
        }
        // 線よりはっきり明るい塗り（髪・服・肌など、2つの塗りの間の線や、
        // 塗りの縁を囲む線の内側）も、線の形の一部でなければ地。
        return lum[q] - lum[core] >= PixelArtLines._sideContrast &&
            lineShape[q] == 0;
      }
      return alpha[q] * 2 <= alpha[core] + opened![core] &&
          solid![q] * 4 <= solid![core];
    }

    bool side(double cx, double cy, double nx, double ny, double half) {
      for (var d = 1; d <= 3; d++) {
        if (background(cx + nx * (half + d), cy + ny * (half + d))) {
          return true;
        }
      }
      return false;
    }

    // 線の端の先も地であること：端の先が塗った面へ続いている（塗った形の
    // とがり・形どうしをつなぐ細い部分）なら線ではない。
    bool openEnd(bool last) {
      final n = smoothed.length;
      final (ex, ey) = last ? smoothed[n - 1] : smoothed[0];
      final (bx, by) = last
          ? smoothed[math.max(0, n - 5)]
          : smoothed[math.min(n - 1, 4)];
      final dx = ex - bx, dy = ey - by;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length < 1e-6) return true;
      final limit = lineWidth / 2 + size + 1;
      for (var t = 1.0; t <= limit; t++) {
        final x = ex + dx / length * t, y = ey + dy / length * t;
        // 絵の外へ出ていく線の端は、線の端。
        if (x < 0 || y < 0 || x >= width || y >= height) return true;
        if (background(x, y)) return true;
        // 線と同じ暗さでも細い所（暗い影の横で線として測れない縁取り）で
        // 終わる線は、その線との交わり。広い面へ続くなら塗った形。
        if (_body(x, y, darkLine, core)) {
          final fx = x + dx / length * spread, fy = y + dy / length * spread;
          return !(_body(fx, fy, darkLine, core) &&
              _wideBody(fx, fy, spread, darkLine, core));
        }
      }
      return false;
    }

    if (!isDot && !b.closed) {
      if (b.start < 0 && !openEnd(false)) return;
      if (b.end < 0 && !openEnd(true)) return;
    }

    var passed = 0, tried = 0;
    final offset = b.start >= 0 ? 1 : 0;
    for (var i = 0; i < count; i++) {
      final (cx, cy) = centres[i];
      final half = widths[i] / 2;
      tried++;
      if (isDot) {
        if (side(cx, cy, 1, 0, half) &&
            side(cx, cy, -1, 0, half) &&
            side(cx, cy, 0, 1, half) &&
            side(cx, cy, 0, -1, half)) {
          passed++;
        }
        continue;
      }
      final j = i + offset;
      final (ax, ay) = smoothed[math.max(0, j - 2)];
      final (bx, by) = smoothed[math.min(smoothed.length - 1, j + 2)];
      final dx = bx - ax, dy = by - ay;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length < 1e-6) continue;
      final nx = -dy / length, ny = dx / length;
      if (side(cx, cy, nx, ny, half) && side(cx, cy, -nx, -ny, half)) passed++;
    }
    if (tried == 0 || passed * 2 < tried) return;
    b.accepted = true;
  }

  /// 位置(x, y)が、芯の画素[core]の線とほぼ同じ暗さ（不透明さ）の塗りの面か：
  /// 線のインクとして測れない（細い形ではない）所で、その場所の地と線の
  /// 差に比べて線にごく近い暗さ（不透明さ）。
  bool _body(double x, double y, bool darkLine, int core) {
    final px = x.floor(), py = y.floor();
    if (px < 0 || py < 0 || px >= width || py >= height) return false;
    final q = py * width + px;
    if (ink[q] >= 64) return false;
    if (darkLine) {
      final l = lum[core];
      return (lum[q] - l) * 4 <=
          math.max(closed[q] - l, PixelArtLines._minDark);
    }
    final a = alpha[core];
    return (a - alpha[q]) * 4 <=
        math.max(a - opened![q], PixelArtLines._minAlpha);
  }

  /// (x, y)から8方向へ[radius]の所のどれかが、線と同じ暗さの広い面か：
  /// その所と、同じ向きにさらに[spread]先の所が[_body]で、先の所の周りの
  /// 8方向も[_wideBody]。線と同じ色の細い・太い線（暗い影の横で線として
  /// 測れない縁取り）に触れるだけの線は、塗った形の一部ではない。
  bool _touches(
    double x,
    double y,
    double radius,
    double spread,
    bool darkLine,
    int core,
  ) {
    const c = 0.7071067811865476;
    final far = radius + spread;
    return _touchesAt(x, y, 1, 0, radius, far, spread, darkLine, core) ||
        _touchesAt(x, y, c, c, radius, far, spread, darkLine, core) ||
        _touchesAt(x, y, 0, 1, radius, far, spread, darkLine, core) ||
        _touchesAt(x, y, -c, c, radius, far, spread, darkLine, core) ||
        _touchesAt(x, y, -1, 0, radius, far, spread, darkLine, core) ||
        _touchesAt(x, y, -c, -c, radius, far, spread, darkLine, core) ||
        _touchesAt(x, y, 0, -1, radius, far, spread, darkLine, core) ||
        _touchesAt(x, y, c, -c, radius, far, spread, darkLine, core);
  }

  /// [_touches]の1方向（向き(ux, uy)）。
  bool _touchesAt(
    double x,
    double y,
    double ux,
    double uy,
    double radius,
    double far,
    double spread,
    bool darkLine,
    int core,
  ) =>
      _body(x + ux * radius, y + uy * radius, darkLine, core) &&
      _body(x + ux * far, y + uy * far, darkLine, core) &&
      _wideBody(x + ux * far, y + uy * far, spread, darkLine, core);

  /// (x, y)から8方向へ[spread]の所の5つ以上が[_body]か（線の上では、線に
  /// 沿った向きだけ）。
  bool _wideBody(double x, double y, double spread, bool darkLine, int core) {
    const c = 0.7071067811865476;
    final d = c * spread;
    var missing = 0;
    if (!_body(x + spread, y, darkLine, core)) missing++;
    if (!_body(x + d, y + d, darkLine, core)) missing++;
    if (!_body(x, y + spread, darkLine, core)) missing++;
    if (!_body(x - d, y + d, darkLine, core)) missing++;
    if (missing > 3) return false;
    if (!_body(x - spread, y, darkLine, core)) missing++;
    if (!_body(x - d, y - d, darkLine, core)) missing++;
    if (missing > 3) return false;
    if (!_body(x, y - spread, darkLine, core)) missing++;
    if (!_body(x + d, y - d, darkLine, core)) missing++;
    return missing <= 3;
  }

  /// [b]の中心線を、太さ[dots]ドットで描くときの両端にそろえたもの。
  ///
  /// 細線化した中心線は、線の端の手前で終わり、端で少し曲がる（丸い端の
  /// 片側へ寄る）：端の少し手前からの向きのまま、インクの端（線の先）まで
  /// 延ばし、そこから置くドットの半分だけ戻した所を、描く線の端にする
  /// （描いた線の長さが元の線の長さを丸めたものになる。ただし線が4分の1
  /// ドット入るドットまでは描く：線どうしが触れている所を離さない）。
  List<(double, double)> _endsFor(_Branch b, int dots) {
    final inset = dots * size / 2 - size / 4;
    var path = b.centre;
    if (!b.closed && path.length >= 2) {
      if (b.end < 0) path = _straightEnd(path, b.width, inset);
      if (b.start < 0) {
        path = _straightEnd(
          path.reversed.toList(),
          b.width,
          inset,
        ).reversed.toList();
      }
    }
    return path;
  }

  /// [points]の最後（線の端）を、端から線の太さの半分ほど手前の向きに
  /// そろえ、その向きにインクの端まで延ばしてから[inset]だけ戻したもの
  /// （線の残りの真ん中より手前へは戻さない）。
  List<(double, double)> _straightEnd(
    List<(double, double)> points,
    double width,
    double inset,
  ) {
    double gap((double, double) a, (double, double) b) => math.sqrt(
      (a.$1 - b.$1) * (a.$1 - b.$1) + (a.$2 - b.$2) * (a.$2 - b.$2),
    );
    final end = points.last;
    // 端の曲がりの手前の点と、そこから向きを測る点。
    var anchor = -1;
    var walked = 0.0;
    for (var i = points.length - 2; i >= 0; i--) {
      walked += gap(points[i], points[i + 1]);
      if (walked >= math.max(2.0, width / 2 + 1)) {
        anchor = i;
        break;
      }
    }
    var base = -1;
    if (anchor > 0) {
      walked = 0;
      for (var i = anchor - 1; i >= 0; i--) {
        walked += gap(points[i], points[i + 1]);
        base = i;
        if (walked >= math.max(4.0, width)) break;
      }
    }
    final (double, double) from, to;
    if (anchor < 0 || base < 0) {
      // 短い線：線全体の向き。
      from = points.first;
      to = points.length > 2 ? points[points.length ~/ 2] : end;
      anchor = points.length > 2 ? points.length ~/ 2 : points.length - 1;
    } else {
      from = points[base];
      to = points[anchor];
    }
    var dx = to.$1 - from.$1, dy = to.$2 - from.$2;
    if (anchor == points.length - 1) {
      dx = end.$1 - from.$1;
      dy = end.$2 - from.$2;
    }
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1e-6) return points;
    final ux = dx / length, uy = dy / length;
    final (ax, ay) = points[anchor];
    // インクの端（線の先）まで。
    var reachTip = math.max(0.0, (end.$1 - ax) * ux + (end.$2 - ay) * uy);
    final limit = reachTip + reach + 2;
    while (reachTip + 0.5 <= limit &&
        _inkAt(ax + ux * (reachTip + 0.5), ay + uy * (reachTip + 0.5)) >= 128) {
      reachTip += 0.5;
    }
    reachTip += 0.25;
    final tip = reachTip - inset;
    if (tip >= 0) {
      return [...points.sublist(0, anchor + 1), (ax + ux * tip, ay + uy * tip)];
    }
    // 戻す分が端の手前の点より奥：線をたどって戻る（真ん中まで）。
    var back = -tip;
    var i = anchor;
    final stop = points.length ~/ 2;
    while (i > stop) {
      final step = gap(points[i], points[i - 1]);
      if (step >= back) {
        final t = back / step;
        final (px, py) = points[i];
        final (qx, qy) = points[i - 1];
        return [
          ...points.sublist(0, i),
          (px + (qx - px) * t, py + (qy - py) * t),
        ];
      }
      back -= step;
      i--;
    }
    return points.sublist(0, stop + 1);
  }

  /// 線が短い間に60°より大きく曲がる所（四角の角など）を、手前と先の
  /// まっすぐな所を延ばして交わる点にする（細線化と中心線のならしで角が
  /// 丸まり、角のドットが抜けた）。
  static List<(double, double)> _sharpenCorners(
    List<(double, double)> points,
    bool closed,
    double width,
  ) {
    final n = points.length;
    final k = math.max(3, width.round());
    if (n < 4 * k + 1) return points;
    (double, double) at(int i) => closed ? points[(i % n + n) % n] : points[i];
    bool valid(int i) => closed || (i >= 0 && i < n);
    // 各点での曲がり（前後k点の向きの差、0〜π）。
    final turn = Float64List(n);
    for (var i = 0; i < n; i++) {
      if (!valid(i - k) || !valid(i + k)) continue;
      final (ax, ay) = at(i - k);
      final (bx, by) = at(i);
      final (cx, cy) = at(i + k);
      final ux = bx - ax, uy = by - ay, vx = cx - bx, vy = cy - by;
      final lu = math.sqrt(ux * ux + uy * uy),
          lv = math.sqrt(vx * vx + vy * vy);
      if (lu < 1e-6 || lv < 1e-6) continue;
      turn[i] = math.acos(((ux * vx + uy * vy) / (lu * lv)).clamp(-1.0, 1.0));
    }
    final out = <(double, double)>[];
    final replaced = List<(double, double)?>.filled(n, null);
    final skip = Uint8List(n);
    for (var i = 0; i < n; i++) {
      if (turn[i] < math.pi / 3) continue;
      var peak = true;
      for (var j = i - k; j <= i + k && peak; j++) {
        if (j == i || !valid(j)) continue;
        final t = turn[(j % n + n) % n];
        if (t > turn[i] || (t == turn[i] && (j % n + n) % n < i)) peak = false;
      }
      if (!peak) continue;
      if (!valid(i - 3 * k) || !valid(i + 3 * k)) continue;
      final (ax, ay) = at(i - 3 * k);
      final (bx, by) = at(i - k);
      final (cx, cy) = at(i + k);
      final (dx, dy) = at(i + 3 * k);
      final ux = bx - ax, uy = by - ay, vx = dx - cx, vy = dy - cy;
      final cross = ux * vy - uy * vx;
      if (cross.abs() < 1e-9) continue;
      final t = ((cx - bx) * vy - (cy - by) * vx) / cross;
      final x = bx + ux * t, y = by + uy * t;
      final (px, py) = at(i);
      if ((x - px) * (x - px) + (y - py) * (y - py) > 4.0 * k * k) continue;
      replaced[i] = (x, y);
      for (var j = i - k + 1; j <= i + k - 1; j++) {
        if (j != i) skip[(j % n + n) % n] = 1;
      }
    }
    for (var i = 0; i < n; i++) {
      final r = replaced[i];
      if (r != null) {
        out.add(r);
      } else if (skip[i] == 0) {
        out.add(points[i]);
      }
    }
    return out;
  }

  /// 前後2点ずつの平均（端は動かさない。輪はつながったまま）。
  static List<(double, double)> _smooth(
    List<(double, double)> points,
    bool closed,
  ) {
    const k = 2;
    final n = points.length;
    final out = List<(double, double)>.of(points);
    if (n < 3) return out;
    for (var i = 0; i < n; i++) {
      final reach = closed ? k : math.min(k, math.min(i, n - 1 - i));
      if (reach == 0) continue;
      var sx = 0.0, sy = 0.0;
      for (var j = i - reach; j <= i + reach; j++) {
        final (x, y) = points[(j % n + n) % n];
        sx += x;
        sy += y;
      }
      out[i] = (sx / (2 * reach + 1), sy / (2 * reach + 1));
    }
    return out;
  }

  /// 線の中心線をドットの格子へ写し、ピクセルパーフェクトにして、
  /// 太さの形を置いたドット。
  List<int> _stampCells(_Branch b) {
    final even = b.dots.isEven;
    // 1画素より離れた点の間を埋める（分かれ目の塊をまたぐ所など）。
    final path = <(double, double)>[];
    final points = b.points;
    final count = b.closed ? points.length + 1 : points.length;
    for (var i = 0; i < count; i++) {
      final (x, y) = points[i % points.length];
      if (path.isNotEmpty) {
        final (px, py) = path.last;
        final dx = x - px, dy = y - py;
        final steps = math.sqrt(dx * dx + dy * dy).ceil();
        for (var s = 1; s < steps; s++) {
          path.add((px + dx * s / steps, py + dy * s / steps));
        }
      }
      path.add((x, y));
    }
    // 中心線が通るドット（太さが偶数なら格子の交点）と、そこを通る長さ。
    final runs = <_Run>[];
    for (var i = 0; i < path.length; i++) {
      final (x, y) = path[i];
      // 1/16画素に丸める：ドットの境目ちょうどを通る線が、測った中心の
      // ごく小さな揺れで境目の両側へ行き来しない。
      final fx = (x * scale * 16).round() / 16;
      final fy = (y * scale * 16).round() / 16;
      final cx = _cellAt(fx, xs, cellOfX, even);
      final cy = _cellAt(fy, ys, cellOfY, even);
      if (runs.isNotEmpty && runs.last.x == cx && runs.last.y == cy) {
        final run = runs.last;
        run.count++;
        run.last = i;
      } else {
        runs.add(_Run(cx, cy, i));
      }
    }
    // 線がドットの中で大きく向きを変える所（四角の角など、1ドットの間に
    // 60°より大きく曲がる所）のドットは、L字の角でも取り除かない。
    final reach = size.ceil();
    for (final r in runs) {
      final (ax, ay) =
          path[b.closed
              ? (r.first - reach) % path.length
              : math.max(0, r.first - reach)];
      final (bx, by) = path[r.first];
      final (cx, cy) = path[r.last];
      final (dx, dy) =
          path[b.closed
              ? (r.last + reach) % path.length
              : math.min(path.length - 1, r.last + reach)];
      final ux = bx - ax, uy = by - ay, vx = dx - cx, vy = dy - cy;
      final lu = math.sqrt(ux * ux + uy * uy),
          lv = math.sqrt(vx * vx + vy * vy);
      if (lu < size / 2 || lv < size / 2) continue;
      r.corner = (ux * vx + uy * vy) / (lu * lv) < 0.5;
    }
    if (b.closed && runs.length > 1) {
      final first = runs.first, last = runs.last;
      if (first.x == last.x && first.y == last.y) {
        first.count += last.count;
        first.corner = first.corner || last.corner;
        runs.removeLast();
      }
    }
    // 線の端の近くで線が横切る向きのドットの境目を越え、次のドットに
    // ほとんど入らないなら、そのドットは描かない（描くと、線の端に1ドットの
    // 足が付く）。線の進む向きへの1ドットは残す。
    if (!b.closed && !even && path.length >= 2) {
      final enough = size / 3;
      bool across(
        _Run end,
        _Run next,
        (double, double) tip,
        (double, double) back,
      ) {
        final dx = (tip.$1 - back.$1).abs(), dy = (tip.$2 - back.$2).abs();
        return (end.y != next.y && dy < 0.5 * dx) ||
            (end.x != next.x && dx < 0.5 * dy);
      }

      (double, double) behind(bool fromEnd) {
        var walked = 0.0;
        final n = path.length;
        for (var i = 1; i < n; i++) {
          final a = fromEnd ? path[n - i] : path[i - 1];
          final c = fromEnd ? path[n - 1 - i] : path[i];
          walked += math.sqrt(
            (a.$1 - c.$1) * (a.$1 - c.$1) + (a.$2 - c.$2) * (a.$2 - c.$2),
          );
          if (walked >= size) return c;
        }
        return fromEnd ? path.first : path.last;
      }

      if (b.end < 0 &&
          runs.length >= 2 &&
          runs.last.count < enough &&
          runs.last.count <= runs[runs.length - 2].count &&
          across(runs.last, runs[runs.length - 2], path.last, behind(true))) {
        runs.removeLast();
      }
      if (b.start < 0 &&
          runs.length >= 2 &&
          runs.first.count < enough &&
          runs.first.count <= runs[1].count &&
          across(runs.first, runs[1], path.first, behind(false))) {
        runs.removeAt(0);
      }
    }
    // 境目を少しだけ越えて戻る所の深さ（元の絵の画素）：その間の点が、
    // 前後のドットの行（列）の境目から、隣の行（列）へ入った最大の距離。
    double depth(_Run bump, _Run from, bool alongY) {
      if (even || bump.first > bump.last) return double.infinity;
      final edges = alongY ? ys : xs;
      final into = alongY ? bump.y : bump.x, base = alongY ? from.y : from.x;
      final edge = into < base ? edges[base] : edges[into];
      var most = 0.0;
      for (var i = bump.first; i <= bump.last; i++) {
        final v =
            ((alongY ? path[i].$2 : path[i].$1) * scale * 16).round() / 16;
        most = math.max(most, into < base ? edge - v : v - edge);
      }
      return most;
    }

    _flattenBumps(runs, b.closed, size / 2, (bump, from, alongY) {
      final edges = alongY ? ys : xs, at = alongY ? from.y : from.x;
      final dot = edges[at + 1] - edges[at];
      return depth(bump, from, alongY) < PixelArtLines._shallow * dot;
    });
    _pixelPerfect(runs, b.closed, even ? cellsX + 1 : cellsX);

    final cells = <int>[];
    final seen = <int>{};
    void put(int cx, int cy) {
      if (cx < 0 || cy < 0 || cx >= cellsX || cy >= cellsY) return;
      final c = cy * cellsX + cx;
      if (seen.add(c)) cells.add(c);
    }

    for (final r in runs) {
      if (even) {
        // 2×2：格子の交点を中心に。
        put(r.x - 1, r.y - 1);
        put(r.x, r.y - 1);
        put(r.x - 1, r.y);
        put(r.x, r.y);
      } else {
        put(r.x, r.y);
      }
    }
    return cells;
  }

  /// 位置[v]（画素の座標）を含むドット。[vertex]なら最も近い格子の線。
  static int _cellAt(double v, List<int> edges, Int32List cellOf, bool vertex) {
    final px = v.floor().clamp(0, cellOf.length - 1);
    final lo = cellOf[px];
    if (!vertex) return lo;
    return v * 2 >= edges[lo] + edges[lo + 1] ? lo + 1 : lo;
  }

  /// 線が隣の行（列）へ半ドットも入らずにすぐ戻る所（境目の近くを通る
  /// 線の小さな揺れ）を、前後と同じ行（列）にそろえる。
  static void _flattenBumps(
    List<_Run> runs,
    bool closed,
    double enough,
    bool Function(_Run bump, _Run from, bool alongY) shallow,
  ) {
    final n = runs.length;
    if (n < 3) return;
    for (var i = 0; i < n; i++) {
      if (!closed && (i == 0 || i == n - 1)) continue;
      final a = runs[(i - 1 + n) % n], b = runs[i], c = runs[(i + 1) % n];
      if (b.corner) continue;
      final rowBump = a.y == c.y && b.y != a.y && (b.y - a.y).abs() == 1;
      final columnBump = a.x == c.x && b.x != a.x && (b.x - a.x).abs() == 1;
      // 短いか、境目をほんの少し越えるだけ（線の中心が境目に沿って揺れる）。
      if (b.count >= enough &&
          !(rowBump && shallow(b, a, true)) &&
          !(columnBump && shallow(b, a, false))) {
        continue;
      }
      if (rowBump) {
        runs[i] = _Run(b.x, a.y, b.first)
          ..last = b.last
          ..count = b.count
          ..corner = b.corner;
      } else if (a.x == c.x && b.x != a.x && (b.x - a.x).abs() == 1) {
        runs[i] = _Run(a.x, b.y, b.first)
          ..last = b.last
          ..count = b.count
          ..corner = b.corner;
      }
    }
    // 同じドットが続いたら1つにまとめる。
    for (var i = runs.length - 1; i > 0; i--) {
      final a = runs[i - 1], b = runs[i];
      if (a.x == b.x && a.y == b.y) {
        a
          ..count += b.count
          ..last = b.last
          ..corner = a.corner || b.corner;
        runs.removeAt(i);
      }
    }
  }

  /// ドットの並びから、線を太らせるだけのドットを取り除く：前後のドットが
  /// 斜めに隣り合うL字の角と、1ドットだけ戻る所。どちらの角を取るかは、
  /// 中心線がそのドットを通る長さの短い方（並びの向きにはよらない）。端の
  /// ドット（線の端・分かれ目）は残す。
  static void _pixelPerfect(List<_Run> runs, bool closed, int stride) {
    var changed = true;
    while (changed && runs.length >= 3) {
      changed = false;
      final n = runs.length;
      // 1ドットだけ戻る所：戻った先と1つにまとめる。
      for (var i = 0; i < runs.length; i++) {
        if (!closed && (i == 0 || i >= runs.length - 1)) continue;
        if (runs.length < 3) break;
        final prev = runs[(i - 1 + runs.length) % runs.length];
        final next = runs[(i + 1) % runs.length];
        if (prev.x == next.x && prev.y == next.y) {
          prev.count += runs[i].count + next.count;
          final nextIndex = (i + 1) % runs.length;
          if (nextIndex > i) {
            runs.removeAt(nextIndex);
            runs.removeAt(i);
          } else {
            runs.removeAt(i);
            runs.removeAt(nextIndex);
          }
          changed = true;
          break;
        }
      }
      if (changed) continue;
      // L字の角。
      bool corner(int i) {
        if (!closed && (i <= 0 || i >= runs.length - 1)) return false;
        if (runs[i].corner) return false;
        final prev = runs[(i - 1 + runs.length) % runs.length];
        final next = runs[(i + 1) % runs.length];
        return (prev.x - next.x).abs() == 1 && (prev.y - next.y).abs() == 1;
      }

      bool before(int a, int b) {
        final ra = runs[a], rb = runs[b];
        if (ra.count != rb.count) return ra.count < rb.count;
        return ra.y * stride + ra.x < rb.y * stride + rb.x;
      }

      final drop = <int>[];
      for (var i = 0; i < n; i++) {
        if (!corner(i)) continue;
        final p = (i - 1 + n) % n, q = (i + 1) % n;
        if ((closed || p != n - 1) && corner(p) && before(p, i)) continue;
        if ((closed || q != 0) && corner(q) && before(q, i)) continue;
        drop.add(i);
      }
      if (drop.isEmpty || runs.length - drop.length < 2) break;
      for (final i in drop.reversed) {
        runs.removeAt(i);
      }
      changed = true;
    }
  }

  /// [li]（細線化した画像の上）から線の形の外へ出るまでの距離（正方形で
  /// 数えた画素数）：線の太さの半分。
  int _halfWidth(Uint8List shape, int li) {
    final lx = li % lw, ly = li ~/ lw;
    for (var r = 1; r < math.max(lw, lh); r++) {
      for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          if (dx.abs() != r && dy.abs() != r) continue;
          final x = lx + dx, y = ly + dy;
          if (x < 0 || y < 0 || x >= lw || y >= lh) return r;
          if (shape[y * lw + x] == 0) return r;
        }
      }
    }
    return 0;
  }

  /// Zhang-Suenの細線化（Lü-Wangの補正つき：斜めの線を端から食べない）。
  void _thinZhangSuen(Uint8List img, Int32List fore) =>
      _thin(img, fore, _zhangSuen);

  /// Zhang-Suenが残す2画素の階段を1画素にする（Guo-Hallの細線化）。
  void _thinGuoHall(Uint8List img, Int32List fore) =>
      _thin(img, fore, _guoHall);

  /// 2つの段（[tables]の0と1）を、取り除く画素が無くなるまで交互に。
  /// 各段は、その段で前に確かめてから周りが変わった画素だけを確かめ直す
  /// （周りが同じなら答えも同じ。段の中では取り除く画素を先にすべて
  /// 決めてから取り除くので、確かめる順序によらない）。
  void _thin(Uint8List img, Int32List fore, List<Uint8List> tables) {
    final n = fore.length;
    final lists = [Int32List(n), Int32List(n)];
    final counts = [0, 0];
    // 画素ごとに、段0（ビット1）・段1（ビット2）で確かめ直すか。
    final flags = _flags ??= Uint8List(img.length);
    // 画素ごとの周り8画素の並び（取り除くたびに隣の分を直す）。
    final masks = _masks ??= Uint8List(img.length);
    var live = 0;
    for (var k = 0; k < n; k++) {
      final i = fore[k];
      if (img[i] == 0) {
        flags[i] = 0;
        continue;
      }
      flags[i] = 3;
      masks[i] = _around(img, i);
      lists[0][live] = i;
      lists[1][live] = i;
      live++;
    }
    counts[0] = counts[1] = live;
    final remove = Int32List(n);
    final o = _offsets;
    var quiet = 0;
    for (var pass = 0; quiet < 2; pass ^= 1) {
      final table = tables[pass], list = lists[pass], bit = 1 << pass;
      final total = counts[pass];
      var removed = 0;
      for (var k = 0; k < total; k++) {
        final i = list[k];
        flags[i] &= ~bit;
        if (img[i] == 0) continue;
        if (table[masks[i]] != 0) remove[removed++] = i;
      }
      counts[pass] = 0;
      if (removed == 0) {
        quiet++;
        continue;
      }
      quiet = 0;
      for (var k = 0; k < removed; k++) {
        img[remove[k]] = 0;
      }
      final list0 = lists[0], list1 = lists[1];
      var n0 = counts[0], n1 = counts[1];
      for (var k = 0; k < removed; k++) {
        final i = remove[k];
        var alive = 0;
        for (var j = 0; j < 8; j++) {
          final q = i + o[j];
          if (img[q] == 0) continue;
          alive++;
          masks[q] &= ~(1 << ((j + 4) & 7));
          final f = flags[q];
          if (f & 1 == 0) list0[n0++] = q;
          if (f & 2 == 0) list1[n1++] = q;
          flags[q] = 3;
        }
        // 周りがすべて消えた画素：形がまるごと消えたかもしれない。
        if (alive == 0) _alone.add(i);
      }
      counts[0] = n0;
      counts[1] = n1;
    }
  }

  /// 周り8画素の並びごとに、細線化の各段でその画素を取り除くか。ビットは
  /// 上から時計回り（p2, p3, …, p9）。
  static final List<Uint8List> _zhangSuen = [
    for (final pass in [0, 1])
      Uint8List.fromList([
        for (var m = 0; m < 256; m++)
          () {
            int p(int k) => (m >> k) & 1;
            final p2 = p(0), p3 = p(1), p4 = p(2), p5 = p(3);
            final p6 = p(4), p7 = p(5), p8 = p(6), p9 = p(7);
            final ns = p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9;
            if (ns < 3 || ns > 6) return 0;
            final ring = [p2, p3, p4, p5, p6, p7, p8, p9, p2];
            var transitions = 0;
            for (var r = 0; r < 8; r++) {
              if (ring[r] == 0 && ring[r + 1] != 0) transitions++;
            }
            if (transitions != 1) return 0;
            if (pass == 0) {
              if (p2 * p4 * p6 != 0 || p4 * p6 * p8 != 0) return 0;
            } else {
              if (p2 * p4 * p8 != 0 || p2 * p6 * p8 != 0) return 0;
            }
            return 1;
          }(),
      ]),
  ];

  static final List<Uint8List> _guoHall = [
    for (final pass in [0, 1])
      Uint8List.fromList([
        for (var m = 0; m < 256; m++)
          () {
            int p(int k) => (m >> k) & 1;
            final p2 = p(0), p3 = p(1), p4 = p(2), p5 = p(3);
            final p6 = p(4), p7 = p(5), p8 = p(6), p9 = p(7);
            final runs =
                (p2 == 0 && (p3 | p4) != 0 ? 1 : 0) +
                (p4 == 0 && (p5 | p6) != 0 ? 1 : 0) +
                (p6 == 0 && (p7 | p8) != 0 ? 1 : 0) +
                (p8 == 0 && (p9 | p2) != 0 ? 1 : 0);
            if (runs != 1) return 0;
            final n1 = (p9 | p2) + (p3 | p4) + (p5 | p6) + (p7 | p8);
            final n2 = (p2 | p3) + (p4 | p5) + (p6 | p7) + (p8 | p9);
            final nn = math.min(n1, n2);
            if (nn < 2 || nn > 3) return 0;
            final side = pass == 0
                ? (p6 | p7 | (1 - p9)) & p8
                : (p2 | p3 | (1 - p5)) & p4;
            return side != 0 ? 0 : 1;
          }(),
      ]),
  ];

  /// 細線化で丸ごと消えた小さな点（目など）に、真ん中の1画素を戻す。
  /// 丸ごと消えた形の最後の画素は、取り除いたときに周りが残っていない
  /// （[_alone]）：そこから中心線の画素を探し、無ければその形に戻す。
  void _keepVanishedDots(Uint8List shape, Uint8List skeleton) {
    final alone = _alone;
    if (alone.isEmpty) return;
    final seen = Uint8List(shape.length), mark = Uint8List(shape.length);
    final o = _offsets;
    final search = <int>[], queue = <int>[];
    for (final from in alone) {
      if (seen[from] != 0) continue;
      search
        ..clear()
        ..add(from);
      mark[from] = 1;
      var centre = skeleton[from] != 0, first = from, found = -1;
      for (var head = 0; head < search.length && !centre; head++) {
        final p = search[head];
        for (var j = 0; j < 8; j++) {
          final q = p + o[j];
          if (shape[q] == 0 || mark[q] != 0) continue;
          if (skeleton[q] != 0) {
            centre = true;
            found = q;
            break;
          }
          mark[q] = 1;
          search.add(q);
          if (q < first) first = q;
        }
      }
      for (final p in search) {
        mark[p] = 0;
      }
      if (found >= 0) mark[found] = 0;
      if (centre) continue;
      // 形の上の行から最初の画素から広げる（同じ距離の画素の選び方を
      // 決める）。
      queue
        ..clear()
        ..add(first);
      seen[first] = 1;
      var sx = 0.0, sy = 0.0;
      for (var head = 0; head < queue.length; head++) {
        final p = queue[head];
        sx += p % lw;
        sy += p ~/ lw;
        for (var j = 0; j < 8; j++) {
          final q = p + o[j];
          if (shape[q] == 0 || seen[q] != 0) continue;
          seen[q] = 1;
          queue.add(q);
        }
      }
      final cx = sx / queue.length, cy = sy / queue.length;
      var best = queue.first;
      var bestDistance = double.infinity;
      for (final p in queue) {
        final dx = p % lw - cx, dy = p ~/ lw - cy;
        final d = dx * dx + dy * dy;
        if (d < bestDistance) {
          bestDistance = d;
          best = p;
        }
      }
      skeleton[best] = 1;
    }
  }

  /// [pixels]のうち、[img]で残っている画素（順序はそのまま）。
  static Int32List _kept(Int32List pixels, Uint8List img) {
    var count = 0;
    for (final i in pixels) {
      if (img[i] != 0) count++;
    }
    final out = Int32List(count);
    var k = 0;
    for (final i in pixels) {
      if (img[i] != 0) out[k++] = i;
    }
    return out;
  }

  /// 周り8画素の並び（[PixelArtLines._ring]の順のビット。[img]は0か1）。
  int _around(Uint8List img, int i) {
    final w = lw;
    return img[i - w] |
        img[i - w + 1] << 1 |
        img[i + 1] << 2 |
        img[i + w + 1] << 3 |
        img[i + w] << 4 |
        img[i + w - 1] << 5 |
        img[i - 1] << 6 |
        img[i - w - 1] << 7;
  }

  /// 8ビットの並びごとの、立っているビットの数。
  static final Uint8List _bits = Uint8List.fromList([
    for (var m = 0; m < 256; m++)
      [for (var k = 0; k < 8; k++) (m >> k) & 1].fold(0, (a, b) => a + b),
  ]);

  /// 周り8画素の並びごとに：段の角の余分な画素として取り除けるか（隣が
  /// 2〜3画素で、縦にも横にも隣があり、2×2の塊の一部ではなく、隣どうしが
  /// 1つにつながっている）。
  static final Uint8List _stepCorner = () {
    final table = Uint8List(256);
    for (var m = 0; m < 256; m++) {
      bool on(int k) => m & (1 << k) != 0;
      var count = 0;
      for (var k = 0; k < 8; k++) {
        if (on(k)) count++;
      }
      if (count < 2 || count > 3) continue;
      if (!(on(0) || on(4)) || !(on(2) || on(6))) continue;
      final knot =
          (on(0) && on(1) && on(2)) ||
          (on(2) && on(3) && on(4)) ||
          (on(4) && on(5) && on(6)) ||
          (on(6) && on(7) && on(0));
      if (knot) continue;
      if (_ringGroups(m) != 1) continue;
      table[m] = 1;
    }
    return table;
  }();

  /// 周り8画素の並び[m]の線の画素が、互いに隣り合うまとまりいくつに
  /// 分かれるか。
  static int _ringGroups(int m) {
    final group = List<int>.generate(8, (k) => k);
    int find(int k) {
      while (group[k] != k) {
        k = group[k] = group[group[k]];
      }
      return k;
    }

    for (var a = 0; a < 8; a++) {
      if (m & (1 << a) == 0) continue;
      for (var b = a + 1; b < 8; b++) {
        if (m & (1 << b) == 0) continue;
        final (ax, ay) = PixelArtLines._ring[a];
        final (bx, by) = PixelArtLines._ring[b];
        if ((ax - bx).abs() <= 1 && (ay - by).abs() <= 1) {
          group[find(a)] = find(b);
        }
      }
    }
    return {
      for (var k = 0; k < 8; k++)
        if (m & (1 << k) != 0) find(k),
    }.length;
  }

  /// 細線化で段の角に残る余分な画素（3画素のL字の角）を取り除き、線の
  /// どの画素も前後の1画素ずつとだけ隣り合うようにする。[live]（上の行から
  /// 順の中心線の画素）のうち残った画素を返す。
  Int32List _removeSteps(Uint8List img, Int32List live) {
    final table = _stepCorner;
    for (var pass = 0; pass < 8; pass++) {
      var removed = false;
      for (final i in live) {
        if (img[i] == 0) continue;
        if (table[_around(img, i)] == 0) continue;
        img[i] = 0;
        removed = true;
      }
      if (!removed) break;
      live = _kept(live, img);
    }
    return live;
  }

  /// 中心線を、分かれ目（3本以上が集まる画素のまとまり）と端の間の線に分ける。
  /// 線を[first]（[previous]の隣）からたどる（分かれ目[from]から、または
  /// 端から）。
  _Branch _walk(
    Uint8List img,
    Uint8List degree,
    Int32List nodeOf,
    Uint8List visited,
    int from,
    int first,
    int previous,
  ) {
    final o = _offsets;
    final path = <int>[first];
    visited[first] = 1;
    var prev = previous, cur = first;
    var end = -1;
    while (true) {
      if (degree[cur] <= 1 && path.length > 1) break;
      var next = -1, junction = -1;
      for (var j = 0; j < 8; j++) {
        final q = cur + o[j];
        if (img[q] == 0 || q == prev) continue;
        if (nodeOf[q] >= 0) {
          if (junction < 0) junction = q;
          continue;
        }
        if (visited[q] != 0) continue;
        if (next < 0) next = q;
      }
      if (next < 0) {
        if (junction >= 0) end = nodeOf[junction];
        break;
      }
      visited[next] = 1;
      path.add(next);
      prev = cur;
      cur = next;
    }
    return _Branch(path, from, end);
  }

  ({List<_Branch> branches, List<List<int>> nodes}) _trace(
    Uint8List img,
    Int32List live,
  ) {
    // 作業用の配列は、中心線の画素の所だけ使う（毎回作り直さない）。
    final degree = _degree ??= Uint8List(img.length);
    final nodeOf = _nodeOf ??= Int32List(img.length);
    final visited = _visited ??= Uint8List(img.length);
    final bits = _bits;
    final o = _offsets;
    for (final i in live) {
      if (img[i] == 0) continue;
      degree[i] = bits[_around(img, i)];
      nodeOf[i] = -1;
      visited[i] = 0;
    }
    final nodes = <List<int>>[];
    for (final i in live) {
      if (img[i] == 0 || degree[i] < 3 || nodeOf[i] >= 0) continue;
      final id = nodes.length;
      final members = <int>[i];
      nodeOf[i] = id;
      for (var head = 0; head < members.length; head++) {
        final p = members[head];
        for (var j = 0; j < 8; j++) {
          final q = p + o[j];
          if (img[q] == 0 || degree[q] < 3 || nodeOf[q] >= 0) continue;
          nodeOf[q] = id;
          members.add(q);
        }
      }
      nodes.add(members);
    }
    final branches = <_Branch>[];

    for (var id = 0; id < nodes.length; id++) {
      for (final j in nodes[id]) {
        for (var k = 0; k < 8; k++) {
          final m = j + o[k];
          if (img[m] == 0 || nodeOf[m] >= 0 || visited[m] != 0) continue;
          branches.add(_walk(img, degree, nodeOf, visited, id, m, j));
        }
      }
    }
    for (final i in live) {
      if (img[i] == 0) continue;
      if (visited[i] != 0 || nodeOf[i] >= 0 || degree[i] > 1) continue;
      if (degree[i] == 0) {
        visited[i] = 1;
        branches.add(_Branch([i], -1, -1));
        continue;
      }
      branches.add(_walk(img, degree, nodeOf, visited, -1, i, -1));
    }
    // 残りは分かれ目の無い輪。
    for (final i in live) {
      if (img[i] == 0 || visited[i] != 0 || nodeOf[i] >= 0) continue;
      final path = <int>[i];
      visited[i] = 1;
      var prev = -1, cur = i;
      while (true) {
        var next = -1;
        for (var j = 0; j < 8; j++) {
          final q = cur + o[j];
          if (img[q] == 0 || q == prev || visited[q] != 0) continue;
          next = q;
          break;
        }
        if (next < 0) break;
        visited[next] = 1;
        path.add(next);
        prev = cur;
        cur = next;
      }
      branches.add(_Branch(path, -1, -1, closed: path.length >= 3));
    }
    return (branches: branches, nodes: nodes);
  }
}

/// 中心線の各画素に集まるインク：線の形とその縁の画素を、最も近い
/// 中心線の画素へ割り当てる（中心線から近い順に広げる）。
class _Slices {
  _Slices._(this.owner, this.pixels, this.ink);

  /// 画素ごと：割り当てた中心線の画素＋1（割り当てていなければ0）。
  final Int32List owner;

  /// 割り当てた画素。
  final Int32List pixels;

  /// 中心線の画素ごとのインクの合計（0〜255の和）。
  final Float64List ink;

  static _Slices of(_Analysis a, List<int> skeleton) {
    final width = a.width, height = a.height;
    final owner = Int32List(width * height);
    final k = skeleton.length;
    final ink = Float64List(k);
    // 割り当てる範囲：線の形の外接矩形を、線の縁が入るだけ広げたもの。
    final rx0 = math.max(0, a.x0 - a.reach);
    final ry0 = math.max(0, a.y0 - a.reach);
    final rx1 = math.min(width - 1, a.x0 + a.lw - 3 + a.reach);
    final ry1 = math.min(height - 1, a.y0 + a.lh - 3 + a.reach);
    final queue = Int32List((rx1 - rx0 + 1) * (ry1 - ry0 + 1));
    var tail = 0;
    for (var s = 0; s < k; s++) {
      final p = a._global(skeleton[s]);
      owner[p] = s + 1;
      queue[tail++] = p;
    }
    // 中心線から線の太さの上限の半分までの、インクのある画素（線の縁の
    // ごく薄い画素も：残すと、線を外したドットに薄い色や不透明度が残る）。
    var layerEnd = tail;
    var layer = 0;
    final source = a.ink;
    for (var head = 0; head < tail; head++) {
      if (head == layerEnd) {
        layer++;
        layerEnd = tail;
        if (layer > a.reach) break;
      }
      final p = queue[head];
      final y = p ~/ width, x = p - y * width;
      final s = owner[p];
      if (x > rx0 && y > ry0 && x < rx1 && y < ry1) {
        for (var j = 0; j < 8; j++) {
          final q = p + _dy[j] * width + _dx[j];
          if (owner[q] != 0 || source[q] == 0) continue;
          owner[q] = s;
          queue[tail++] = q;
        }
        continue;
      }
      for (var j = 0; j < 8; j++) {
        final nx = x + _dx[j], ny = y + _dy[j];
        if (nx < rx0 || ny < ry0 || nx > rx1 || ny > ry1) continue;
        final q = ny * width + nx;
        if (owner[q] != 0 || source[q] == 0) continue;
        owner[q] = s;
        queue[tail++] = q;
      }
    }
    for (var i = 0; i < tail; i++) {
      final p = queue[i];
      ink[owner[p] - 1] += source[p];
    }
    return _Slices._(owner, Int32List.sublistView(queue, 0, tail), ink);
  }
}

/// 8近傍のずれ（[PixelArtLines._ring]と同じ順）。
const _dx = [0, 1, 1, 1, 0, -1, -1, -1];
const _dy = [-1, -1, 0, 1, 1, 1, 0, -1];

/// ドットの並びの1つ（同じドットが続く間）。
class _Run {
  _Run(this.x, this.y, this.first) : last = first;
  final int x, y;

  /// 中心線がこのドットを通る長さ（点の数）と、その最初と最後の点。
  int count = 1;
  final int first;
  int last;

  /// 線がこのドットで大きく向きを変える（L字の角でも残す）。
  bool corner = false;
}
