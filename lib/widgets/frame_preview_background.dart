import 'package:flutter/material.dart';

import '../utils/color_contrast.dart';

/// The two grey squares the canvas uses to show transparency.
const Color kTransparencyCheckerLight = Color.fromARGB(255, 242, 242, 242);
const Color kTransparencyCheckerDark = Color.fromARGB(255, 167, 167, 167);

/// What shows behind a frame's picture in a small preview (the frame lists,
/// the playback preview): the project's background colour, as the canvas and
/// the export show it, with the canvas's checkerboard under any part of it
/// that is transparent. The pictures themselves carry no background, so
/// without this a frame shows the panel's colour through its empty parts.
///
/// [showTransparency] shows the checkerboard instead of the colour, as the
/// canvas does when it is switched to show transparency. With [aspectRatio]
/// the background covers only the picture's own rectangle, centred, so a
/// picture letterboxed into its cell isn't framed by background colour.
class FramePreviewBackground extends StatelessWidget {
  const FramePreviewBackground({
    super.key,
    required this.backgroundColor,
    this.showTransparency = false,
    this.aspectRatio,
    this.checkerSize = 6,
    this.child,
  });

  /// The project's background colour (ARGB).
  final int backgroundColor;
  final bool showTransparency;
  final double? aspectRatio;
  final double checkerSize;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final color = Color(backgroundColor);
    final opaque = !showTransparency && (backgroundColor >>> 24) == 0xFF;
    Widget layered = Stack(
      fit: StackFit.expand,
      children: [
        if (!opaque)
          CustomPaint(painter: TransparencyCheckerPainter(size: checkerSize)),
        if (!showTransparency && (backgroundColor >>> 24) != 0)
          ColoredBox(color: color),
        ?child,
      ],
    );
    final ratio = aspectRatio;
    if (ratio != null && ratio.isFinite && ratio > 0) {
      layered = Center(
        child: AspectRatio(aspectRatio: ratio, child: layered),
      );
    }
    return layered;
  }
}

/// The colour of a mark drawn on a project's paper where its picture would
/// be (a cover before the project has a thumbnail). The paper is the
/// project's own background colour, chosen per project rather than taken
/// from the theme, so a theme colour can vanish on it (light theme text on
/// white paper, dark text on black paper). The mark is a neutral ink chosen
/// for the paper instead: black on light paper, white on dark, at the muted
/// strength of a placeholder (60% / 70%). Where that is too faint (strongly
/// coloured paper, or as seen with protanopia, deuteranopia or tritanopia)
/// the ink is made stronger until it reaches APCA |Lc| 45, the guide for
/// icons with fine detail. Transparent paper shows the checkerboard, so the
/// ink must read on both of its squares.
Color paperMarkColor(int backgroundColor, {bool showTransparency = false}) =>
    _paperMarks.putIfAbsent((
      backgroundColor,
      showTransparency,
    ), () => _paperMark(backgroundColor, showTransparency: showTransparency));

final _paperMarks = <(int, bool), Color>{};

const double _kPaperMarkLc = 45;

Color _paperMark(int backgroundColor, {required bool showTransparency}) {
  final paper = Color(backgroundColor);
  final under = showTransparency || paper.a == 0
      ? const [kTransparencyCheckerLight, kTransparencyCheckerDark]
      : paper.a >= 1
      ? [paper]
      : [
          Color.alphaBlend(paper, kTransparencyCheckerLight),
          Color.alphaBlend(paper, kTransparencyCheckerDark),
        ];
  double weakest(Color ink) {
    var lc = double.infinity;
    for (final surface in under) {
      final drawn = Color.alphaBlend(ink, surface);
      lc = [
        lc,
        apcaContrast(drawn, surface).abs(),
        for (final type in const [
          ColorVisionType.protanopia,
          ColorVisionType.deuteranopia,
          ColorVisionType.tritanopia,
        ])
          apcaContrast(
            simulateColorVision(drawn, type),
            simulateColorVision(surface, type),
          ).abs(),
      ].reduce((a, b) => a < b ? a : b);
    }
    return lc;
  }

  // Each ink starts muted and grows in small steps; the one that reads with
  // the lighter touch wins (or, if neither reaches the guide, the clearer).
  ({Color ink, double lc})? best;
  for (final (base, muted) in const [
    (Colors.black, 0.6),
    (Colors.white, 0.7),
  ]) {
    var alpha = muted;
    var ink = base.withValues(alpha: alpha);
    var lc = weakest(ink);
    while (lc < _kPaperMarkLc && alpha < 1) {
      alpha = (alpha + 0.04).clamp(0.0, 1.0);
      ink = base.withValues(alpha: alpha);
      lc = weakest(ink);
    }
    final current = best;
    final reaches = lc >= _kPaperMarkLc;
    final bestReaches = current != null && current.lc >= _kPaperMarkLc;
    if (current == null ||
        (reaches && !bestReaches) ||
        (reaches && bestReaches && ink.a < current.ink.a) ||
        (!reaches && !bestReaches && lc > current.lc)) {
      best = (ink: ink, lc: lc);
    }
  }
  return best!.ink;
}

/// The canvas's transparency checkerboard, in squares of [size].
class TransparencyCheckerPainter extends CustomPainter {
  const TransparencyCheckerPainter({this.size = 6});

  final double size;

  @override
  void paint(Canvas canvas, Size area) {
    final light = Paint()..color = kTransparencyCheckerLight;
    final dark = Paint()..color = kTransparencyCheckerDark;
    canvas.drawRect(Offset.zero & area, light);
    for (var row = 0; row * size < area.height; row++) {
      for (var col = 0; col * size < area.width; col++) {
        if ((row + col).isOdd) {
          canvas.drawRect(
            Rect.fromLTWH(col * size, row * size, size, size),
            dark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(TransparencyCheckerPainter oldDelegate) =>
      oldDelegate.size != size;
}
