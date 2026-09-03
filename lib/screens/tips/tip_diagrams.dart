import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Tipsページの図解。実際の画面のスクリーンショット（ラスタ画像）を
/// 埋め込むと、多言語×複数ページ分の画像アセットでアプリの容量が
/// 増え、低スペック端末では画像デコードの負荷もかさむ。ここでは
/// 各Tipの要点だけを表す簡易的な模式図をCanvas描画で表現することで、
/// 画像アセットを一切使わずに済ませている（ベクター描画はテーマの
/// 色にも自動追従する）。
///
/// 各Tipは重複せずそれぞれの内容に即した図解を持つ。専用の模式図を持つ
/// Tip（[TipDiagramKind.clipDuplicate]等）に加え、「アイコンA×アイコンBの
/// 組み合わせ」という頻出パターンには[TipDiagramKind.pairCombo]、
/// 「Aだったものが矢印を経てBになる」という頻出パターンには
/// [TipDiagramKind.flowArrow]という2つの汎用テンプレートを用意し、
/// Tip側でアイコンの組み合わせを指定する（[TipDiagramSpec]参照）。
enum TipDiagramKind {
  clipDuplicate,
  textCaption,
  autofillPreset,
  brushFavorite,
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
  radialVignette,
  mirrorLayout,
  lineColorModes,
  blushGradient,
  // 汎用テンプレート（iconA・iconBをTip側で指定する）
  pairCombo,
  flowArrow,
}

/// 1件のTipsに紐づく図解の指定。専用の模式図を持つ[kind]は[iconA]等を
/// 使わない。[TipDiagramKind.pairCombo]・[TipDiagramKind.flowArrow]は
/// [iconA]・[iconB]（と[separator]）が必須。[TipDiagramKind.gestureShortcut]
/// は[iconA]で中央のアイコンを、[TipDiagramKind.pressureCurve]は
/// [iconA]（省略可）でグラフ右上に添えるバッジアイコンを上書きできる。
class TipDiagramSpec {
  final TipDiagramKind kind;
  final IconData? iconA;
  final IconData? iconB;
  final String separator;
  const TipDiagramSpec(
    this.kind, {
    this.iconA,
    this.iconB,
    this.separator = '×',
  });
}

class TipDiagram extends StatelessWidget {
  final TipDiagramSpec spec;
  const TipDiagram(this.spec, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: const Size(double.infinity, 96),
      painter: _TipDiagramPainter(spec, scheme),
    );
  }
}

class _TipDiagramPainter extends CustomPainter {
  final TipDiagramSpec spec;
  final ColorScheme scheme;
  _TipDiagramPainter(this.spec, this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    switch (spec.kind) {
      case TipDiagramKind.clipDuplicate:
        _paintClipDuplicate(canvas, size);
      case TipDiagramKind.textCaption:
        _paintTextCaption(canvas, size);
      case TipDiagramKind.autofillPreset:
        _paintAutofillPreset(canvas, size);
      case TipDiagramKind.brushFavorite:
        _paintBrushFavorite(canvas, size);
      case TipDiagramKind.pressureCurve:
        _paintPressureCurve(canvas, size, badge: spec.iconA);
      case TipDiagramKind.effectFilter:
        _paintEffectFilter(canvas, size);
      case TipDiagramKind.cameraKeyframe:
        _paintCameraKeyframe(canvas, size);
      case TipDiagramKind.exportFormat:
        _paintExportFormat(canvas, size);
      case TipDiagramKind.gestureShortcut:
        _paintGestureShortcut(
          canvas,
          size,
          icon: spec.iconA ?? Icons.touch_app,
        );
      case TipDiagramKind.timelineMarker:
        _paintTimelineMarker(canvas, size);
      case TipDiagramKind.pcDexLayout:
        _paintPcDexLayout(canvas, size);
      case TipDiagramKind.lineArtExtraction:
        _paintLineArtExtraction(canvas, size);
      case TipDiagramKind.selectionTool:
        _paintSelectionTool(canvas, size);
      case TipDiagramKind.layerFolder:
        _paintLayerFolder(canvas, size);
      case TipDiagramKind.saveSlot:
        _paintSaveSlot(canvas, size);
      case TipDiagramKind.transparentColor:
        _paintTransparentColor(canvas, size);
      case TipDiagramKind.performanceGauge:
        _paintPerformanceGauge(canvas, size);
      case TipDiagramKind.deviceTransfer:
        _paintDeviceTransfer(canvas, size);
      case TipDiagramKind.toolbarCustomize:
        _paintToolbarCustomize(canvas, size);
      case TipDiagramKind.radialVignette:
        _paintRadialVignette(canvas, size);
      case TipDiagramKind.mirrorLayout:
        _paintMirrorLayout(canvas, size);
      case TipDiagramKind.lineColorModes:
        _paintLineColorModes(canvas, size);
      case TipDiagramKind.blushGradient:
        _paintBlushGradient(canvas, size);
      case TipDiagramKind.pairCombo:
        _paintPairCombo(canvas, size, spec.iconA!, spec.iconB!, spec.separator);
      case TipDiagramKind.flowArrow:
        _paintFlowArrow(canvas, size, spec.iconA!, spec.iconB!);
    }
  }

  @override
  bool shouldRepaint(covariant _TipDiagramPainter oldDelegate) =>
      oldDelegate.spec.kind != spec.kind ||
      oldDelegate.spec.iconA != spec.iconA ||
      oldDelegate.spec.iconB != spec.iconB ||
      oldDelegate.spec.separator != spec.separator ||
      oldDelegate.scheme != scheme;

