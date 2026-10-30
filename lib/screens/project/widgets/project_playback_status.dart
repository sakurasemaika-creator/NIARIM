import 'package:flutter/material.dart';
import '../../../config/accent_text_theme.dart';
import '../../../l10n/app_localizations.dart';

/// Playback values remain legible when system text scaling exceeds one row.
class ProjectPlaybackStatus extends StatefulWidget {
  const ProjectPlaybackStatus({
    super.key,
    required this.currentFrame,
    required this.totalFrames,
    required this.fps,
    required this.loopPlayback,
    required this.onToggleLoop,
  });

  final int currentFrame;
  final int totalFrames;
  final int fps;
  final bool loopPlayback;
  final VoidCallback onToggleLoop;

  @override
  State<ProjectPlaybackStatus> createState() => _ProjectPlaybackStatusState();
}

class _ProjectPlaybackStatusState extends State<ProjectPlaybackStatus> {
  Object? _measurementKey;
  late String _widestTime;
  late String _widestCounter;
  late double _rowWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveFps = widget.fps > 0 ? widget.fps : 24;
    final currentSeconds = widget.currentFrame == 0
        ? 0.0
        : (widget.currentFrame - 1) / effectiveFps;
    final currentLabel = '${currentSeconds.toStringAsFixed(1)}s';
    final totalLabel =
        '${(widget.totalFrames / effectiveFps).toStringAsFixed(1)}s';
    final frameLabel = '${widget.currentFrame}/${widget.totalFrames}';
    final colors = Theme.of(context).colorScheme;
    var frameStyle = DefaultTextStyle.of(context).style;
    if (MediaQuery.boldTextOf(context)) {
      frameStyle = frameStyle.copyWith(fontWeight: FontWeight.bold);
    }
    final timeStyle = frameStyle.copyWith(
      fontSize: 12,
      color: colors.onSurfaceVariant,
    );
    final l10n = AppLocalizations.of(context)!;
    final current = Text(
      currentLabel,
      key: const Key('projectDetailCurrentSeconds'),
      style: timeStyle,
    );
    final total = Text(
      totalLabel,
      key: const Key('projectDetailTotalSeconds'),
      style: timeStyle,
    );
    final counter = Text(
      frameLabel,
      key: const Key('projectDetailFrameCounter'),
      style: frameStyle,
      textAlign: TextAlign.center,
    );
    final loop = Semantics(
      toggled: widget.loopPlayback,
      child: IconButton(
        key: const Key('projectDetailLoopButton'),
        onPressed: widget.onToggleLoop,
        icon: Icon(
          Icons.repeat,
          color: widget.loopPlayback
              ? AccentTextTheme.of(context)
              : colors.onSurfaceVariant,
        ),
        tooltip: widget.loopPlayback
            ? l10n.timelineLoopOnTooltip
            : l10n.timelineLoopOffTooltip,
        iconSize: 20,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        visualDensity: VisualDensity.standard,
      ),
    );
    Size textSize(
      String value,
      TextStyle style, {
      double maxWidth = double.infinity,
    }) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        locale: Localizations.localeOf(context),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout(maxWidth: maxWidth);
      final size = painter.size;
      painter.dispose();
      return size;
    }

    // The two fonts have proportional digits. Measure the widest possible
    // counters once per project/typography change, rather than at each tick.
    final measurementKey = (
      widget.totalFrames,
      effectiveFps,
      frameStyle,
      MediaQuery.textScalerOf(context),
      Localizations.localeOf(context),
      Directionality.of(context),
    );
    if (_measurementKey != measurementKey) {
      _measurementKey = measurementKey;
      var timeWidth = 0.0;
      var counterWidth = 0.0;
      for (var digit = 0; digit <= 9; digit++) {
        final time = totalLabel.replaceAll(RegExp(r'[0-9]'), '$digit');
        final frame = List.filled(
          widget.totalFrames.toString().length,
          '$digit',
        ).join();
        final count = '$frame/${widget.totalFrames}';
        final tw = textSize(time, timeStyle).width;
        final cw = textSize(count, frameStyle).width;
        if (tw >= timeWidth) {
          timeWidth = tw;
          _widestTime = time;
        }
        if (cw >= counterWidth) {
          counterWidth = cw;
          _widestCounter = count;
        }
      }
      _rowWidth =
          timeWidth +
          counterWidth +
          48 +
          textSize(totalLabel, timeStyle).width +
          24;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _rowWidth) {
            // Preserve the existing three equal gaps and the two outer edges.
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [current, counter, loop, total],
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: textSize(
                    _widestTime,
                    timeStyle,
                    maxWidth: constraints.maxWidth / 2,
                  ).height,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: current),
                    Flexible(child: total),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: textSize(
                    _widestCounter,
                    frameStyle,
                    maxWidth: (constraints.maxWidth - 56).clamp(
                      1.0,
                      double.infinity,
                    ),
                  ).height.clamp(48.0, double.infinity),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: counter),
                    const SizedBox(width: 8),
                    loop,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
