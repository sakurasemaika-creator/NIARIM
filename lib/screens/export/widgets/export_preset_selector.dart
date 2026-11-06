import 'package:flutter/material.dart';
import '../../../config/font_fallback.dart';
import '../../../models/export_preset.dart';
import '../../../l10n/app_localizations.dart';

/// Keep the three choices inline only when their full scaled labels fit.
class ExportPresetSelector extends StatelessWidget {
  const ExportPresetSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ExportPreset value;
  final ValueChanged<ExportPreset> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final labels = <ExportPreset, String>{
      ExportPreset.standard: l10n.exportPresetStandard,
      ExportPreset.highQuality: l10n.exportPresetHighQuality,
      ExportPreset.custom: l10n.exportPresetCustom,
    };
    final textStyle =
        (theme.segmentedButtonTheme.style?.textStyle?.resolve({}) ??
                theme.textTheme.labelLarge ??
                const TextStyle(fontSize: 14))
            .copyWith(
              fontFamily: 'Kuramubon',
              fontFamilyFallback: kHeadingFontFallback,
            );
    final measureStyle = MediaQuery.boldTextOf(context)
        ? textStyle.copyWith(fontWeight: FontWeight.bold)
        : textStyle;
    var requiredWidth = 0.0;
    final labelWidths = <String, double>{};
    for (final label in labels.values) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: measureStyle),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
        locale: Localizations.localeOf(context),
      )..layout();
      // Reserve padding and the selection glyph in every segment so changing
      // the selected value never makes another label wrap inside a word.
      final allSegmentsWidth = (painter.width + 64) * labels.length;
      if (allSegmentsWidth > requiredWidth) requiredWidth = allSegmentsWidth;
      labelWidths[label] = painter.width;
      painter.dispose();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= requiredWidth) {
          return SegmentedButton<ExportPreset>(
            key: const Key('exportPresetSegments'),
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(48, 48)),
              visualDensity: VisualDensity.standard,
            ),
            segments: [
              for (final entry in labels.entries)
                ButtonSegment(
                  value: entry.key,
                  label: Text(
                    entry.value,
                    style: const TextStyle(
                      fontFamily: 'Kuramubon',
                      fontFamilyFallback: kHeadingFontFallback,
                    ),
                  ),
                ),
            ],
            selected: {value},
            onSelectionChanged: (values) => onChanged(values.first),
          );
        }
        final foreground =
            theme.popupMenuTheme.textStyle?.color ??
            theme.colorScheme.onSurface;
        final surface =
            theme.popupMenuTheme.color ?? theme.colorScheme.surfaceContainer;
        Widget content(String label, IconData? glyph) {
          final text = Text(
            label,
            style: textStyle.copyWith(color: foreground),
          );
          if (glyph == null) return text;
          final icon = Icon(glyph, color: foreground);
          if (labelWidths[label]! + 32 <= constraints.maxWidth - 16) {
            return Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: 8),
                icon,
              ],
            );
          }
          // A long single word keeps the full field width; the affordance
          // moves below it rather than splitting or shrinking the chosen font.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              text,
              Align(alignment: Alignment.centerRight, child: icon),
            ],
          );
        }

        return PopupMenuButton<ExportPreset>(
          key: const Key('exportPresetMenu'),
          borderRadius: BorderRadius.circular(18),
          tooltip: l10n.exportPresetSection,
          initialValue: value,
          onSelected: onChanged,
          constraints: BoxConstraints.tightFor(width: constraints.maxWidth),
          itemBuilder: (_) => [
            for (final entry in labels.entries)
              PopupMenuItem<ExportPreset>(
                key: ValueKey('exportPresetOption-${entry.key.name}'),
                value: entry.key,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: content(
                  entry.value,
                  entry.key == value ? Icons.check : null,
                ),
              ),
          ],
          child: Ink(
            decoration: ShapeDecoration(
              color: surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: foreground.withValues(alpha: 0.35)),
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: content(labels[value]!, Icons.expand_more),
              ),
            ),
          ),
        );
      },
    );
  }
}
