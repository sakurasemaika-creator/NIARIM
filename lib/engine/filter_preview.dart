import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../models/filter_def.dart';
import 'auto_lineart_engine.dart';
import 'background_acclimation_engine.dart';
import 'filter_engine.dart';
import 'filter_selection.dart';
import 'prism_filter_engine.dart';

/// What a filter's preview is run with: the layer's pixels at the preview's
/// own size, and how that size relates to the canvas ([scale] is preview
/// pixels per canvas pixel, for settings measured in canvas pixels). [mask]
/// is the selection layer and [background] the other layers, both at the
/// preview's size, for the filters that use them.
typedef FilterPreviewJob = ({
  FilterDef filter,
  Uint8List data,
  int width,
  int height,
  double scale,
  int canvasWidth,
  int canvasHeight,
  Uint8List? mask,
  Uint8List? background,
  int frameIndex,
});

/// [runFilterPreview] kept inside the canvas selection: the coverage at the
/// preview's size, or null for the whole layer.
Uint8List runFilterPreviewInSelection(
  (FilterPreviewJob job, Uint8List? selection) args,
) {
  final (job, selection) = args;
  final out = runFilterPreview(job);
  return selection == null
      ? out
      : restrictToSelection(job.data, out, selection);
}

/// A filter's preview: [job]'s layer as the filter would leave it, at the
/// preview's size. A plain function of its input so it can run in a
/// background isolate (`compute`) while the controls stay responsive.
Uint8List runFilterPreview(FilterPreviewJob job) {
  final (
    :filter,
    :data,
    :width,
    :height,
    :scale,
    :canvasWidth,
    :canvasHeight,
    :mask,
    :background,
    :frameIndex,
  ) = job;
  final engine = FilterEngine();
  if (filter.kind == FilterKind.prism) {
    return PrismFilterEngine().apply(
      data,
      width,
      height,
      blurPx: filter.prismBlurPx * scale,
      gradientDirectionDegrees: filter.prismDirectionDegrees,
    );
  }
  switch (filter.kind) {
    case FilterKind.prism:
      return PrismFilterEngine().apply(
        data,
        width,
        height,
        blurPx: filter.prismBlurPx * scale,
        gradientDirectionDegrees: filter.prismDirectionDegrees,
      );
    // Radii are in canvas pixels; the preview is scaled down.
    case FilterKind.gaussianBlur:
      return engine.applyGaussianBlur(
        data,
        width,
        height,
        filter.strength * scale,
      );
    case FilterKind.lensBlur:
      return engine.applyLensBlur(data, width, height, filter.strength * scale);
    case FilterKind.animeStyle:
      return engine.applyAnimeStyle(
        data,
        width,
        height,
        strength: filter.strength,
        colorCount: filter.colorLevels,
        edgeStrength: filter.edgeStrength,
        lineWidth: filter.animeLineWidth * scale,
      );
    case FilterKind.outline:
      return engine.applyOutline(
        data,
        width,
        height,
        color: filter.outlineColor,
        // In canvas pixels; the preview is scaled down.
        widthPx: filter.outlineWidth * scale,
        erosion: filter.outlineErosion,
      );
    case FilterKind.toneCurve:
      return engine.applyToneCurve(
        data,
        width,
        height,
        filter.toneCurvePoints.length >= 4
            ? [
                for (var i = 0; i + 1 < filter.toneCurvePoints.length; i += 2)
                  Offset(
                    filter.toneCurvePoints[i],
                    filter.toneCurvePoints[i + 1],
                  ),
              ]
            : toneCurvePoints(filter.toneCurvePreset),
        redPoints: filter.toneCurveRedPoints.length >= 4
            ? [
                for (
                  var i = 0;
                  i + 1 < filter.toneCurveRedPoints.length;
                  i += 2
                )
                  Offset(
                    filter.toneCurveRedPoints[i],
                    filter.toneCurveRedPoints[i + 1],
                  ),
              ]
            : null,
        greenPoints: filter.toneCurveGreenPoints.length >= 4
            ? [
                for (
                  var i = 0;
                  i + 1 < filter.toneCurveGreenPoints.length;
                  i += 2
                )
                  Offset(
                    filter.toneCurveGreenPoints[i],
                    filter.toneCurveGreenPoints[i + 1],
                  ),
              ]
            : null,
        bluePoints: filter.toneCurveBluePoints.length >= 4
            ? [
                for (
                  var i = 0;
                  i + 1 < filter.toneCurveBluePoints.length;
                  i += 2
                )
                  Offset(
                    filter.toneCurveBluePoints[i],
                    filter.toneCurveBluePoints[i + 1],
                  ),
              ]
            : null,
      );
    case FilterKind.levels:
      return engine.applyLevels(
        data,
        width,
        height,
        inputBlack: filter.inputBlack,
        inputWhite: filter.inputWhite,
        inputGamma: filter.inputGamma,
        outputBlack: filter.outputBlack,
        outputWhite: filter.outputWhite,
        redLevels: filter.levelsRed.length >= 5 ? filter.levelsRed : null,
        greenLevels: filter.levelsGreen.length >= 5 ? filter.levelsGreen : null,
        blueLevels: filter.levelsBlue.length >= 5 ? filter.levelsBlue : null,
      );
    case FilterKind.sharpen:
      return engine.applySharpen(data, width, height, filter.strength);
    case FilterKind.unsharpMask:
      return engine.applyUnsharpMask(
        data,
        width,
        height,
        filter.strength,
        filter.edgeStrength,
      );
    case FilterKind.vignette:
      return engine.applyVignette(
        data,
        width,
        height,
        filter.strength,
        color: filter.vignetteColor,
        range: filter.vignetteRange,
      );
    case FilterKind.noise:
      return applyNoiseFilter(
        data,
        width,
        height,
        filter,
        frameIndex: frameIndex,
      );
    case FilterKind.retroAnime:
      return engine.applyRetroAnime(data, width, height, filter.strength);
    case FilterKind.crt:
      // The misregistration and bleed are in canvas pixels.
      return engine.applyCrt(
        data,
        width,
        height,
        filter.strength,
        aberration: filter.crtAberration * scale,
        bleed: filter.crtBleed * scale,
      );
    case FilterKind.colorAdjust:
      return engine.applyColorAdjust(
        data,
        width,
        height,
        saturation: filter.caSaturation,
        brightness: filter.caBrightness,
        contrast: filter.caContrast,
      );
    case FilterKind.threshold:
      return engine.applyThreshold(data, width, height, filter.thresholdValue);
    case FilterKind.fisheye:
      // The centre is a proportion of the canvas, so the preview's own
      // size places it.
      final center = filter.fisheyeCenter(width, height);
      return engine.applyFisheye(
        data,
        width,
        height,
        filter.strength,
        radiusPercent: filter.fisheyeRadius,
        centerOffsetX: center.x - width / 2,
        centerOffsetY: center.y - height / 2,
      );
    case FilterKind.sphereShading:
      return applySphereShadingFilter(data, width, height, filter, mask);
    case FilterKind.chromaticAberration:
      final (dx, dy, radial) = filter.chromaticDisplacement;
      return engine.applyChromaticShift(
        data,
        width,
        height,
        shiftX: dx * scale,
        shiftY: dy * scale,
        radial: radial * scale,
      );
    case FilterKind.lensDistortion:
      return engine.applyLensDistortion(
        data,
        width,
        height,
        filter.strength,
        mask,
        centerOffsetX: filter.lensCenterOffsetX * scale,
        centerOffsetY: filter.lensCenterOffsetY * scale,
      );
    case FilterKind.pixelate:
      // Blocks are measured in canvas pixels; the preview is a scaled-down
      // copy, so scale them with it.
      return engine.applyPixelate(
        data,
        width,
        height,
        mosaicSize: math.max(
          1.0,
          filter.pixelArtCellSize(canvasWidth, canvasHeight) * scale,
        ),
        colorMode: filter.pixelColorMode,
        colorLevels: filter.colorLevels,
        paletteColors: filter.pixelExplicitColors,
        dither: filter.pixelDither,
      );
    case FilterKind.mosaic:
      return engine.applyMosaic(
        data,
        width,
        height,
        (filter.strength * scale).round().clamp(1, kPixelArtMaxBlockSize),
      );
    case FilterKind.auroraHologram:
      return engine.applyAuroraHologram(
        data,
        width,
        height,
        strength: filter.strength,
        brightness: filter.hologramBrightness,
        saturation: filter.hologramSaturation,
        preset: filter.hologramPreset,
      );
    case FilterKind.autoLineart:
      return AutoLineartEngine.render(
        AutoLineartEngine.prepareEditableGraph(
          AutoLineartEngine.analyze(
            data,
            width,
            height,
            roughWidthPx: filter.autoLineartRoughWidth * scale,
          ),
          smoothingLevel: filter.autoLineartSmoothing.round().clamp(0, 10),
        ),
        width,
        height,
        outputWidthPx: math.max(1.0, filter.autoLineartOutputWidth * scale),
        taperLengthPx: filter.autoLineartTaper
            ? filter.autoLineartTaperLength * scale
            : 0,
        smoothing: 0,
        color: filter.autoLineartColor,
      );
    case FilterKind.inkPool:
      return engine.applyInkPoolComposite(
        data,
        width,
        height,
        color: filter.inkPoolColor,
        rangePx: filter.inkPoolRange * scale,
        centerWidthPx: filter.inkPoolCenterWidth * scale,
        maxAngleDegrees: filter.inkPoolMaxAngle,
      );
    case FilterKind.backgroundBlend:
      final others = background;
      if (others == null) return Uint8List.fromList(data);
      final previewFilter = filter.copyWith(
        bgBlendLength: filter.bgBlendLength * scale,
        bgBlendSamplingBand: filter.bgBlendSamplingBand * scale,
      );
      return BackgroundAcclimationEngine.apply(
        data,
        others,
        width,
        height,
        previewFilter,
      );
  }
}
