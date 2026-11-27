import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;

/// The pink of the NIARIM badge (the default theme's accent, also used by
/// the launcher icon and the official end mark).
const int niarimBadgeColor = 0xFFFF5C7A;

/// Paints the NIARIM badge (a rounded square in [niarimBadgeColor] with the
/// white monogram) into [rect] of [canvas]. [monogram] is the decoded
/// `assets/logo/app_logo.svg`.
void paintNiarimBadge(ui.Canvas canvas, ui.Rect rect, PictureInfo monogram) {
  final size = rect.width;
  canvas.drawRRect(
    ui.RRect.fromRectAndRadius(rect, ui.Radius.circular(size * 0.22)),
    ui.Paint()..color = const ui.Color(niarimBadgeColor),
  );
  // The monogram keeps an 8% inset inside the badge, like the splash screen.
  final inset = size * 0.08;
  final glyphSize = size - inset * 2;
  final glyphLeft = rect.left + inset;
  final glyphTop = rect.top + inset;
  canvas.save();
  // The monogram SVG has one colour; it is drawn white through a layer.
  canvas.saveLayer(
    ui.Rect.fromLTWH(glyphLeft, glyphTop, glyphSize, glyphSize),
    ui.Paint()
      ..colorFilter = const ui.ColorFilter.mode(
        ui.Color(0xFFFFFFFF),
        ui.BlendMode.srcIn,
      ),
  );
  canvas.translate(glyphLeft, glyphTop);
  final scale = glyphSize / monogram.size.width;
  canvas.scale(scale, scale);
  canvas.drawPicture(monogram.picture);
  canvas.restore();
  canvas.restore();
}

/// Loads the NIARIM monogram. The caller disposes the returned picture.
Future<PictureInfo> loadNiarimMonogram() =>
    vg.loadPicture(const SvgAssetLoader('assets/logo/app_logo.svg'), null);

/// Loads the NIARIM wordmark (the app name lettering). The caller disposes
/// the returned picture.
Future<PictureInfo> loadNiarimWordmark() =>
    vg.loadPicture(const SvgAssetLoader('assets/logo/title_logo.svg'), null);

/// Width ÷ height of the wordmark (`assets/logo/title_logo.svg`'s viewBox).
const double niarimWordmarkAspect = 3470 / 690;

/// Paints the NIARIM wordmark into [rect] of [canvas] in [color].
/// [wordmark] is the decoded `assets/logo/title_logo.svg`; [rect] should
/// have its aspect ratio.
void paintNiarimWordmark(
  ui.Canvas canvas,
  ui.Rect rect,
  PictureInfo wordmark,
  ui.Color color,
) {
  canvas.save();
  // The wordmark SVG has one colour; it is drawn in [color] through a layer.
  canvas.saveLayer(
    rect,
    ui.Paint()..colorFilter = ui.ColorFilter.mode(color, ui.BlendMode.srcIn),
  );
  canvas.translate(rect.left, rect.top);
  final scale = rect.width / wordmark.size.width;
  canvas.scale(scale, scale);
  canvas.drawPicture(wordmark.picture);
  canvas.restore();
  canvas.restore();
}

/// A corner of the frame for the GIF logo.
enum LogoCorner { bottomRight, bottomLeft, topRight, topLeft }

/// Where the GIF logo of a [width]×[height] frame goes.
///
/// The badge is a tenth of the shorter side, at least 24 px (a quarter of
/// the shorter side on frames too small for that), with a margin of 3% of
/// the shorter side (at least 4 px) from both edges of its corner. The app
/// name follows the badge on a translucent dark plate, its lettering about
/// half the badge high, when the badge is at least [minBadgeForName] px and
/// the whole logo takes at most half the frame width; otherwise the badge is
/// alone.
class CornerLogoPlacement {
  CornerLogoPlacement(this.width, this.height, this.corner)
    : size = sizeFor(width, height),
      margin = marginFor(width, height) {
    final nameHeight = (size * nameHeightRatio).round();
    final nameWidth = (nameHeight * niarimWordmarkAspect).ceil();
    final gap = (size * 0.2).round();
    final end = (size * 0.3).round();
    final wide = size + gap + nameWidth + end;
    showsName = size >= minBadgeForName && wide <= width / 2;
    if (showsName) {
      this.nameHeight = nameHeight;
      this.nameWidth = nameWidth;
      nameLeft = size + gap;
      logoWidth = wide;
    } else {
      this.nameHeight = 0;
      this.nameWidth = 0;
      nameLeft = size;
      logoWidth = size;
    }
  }

