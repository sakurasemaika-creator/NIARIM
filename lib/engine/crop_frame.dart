import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import '../models/layer_crop.dart';

/// How much of each edge of a material's picture a crop cuts away, in
/// percent of the picture (its drawn part on the layer, [frame]).
typedef CropCuts = ({double left, double top, double right, double bottom});

/// The smallest part of the picture a crop keeps, in percent.
const double minCropKeptPercent = 1;

/// The rectangle a [content]-size picture takes when it is fitted, centred,
/// into a [width] × [height] layer (how timeline images and video frames are
/// placed).
Rect fittedContentRect(Size content, double width, double height) {
  if (content.width <= 0 || content.height <= 0 || width <= 0 || height <= 0) {
    return Rect.fromLTWH(0, 0, width, height);
  }
  final scale = math.min(width / content.width, height / content.height);
  final w = content.width * scale;
  final h = content.height * scale;
  return Rect.fromLTWH((width - w) / 2, (height - h) / 2, w, h);
}

/// The cuts [crop] makes in [frame] on a [width] × [height] layer.
CropCuts cropCutsIn(LayerCrop? crop, Rect frame, double width, double height) {
  final c = crop ?? LayerCrop.full;
  if (frame.width <= 0 || frame.height <= 0) {
    return (left: 0, top: 0, right: 0, bottom: 0);
  }
  double percent(double v) => (v * 100).clamp(0, 100).toDouble();
  return (
    left: percent((c.left * width - frame.left) / frame.width),
    top: percent((c.top * height - frame.top) / frame.height),
    right: percent((frame.right - c.right * width) / frame.width),
    bottom: percent((frame.bottom - c.bottom * height) / frame.height),
  );
}

/// The crop that cuts [cuts] from [frame] on a [width] × [height] layer, or
/// null when it cuts nothing. Each pair of opposite cuts keeps at least
/// [minCropKeptPercent] of the picture.
LayerCrop? cropFromCuts(
  CropCuts cuts,
  Rect frame,
  double width,
  double height,
) {
  if (width <= 0 || height <= 0 || frame.width <= 0 || frame.height <= 0) {
    return null;
  }
  const most = 100 - minCropKeptPercent;
  double clampCut(double v) => v.isFinite ? v.clamp(0, most).toDouble() : 0;
  var left = clampCut(cuts.left);
  var right = clampCut(cuts.right);
  var top = clampCut(cuts.top);
  var bottom = clampCut(cuts.bottom);
  if (left + right > most) right = most - left;
  if (top + bottom > most) bottom = most - top;
  if (left == 0 && right == 0 && top == 0 && bottom == 0) return null;
  final crop = LayerCrop(
    left: ((frame.left + frame.width * left / 100) / width).clamp(0, 1),
    top: ((frame.top + frame.height * top / 100) / height).clamp(0, 1),
    right: ((frame.right - frame.width * right / 100) / width).clamp(0, 1),
    bottom: ((frame.bottom - frame.height * bottom / 100) / height).clamp(0, 1),
  );
  return crop.isValid ? crop : null;
}
