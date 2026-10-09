import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../engine/blend_math.dart';
import '../engine/filter_preview.dart';
import '../models/filter_def.dart';
import '../models/layer.dart';

/// The size of a filter's sample picture, in pixels.
const int kFilterSampleWidth = 132;
const int kFilterSampleHeight = 84;

/// The canvas the sample stands for: settings measured in canvas pixels
/// (blur radii, outline widths, dot sizes) are scaled down by its size.
const int _sampleCanvasWidth = 400;

/// A small picture of what [filter] does with its current settings, for
/// choosing a filter by its look: the filter run on a built-in sample (a
/// small character with colour swatches and a grey ramp; line art for the
/// filters that work on lines; slender leaves for プリズム; a sky behind the
/// character for 背景馴染ませ), shown on white paper. Opaque straight RGBA,
/// [kFilterSampleWidth] x [kFilterSampleHeight]. A plain function of its
/// input, so it runs in a background isolate.
Uint8List filterSamplePixels(FilterDef settings) {
  const w = kFilterSampleWidth, h = kFilterSampleHeight;
  final filter = _illustrative(settings);
  final sample = _sampleFor(filter.kind);
  final out = runFilterPreview((
    filter: filter,
    data: sample.data,
    width: w,
    height: h,
    // Line art is drawn at the sample's own size, so 墨溜まり's pools are as
    // large next to the lines as on a canvas.
    scale: filter.kind == FilterKind.inkPool ? .8 : w / _sampleCanvasWidth,
    canvasWidth: _sampleCanvasWidth,
    canvasHeight: (_sampleCanvasWidth * h / w).round(),
    mask: sample.mask,
    background: sample.background,
    frameIndex: 0,
  ));
  // On white paper, over what lies beneath, in the mode the filter leaves
  // the layer in.
  final mode = filter.kind == FilterKind.prism
      ? LayerBlendMode.linearDodge
      : LayerBlendMode.normal;
  final picture = Uint8List(w * h * 4);
  final mixed = Float64List(3);
  for (var p = 0; p < w * h; p++) {
    final i = p * 4;
    var r = 1.0, g = 1.0, b = 1.0;
    final under = sample.background;
    if (under != null) {
      final a = under[i + 3] / 255;
      r = under[i] / 255 + r * (1 - a);
      g = under[i + 1] / 255 + g * (1 - a);
      b = under[i + 2] / 255 + b * (1 - a);
    }
    final a = out[i + 3] / 255;
    if (a > 0) {
      blendRgbOver(
        mode,
        r,
        g,
        b,
        out[i] / 255 / a,
        out[i + 1] / 255 / a,
        out[i + 2] / 255 / a,
        a,
        mixed,
      );
      r = mixed[0];
      g = mixed[1];
      b = mixed[2];
    }
    picture[i] = (r.clamp(0.0, 1.0) * 255).round();
    picture[i + 1] = (g.clamp(0.0, 1.0) * 255).round();
    picture[i + 2] = (b.clamp(0.0, 1.0) * 255).round();
    picture[i + 3] = 255;
  }
  return picture;
}

/// Filters whose settings change nothing at first (トーンカーブ, レベル補正)
/// are shown with an example setting instead, so the card still tells what
/// they do.
FilterDef _illustrative(FilterDef filter) {
  switch (filter.kind) {
    case FilterKind.toneCurve
        when filter.toneCurvePreset == ToneCurvePreset.linear &&
            filter.toneCurvePoints.length < 4 &&
            filter.toneCurveRedPoints.length < 4 &&
            filter.toneCurveGreenPoints.length < 4 &&
            filter.toneCurveBluePoints.length < 4:
      return filter.copyWith(toneCurvePreset: ToneCurvePreset.highContrast);
    case FilterKind.levels
        when filter.inputBlack == 0 &&
            filter.inputWhite == 255 &&
            filter.inputGamma == 1 &&
            filter.outputBlack == 0 &&
            filter.outputWhite == 255 &&
            filter.levelsRed.length < 5 &&
            filter.levelsGreen.length < 5 &&
            filter.levelsBlue.length < 5:
      return filter.copyWith(inputBlack: 48, inputWhite: 210, inputGamma: .8);
    default:
      return filter;
  }
}

final Map<String, Future<ui.Image>> _samples = {};
Future<void> _queue = Future.value();

