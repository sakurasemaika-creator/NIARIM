import 'dart:io';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/brush.dart';
import '../../../widgets/editable_slider_value.dart';
import '../../../widgets/stepped_slider.dart';

/// Every tip option is shared by built-in and user-created brush definitions.
class BrushTipSettings extends StatelessWidget {
  final Brush brush;
  final ValueChanged<Brush> onChanged;
  final VoidCallback onAddImages;
  const BrushTipSettings({
    super.key,
    required this.brush,
    required this.onChanged,
    required this.onAddImages,
  });

  Widget _number(
    String title,
    double value,
    double min,
    double max,
    ValueChanged<double> change, {
    String suffix = '%',
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: Text(title)),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: EditableSliderValue(
              text: '${value.round()}$suffix',
              value: value,
              min: min,
              max: max,
              title: title,
              onChanged: (v) => change(v.toDouble()),
            ),
          ),
        ],
      ),
      SteppedSlider(
        value: value,
        min: min,
        max: max,
        step: 1,
        onChanged: change,
      ),
    ],
  );

  void _setImages(List<String> paths) => onChanged(
    brush.copyWith(customImagePaths: paths, clearCustomImages: paths.isEmpty),
  );
  void _move(int index, int delta) {
    final paths = brush.resolvedCustomImagePaths.toList();
    final path = paths.removeAt(index);
    paths.insert(index + delta, path);
    _setImages(paths);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final shapes = {
      BrushTipShape.round: l.brushTipRound,
      BrushTipShape.hollowSquare: l.brushTipSquare,
      BrushTipShape.hexagon: l.brushTipHexagon,
      BrushTipShape.chainLink: l.brushTipChain,
      BrushTipShape.ballChain: l.brushTipBallChain,
    };
    final inks = {
      BrushImageInkMode.dark: l.brushImageInkDark,
      BrushImageInkMode.light: l.brushImageInkLight,
      BrushImageInkMode.alpha: l.brushImageInkAlpha,
    };
    final paths = brush.resolvedCustomImagePaths;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<BrushTipShape>(
          key: ValueKey('tip-shape-${brush.tipShape.name}'),
          decoration: InputDecoration(labelText: l.brushTipShapeLabel),
          initialValue: brush.tipShape,
          items: [
            for (final entry in shapes.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: (value) {
            if (value != null) onChanged(brush.copyWith(tipShape: value));
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.brushTipRelativeSpacing),
          value: brush.tipSpacingFactor > 0,
          onChanged: (enabled) =>
              onChanged(brush.copyWith(tipSpacingFactor: enabled ? 1 : 0)),
        ),
        if (brush.tipSpacingFactor > 0)
          _number(
            l.brushTipSpacingRatio,
            brush.tipSpacingFactor * 100,
            1,
            400,
            (v) => onChanged(brush.copyWith(tipSpacingFactor: v / 100)),
          ),
        if (brush.tipShape == BrushTipShape.chainLink) ...[
          _number(
            l.brushChainAspect,
            brush.chainAspect * 100,
            10,
            100,
            (v) => onChanged(brush.copyWith(chainAspect: v / 100)),
          ),
          _number(
            l.brushChainThickness,
            brush.chainThickness * 100,
            5,
            90,
            (v) => onChanged(brush.copyWith(chainThickness: v / 100)),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.brushNibFlat),
          value: brush.calligraphyAngle != null,
          onChanged: (enabled) => onChanged(
            brush.copyWith(
              calligraphyAngle: enabled ? 0 : null,
              clearCalligraphyAngle: !enabled,
            ),
          ),
        ),
        if (brush.calligraphyAngle != null)
          _number(
            l.brushNibAngle,
            brush.calligraphyAngle!,
            0,
            359,
            (v) => onChanged(brush.copyWith(calligraphyAngle: v)),
            suffix: '°',
          ),
        const Divider(),
        OutlinedButton.icon(
          onPressed: onAddImages,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(l.brushImagesAdd),
        ),
        for (var i = 0; i < paths.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xff9e9e9e),
                borderRadius: BorderRadius.circular(4),
              ),
              clipBehavior: Clip.antiAlias,
              child: paths[i].startsWith('assets/')
                  ? Image.asset(
                      paths[i],
                      fit: BoxFit.contain,
                      errorBuilder: (_, error, stack) =>
                          const Icon(Icons.broken_image_outlined),
                    )
                  : Image.file(
                      File(paths[i]),
                      fit: BoxFit.contain,
                      errorBuilder: (_, error, stack) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
            ),
            title: Text(
              '${i + 1}. ${paths[i].split('/').last}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: l.brushImageMoveUp,
                  onPressed: i > 0 ? () => _move(i, -1) : null,
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  tooltip: l.brushImageMoveDown,
                  onPressed: i + 1 < paths.length ? () => _move(i, 1) : null,
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  tooltip: l.brushImageRemove,
                  onPressed: () => _setImages(paths.toList()..removeAt(i)),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        if (paths.isNotEmpty) ...[
          DropdownButtonFormField<BrushImageInkMode>(
            key: ValueKey('image-ink-${brush.imageInkMode.name}'),
            decoration: InputDecoration(labelText: l.brushImageInkLabel),
            initialValue: brush.imageInkMode,
            items: [
              for (final entry in inks.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) {
              if (value != null) onChanged(brush.copyWith(imageInkMode: value));
            },
          ),
          const SizedBox(height: 8),
          Text(
            l.brushImageInkHelp,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<BrushImageSelectionMode>(
            key: ValueKey('image-order-${brush.customImageSelectionMode.name}'),
            decoration: InputDecoration(labelText: l.brushImageOrderLabel),
            initialValue: brush.customImageSelectionMode,
            items: [
              DropdownMenuItem(
                value: BrushImageSelectionMode.random,
                child: Text(l.brushImageOrderRandom),
              ),
              DropdownMenuItem(
                value: BrushImageSelectionMode.sequential,
                child: Text(l.brushImageOrderSequential),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                onChanged(brush.copyWith(customImageSelectionMode: value));
              }
            },
          ),
        ],
      ],
    );
  }
}
