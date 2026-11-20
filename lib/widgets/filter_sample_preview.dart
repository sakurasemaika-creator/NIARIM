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
/// choosing a filter by its look. The filter is run on Moonlit Valley or on
/// its linework or foreground layers, depending on the filter. Opaque RGBA,
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

/// Every card uses the same scene. Filters that need a transparent input, a
/// background, or a selection use the corresponding part of the illustration.
_Sample _sampleFor(FilterKind kind) {
  const w = kFilterSampleWidth, h = kFilterSampleHeight;
  final valley = _Raster(w, h);
  _paintValley(valley);

  switch (kind) {
    case FilterKind.inkPool:
    case FilterKind.autoLineart:
      _paintMoonAndBirds(valley);
      final lines = _Raster(w, h);
      // The upper ridges supply both sharp corners and intersecting slopes.
      for (final (points, _) in _valleyRidges.take(2)) {
        if (kind == FilterKind.inkPool) {
          lines.stroke(points, 1.6, 0xFF342A3E);
        } else {
          for (final dy in [-.9, 0.0, .9]) {
            lines.stroke(
              [for (final point in points) point.translate(0, dy)],
              1.2,
              0xB0342A3E,
            );
          }
        }
      }
      return (data: lines.rgba, background: valley.rgba, mask: null);
    case FilterKind.prism:
    case FilterKind.backgroundBlend:
    case FilterKind.outline:
    case FilterKind.watercolorBorder:
      final foreground = _Raster(w, h);
      _paintMoonAndBirds(foreground);
      // Prism adds light to the painted moon and birds beneath it.
      if (kind == FilterKind.prism) _paintMoonAndBirds(valley);
      return (data: foreground.rgba, background: valley.rgba, mask: null);
    default:
      _paintMoonAndBirds(valley);
      final mask = kind == FilterKind.lensDistortion
          ? (_Raster(w, h)..disc(_moonCenter, 15, 0xFFFFFFFF)).rgba
          : null;
      return (data: valley.rgba, background: null, mask: mask);
  }
}

const _moonCenter = Offset(93.8, 26.1);
const _moonRadius = 10.0;
const _moonlight = 0xFFFFE4A9;
const _moonShadow = 0xFF645274;

/// Moonlit Valley, traced from the unmarked reference at thumbnail width.
/// The extra height of the card continues the sky and foreground evenly.
void _paintValley(_Raster art) {
  for (var y = 0; y < art.height; y++) {
    final t = ((y - 4.85) / 52).clamp(0.0, 1.0);
    final color = _lerpColor(0xFF232B50, 0xFFB17489, t);
    for (var x = 0; x < art.width; x++) {
      art.set(x, y, color);
    }
  }
  const starlight = 0xFFF7DCE5;
  for (final star in _brightStars) {
    art.disc(star, .72, starlight);
  }
  for (final star in _smallStars) {
    art.disc(star, .43, starlight);
  }
  for (final (points, color) in _valleyRidges) {
    art.fillBelow(points, color);
  }
}

void _paintMoonAndBirds(_Raster art) {
  final shadowCenter = _moonCenter.translate(3.9, -2.1);
  final left = (_moonCenter.dx - _moonRadius).floor();
  final right = (_moonCenter.dx + _moonRadius).ceil();
  final top = (_moonCenter.dy - _moonRadius).floor();
  final bottom = (_moonCenter.dy + _moonRadius).ceil();
  for (var y = top; y <= bottom; y++) {
    for (var x = left; x <= right; x++) {
      final point = Offset(x + .5, y + .5);
      final diskCoverage = _moonRadius + .5 - (point - _moonCenter).distance;
      final shadow = (9.15 + .5 - (point - shadowCenter).distance).clamp(
        0.0,
        1.0,
      );
      // Both colours share the same outer edge of the lunar disk.
      art._over(
        x,
        y,
        _lerpColor(_moonlight, _moonShadow, shadow),
        diskCoverage,
      );
    }
  }
  for (final bird in const [
    Offset(31.9, 53.6),
    Offset(35.3, 56.8),
    Offset(39.1, 52.8),
    Offset(44.2, 49.2),
  ]) {
    art.stroke(
      [
        bird.translate(-1.1, -.2),
        bird.translate(.2, .5),
        bird.translate(1.1, -.8),
      ],
      .55,
      _moonlight,
    );
  }
}

