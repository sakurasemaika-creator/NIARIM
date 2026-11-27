// ボタン・チップの上下（や左右）が、切る欄に一部だけ切られていないかを調べる。
//
// 実際に使ってみたとき（2026-11-27）、タイムラインの素材の編集の「配置・長さ
// 調整・トリミング…」のチップの上下が切れていた。チップの縁取り線は箱の外側に
// 描く（chipTheme.side）ので、箱が絵と同じ高さになる所（押せる所を縮めた
// チップ）では、横スクロールの欄が線を切った。所有者の依頼「こういうことは
// どの画面でも起きないようにしてください」。
//
// 調べるもの：今の画面（一番上のルート）にある、チップ（RawChip）とボタン
// （ButtonStyleButton〔Text/Outlined/Filled/Elevated/IconButton〕・
// FloatingActionButton・SegmentedButton）の見える形（中の`Material`の面と、
// 外側に描く縁取り線）。
//
// 切る欄：スクロールの欄（Scrollable）はスクロールしない向き（横スクロールなら
// 上下）、ClipRect・ClipRRect・ClipOval・ClipPathは両方の向き。形が欄と重なって
// いて、欄からはみ出している所があれば「切れている」。欄の外にすっかり出ている
// （スクロールで隠れた）ものと、スクロールする向きに一部だけ見えているものは
// 数えない。
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The controls on the current screen that a clipping box cuts part of, as
/// "what — where — cut by what" lines (empty when nothing is cut).
List<String> cutControls(WidgetTester tester, {double tolerance = 0.5}) {
  final problems = <String>[];
  final controls = find.byWidgetPredicate(
    (widget) =>
        widget is RawChip ||
        widget is ButtonStyleButton ||
        widget is FloatingActionButton ||
        widget is SegmentedButton,
  );
  for (final element in controls.evaluate()) {
    final route = ModalRoute.of(element);
    if (route != null && !route.isCurrent) continue;
    final shape = _visibleShape(element);
    if (shape == null) continue;
    final ancestors = <Element>[];
    element.visitAncestorElements((ancestor) {
      ancestors.add(ancestor);
      return true;
    });
    // The directions the control can be scrolled in: along them, any box
    // further out may cut it too (the rest is a scroll away).
    final scrolled = <Axis>{};
    for (var i = 0; i < ancestors.length; i++) {
      final ancestor = ancestors[i];
      final widget = ancestor.widget;
      final clip = _globalRect(ancestor.renderObject);
      final Set<Axis> checked;
      if (widget is Scrollable) {
        final along = axisDirectionToAxis(widget.axisDirection);
        // Cut across the scrolling only.
        checked = {flipAxis(along)}.difference(scrolled);
        scrolled.add(along);
      } else if (widget is ClipRect ||
          widget is ClipRRect ||
          widget is ClipOval ||
          widget is ClipPath) {
        // A clip the scroll view puts around its own viewport (Android's
        // stretching overscroll) belongs to that scroll view.
        final owner = ancestors
            .skip(i + 1)
            .where((e) => e.widget is Scrollable)
            .firstOrNull;
        final ownerRect = owner == null
            ? null
            : _globalRect(owner.renderObject);
        if (owner != null &&
            clip != null &&
            ownerRect != null &&
            _same(clip, ownerRect)) {
          final along = axisDirectionToAxis(
            (owner.widget as Scrollable).axisDirection,
          );
          checked = {flipAxis(along)}.difference(scrolled);
        } else {
          checked = {Axis.vertical, Axis.horizontal}.difference(scrolled);
        }
      } else {
        continue;
      }
      if (checked.isEmpty) continue;
      if (clip == null || !clip.overlaps(shape)) continue;
      bool cutAlong(Axis axis) => axis == Axis.vertical
          ? shape.top < clip.top - tolerance ||
                shape.bottom > clip.bottom + tolerance
          : shape.left < clip.left - tolerance ||
                shape.right > clip.right + tolerance;
      if (checked.any(cutAlong)) {
        problems.add(
          '${_describe(element)} at ${_rect(shape)} cut by '
          '${widget.runtimeType}${widget.key == null ? '' : ' ${widget.key}'}'
          ' at ${_rect(clip)}',
        );
        break;
      }
    }
  }
  return problems;
}

/// The control's visible shape on the screen: its `Material` (the face a
/// button or chip paints, inside the bigger area that takes taps), grown by
/// the part of its outline drawn outside it.
Rect? _visibleShape(Element element) {
  Element? face;
  void find(Element e) {
    if (face != null) return;
    if (e.widget is Material) {
      face = e;
      return;
    }
    e.visitChildElements(find);
  }

  element.visitChildElements(find);
  final faceElement = face;
  if (faceElement == null) return null;
  final rect = _globalRect(faceElement.renderObject);
  if (rect == null || rect.isEmpty) return null;
  final material = faceElement.widget as Material;
  final shape = material.shape;
  final outside = shape is OutlinedBorder ? shape.side.strokeOutset : 0.0;
  return rect.inflate(math.max(0, outside));
}

Rect? _globalRect(RenderObject? object) {
  if (object is! RenderBox || !object.attached || !object.hasSize) {
    return null;
  }
  return MatrixUtils.transformRect(
    object.getTransformTo(null),
    Offset.zero & object.size,
  );
}

String _describe(Element element) {
  final texts = <String>[];
  void collect(Element e) {
    final widget = e.widget;
    if (widget is Text) {
      texts.add(widget.data ?? widget.textSpan?.toPlainText() ?? '');
    } else if (widget is Icon) {
      texts.add(
        widget.icon == null ? 'icon' : 'icon ${widget.icon!.codePoint}',
      );
    }
    e.visitChildElements(collect);
  }

  element.visitChildElements(collect);
  final key = element.widget.key;
  return '${element.widget.runtimeType}'
      '${key == null ? '' : ' $key'} "${texts.take(2).join(' ')}"';
}

bool _same(Rect a, Rect b) =>
    (a.left - b.left).abs() < 1 &&
    (a.top - b.top).abs() < 1 &&
    (a.right - b.right).abs() < 1 &&
    (a.bottom - b.bottom).abs() < 1;

String _rect(Rect r) =>
    '(${r.left.toStringAsFixed(1)}, ${r.top.toStringAsFixed(1)}, '
    '${r.right.toStringAsFixed(1)}, ${r.bottom.toStringAsFixed(1)})';
