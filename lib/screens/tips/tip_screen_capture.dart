import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/keep_together_text.dart';

/// Focus rectangles are fractions of the captured image's width and height.
class TipScreenCapture {
  const TipScreenCapture(this.asset, this.size, this.label, this.focus);

  final String asset;
  final Size size;
  final String label;
  final List<Rect> focus;
}

class TipScreenCaptures extends StatefulWidget {
  const TipScreenCaptures({super.key, required this.frames});

  final List<TipScreenCapture> frames;

  @override
  State<TipScreenCaptures> createState() => _TipScreenCapturesState();
}

class _TipScreenCapturesState extends State<TipScreenCaptures> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final words = AppLocalizations.of(context)!;
    final capture = widget.frames[_selected];
    final count = widget.frames.length;
    final caption = Theme.of(context).textTheme.titleSmall;
    return Column(
      children: [
        messageText(
          capture.label,
          keepLineStarts: true,
          textAlign: TextAlign.center,
          style: caption,
        ),
        const SizedBox(height: 8),
        Expanded(child: Center(child: _CapturePicture(capture))),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (count > 1) ...[
              IconButton(
                key: const ValueKey('tipPreviousCapture'),
                tooltip: material.previousPageTooltip,
                onPressed: _selected == 0
                    ? null
                    : () => setState(() => _selected--),
                icon: const Icon(Icons.chevron_left),
              ),
              Semantics(
                liveRegion: true,
                label: material.pageRowsInfoTitle(
                  _selected + 1,
                  _selected + 1,
                  count,
                  false,
                ),
                excludeSemantics: true,
                child: Text('${_selected + 1} / $count'),
              ),
              IconButton(
                key: const ValueKey('tipNextCapture'),
                tooltip: material.nextPageTooltip,
                onPressed: _selected >= count - 1
                    ? null
                    : () => setState(() => _selected++),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
            IconButton(
              tooltip: words.canvasViewZoomIn,
              onPressed: () => _enlarge(context, capture),
              icon: const Icon(Icons.fullscreen),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _enlarge(BuildContext context, TipScreenCapture capture) =>
      showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: messageText(
                          capture.label,
                          keepLineStarts: true,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: Center(child: _CapturePicture(capture)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _CapturePicture extends StatelessWidget {
  const _CapturePicture(this.capture);

  final TipScreenCapture capture;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: SizedBox.fromSize(
        size: capture.size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              capture.asset,
              fit: BoxFit.contain,
              semanticLabel: capture.label,
            ),
            IgnorePointer(
              child: CustomPaint(painter: _CaptureFocus(capture.focus)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureFocus extends CustomPainter {
  const _CaptureFocus(this.focus);

  final List<Rect> focus;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 300;
    final outline = Paint()..style = PaintingStyle.stroke;
    for (final rect in focus) {
      final target = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left * size.width,
          rect.top * size.height,
          rect.width * size.width,
          rect.height * size.height,
        ),
        Radius.circular(5 * scale),
      );
      canvas.drawRRect(
        target,
        outline
          ..color = Colors.white
          ..strokeWidth = 5 * scale,
      );
      canvas.drawRRect(
        target,
        outline
          ..color = const Color(0xffb61250)
          ..strokeWidth = 2.5 * scale,
      );
    }
  }

  @override
  bool shouldRepaint(_CaptureFocus previous) => previous.focus != focus;
}
