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
  const TipScreenCaptures({
    super.key,
    required this.frames,
    this.index,
    this.onChanged,
  });

  final List<TipScreenCapture> frames;
  final int? index;
  final ValueChanged<int>? onChanged;

  @override
  State<TipScreenCaptures> createState() => _TipScreenCapturesState();
}

class _TipScreenCapturesState extends State<TipScreenCaptures> {
  int _localIndex = 0;

  void _select(int index) {
    final onChanged = widget.onChanged;
    if (onChanged != null) {
      onChanged(index);
    } else {
      setState(() => _localIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final words = AppLocalizations.of(context)!;
    final count = widget.frames.length;
    final selected = (widget.index ?? _localIndex).clamp(0, count - 1);
    final capture = widget.frames[selected];
    final theme = Theme.of(context);
    final caption = theme.textTheme.titleSmall!.copyWith(height: 1.2);
    final captionLine =
        MediaQuery.textScalerOf(context).scale(caption.fontSize!) *
        caption.height!;
    final captionLines = captionLine > 23 ? 3 : 2;
    return Column(
      children: [
        SizedBox(
          height: captionLine * captionLines + 4,
          child: Center(
            child: SingleChildScrollView(
              primary: false,
              child: messageText(
                capture.label,
                keepLineStarts: true,
                textAlign: TextAlign.center,
                style: caption,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SizedBox.expand(
            key: const ValueKey('tipCaptureViewport'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: _CapturePicture(capture),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (count > 1) ...[
              IconButton(
                key: const ValueKey('tipPreviousCapture'),
                tooltip: material.previousPageTooltip,
                onPressed: selected == 0 ? null : () => _select(selected - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Semantics(
                liveRegion: true,
                label: material.pageRowsInfoTitle(
                  selected + 1,
                  selected + 1,
                  count,
                  false,
                ),
                excludeSemantics: true,
                child: Text('${selected + 1} / $count'),
              ),
              IconButton(
                key: const ValueKey('tipNextCapture'),
                tooltip: material.nextPageTooltip,
                onPressed: selected >= count - 1
                    ? null
                    : () => _select(selected + 1),
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
                      child: _CapturePicture(capture),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          capture.asset,
          fit: BoxFit.contain,
          semanticLabel: capture.label,
        ),
        if (capture.focus.isNotEmpty)
          IgnorePointer(
            child: CustomPaint(
              painter: _CaptureFocus(capture.size, capture.focus),
            ),
          ),
      ],
    );
  }
}

class _CaptureFocus extends CustomPainter {
  const _CaptureFocus(this.imageSize, this.focus);

  final Size imageSize;
  final List<Rect> focus;

  @override
  void paint(Canvas canvas, Size size) {
    final fitted = applyBoxFit(BoxFit.contain, imageSize, size).destination;
    final picture = Alignment.center.inscribe(fitted, Offset.zero & size);
    final scale = fitted.shortestSide / 300;
    final outline = Paint()..style = PaintingStyle.stroke;
    for (final rect in focus) {
      final target = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          picture.left + rect.left * picture.width,
          picture.top + rect.top * picture.height,
          rect.width * picture.width,
          rect.height * picture.height,
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
  bool shouldRepaint(_CaptureFocus previous) =>
      previous.imageSize != imageSize || previous.focus != focus;
}