/// [filterSamplePixels] as an image, made once per filter and settings. The
/// samples are made one at a time in the background, so opening the filter
/// list does not start an isolate for every filter at once.
Future<ui.Image> filterSampleImage(FilterDef filter) {
  final settings = filter.toJson()
    ..remove('name')
    ..remove('isFavorite');
  final key = jsonEncode(settings);
  return _samples.putIfAbsent(key, () {
    if (_samples.length > 96) _samples.remove(_samples.keys.first);
    final done = Completer<ui.Image>();
    _queue = _queue.then((_) async {
      try {
        final pixels = await compute(filterSamplePixels, filter);
        ui.decodeImageFromPixels(
          pixels,
          kFilterSampleWidth,
          kFilterSampleHeight,
          ui.PixelFormat.rgba8888,
          done.complete,
        );
        await done.future;
      } catch (error, stack) {
        _samples.remove(key);
        if (!done.isCompleted) done.completeError(error, stack);
      }
    });
    return done.future;
  });
}

/// A filter's sample picture ([filterSampleImage]): what it does with its
/// current settings.
class FilterSamplePreview extends StatefulWidget {
  final FilterDef filter;
  final double width;
  final double height;

  const FilterSamplePreview(
    this.filter, {
    super.key,
    this.width = 66,
    this.height = 42,
  });

  @override
  State<FilterSamplePreview> createState() => _FilterSamplePreviewState();
}

class _FilterSamplePreviewState extends State<FilterSamplePreview> {
  late Future<ui.Image> _image;

  @override
  void initState() {
    super.initState();
    _image = filterSampleImage(widget.filter);
  }

  @override
  void didUpdateWidget(covariant FilterSamplePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.filter, widget.filter)) {
      _image = filterSampleImage(widget.filter);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<ui.Image>(
        future: _image,
        builder: (context, snapshot) {
          final image = snapshot.data;
          if (image == null) return const SizedBox.expand();
          return RawImage(
            image: image,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          );
        },
      ),
    );
  }
}

typedef _Sample = ({Uint8List data, Uint8List? background, Uint8List? mask});

/// The picture [kind] is shown on.
_Sample _sampleFor(FilterKind kind) {
  const w = kFilterSampleWidth, h = kFilterSampleHeight;
  switch (kind) {
    case FilterKind.inkPool:
      // Thin line art with sharp and right-angled corners.
      final art = _Raster(w, h);
      const ink = 0xFF242739;
      art.stroke([const Offset(14, 70), const Offset(40, 14)], 1.6, ink);
      art.stroke([const Offset(40, 14), const Offset(66, 70)], 1.6, ink);
      art.stroke([const Offset(24, 48), const Offset(56, 48)], 1.6, ink);
      art.stroke([const Offset(80, 18), const Offset(124, 18)], 1.6, ink);
      art.stroke([const Offset(102, 18), const Offset(102, 72)], 1.6, ink);
      art.stroke([const Offset(80, 72), const Offset(124, 72)], 1.6, ink);
      return (data: art.rgba, background: null, mask: null);
    case FilterKind.autoLineart:
      // A rough sketch: each line drawn over a few times, a little apart.
      final art = _Raster(w, h);
      const pencil = 0xB0505868;
      for (var k = 0; k < 3; k++) {
        final o = (k - 1) * 1.6;
        art.strokeCircle(Offset(46 + o, 40 - o * .5), 24 + k * .8, 1.2, pencil);
        art.stroke(
          [Offset(88, 16 + o), Offset(120, 30 - o), Offset(110, 70 + o)],
          1.2,
          pencil,
        );
      }
      return (data: art.rgba, background: null, mask: null);
    case FilterKind.prism:
      // Slender leaves of dark red over the character on grey paper.
      final leaves = _Raster(w, h);
      leaves.leaf(const Offset(18, 40), 62, 14, 12, 0xFF4D0000);
      leaves.leaf(const Offset(98, 46), 50, 11, -24, 0xFF4D0000);
      final under = _Raster(w, h)..fill(0xFFA9A5A6);
      _character(under);
      return (data: leaves.rgba, background: under.rgba, mask: null);
    case FilterKind.backgroundBlend:
      final sky = _Raster(w, h);
      for (var y = 0; y < h; y++) {
        final t = y / (h - 1);
        final c = _lerpColor(0xFF6FA8DC, 0xFFF4B26B, t);
        for (var x = 0; x < w; x++) {
          sky.set(x, y, c);
        }
      }
      final art = _Raster(w, h);
      _character(art);
      return (data: art.rgba, background: sky.rgba, mask: null);
    default:
      final art = _Raster(w, h);
      _character(art);
      Uint8List? mask;
      if (kind == FilterKind.lensDistortion) {
        // The lens over the face.
        final lens = _Raster(w, h)..disc(const Offset(52, 36), 20, 0xFFFFFFFF);
        mask = lens.rgba;
      }
      return (data: art.rgba, background: null, mask: mask);
  }
}

