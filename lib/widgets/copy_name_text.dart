import 'package:flutter/widgets.dart';

import '../utils/duplicate_name.dart';
import 'keep_together_text.dart';

/// 文[text]を描く。複製の名前（[name]、省けば[text]そのもの）の印と拡張子
/// （「(コピー 2)」「（副本）.png」）は行の途中で切らない（番号が印から離れて
/// 「(コピー」「2)」と折れていた）。韓国語の語（空白で区切った単位）も、1行に
/// 入るものは途中で切らない（ゴミ箱から戻す確認の文・名前が「휴지통에서 복원
/// 하 / 시겠습니까?」のように切れた。[koreanWordParts]）。描く文だけを変え、
/// `Text.data`・読み上げは元の文のまま（[KeepTogetherText]）。どちらも無ければ
/// 普通の[Text]。
Widget copyNameText(String text, {String? name, Key? key, TextStyle? style}) {
  final marks = copyMarkParts(name ?? text);
  final keep = [...marks, ...koreanWordParts(text, except: marks)];
  if (keep.isEmpty) return Text(text, key: key, style: style);
  return KeepTogetherText(text, key: key, keep: keep, style: style);
}
