import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// アプリ全体のスクロールの振る舞い（`MaterialApp.scrollBehavior`）。
///
/// - マウス・スタイラス・トラックパッドでもドラッグでスクロール・PageViewの
///   スワイプができる（Flutterの既定はマウスドラッグを対象外にしており、
///   Chrome等デスクトップ環境でTipsの詳細ポップアップ〔PageView〕を横スワイプ
///   できなかった）。
/// - 縦にスクロールする所には、右端へ**常に**スクロールバーを出す（どこが
///   スクロールでき、いまどの辺りを見ているかが一目で分かるように）。
///   Flutter既定のMaterialScrollBehaviorはAndroid/iOSでは何も出さず、
///   デスクトップでもスクロール中しか出さない。
///
/// スマホでは操作できない表示だけのバー（[AlwaysShownScrollIndicator]）を
/// 使う。Flutterの`Scrollbar(thumbVisibility: true)`はScrollControllerが
/// 1つのスクロールにだけ付いていることを要求するが、スマホでは
/// コントローラーを渡していない縦スクロールが画面ごとの
/// PrimaryScrollControllerを共有するため、同じ画面に2つあると例外になる。
/// 表示だけのバーはスクロール通知だけで描くので、この制約を受けない。
/// デスクトップ（PrimaryScrollControllerを共有しない）では掴んで動かせる
/// Materialのスクロールバーを常時表示にする。
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (axisDirectionToAxis(details.direction) != Axis.vertical) return child;
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return Scrollbar(
          controller: details.controller,
          thumbVisibility: true,
          child: child,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return AlwaysShownScrollIndicator(child: child);
    }
  }
}

/// [child]（縦スクロール）の右端へ、いまの表示位置を示すつまみを常に描く。
/// 中身が収まっていてスクロールできないときは何も描かない。
///
/// 自分の直下のスクロール（通知の`depth == 0`）だけを見る。入れ子の
/// スクロールはそれぞれが自分のバーを持つ。再描画は`CustomPaint`の
/// `repaint`だけで行い、スクロールのたびに子を作り直さない。
class AlwaysShownScrollIndicator extends StatefulWidget {
  const AlwaysShownScrollIndicator({super.key, required this.child});

  final Widget child;

  /// つまみの太さ・右端からの余白・最小の長さ（論理px）。
  static const double thickness = 4;
  static const double margin = 2;
  static const double minThumbLength = 24;

  @override
  State<AlwaysShownScrollIndicator> createState() =>
      _AlwaysShownScrollIndicatorState();
}

class _AlwaysShownScrollIndicatorState
    extends State<AlwaysShownScrollIndicator> {
  final _metrics = ValueNotifier<ScrollMetrics?>(null);

  @override
  void dispose() {
    _metrics.dispose();
    super.dispose();
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    if (notification.depth == 0) _metrics.value = notification.metrics;
    return false;
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth == 0) _metrics.value = notification.metrics;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.45);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomPaint(
          foregroundPainter: ScrollIndicatorPainter(_metrics, color),
          child: widget.child,
        ),
      ),
    );
  }
}

/// [AlwaysShownScrollIndicator]のつまみ。
class ScrollIndicatorPainter extends CustomPainter {
  ScrollIndicatorPainter(this.metrics, this.color) : super(repaint: metrics);

  final ValueListenable<ScrollMetrics?> metrics;
  final Color color;

  /// [size]の領域で、[m]の位置に描くつまみの矩形（描かないときはnull）。
  static Rect? thumbRectFor(ScrollMetrics? m, Size size) {
    if (m == null || !m.hasContentDimensions || !m.hasViewportDimension) {
      return null;
    }
    final range = m.maxScrollExtent - m.minScrollExtent;
    if (range < 0.5) return null;
    const margin = AlwaysShownScrollIndicator.margin;
    const thickness = AlwaysShownScrollIndicator.thickness;
    final track = size.height - margin * 2;
    if (track <= 0 || size.width < thickness + margin) return null;
    final viewport = m.viewportDimension;
    final length = (track * viewport / (range + viewport))
        .clamp(
          math.min(AlwaysShownScrollIndicator.minThumbLength, track),
          track,
        )
        .toDouble();
    var t = ((m.pixels - m.minScrollExtent) / range).clamp(0.0, 1.0);
    if (m.axisDirection == AxisDirection.up) t = 1 - t;
    return Rect.fromLTWH(
      size.width - thickness - margin,
      margin + (track - length) * t,
      thickness,
      length,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = thumbRectFor(metrics.value, size);
    if (rect == null) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        const Radius.circular(AlwaysShownScrollIndicator.thickness / 2),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(ScrollIndicatorPainter old) =>
      old.metrics != metrics || old.color != color;
}