/// A small character on a transparent layer: hair, a face, a shirt with a
/// gradient, an outline; colour swatches and a grey ramp beside it.
void _character(_Raster art) {
  const ink = 0xFF242739;
  art.polygon([
    const Offset(30, 58),
    const Offset(74, 58),
    const Offset(86, 84),
    const Offset(18, 84),
  ], (x, y) => _lerpColor(0xFFE07AB8, 0xFF6A3FA8, ((x - 18) / 68).clamp(0, 1)));
  art.stroke(
    [
      const Offset(30, 58),
      const Offset(74, 58),
      const Offset(86, 84),
      const Offset(18, 84),
      const Offset(30, 58),
    ],
    2,
    ink,
  );
  art.disc(const Offset(52, 36), 22, 0xFFFFD8B4);
  // Hair over the top of the head, cut in a zigzag fringe.
  art.polygon([
    for (var a = 0; a <= 12; a++)
      Offset(
        52 - 23 * math.cos(math.pi * a / 12),
        34 - 23 * math.sin(math.pi * a / 12),
      ),
    const Offset(75, 38),
    const Offset(64, 30),
    const Offset(56, 37),
    const Offset(44, 28),
    const Offset(29, 38),
  ], (_, _) => 0xFF34405A);
  art.strokeCircle(const Offset(52, 36), 22, 2, ink);
  art.disc(const Offset(45, 41), 2.2, ink);
  art.disc(const Offset(59, 41), 2.2, ink);
  art.stroke(
    [const Offset(47, 49), const Offset(52, 52), const Offset(57, 49)],
    1.6,
    ink,
  );
  const swatches = [
    0xFFE84A3C,
    0xFF20B6D0,
    0xFF4CAF50,
    0xFF9C27B0,
    0xFF2E7BE6,
    0xFFF5D130,
  ];
  for (var k = 0; k < swatches.length; k++) {
    final x = 94 + (k % 2) * 12.0, y = 14 + (k ~/ 2) * 12.0;
    art.polygon([
      Offset(x, y),
      Offset(x + 11, y),
      Offset(x + 11, y + 11),
      Offset(x, y + 11),
    ], (_, _) => swatches[k]);
  }
  // A grey ramp from black to white.
  for (var y = 10; y < 78; y++) {
    final v = ((y - 10) / 67 * 255).round();
    for (var x = 122; x < 128; x++) {
      art.set(x, y, 0xFF000000 | v << 16 | v << 8 | v);
    }
  }
}

int _lerpColor(int a, int b, double t) {
  int ch(int shift) {
    final u = (a >> shift) & 0xFF, v = (b >> shift) & 0xFF;
    return (u + (v - u) * t).round().clamp(0, 255);
  }

  return ch(24) << 24 | ch(16) << 16 | ch(8) << 8 | ch(0);
}

/// A tiny anti-aliased rasteriser into premultiplied RGBA, so the samples
/// can be drawn inside the background isolate.
class _Raster {
  final int width, height;
  final Uint8List rgba;
  _Raster(this.width, this.height) : rgba = Uint8List(width * height * 4);

