import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/blend_math.dart';
import '../models/layer.dart';

/// The size of a blend mode preview's picture, in pixels.
const int kBlendPreviewWidth = 100;
const int kBlendPreviewHeight = 60;

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
const int _band = 8;

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