  /// Below this badge size the name would not be readable: badge only.
  static const int minBadgeForName = 22;

  /// The name's lettering height as a share of the badge size.
  static const double nameHeightRatio = 0.5;

  final int width;
  final int height;
  final LogoCorner corner;

  /// The badge's side.
  final int size;
  final int margin;

  /// Whether the app name follows the badge.
  late final bool showsName;

  /// The name's lettering box, from the logo's left edge.
  late final int nameLeft;
  late final int nameWidth;
  late final int nameHeight;

  /// The whole logo's width (its height is [size]).
  late final int logoWidth;

  static int sizeFor(int width, int height) {
    final shorter = math.min(width, height);
    final readable = math.min(24, shorter ~/ 4);
    return math.max(1, math.max(readable, (shorter * 0.1).round()));
  }

  static int marginFor(int width, int height) {
    final shorter = math.min(width, height);
    return math.min(math.max(4, (shorter * 0.03).round()), shorter ~/ 8);
  }

  int get left => switch (corner) {
    LogoCorner.bottomRight || LogoCorner.topRight => width - margin - logoWidth,
    LogoCorner.bottomLeft || LogoCorner.topLeft => margin,
  };

  int get top => switch (corner) {
    LogoCorner.bottomRight || LogoCorner.bottomLeft => height - margin - size,
    LogoCorner.topRight || LogoCorner.topLeft => margin,
  };

  /// The logo with half the margin around it: the part of the frame the
  /// user's own watermark should stay out of.
  math.Rectangle<int> get clearArea {
    final gap = margin ~/ 2;
    final x = math.max(0, left - gap);
    final y = math.max(0, top - gap);
    return math.Rectangle<int>(
      x,
      y,
      math.min(width, left + logoWidth + gap) - x,
      math.min(height, top + size + gap) - y,
    );
  }
}

/// The corner for the GIF logo: the first corner (bottom right, bottom left,
/// top right, top left) where [overlap] reports none of the user's own
/// watermark in its [CornerLogoPlacement.clearArea], or the corner with the
/// least of it.
LogoCorner chooseLogoCorner(double Function(LogoCorner corner) overlap) {
  var best = LogoCorner.bottomRight;
  var least = double.infinity;
  for (final corner in LogoCorner.values) {
    final amount = overlap(corner);
    if (amount <= 0) return corner;
    if (amount < least) {
      least = amount;
      best = corner;
    }
  }
  return best;
}

/// How much of [areas] (rectangles as fractions of the frame, 0–1) falls in
/// [area] of a [width]×[height] frame, in pixels.
double fractionalAreasInside(
  Iterable<ui.Rect> areas,
  int width,
  int height,
  math.Rectangle<int> area,
) {
  final target = ui.Rect.fromLTWH(
    area.left.toDouble(),
    area.top.toDouble(),
    area.width.toDouble(),
    area.height.toDouble(),
  );
  var sum = 0.0;
  for (final fraction in areas) {
    final scaled = ui.Rect.fromLTRB(
      fraction.left * width,
      fraction.top * height,
      fraction.right * width,
      fraction.bottom * height,
    );
    final common = scaled.intersect(target);
    if (common.width > 0 && common.height > 0) {
      sum += common.width * common.height;
    }
  }
  return sum;
}

/// Sums the alpha of [rgba] (a [width]-wide RGBA frame) inside [area].
double alphaInside(Uint8List rgba, int width, math.Rectangle<int> area) {
  var sum = 0;
  for (var y = area.top; y < area.top + area.height; y++) {
    final row = y * width * 4;
    for (var x = area.left; x < area.left + area.width; x++) {
      sum += rgba[row + x * 4 + 3];
    }
  }
  return sum.toDouble();
}

