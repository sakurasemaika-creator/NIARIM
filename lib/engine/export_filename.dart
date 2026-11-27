import 'dart:convert';

import 'package:flutter/widgets.dart' show StringCharacters;

final _invalid = RegExp(
  r'[<>:"/\\|?*\x00-\x1f\x7f-\x9f\u061c\u200e\u200f\u202a-\u202e\u2066-\u2069]+',
);
final _edgeDots = RegExp(r'^[ .]+|[ .]+$');
final _reserved = RegExp(
  r'^(con|prn|aux|nul|com[1-9¹²³]|lpt[1-9¹²³])\s*\.',
  caseSensitive: false,
);

/// Produces a portable basename without splitting a visible character.
/// Leaves space for the date, frame number, collision suffix and extension.
/// [making] marks a making video ("作品名 Making 日時"): found by the work's
/// name in the Works list like the work's own exports.
String exportFilenameStem(
  String? projectName,
  DateTime time, {
  int? frameIndex,
  bool making = false,
}) {
  final title = (projectName ?? '')
      .replaceAll(_invalid, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(_edgeDots, '');
  final buffer = StringBuffer();
  var byteCount = 0;
  for (final character in title.characters) {
    final count = utf8.encode(character).length;
    if (byteCount + count > 160) break;
    buffer.write(character);
    byteCount += count;
  }
  final name = buffer.toString().trimRight();
  if (name.isEmpty) {
    final prefix = making
        ? 'niarim_making'
        : frameIndex == null
        ? 'niarim'
        : 'niarim_frame';
    return '${prefix}_${time.millisecondsSinceEpoch}';
  }
  final safeName = _reserved.hasMatch(name) ? '_$name' : name;
  final frame = making
      ? ' Making'
      : frameIndex == null
      ? ''
      : ' F${(frameIndex + 1).toString().padLeft(3, '0')}';
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  final date =
      '${local.year.toString().padLeft(4, '0')}${two(local.month)}${two(local.day)}';
  final clock = '${two(local.hour)}${two(local.minute)}${two(local.second)}';
  return '$safeName$frame $date-$clock';
}
