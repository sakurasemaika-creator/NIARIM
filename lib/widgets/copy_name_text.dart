import 'package:flutter/widgets.dart';

import '../utils/duplicate_name.dart';
import 'keep_together_text.dart';

/// 文[text]を描く。複製の名前（[name]、省けば[text]そのもの）の印と拡張子
/// （「(コピー 2)」「（副本）.png」）は行の途中で切らない（番号が印から離れて
/// 「(コピー」「2)」と折れていた）。描く文だけを変え、`Text.data`・読み上げは
/// 元の文のまま（[KeepTogetherText]）。複製の名前でなければ普通の[Text]。
Widget copyNameText(String text, {String? name, Key? key, TextStyle? style}) {
  final keep = copyMarkParts(name ?? text);
  if (keep.isEmpty) return Text(text, key: key, style: style);
  return KeepTogetherText(text, key: key, keep: keep, style: style);
}
