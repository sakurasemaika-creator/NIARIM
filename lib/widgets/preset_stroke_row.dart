import 'package:flutter/material.dart';

import '../config/font_fallback.dart';
import '../models/brush.dart';
import '../models/stamp.dart';
import '../models/tone.dart';
import 'stroke_sample_preview.dart';

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
    final title = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 12,
        fontFamily: 'Kuramubon',
        fontFamilyFallback: kHeadingFontFallback,
      ),
    );
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsetsDirectional.fromSTEB(6, 2, 6, 2),
      selected: selected,
      title: semanticsLabel == null
          ? title
          : Semantics(label: semanticsLabel, child: title),
      subtitle: StrokeSamplePreview(
        brush: brush,
        tone: tone,
        stamp: stamp,
        color: color,
      ),
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