const _brightStars = [
  Offset(24.0, 6.4),
  Offset(122.2, 9.4),
  Offset(69.5, 13.2),
  Offset(36.4, 13.7),
  Offset(44.9, 15.8),
  Offset(77.5, 16.0),
  Offset(29.4, 18.1),
  Offset(66.9, 18.6),
  Offset(113.5, 23.8),
  Offset(51.9, 24.4),
  Offset(115.3, 28.9),
  Offset(130.3, 29.2),
  Offset(49.3, 34.1),
  Offset(74.9, 34.6),
  Offset(1.9, 35.0),
  Offset(68.6, 35.7),
  Offset(31.5, 39.3),
  Offset(27.7, 41.1),
  Offset(26.1, 43.2),
  Offset(9.6, 43.7),
];

const _smallStars = [
  Offset(48.3, 5.1),
  Offset(119.3, 6.1),
  Offset(96.8, 7.8),
  Offset(83.9, 8.9),
  Offset(11.8, 9.9),
  Offset(95.4, 10.9),
  Offset(69.0, 12.0),
  Offset(121.0, 12.5),
  Offset(22.5, 13.2),
  Offset(12.2, 13.9),
  Offset(59.0, 15.0),
  Offset(73.0, 17.2),
  Offset(18.6, 18.1),
  Offset(74.0, 18.6),
  Offset(115.3, 23.0),
  Offset(69.1, 23.0),
  Offset(65.8, 24.0),
  Offset(115.8, 24.9),
  Offset(35.9, 26.1),
  Offset(28.4, 26.3),
  Offset(108.7, 26.4),
  Offset(2.1, 30.3),
  Offset(120.3, 30.4),
  Offset(54.7, 30.4),
  Offset(52.6, 30.8),
  Offset(59.6, 30.8),
  Offset(25.8, 32.4),
  Offset(82.0, 32.5),
  Offset(17.8, 33.1),
  Offset(104.6, 33.9),
  Offset(113.4, 36.4),
  Offset(11.3, 39.3),
  Offset(64.8, 40.5),
  Offset(61.5, 40.9),
  Offset(5.9, 42.3),
  Offset(10.3, 42.3),
  Offset(28.0, 44.2),
];

const _valleyRidges = [
  (
    [
      Offset(0, 55.6),
      Offset(17.9, 41),
      Offset(28.2, 47),
      Offset(41.6, 32.7),
      Offset(59.6, 47.7),
      Offset(74, 38.3),
      Offset(90.3, 50.5),
      Offset(109.5, 33.6),
      Offset(132, 53),
    ],
    0xFF8D648A,
  ),
  (
    [
      Offset(0, 58.4),
      Offset(19.5, 49.6),
      Offset(32.2, 54.1),
      Offset(50.4, 44),
      Offset(69.1, 53),
      Offset(80.1, 47.7),
      Offset(104, 58),
      Offset(119.5, 49.4),
      Offset(132, 56.6),
    ],
    0xFF535074,
  ),
  (
    [
      Offset(0, 64.5),
      Offset(12.2, 60.8),
      Offset(32, 64.5),
      Offset(46.3, 53.1),
      Offset(59.2, 61.2),
      Offset(76.5, 57),
      Offset(88.3, 63.9),
      Offset(100.7, 58),
      Offset(132, 64.2),
    ],
    0xFF363754,
  ),
  (
    [
      Offset(0, 70.4),
      Offset(26.2, 72),
      Offset(45, 66.1),
      Offset(56.4, 68.9),
      Offset(75.4, 64),
      Offset(90.6, 70.4),
      Offset(117, 67.1),
      Offset(132, 70.8),
    ],
    0xFF232B45,
  ),
];

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

  /// Fills below a left-to-right ridge spanning the raster. Four subpixel
  /// samples per column smooth the silhouette against the layer behind it.
  void fillBelow(List<Offset> ridge, int color) {
    var segment = 0;
    final edge = Float64List(4);
    for (var x = 0; x < width; x++) {
      for (var sample = 0; sample < edge.length; sample++) {
        final px = x + (sample + .5) / edge.length;
        while (px > ridge[segment + 1].dx) {
          segment++;
        }
        final a = ridge[segment], b = ridge[segment + 1];
        edge[sample] = a.dy + (b.dy - a.dy) * (px - a.dx) / (b.dx - a.dx);
      }
      final top = edge.reduce(math.min).floor();
      final bottom = edge.reduce(math.max).ceil();
      for (var y = top; y < bottom; y++) {
        var coverage = 0.0;
        for (final edgeY in edge) {
          coverage += (y + 1 - edgeY).clamp(0.0, 1.0);
        }
        _over(x, y, color, coverage / edge.length);
      }
      for (var y = bottom; y < height; y++) {
        set(x, y, color);
      }
    }
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
