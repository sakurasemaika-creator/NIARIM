import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 2つの部品を、1行に収まれば左端と右端へ、収まらなければ2行（1つ目は
/// 左寄せ、2つ目は右寄せ）に並べる。
///
/// [OverflowBar]は2行にするとき全部の部品を同じ側へ寄せる。1つ目だけ左へ
/// 残そうと幅いっぱいに広げると、どの幅でも「収まらない」と判断されて
/// 常に2行になった。
class LeadingTrailingBar extends MultiChildRenderObjectWidget {
  LeadingTrailingBar({super.key, required Widget leading, Widget? trailing})
    : super(children: [leading, ?trailing]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLeadingTrailingBar(Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderLeadingTrailingBar).textDirection =
        Directionality.of(context);
  }
}

class _BarParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderLeadingTrailingBar extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BarParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BarParentData> {
  _RenderLeadingTrailingBar(this._textDirection);

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BarParentData) {
      child.parentData = _BarParentData();
    }
  }

  // 並べたときの大きさと、1行に収まるか。
  ({Size size, bool oneLine}) _measure(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) sizeOf,
  ) {
    final childConstraints = constraints.loosen();
    final leading = firstChild;
    if (leading == null) return (size: constraints.smallest, oneLine: true);
    final a = sizeOf(leading, childConstraints);
    final trailing = childAfter(leading);
    final b = trailing == null ? Size.zero : sizeOf(trailing, childConstraints);
    final oneLine = a.width + b.width <= constraints.maxWidth;
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : a.width + b.width;
    final height = oneLine ? math.max(a.height, b.height) : a.height + b.height;
    return (size: constraints.constrain(Size(width, height)), oneLine: oneLine);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _measure(constraints, (child, c) => child.getDryLayout(c)).size;

  @override
  void performLayout() {
    final measured = _measure(constraints, (child, c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    });
    size = measured.size;
    final leading = firstChild;
    if (leading == null) return;
    final trailing = childAfter(leading);
    final rtl = _textDirection == TextDirection.rtl;
    double startX(RenderBox child) => rtl ? size.width - child.size.width : 0;
    double endX(RenderBox child) => rtl ? 0 : size.width - child.size.width;
    final leadingData = leading.parentData! as _BarParentData;
    if (measured.oneLine) {
      leadingData.offset = Offset(
        startX(leading),
        (size.height - leading.size.height) / 2,
      );
      if (trailing != null) {
        (trailing.parentData! as _BarParentData).offset = Offset(
          endX(trailing),
          (size.height - trailing.size.height) / 2,
        );
      }
    } else {
      leadingData.offset = Offset(startX(leading), 0);
      if (trailing != null) {
        (trailing.parentData! as _BarParentData).offset = Offset(
          endX(trailing),
          leading.size.height,
        );
      }
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    var width = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      width = math.max(width, child.getMinIntrinsicWidth(double.infinity));
    }
    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    var width = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      width += child.getMaxIntrinsicWidth(double.infinity);
    }
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _measure(
    BoxConstraints(maxWidth: width),
    (child, c) => child.getDryLayout(c),
  ).size.height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
