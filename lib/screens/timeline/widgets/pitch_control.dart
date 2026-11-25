import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../engine/clip_speed.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/labeled_slider.dart';

/// 音の高さ: a sound's pitch change in semitones, on its own (the speed keeps
/// the pitch). The slider moves it a semitone at a time; the field below it
/// takes any value in the range (decimals and minus too, applied on Enter or
/// when the field is left); 速度に合わせる sets the pitch a tape would have
/// at [soundRate], the speed the sound plays at; 元の高さ puts it back to 0.
///
/// [onChanged] gets each value while the slider is dragged, [onCommit] the
/// value when a drag ends or a button or typed value sets it.
class PitchControl extends StatefulWidget {
  const PitchControl({
    super.key,
    required this.semitones,
    required this.soundRate,
    required this.onChanged,
    required this.onCommit,
  });

  final double semitones;
  final double soundRate;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onCommit;

  /// [semitones] for the value of the slider: signed, one decimal when it
  /// is not a whole semitone, in the language's way of writing numbers.
  static String valueText(double semitones, String locale) {
    final rounded = (semitones * 10).round() / 10;
    if (rounded == 0) return '0';
    final whole = rounded == rounded.roundToDouble();
    final number = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: whole ? 0 : 1,
    ).format(rounded.abs());
    return '${rounded > 0 ? '+' : '−'}$number';
  }

  @override
  State<PitchControl> createState() => _PitchControlState();
}

class _PitchControlState extends State<PitchControl> {
  final TextEditingController _field = TextEditingController();
  final FocusNode _fieldFocus = FocusNode();
  bool _invalidEntry = false;

  @override
  void initState() {
    super.initState();
    _field.text = formatPitchSemitones(widget.semitones);
    _fieldFocus.addListener(() {
      if (!_fieldFocus.hasFocus) _submit();
    });
  }

  @override
  void didUpdateWidget(PitchControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The pitch may change elsewhere (the slider, a button, Undo): show it,
    // except while a value is being typed (a field still showing the old
    // value, or a refused one, is not being typed in).
    if (oldWidget.semitones != widget.semitones &&
        (!_fieldFocus.hasFocus ||
            _invalidEntry ||
            parsePitchSemitones(_field.text) == oldWidget.semitones)) {
      _field.text = formatPitchSemitones(widget.semitones);
      _invalidEntry = false;
    }
  }

  @override
  void dispose() {
    _field.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  void _submit() {
    // Focus can leave the field while the control is being taken away.
    if (!mounted) return;
    final typed = parsePitchSemitones(_field.text);
    setState(() => _invalidEntry = typed == null);
    if (typed == null || typed == widget.semitones) return;
    widget.onCommit(typed);
  }

  void _set(double value) {
    _field.text = formatPitchSemitones(value);
    setState(() => _invalidEntry = false);
    widget.onCommit(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final semitones = widget.semitones;
    final value = semitones
        .clamp(minPitchSemitones, maxPitchSemitones)
        .toDouble();
    final matching = pitchMatchingSpeed(widget.soundRate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledSlider(
          key: const ValueKey('pitchSlider'),
          label: l10n.timelinePitchLabel,
          value: value,
          min: minPitchSemitones,
          max: maxPitchSemitones,
          divisions: (maxPitchSemitones - minPitchSemitones).round(),
          isInt: false,
          valueText: PitchControl.valueText(value, locale),
          onChanged: widget.onChanged,
          onChangeEnd: widget.onCommit,
        ),
        TextField(
          key: const ValueKey('pitchField'),
          controller: _field,
          focusNode: _fieldFocus,
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: true,
          ),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.timelinePitchInputLabel,
            errorText: _invalidEntry ? l10n.timelinePitchInvalid : null,
            isDense: true,
          ),
          onSubmitted: (_) => _submit(),
          // Keep the keyboard and the focus in the field after Enter.
          onEditingComplete: () {},
        ),
        const SizedBox(height: 6),
        Text(
          l10n.timelinePitchHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              key: const ValueKey('pitchMatchSpeed'),
              icon: const Icon(Icons.speed, size: 18),
              label: Text(l10n.timelinePitchMatchSpeed),
              // At 1x there is nothing to match.
              onPressed: widget.soundRate == 1 || matching == semitones
                  ? null
                  : () => _set(matching),
            ),
            TextButton.icon(
              key: const ValueKey('pitchReset'),
              icon: const Icon(Icons.restart_alt, size: 18),
              label: Text(l10n.timelinePitchReset),
              onPressed: semitones == 0 ? null : () => _set(0),
            ),
          ],
        ),
      ],
    );
  }
}