  // ── 共通パーツ ──────────────────────────────────────────────
  Paint get _fillPrimary => Paint()..color = scheme.primary;
  Paint get _fillPrimaryFaint =>
      Paint()..color = scheme.primary.withValues(alpha: 0.35);
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
  void _drawIcon(
    Canvas canvas,
    IconData icon,
    Offset center, {
    double size = 16,
    Color? color,
  }) {
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      )
      ..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _arrow(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint, {
    double headLen = 6.0,
  }) {
    canvas.drawLine(from, to, paint);
    final angle = (to - from).direction;
    for (final da in [2.6, -2.6]) {
      final p = to - Offset.fromDirection(angle + da * 0.3, headLen);
      canvas.drawLine(to, p, paint);
    }
  }

  /// 「画面の一部」を表す背景枠。キャンバス編集画面のように、テーマの
  /// 表面色で塗った角丸パネルの上に要素を重ねることで、抽象的な図形
  /// だけでなく実際の画面の断片を切り取ったような見た目にする。
  void _screenFrame(Canvas canvas, Rect rect, {double radius = 8}) {
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rr, Paint()..color = scheme.surfaceContainerLow);
    canvas.drawRRect(rr, _strokeOutline);
  }

  void _star(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outer = Offset.fromDirection(-1.5708 + i * 2 * 3.14159 / 5, r);
      final inner = Offset.fromDirection(
        -1.5708 + (i + 0.5) * 2 * 3.14159 / 5,
        r * 0.45,
      );
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

  // ── 汎用テンプレート ─────────────────────────────────────────

  /// 「AとBを組み合わせる」パターン用の汎用図解：左にA、右にB、中央に
  /// 組み合わせ記号（既定は×）を配した2つの円アイコン。多くのTipsが
  /// 「○○×○○で△△」という組み合わせ活用法のため、最も出番の多い
  /// テンプレート。
  void _paintPairCombo(
    Canvas canvas,
    Size size,
    IconData a,
    IconData b,
    String separator,
  ) {
    final s = size.height / 96;
    final cy = size.height / 2;
    final leftX = size.width * 0.24;
    final rightX = size.width * 0.76;
    final r = size.height * 0.32;
    canvas.drawCircle(Offset(leftX, cy), r, _fillPrimaryFaint);
    canvas.drawCircle(
      Offset(leftX, cy),
      r,
      Paint()
        ..color = scheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * s,
    );
    _drawIcon(
      canvas,
      a,
      Offset(leftX, cy),
      size: r * 0.95,
      color: scheme.primary,
    );
    final rightFill = Paint()..color = scheme.tertiary.withValues(alpha: 0.25);
    final rightStroke = Paint()
      ..color = scheme.tertiary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * s;
    canvas.drawCircle(Offset(rightX, cy), r, rightFill);
    canvas.drawCircle(Offset(rightX, cy), r, rightStroke);
    _drawIcon(
      canvas,
      b,
      Offset(rightX, cy),
      size: r * 0.95,
      color: scheme.tertiary,
    );
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: separator,
        style: TextStyle(
          fontSize: 26 * s,
          fontWeight: FontWeight.bold,
          color: scheme.onSurfaceVariant,
        ),
      )
      ..layout();
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, cy - tp.height / 2));
  }

  /// 「AだったものをBにする／Bで使い回す」パターン用の汎用図解：左に
  /// 控えめなAのアイコン、矢印、右に強調されたBのアイコン。
  void _paintFlowArrow(Canvas canvas, Size size, IconData a, IconData b) {
    final s = size.height / 96;
    final cy = size.height / 2;
    final leftX = size.width * 0.22;
    final rightX = size.width * 0.78;
    final r = size.height * 0.3;
    canvas.drawCircle(Offset(leftX, cy), r, _strokeOutline);
    _drawIcon(
      canvas,
      a,
      Offset(leftX, cy),
      size: r * 0.85,
      color: scheme.onSurfaceVariant,
    );
    _arrow(
      canvas,
      Offset(leftX + r + 10 * s, cy),
      Offset(rightX - r - 10 * s, cy),
      _strokePrimary,
      headLen: 10 * s,
    );
    canvas.drawCircle(Offset(rightX, cy), r, _fillPrimaryFaint);
    canvas.drawCircle(
      Offset(rightX, cy),
      r,
      Paint()
        ..color = scheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * s,
    );
    _drawIcon(
      canvas,
      b,
      Offset(rightX, cy),
      size: r * 0.85,
      color: scheme.primary,
    );
  }

  // ── 各Tipの模式図（専用）────────────────────────────────────

  /// タイムラインの帯＋クリップ1つ→矢印→複製されたクリップ。timeline_screen.dart
  /// の実際のトラック背景色（帯の下地）を模した「画面の一部」として描く。
  void _paintClipDuplicate(Canvas canvas, Size size) {
    final s = size.height / 96;
    final track = Rect.fromLTWH(
      0,
      size.height * 0.4,
      size.width,
      size.height * 0.3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, Radius.circular(6 * s)),
      Paint()..color = scheme.surfaceContainerHighest,
    );
    final y = track.center.dy;
    final clip1 = Rect.fromCenter(
      center: Offset(size.width * 0.22, y),
      width: 44 * s,
      height: 26 * s,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(clip1, Radius.circular(4 * s)),
      _fillPrimary,
    );
    _arrow(
      canvas,
      Offset(clip1.right + 6 * s, y),
      Offset(size.width * 0.62, y),
      _strokeOutline,
      headLen: 9 * s,
    );
    final clip2 = Rect.fromCenter(
      center: Offset(size.width * 0.78, y),
      width: 44 * s,
      height: 26 * s,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(clip2, Radius.circular(4 * s)),
      _fillPrimaryFaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(clip2, Radius.circular(4 * s)),
      _strokePrimary,
    );
  }

  /// キャンバス画面全体（枠＋キャンバス背景色）を模し、下部に字幕の
  /// 吹き出し（横線2本＝テキスト）を重ねる。
  void _paintTextCaption(Canvas canvas, Size size) {
    final s = size.height / 96;
    final screen = Rect.fromLTWH(
      size.width * 0.5 - size.height * 0.48,
      6 * s,
      size.height * 0.96,
      size.height - 12 * s,
    );
    _screenFrame(canvas, screen, radius: 8 * s);
    final bubble = Rect.fromLTWH(
      screen.left + 8 * s,
      screen.bottom - 34 * s,
      screen.width - 16 * s,
      24 * s,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bubble, Radius.circular(5 * s)),
      _fillPrimary,
    );
    final linePaint = Paint()
      ..color = scheme.surface
      ..strokeWidth = 2 * s;
    canvas.drawLine(
      Offset(bubble.left + 8 * s, bubble.center.dy - 4 * s),
      Offset(bubble.right - 14 * s, bubble.center.dy - 4 * s),
      linePaint,
    );
    canvas.drawLine(
      Offset(bubble.left + 8 * s, bubble.center.dy + 5 * s),
      Offset(bubble.right - 26 * s, bubble.center.dy + 5 * s),
      linePaint,
    );
  }

  /// 3色の配色スウォッチ（肌・髪・服の陰影セット）を積み、実際のパレット
  /// アイコンを添える。自動塗りプリセット編集画面の背景を模した
  /// パネル上に配置する。
  void _paintAutofillPreset(Canvas canvas, Size size) {
    final s = size.height / 96;
    _screenFrame(canvas, Offset.zero & size, radius: 10 * s);
    final colors = [scheme.primary, scheme.secondary, scheme.tertiary];
    final w = (size.width - 40 * s) / 3;
    for (int i = 0; i < 3; i++) {
      final x = 16 * s + i * (w + 12 * s);
      final base = Rect.fromLTWH(x, size.height * 0.24, w, size.height * 0.32);
      final shade = Rect.fromLTWH(x, base.bottom, w, size.height * 0.2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(base, Radius.circular(3 * s)),
        Paint()..color = colors[i],
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(shade, Radius.circular(3 * s)),
        Paint()..color = colors[i].withValues(alpha: 0.55),
      );
    }
    _drawIcon(
      canvas,
      Icons.palette_outlined,
      Offset(size.width / 2, size.height * 0.11),
      size: 16 * s,
      color: scheme.onSurfaceVariant,
    );
  }

  /// 実際のブラシアイコンと、右上に星マーク（お気に入り）。ブラシ設定
  /// 画面の背景を模したパネル上に配置する。
  void _paintBrushFavorite(Canvas canvas, Size size) {
    final s = size.height / 96;
    _screenFrame(canvas, Offset.zero & size, radius: 10 * s);
    _drawIcon(
      canvas,
      Icons.brush,
      Offset(size.width * 0.42, size.height * 0.52),
      size: 34 * s,
      color: scheme.primary,
    );
    _star(
      canvas,
      Offset(size.width * 0.72, size.height * 0.28),
      14 * s,
      Paint()..color = scheme.tertiary,
    );
  }

  /// 軸＋曲線＋制御点2つ（筆圧カーブ・トーンカーブ等）。[badge]を指定すると
  /// 右上に小さくアイコンを添え、同じ「曲線グラフ」構図でも他のTipと
  /// 見分けが付くようにする。設定画面のグラフパネルを模した背景に描く。
  void _paintPressureCurve(Canvas canvas, Size size, {IconData? badge}) {
    final s = size.height / 96;
    _screenFrame(canvas, Offset.zero & size, radius: 10 * s);
    final origin = Offset(size.width * 0.24, size.height * 0.82);
    final top = Offset(size.width * 0.24, size.height * 0.14);
    final right = Offset(size.width * 0.82, size.height * 0.82);
    canvas.drawLine(origin, top, _strokeOutline);
    canvas.drawLine(origin, right, _strokeOutline);
    final curve = Path()
      ..moveTo(origin.dx, origin.dy)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.78,
        right.dx,
        top.dy,
      );
    canvas.drawPath(curve, _strokePrimary);
    canvas.drawCircle(origin, 5 * s, _fillPrimary);
    canvas.drawCircle(
      Offset(size.width * 0.52, size.height * 0.48),
      5 * s,
      _fillPrimary,
    );
    canvas.drawCircle(Offset(right.dx, top.dy), 5 * s, _fillPrimary);
    if (badge != null) {
      canvas.drawCircle(
        Offset(size.width * 0.88, size.height * 0.16),
        15 * s,
        _fillPrimaryFaint,
      );
      _drawIcon(
        canvas,
        badge,
        Offset(size.width * 0.88, size.height * 0.16),
        size: 17 * s,
        color: scheme.primary,
      );
    }
  }

  /// キャンバス画面全体を模した枠に斜めのグラデーション帯＋きらめき
  /// （演出フィルターの組み合わせ）。
  void _paintEffectFilter(Canvas canvas, Size size) {
    final s = size.height / 96;
    final screen = Rect.fromLTWH(
      size.width * 0.5 - size.height * 0.48,
      6 * s,
      size.height * 0.96,
      size.height - 12 * s,
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(screen, Radius.circular(8 * s)));
    final shader = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.primary.withValues(alpha: 0.7),
          scheme.tertiary.withValues(alpha: 0.7),
        ],
      ).createShader(screen);
    canvas.drawRect(screen, shader);
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, Radius.circular(8 * s)),
      _strokeOutline,
    );
    _drawIcon(
      canvas,
      Icons.auto_awesome,
      screen.center,
      size: 22 * s,
      color: scheme.surface,
    );
    _star(
      canvas,
      Offset(screen.right + 14 * s, screen.top + 18 * s),
      10 * s,
      Paint()..color = scheme.tertiary,
    );
  }

  /// 小さい矩形→大きい矩形への矢印（ズーム）。カメラキーフレームによる
  /// ズームブラー演出専用。バッジには timeline_screen.dart
  /// _buildTrackLabel(Icons.camera_alt, ...) が実際にカメラトラックの
  /// ラベルへ使う実アイコンを使う。
  void _paintCameraKeyframe(Canvas canvas, Size size) {
    final s = size.height / 96;
    final small = Rect.fromCenter(
      center: Offset(size.width * 0.22, size.height * 0.5),
      width: 30 * s,
      height: 22 * s,
    );
    final large = Rect.fromCenter(
      center: Offset(size.width * 0.74, size.height * 0.5),
      width: 56 * s,
      height: 42 * s,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(small, Radius.circular(3 * s)),
      _strokeOutline,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(large, Radius.circular(4 * s)),
      _strokePrimary,
    );
    _arrow(
      canvas,
      Offset(small.right + 8 * s, size.height * 0.5),
      Offset(large.left - 8 * s, size.height * 0.5),
      _strokeOutline,
      headLen: 9 * s,
    );
    _drawIcon(
      canvas,
      Icons.camera_alt,
      large.center,
      size: 22 * s,
      color: scheme.primary,
    );
  }

  /// 3つの書き出し形式チップ（透過＝市松模様・動画＝塗り＋再生アイコン・GIF＝丸枠）。
  /// export_screen.dartのRadioListTileは形式ごとの専用アイコンを
  /// 持たないため、アイコンは形式の内容を象徴する一般的なものを使う。
  void _paintExportFormat(Canvas canvas, Size size) {
    final s = size.height / 96;
    final w = (size.width - 40 * s) / 3;
    for (int i = 0; i < 3; i++) {
      final rect = Rect.fromLTWH(
        16 * s + i * (w + 12 * s),
        size.height * 0.22,
        w,
        size.height * 0.56,
      );
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(6 * s));
      canvas.drawRRect(rr, _strokeOutline);
      switch (i) {
        case 0: // 透過WebM：市松模様
          canvas.save();
          canvas.clipRRect(rr);
          final cell = rect.width / 4;
          final checker = Paint()
            ..color = scheme.outlineVariant.withValues(alpha: 0.5);
          for (int gy = 0; gy < 4; gy++) {
            for (int gx = 0; gx < 4; gx++) {
              if ((gx + gy).isEven) continue;
              canvas.drawRect(
                Rect.fromLTWH(
                  rect.left + gx * cell,
                  rect.top + gy * cell,
                  cell,
                  cell,
                ),
                checker,
              );
            }
          }
          canvas.restore();
        case 1: // MP4：実際の再生アイコン
          canvas.drawRRect(rr, _fillPrimaryFaint);
          _drawIcon(
            canvas,
            Icons.play_circle_outline,
            rect.center,
            size: 28 * s,
            color: scheme.primary,
          );
        default: // GIF：実際のGIFアイコン
          canvas.drawRRect(rr, _fillPrimaryFaint);
          _drawIcon(
            canvas,
            Icons.gif_box_outlined,
            rect.center,
            size: 28 * s,
            color: scheme.primary,
          );
      }
    }
  }

  /// 画面の上に重なる2本指タップ（実際のタップアイコン）と、中央の
  /// アイコン（何を割り当てたジェスチャーかを[icon]で切り替える）。
  /// キャンバス画面全体を模した枠の上に重ねる。
  void _paintGestureShortcut(
    Canvas canvas,
    Size size, {
    required IconData icon,
  }) {
    final s = size.height / 96;
    final screen = Rect.fromLTWH(
      size.width * 0.5 - size.height * 0.44,
      size.height * 0.06,
      size.height * 0.88,
      size.height * 0.88,
    );
    _screenFrame(canvas, screen, radius: 10 * s);
    canvas.drawArc(
      Rect.fromCenter(center: screen.center, width: 40 * s, height: 40 * s),
      3.7,
      4.2,
      false,
      _strokePrimary,
    );
    _drawIcon(canvas, icon, screen.center, size: 20 * s, color: scheme.primary);
    canvas.drawCircle(
      Offset(size.width * 0.4, size.height * 0.16),
      12 * s,
      _fillPrimaryFaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.6, size.height * 0.16),
      12 * s,
      _fillPrimaryFaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.4, size.height * 0.16),
      12 * s,
      _strokePrimary,
    );
    canvas.drawCircle(
      Offset(size.width * 0.6, size.height * 0.16),
      12 * s,
      _strokePrimary,
    );
    _drawIcon(
      canvas,
      Icons.touch_app,
      Offset(size.width * 0.5, size.height * 0.16),
      size: 16 * s,
      color: scheme.primary,
    );
  }

  /// タイムラインの帯＋ピン（タイムスタンプ）＋コメントの吹き出し。
  /// timeline_screen.dartのトラック背景色を模した帯の上に描く。
  void _paintTimelineMarker(Canvas canvas, Size size) {
    final s = size.height / 96;
    final track = Rect.fromLTWH(
      0,
      size.height * 0.52,
      size.width,
      size.height * 0.24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(track, Radius.circular(6 * s)),
      Paint()..color = scheme.surfaceContainerHighest,
    );
    final y = track.center.dy;
    for (final t in [0.28, 0.56, 0.82]) {
      final x = size.width * t;
      final isMain = t == 0.56;
      canvas.drawCircle(
        Offset(x, y),
        isMain ? 8 * s : 5 * s,
        isMain ? _fillPrimary : _fillPrimaryFaint,
      );
      if (isMain) {
        final bubble = Rect.fromLTWH(
          x - 26 * s,
          size.height * 0.08,
          52 * s,
          size.height * 0.36,
        );
        final rr = RRect.fromRectAndRadius(bubble, Radius.circular(5 * s));
        canvas.drawRRect(rr, _fillPrimaryFaint);
        canvas.drawRRect(rr, _strokePrimary);
        final tail = Path()
          ..moveTo(x - 5 * s, bubble.bottom)
          ..lineTo(x, bubble.bottom + 7 * s)
          ..lineTo(x + 5 * s, bubble.bottom)
          ..close();
        canvas.drawPath(tail, _fillPrimaryFaint);
      }
    }
  }

  /// 左：スマホ（下部にツールバー）→矢印→右：PC/DeX（左右にドッキング
  /// パネル）。ワイド画面で自動的にレイアウトが切り替わることを表す。
  void _paintPcDexLayout(Canvas canvas, Size size) {
    final s = size.height / 96;
    final phone = Rect.fromLTWH(
      size.width * 0.06,
      size.height * 0.1,
      size.width * 0.2,
      size.height * 0.8,
    );
    _screenFrame(canvas, phone, radius: 8 * s);
    _drawIcon(
      canvas,
      Icons.smartphone,
      Offset(phone.center.dx, phone.top + phone.height * 0.35),
      size: 18 * s,
      color: scheme.onSurfaceVariant,
    );
    final phoneToolbar = Rect.fromLTWH(
      phone.left + 4 * s,
      phone.bottom - 18 * s,
      phone.width - 8 * s,
      13 * s,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(phoneToolbar, Radius.circular(3 * s)),
      _fillPrimaryFaint,
    );

    _arrow(
      canvas,
      Offset(phone.right + 10 * s, size.height * 0.5),
      Offset(size.width * 0.52, size.height * 0.5),
      _strokeOutline,
      headLen: 9 * s,
    );

    final pc = Rect.fromLTWH(
      size.width * 0.58,
      size.height * 0.16,
      size.width * 0.38,
      size.height * 0.68,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pc, Radius.circular(8 * s)),
      Paint()..color = scheme.surfaceContainerLow,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pc, Radius.circular(8 * s)),
      _strokePrimary,
    );
    final leftPanel = Rect.fromLTWH(
      pc.left + 4 * s,
      pc.top + 4 * s,
      pc.width * 0.2,
      pc.height - 8 * s,
    );
    final rightPanel = Rect.fromLTWH(
      pc.right - pc.width * 0.2 - 4 * s,
      pc.top + 4 * s,
      pc.width * 0.2,
      pc.height - 8 * s,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(leftPanel, Radius.circular(3 * s)),
      _fillPrimaryFaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightPanel, Radius.circular(3 * s)),
      _fillPrimaryFaint,
    );
  }

  /// 左：色つきのイラスト（グラデーション＋線）→矢印→右：市松模様（透過）の
  /// 上に線だけが残った線画。色調補正・二値化・明度で透過を組み合わせて
  /// 線画を抽出するTipsの図解。
  void _paintLineArtExtraction(Canvas canvas, Size size) {
    final s = size.height / 96;
    final left = Rect.fromLTWH(
      4 * s,
      size.height * 0.1,
      size.width * 0.36,
      size.height * 0.8,
    );
    final right = Rect.fromLTWH(
      size.width * 0.6,
      size.height * 0.1,
      size.width * 0.36,
      size.height * 0.8,
    );

    // 左：色つきの元イラスト（グラデーション背景＋輪郭線）
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(left, Radius.circular(8 * s)));
    final gradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.primary.withValues(alpha: 0.6),
          scheme.tertiary.withValues(alpha: 0.6),
        ],
      ).createShader(left);
    canvas.drawRect(left, gradient);
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(left, Radius.circular(8 * s)),
      _strokeOutline,
    );
    final face = Path()
      ..addOval(
        Rect.fromCenter(
          center: left.center,
          width: left.width * 0.55,
          height: left.height * 0.5,
        ),
      );
    canvas.drawPath(
      face,
      Paint()
        ..color = scheme.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6 * s,
    );

    _arrow(
      canvas,
      Offset(left.right + 8 * s, size.height * 0.5),
      Offset(right.left - 8 * s, size.height * 0.5),
      _strokeOutline,
      headLen: 9 * s,
    );

    // 右：市松模様（透過）の上に線だけが残った抽出結果
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(right, Radius.circular(8 * s)));
    final cell = right.width / 5;
    final checker = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.45);
    for (int gy = 0; gy * cell < right.height; gy++) {
      for (int gx = 0; gx < 5; gx++) {
        if ((gx + gy).isEven) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            right.left + gx * cell,
            right.top + gy * cell,
            cell,
            cell,
          ),
          checker,
        );
      }
    }
    final extractedFace = Path()
      ..addOval(
        Rect.fromCenter(
          center: right.center,
          width: right.width * 0.55,
          height: right.height * 0.5,
        ),
      );
    canvas.drawPath(
      extractedFace,
      Paint()
        ..color = scheme.onSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6 * s,
    );
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(right, Radius.circular(8 * s)),
      _strokeOutline,
    );
  }

  /// 破線の投げ縄パスと、その脇にマジックワンド（きらめき）アイコン。
  /// キャンバス画面全体を模した枠の上に描く。
  void _paintSelectionTool(Canvas canvas, Size size) {
    final s = size.height / 96;
    _screenFrame(canvas, Offset.zero & size, radius: 10 * s);
    final path = Path()
      ..moveTo(size.width * 0.16, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.1,
        size.height * 0.32,
        size.width * 0.34,
        size.height * 0.22,
      )
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.1,
        size.width * 0.6,
        size.height * 0.4,
      )
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.68,
        size.width * 0.34,
        size.height * 0.7,
      )
      ..close();
    final dashed = Path();
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double dist = 0;
      final dashLen = 5.0 * s, gapLen = 4.0 * s;
      while (dist < m.length) {
        final next = (dist + dashLen).clamp(0, m.length);
        dashed.addPath(m.extractPath(dist, next.toDouble()), Offset.zero);
        dist += dashLen + gapLen;
      }
    }
    canvas.drawPath(dashed, _strokePrimary);
    canvas.drawPath(
      path,
      Paint()..color = scheme.primary.withValues(alpha: 0.15),
    );
    // 実際のツールアイコン：DrawingTool.selectMagicWand=auto_awesome、
    // DrawingTool.selectLasso=gesture（toolbar_widget.dart参照）。
    _drawIcon(
      canvas,
      Icons.auto_awesome,
      Offset(size.width * 0.8, size.height * 0.28),
      size: 26 * s,
      color: scheme.tertiary,
    );
    _drawIcon(
      canvas,
      Icons.gesture,
      Offset(size.width * 0.8, size.height * 0.68),
      size: 26 * s,
      color: scheme.primary,
    );
  }

  /// フォルダアイコンの中に、複数プロジェクトへ共有される共通レイヤー
  /// （重なった四角）を示す。共通レイヤーのバッジには
  /// layer_panel.dart _layerTypeIcon()が実際に使うIcons.link（レイヤー
  /// パネルの行で共通レイヤーに表示される実アイコン）を使う
  /// （実画面ではColors.blue固定だが、この図解はテーマの配色に自動追従
  /// させるためscheme.primary系の色で描く）。
  void _paintLayerFolder(Canvas canvas, Size size) {
    final s = size.height / 96;
    _drawIcon(
      canvas,
      Icons.folder,
      Offset(size.width * 0.28, size.height * 0.5),
      size: 52 * s,
      color: scheme.tertiary,
    );
    final stack = [0, 1, 2];
    for (final i in stack) {
      final rect = Rect.fromCenter(
        center: Offset(
          size.width * 0.72 - i * 5 * s,
          size.height * 0.5 - i * 5 * s,
        ),
        width: 44 * s,
        height: 30 * s,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(4 * s)),
        i == 0
            ? _fillPrimary
            : (Paint()
                ..color = scheme.primary.withValues(alpha: 0.4 - i * 0.1)),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(4 * s)),
        _strokeOutline,
      );
    }
    _drawIcon(
      canvas,
      Icons.link,
      Offset(size.width * 0.72, size.height * 0.5),
      size: 18 * s,
      color: scheme.onPrimary,
    );
  }

  /// 手動セーブ（保存アイコン、複数残る）と自動保存（回転する更新
  /// アイコン、常に1つだけ）を並べる。手動セーブのアイコンは
  /// save_tree_screen.dartが実際に使うIcons.saveを使う。
  void _paintSaveSlot(Canvas canvas, Size size) {
    final s = size.height / 96;
    for (int i = 0; i < 3; i++) {
      final cx = size.width * (0.12 + i * 0.16);
      final rect = Rect.fromCenter(
        center: Offset(cx, size.height * 0.5),
        width: 32 * s,
        height: 42 * s,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(5 * s)),
        i == 2 ? _fillPrimaryFaint : _strokeOutline,
      );
      if (i == 2)
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(5 * s)),
          _strokePrimary,
        );
      _drawIcon(
        canvas,
        Icons.save,
        rect.center,
        size: 18 * s,
        color: i == 2
            ? scheme.primary
            : scheme.onSurfaceVariant.withValues(alpha: 0.6),
      );
    }
    final autoCenter = Offset(size.width * 0.78, size.height * 0.5);
    canvas.drawCircle(
      autoCenter,
      27 * s,
      Paint()..color = scheme.tertiary.withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      autoCenter,
      27 * s,
      Paint()
        ..color = scheme.tertiary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s,
    );
    _drawIcon(
      canvas,
      Icons.autorenew,
      autoCenter,
      size: 26 * s,
      color: scheme.tertiary,
    );
  }

  /// 色の塗られた面の一部が市松模様（透明）に削れた帯＋ブラシアイコン。
  /// 消しゴムではなく「ブラシで透明色を塗って消す」イメージを表す。
  void _paintTransparentColor(Canvas canvas, Size size) {
    final s = size.height / 96;
    final area = Rect.fromLTWH(
      size.width * 0.5 - size.height * 0.48,
      8 * s,
      size.height * 0.96,
      size.height - 16 * s,
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(area, Radius.circular(8 * s)));
    canvas.drawRect(area, _fillPrimaryFaint);
    // 帯状に市松模様（透明部分）を重ね、斜めのブラシストロークで
    // 「なぞって透明にした」帯を表現する。
    final band = Rect.fromLTWH(
      area.left,
      area.top + area.height * 0.36,
      area.width,
      area.height * 0.3,
    );
    final cell = area.width / 6;
    final checker = Paint()..color = scheme.surface;
    for (int gy = 0; gy * cell < band.height; gy++) {
      for (int gx = 0; gx < 6; gx++) {
        if ((gx + gy).isOdd) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            band.left + gx * cell,
            band.top + gy * cell,
            cell,
            cell,
          ),
          checker,
        );
      }
    }
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(area, Radius.circular(8 * s)),
      _strokeOutline,
    );
    _drawIcon(
      canvas,
      Icons.brush,
      band.center,
      size: 24 * s,
      color: scheme.primary,
    );
  }

  /// 速度計（ゲージ）の針を「低品質」寄りに振り、軽量化を示す。
  void _paintPerformanceGauge(Canvas canvas, Size size) {
    final s = size.height / 96;
    final center = Offset(size.width / 2, size.height * 0.78);
    final r = size.height * 0.62;
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawArc(
      rect,
      3.14159,
      3.14159,
      false,
      Paint()
        ..color = scheme.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * s,
    );
    canvas.drawArc(
      rect,
      3.14159,
      3.14159 * 0.35,
      false,
      Paint()
        ..color = scheme.tertiary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * s,
    );
    const needleAngle = 3.14159 * 1.18; // 低品質寄り
    final needleEnd = center + Offset.fromDirection(needleAngle, r * 0.85);
    canvas.drawLine(center, needleEnd, _strokePrimary);
    canvas.drawCircle(center, 5 * s, _fillPrimary);
    _drawIcon(
      canvas,
      Icons.speed,
      Offset(center.dx, center.dy - r * 0.55),
      size: 22 * s,
      color: scheme.onSurfaceVariant,
    );
  }

  /// スマートフォン→引き継ぎファイルのアイコン→スマートフォンの順で、
  /// 端末間でプロジェクト本体がまとめて移動することを示す。
  void _paintDeviceTransfer(Canvas canvas, Size size) {
    final s = size.height / 96;
    final left = Offset(size.width * 0.16, size.height * 0.5);
    final right = Offset(size.width * 0.84, size.height * 0.5);
    _drawIcon(
      canvas,
      Icons.smartphone,
      left,
      size: 34 * s,
      color: scheme.onSurfaceVariant,
    );
    _drawIcon(
      canvas,
      Icons.smartphone,
      right,
      size: 34 * s,
      color: scheme.onSurfaceVariant,
    );
    final fileCenter = Offset(size.width / 2, size.height * 0.42);
    _arrow(
      canvas,
      left + Offset(18 * s, 0),
      fileCenter - Offset(18 * s, 0),
      _strokeOutline,
      headLen: 8 * s,
    );
    _arrow(
      canvas,
      fileCenter + Offset(18 * s, 0),
      right - Offset(18 * s, 0),
      _strokeOutline,
      headLen: 8 * s,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: fileCenter, width: 38 * s, height: 44 * s),
        Radius.circular(5 * s),
      ),
      _fillPrimaryFaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: fileCenter, width: 38 * s, height: 44 * s),
        Radius.circular(5 * s),
      ),
      _strokePrimary,
    );
    _drawIcon(
      canvas,
      Icons.sync_alt,
      fileCenter,
      size: 20 * s,
      color: scheme.primary,
    );
  }

  /// ツールバーの並び（models/toolbar_item.dartの実アイコン・実順序の
  /// 先頭5項目：ペン→消しゴム→バケツ→スポイト→選択）のうち1つを上へ
  /// ずらして「並び替え中」を示し、もう1つを薄く消して「非表示」を示す。
  /// バケツはMaterial Icons標準の汎用アイコンではなく、実装がFont Awesomeへ
  /// 変更したペンキ缶（fillDrip）を使う（ToolbarItemIcon._iconData参照）。
  void _paintToolbarCustomize(Canvas canvas, Size size) {
    final s = size.height / 96;
    // キャンバス背景（kCanvasOutsideColor相当）の上に、実画面同様
    // 背景を持たないツールバーを直接重ねる（toolbar_widget.dart参照。
    // 実画面はheight:40の帯だが、図解では見やすさのため高さを取る）。
    _screenFrame(canvas, Offset.zero & size, radius: 10 * s);
    final y = size.height * 0.6;
    final icons = <IconData>[
      Icons.brush,
      FontAwesomeIcons.eraser.data,
      FontAwesomeIcons.fillDrip.data,
      Icons.colorize,
      Icons.highlight_alt,
    ];
    final w = size.width / icons.length;
    for (int i = 0; i < icons.length; i++) {
      final cx = w * (i + 0.5);
      if (i == 1) {
        // 非表示にする項目：薄く＋斜線
        _drawIcon(
          canvas,
          icons[i],
          Offset(cx, y),
          size: 22 * s,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
        );
        canvas.drawLine(
          Offset(cx - 11 * s, y + 11 * s),
          Offset(cx + 11 * s, y - 11 * s),
          Paint()
            ..color = scheme.error.withValues(alpha: 0.7)
            ..strokeWidth = 2 * s,
        );
      } else if (i == 3) {
        // 並び替え中の項目：上にずらして縁取り＋ドラッグハンドル
        _drawIcon(
          canvas,
          icons[i],
          Offset(cx, y - 20 * s),
          size: 23 * s,
          color: scheme.primary,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, y - 20 * s),
              width: 32 * s,
              height: 32 * s,
            ),
            Radius.circular(7 * s),
          ),
          Paint()
            ..color = scheme.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * s,
        );
        _drawIcon(
          canvas,
          Icons.drag_indicator,
          Offset(cx, y + 14 * s),
          size: 17 * s,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
        );
      } else {
        _drawIcon(
          canvas,
          icons[i],
          Offset(cx, y),
          size: 22 * s,
          color: scheme.onSurfaceVariant,
        );
      }
    }
  }

  /// 中心から放射状に伸びる集中線と、四隅を暗くする周辺減光の
  /// グラデーション。放射定規×周辺減光専用。キャンバス画面全体を
  /// 模した枠の上に描く。
  void _paintRadialVignette(Canvas canvas, Size size) {
    final s = size.height / 96;
    _screenFrame(canvas, Offset.zero & size, radius: 10 * s);
    final center = Offset(size.width / 2, size.height / 2);
    final linePaint = Paint()
      ..color = scheme.primary
      ..strokeWidth = 2 * s;
    for (int i = 0; i < 12; i++) {
      final angle = i * 3.14159 * 2 / 12;
      final inner = center + Offset.fromDirection(angle, size.height * 0.1);
      final outer = center + Offset.fromDirection(angle, size.height * 0.48);
      canvas.drawLine(inner, outer, linePaint);
    }
    final vignette = Paint()
      ..shader =
          RadialGradient(
            colors: [Colors.transparent, scheme.shadow.withValues(alpha: 0.4)],
            stops: const [0.35, 1.0],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.width * 0.62),
          );
    canvas.drawRect(Offset.zero & size, vignette);
    canvas.drawCircle(center, 6 * s, _fillPrimary);
  }

  /// 右側にドッキングされたパネル（標準）と、左右反転アイコンを挟んで
  /// 左側にドッキングされたパネル（左利きモード）。ワークスペース設定の
  /// 左利きモード専用。
  void _paintMirrorLayout(Canvas canvas, Size size) {
    final s = size.height / 96;
    _screenFrame(canvas, Offset.zero & size, radius: 10 * s);
    final barW = size.width * 0.15;
    final rightPanel = Rect.fromLTWH(
      size.width * 0.66,
      size.height * 0.16,
      barW,
      size.height * 0.68,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightPanel, Radius.circular(5 * s)),
      _fillPrimaryFaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightPanel, Radius.circular(5 * s)),
      _strokeOutline,
    );
    final leftPanel = Rect.fromLTWH(
      size.width * 0.19,
      size.height * 0.16,
      barW,
      size.height * 0.68,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(leftPanel, Radius.circular(5 * s)),
      Paint()..color = scheme.tertiary.withValues(alpha: 0.28),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(leftPanel, Radius.circular(5 * s)),
      Paint()
        ..color = scheme.tertiary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      21 * s,
      Paint()..color = scheme.surface,
    );
    _drawIcon(
      canvas,
      Icons.swap_horiz,
      Offset(size.width / 2, size.height / 2),
      size: 26 * s,
      color: scheme.primary,
    );
  }

  /// 線画色の3つの使い分け（輪郭線＝色トレス／影・ハイライト＝塗り色と
  /// 同化／指定色＝あえて別色）を、3つの小さな「線」見本として横に並べる。
  void _paintLineColorModes(Canvas canvas, Size size) {
    final s = size.height / 96;
    final labels = [
      (Icons.border_color, scheme.primary), // 輪郭線：色トレス・線画馴染ませ
      (
        Icons.gradient,
        scheme.onSurfaceVariant.withValues(alpha: 0.5),
      ), // 影・ハイライト：塗り色と同化
      (Icons.palette, scheme.tertiary), // 指定色：あえて別色
    ];
    final w = (size.width - 32 * s) / 3;
    for (int i = 0; i < 3; i++) {
      final x = 16 * s + i * (w + 8 * s);
      final swatch = Rect.fromLTWH(
        x,
        size.height * 0.18,
        w,
        size.height * 0.36,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(swatch, Radius.circular(5 * s)),
        _fillPrimaryFaint,
      );
      // 見本の輪郭線（各モードの色でなぞる）
      canvas.drawRRect(
        RRect.fromRectAndRadius(swatch, Radius.circular(5 * s)),
        Paint()
          ..color = labels[i].$2
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * s,
      );
      _drawIcon(
        canvas,
        labels[i].$1,
        Offset(x + w / 2, size.height * 0.72),
        size: 22 * s,
        color: labels[i].$2,
      );
    }
  }

  /// 肌色の丸の中心に、頬の赤みが放射状に馴染みながら透明色へ溶け込む
  /// 表現（自動塗りの「線画色＝透明色の指定色」×「塗り色＝放射：中央→
  /// 外側」の組み合わせで頬の赤みだけを乗せるTips専用）。
  void _paintBlushGradient(Canvas canvas, Size size) {
    final s = size.height / 96;
    final skin = Rect.fromLTWH(
      size.width * 0.5 - size.height * 0.46,
      6 * s,
      size.height * 0.92,
      size.height - 12 * s,
    );
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(skin, Radius.circular(size.height * 0.46)),
    );
    canvas.drawRect(skin, Paint()..color = const Color(0xFFF3C9A0));
    final blushCenter = Offset(skin.center.dx, skin.center.dy);
    canvas.drawCircle(
      blushCenter,
      skin.width * 0.32,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                scheme.error.withValues(alpha: 0.55),
                scheme.error.withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromCircle(center: blushCenter, radius: skin.width * 0.32),
            ),
    );
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(skin, Radius.circular(size.height * 0.46)),
      _strokeOutline,
    );
  }
}
