import 'package:flutter/material.dart';

import '../../../engine/clip_speed.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/icon_notice.dart';
import '../../../widgets/typing_dialog_inset.dart';
import 'clip_speed_control.dart';

/// A range of keys and the speed to play it at, chosen in
/// [showKeyframeRetimeDialog].
typedef KeyframeRetime = ({int fromFrame, int toFrame, double rate});

/// Asks which keys (a range between two of [keyFrames]) should play how many
/// times as fast, showing where every key of the range would go first. The
/// keys' values and easing are not changed; keys outside the range stay put.
/// A speed that would make keys share a frame, pass a key after the range
/// or leave the scene (past [lastFrame]) cannot be chosen.
///
/// [exactTimes] gives the keys' times before rounding (frame → time), so
/// the positions shown are the ones applying the speed gives.
Future<KeyframeRetime?> showKeyframeRetimeDialog(
  BuildContext context, {
  required List<int> keyFrames,
  required int lastFrame,
  Map<int, double>? exactTimes,
}) => showDialog<KeyframeRetime>(
  context: context,
  builder: (context) => KeyframeRetimeDialog(
    keyFrames: keyFrames,
    lastFrame: lastFrame,
    exactTimes: exactTimes,
  ),
);

class KeyframeRetimeDialog extends StatefulWidget {
  const KeyframeRetimeDialog({
    super.key,
    required this.keyFrames,
    required this.lastFrame,
    this.exactTimes,
  });

  final List<int> keyFrames;
  final int lastFrame;

  /// The keys' times before rounding (frame → time); a key not in it is on
  /// its frame.
  final Map<int, double>? exactTimes;

  @override
  State<KeyframeRetimeDialog> createState() => _KeyframeRetimeDialogState();
}

class _KeyframeRetimeDialogState extends State<KeyframeRetimeDialog> {
  late final List<int> _keys = widget.keyFrames.toSet().toList()..sort();
  late int _from = _keys.first;
  late int _to = _keys.last;
  double _rate = 1;

  Map<int, int>? _movesAt(double rate) => retimeKeyRangeExact(
    {for (final k in _keys) k: widget.exactTimes?[k] ?? k.toDouble()},
    fromFrame: _from,
    toFrame: _to,
    rate: rate,
    lastFrame: widget.lastFrame,
  )?.map((frame, exact) => MapEntry(frame, exact.round()));

  void _setRange({int? from, int? to}) {
    setState(() {
      _from = from ?? _from;
      _to = to ?? _to;
      // A speed the new range cannot take goes back to 1x.
      if (_movesAt(_rate) == null) _rate = 1;
    });
  }

  String _frames(Iterable<int> frames) =>
      frames.map((f) => 'F${f + 1}').join(' · ');

  Widget _keyPicker({
    required String label,
    required int value,
    required Iterable<int> choices,
    required ValueChanged<int> onChanged,
    required Key key,
  }) => Row(
    children: [
      Expanded(child: Text(label)),
      DropdownButton<int>(
        key: key,
        value: value,
        items: [
          for (final f in choices)
            DropdownMenuItem(value: f, child: Text('F${f + 1}')),
        ],
        onChanged: (f) {
          if (f != null) onChanged(f);
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final moves = _movesAt(_rate);
    final inRange = [
      for (final f in _keys)
        if (f >= _from && f <= _to) f,
    ];
    return AlertDialog(
      insetPadding: dialogInsetPadding(context),
      title: Text(l10n.keyframeRetimeTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.keyframeRetimeHint),
              const SizedBox(height: 8),
              _keyPicker(
                key: const ValueKey('keyframeRetimeFrom'),
                label: l10n.keyframeRetimeFrom,
                value: _from,
                choices: _keys.where((f) => f < _to),
                onChanged: (f) => _setRange(from: f),
              ),
              _keyPicker(
                key: const ValueKey('keyframeRetimeTo'),
                label: l10n.keyframeRetimeTo,
                value: _to,
                choices: _keys.where((f) => f > _from),
                onChanged: (f) => _setRange(to: f),
              ),
              const SizedBox(height: 8),
              ClipSpeedControl(
                rate: _rate,
                hasSound: false,
                endFrameAt: (rate) => _movesAt(rate)?[_to] ?? _to,
                onApply: (rate) {
                  if (_movesAt(rate) == null) {
                    return l10n.keyframeRetimeClash;
                  }
                  setState(() => _rate = rate);
                  return null;
                },
              ),
              const SizedBox(height: 8),
              IconNotice(
                l10n.keyframeRetimePreview(
                  _frames(inRange),
                  _frames([for (final f in inRange) moves?[f] ?? f]),
                ),
                key: const ValueKey('keyframeRetimePreview'),
                icon: Icons.diamond_outlined,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('keyframeRetimeApply'),
          onPressed: _rate == 1 || moves == null
              ? null
              : () => Navigator.pop<KeyframeRetime>(context, (
                  fromFrame: _from,
                  toFrame: _to,
                  rate: _rate,
                )),
          child: Text(l10n.commonApply),
        ),
      ],
    );
  }
}
