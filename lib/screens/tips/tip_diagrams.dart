import 'package:flutter/material.dart';

/// Tipsページの図解。実際の画面のスクリーンショット（ラスタ画像）を
/// 埋め込むと、多言語×複数ページ分の画像アセットでアプリの容量が
/// 増え、低スペック端末では画像デコードの負荷もかさむ。ここでは
/// 各Tipの要点だけを表す簡易的な模式図をCanvas描画で表現することで、
/// 画像アセットを一切使わずに済ませている（ベクター描画はテーマの
/// 色にも自動追従する）。
enum TipDiagramKind {
  clipDuplicate,
  textCaption,
  autofillPreset,
  brushFavorite,
  onionSkin,
  pressureCurve,
  effectFilter,
  cameraKeyframe,
  exportFormat,
  gestureShortcut,
  timelineMarker,
}

class TipDiagram extends StatelessWidget {
  final TipDiagramKind kind;
  const TipDiagram(this.kind, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: const Size(double.infinity, 96),
      painter: _TipDiagramPainter(kind, scheme),
    );
  }
}

class _TipDiagramPainter extends CustomPainter {
  final TipDiagramKind kind;
  final ColorScheme scheme;
  _TipDiagramPainter(this.kind, this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case TipDiagramKind.clipDuplicate: _paintClipDuplicate(canvas, size);
      case TipDiagramKind.textCaption: _paintTextCaption(canvas, size);
      case TipDiagramKind.autofillPreset: _paintAutofillPreset(canvas, size);
      case TipDiagramKind.brushFavorite: _paintBrushFavorite(canvas, size);
      case TipDiagramKind.onionSkin: _paintOnionSkin(canvas, size);
      case TipDiagramKind.pressureCurve: _paintPressureCurve(canvas, size);
      case TipDiagramKind.effectFilter: _paintEffectFilter(canvas, size);
      case TipDiagramKind.cameraKeyframe: _paintCameraKeyframe(canvas, size);
      case TipDiagramKind.exportFormat: _paintExportFormat(canvas, size);
      case TipDiagramKind.gestureShortcut: _paintGestureShortcut(canvas, size);
      case TipDiagramKind.timelineMarker: _paintTimelineMarker(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant _TipDiagramPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.scheme != scheme;

  // ── 共通パーツ ──────────────────────────────────────────────
  Paint get _fillPrimary => Paint()..color = scheme.primary;
  Paint get _fillPrimaryFaint => Paint()..color = scheme.primary.withValues(alpha: 0.35);
  Paint get _strokeOutline => Paint()
    ..color = scheme.outlineVariant
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  Paint get _strokePrimary => Paint()
    ..color = scheme.primary
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8;

  void _arrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    canvas.drawLine(from, to, paint);
    final angle = (to - from).direction;
    const headLen = 6.0;
    for (final da in [2.6, -2.6]) {
      final p = to - Offset.fromDirection(angle + da * 0.3, headLen);
      canvas.drawLine(to, p, paint);
    }
  }

  void _star(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outer = Offset.fromDirection(-1.5708 + i * 2 * 3.14159 / 5, r);
      final inner = Offset.fromDirection(-1.5708 + (i + 0.5) * 2 * 3.14159 / 5, r * 0.45);
      if (i == 0) {
        path.moveTo(center.dx + outer.dx, center.dy + outer.dy);
      } else {
        path.lineTo(center.dx + outer.dx, center.dy + outer.dy);
      }
      path.lineTo(center.dx + inner.dx, center.dy + inner.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // ── 各Tipの模式図 ────────────────────────────────────────────

  /// タイムラインの帯＋クリップ1つ→矢印→複製されたクリップ。
  void _paintClipDuplicate(Canvas canvas, Size size) {
    final y = size.height * 0.55;
    canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), _strokeOutline);
    final clip1 = Rect.fromCenter(center: Offset(size.width * 0.22, y), width: 44, height: 26);
    canvas.drawRRect(RRect.fromRectAndRadius(clip1, const Radius.circular(4)), _fillPrimary);
    _arrow(canvas, Offset(clip1.right + 6, y), Offset(size.width * 0.62, y), _strokeOutline);
    final clip2 = Rect.fromCenter(center: Offset(size.width * 0.78, y), width: 44, height: 26);
    canvas.drawRRect(RRect.fromRectAndRadius(clip2, const Radius.circular(4)), _fillPrimaryFaint);
    canvas.drawRRect(RRect.fromRectAndRadius(clip2, const Radius.circular(4)), _strokePrimary);
  }

  /// 画面枠の下部に字幕の吹き出し（横線2本＝テキスト）。
  void _paintTextCaption(Canvas canvas, Size size) {
    final screen = Rect.fromLTWH(size.width * 0.5 - 46, 6, 92, size.height - 12);
    canvas.drawRRect(RRect.fromRectAndRadius(screen, const Radius.circular(8)), _strokeOutline);
    final bubble = Rect.fromLTWH(screen.left + 8, screen.bottom - 34, screen.width - 16, 24);
    canvas.drawRRect(RRect.fromRectAndRadius(bubble, const Radius.circular(5)), _fillPrimary);
    final linePaint = Paint()..color = scheme.surface..strokeWidth = 2;
    canvas.drawLine(Offset(bubble.left + 8, bubble.center.dy - 4), Offset(bubble.right - 14, bubble.center.dy - 4), linePaint);
    canvas.drawLine(Offset(bubble.left + 8, bubble.center.dy + 5), Offset(bubble.right - 26, bubble.center.dy + 5), linePaint);
  }

  /// 3色の配色スウォッチ（肌・髪・服の陰影セット）を積む。
  void _paintAutofillPreset(Canvas canvas, Size size) {
    final colors = [scheme.primary, scheme.secondary, scheme.tertiary];
    final w = (size.width - 40) / 3;
    for (int i = 0; i < 3; i++) {
      final x = 16 + i * (w + 12);
      final base = Rect.fromLTWH(x, size.height * 0.2, w, size.height * 0.32);
      final shade = Rect.fromLTWH(x, base.bottom, w, size.height * 0.2);
      canvas.drawRRect(RRect.fromRectAndRadius(base, const Radius.circular(3)), Paint()..color = colors[i]);
      canvas.drawRRect(RRect.fromRectAndRadius(shade, const Radius.circular(3)),
          Paint()..color = colors[i].withValues(alpha: 0.55));
    }
  }

  /// ブラシ（斜めの線＋筆先）と、右上に星マーク。
  void _paintBrushFavorite(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.42, size.height * 0.52);
    final brush = Paint()
      ..color = scheme.primary
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c + const Offset(-26, 18), c + const Offset(20, -22), brush);
    final tip = Paint()..color = scheme.tertiary;
    canvas.drawCircle(c + const Offset(-26, 18), 6, tip);
    _star(canvas, Offset(size.width * 0.78, size.height * 0.3), 12, Paint()..color = scheme.tertiary);
  }

  /// 半透明で重なる3枚の丸（前後フレームを透かして見る）。
  void _paintOnionSkin(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final r = size.height * 0.32;
    canvas.drawCircle(Offset(size.width * 0.38, cy), r, Paint()..color = scheme.primary.withValues(alpha: 0.25));
    canvas.drawCircle(Offset(size.width * 0.5, cy), r, Paint()..color = scheme.primary.withValues(alpha: 0.5));
    canvas.drawCircle(Offset(size.width * 0.62, cy), r, _fillPrimary);
  }

  /// 軸＋曲線＋制御点2つ（筆圧カーブ）。
  void _paintPressureCurve(Canvas canvas, Size size) {
    final origin = Offset(size.width * 0.24, size.height * 0.82);
    final top = Offset(size.width * 0.24, size.height * 0.14);
    final right = Offset(size.width * 0.82, size.height * 0.82);
    canvas.drawLine(origin, top, _strokeOutline);
    canvas.drawLine(origin, right, _strokeOutline);
    final curve = Path()
      ..moveTo(origin.dx, origin.dy)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.78, right.dx, top.dy);
    canvas.drawPath(curve, _strokePrimary);
    canvas.drawCircle(origin, 4, _fillPrimary);
    canvas.drawCircle(Offset(size.width * 0.52, size.height * 0.48), 4, _fillPrimary);
    canvas.drawCircle(Offset(right.dx, top.dy), 4, _fillPrimary);
  }

  /// 画面枠に斜めのグラデーション帯＋きらめき（演出フィルター）。
  void _paintEffectFilter(Canvas canvas, Size size) {
    final screen = Rect.fromLTWH(size.width * 0.5 - 46, 6, 92, size.height - 12);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(screen, const Radius.circular(8)));
    final shader = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [scheme.primary.withValues(alpha: 0.7), scheme.tertiary.withValues(alpha: 0.7)],
      ).createShader(screen);
    canvas.drawRect(screen, shader);
    canvas.restore();
    canvas.drawRRect(RRect.fromRectAndRadius(screen, const Radius.circular(8)), _strokeOutline);
    _star(canvas, Offset(screen.right + 14, screen.top + 18), 8, Paint()..color = scheme.tertiary);
  }

  /// 小さい矩形→大きい矩形への矢印（ズーム）＋横矢印（パン）。
  void _paintCameraKeyframe(Canvas canvas, Size size) {
    final small = Rect.fromCenter(center: Offset(size.width * 0.24, size.height * 0.5), width: 26, height: 20);
    final large = Rect.fromCenter(center: Offset(size.width * 0.76, size.height * 0.5), width: 46, height: 36);
    canvas.drawRRect(RRect.fromRectAndRadius(small, const Radius.circular(3)), _strokeOutline);
    canvas.drawRRect(RRect.fromRectAndRadius(large, const Radius.circular(4)), _strokePrimary);
    _arrow(canvas, Offset(small.right + 6, size.height * 0.5), Offset(large.left - 6, size.height * 0.5), _strokeOutline);
  }

  /// 3つの書き出し形式チップ（透過＝市松模様・動画＝塗り＋再生アイコン・GIF＝丸枠）。
  void _paintExportFormat(Canvas canvas, Size size) {
    final w = (size.width - 40) / 3;
    for (int i = 0; i < 3; i++) {
      final rect = Rect.fromLTWH(16 + i * (w + 12), size.height * 0.22, w, size.height * 0.56);
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(5));
      canvas.drawRRect(rr, _strokeOutline);
      switch (i) {
        case 0: // 透過WebM：市松模様
          canvas.save();
          canvas.clipRRect(rr);
          final cell = rect.width / 4;
          final checker = Paint()..color = scheme.outlineVariant.withValues(alpha: 0.5);
          for (int gy = 0; gy < 4; gy++) {
            for (int gx = 0; gx < 4; gx++) {
              if ((gx + gy).isEven) continue;
              canvas.drawRect(Rect.fromLTWH(rect.left + gx * cell, rect.top + gy * cell, cell, cell), checker);
            }
          }
          canvas.restore();
        case 1: // MP4：再生アイコン
          canvas.drawRRect(rr, _fillPrimaryFaint);
          final c = rect.center;
          final play = Path()
            ..moveTo(c.dx - 6, c.dy - 8)
            ..lineTo(c.dx - 6, c.dy + 8)
            ..lineTo(c.dx + 8, c.dy)
            ..close();
          canvas.drawPath(play, _fillPrimary);
        default: // GIF：丸いループ矢印
          canvas.drawRRect(rr, _fillPrimaryFaint);
          canvas.drawArc(Rect.fromCenter(center: rect.center, width: 20, height: 20), 0.3, 5, false, _strokePrimary);
      }
    }
  }

  /// 画面の上に重なる2本指タップと、Undoの巻き戻し矢印。
  void _paintGestureShortcut(Canvas canvas, Size size) {
    final screen = Rect.fromLTWH(size.width * 0.5 - 42, size.height * 0.3, 84, size.height * 0.6);
    canvas.drawRRect(RRect.fromRectAndRadius(screen, const Radius.circular(8)), _strokeOutline);
    canvas.drawArc(Rect.fromCenter(center: screen.center, width: 30, height: 30), 3.7, 4.2, false, _strokePrimary);
    canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.16), 9, _fillPrimaryFaint);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.16), 9, _fillPrimaryFaint);
    canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.16), 9, _strokePrimary);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.16), 9, _strokePrimary);
  }

  /// タイムラインの帯＋ピン（タイムスタンプ）＋コメントの吹き出し。
  void _paintTimelineMarker(Canvas canvas, Size size) {
    final y = size.height * 0.62;
    canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), _strokeOutline);
    for (final t in [0.28, 0.56, 0.82]) {
      final x = size.width * t;
      final isMain = t == 0.56;
      canvas.drawCircle(Offset(x, y), isMain ? 6 : 4, isMain ? _fillPrimary : _fillPrimaryFaint);
      if (isMain) {
        final bubble = Rect.fromLTWH(x - 20, size.height * 0.08, 40, size.height * 0.34);
        final rr = RRect.fromRectAndRadius(bubble, const Radius.circular(4));
        canvas.drawRRect(rr, _fillPrimaryFaint);
        canvas.drawRRect(rr, _strokePrimary);
        final tail = Path()
          ..moveTo(x - 4, bubble.bottom)
          ..lineTo(x, bubble.bottom + 6)
          ..lineTo(x + 4, bubble.bottom)
          ..close();
        canvas.drawPath(tail, _fillPrimaryFaint);
      }
    }
  }
}
