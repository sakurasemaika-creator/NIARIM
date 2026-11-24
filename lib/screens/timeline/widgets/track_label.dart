import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../config/font_fallback.dart';
import '../../../utils/line_break.dart';
import '../../../widgets/action_beside_or_below.dart';

/// タイムラインの行の名前の欄（左端の印＋名前）の寸法と幅の決め方。
///
/// 欄の幅はいつもの94dpから始め、この言語の決まった行の名前（フレーム・
/// カメラ・読み上げ・素材の種類・エンドマーク・演出フィルターの種類）が
/// どれも語の途中で折れず、2行までに入るところまで広げる。以前は94dpの
/// 1行に「…」で切っていて、英語の読み上げの行が「Text to s…」、
/// スペイン語が「Texto a v…」、フランス語が「Synthès…」になっていた。
abstract final class TrackLabelMetrics {
  static const double baseWidth = 94;
  static const double fontSize = 11;

  /// 2行にしたときの行の高さ。くらむぼんは字が行の外へはみ出すので、
  /// 1.0のままだと2行目の字が1行目に触れる。
  static const double lineHeight = 1.15;
  static const double horizontalPadding = 3;
  static const double iconSize = 14;
  static const double iconGap = 4;
  static const double chrome = horizontalPadding * 2 + iconSize + iconGap;

  /// 文字を大きくする設定でも、タイムラインの行を押しつぶさない上限。
  /// これを超える名前は、入る行数で「…」にする。
  static const double maxWidth = 168;

  static TextStyle style(Locale? locale, Color color) => headingStyleFor(
    locale,
    TextStyle(fontSize: fontSize, height: lineHeight, color: color),
  );

  static final Map<(String, double, String), double> _widthCache = {};

  /// [fixedLabels]がどれも語の途中で折れず、2行までに入る欄の幅。
  static double columnWidth({
    required Locale? locale,
    required TextScaler textScaler,
    required List<String> fixedLabels,
  }) {
    final key = (
      locale?.toLanguageTag() ?? '',
      textScaler.scale(fontSize),
      fixedLabels.join('\u0000'),
    );
    final cached = _widthCache[key];
    if (cached != null) return cached;
    final textStyle = style(locale, const Color(0xFF000000));
    TextPainter painterFor(String label) => TextPainter(
      text: TextSpan(text: keepKoreanWordsTogether(label), style: textStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    );

    final maxText = maxWidth - chrome;
    var textWidth = baseWidth - chrome;
    for (final label in fixedLabels) {
      final painter = painterFor(label)..layout();
      final widest = widestUnbreakableWidth(
        painter,
        reported: painter.minIntrinsicWidth,
      );
      painter.dispose();
      textWidth = math.max(textWidth, widest.ceilToDouble());
    }
    for (final label in fixedLabels) {
      while (textWidth < maxText) {
        final painter = painterFor(label)..layout(maxWidth: textWidth);
        final lines = painter.computeLineMetrics().length;
        painter.dispose();
        if (lines <= 2) break;
        textWidth += 4;
      }
    }
    final width = math.min(maxWidth, textWidth + chrome);
    if (_widthCache.length > 32) _widthCache.clear();
    return _widthCache[key] = width;
  }
}

/// タイムラインの行の名前。行の高さに入るだけ（多くて2行）折り返し、
/// 語の途中では折らない。利用者が付けた長い名前（行の名前・レイヤー名・
/// 演出フィルター名）は入る行の終わりで「…」にする。
class TrackLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final double width;

  const TrackLabel({
    super.key,
    required this.icon,
    required this.label,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final locale = Localizations.maybeLocaleOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
        horizontal: TrackLabelMetrics.horizontalPadding,
      ),
      child: Row(
        children: [
          Icon(icon, size: TrackLabelMetrics.iconSize, color: color),
          const SizedBox(width: TrackLabelMetrics.iconGap),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final lineExtent =
                    textScaler.scale(TrackLabelMetrics.fontSize) *
                    TrackLabelMetrics.lineHeight;
                final lines = constraints.maxHeight.isFinite
                    ? (constraints.maxHeight / lineExtent).floor().clamp(1, 2)
                    : 2;
                final shown = keepKoreanWordsTogether(label);
                return Text(
                  shown,
                  maxLines: lines,
                  overflow: TextOverflow.ellipsis,
                  style: TrackLabelMetrics.style(locale, color),
                  // 語結合子を挟んだときだけ、読み上げには元の名前を渡す。
                  semanticsLabel: shown == label ? null : label,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
