import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/font_fallback.dart';
import '../models/brush.dart';
import '../models/stamp.dart';
import '../models/tone.dart';
import '../utils/line_break.dart';
import 'action_beside_or_below.dart';
import 'docked_panel_scope.dart';
import 'keep_together_text.dart';
import 'stroke_sample_preview.dart';

/// 字の間で折り返せる日本語・中国語の字（かな・漢字）。
final RegExp _cjk = RegExp(
  r'[\u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]',
);

/// Identical two-line row for the brush, tone and stamp catalogues and
/// their quick-select tabs. Action buttons and drag handles are supplied
/// by each owner and never displaced by the full-width stroke sample.
class PresetStrokeRow extends StatelessWidget {
  const PresetStrokeRow({
    super.key,
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.brush,
    this.tone,
    this.stamp,
    this.semanticsLabel,
    this.trailing,
  }) : assert(
         (brush != null ? 1 : 0) +
                 (tone != null ? 1 : 0) +
                 (stamp != null ? 1 : 0) ==
             1,
       );

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Brush? brush;
  final Tone? tone;
  final Stamp? stamp;
  final String? semanticsLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    final style = TextStyle(
      fontSize: 12,
      fontFamily: headingFontFamilyFor(locale),
      fontFamilyFallback: headingFontFallbackFor(locale),
    );
    // 名前は2行まで折り返してから「…」で切る（狭いドック・大きな文字で
    // 「三角形」が「三…」と1字で切れた）。ただし行に入らない語がある名前と、
    // 1行に2字も入らない狭い行（折り返すと1字ずつ縦に並ぶ）は、1行で「…」に
    // する。折り返すときは、長音符・小さいかな・閉じ括弧で行を始めない
    // （「カリグラフィ / ー」にしない。日本語の行頭禁則）。
    final shown = KeepTogetherText(
      name,
      keep: lineStartKeepParts(name),
      style: style,
    );
    final title = LayoutBuilder(
      builder: (context, constraints) {
        final merged = DefaultTextStyle.of(context).style.merge(style);
        final painter = TextPainter(
          text: shown.joinedSpan(merged),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
          maxLines: 2,
        )..layout(maxWidth: constraints.maxWidth);
        // 折り返して並べた後の最小の固有幅は、いちばん広い語の幅。ただし
        // Flutter（SkParagraph）は、日本語・中国語の文が1つの書体で描けて途中に
        // 空白が無いと文全体を1つの語と数える。字の間で折り返せるので、1pxの
        // 幅で並べ直して数え直す（欧文の語・数は1つのまま数える）。
        var widest = painter.minIntrinsicWidth;
        if (_cjk.hasMatch(name)) {
          painter
            ..maxLines = null
            ..layout(maxWidth: 1);
          widest = math.min(widest, painter.minIntrinsicWidth);
        }
        // 行頭禁則でつないだ字（「フィー」）・数と単位は、1つのまま数える
        // （1pxで並べ直した最小の固有幅は、つないだ字の間でも折れるものと
        // して数え、入らないかたまりを字の途中で折った）。
        for (final part in shown.keptParts()) {
          painter
            ..text = TextSpan(text: part, style: merged)
            ..maxLines = null
            ..layout();
          widest = math.max(widest, painter.width);
        }
        final wordBreaks = widest > constraints.maxWidth + 0.5;
        painter.dispose();
        final twoCharacters = 2 * MediaQuery.textScalerOf(context).scale(12);
        final wraps = !wordBreaks && constraints.maxWidth >= twoCharacters;
        return DefaultTextStyle.merge(
          maxLines: wraps ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          child: shown,
        );
      },
    );
    final label = semanticsLabel == null
        ? title
        : Semantics(label: semanticsLabel, child: title);
    final dockActions = DockedPanelScope.of(context) ? trailing : null;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsetsDirectional.fromSTEB(6, 2, 6, 2),
      selected: selected,
      title: Padding(
        // Shift names slightly higher and separate all three asset samples.
        padding: const EdgeInsets.only(bottom: 6),
        child: dockActions == null
            ? label
            : ActionBesideOrBelow(
                text: label,
                action: dockActions,
                // 名前のいちばん広い語が横の幅に入らない行だけ、操作を名前の
                // 下へ回す（狭いドックで「Cuadrado redondeado」が1行の「…」に
                // 切れた）。
                minTextWidth: math.max(
                  MediaQuery.textScalerOf(context).scale(72),
                  _widestWord(context, shown, style),
                ),
                gap: 8,
              ),
      ),
      subtitle: StrokeSamplePreview(
        brush: brush,
        tone: tone,
        stamp: stamp,
        color: color,
      ),
      trailing: dockActions == null ? trailing : null,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

/// [shown]の名前の、行の途中で折れないいちばん広いかたまりの幅（欧文の語、
/// 行頭禁則でつないだ字、数と単位）。日本語・中国語の字の間は折れるので
/// 1字ずつ数える。
double _widestWord(
  BuildContext context,
  KeepTogetherText shown,
  TextStyle style,
) {
  final merged = DefaultTextStyle.of(context).style.merge(style);
  final painter = TextPainter(
    text: shown.joinedSpan(merged),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
  )..layout();
  var widest = painter.minIntrinsicWidth;
  if (_cjk.hasMatch(shown.data ?? '')) {
    painter.layout(maxWidth: 1);
    widest = math.min(widest, painter.minIntrinsicWidth);
  }
  for (final part in shown.keptParts()) {
    painter
      ..text = TextSpan(text: part, style: merged)
      ..layout();
    widest = math.max(widest, painter.width);
  }
  painter.dispose();
  return widest;
}