/// The NIARIM logo (the badge, and the app name on a translucent plate when
/// the frame is big enough) rendered once for one placement, ready to blend
/// onto every frame (also in another isolate). Only the logo's own pixels
/// are touched.
class CornerLogoStamp {
  CornerLogoStamp._(
    this._pixelAt,
    this._source,
    this._keep, {
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final int left;
  final int top;
  final int width;
  final int height;

  /// The covered pixels (y × [width] + x within the logo).
  final Int32List _pixelAt;

  /// Per covered pixel, the logo's premultiplied R, G, B, A at [opacity],
  /// × 256.
  final Uint16List _source;

  /// Per covered pixel, how much of the frame shows through, × 256.
  final Uint16List _keep;

  /// How much of the frame shows through the logo.
  static const double opacity = 0.85;

  /// The plate behind the name: black at this alpha (before [opacity]).
  static const double plateAlpha = 0.6;

  /// Colours the logo leaves are rounded to this step, so a logo over a
  /// detailed picture adds few colours to the frame's 256-colour GIF palette.
  static const int colourStep = 8;

  static final Uint8List _snapped = Uint8List.fromList([
    for (var v = 0; v < 256; v++)
      ((v / colourStep).round() * colourStep).clamp(0, 255).toInt(),
  ]);

  static Future<CornerLogoStamp> render(CornerLogoPlacement placement) async {
    final width = placement.logoWidth;
    final height = placement.size;
    final monogram = await loadNiarimMonogram();
    final wordmark = placement.showsName ? await loadNiarimWordmark() : null;
    final recorder = ui.PictureRecorder();
    try {
      final canvas = ui.Canvas(recorder);
      final radius = ui.Radius.circular(height * 0.22);
      if (wordmark != null) {
        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
            radius,
          ),
          ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, plateAlpha),
        );
        paintNiarimWordmark(
          canvas,
          ui.Rect.fromLTWH(
            placement.nameLeft.toDouble(),
            (height - placement.nameHeight) / 2,
            placement.nameWidth.toDouble(),
            placement.nameHeight.toDouble(),
          ),
          wordmark,
          const ui.Color(0xFFFFFFFF),
        );
      }
      paintNiarimBadge(
        canvas,
        ui.Rect.fromLTWH(0, 0, height.toDouble(), height.toDouble()),
        monogram,
      );
    } finally {
      monogram.picture.dispose();
      wordmark?.picture.dispose();
    }
    final picture = recorder.endRecording();
    final ui.Image image;
    try {
      image = await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
    final Uint8List rgba;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      rgba = data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
    final covered = <int>[];
    for (var i = 0; i < width * height; i++) {
      if (rgba[i * 4 + 3] != 0) covered.add(i);
    }
    final pixelAt = Int32List.fromList(covered);
    final source = Uint16List(covered.length * 4);
    final keep = Uint16List(covered.length);
    for (var k = 0; k < covered.length; k++) {
      final i = covered[k] * 4;
      for (var c = 0; c < 4; c++) {
        source[k * 4 + c] = (rgba[i + c] * opacity * 256).round();
      }
      keep[k] = ((1 - rgba[i + 3] * opacity / 255) * 256).round();
    }
    return CornerLogoStamp._(
      pixelAt,
      source,
      keep,
      left: placement.left,
      top: placement.top,
      width: width,
      height: height,
    );
  }

  /// Blends the logo onto [pixels]: a [frameWidth]×[frameHeight] frame of
  /// [channels] (3: RGB, 4: premultiplied RGBA) bytes per pixel.
  void stampOntoBytes(
    Uint8List pixels,
    int frameWidth,
    int frameHeight,
    int channels,
  ) {
    final snapped = _snapped;
    for (var k = 0; k < _pixelAt.length; k++) {
      final at = _pixelAt[k];
      final y = top + at ~/ width;
      final x = left + at % width;
      if (x < 0 || y < 0 || x >= frameWidth || y >= frameHeight) continue;
      final i = (y * frameWidth + x) * channels;
      final keep = _keep[k];
      final s = k * 4;
      final r = snapped[(_source[s] + pixels[i] * keep + 128) >> 8];
      final g = snapped[(_source[s + 1] + pixels[i + 1] * keep + 128) >> 8];
      final b = snapped[(_source[s + 2] + pixels[i + 2] * keep + 128) >> 8];
      if (channels == 4) {
        final a = (_source[s + 3] + pixels[i + 3] * keep + 128) >> 8;
        pixels[i] = r < a ? r : a;
        pixels[i + 1] = g < a ? g : a;
        pixels[i + 2] = b < a ? b : a;
        pixels[i + 3] = a;
      } else {
        pixels[i] = r;
        pixels[i + 1] = g;
        pixels[i + 2] = b;
      }
    }
  }

  /// Blends the logo onto [frame]. Returns the frame it drew on: [frame]
  /// itself, or a copy in 8-bit RGB(A) when [frame] was in another format.
  img.Image stampOnto(img.Image frame) {
    var target = frame;
    if (target.hasPalette ||
        target.format != img.Format.uint8 ||
        target.numChannels < 3) {
      target = target.convert(
        format: img.Format.uint8,
        numChannels: target.numChannels == 4 ? 4 : 3,
      );
    }
    stampOntoBytes(
      (target.data! as img.ImageDataUint8).data,
      target.width,
      target.height,
      target.numChannels,
    );
    return target;
  }
}
