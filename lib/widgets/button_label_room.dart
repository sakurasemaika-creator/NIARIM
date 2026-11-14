import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// ボタンのラベルの上下に取る余白（8px。文字が2倍より大きければ字の大きさに
/// 合わせて広げる）。
double buttonLabelRoom(BuildContext context) =>
    math.max(8, MediaQuery.textScalerOf(context).scale(4));

/// 塗り・枠・文字・浮きのボタンのテーマに渡す、ラベルの上下の余白
/// （[ButtonStyle.foregroundBuilder]）。[minHeight]はそのテーマのボタンの
/// 最小の高さ。
///
/// Material 3のボタンは上下の余白が0で、ボタンはラベルの行の高さぴったり
/// までしか伸びない。くらむぼんは行の高さが字の大きさと同じ（1em）で、
/// アクセント（É）や下に伸びる字（p・g）が行の外へ出るので、ラベルが2行以上
/// になる（大きな文字のフランス語の「Réinitialiser aux valeurs par défaut」
/// 等）と、字がボタンの枠を越えた。ラベルが折り返して、最小の高さから上下の
/// 余白を引いた高さより高くなったときだけ上下に余白を取り、ボタンを伸ばす。
/// 余白は、字の描かれる所（行の外へ出たアクセント・下に伸びる字）から
/// [buttonLabelRoom]を取る（行の端から取ると、字と枠の間が3〜6pxしか残らな
/// かった）。1行のラベルは余白を取らず、ボタンの高さも見た目も変わらない
/// （行の中で小さくしたボタン、行の高い韓国語・中国語の書体の1行も同じ）。
ButtonLayerBuilder buttonLabelRoomBuilder({required double minHeight}) =>
    (context, states, child) => child == null
    ? const SizedBox.shrink()
    : _ButtonLabelRoom(
        room: buttonLabelRoom(context),
        // 机の上の端末（密度compact）では、ボタンの最小の高さが8px低い。
        minHeight:
            minHeight + Theme.of(context).visualDensity.baseSizeAdjustment.dy,
        child: child,
      );

/// 字の描かれる所が、行の高さ（フォントのascent・descent）の外へ出る書体の、
/// 字の描かれる上端・下端（ベースラインから、字の大きさに対する割合）。
///
/// くらむぼんの行の高さはascent 0.88・descent 0.12（1em）だが、アプリの文
/// （7言語のARB）の字は上へÓ・À・É（1.113em）、下へç・j・g・p（0.278em）まで
/// 描かれる。ほかの同梱の書体は、行の高さの中に字が収まる（Noto Sans KR/SC
/// Black・白光明朝・Noto Serif JP/KR/SC・Dela Gothic One：ascent 1.15〜1.16・
/// descent 0.29で、字は上1.03em・下0.28emまで）。
const Map<String, ({double top, double bottom})> _inkExtents = {
  'Kuramubon': (top: 1.12, bottom: 0.28),
};

/// [_inkOverhang]の、書式と字の大きさごとの結果。
final Map<(TextStyle, double), double> _inkOverhangCache = {};

/// 字の縁のにじみ（アンチエイリアス）と画素への位置合わせで、字の画素が字の
/// 形より外に描かれる分（論理px）。くらむぼんの太字を12〜28pxで描いて測ると、
/// 字の形の上下より最大1.3px外まで色の付いた画素があった。
const double _antialiasBleed = 1.5;

/// 書式[style]・字の倍率[scaler]の1行の、行の上下から字の画素がはみ出す量
/// （上と下の大きい方、論理px）。
double _inkOverhang(TextStyle style, TextScaler scaler) {
  final extents = _inkExtents[style.fontFamily];
  if (extents == null) return 0;
  final size = scaler.scale(style.fontSize ?? 14);
  final key = (style, size);
  final cached = _inkOverhangCache[key];
  if (cached != null) return cached;
  // 行の上下（ascent・descent。行の高さの指定があればその分も）は、書体の
  // 字を1つ並べて測る。
  final painter = TextPainter(
    text: TextSpan(text: 'H', style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  final line = painter.computeLineMetrics().first;
  painter.dispose();
  final overhang = math.max(
    0.0,
    math.max(
          extents.top * size - line.ascent,
          extents.bottom * size - line.descent,
        ) +
        _antialiasBleed,
  );
  if (_inkOverhangCache.length > 64) _inkOverhangCache.clear();
  return _inkOverhangCache[key] = overhang;
}

class _ButtonLabelRoom extends SingleChildRenderObjectWidget {
  const _ButtonLabelRoom({
    required this.room,
    required this.minHeight,
    required super.child,
  });

  final double room;
  final double minHeight;

  @override
  _RenderButtonLabelRoom createRenderObject(BuildContext context) =>
      _RenderButtonLabelRoom(room: room, minHeight: minHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderButtonLabelRoom renderObject,
  ) {
    renderObject
      ..room = room
      ..minHeight = minHeight;
  }
}

class _RenderButtonLabelRoom extends RenderShiftedBox {
  _RenderButtonLabelRoom({required this._room, required this._minHeight})
    : super(null);

  double get room => _room;
  double _room;
  set room(double value) {
    if (_room == value) return;
    _room = value;
    markNeedsLayout();
  }

  double get minHeight => _minHeight;
  double _minHeight;
  set minHeight(double value) {
    if (_minHeight == value) return;
    _minHeight = value;
    markNeedsLayout();
  }

  /// ラベルの段落（アイコンを除く）の字が、行の上下からはみ出す量の最大。
  double _inkOverhangOf(RenderBox child) {
    var overhang = 0.0;
    void visit(RenderObject node) {
      if (node is RenderParagraph) {
        final style = node.text.style;
        if (style != null) {
          overhang = math.max(overhang, _inkOverhang(style, node.textScaler));
        }
        return;
      }
      node.visitChildren(visit);
    }

    visit(child);
    return overhang;
  }

  /// 高さ[height]のラベルの上下に取る余白（字の描かれる所から[room]）。1行の
  /// 高さ（折り返さない幅で並べた高さ）より高い＝折り返したラベルで、最小の
  /// 高さに余白ごと収まらないときだけ取る。
  double _roomFor(double height) {
    final child = this.child;
    if (child == null) return 0;
    final room = _room + _inkOverhangOf(child);
    if (height + 2 * room <= _minHeight + 0.01) return 0;
    final oneLine = child.getMinIntrinsicHeight(double.infinity);
    return height > oneLine + 0.5 ? room : 0;
  }

  Size _sizeFor(Size child, BoxConstraints constraints) => constraints
      .constrain(Size(child.width, child.height + 2 * _roomFor(child.height)));

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = _sizeFor(child.size, constraints);
    (child.parentData! as BoxParentData).offset = Offset(
      0,
      (size.height - child.size.height) / 2,
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return _sizeFor(child.getDryLayout(constraints), constraints);
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    if (child == null) return null;
    final distance = child.getDryBaseline(constraints, baseline);
    if (distance == null) return null;
    final childSize = child.getDryLayout(constraints);
    return distance +
        (_sizeFor(childSize, constraints).height - childSize.height) / 2;
  }

  double _withRoom(double height) => height + 2 * _roomFor(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _withRoom(child?.getMinIntrinsicHeight(width) ?? 0);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _withRoom(child?.getMaxIntrinsicHeight(width) ?? 0);

  @override
  double computeMinIntrinsicWidth(double height) =>
      child?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      child?.getMaxIntrinsicWidth(height) ?? 0;
}
