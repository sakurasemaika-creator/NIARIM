import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// ボタン（[children]）を、どれも名前の幅のまま1行に並べて入る幅では1行に
/// 並べ、最初のボタンを残りの幅いっぱいに広げる。入らなければ1つずつの行に
/// 分け、どれも行の幅いっぱいにする。
///
/// 最初のボタンを`Expanded`で広げた行にほかのボタンを並べると、狭い幅や大きな
/// 文字では最初のボタンが押しつぶされ、名前が1語ずつ・語の途中で折れた
/// （作品の詳細の「Voir sur YouTube」が「Voir / sur / You / Tube」）。
/// 名前は折り返さない幅で測る（ボタンの最大の固有幅）。
class ButtonRowOrStack extends MultiChildRenderObjectWidget {
  const ButtonRowOrStack({super.key, required super.children, this.gap = 8});

  /// ボタンの間（横に並べるときも、行に分けるときも）。
  final double gap;

  @override
  RenderButtonRowOrStack createRenderObject(BuildContext context) =>
      RenderButtonRowOrStack(
        gap: gap,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderButtonRowOrStack renderObject,
  ) {
    renderObject
      ..gap = gap
      ..textDirection = Directionality.of(context);
  }
}

class _ButtonRowOrStackParentData extends ContainerBoxParentData<RenderBox> {}

/// [ButtonRowOrStack]の描画。
class RenderButtonRowOrStack extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ButtonRowOrStackParentData>,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          _ButtonRowOrStackParentData
        > {
  RenderButtonRowOrStack({required this._gap, required this._textDirection});

  double get gap => _gap;
  double _gap;
  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ButtonRowOrStackParentData) {
      child.parentData = _ButtonRowOrStackParentData();
    }
  }

  List<RenderBox> get _children {
    final out = <RenderBox>[];
    for (var child = firstChild; child != null; child = childAfter(child)) {
      out.add(child);
    }
    return out;
  }

  /// 幅[width]で、どのボタンも名前の幅のまま1行に並ぶか。
  bool _fitsInRow(double width) {
    final children = _children;
    if (children.isEmpty || !width.isFinite) return true;
    var total = gap * (children.length - 1);
    for (final child in children) {
      total += child.getMaxIntrinsicWidth(double.infinity);
    }
    return total <= width + 0.01;
  }

  Size _arrange(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) measure, {
    void Function(RenderBox child, Offset offset)? place,
  }) {
    final children = _children;
    if (children.isEmpty) return constraints.smallest;
    final width = constraints.maxWidth;
    if (!_fitsInRow(width)) {
      // 1つずつの行に分け、どれも行の幅いっぱい。
      var y = 0.0;
      for (final child in children) {
        if (y > 0) y += gap;
        final size = measure(child, BoxConstraints.tightFor(width: width));
        place?.call(child, Offset(0, y));
        y += size.height;
      }
      return constraints.constrain(Size(width, y));
    }
    // 2つ目からは名前の幅のまま、最初のボタンは残りの幅いっぱい。
    final sizes = List<Size>.filled(children.length, Size.zero);
    var rest = width.isFinite ? width - gap * (children.length - 1) : 0.0;
    for (var i = 1; i < children.length; i++) {
      sizes[i] = measure(
        children[i],
        BoxConstraints(maxWidth: width.isFinite ? width : double.infinity),
      );
      rest -= sizes[i].width;
    }
    sizes[0] = width.isFinite
        ? measure(
            children[0],
            BoxConstraints.tightFor(width: math.max(0.0, rest)),
          )
        : measure(children[0], const BoxConstraints());
    final height = sizes.map((s) => s.height).reduce(math.max);
    final total =
        sizes.map((s) => s.width).reduce((a, b) => a + b) +
        gap * (children.length - 1);
    final full = width.isFinite ? width : total;
    final ltr = textDirection == TextDirection.ltr;
    var x = 0.0;
    for (var i = 0; i < children.length; i++) {
      final left = ltr ? x : full - x - sizes[i].width;
      place?.call(children[i], Offset(left, (height - sizes[i].height) / 2));
      x += sizes[i].width + gap;
    }
    return constraints.constrain(Size(full, height));
  }

  @override
  void performLayout() {
    size = _arrange(
      constraints,
      (child, c) => (child..layout(c, parentUsesSize: true)).size,
      place: (child, offset) =>
          (child.parentData! as _ButtonRowOrStackParentData).offset = offset,
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _arrange(constraints, (child, c) => child.getDryLayout(c));

  @override
  double computeMinIntrinsicWidth(double height) => _children.fold(
    0.0,
    (w, child) => math.max(w, child.getMinIntrinsicWidth(double.infinity)),
  );

  @override
  double computeMaxIntrinsicWidth(double height) {
    final children = _children;
    if (children.isEmpty) return 0;
    return children.fold(
          0.0,
          (w, child) => w + child.getMaxIntrinsicWidth(double.infinity),
        ) +
        gap * (children.length - 1);
  }

  double _intrinsicHeight(
    double width,
    double Function(RenderBox child, double width) height,
  ) {
    final children = _children;
    if (children.isEmpty) return 0;
    if (_fitsInRow(width)) {
      return children.fold(
        0.0,
        (h, child) => math.max(h, height(child, width)),
      );
    }
    return children.fold(0.0, (h, child) => h + height(child, width)) +
        gap * (children.length - 1);
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (child, w) => child.getMinIntrinsicHeight(w));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (child, w) => child.getMaxIntrinsicHeight(w));

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
