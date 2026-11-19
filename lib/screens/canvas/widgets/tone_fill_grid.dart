import 'package:flutter/material.dart';

import '../../../models/tone.dart';
import '../../../widgets/tone_preview_thumb.dart';

/// The bucket and lasso use the same full-area samples of the fill texture.
class SliverToneFillGrid extends StatelessWidget {
  const SliverToneFillGrid({
    super.key,
    required this.tones,
    required this.selectedId,
    required this.labelOf,
    required this.onSelected,
  });

  final List<Tone> tones;
  final String? selectedId;
  final String Function(Tone) labelOf;
  final ValueChanged<Tone> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        sliver: SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.crossAxisExtent < 340 ? 3 : 4,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            mainAxisExtent: 68 + MediaQuery.textScalerOf(context).scale(28),
          ),
          itemCount: tones.length,
          itemBuilder: (context, index) {
            final tone = tones[index];
            final selected = selectedId == tone.id;
            return Semantics(
              selected: selected,
              button: true,
              child: Material(
                color: selected ? scheme.primaryContainer : scheme.surface,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                    width: selected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('fill-tone-${tone.id}'),
                  onTap: () => onSelected(tone),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        Expanded(
                          child: SizedBox.expand(
                            child: TonePreviewThumb(
                              tone: tone,
                              color: scheme.onSurface,
                              background: scheme.surface,
                              shape: BoxShape.rectangle,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          labelOf(tone),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
