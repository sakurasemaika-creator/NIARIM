import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/blend_math.dart';
import '../models/layer.dart';

/// The size of a blend mode preview's picture, in pixels: large enough to
/// stay sharp in the picker's tiles.
const int kBlendPreviewWidth = 200;
const int kBlendPreviewHeight = 120;

// Five colour swatches side by side (red, yellow, blue, white, black), each
// over a backdrop that runs from dark to light across the swatch and from
// teal at the top to orange at the bottom. The top and bottom rows show the
// backdrop alone; the lower third of the swatches is at half opacity, where
// Addition and Linear Dodge differ.
const List<(double, double, double)> _swatches = [
  (0.90, 0.20, 0.20),
  (0.95, 0.85, 0.25),
  (0.20, 0.35, 0.90),
  (1.0, 1.0, 1.0),
  (0.0, 0.0, 0.0),
];
// The backdrop-only rows at the top and bottom.
const int _band = kBlendPreviewHeight * 2 ~/ 15;

/// The preview picture of [mode] as RGBA (opaque, so premultiplied and
/// straight are the same): a layer in that mode over a backdrop, drawn with
/// the formulas the layer compositor uses ([blendRgbOver]).
Uint8List blendModePreviewPixels(LayerBlendMode mode) {
  const w = kBlendPreviewWidth, h = kBlendPreviewHeight;
  final out = Uint8List(w * h * 4);
  final mixed = Float64List(3);
  final segment = w / _swatches.length;
  const top = _band, bottom = h - _band;
  final halfFrom = top + ((bottom - top) * 2 / 3).round();
  for (var y = 0; y < h; y++) {
    final v = y / (h - 1);
    for (var x = 0; x < w; x++) {
      final index = (x / segment).floor().clamp(0, _swatches.length - 1);
      final t = (x - index * segment) / (segment - 1);
      // Dark to light across the swatch, teal to orange down the picture.
      final grey = 0.08 + 0.84 * t.clamp(0.0, 1.0);
      final br = grey * (0.55 + 0.45 * (0.25 + 0.75 * v));
      final bg = grey * (0.55 + 0.45 * (0.85 - 0.35 * v));
      final bb = grey * (0.55 + 0.45 * (0.95 - 0.8 * v));
      var r = br, g = bg, b = bb;
      if (y >= top && y < bottom) {
        final (sr, sg, sb) = _swatches[index];
        blendRgbOver(
          mode,
          br,
          bg,
          bb,
          sr,
          sg,
          sb,
          y >= halfFrom ? 0.5 : 1.0,
          mixed,
        );
        r = mixed[0];
        g = mixed[1];
        b = mixed[2];
      }
      final i = (y * w + x) * 4;
      out[i] = (r.clamp(0.0, 1.0) * 255).round();
      out[i + 1] = (g.clamp(0.0, 1.0) * 255).round();
      out[i + 2] = (b.clamp(0.0, 1.0) * 255).round();
      out[i + 3] = 255;
    }
  }
  return out;
}

final Map<LayerBlendMode, Future<ui.Image>> _previews = {};

/// [blendModePreviewPixels] as an image, made once per mode.
Future<ui.Image> blendModePreviewImage(LayerBlendMode mode) =>
    _previews.putIfAbsent(mode, () {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        blendModePreviewPixels(mode),
        kBlendPreviewWidth,
        kBlendPreviewHeight,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      return completer.future;
    });

/// A small picture of what a layer in [mode] does to what lies beneath it,
/// for choosing a blend mode by its look.
class BlendModePreview extends StatelessWidget {
  final LayerBlendMode mode;
  final double width;
  final double height;

  const BlendModePreview(
    this.mode, {
    super.key,
    this.width = 60,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<ui.Image>(
        future: blendModePreviewImage(mode),
        builder: (context, snapshot) {
          final image = snapshot.data;
          if (image == null) return const SizedBox.expand();
          return RawImage(
            image: image,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
          );
        },
      ),
    );
  }
}

/// The blend modes as a grid of two columns, each mode's name above a large
/// picture of its look, [current] marked (and scrolled into view). Returns
/// the chosen mode, or null when closed without choosing.
Future<LayerBlendMode?> showBlendModePicker(
  BuildContext context, {
  required LayerBlendMode current,
  required String title,
  required String Function(LayerBlendMode mode) label,
}) {
  return showDialog<LayerBlendMode>(
    context: context,
    builder: (ctx) {
      final screen = MediaQuery.sizeOf(ctx);
      const spacing = 8.0, padding = 6.0;
      final width = math.min(screen.width - 56, 460.0);
      final tile = (width - spacing) / 2;
      final picture =
          (tile - padding * 2) * kBlendPreviewHeight / kBlendPreviewWidth;
      final name = MediaQuery.textScalerOf(ctx).scale(13) * 2.7;
      final extent = padding * 2 + name + 4 + picture;
      const modes = LayerBlendMode.values;
      final row = modes.indexOf(current) ~/ 2;
      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        // popup-standard-close: タイトル行の右端へ寄せた閉じるボタン。
        // AlertDialogの`icon:`スロットへ入れると、Flutterが
        // タイトルを強制的に中央寄せにするため（dialog.dartの
        // `textAlign: icon == null ? TextAlign.start : TextAlign.center`）、
        // 他のダイアログと不揃いになる。タイトル行へ直接置くこと。
        title: Row(
          children: [
            Expanded(child: Text(title)),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: width,
          height: math.min(screen.height * .62, 640.0),
          child: GridView.builder(
            key: const ValueKey('blend-mode-picker-grid'),
            controller: ScrollController(
              initialScrollOffset: math.max(0, (row - 1) * (extent + spacing)),
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              mainAxisExtent: extent,
            ),
            itemCount: modes.length,
            itemBuilder: (ctx, i) {
              final mode = modes[i];
              final selected = mode == current;
              final scheme = Theme.of(ctx).colorScheme;
              return Material(
                key: ValueKey('blend-mode-tile-${mode.name}'),
                color: selected
                    ? scheme.primaryContainer.withValues(alpha: .45)
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.of(ctx).pop(mode),
                  child: Padding(
                    padding: const EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: name,
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              label(mode),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        BlendModePreview(
                          mode,
                          width: tile - padding * 2,
                          height: picture,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
}
