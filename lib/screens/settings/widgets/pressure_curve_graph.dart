import 'package:flutter/material.dart';

import '../../../config/accent_text_theme.dart';

/// 筆圧カーブのグラフエディタ。X軸＝実際の筆圧
/// （0〜1）、Y軸＝反映される太さ・不透明度の倍率（0〜1）として、現在の
/// カーブ形状（制御点を結ぶ折れ線）を表示する。
/// 以前の「x=0.5固定の1点のみドラッグ可能」な指数
/// カーブ方式から、制御点を自由に打てる方式へ刷新した。
/// - 空いている場所をタップ：新しい制御点を追加
/// - 制御点をドラッグ：移動（先頭・末尾はy方向のみ、中間点はx・y両方
///   だが前後の制御点を追い越さない範囲）
/// - 制御点をダブルタップ：削除（先頭・末尾は削除不可）
class PressureCurveGraph extends StatefulWidget {
  final List<(double, double)> points;
  final void Function(double x, double y) onAddPoint;
  final void Function(int index, double x, double y) onMovePoint;
  final void Function(int index) onRemovePoint;
  final double size;
  final bool editable;

  const PressureCurveGraph({
    super.key,
    required this.points,
    required this.onAddPoint,
    required this.onMovePoint,
    required this.onRemovePoint,
    this.size = 240,
    this.editable = true,
  });

  /// 見るだけのグラフ（弱・普通・強の形を見せる）。偽なら点を足す・動かす・
  /// 消す操作を受けず、点の丸も描かない。
  const PressureCurveGraph.preview({
    super.key,
    required this.points,
    this.size = 240,
  }) : onAddPoint = _ignoreAdd,
       onMovePoint = _ignoreMove,
       onRemovePoint = _ignoreRemove,
       editable = false;

  static void _ignoreAdd(double x, double y) {}
  static void _ignoreMove(int index, double x, double y) {}
  static void _ignoreRemove(int index) {}

  @override
  State<PressureCurveGraph> createState() => _PressureCurveGraphState();
}

class _PressureCurveGraphState extends State<PressureCurveGraph> {
  int? _dragIndex;

  (double, double) _toCurveSpace(Offset localPos) {
    final x = (localPos.dx / widget.size).clamp(0.0, 1.0);
    final y = (1.0 - localPos.dy / widget.size).clamp(0.0, 1.0);
    return (x, y);
  }

  int? _hitTestPoint(Offset localPos, {double radius = 18}) {
    int? nearest;
    var distance = radius;
    for (var i = 0; i < widget.points.length; i++) {
      final p = widget.points[i];
      final screenPos = Offset(p.$1 * widget.size, (1 - p.$2) * widget.size);
      final candidate = (screenPos - localPos).distance;
      if (candidate < distance) {
        nearest = i;
        distance = candidate;
      }
    }
    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final graph = Container(
      width: widget.size,
      height: widget.size,
      // グラフは置かれた面の上にじかに描き、枠と目盛りの線だけを引く
      // （面の上にもう1色の灰色の箱を重ねない）。
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: CustomPaint(
        painter: _PressureCurvePainter(
          points: widget.points,
          color: AccentTextTheme.of(context),
          handleOutlineColor:
              Theme.of(context).cardTheme.color ?? scheme.surface,
          gridColor: scheme.outlineVariant,
          showHandles: widget.editable,
        ),
      ),
    );
    if (!widget.editable) return graph;
    return GestureDetector(
      onTapUp: (d) {
        final hit = _hitTestPoint(d.localPosition, radius: 8);
        if (hit != null) return;
        final (x, y) = _toCurveSpace(d.localPosition);
        widget.onAddPoint(x, y);
      },
      onDoubleTapDown: (d) {
        final hit = _hitTestPoint(d.localPosition);
        if (hit != null) widget.onRemovePoint(hit);
      },
      onPanStart: (d) => _dragIndex = _hitTestPoint(d.localPosition),
      onPanUpdate: (d) {
        final idx = _dragIndex;
        if (idx == null) return;
        final (x, y) = _toCurveSpace(d.localPosition);
        widget.onMovePoint(idx, x, y);
      },
      onPanEnd: (_) => _dragIndex = null,
      child: graph,
    );
  }
}

class _PressureCurvePainter extends CustomPainter {
  final List<(double, double)> points;
  final Color color;
  final Color handleOutlineColor;
  final Color gridColor;
  final bool showHandles;
  _PressureCurvePainter({
    required this.points,
    required this.color,
    required this.handleOutlineColor,
    required this.gridColor,
    required this.showHandles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final t = i / 4;
      canvas.drawLine(
        Offset(size.width * t, 0),
        Offset(size.width * t, size.height),
        gridPaint,
      );
      canvas.drawLine(
        Offset(0, size.height * t),
        Offset(size.width, size.height * t),
        gridPaint,
      );
    }
    // 傾き1の参考対角線（筆圧をそのまま反映する基準線）
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      Paint()
        ..color = gridColor
        ..strokeWidth = 1,
    );

    final sorted = [...points]..sort((a, b) => a.$1.compareTo(b.$1));
    final path = Path();
    for (int i = 0; i < sorted.length; i++) {
      final p = Offset(
        sorted[i].$1 * size.width,
        (1 - sorted[i].$2) * size.height,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (!showHandles) return;
    for (final p in sorted) {
      final handle = Offset(p.$1 * size.width, (1 - p.$2) * size.height);
      canvas.drawCircle(handle, 8, Paint()..color = color);
      canvas.drawCircle(
        handle,
        8,
        Paint()
          ..color = handleOutlineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_PressureCurvePainter old) =>
      old.points != points ||
      old.color != color ||
      old.handleOutlineColor != handleOutlineColor ||
      old.gridColor != gridColor ||
      old.showHandles != showHandles;
}
