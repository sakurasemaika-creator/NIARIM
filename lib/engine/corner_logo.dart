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

/// A corner of the frame for the GIF logo.
enum LogoCorner { bottomRight, bottomLeft, topRight, topLeft }

/// Where the GIF logo of a [width]×[height] frame goes.
///
/// The badge is a tenth of the shorter side, at least 24 px (a quarter of
/// the shorter side on frames too small for that), with a margin of 3% of
/// the shorter side (at least 4 px) from both edges of its corner.
class CornerLogoPlacement {
  CornerLogoPlacement(this.width, this.height, this.corner)
    : size = sizeFor(width, height),
      margin = marginFor(width, height);

  final int width;
  final int height;
  final LogoCorner corner;
  final int size;
  final int margin;

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
    LogoCorner.bottomRight || LogoCorner.topRight => width - margin - size,
    LogoCorner.bottomLeft || LogoCorner.topLeft => margin,
  };

  int get top => switch (corner) {
    LogoCorner.bottomRight || LogoCorner.bottomLeft => height - margin - size,
    LogoCorner.topRight || LogoCorner.topLeft => margin,
  };

  /// The badge with half the margin around it: the part of the frame the
  /// user's own watermark should stay out of.
  math.Rectangle<int> get clearArea {
    final gap = margin ~/ 2;
    final x = math.max(0, left - gap);
    final y = math.max(0, top - gap);
    return math.Rectangle<int>(
      x,
      y,
      math.min(width, left + size + gap) - x,
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

/// The NIARIM badge rendered for one placement, ready to stamp onto frames
/// (also in another isolate).
class CornerLogoStamp {
  const CornerLogoStamp({
    required this.left,
    required this.top,
    required this.size,
    required this.pixels,
  });

  final int left;
  final int top;
  final int size;

  /// [size]×[size] premultiplied RGBA of the opaque badge.
  final Uint8List pixels;

  /// How much of the frame shows through the badge.
  static const double opacity = 0.8;

  /// Colours the badge leaves are rounded to this step, so a badge over a
  /// detailed picture adds few colours to the frame's 256-colour GIF palette.
  static const int colourStep = 8;

  static Future<CornerLogoStamp> render(CornerLogoPlacement placement) async {
    final size = placement.size;
    final monogram = await loadNiarimMonogram();
    final recorder = ui.PictureRecorder();
    try {
      paintNiarimBadge(
        ui.Canvas(recorder),
        ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        monogram,
      );
    } finally {
      monogram.picture.dispose();
    }
    final picture = recorder.endRecording();
    final ui.Image image;
    try {
      image = await picture.toImage(size, size);
    } finally {
      picture.dispose();
    }
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return CornerLogoStamp(
        left: placement.left,
        top: placement.top,
        size: size,
        pixels: data!.buffer.asUint8List(),
      );
    } finally {
      image.dispose();
    }
  }

  /// Draws the badge at [opacity] onto [frame] (premultiplied, or opaque).
  void stampOnto(img.Image frame) {
    final hasAlpha = frame.numChannels == 4;
    for (var y = 0; y < size; y++) {
      final fy = top + y;
      if (fy < 0 || fy >= frame.height) continue;
      for (var x = 0; x < size; x++) {
        final fx = left + x;
        if (fx < 0 || fx >= frame.width) continue;
        final i = (y * size + x) * 4;
        final coverage = pixels[i + 3] * opacity / 255;
        if (coverage <= 0) continue;
        final keep = 1 - coverage;
        final under = frame.getPixel(fx, fy);
        int mix(int channel, num below) =>
            _rounded(pixels[i + channel] * opacity + below * keep);
        final r = mix(0, under.r);
        final g = mix(1, under.g);
        final b = mix(2, under.b);
        if (hasAlpha) {
          final a = (coverage * 255 + under.a * keep).round().clamp(0, 255);
          frame.setPixelRgba(
            fx,
            fy,
            math.min(r, a),
            math.min(g, a),
            math.min(b, a),
            a,
          );
        } else {
          frame.setPixelRgb(fx, fy, r, g, b);
        }
      }
    }
  }

  static int _rounded(double value) =>
      ((value / colourStep).round() * colourStep).clamp(0, 255);
}
