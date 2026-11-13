import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/blend_math.dart';
import '../l10n/app_localizations.dart';
import '../models/layer.dart';
import 'frame_preview_background.dart';

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

/// What the canvas would look like with the layer in a blend mode: a
/// picture of the frame, or null when it cannot be drawn.
typedef BlendModeCanvasPreview =
    Future<ui.Image?> Function(LayerBlendMode mode, int maxSize);

/// The blend modes as tiles in two columns, each mode's name above a
/// picture of its look. Tapping a tile picks the mode and, with [preview],
/// shows the canvas as it would look with the layer in it; 適用 returns the
/// picked mode (null when closed without applying). The title, the canvas
/// preview, the close button and 適用 stay put while the tiles scroll.
/// [previewBackground] (ARGB) and [previewAspectRatio] are the project's
/// background colour and picture shape, for the preview.
Future<LayerBlendMode?> showBlendModePicker(
  BuildContext context, {
  required LayerBlendMode current,
  required String title,
  required String Function(LayerBlendMode mode) label,
  BlendModeCanvasPreview? preview,
  int previewBackground = 0xFFFFFFFF,
  double previewAspectRatio = 16 / 9,
}) {
  return showDialog<LayerBlendMode>(
    context: context,
    builder: (ctx) => _BlendModePicker(
      current: current,
      title: title,
      label: label,
      preview: preview,
      previewBackground: previewBackground,
      previewAspectRatio: previewAspectRatio,
    ),
  );
}

class _BlendModePicker extends StatefulWidget {
  final LayerBlendMode current;
  final String title;
  final String Function(LayerBlendMode mode) label;
  final BlendModeCanvasPreview? preview;
  final int previewBackground;
  final double previewAspectRatio;

  const _BlendModePicker({
    required this.current,
    required this.title,
    required this.label,
    required this.preview,
    required this.previewBackground,
    required this.previewAspectRatio,
  });

  @override
  State<_BlendModePicker> createState() => _BlendModePickerState();
}

class _BlendModePickerState extends State<_BlendModePicker> {
  static const _spacing = 8.0, _padding = 6.0;

  late LayerBlendMode _picked = widget.current;
  final Map<LayerBlendMode, ui.Image> _pictures = {};
  ui.Image? _shown;
  LayerBlendMode? _loading;
  int _previewSize = 0;
  bool _disposed = false;
  ScrollController? _scroll;
  final GlobalKey _currentTile = GlobalKey();

  @override
  void dispose() {
    _disposed = true;
    for (final image in _pictures.values) {
      image.dispose();
    }
    _scroll?.dispose();
    super.dispose();
  }

  Future<void> _load(LayerBlendMode mode) async {
    final preview = widget.preview;
    if (preview == null || _previewSize <= 0) return;
    final cached = _pictures[mode];
    if (cached != null) {
      setState(() => _shown = cached);
      return;
    }
    setState(() => _loading = mode);
    final image = await preview(mode, _previewSize);
    if (_disposed) {
      image?.dispose();
      return;
    }
    if (image != null) _pictures[mode] = image;
    if (_picked != mode) return;
    setState(() {
      _loading = null;
      if (image != null) _shown = image;
    });
  }

