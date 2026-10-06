import 'package:flutter/material.dart';

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
