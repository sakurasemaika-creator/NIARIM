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
  pcDexLayout,
  lineArtExtraction,
  selectionTool,
  layerFolder,
  saveSlot,
  transparentColor,
  performanceGauge,
  deviceTransfer,
  toolbarCustomize,
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
      case TipDiagramKind.pcDexLayout: _paintPcDexLayout(canvas, size);
      case TipDiagramKind.lineArtExtraction: _paintLineArtExtraction(canvas, size);
      case TipDiagramKind.selectionTool: _paintSelectionTool(canvas, size);
      case TipDiagramKind.layerFolder: _paintLayerFolder(canvas, size);
      case TipDiagramKind.saveSlot: _paintSaveSlot(canvas, size);
      case TipDiagramKind.transparentColor: _paintTransparentColor(canvas, size);
      case TipDiagramKind.performanceGauge: _paintPerformanceGauge(canvas, size);
      case TipDiagramKind.deviceTransfer: _paintDeviceTransfer(canvas, size);
      case TipDiagramKind.toolbarCustomize: _paintToolbarCustomize(canvas, size);
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

  /// [icon]の実際のグリフ（Material Icons）をCanvasへ直接描画する
  /// （help_diagrams.dartの_drawIconと同じ手法。実アイコンを使うことで
  /// 抽象的な図形だけよりも実画面に近い印象にする）。
  void _drawIcon(Canvas canvas, IconData icon, Offset center, {double size = 16, Color? color}) {
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontSize: size, fontFamily: icon.fontFamily, package: icon.fontPackage, color: color),
      )
      ..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

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

  /// 3色の配色スウォッチ（肌・髪・服の陰影セット）を積み、実際のパレット
  /// アイコンを添える。
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
    _drawIcon(canvas, Icons.palette_outlined, Offset(size.width / 2, size.height * 0.09), size: 14,
        color: scheme.onSurfaceVariant);
  }

  /// 実際のブラシアイコンと、右上に星マーク（お気に入り）。
  void _paintBrushFavorite(Canvas canvas, Size size) {
    _drawIcon(canvas, Icons.brush, Offset(size.width * 0.42, size.height * 0.52), size: 28, color: scheme.primary);
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
    _drawIcon(canvas, Icons.auto_awesome, screen.center, size: 16, color: scheme.surface);
    _star(canvas, Offset(screen.right + 14, screen.top + 18), 8, Paint()..color = scheme.tertiary);
  }

  /// 小さい矩形→大きい矩形への矢印（ズーム）＋横矢印（パン）。
  void _paintCameraKeyframe(Canvas canvas, Size size) {
    final small = Rect.fromCenter(center: Offset(size.width * 0.24, size.height * 0.5), width: 26, height: 20);
    final large = Rect.fromCenter(center: Offset(size.width * 0.76, size.height * 0.5), width: 46, height: 36);
    canvas.drawRRect(RRect.fromRectAndRadius(small, const Radius.circular(3)), _strokeOutline);
    canvas.drawRRect(RRect.fromRectAndRadius(large, const Radius.circular(4)), _strokePrimary);
    _arrow(canvas, Offset(small.right + 6, size.height * 0.5), Offset(large.left - 6, size.height * 0.5), _strokeOutline);
    _drawIcon(canvas, Icons.videocam_outlined, large.center, size: 16, color: scheme.primary);
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
        case 1: // MP4：実際の再生アイコン
          canvas.drawRRect(rr, _fillPrimaryFaint);
          _drawIcon(canvas, Icons.play_circle_outline, rect.center, size: 20, color: scheme.primary);
        default: // GIF：実際のGIFアイコン
          canvas.drawRRect(rr, _fillPrimaryFaint);
          _drawIcon(canvas, Icons.gif_box_outlined, rect.center, size: 20, color: scheme.primary);
      }
    }
  }

  /// 画面の上に重なる2本指タップ（実際のタップアイコン）と、Undoの巻き戻し矢印。
  void _paintGestureShortcut(Canvas canvas, Size size) {
    final screen = Rect.fromLTWH(size.width * 0.5 - 42, size.height * 0.3, 84, size.height * 0.6);
    canvas.drawRRect(RRect.fromRectAndRadius(screen, const Radius.circular(8)), _strokeOutline);
    canvas.drawArc(Rect.fromCenter(center: screen.center, width: 30, height: 30), 3.7, 4.2, false, _strokePrimary);
    _drawIcon(canvas, Icons.undo, screen.center, size: 14, color: scheme.primary);
    canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.16), 9, _fillPrimaryFaint);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.16), 9, _fillPrimaryFaint);
    canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.16), 9, _strokePrimary);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.16), 9, _strokePrimary);
    _drawIcon(canvas, Icons.touch_app, Offset(size.width * 0.5, size.height * 0.16), size: 12,
        color: scheme.primary);
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

  /// 左：スマホ（下部にツールバー）→矢印→右：PC/DeX（左右にドッキング
  /// パネル）。ワイド画面で自動的にレイアウトが切り替わることを表す。
  void _paintPcDexLayout(Canvas canvas, Size size) {
    final phone = Rect.fromLTWH(size.width * 0.06, size.height * 0.1, size.width * 0.2, size.height * 0.8);
    canvas.drawRRect(RRect.fromRectAndRadius(phone, const Radius.circular(6)), _strokeOutline);
    _drawIcon(canvas, Icons.smartphone, Offset(phone.center.dx, phone.top + phone.height * 0.35), size: 14,
        color: scheme.onSurfaceVariant);
    final phoneToolbar = Rect.fromLTWH(phone.left + 3, phone.bottom - 14, phone.width - 6, 10);
    canvas.drawRRect(RRect.fromRectAndRadius(phoneToolbar, const Radius.circular(2)), _fillPrimaryFaint);

    _arrow(canvas, Offset(phone.right + 8, size.height * 0.5), Offset(size.width * 0.52, size.height * 0.5),
        _strokeOutline);

    final pc = Rect.fromLTWH(size.width * 0.58, size.height * 0.16, size.width * 0.38, size.height * 0.68);
    canvas.drawRRect(RRect.fromRectAndRadius(pc, const Radius.circular(6)), _strokePrimary);
    final leftPanel = Rect.fromLTWH(pc.left + 3, pc.top + 3, pc.width * 0.2, pc.height - 6);
    final rightPanel = Rect.fromLTWH(pc.right - pc.width * 0.2 - 3, pc.top + 3, pc.width * 0.2, pc.height - 6);
    canvas.drawRRect(RRect.fromRectAndRadius(leftPanel, const Radius.circular(2)), _fillPrimaryFaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rightPanel, const Radius.circular(2)), _fillPrimaryFaint);
  }

  /// 左：色つきのイラスト（グラデーション＋線）→矢印→右：市松模様（透過）の
  /// 上に線だけが残った線画。色調補正・二値化・明度で透過を組み合わせて
  /// 線画を抽出するTipsの図解。
  void _paintLineArtExtraction(Canvas canvas, Size size) {
    final left = Rect.fromLTWH(4, size.height * 0.1, size.width * 0.36, size.height * 0.8);
    final right = Rect.fromLTWH(size.width * 0.6, size.height * 0.1, size.width * 0.36, size.height * 0.8);

    // 左：色つきの元イラスト（グラデーション背景＋輪郭線）
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(left, const Radius.circular(6)));
    final gradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [scheme.primary.withValues(alpha: 0.6), scheme.tertiary.withValues(alpha: 0.6)],
      ).createShader(left);
    canvas.drawRect(left, gradient);
    canvas.restore();
    canvas.drawRRect(RRect.fromRectAndRadius(left, const Radius.circular(6)), _strokeOutline);
    final face = Path()
      ..addOval(Rect.fromCenter(center: left.center, width: left.width * 0.55, height: left.height * 0.5));
    canvas.drawPath(face, Paint()
      ..color = scheme.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2);

    _arrow(canvas, Offset(left.right + 6, size.height * 0.5), Offset(right.left - 6, size.height * 0.5),
        _strokeOutline);

    // 右：市松模様（透過）の上に線だけが残った抽出結果
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(right, const Radius.circular(6)));
    final cell = right.width / 5;
    final checker = Paint()..color = scheme.outlineVariant.withValues(alpha: 0.45);
    for (int gy = 0; gy * cell < right.height; gy++) {
      for (int gx = 0; gx < 5; gx++) {
        if ((gx + gy).isEven) continue;
        canvas.drawRect(Rect.fromLTWH(right.left + gx * cell, right.top + gy * cell, cell, cell), checker);
      }
    }
    final extractedFace = Path()
      ..addOval(Rect.fromCenter(center: right.center, width: right.width * 0.55, height: right.height * 0.5));
    canvas.drawPath(extractedFace, Paint()
      ..color = scheme.onSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2);
    canvas.restore();
    canvas.drawRRect(RRect.fromRectAndRadius(right, const Radius.circular(6)), _strokeOutline);
  }

  /// 破線の投げ縄パスと、その脇にマジックワンド（きらめき）アイコン。
  void _paintSelectionTool(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.16, size.height * 0.72)
      ..quadraticBezierTo(size.width * 0.1, size.height * 0.32, size.width * 0.34, size.height * 0.22)
      ..quadraticBezierTo(size.width * 0.58, size.height * 0.1, size.width * 0.6, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.62, size.height * 0.68, size.width * 0.34, size.height * 0.7)
      ..close();
    final dashed = Path();
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double dist = 0;
      const dashLen = 4.0, gapLen = 3.0;
      while (dist < m.length) {
        final next = (dist + dashLen).clamp(0, m.length);
        dashed.addPath(m.extractPath(dist, next.toDouble()), Offset.zero);
        dist += dashLen + gapLen;
      }
    }
    canvas.drawPath(dashed, _strokePrimary);
    canvas.drawPath(path, Paint()..color = scheme.primary.withValues(alpha: 0.15));
    _drawIcon(canvas, Icons.auto_awesome, Offset(size.width * 0.8, size.height * 0.28), size: 20,
        color: scheme.tertiary);
    _drawIcon(canvas, Icons.gesture, Offset(size.width * 0.8, size.height * 0.68), size: 20, color: scheme.primary);
  }

  /// フォルダアイコンの中に、複数プロジェクトへ共有される共通レイヤー
  /// （重なった四角）を示す。
  void _paintLayerFolder(Canvas canvas, Size size) {
    _drawIcon(canvas, Icons.folder, Offset(size.width * 0.28, size.height * 0.5), size: 40, color: scheme.tertiary);
    final stack = [0, 1, 2];
    for (final i in stack) {
      final rect = Rect.fromCenter(
          center: Offset(size.width * 0.72 - i * 4, size.height * 0.5 - i * 4), width: 34, height: 24);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          i == 0 ? _fillPrimary : (Paint()..color = scheme.primary.withValues(alpha: 0.4 - i * 0.1)));
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), _strokeOutline);
    }
    _drawIcon(canvas, Icons.groups_outlined, Offset(size.width * 0.72, size.height * 0.5), size: 14,
        color: scheme.onPrimary);
  }

  /// 手動セーブ（ピン留めされた保存アイコン、複数残る）と自動保存
  /// （回転する更新アイコン、常に1つだけ）を並べる。
  void _paintSaveSlot(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      final cx = size.width * (0.12 + i * 0.16);
      final rect = Rect.fromCenter(center: Offset(cx, size.height * 0.5), width: 26, height: 34);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          i == 2 ? _fillPrimaryFaint : _strokeOutline);
      if (i == 2) canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), _strokePrimary);
      _drawIcon(canvas, Icons.bookmark, rect.center, size: 14,
          color: i == 2 ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.6));
    }
    final autoCenter = Offset(size.width * 0.78, size.height * 0.5);
    canvas.drawCircle(autoCenter, 22, Paint()..color = scheme.tertiary.withValues(alpha: 0.25));
    canvas.drawCircle(autoCenter, 22,
        Paint()..color = scheme.tertiary..style = PaintingStyle.stroke..strokeWidth = 1.8);
    _drawIcon(canvas, Icons.autorenew, autoCenter, size: 20, color: scheme.tertiary);
  }

  /// 色の塗られた面の一部が市松模様（透明）に削れた帯＋ブラシアイコン。
  /// 消しゴムではなく「ブラシで透明色を塗って消す」イメージを表す。
  void _paintTransparentColor(Canvas canvas, Size size) {
    final area = Rect.fromLTWH(size.width * 0.5 - 46, 8, 92, size.height - 16);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(area, const Radius.circular(8)));
    canvas.drawRect(area, _fillPrimaryFaint);
    // 帯状に市松模様（透明部分）を重ね、斜めのブラシストロークで
    // 「なぞって透明にした」帯を表現する。
    final band = Rect.fromLTWH(area.left, area.top + area.height * 0.36, area.width, area.height * 0.3);
    final cell = area.width / 6;
    final checker = Paint()..color = scheme.surface;
    for (int gy = 0; gy * cell < band.height; gy++) {
      for (int gx = 0; gx < 6; gx++) {
        if ((gx + gy).isOdd) continue;
        canvas.drawRect(Rect.fromLTWH(band.left + gx * cell, band.top + gy * cell, cell, cell), checker);
      }
    }
    canvas.restore();
    canvas.drawRRect(RRect.fromRectAndRadius(area, const Radius.circular(8)), _strokeOutline);
    _drawIcon(canvas, Icons.brush, band.center, size: 18, color: scheme.primary);
  }

  /// 速度計（ゲージ）の針を「低品質」寄りに振り、軽量化を示す。
  void _paintPerformanceGauge(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.78);
    final r = size.height * 0.62;
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawArc(rect, 3.14159, 3.14159, false,
        Paint()..color = scheme.outlineVariant..style = PaintingStyle.stroke..strokeWidth = 8);
    canvas.drawArc(rect, 3.14159, 3.14159 * 0.35, false,
        Paint()..color = scheme.tertiary..style = PaintingStyle.stroke..strokeWidth = 8);
    const needleAngle = 3.14159 * 1.18; // 低品質寄り
    final needleEnd = center + Offset.fromDirection(needleAngle, r * 0.85);
    canvas.drawLine(center, needleEnd, _strokePrimary);
    canvas.drawCircle(center, 4, _fillPrimary);
    _drawIcon(canvas, Icons.speed, Offset(center.dx, center.dy - r * 0.55), size: 16, color: scheme.onSurfaceVariant);
  }

  /// スマートフォン→引き継ぎファイルのアイコン→スマートフォンの順で、
  /// 端末間でプロジェクト・設定がまとめて移動することを示す。
  void _paintDeviceTransfer(Canvas canvas, Size size) {
    final left = Offset(size.width * 0.16, size.height * 0.5);
    final right = Offset(size.width * 0.84, size.height * 0.5);
    _drawIcon(canvas, Icons.smartphone, left, size: 26, color: scheme.onSurfaceVariant);
    _drawIcon(canvas, Icons.smartphone, right, size: 26, color: scheme.onSurfaceVariant);
    final fileCenter = Offset(size.width / 2, size.height * 0.42);
    _arrow(canvas, left + const Offset(14, 0), fileCenter - const Offset(14, 0), _strokeOutline);
    _arrow(canvas, fileCenter + const Offset(14, 0), right - const Offset(14, 0), _strokeOutline);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: fileCenter, width: 30, height: 34), const Radius.circular(4)),
        _fillPrimaryFaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: fileCenter, width: 30, height: 34), const Radius.circular(4)),
        _strokePrimary);
    _drawIcon(canvas, Icons.sync_alt, fileCenter, size: 16, color: scheme.primary);
  }

  /// ツールバーの並び（実アイコン）のうち1つを上へずらして「並び替え中」を
  /// 示し、もう1つを薄く消して「非表示」を示す。
  void _paintToolbarCustomize(Canvas canvas, Size size) {
    final y = size.height * 0.6;
    final barRect = Rect.fromLTWH(4, y - 18, size.width - 8, 36);
    canvas.drawRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(6)), _fillPrimaryFaint);
    const icons = [Icons.brush, Icons.auto_fix_high, Icons.colorize, Icons.highlight_alt, Icons.category];
    final w = barRect.width / icons.length;
    for (int i = 0; i < icons.length; i++) {
      final cx = barRect.left + w * (i + 0.5);
      if (i == 1) {
        // 非表示にする項目：薄く＋斜線
        _drawIcon(canvas, icons[i], Offset(cx, y), size: 15, color: scheme.onSurfaceVariant.withValues(alpha: 0.3));
        canvas.drawLine(Offset(cx - 8, y + 8), Offset(cx + 8, y - 8),
            Paint()..color = scheme.error.withValues(alpha: 0.7)..strokeWidth = 1.5);
      } else if (i == 3) {
        // 並び替え中の項目：上にずらして縁取り＋ドラッグハンドル
        _drawIcon(canvas, icons[i], Offset(cx, y - 14), size: 16, color: scheme.primary);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(cx, y - 14), width: 22, height: 22), const Radius.circular(5)),
            Paint()..color = scheme.primary..style = PaintingStyle.stroke..strokeWidth = 1.5);
        _drawIcon(canvas, Icons.drag_indicator, Offset(cx, y + 10), size: 12,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6));
      } else {
        _drawIcon(canvas, icons[i], Offset(cx, y), size: 15, color: scheme.onSurfaceVariant);
      }
    }
  }
}