  /// Scrolls the current mode's tile into view once it is built; when the
  /// estimate of where it lies was off (long names wrap with large text),
  /// jumps by the list's measured row height and tries again.
  void _revealCurrent([int tries = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      final tileContext = _currentTile.currentContext;
      if (tileContext != null) {
        Scrollable.ensureVisible(tileContext, alignment: .3);
        return;
      }
      final scroll = _scroll;
      if (scroll == null || !scroll.hasClients || tries >= 4) return;
      final position = scroll.position;
      const modes = LayerBlendMode.values;
      final rows = (modes.length + 1) ~/ 2;
      final rowExtent =
          (position.maxScrollExtent + position.viewportDimension) / rows;
      final row = modes.indexOf(widget.current) ~/ 2;
      scroll.jumpTo(
        (rowExtent * row - position.viewportDimension * .3).clamp(
          0,
          position.maxScrollExtent,
        ),
      );
      _revealCurrent(tries + 1);
    });
  }

  void _pick(LayerBlendMode mode) {
    setState(() => _picked = mode);
    unawaited(_load(mode));
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final scale = MediaQuery.textScalerOf(context);
    final width = math.min(screen.width - 56, 460.0);
    final tile = (width - _spacing) / 2;
    final picture =
        (tile - _padding * 2) * kBlendPreviewHeight / kBlendPreviewWidth;
    const modes = LayerBlendMode.values;
    final rows = (modes.length + 1) ~/ 2;
    final ratio =
        widget.previewAspectRatio.isFinite && widget.previewAspectRatio > 0
        ? widget.previewAspectRatio
        : 16 / 9;
    // Opened with the current mode's row in view (a little below the top).
    if (_scroll == null) {
      final rowExtent = _padding * 2 + scale.scale(13) * 1.4 + 4 + picture;
      final row = modes.indexOf(widget.current) ~/ 2;
      _scroll = ScrollController(
        initialScrollOffset: math.max(0, (row - 1) * (rowExtent + _spacing)),
      );
      _revealCurrent();
    }
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    Widget tileOf(LayerBlendMode mode) {
      final selected = mode == _picked;
      return Material(
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
          onTap: () => _pick(mode),
          child: Padding(
            padding: const EdgeInsets.all(_padding),
            // The name at the top of the tile and the picture at the bottom:
            // when the other tile of the row has a longer name, the space
            // goes between the two, never above the name.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.label(mode),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: BlendModePreview(
                    mode,
                    width: tile - _padding * 2,
                    height: picture,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget keyed(LayerBlendMode mode) {
      final tile = KeyedSubtree(
        key: ValueKey('blend-mode-tile-${mode.name}'),
        child: tileOf(mode),
      );
      return mode == widget.current
          ? KeyedSubtree(key: _currentTile, child: tile)
          : tile;
    }

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      // popup-standard-close: タイトル行の右端へ寄せた閉じるボタン。
      // AlertDialogの`icon:`スロットへ入れると、Flutterが
      // タイトルを強制的に中央寄せにするため（dialog.dartの
      // `textAlign: icon == null ? TextAlign.start : TextAlign.center`）、
      // 他のダイアログと不揃いになる。タイトル行へ直接置くこと。
      title: Row(
        children: [
          Expanded(child: Text(widget.title)),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: width,
        // The dialog's content is flexible: on a short screen this gives
        // way, and only the tiles get less room.
        height: screen.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // At most two fifths of the room, so the tiles keep the rest.
            final previewHeight = math.min(
              math.min(width / ratio, screen.height * .26),
              constraints.maxHeight * .4,
            );
            if (widget.preview != null && _previewSize == 0) {
              final dpr = MediaQuery.devicePixelRatioOf(context);
              _previewSize =
                  (math.max(previewHeight * ratio, previewHeight) * dpr)
                      .round()
                      .clamp(64, 720);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_disposed) unawaited(_load(_picked));
              });
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.preview != null) ...[
                  SizedBox(
                    key: const ValueKey('blend-mode-canvas-preview'),
                    height: previewHeight,
                    child: _CanvasPreview(
                      image: _shown,
                      loading: _loading != null,
                      background: widget.previewBackground,
                      aspectRatio: ratio,
                      caption: widget.label(_picked),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Expanded(
                  child: ListView.separated(
                    key: const ValueKey('blend-mode-picker-grid'),
                    controller: _scroll,
                    itemCount: rows,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: _spacing),
                    itemBuilder: (ctx, r) {
                      final a = modes[r * 2];
                      final b = r * 2 + 1 < modes.length
                          ? modes[r * 2 + 1]
                          : null;
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: keyed(a)),
                            const SizedBox(width: _spacing),
                            Expanded(
                              child: b == null ? const SizedBox() : keyed(b),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        FilledButton(
          key: const ValueKey('blend-mode-apply'),
          onPressed: () => Navigator.of(context).pop(_picked),
          child: Text(l10n.filterApplyButton),
        ),
      ],
    );
  }
}

/// The canvas as it would look in the picked mode, over the project's
/// background, the mode's name in a corner.
class _CanvasPreview extends StatelessWidget {
  final ui.Image? image;
  final bool loading;
  final int background;
  final double aspectRatio;
  final String caption;

  const _CanvasPreview({
    required this.image,
    required this.loading,
    required this.background,
    required this.aspectRatio,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final picture = image;
    return Container(
      decoration: BoxDecoration(
        // Around the picture, as around the canvas itself.
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FramePreviewBackground(
            backgroundColor: background,
            aspectRatio: aspectRatio,
            child: picture == null
                ? null
                : RawImage(
                    image: picture,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  caption,
                  style: TextStyle(fontSize: 12, color: scheme.onSurface),
                ),
              ),
            ),
          ),
          if (loading || picture == null)
            const Positioned(
              right: 8,
              top: 8,
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}
