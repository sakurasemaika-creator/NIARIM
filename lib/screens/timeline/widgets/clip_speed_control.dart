import 'package:flutter/material.dart';

import '../../../engine/clip_speed.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/icon_notice.dart';
import '../../../widgets/labeled_slider.dart';

/// The speed of a video, audio or read-aloud clip: a logarithmic slider for
/// the usual range, one-tap speeds, and a field for any speed from 0.01× to
/// 100×. The clip's end before and after is shown while a speed is chosen.
///
/// [onApply] changes the speed and returns null, or returns why it was not
/// changed (the clip would overlap another, pass the scene's end, or two
/// keyframes would land on one frame); nothing is changed then.
class ClipSpeedControl extends StatefulWidget {
  const ClipSpeedControl({
    super.key,
    required this.rate,
    required this.endFrameAt,
    required this.onApply,
    this.hasSound = false,
  });

  /// The clip's current speed.
  final double rate;

  /// The clip's last timeline frame (0-based) at a speed.
  final int Function(double rate) endFrameAt;
  final String? Function(double rate) onApply;

  /// Whether the clip plays sound (a note about high speeds is shown).
  final bool hasSound;

  @override
  State<ClipSpeedControl> createState() => _ClipSpeedControlState();
}

class _ClipSpeedControlState extends State<ClipSpeedControl> {
  final TextEditingController _field = TextEditingController();
  final FocusNode _fieldFocus = FocusNode();

  /// The speed being dragged on the slider (applied when released).
  double? _dragging;
  String? _problem;
  bool _invalidEntry = false;

  @override
  void initState() {
    super.initState();
    _field.text = _plain(widget.rate);
    _fieldFocus.addListener(() {
      if (!_fieldFocus.hasFocus) _submitField();
    });
  }

  @override
  void didUpdateWidget(ClipSpeedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rate != widget.rate && !_fieldFocus.hasFocus) {
      _field.text = _plain(widget.rate);
    }
  }

  @override
  void dispose() {
    _field.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  static String _plain(double rate) =>
      formatPlaybackRate(rate).replaceFirst(RegExp(r'x$'), '');

  void _apply(double rate) {
    if (rate == widget.rate) {
      setState(() => _problem = null);
      return;
    }
    final problem = widget.onApply(rate);
    setState(() {
      _problem = problem;
      _field.text = _plain(problem == null ? rate : widget.rate);
    });
  }

  void _submitField() {
    final rate = parsePlaybackRate(_field.text);
    if (rate == null) {
      setState(() => _invalidEntry = _field.text.trim().isNotEmpty);
      return;
    }
    setState(() => _invalidEntry = false);
    _apply(rate);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shown = _dragging ?? widget.rate;
    final before = widget.endFrameAt(widget.rate);
    final after = widget.endFrameAt(shown);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledSlider(
          key: const ValueKey('clipSpeedSlider'),
          label: l10n.timelineClipSpeedLabel,
          value: playbackRateToSlider(shown) * 1000,
          min: 0,
          max: 1000,
          editable: false,
          showSteppers: false,
          valueText: formatPlaybackRate(shown),
          onChanged: (position) =>
              setState(() => _dragging = sliderToPlaybackRate(position / 1000)),
          onChangeEnd: (position) {
            final rate = sliderToPlaybackRate(position / 1000);
            setState(() => _dragging = null);
            _apply(rate);
          },
        ),
        if (after != before)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              l10n.timelineClipSpeedEndPreview(before + 1, after + 1),
              key: const ValueKey('clipSpeedEndPreview'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final rate in quickPlaybackRates)
              ChoiceChip(
                key: ValueKey('clipSpeedQuick$rate'),
                label: Text(formatPlaybackRate(rate)),
                selected: rate == widget.rate,
                showCheckmark: false,
                onSelected: (_) => _apply(rate),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('clipSpeedField'),
          controller: _field,
          focusNode: _fieldFocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.timelineClipSpeedInputLabel,
            hintText: l10n.timelineClipSpeedInputHint,
            suffixText: 'x',
            errorText: _invalidEntry ? l10n.timelineClipSpeedInvalid : null,
            isDense: true,
          ),
          onSubmitted: (_) => _submitField(),
          // Keep the keyboard and the focus in the field after Enter.
          onEditingComplete: () {},
        ),
        if (_problem != null) ...[
          const SizedBox(height: 8),
          IconNotice(
            _problem!,
            key: const ValueKey('clipSpeedProblem'),
            icon: Icons.info_outline,
            liveRegion: true,
          ),
        ],
        if (widget.hasSound && shown > 2) ...[
          const SizedBox(height: 8),
          IconNotice(
            l10n.timelineClipSpeedSoundNote,
            icon: Icons.volume_down_outlined,
          ),
        ],
      ],
    );
  }
}
