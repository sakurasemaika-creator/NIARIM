import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/icon_notice.dart';

/// Where a clip lies on the timeline, typed as frame numbers (時間範囲 of
/// 長さ調整): its first and last frame, numbered from 1 as the timeline
/// shows them, and the length that gives. A number is applied when it is
/// entered (Enter, or leaving the field); a half-typed number is not.
///
/// [onApply] gets the new first and last frame (from 0) and changes the
/// clip, returning null, or returns why it did not (the clip would overlap
/// another on its row, or start before its sound); nothing is changed then.
/// The clip's edges can still be dragged on the timeline as before.
class ClipTimeRangeControl extends StatefulWidget {
  const ClipTimeRangeControl({
    super.key,
    required this.start,
    required this.end,
    required this.totalFrames,
    required this.framesPerSecond,
    required this.onApply,
  });

  /// The clip's first and last frame on the timeline (from 0, the last one
  /// included).
  final int start;
  final int end;

  /// The frames the scene has: the clip stays inside them.
  final int totalFrames;
  final double framesPerSecond;
  final String? Function(int start, int end) onApply;

  @override
  State<ClipTimeRangeControl> createState() => _ClipTimeRangeControlState();
}

class _ClipTimeRangeControlState extends State<ClipTimeRangeControl> {
  final TextEditingController _startField = TextEditingController();
  final TextEditingController _endField = TextEditingController();
  final FocusNode _startFocus = FocusNode();
  final FocusNode _endFocus = FocusNode();
  String? _problem;
  bool _invalidEntry = false;

  @override
  void initState() {
    super.initState();
    _startField.text = '${widget.start + 1}';
    _endField.text = '${widget.end + 1}';
    _startFocus.addListener(() {
      if (!_startFocus.hasFocus) _submit();
    });
    _endFocus.addListener(() {
      if (!_endFocus.hasFocus) _submit();
    });
  }

  @override
  void didUpdateWidget(ClipTimeRangeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The clip may change elsewhere (a drag on the timeline, Undo, its
    // speed): show where it is now, except in a field with a number being
    // typed (one that still shows the old frame is not).
    if (oldWidget.start != widget.start &&
        (!_startFocus.hasFocus ||
            _startField.text.trim() == '${oldWidget.start + 1}')) {
      _startField.text = '${widget.start + 1}';
    }
    if (oldWidget.end != widget.end &&
        (!_endFocus.hasFocus ||
            _endField.text.trim() == '${oldWidget.end + 1}')) {
      _endField.text = '${widget.end + 1}';
    }
  }

  @override
  void dispose() {
    _startField.dispose();
    _endField.dispose();
    _startFocus.dispose();
    _endFocus.dispose();
    super.dispose();
  }

  /// The frame typed in [field] (from 0), or null when it is not a whole
  /// number inside the scene.
  int? _frameIn(TextEditingController field) {
    final value = int.tryParse(field.text.trim());
    if (value == null || value < 1 || value > widget.totalFrames) return null;
    return value - 1;
  }

  void _submit() {
    // Focus can leave a field while the control is being taken away.
    if (!mounted) return;
    final start = _frameIn(_startField);
    final end = _frameIn(_endField);
    if (start == null || end == null || start > end) {
      setState(() {
        _invalidEntry = true;
        _problem = null;
      });
      return;
    }
    if (start == widget.start && end == widget.end) {
      setState(() {
        _invalidEntry = false;
        _problem = null;
      });
      return;
    }
    final problem = widget.onApply(start, end);
    setState(() {
      _invalidEntry = false;
      _problem = problem;
      if (problem != null) {
        _startField.text = '${widget.start + 1}';
        _endField.text = '${widget.end + 1}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final frames = widget.end - widget.start + 1;
    final fps = widget.framesPerSecond > 0 ? widget.framesPerSecond : 1;
    final seconds = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 2,
    ).format(frames / fps);
    final small = Theme.of(context).textTheme.bodySmall;

    Widget field(
      String key,
      TextEditingController controller,
      FocusNode focus,
      String label,
    ) => TextField(
      key: ValueKey(key),
      controller: controller,
      focusNode: focus,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'F',
        isDense: true,
      ),
      onSubmitted: (_) => _submit(),
      // Keep the keyboard and the focus in the field after Enter.
      onEditingComplete: () {},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.timelineDurationRangeHint, style: small),
        const SizedBox(height: 8),
        field(
          'clipRangeStart',
          _startField,
          _startFocus,
          l10n.timelineDurationStartLabel,
        ),
        const SizedBox(height: 8),
        field(
          'clipRangeEnd',
          _endField,
          _endFocus,
          l10n.timelineDurationEndLabel,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.timelineDurationLength(frames, seconds),
          key: const ValueKey('clipRangeLength'),
          style: small,
        ),
        if (_invalidEntry) ...[
          const SizedBox(height: 8),
          IconNotice(
            l10n.timelineDurationInvalid(widget.totalFrames),
            key: const ValueKey('clipRangeInvalid'),
            icon: Icons.info_outline,
            liveRegion: true,
          ),
        ],
        if (_problem != null) ...[
          const SizedBox(height: 8),
          IconNotice(
            _problem!,
            key: const ValueKey('clipRangeProblem'),
            icon: Icons.info_outline,
            liveRegion: true,
          ),
        ],
      ],
    );
  }
}
