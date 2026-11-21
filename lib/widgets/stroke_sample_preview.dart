import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/brush.dart';
import '../models/stamp.dart';
import '../models/tone.dart';
import '../services/shared_asset_card_preview.dart';

/// A wave drawn by the same raster engines used by the canvas.
/// The strip is read-only: it never changes the user's project.
class StrokeSamplePreview extends StatefulWidget {
  const StrokeSamplePreview({
    super.key,
    this.brush,
    this.tone,
    this.stamp,
    required this.color,
    this.height = 38,
  }) : assert(
         (brush != null ? 1 : 0) +
                 (tone != null ? 1 : 0) +
                 (stamp != null ? 1 : 0) ==
             1,
       );

  final Brush? brush;
  final Tone? tone;
  final Stamp? stamp;
  final Color color;
  final double height;

  @override
  State<StrokeSamplePreview> createState() => _StrokeSamplePreviewState();
}

class _StrokeSamplePreviewState extends State<StrokeSamplePreview> {
  ui.Image? _sample;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(StrokeSamplePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.brush != widget.brush ||
        oldWidget.tone != widget.tone ||
        oldWidget.stamp != widget.stamp ||
        oldWidget.color != widget.color) {
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    _revision++;
    _sample?.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final revision = ++_revision;
    try {
      final next = await SharedAssetCardPreview.render(
        brush: widget.brush,
        tone: widget.tone,
        stamp: widget.stamp,
        color: widget.color,
      );
      if (!mounted || revision != _revision) {
        next.dispose();
        return;
      }
      setState(() {
        _sample?.dispose();
        _sample = next;
      });
    } catch (_) {
      // An unreadable user texture must not break the tool list.
      if (mounted && revision == _revision) {
        setState(() {
          _sample?.dispose();
          _sample = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          key: ValueKey(
            widget.brush?.id ?? widget.tone?.id ?? widget.stamp?.id,
          ),
          height: widget.height,
          child: ColoredBox(
            color: scheme.surfaceContainerLow,
            child: _sample == null
                ? const SizedBox.expand()
                : RawImage(
                    image: _sample,
                    fit: BoxFit.contain,
                    // The 240px raster is normally shrunk into a narrow
                    // dock. Smooth resampling must preserve the diffuse
                    // edge of airbrush and blur presets instead of turning
                    // their soft halo into jagged opaque-looking pixels.
                    // Pixel-art brushes, stamps and dot-grid tones must
                    // remain crisp; soften only continuous-color samples.
                    filterQuality:
                        (widget.brush?.pixelMode ?? false) ||
                            (widget.stamp?.pixelMode ?? false) ||
                            (widget.tone?.name.startsWith('ピクセル') ?? false)
                        ? FilterQuality.none
                        : FilterQuality.high,
                  ),
          ),
        ),
      ),
    );
  }
}