  void fill(int color) {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        set(x, y, color);
      }
    }
  }

  void set(int x, int y, int color) => _over(x, y, color, 1);

  /// [color] (ARGB) over the pixel, [coverage] of it.
  void _over(int x, int y, int color, double coverage) {
    if (x < 0 || y < 0 || x >= width || y >= height || coverage <= 0) return;
    final a = ((color >> 24) & 0xFF) / 255 * coverage.clamp(0.0, 1.0);
    final i = (y * width + x) * 4;
    final keep = 1 - a;
    rgba[i] = (((color >> 16) & 0xFF) * a + rgba[i] * keep).round();
    rgba[i + 1] = (((color >> 8) & 0xFF) * a + rgba[i + 1] * keep).round();
    rgba[i + 2] = ((color & 0xFF) * a + rgba[i + 2] * keep).round();
    rgba[i + 3] = (255 * a + rgba[i + 3] * keep).round();
  }

  void disc(Offset c, double r, int color) {
    for (var y = (c.dy - r - 1).floor(); y <= (c.dy + r + 1).ceil(); y++) {
      for (var x = (c.dx - r - 1).floor(); x <= (c.dx + r + 1).ceil(); x++) {
        final d = (Offset(x + .5, y + .5) - c).distance;
        _over(x, y, color, r + .5 - d);
      }
    }
  }

  void strokeCircle(Offset c, double r, double lineWidth, int color) {
    final half = lineWidth / 2;
    for (
      var y = (c.dy - r - half - 1).floor();
      y <= (c.dy + r + half + 1).ceil();
      y++
    ) {
      for (
        var x = (c.dx - r - half - 1).floor();
        x <= (c.dx + r + half + 1).ceil();
        x++
      ) {
        final d = ((Offset(x + .5, y + .5) - c).distance - r).abs();
        _over(x, y, color, half + .5 - d);
      }
    }
  }

  void stroke(List<Offset> points, double lineWidth, int color) {
    final half = lineWidth / 2;
    final xs = points.map((p) => p.dx), ys = points.map((p) => p.dy);
    final x0 = (xs.reduce(math.min) - half - 1).floor();
    final x1 = (xs.reduce(math.max) + half + 1).ceil();
    final y0 = (ys.reduce(math.min) - half - 1).floor();
    final y1 = (ys.reduce(math.max) + half + 1).ceil();
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final p = Offset(x + .5, y + .5);
        var d = double.infinity;
        for (var k = 0; k + 1 < points.length; k++) {
          d = math.min(d, _toSegment(p, points[k], points[k + 1]));
        }
        _over(x, y, color, half + .5 - d);
      }
    }
  }

  /// A filled polygon, 4 x 4 samples a pixel, coloured by [color] at each
  /// pixel.
  void polygon(List<Offset> points, int Function(double x, double y) color) {
    final xs = points.map((p) => p.dx), ys = points.map((p) => p.dy);
    for (var y = ys.reduce(math.min).floor(); y <= ys.reduce(math.max); y++) {
      for (var x = xs.reduce(math.min).floor(); x <= xs.reduce(math.max); x++) {
        var inside = 0;
        for (var sy = 0; sy < 4; sy++) {
          for (var sx = 0; sx < 4; sx++) {
            if (_inside(x + (sx + .5) / 4, y + (sy + .5) / 4, points)) {
              inside++;
            }
          }
        }
        _over(x, y, color(x.toDouble(), y.toDouble()), inside / 16);
      }
    }
  }

  /// A leaf of [length] and [breadth] at [centre], turned [degrees].
  void leaf(
    Offset centre,
    double length,
    double breadth,
    double degrees,
    int color,
  ) {
    final a = degrees * math.pi / 180;
    final along = Offset(math.sin(a), -math.cos(a));
    final across = Offset(math.cos(a), math.sin(a));
    polygon([
      for (var k = 0; k <= 16; k++)
        centre +
            along * (length / 2 * (1 - 2 * k / 16)) +
            across * (breadth / 2 * math.sin(math.pi * k / 16)),
      for (var k = 1; k < 16; k++)
        centre +
            along * (length / 2 * (-1 + 2 * k / 16)) -
            across * (breadth / 2 * math.sin(math.pi * k / 16)),
    ], (_, _) => color);
  }

  static bool _inside(double x, double y, List<Offset> polygon) {
    var crossings = 0;
    for (var k = 0; k < polygon.length; k++) {
      final a = polygon[k], b = polygon[(k + 1) % polygon.length];
      if ((a.dy <= y && b.dy > y) || (b.dy <= y && a.dy > y)) {
        final t = (y - a.dy) / (b.dy - a.dy);
        if (x < a.dx + t * (b.dx - a.dx)) crossings++;
      }
    }
    return crossings.isOdd;
  }

  static double _toSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final length = ab.distanceSquared;
    if (length == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / length).clamp(
      0.0,
      1.0,
    );
    return (p - (a + ab * t)).distance;
  }
}
