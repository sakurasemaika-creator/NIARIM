import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../engine/blend_math.dart';
import '../engine/filter_preview.dart';
import '../engine/moonlit_valley.dart';
import '../models/filter_def.dart';
import '../models/layer.dart';

/// The size of a filter's sample picture, in pixels.
const int kFilterSampleWidth = moonlitValleyWidth;
const int kFilterSampleHeight = moonlitValleyHeight;

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
  if (filter.isSettingsPreset) return filter;
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
    // 見本ができるまでは下地を塗らず、置かれた面（パネル）の色のまま枠だけを
    // 見せる（白で塗ると、暗いテーマでは読み込み中の白い箱が並んだ）。見本の
    // 絵は不透明なので、できたら枠の中を覆う。
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
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

/// Filters that need a transparent input, a background or a selection use
/// the corresponding layer of the same scene.
_Sample _sampleFor(FilterKind kind) {
  Uint8List draw(MoonlitValleyPart part) => moonlitValleyPixels(part: part);
  return switch (kind) {
    FilterKind.inkPool || FilterKind.autoLineart => (
      data: draw(
        kind == FilterKind.inkPool
            ? MoonlitValleyPart.ridges
            : MoonlitValleyPart.roughRidges,
      ),
      background: draw(MoonlitValleyPart.scene),
      mask: null,
    ),
    FilterKind.prism ||
    FilterKind.backgroundBlend ||
    FilterKind.outline ||
    FilterKind.watercolorBorder => (
      data: draw(MoonlitValleyPart.foreground),
      background: draw(
        kind == FilterKind.prism
            ? MoonlitValleyPart.scene
            : MoonlitValleyPart.landscape,
      ),
      mask: null,
    ),
    _ => (
      data: draw(MoonlitValleyPart.scene),
      background: null,
      mask: kind == FilterKind.lensDistortion
          ? draw(MoonlitValleyPart.moonMask)
          : null,
    ),
  };
}
